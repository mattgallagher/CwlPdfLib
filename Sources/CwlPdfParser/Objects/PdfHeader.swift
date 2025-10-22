// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfHeader: Sendable {
	public let type: String
	public let version: String

	init(type: String, version: String) {
		self.type = type
		self.version = version
	}
}

extension PdfHeader: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfHeader {
		try context.nextToken()
		guard case .comment(let range) = context.token else {
			throw PdfParseError(context: context, failure: .headerNotFound)
		}
		var commentContext = PdfParseContext(slice: context.slice[reslice: range])
		try commentContext.nextToken()
		guard case .comment(let range) = commentContext.token else {
			throw PdfParseError(context: commentContext, failure: .headerNotFound)
		}
		let split = commentContext.pdfText(range: range).split(separator: "-")
		guard split.count == 2, let type = split.first, let version = split.dropFirst().first else {
			throw PdfParseError(context: commentContext, failure: .headerNotFound)
		}
		return PdfHeader(type: String(type), version: String(version))
	}
}
