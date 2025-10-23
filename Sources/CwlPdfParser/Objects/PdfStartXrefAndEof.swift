// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfStartXrefAndEof: Sendable {
	let range: Range<Int>
}

extension PdfStartXrefAndEof: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfStartXrefAndEof {
		let endXref = context.slice.startIndex
		
		try context.nextToken()
		try context.identifier(equals: .startxref, else: .startXrefNotFound)
		
		try context.nextToken()
		let startXref = try context.naturalNumber()

		try context.nextToken()
		guard
			case .comment(let range) = context.token,
			context.slice[reslice: range].starts(with: [.percent, .E, .O, .F])
		else {
			throw PdfParseError(context: context, failure: .eofMarkerNotFound)
		}
		
		return PdfStartXrefAndEof(range: startXref..<endXref)
	}
}
