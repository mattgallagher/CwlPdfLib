// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public enum PdfParseFailure: Sendable {
	case eofMarkerNotFound
	case expectedDictionary
	case expectedIdentifierNotFound
	case expectedNaturalNumber
	case expectedCrLf
	case expectedObject
	case endOfFile
	case headerNotFound
	case invalidHexDigit
	case missingLength
	case missingEndOfScope
	case missingLayoutForObject
	case objectEndedUnexpectedly
	case objectNotFound
	case startXrefNotFound
	case unexpectedToken
	case unknownFilter
	case unsupportedFilter
	case xrefNotFound
}

public struct PdfParseError: Error {
	public let failure: PdfParseFailure
	public var objectIdentifier: PdfObjectIdentifier?
	public var underlying: Error?
	public var range: Range<Int>?
}

extension PdfParseError {
	init(context: PdfParseContext, failure: PdfParseFailure) {
		self.init(failure: failure, objectIdentifier: context.objectIdentifier, range: (context.tokenStart ?? context.slice.startIndex)..<context.slice.startIndex)
	}
}
