// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Compression
import Foundation

extension PdfParseContext {
	mutating func decode(length: Int, filter: PdfObject?, decodeParams: PdfObject?) throws -> Data {
		guard length > 0 else {
			return Data()
		}
		guard var data = slice.pop(length: length).map(Data.init(_:)) else {
			throw PdfParseError(context: self, failure: .objectEndedUnexpectedly)
		}
		for filter in try filters(from: filter) {
			switch filter {
			case "ASCII85Decode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "ASCIIHexDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "CCITTFaxDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "Crypt": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "DCTDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "FlateDecode": data = try (data.dropFirst(2) as NSData).decompressed(using: .zlib) as Data
			case "JBIG2Decode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "JPXDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "LZWDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			case "RunLengthDecode": throw PdfParseError(context: self, failure: .unsupportedFilter)
			default: throw PdfParseError(context: self, failure: .unknownFilter)
			}
		}
		return data
	}

	func filters(from filter: PdfObject?) throws -> [String] {
		switch filter {
		case nil: return []
		case .name(let string): return [string]
		case .array(let array): return array.compactMap(\.name)
		default: throw PdfParseError(context: self, failure: .unexpectedToken)
		}
	}
}
