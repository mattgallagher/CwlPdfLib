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
		objectId: PdfObjectIdentifier?
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
			case "DCTDecode", "DCT": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "FlateDecode", "Fl":
				if data.first == 0x78 {
					data = try (data.dropFirst(2) as NSData).decompressed(using: .zlib) as Data
				} else {
					data = try (data as NSData).decompressed(using: .zlib) as Data
				}
			case "JBIG2Decode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "JPXDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "LZWDecode", "LZW": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "RunLengthDecode", "RL": throw PdfParseError(context: self, failure: .unsupportedFilter)
			default: throw PdfParseError(context: self, failure: .unknownFilter)
			}
		}
		return data
	}
}

private extension Array {
	subscript(safe index: Int) -> Element? {
		guard index >= 0, index < count else { return nil }
		return self[index]
	}
}
