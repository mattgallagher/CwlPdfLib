// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

protocol PdfContextParseable: Sendable {
	static func parse(context: inout PdfParseContext) throws -> Self
}

extension PdfParseContext {
	func pdfText(range: Range<Int>) -> String {
		slice[reslice: range].pdfText()
	}
	
	func data(range: Range<Int>) -> Data {
		Data(slice[reslice: range])
	}
	
	func identifierString(else failure: PdfParseFailure) throws -> String {
		guard case .identifier(let range) = token else {
			throw PdfParseError(context: self, failure: failure)
		}
		return pdfText(range: range)
	}

	func stringData(token: PdfToken? = nil, else failure: PdfParseFailure) throws -> Data {
		guard case .string(var bytes, let range) = token ?? self.token else {
			throw PdfParseError(context: self, failure: failure)
		}
		bytes.append(data(range: range))
		return bytes
	}
	
	func naturalNumber(token: PdfToken? = nil, else failure: PdfParseFailure = .expectedNaturalNumber) throws -> Int {
		guard case .integer(let sign, let value) = token ?? self.token, sign == 1 else {
			throw PdfParseError(context: self, failure: failure)
		}
		return value
	}
	
	func identifier(token: PdfToken? = nil, equals identifier: PdfIdentifier, else failure: PdfParseFailure) throws {
		guard case .identifier(let range) = token ?? self.token, slice[reslice: range].elementsEqual(identifier.rawValue.utf8) else {
			throw PdfParseError(context: self, failure: failure)
		}
	}
	
	func identifier(token: PdfToken? = nil, equals identifier: PdfIdentifier) -> Bool {
		guard case .identifier(let range) = token ?? self.token, slice[reslice: range].elementsEqual(identifier.rawValue.utf8) else {
			return false
		}
		return true
	}
}
