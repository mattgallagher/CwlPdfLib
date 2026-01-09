// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

enum PdfToken: Sendable {
	case arrayClose
	case arrayOpen
	case closeAngle
	case comment(_ range: Range<Int>)
	case dictionaryClose
	case dictionaryOpen
	case hex(Data, high: UInt8?, name: String?)
	case identifier(_ range: Range<Int>)
	case integer(sign: Int, value: Int)
	case name(string: String, range: Range<Int>)
	case openAngle
	case real(sign: Double, value: Double, fraction: Double)
	case string(bytes: Data, range: Range<Int>)
	case stringEscape(bytes: Data)
	case stringOctal(bytes: Data, byte: UInt8, count: UInt8)
}

extension PdfToken {
	func requireIdentifier(context: inout PdfParseContext, equals identifier: PdfParseIdentifier, else failure: PdfParseFailure) throws {
		guard case .identifier(let range) = self, context.slice[reslice: range].elementsEqual(identifier.rawValue.utf8) else {
			throw PdfParseError(context: context, failure: failure)
		}
	}

	func isIdentifier(context: PdfParseContext, token: PdfToken? = nil, equals identifier: PdfParseIdentifier) -> Bool {
		guard case .identifier(let range) = self, context.slice[reslice: range].elementsEqual(identifier.rawValue.utf8) else {
			return false
		}
		return true
	}
	
	func requireNaturalNumber(context: inout PdfParseContext, else failure: PdfParseFailure = .expectedNaturalNumber) throws -> Int {
		guard case .integer(let sign, let value) = self, sign == 1 else {
			throw PdfParseError(context: context, failure: failure)
		}
		return value
	}
}
