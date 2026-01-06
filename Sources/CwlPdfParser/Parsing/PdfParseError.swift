// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public enum PdfParseFailure: Int, Sendable {
	case eofMarkerNotFound
	case expectedArray
	case expectedCatalog
	case expectedCrLf
	case expectedDictionary
	case expectedIndirectObject
	case expectedIdentifierNotFound
	case expectedNaturalNumber
	case expectedObject
	case expectedOperator
	case expectedPageTree
	case expectedType
	case endOfFile
	case headerNotFound
	case invalidHexDigit
	case missingLength
	case missingEndOfScope
	case missingLayoutForObject
	case missingRequiredParameters	
	case pageNotFound
	case objectEndedUnexpectedly
	case objectNotFound
	case startXrefNotFound
	case unexpectedToken
	case unknownFilter
	case unknownOperator
	case unsupportedFilter
	case xrefNotFound
}

public struct PdfParseError: Error {
	public let failure: PdfParseFailure
	public var objectIdentifier: PdfObjectIdentifier?
	public var underlying: Error?
	public var range: Range<Int>?
}

extension PdfParseError: CustomNSError {
	public static var errorDomain: String { "CwlPdfLib.ParseError" }
	public var errorCode: Int {
		failure.rawValue
	}
	
	public var errorUserInfo: [String: Any] {
		var info: [String: Any] = [:]
		if let objectIdentifier = objectIdentifier {
			info["objectIdentifier"] = objectIdentifier
		}
		if let range = range {
			info["range"] = range
		}
		if let underlying = underlying {
			info["underlying"] = underlying
		}
		return info
	}
}

extension PdfParseError {
	init(context: PdfParseContext, failure: PdfParseFailure) {
		self.init(failure: failure, objectIdentifier: context.objectIdentifier, range: (context.tokenStart ?? context.slice.startIndex)..<context.slice.startIndex)
	}
}
