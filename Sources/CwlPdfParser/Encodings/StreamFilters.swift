// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Compression
import Foundation
import zlib

extension PdfParseContext {
	mutating func decode(
		length: Int,
		filters: [String],
		decodeParams: PdfObject?,
		decryption: PdfDecryption?,
		objectId: PdfObjectIdentifier?,
		isImage: Bool
	) throws -> Data {
		guard length > 0 else {
			return Data()
		}
		guard var data = slice.pop(length: length).map(Data.init(_:)) else {
			throw PdfParseError(context: self, failure: .objectEndedUnexpectedly)
		}

		// Apply implicit decryption if no explicit Crypt filter in the chain
		let hasExplicitCrypt = filters.contains("Crypt")
		if !hasExplicitCrypt, let decryption, let objectId, decryption.shouldDecrypt(objectId: objectId) {
			// Get crypt filter name from DecodeParms if present
			let cryptFilterName = decodeParams?.dictionary(lookup: nil)?["Name"]?.name(lookup: nil)
			data = try decryption.decryptStream(data: data, objectId: objectId, cryptFilterName: cryptFilterName)
		}

		for (index, filter) in filters.enumerated() {
			// Get filter-specific params if DecodeParms is an array
			let params = decodeParams?.array(lookup: nil)?[safe: index]?.dictionary(lookup: nil)
				?? decodeParams?.dictionary(lookup: nil)

			switch filter {
			case "ASCII85Decode", "AHx": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "ASCIIHexDecode", "A85": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "CCITTFaxDecode", "CCF": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "Crypt":
				// Explicit Crypt filter - apply decryption with specified filter name
				if let decryption, let objectId {
					let cryptFilterName = params?["Name"]?.name(lookup: nil)
					data = try decryption.decryptStream(data: data, objectId: objectId, cryptFilterName: cryptFilterName)
				}
			case "DCTDecode", "DCT":
				if isImage {
					break
				}
				throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "FlateDecode", "Fl":
				data = try flateDecodeWithPredictor(data: data, params: params)
			case "JBIG2Decode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "JPXDecode":
				if isImage {
					break
				}
				throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "LZWDecode", "LZW": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "RunLengthDecode", "RL": throw PdfParseError(context: self, failure: .unsupportedFilter)
			default: throw PdfParseError(context: self, failure: .unknownFilter)
			}
		}
		return data
	}
}

/// Performs FlateDecode (zlib/deflate decompression) with optional predictor support.
private func flateDecodeWithPredictor(data: Data, params: [String: PdfObject]?) throws -> Data {
	// First, decompress using zlib/deflate
	let decompressed = try zlibDecompress(data: data)

	// Check for predictor
	let predictor = params?["Predictor"]?.integer(lookup: nil) ?? 1

	guard predictor != 1 else {
		// No predictor, return decompressed data as-is
		return decompressed
	}

	// Get predictor parameters
	let colors = params?["Colors"]?.integer(lookup: nil) ?? 1
	let bitsPerComponent = params?["BitsPerComponent"]?.integer(lookup: nil) ?? 8
	let columns = params?["Columns"]?.integer(lookup: nil) ?? 1

	if predictor == 2 {
		// TIFF Predictor 2
		return applyTiffPredictor2(data: decompressed, colors: colors, bitsPerComponent: bitsPerComponent, columns: columns)
	} else if predictor >= 10 && predictor <= 15 {
		// PNG predictors
		return try applyPngPredictor(data: decompressed, colors: colors, bitsPerComponent: bitsPerComponent, columns: columns)
	} else {
		// Unknown predictor, return data as-is
		return decompressed
	}
}

/// Attempts zlib decompression with multiple strategies for robustness.
private func zlibDecompress(data: Data) throws -> Data {
	// Check for valid zlib header (RFC 1950)
	// First byte: CMF (Compression Method and Flags)
	//   - Lower 4 bits: CM (compression method, should be 8 for deflate)
	//   - Upper 4 bits: CINFO (window size)
	// Second byte: FLG (flags)
	//   - The check: (CMF * 256 + FLG) must be multiple of 31
	let hasZlibHeader: Bool
	if data.count >= 2 {
		let cmf = data[data.startIndex]
		let flg = data[data.startIndex + 1]
		let cm = cmf & 0x0F
		let check = (Int(cmf) * 256 + Int(flg)) % 31
		hasZlibHeader = (cm == 8) && (check == 0)
	} else {
		hasZlibHeader = false
	}

	// Try decompression strategies in order of likelihood
	var lastError: Error?

	if hasZlibHeader {
		// Try with zlib header first
		do {
			return try zlibInflate(data: data, skipHeader: false)
		} catch {
			lastError = error
		}
		// Try skipping the header
		do {
			return try zlibInflate(data: data, skipHeader: true)
		} catch {
			lastError = error
		}
	} else {
		// Try raw deflate first
		do {
			return try zlibInflate(data: data, skipHeader: false)
		} catch {
			lastError = error
		}
	}

	// If all else fails, throw the last error
	throw lastError ?? NSError(domain: "FlateDecode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decompress data"])
}

