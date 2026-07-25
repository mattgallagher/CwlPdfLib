// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

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
	case expectedToken
	case endOfFile
	case endOfRange
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
	case unsupportedFontSubtype
	case unsupportedCMap
	case invalidCMapData
	case xrefNotFound
	case invalidPassword
	case passwordRequired
	case unsupportedEncryption
	case decryptionFailed
	case missingDocumentId
}

/// Describes the higher-level operation underway when PDF parsing fails.
public enum PdfParseIntent: Equatable, Sendable {
	/// Parsing operators from the identified content stream object.
	case contentOperatorStream(streamObject: PdfObjectIdentifier)
	/// Parsing either a classic cross-reference table or cross-reference stream header.
	case crossReferenceSection
	/// Parsing the identified cross-reference stream object.
	case crossReferenceStream(streamObject: PdfObjectIdentifier)
	/// Parsing a character encoding CMap stream.
	case encodingCMap(streamObject: PdfObjectIdentifier)
	/// Parsing the identified indirect object.
	case indirectObject(object: PdfObjectIdentifier)
	/// Parsing an object embedded in the identified object stream.
	case objectFromObjectStream(object: PdfObjectIdentifier, streamObject: PdfObjectIdentifier)
	/// Parsing the index header of the identified object stream.
	case objectStreamHeader(streamObject: PdfObjectIdentifier)
	/// Parsing the PDF header.
	case pdfHeader
	/// Parsing a direct PDF object without an enclosing source object.
	case pdfObject
	/// Scanning PDF structure when cross-reference data is unavailable.
	case pdfStructureScan
	/// Parsing the startxref and end-of-file markers.
	case startXrefAndEof
	/// Parsing a ToUnicode CMap stream.
	case toUnicodeCMap(streamObject: PdfObjectIdentifier)
}

extension PdfParseIntent {
	/// The object identifier that an indirect object header is expected to contain.
	var expectedIndirectObjectIdentifier: PdfObjectIdentifier? {
		switch self {
		case .indirectObject(let objectIdentifier):
			objectIdentifier
		case .contentOperatorStream, .crossReferenceSection, .crossReferenceStream, .encodingCMap, .objectFromObjectStream, .objectStreamHeader, .pdfHeader, .pdfObject, .pdfStructureScan, .startXrefAndEof, .toUnicodeCMap:
			nil
		}
	}

	/// The enclosing indirect object whose number and generation seed decryption.
	var enclosingObjectIdentifier: PdfObjectIdentifier? {
		switch self {
		case .indirectObject(let objectIdentifier):
			objectIdentifier
		case .contentOperatorStream, .crossReferenceSection, .crossReferenceStream, .encodingCMap, .objectFromObjectStream, .objectStreamHeader, .pdfHeader, .pdfObject, .pdfStructureScan, .startXrefAndEof, .toUnicodeCMap:
			nil
		}
	}
}

public struct PdfParseError: Error {
	public let failure: PdfParseFailure
	public var underlying: Error?
	public var range: Range<Int>?
	/// The higher-level parsing operation active when the error occurred.
	public var intent: PdfParseIntent?

	init(
		failure: PdfParseFailure,
		underlying: Error? = nil,
		range: Range<Int>? = nil,
		intent: PdfParseIntent? = nil
	) {
		self.failure = failure
		self.underlying = underlying
		self.range = range
		self.intent = intent
	}
}

extension PdfParseError: CustomNSError {
	public static var errorDomain: String { "CwlPdfLib.ParseError" }
	public var errorCode: Int {
		failure.rawValue
	}
	
	public var errorUserInfo: [String: Any] {
		var info: [String: Any] = [:]
		if let range {
			info["range"] = range
		}
		if let underlying {
			info["underlying"] = underlying
		}
		if let intent {
			info["intent"] = String(reflecting: intent)
		}
		return info
	}
}

extension PdfParseError {
	init(context: PdfParseContext, failure: PdfParseFailure) {
		self.init(
			failure: failure,
			range: (context.tokenStart ?? context.slice.startIndex)..<context.slice.startIndex,
			intent: context.intent
		)
	}
}
