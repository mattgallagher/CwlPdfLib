// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	private var source: any PdfSource
	let header: PdfHeader
	let trailer: PdfDictionary
	let xrefTables: [PdfXRefTable]
	let objectEnds: [Int: Int]

	public init(source: any PdfSource) throws {
		self.source = source
		
		try self.source.seek(to: 0)
		self.header = try self.source.parseContext(lineCount: 1) { context in
			try PdfHeader.parse(context: &context)
		}
		try self.source.seek(to: self.source.length)
		let startXrefAndEof = try self.source.parseContext(lineCount: 3, reverse: true) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		var startOfXrefTableContainingLastObject: Int?
		var xrefTables = [PdfXRefTable]()
		var nextRange = startXrefAndEof.range
		repeat {
			let nextTable = try self.source.parseContext(range: nextRange) { context in
				try PdfXRefTable.parse(context: &context)
			}
			xrefTables.append(nextTable)
			if startOfXrefTableContainingLastObject == nil, !nextTable.objectLocations.isEmpty {
				startOfXrefTableContainingLastObject = nextRange.lowerBound
			}
			guard case .integer(let previousStart) = nextTable.trailer["Prev"] else {
				break
			}
			nextRange = previousStart..<nextRange.startIndex
		} while true
		guard let trailer = xrefTables.first?.trailer else {
			throw PdfParseError(failure: .xrefNotFound, range: startXrefAndEof.range)
		}
		self.trailer = trailer
		self.xrefTables = xrefTables
		
		var objectEnds = [Int: Int]()
		if let startOfXrefTableContainingLastObject {
			let allObjectRanges = xrefTables.flatMap { $0.objectLocations.values }.sorted()
			for (offset, (previous, next)) in zip(allObjectRanges, [allObjectRanges.dropFirst(), [startOfXrefTableContainingLastObject]].joined()).enumerated() {
				objectEnds[previous] = next
			}
		}
		self.objectEnds = objectEnds
	}
}

