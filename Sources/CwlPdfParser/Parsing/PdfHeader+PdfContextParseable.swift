// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

extension PdfHeader: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfHeader {
		context.skipComments = false
		guard case .comment(let range) = try PdfToken.parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .headerNotFound)
		}
		context.slice = context.slice[reslice: range]
		guard case .identifier(let range) = try PdfToken.parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .headerNotFound)
		}
		let split = context.pdfText(range: range).split(separator: "-")
		guard split.count == 2, let type = split.first, let version = split.dropFirst().first else {
			throw PdfParseError(context: context, failure: .headerNotFound)
		}
		return PdfHeader(type: String(type), version: String(version))
	}
}
