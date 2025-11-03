// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	private let source: any PdfSource
	let header: PdfHeader
	let trailer: PdfDictionary
	let xrefTables: [PdfXRefTable]
	let byteRangeFromObjectOffset: [Int: PdfObjectByteRange]
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
		
		(self.xrefTables, self.trailer, self.byteRangeFromObjectOffset) = try PdfXRefTable.parseXrefTables(
			source: self.source,
			firstXrefRange: self.startXrefAndEof.range
		)
	}

	public func objectByteRange(for objectIdentifier: PdfObjectIdentifier) throws -> PdfObjectByteRange? {
		for table in xrefTables {
			guard let location = table.objectLocations[objectIdentifier] else { continue }
			guard let layout = byteRangeFromObjectOffset[location] else {
				throw PdfParseError(failure: .missingLayoutForObject, objectIdentifier: objectIdentifier, range: 0..<source.length)
			}
			return layout
		}
		return nil
	}
	
	public func object(range byteRange: PdfObjectByteRange) throws -> PdfObject {
		return try source.parseContext(range: byteRange.range) { context in
			context.objectIdentifier = byteRange.objectIdentifier
			return try PdfObject.parseIndirect(document: self, context: &context)
		}
	}
	
	public func object(for objectIdentifier: PdfObjectIdentifier) throws -> PdfObject? {
		guard let byteRange = try objectByteRange(for: objectIdentifier) else { return nil }
		return try object(range: byteRange)
	}
	
	public var allObjectByteRanges: [PdfObjectByteRange] {
		byteRangeFromObjectOffset.sorted { lhs, rhs in
			if lhs.value.objectIdentifier.number == rhs.value.objectIdentifier.number {
				return lhs.value.range.lowerBound < rhs.value.range.lowerBound
			}
			return lhs.value.objectIdentifier.number < rhs.value.objectIdentifier.number
		}.map { $0.value }
	}
}

