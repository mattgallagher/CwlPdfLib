// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import PDFKit
import Testing

@testable import CwlPdfLib

struct PdfObjectParsingTests {
	@Test(arguments: [
		(
			"blank-page.pdf",
			PdfObjectNumber(number: 1, generation: 0),
			PdfObject.dictionary([
				"Type": PdfObject.name("Page"),
				"Parent": PdfObject.reference(PdfObjectNumber(number: 2, generation: 0)),
				"Contents": PdfObject.reference(PdfObjectNumber(number: 3, generation: 0)),
				"Resources": PdfObject.reference(PdfObjectNumber(number: 4, generation: 0)),
				"MediaBox": PdfObject.array(
					[
						PdfObject.integer(0),
						PdfObject.integer(0),
						PdfObject.real(595.2756),
						PdfObject.real(841.8898)
					]
				)
			])
		),
		(
			"blank-page.pdf",
			PdfObjectNumber(number: 3, generation: 0),
			PdfObject.stream(PdfStream(dictionary: [
				"Filter": PdfObject.name("FlateDecode"),
				"Length": PdfObject.integer(11),
			], data: Data("q Q".utf8)))
		),
		(
			"blank-page.pdf",
			PdfObjectNumber(number: 6, generation: 0),
			PdfObject.dictionary([
				"Title": PdfObject.string("Untitled".pdfData()),
				"Producer": PdfObject.string("macOS Version 15.4.1 (Build 24E263) Quartz PDFContext".pdfData()),
				"Creator": PdfObject.string("TextEdit".pdfData()),
				"CreationDate": PdfObject.string("D:20250515100510Z00'00'".pdfData()),
				"ModDate": PdfObject.string("D:20250515100510Z00'00'".pdfData())
			])
		)
	])
	func `GIVEN a pdf file WHEN PdfDocument.object THEN object parsed`(filename: String, objectNumber: PdfObjectNumber, matches: PdfObject) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		let object = try document.object(for: objectNumber)
		
		#expect(object == matches)
	}
}