/// Performs zlib/deflate inflation using the zlib library directly.
private func zlibInflate(data: Data, skipHeader: Bool) throws -> Data {
	let sourceData = skipHeader && data.count > 2 ? Data(data.dropFirst(2)) : data

	return try sourceData.withUnsafeBytes { (sourcePtr: UnsafeRawBufferPointer) -> Data in
		guard let sourceBaseAddress = sourcePtr.baseAddress else {
			throw NSError(domain: "FlateDecode", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid source data"])
		}

		var stream = z_stream()
		stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourceBaseAddress.assumingMemoryBound(to: Bytef.self))
		stream.avail_in = uInt(sourceData.count)

		// Use raw deflate (negative window bits) to handle both raw and zlib-wrapped streams
		// -15 means raw deflate with 32KB window
		// 15 means zlib format with 32KB window
		// 47 (15 + 32) means automatic header detection (zlib or gzip)
		let windowBits: Int32 = skipHeader ? -MAX_WBITS : MAX_WBITS + 32

		var status = inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
		guard status == Z_OK else {
			throw NSError(domain: "FlateDecode", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "inflateInit2 failed"])
		}

		defer {
			inflateEnd(&stream)
		}

		var output = Data()
		let chunkSize = 65536
		var buffer = [UInt8](repeating: 0, count: chunkSize)

		repeat {
			buffer.withUnsafeMutableBufferPointer { bufferPtr in
				stream.next_out = bufferPtr.baseAddress
				stream.avail_out = uInt(chunkSize)
			}

			status = inflate(&stream, Z_NO_FLUSH)

			let bytesProduced = chunkSize - Int(stream.avail_out)
			if bytesProduced > 0 {
				output.append(contentsOf: buffer[0..<bytesProduced])
			}
		} while status == Z_OK && stream.avail_in > 0

		guard status == Z_OK || status == Z_STREAM_END else {
			throw NSError(domain: "FlateDecode", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "inflate failed with status \(status)"])
		}

		return output
	}
}

/// Applies TIFF Predictor 2 (horizontal differencing).
private func applyTiffPredictor2(data: Data, colors: Int, bitsPerComponent: Int, columns: Int) -> Data {
	guard bitsPerComponent == 8 else {
		// Only 8-bit is commonly used; return as-is for other cases
		return data
	}

	let bytesPerPixel = colors
	let bytesPerRow = columns * bytesPerPixel

	guard bytesPerRow > 0 else { return data }

	var output = Data(capacity: data.count)
	var offset = 0

	while offset + bytesPerRow <= data.count {
		var row = [UInt8](repeating: 0, count: bytesPerRow)

		for i in 0..<bytesPerRow {
			let current = data[data.startIndex + offset + i]
			if i < bytesPerPixel {
				row[i] = current
			} else {
				row[i] = current &+ row[i - bytesPerPixel]
			}
		}

		output.append(contentsOf: row)
		offset += bytesPerRow
	}

	// Append any remaining bytes
	if offset < data.count {
		output.append(contentsOf: data[(data.startIndex + offset)...])
	}

	return output
}

/// Applies PNG predictor filters.
private func applyPngPredictor(data: Data, colors: Int, bitsPerComponent: Int, columns: Int) throws -> Data {
	let bytesPerPixel = max(1, (colors * bitsPerComponent + 7) / 8)
	let bytesPerRow = (columns * colors * bitsPerComponent + 7) / 8
	let rowStride = bytesPerRow + 1  // +1 for filter type byte

	guard rowStride > 1 else {
		return data
	}

	let rowCount = data.count / rowStride
	guard rowCount > 0 else {
		return data
	}

	var output = Data(capacity: rowCount * bytesPerRow)
	var previousRow = [UInt8](repeating: 0, count: bytesPerRow)

	for rowIndex in 0..<rowCount {
		let rowStart = data.startIndex + rowIndex * rowStride
		let filterType = data[rowStart]

		var currentRow = [UInt8](repeating: 0, count: bytesPerRow)

		for i in 0..<bytesPerRow {
			let raw = data[rowStart + 1 + i]
			let a = i >= bytesPerPixel ? currentRow[i - bytesPerPixel] : 0  // left
			let b = previousRow[i]  // up
			let c = i >= bytesPerPixel ? previousRow[i - bytesPerPixel] : 0  // upper-left

			switch filterType {
			case 0:  // None
				currentRow[i] = raw
			case 1:  // Sub
				currentRow[i] = raw &+ a
			case 2:  // Up
				currentRow[i] = raw &+ b
			case 3:  // Average
				currentRow[i] = raw &+ UInt8((Int(a) + Int(b)) / 2)
			case 4:  // Paeth
				currentRow[i] = raw &+ paethPredictor(a: a, b: b, c: c)
			default:
				// Unknown filter, treat as None
				currentRow[i] = raw
			}
		}

		output.append(contentsOf: currentRow)
		previousRow = currentRow
	}

	return output
}

/// Paeth predictor function used in PNG filtering.
private func paethPredictor(a: UInt8, b: UInt8, c: UInt8) -> UInt8 {
	let ia = Int(a)
	let ib = Int(b)
	let ic = Int(c)
	let p = ia + ib - ic
	let pa = abs(p - ia)
	let pb = abs(p - ib)
	let pc = abs(p - ic)

	if pa <= pb && pa <= pc {
		return a
	} else if pb <= pc {
		return b
	} else {
		return c
	}
}

private extension Array {
	subscript(safe index: Int) -> Element? {
		guard index >= 0, index < count else { return nil }
		return self[index]
	}
}
