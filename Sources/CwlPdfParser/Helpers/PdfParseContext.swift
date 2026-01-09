// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

struct PdfParseContext {
	var slice: OffsetSlice<UnsafeRawBufferPointer>
	var objectIdentifier: PdfObjectIdentifier?
	var skipComments = true
	var errorIfEndOfRange = false
	var tokenStart: Int?
}

protocol PdfContextParseable: Sendable {
	static func parse(context: inout PdfParseContext) throws -> Self
}

protocol PdfContextOptionalParseable: PdfContextParseable {
	static func parseNext(context: inout PdfParseContext) throws -> Self?
}

extension PdfContextOptionalParseable {
	static func parse(context: inout PdfParseContext) throws -> Self {
		guard let result = try parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .endOfRange)
		}
		return result
	}
}

extension PdfParseContext {
	func pdfText(range: Range<Int>) -> String {
		slice[reslice: range].pdfTextToString()
	}
	
	func data(range: Range<Int>) -> Data {
		Data(slice[reslice: range])
	}
	
	mutating func readEndOfLine() throws {
		if slice.first == .carriageReturn {
			slice = slice.dropFirst()
		}
		if slice.first == .lineFeed {
			slice = slice.dropFirst()
		}
	}
	
	mutating func skip(count: Int) throws {
		slice = slice.dropFirst(count)
	}
}
