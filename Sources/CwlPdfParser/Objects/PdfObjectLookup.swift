// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectLookup: Sendable {
	let source: any PdfSource
	let xrefTables: [PdfXRefTable]
	let objectLayoutFromOffset: [Int: PdfObjectLayout]

	/// Decryption handler for encrypted documents. Set after initialization when encryption is detected.
	var decryption: PdfDecryption?
	
	public func objectLayout(for objectIdentifier: PdfObjectIdentifier) throws -> PdfObjectLayout? {
		for table in xrefTables {
			guard let location = table.objectLocations[objectIdentifier] else { continue }
			guard let layout = objectLayoutFromOffset[location] else {
				throw PdfParseError(failure: .missingLayoutForObject, objectIdentifier: objectIdentifier, range: 0..<source.length)
			}
			return layout
		}
		return nil
	}
	
	public func object(layout: PdfObjectLayout) throws -> PdfObject {
		return try source.parseContext(range: layout.range) { context in
			context.objectIdentifier = layout.objectIdentifier
			return try PdfObject.parseIndirect(lookup: self, context: &context)
		}
	}
	
	public func object(for objectIdentifier: PdfObjectIdentifier) throws -> PdfObject? {
		guard let layout = try objectLayout(for: objectIdentifier) else { return nil }
		return try object(layout: layout)
	}
	
	public var allObjectByteRanges: [PdfObjectLayout] {
		objectLayoutFromOffset.sorted { lhs, rhs in
			if lhs.value.objectIdentifier.number == rhs.value.objectIdentifier.number {
				return lhs.value.range.lowerBound < rhs.value.range.lowerBound
			}
			return lhs.value.objectIdentifier.number < rhs.value.objectIdentifier.number
		}.map { $0.value }
	}
}
