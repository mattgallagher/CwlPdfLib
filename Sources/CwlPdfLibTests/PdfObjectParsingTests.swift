// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfObjectParsingTests {
	@Test(
		arguments: [
			(
				"blank-page.pdf",
				PdfObjectIdentifier(number: 1, generation: 0),
				PdfObject.dictionary([
					"Type": .name("Page"),
					"Parent": .reference(PdfObjectIdentifier(number: 2, generation: 0)),
					"Contents": .reference(PdfObjectIdentifier(number: 3, generation: 0)),
					"Resources": .reference(PdfObjectIdentifier(number: 4, generation: 0)),
					"MediaBox": .array(
						[
							.integer(0),
							.integer(0),
							.real(595.2756),
							.real(841.8898)
						]
					)
				])
			),
			(
				"blank-page.pdf",
				PdfObjectIdentifier(number: 2, generation: 0),
				PdfObject.dictionary([
					"MediaBox": .array([.integer(0), .integer(0), .real(595.2756), .real(841.8898)]),
					"Kids": .array([.reference(PdfObjectIdentifier(number: 1, generation: 0))]),
					"Count": .integer(1),
					"Type": .name("Pages")
				])
			),
			(
				"blank-page.pdf",
				PdfObjectIdentifier(number: 3, generation: 0),
				PdfObject.stream(PdfStream(dictionary: [
					"Filter": .name("FlateDecode"),
					"Length": .integer(11)
				], data: Data("q Q".utf8)))
			),
			(
				"blank-page.pdf",
				PdfObjectIdentifier(number: 4, generation: 0),
				PdfObject.dictionary([
					"ProcSet": .array([.name("PDF")])
				])
			),
			(
				"blank-page.pdf",
				PdfObjectIdentifier(number: 5, generation: 0),
				PdfObject.dictionary([
					"Pages": .reference(PdfObjectIdentifier(number: 2, generation: 0)),
					"Type": .name("Catalog")
				])
			),
			(
				"blank-page.pdf",
				PdfObjectIdentifier(number: 6, generation: 0),
				PdfObject.dictionary([
					"Title": .string("Untitled".pdfData()),
					"Producer": .string("macOS Version 15.4.1 (Build 24E263) Quartz PDFContext".pdfData()),
					"Creator": .string("TextEdit".pdfData()),
					"CreationDate": .string("D:20250515100510Z00'00'".pdfData()),
					"ModDate": .string("D:20250515100510Z00'00'".pdfData())
				])
			)
		]
	)
	func `GIVEN a pdf file WHEN PdfDocument.objects.object THEN object parsed`(filename: String, objectIdentifier: PdfObjectIdentifier, matches: PdfObject) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		let object = try document.objects.object(for: objectIdentifier)
		
		#expect(object == matches)
	}
}
