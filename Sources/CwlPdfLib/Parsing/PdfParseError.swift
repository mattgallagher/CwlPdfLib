// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public enum PdfParseFailure: Sendable {
	case eofMarkerNotFound
	case expectedDictionary
	case expectedNaturalNumber
	case expectedObject
	case endOfFile
	case headerNotFound
	case invalidHexDigit
	case missingEndOfScope
	case missingLayoutForObject
	case objectEndedUnexpectedly
	case objectNotFount
	case startXrefNotFound
	case unexpectedToken
	case xrefNotFound
}

public struct PdfParseError: Error {
	public let failure: PdfParseFailure
	public var objectNumber: PdfObjectNumber?
	public var underlying: Error?
	public var range: Range<Int>?
}

extension PdfParseError {
	init(context: PdfParseContext, failure: PdfParseFailure) {
		self.init(failure: failure, range: (context.tokenStart ?? context.slice.startIndex)..<context.slice.startIndex)
	}
}
