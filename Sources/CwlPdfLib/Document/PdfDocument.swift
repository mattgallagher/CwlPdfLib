// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	public let objects: PdfObjectList
	public let pages: [PdfPage]

	let header: PdfHeader
	let startXrefAndEof: PdfStartXrefAndEof
	let trailer: PdfDictionary

	public init(source: any PdfSource) throws {
		var buffer = PdfSourceBuffer()
		try source.seek(to: 0, buffer: &buffer)
		self.header = try source.parseContext(lineCount: 1, buffer: &buffer) { context in
			try PdfHeader.parse(context: &context)
		}
		
		try source.seek(to: source.length, buffer: &buffer)
		self.startXrefAndEof = try source.parseContext(lineCount: 3, reverse: true, buffer: &buffer) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		let (xrefTables, trailer, objectLayoutFromOffset) = try PdfXRefTable.parseXrefTables(
			source: source,
			firstXrefRange: startXrefAndEof.range
		)

		self.trailer = trailer
		self.objects = PdfObjectList(source: source, xrefTables: xrefTables, objectLayoutFromOffset: objectLayoutFromOffset)
		
		guard let catalog = try trailer[.Root]?.dictionary(objects: objects) else {
			throw PdfParseError(failure: .expectedCatalog)
		}

		guard let pageTreeRoot = try catalog[.Pages]?.dictionary(objects: objects) else {
			throw PdfParseError(failure: .expectedPageTree)
		}
		
		self.pages = try allPages(pageTree: pageTreeRoot, objects: objects, offset: 0)
	}
	
	public func page(for objectLayout: PdfObjectLayout) -> PdfPage? {
		return pages.first(where: { $0.objectLayout == objectLayout })
	}
}

func allPages(pageTree: PdfDictionary, objects: PdfObjectList, offset: Int) throws -> [PdfPage] {
	guard let kids = try pageTree[.Kids]?.array(objects: objects) else {
		throw PdfParseError(failure: .expectedArray)
	}
	
	var pages = [PdfPage]()
	for kid in kids {
		guard case .reference(let objectIdentifier) = kid else {
			throw PdfParseError(failure: .expectedIndirectObject)
		}
		guard let dictionary = try? kid.dictionary(objects: objects) else {
			throw PdfParseError(failure: .expectedDictionary)
		}
		guard let type = try? dictionary[.Type]?.name(objects: objects) else {
			throw PdfParseError(failure: .expectedType)
		}
		switch type {
		case .Page:
			if let objectLayout = try objects.objectLayout(for: objectIdentifier) {
				pages.append(PdfPage(pageIndex: pages.count + offset, objectLayout: objectLayout, pageDictionary: dictionary))
			}
		case .Pages:
			try pages.append(contentsOf: allPages(pageTree: dictionary, objects: objects, offset: pages.count + offset))
		default:
			throw PdfParseError(failure: .expectedPageTree)
		}
	}
	
	return pages
}
