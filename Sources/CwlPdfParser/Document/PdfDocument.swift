// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDocument: Sendable {
	public let lookup: PdfObjectLookup
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
		self.lookup = PdfObjectLookup(source: source, xrefTables: xrefTables, objectLayoutFromOffset: objectLayoutFromOffset)
		
		guard let catalog = trailer[.Root]?.dictionary(lookup: lookup) else {
			throw PdfParseError(failure: .expectedCatalog)
		}

		guard let pageTreeRoot = catalog[.Pages]?.dictionary(lookup: lookup) else {
			throw PdfParseError(failure: .expectedPageTree)
		}
		
		self.pages = try allPages(pageTree: pageTreeRoot, lookup: lookup, offset: 0)
	}
	
	public func page(for objectLayout: PdfObjectLayout) -> PdfPage? {
		pages.first(where: { $0.objectLayout == objectLayout })
	}
}

func allPages(pageTree: PdfDictionary, lookup: PdfObjectLookup, offset: Int) throws -> [PdfPage] {
	guard let kids = pageTree[.Kids]?.array(lookup: lookup) else {
		throw PdfParseError(failure: .expectedArray)
	}
	
	// Default to standard US Letter size if no default dimensions found
	let cropBox =
		(
			pageTree[.CropBox]?.array(lookup: lookup) ??
			pageTree[.MediaBox]?.array(lookup: lookup)
		).flatMap {
			PdfRect(array: $0, lookup: lookup)
		} ?? PdfRect(x: 0, y: 0, width: 612, height: 792)
	
	var pages = [PdfPage]()
	for kid in kids {
		guard case .reference(let objectIdentifier) = kid else {
			throw PdfParseError(failure: .expectedIndirectObject)
		}
		guard let dictionary = kid.dictionary(lookup: lookup) else {
			throw PdfParseError(failure: .expectedDictionary)
		}
		guard let type = dictionary[.Type]?.name(lookup: lookup) else {
			throw PdfParseError(failure: .expectedType)
		}
		switch type {
		case .Page:
			if let objectLayout = try lookup.objectLayout(for: objectIdentifier) {
				pages
					.append(
						PdfPage(
							pageIndex: pages.count + offset,
							objectLayout: objectLayout,
							pageDictionary: dictionary,
							documentPageSize: cropBox
						)
					)
			}
		case .Pages:
			try pages.append(contentsOf: allPages(pageTree: dictionary, lookup: lookup, offset: pages.count + offset))
		default:
			throw PdfParseError(failure: .expectedPageTree)
		}
	}
	
	return pages
}
