// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

extension PdfStartXrefAndEof: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfStartXrefAndEof {
		let endXref = context.slice.startIndex
		
		try PdfToken
			.parse(context: &context)
			.requireIdentifier(context: &context, equals: .startxref, else: .startXrefNotFound)
		
		let startXref = try PdfToken
			.parse(context: &context)
			.requireNaturalNumber(context: &context)

		context.skipComments = false
		
		guard
			case .comment(let range) = try PdfToken.parse(context: &context),
			context.slice[reslice: range].starts(with: "%EOF".utf8)
		else {
			throw PdfParseError(context: context, failure: .eofMarkerNotFound)
		}
		
		return PdfStartXrefAndEof(range: startXref..<endXref)
	}
}
