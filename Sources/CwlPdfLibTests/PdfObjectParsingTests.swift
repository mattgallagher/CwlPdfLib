// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

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
				PdfObject.stream(PdfStream(
					objectIdentifier: PdfObjectIdentifier(number: 3, generation: 0),
					dictionary: [
						"Filter": .name("FlateDecode"),
						"Length": .integer(11)
					],
					data: Data("q Q".utf8))
				)
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
					"Title": .string("Untitled".toPdfText()),
					"Producer": .string("macOS Version 15.4.1 (Build 24E263) Quartz PDFContext".toPdfText()),
					"Creator": .string("TextEdit".toPdfText()),
					"CreationDate": .string("D:20250515100510Z00'00'".toPdfText()),
					"ModDate": .string("D:20250515100510Z00'00'".toPdfText())
				])
			)
		]
	)
	func `GIVEN a pdf file WHEN PdfDocument.objects.object THEN object parsed`(filename: String, objectIdentifier: PdfObjectIdentifier, matches: PdfObject) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		let object = try document.lookup.object(for: objectIdentifier)
		
		#expect(object == matches)
	}

	@Test
	func `GIVEN an object lookup WHEN an object is requested THEN object is cached in shared mutable state`() throws {
		let document = try basicFixtureDocument(filename: "blank-page.pdf")
		let objectIdentifier = PdfObjectIdentifier(number: 6, generation: 0)
		let lookupCopy = document.lookup

		let object = try document.lookup.object(for: objectIdentifier)

		#expect(document.lookup.mutableState.cachedObject(for: objectIdentifier) == object)
		#expect(lookupCopy.mutableState.cachedObject(for: objectIdentifier) == object)
		document.lookup.mutableState.cache(.null, for: objectIdentifier)
		#expect(try lookupCopy.object(for: objectIdentifier) == .null)
		#expect(!document.lookup.mutableState.isChanged(for: objectIdentifier))
	}
	
	@Test
	func `GIVEN a null token WHEN PdfObject.parse THEN null object returned`() throws {
		let data = Data("null".utf8)
		let object = try data.parseContext(intent: .pdfObject) { context in
			try PdfObject.parse(context: &context)
		}
		
		#expect(object == .null)
	}

	@Test
	func `GIVEN parse intents WHEN object identifiers requested THEN identifiers match their semantic role`() {
		let objectIdentifier = PdfObjectIdentifier(number: 10, generation: 2)
		let streamIdentifier = PdfObjectIdentifier(number: 20, generation: 0)
		let indirectObject = PdfParseIntent.indirectObject(object: objectIdentifier)
		let objectStreamObject = PdfParseIntent.objectFromObjectStream(
			object: objectIdentifier,
			streamObject: streamIdentifier
		)

		#expect(indirectObject.expectedIndirectObjectIdentifier == objectIdentifier)
		#expect(indirectObject.enclosingObjectIdentifier == objectIdentifier)
		#expect(objectStreamObject.expectedIndirectObjectIdentifier == nil)
		#expect(objectStreamObject.enclosingObjectIdentifier == nil)
		#expect(PdfParseIntent.contentOperatorStream(streamObject: streamIdentifier).enclosingObjectIdentifier == nil)
	}
}
