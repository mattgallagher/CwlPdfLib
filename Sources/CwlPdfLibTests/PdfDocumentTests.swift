// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfLib

struct PdfDocumentTests {
	@Test(arguments: [
		"blank-page.pdf",
		"single-text-line.pdf"
	])
	func `GIVEN a pdf file seeked to 0 WHEN PdfHeader.parse over a parseContext of lineCount 1 THEN pdf and version number extracted`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
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
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
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
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		let dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		
		let xrefTable = try dataSource.parseContext(range: range) { context in
			try PdfXRefTable.parse(context: &context)
		}
		
		#expect(!xrefTable.trailer.isEmpty)
		#expect(!xrefTable.trailer.isEmpty)
	}
	
	@Test
	func `GIVEN a pdf file with multiple xref tables WHEN PdfDocument.init THEN xref tables extracted, object ends calculated and size is max objNum plus one`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/three-page-images-annots.pdf", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		#expect(document.xrefTables.count == 2)
		#expect(document.objectLayouts.count == 105)
		
		var size = 0
		if case .integer(let value) = document.trailer["Size"] {
			size = value
		}
		#expect(size == (document.xrefTables.flatMap { $0.objectLocations.keys.map { $0.number } }.max() ?? 0) + 1)
	}
	
	@Test(arguments: [
		("blank-page.pdf", [
			"ID": PdfObject.array([.string(Data(hexString: "edb254fca2ae46d92dad520df17ccad1")!, hex: true), .string(Data(hexString: "edb254fca2ae46d92dad520df17ccad1")!, hex: true)]),
			"Info": PdfObject.reference(PdfObjectNumber(number: 6, generation: 0)),
			"Root": PdfObject.reference(PdfObjectNumber(number: 5, generation: 0)),
			"Size": PdfObject.integer(7)
		]),
		("single-text-line.pdf", [
			"ID": PdfObject.array([.string(Data(hexString: "5571570d6c27c2b8042a720ce493221a")!, hex: true), .string(Data(hexString: "5571570d6c27c2b8042a720ce493221a")!, hex: true)]),
			"Info": PdfObject.reference(PdfObjectNumber(number: 11, generation: 0)),
			"Root": PdfObject.reference(PdfObjectNumber(number: 8, generation: 0)),
			"Size": PdfObject.integer(12)
		])
	])
	func `GIVEN a pdf file WHEN PdfDocument.init THEN trailer parsed`(filename: String, trailer: PdfDictionary) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		#expect(document.trailer == trailer)
	}
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
