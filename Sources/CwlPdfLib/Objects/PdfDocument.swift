// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	private var source: any PdfSource
	let header: PdfHeader
	let trailer: PdfDictionary
	let xrefTables: [PdfXRefTable]
	let objectEnds: [Int: Int]
	let startXrefAndEof: PdfStartXrefAndEof

	public init(source: any PdfSource) throws {
		self.source = source
		
		try self.source.seek(to: 0)
		self.header = try self.source.parseContext(lineCount: 1) { context in
			try PdfHeader.parse(context: &context)
		}
		
		try self.source.seek(to: self.source.length)
		self.startXrefAndEof = try self.source.parseContext(lineCount: 3, reverse: true) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		(self.xrefTables, self.trailer, self.objectEnds) = try PdfXRefTable.parseXrefTables(
			source: &self.source,
			firstXrefRange: self.startXrefAndEof.range
		)
	}
}

