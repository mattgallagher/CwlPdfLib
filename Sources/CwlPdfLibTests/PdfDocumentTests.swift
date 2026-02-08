// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfDocumentTests {
	@Test(arguments: [
		"blank-page.pdf",
		"single-text-line.pdf"
	])
	func `GIVEN a pdf file seeked to 0 WHEN PdfHeader.parse over a parseContext of lineCount 1 THEN pdf and version number extracted`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		var buffer = PdfSourceBuffer()
		try dataSource.seek(to: 0, buffer: &buffer)
		
		let header = try dataSource.parseContext(lineCount: 1, buffer: &buffer) { context in
			try PdfHeader.parse(context: &context)
		}
		
		#expect(header.type == "PDF")
		#expect(header.version == "1.3")
	}
	
	@Test(arguments: [
		("blank-page.pdf", 601..<874),
		("single-text-line.pdf", 10450..<10826)
	])
	func `GIVEN a pdf file seeked to end and an xref table range WHEN PdfStartXrefAndEof.parse over a reverse parseContext of lineCount 3 THEN matching xref table range extracted`(filename: String, range: Range<Int>) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		var buffer = PdfSourceBuffer()
		try dataSource.seek(to: dataSource.length, buffer: &buffer)
		
		let xref = try dataSource.parseContext(lineCount: 3, reverse: true, buffer: &buffer) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		#expect(xref.range == range)
	}
	
	@Test(arguments: [
		("blank-page.pdf", 601..<874),
		("single-text-line.pdf", 10450..<10826)
	])
	func `GIVEN a pdf file and appropriate range WHEN PdfXRefTable.parse over that range THEN xref table extracted`(filename: String, range: Range<Int>) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		
		let xrefTable = try dataSource.parseContext(range: range) { context in
			try PdfXRefTable.parse(context: &context)
		}
		
		#expect(!xrefTable.trailer.isEmpty)
		#expect(!xrefTable.trailer.isEmpty)
	}
	
	@Test
	func `GIVEN a pdf file with multiple xref tables WHEN PdfDocument.init THEN xref tables extracted, all objects extracted and size is max objNum plus one`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/three-page-images-annots.pdf", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		#expect(document.lookup.xrefTables.count == 2)
		#expect(document.lookup.objectLayoutFromOffset.count == 105)
		
		var size = 0
		if case .integer(let value) = document.trailer["Size"] {
			size = value
		}
		#expect(size == (document.lookup.xrefTables.flatMap { $0.objectLocations.keys.map { $0.number } }.max() ?? 0) + 1)
	}
	
	@Test
	func `GIVEN a pdf and a low initial xref table limit WHEN xref tables read THEN retries with larger reads succeed`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/three-page-images-annots.pdf", withExtension: nil))
		
		let source = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		var buffer = PdfSourceBuffer()
		try source.seek(to: source.length, buffer: &buffer)
		let startXrefAndEof = try source.parseContext(lineCount: 3, reverse: true, buffer: &buffer) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		let (xrefTables, trailer, objectLayoutFromOffset, _) = try PdfXRefTable.parseXrefTables(
			source: source,
			firstXrefRange: startXrefAndEof.range,
			initialXrefTableLimit: 20
		)
		
		#expect(xrefTables.count == 2)
		#expect(objectLayoutFromOffset.count == 105)
		#expect(trailer.count == 6)
	}
	
	@Test(arguments: [
		("blank-page.pdf", [
			"ID": PdfObject.array([.string(Data(hexString: "edb254fca2ae46d92dad520df17ccad1")!), .string(Data(hexString: "edb254fca2ae46d92dad520df17ccad1")!)]),
			"Info": PdfObject.reference(PdfObjectIdentifier(number: 6, generation: 0)),
			"Root": PdfObject.reference(PdfObjectIdentifier(number: 5, generation: 0)),
			"Size": PdfObject.integer(7)
		]),
		("single-text-line.pdf", [
			"ID": PdfObject.array([.string(Data(hexString: "5571570d6c27c2b8042a720ce493221a")!), .string(Data(hexString: "5571570d6c27c2b8042a720ce493221a")!)]),
			"Info": PdfObject.reference(PdfObjectIdentifier(number: 11, generation: 0)),
			"Root": PdfObject.reference(PdfObjectIdentifier(number: 8, generation: 0)),
			"Size": PdfObject.integer(12)
		])
	])
	func `GIVEN a pdf file WHEN PdfDocument.init THEN trailer parsed`(filename: String, trailer: PdfDictionary) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		#expect(document.trailer == trailer)
	}
	
	@Test(arguments: [
		"smallest-possible-pdf-1.5.pdf",
		"smallest-possible-pdf-1.5-xrefstm-only.pdf"
	])
	func `GIVEN a pdf with xref stream WHEN PdfDocument.init THEN document loads`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		#expect(!document.pages.isEmpty)
		#expect(document.trailer[.Root] != nil)
	}
	
	@Test(arguments: [
		"smallest-possible-pdf-2.0-stms.pdf",
		"smallest-possible-pdf-2.0-stms-flate.pdf"
	])
	func `GIVEN a pdf with object streams WHEN xref tables parsed THEN object stream layouts tracked`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let source = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		var buffer = PdfSourceBuffer()
		try source.seek(to: source.length, buffer: &buffer)
		let startXrefAndEof = try source.parseContext(lineCount: 3, reverse: true, buffer: &buffer) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		let (xrefTables, _, _, objectStreamLayouts) = try PdfXRefTable.parseXrefTables(
			source: source,
			firstXrefRange: startXrefAndEof.range
		)
		let expectedObjectStreamCount = xrefTables.reduce(0) { total, table in
			total + table.objectStreamLocations.count
		}
		#expect(objectStreamLayouts.count == expectedObjectStreamCount)
	}
	
	@Test(arguments: [
		("single-text-line-encrypted-ownerpw-pdf.pdf", nil),
		("single-text-line-encrypted-ownerpw-pdf.pdf", "pdf")
	])
	func `GIVEN an owner password protected pdf WHEN PdfDocument.init THEN content stream decrypted`(filename: String, password: String?) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let document = try PdfDocument(
			source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)),
			password: password
		)
		let operators = try parseContentOperators(document: document)
		#expect(containsTextLine(operators: operators, text: "This is some basic text"))
	}
	
	@Test
	func `GIVEN a user password protected pdf WHEN PdfDocument.init THEN content stream decrypted`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/single-text-line-pw-pdf.pdf", withExtension: nil))
		let document = try PdfDocument(
			source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)),
			password: "pdf"
		)
		let operators = try parseContentOperators(document: document)
		
		#expect(containsTextLine(operators: operators, text: "This is some basic text"))
	}
	
	@Test(arguments: [
		"notrailer-xref.pdf",
		"noxref-trailer.pdf",
		"smallest-possible-pdf-1.0.pdf",
		"smallest-possible-pdf-1.5-flate.pdf",
		"smallest-possible-pdf-2.0.pdf"
	])
	func `GIVEN a tiny pdf WHEN PdfDocument.init THEN page 1 media box can be read`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let document = try PdfDocument(
			source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		)
		let pageRect = document.pages.first?.pageRect(lookup: document.lookup)
		
		#expect((pageRect?.width ?? 0) > 0)
		#expect((pageRect?.height ?? 0) > 0)
	}
}

private func parseContentOperators(document: PdfDocument) throws -> [PdfOperator] {
	let page = try #require(document.pages.first)
	let contentStream = try #require(page.contentStreams(lookup: document.lookup).first)
	var parsed = [PdfOperator]()
	try contentStream.parse { op in
		parsed.append(op)
		return true
	}
	return parsed
}

private func containsTextLine(operators: [PdfOperator], text: String) -> Bool {
	for op in operators {
		switch op {
		case .Tj(let data):
			if data.pdfTextToString() == text {
				return true
			}
		case .TJ(let elements):
			let combined = elements.compactMap { element -> String? in
				if case .text(let data) = element {
					return data.pdfTextToString()
				}
				return nil
			}.joined()
			if combined.contains(text) {
				return true
			}
		default:
			break
		}
	}
	return false
}

private extension Data {
	init?(hexString: String) {
		var high: UInt8?
		var result = Data()
		for character in hexString.utf8 {
			guard let nybble = nybbleFromHex(character) else { return nil }
			if let highNybble = high {
				result.append((highNybble << 4) + nybble)
				high = nil
			} else {
				high = nybble
			}
		}
		self = result
	}
}
