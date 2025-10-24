// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfDocumentTests {
	@Test(arguments: [
		"blank-page.pdf",
		"single-text-line.pdf"
	])
	func `GIVEN a pdf file seeked to 0 WHEN PdfHeader.parse over a parseContext of lineCount 1 THEN pdf and version number extracted`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		var dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		try dataSource.seek(to: 0)
		
		let header = try dataSource.parseContext(lineCount: 1) { context in
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
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		var dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		try dataSource.seek(to: dataSource.length)
		
		let xref = try dataSource.parseContext(lineCount: 3, reverse: true) { context in
			try PdfStartXrefAndEof.parse(context: &context)
		}
		
		#expect(xref.range == range)
	}
	
	@Test(arguments: [
		("blank-page.pdf", 601..<874),
		("single-text-line.pdf", 10450..<10826)
	])
	func `GIVEN a pdf file and appropriate range WHEN PdfXRefTable.parse over that range THEN xref table extracted`(filename: String, range: Range<Int>) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		var dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		try dataSource.seek(to: dataSource.length)
		
		let xrefTable = try dataSource.parseContext(range: range) { context in
			try PdfXRefTable.parse(context: &context)
		}
		
		#expect(!xrefTable.trailer.isEmpty)
		#expect(!xrefTable.trailer.isEmpty)
	}
	
	@Test(arguments: [
		"three-page-images-annots.pdf",
	])
	func `GIVEN a pdf file with multiple xref tabls WHEN PdfDocument.init THEN xref tables extracted, object ends calculated and size is max objNum plus one`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		#expect(document.xrefTables.count == 2)
		#expect(document.objectEnds.count == 105)
		
		var size = 0
		if case .integer(let value) = document.trailer["Size"] {
			size = value
		}
		#expect(size == (document.xrefTables.flatMap { $0.objectLocations.keys.map { $0.number } }.max() ?? 0) + 1)
	}
}
