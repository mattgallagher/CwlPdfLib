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
			firstXrefRange: self.startXrefAndEof.range
		)

		self.trailer = trailer
		self.objects = PdfObjectList(source: source, xrefTables: xrefTables, objectLayoutFromOffset: objectLayoutFromOffset)
		
		guard let catalog = try trailer[.Root]?.dictionary(objects: objects) else {
			throw PdfParseError(failure: .expectedCatalog)
		}

		guard let pageTreeRoot = try catalog[.Pages]?.dictionary(objects: objects) else {
			throw PdfParseError(failure: .expectedPageTree)
		}
		
		self.pages = try allPages(pageTree: pageTreeRoot, objects: objects)
	}
}

func allPages(pageTree: PdfDictionary, objects: PdfObjectList) throws -> [PdfPage] {
	guard let kids = try pageTree[.Kids]?.array(objects: objects) else {
		throw PdfParseError(failure: .expectedArray)
	}
	
	var pages = [PdfPage]()
	for (index, kid) in kids.enumerated() {
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
			pages.append(PdfPage(pageIndex: index, objectIdentifier: objectIdentifier, pageDictionary: dictionary))
		case .Pages:
			pages.append(contentsOf: try allPages(pageTree: dictionary, objects: objects))
		default:
			throw PdfParseError(failure: .expectedPageTree)
		}
	}
	
	return pages
}
