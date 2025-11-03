// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import PDFKit
import Testing

@testable import CwlPdfLib

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
					"Length": .integer(11),
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
	func `GIVEN a pdf file WHEN PdfDocument.object THEN object parsed`(filename: String, objectIdentifier: PdfObjectIdentifier, matches: PdfObject) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		
		let object = try document.object(for: objectIdentifier)
		
		#expect(object == matches)
	}
}

extension PdfObject: Equatable {
	public static func == (lhs: PdfObject, rhs: PdfObject) -> Bool {
		switch (lhs, rhs) {
		case (.array(let lhs), .array(let rhs)): lhs == rhs
		case (.boolean(let lhs), .boolean(let rhs)): lhs == rhs
		case (.dictionary(let lhs), .dictionary(let rhs)): lhs == rhs
		case (.identifier(let lhs), .identifier(let rhs)): lhs == rhs
		case (.integer(let lhs), .integer(let rhs)): lhs == rhs
		case (.name(let lhs), .name(let rhs)): lhs == rhs
		case (.null, .null): true
		case (.real(let lhs), .real(let rhs)): abs(lhs - rhs) < realPrecision
		case (.reference(let lhs), .reference(let rhs)): lhs == rhs
		case (.stream(let lhs), .stream(let rhs)): lhs == rhs
		case (.string(let lhs, let lhsHex), .string(let rhs, let rhsHex)): lhs == rhs && lhsHex == rhsHex
		default: false
		}
	}
	
	public static let realPrecision = 0.5e-5
}

extension PdfStream: Equatable {
	public static func == (lhs: PdfStream, rhs: PdfStream) -> Bool {
		return lhs.dictionary == rhs.dictionary && lhs.data == rhs.data
	}
}
