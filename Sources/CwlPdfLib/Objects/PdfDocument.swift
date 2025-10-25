// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	private let source: any PdfSource
	let header: PdfHeader
	let trailer: PdfDictionary
	let xrefTables: [PdfXRefTable]
	let objectLayouts: [Int: PdfObjectLayout]
	let startXrefAndEof: PdfStartXrefAndEof

	public init(source: any PdfSource) throws {
		self.source = source
		
		var buffer = PdfSourceBuffer()
		try self.source.seek(to: 0, buffer: &buffer)
		self.header = try self.source.parseContext(lineCount: 1, buffer: &buffer) { context in
			try PdfHeader.parse(context: &context)
		}
		
		try self.source.seek(to: self.source.length, buffer: &buffer)
		self.startXrefAndEof = try self.source.parseContext(lineCount: 3, reverse: true, buffer: &buffer) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		(self.xrefTables, self.trailer, self.objectLayouts) = try PdfXRefTable.parseXrefTables(
			source: self.source,
			firstXrefRange: self.startXrefAndEof.range
		)
	}

	public func layout(for objectNumber: PdfObjectNumber) throws -> PdfObjectLayout {
		for table in xrefTables {
			guard let location = table.objectLocations[objectNumber] else { continue }
			guard let layout = objectLayouts[location] else {
				throw PdfParseError(failure: .missingLayoutForObject, objectNumber: objectNumber, range: 0..<source.length)
			}
			return layout
		}
		throw PdfParseError(failure: .objectNotFount, objectNumber: objectNumber, range: 0..<source.length)
	}
	
	public func object(for layout: PdfObjectLayout) throws -> PdfObject {
		return try source.parseContext(range: layout.range) { context in
			try PdfObject.parse(context: &context)
		}
	}
	
	public func object(for objectNumber: PdfObjectNumber) throws -> PdfObject {
		return try object(for: layout(for: objectNumber))
	}
	
	public var allObjectLayouts: [PdfObjectLayout] {
		objectLayouts.sorted { lhs, rhs in
			if lhs.value.objectNumber.number == rhs.value.objectNumber.number {
				return lhs.value.range.lowerBound < rhs.value.range.lowerBound
			}
			return lhs.value.objectNumber.number < rhs.value.objectNumber.number
		}.map { $0.value }
	}
}

