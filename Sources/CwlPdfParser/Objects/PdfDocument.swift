// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	private var source: any PdfSource
	private let header: PdfHeader
	private let xrefTable: PdfXRefTable
	private let previousTables: [PdfXRefTable]
	private let startXrefAndEof: PdfStartXrefAndEof

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
		self.xrefTable = try self.source.parseContext(range: startXrefAndEof.range) { context in
			try PdfXRefTable.parse(context: &context)
		}
		self.previousTables = []
	}
}

