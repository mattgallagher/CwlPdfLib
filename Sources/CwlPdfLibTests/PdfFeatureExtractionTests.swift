// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser
import CwlPdfRenderer
import Foundation
import Testing

struct PdfFeatureExtractionTests {
	@Test
	func `GIVEN page annotations WHEN extracting annotations only THEN only annotation features are returned`() throws {
		let document = try fixtureDocument(filename: "three-page-images-annots.pdf")
		let page = try #require(document.pages.first)

		let features = page.extract(features: .annotations, lookup: document.lookup)
		#expect(!features.isEmpty)

		for feature in features {
			if case .annotation = feature.payload {
				#expect(feature.matrix.a == 1)
				#expect(feature.matrix.b == 0)
				#expect(feature.matrix.c == 0)
				#expect(feature.matrix.d == 1)
				#expect(feature.matrix.tx == 0)
				#expect(feature.matrix.ty == 0)
			} else {
				Issue.record("Expected only annotation payloads")
			}
		}
	}

	@Test
	func `GIVEN text content WHEN extracting text only THEN text features contain bounds and font info`() throws {
		let document = try fixtureDocument(filename: "single-text-line.pdf")
		let page = try #require(document.pages.first)

		let features = page.extract(features: .text, lookup: document.lookup)
		#expect(!features.isEmpty)

		for feature in features {
			guard case .text(let utf8Text, let font) = feature.payload else {
				Issue.record("Expected only text payloads")
				continue
			}
			#expect(!utf8Text.isEmpty)
			#expect(font.size > 0)
			#expect(feature.bounds.width >= 0)
			#expect(feature.bounds.height >= 0)
			#expect(feature.bounds.x.isFinite)
			#expect(feature.bounds.y.isFinite)
			#expect(feature.matrix.a.isFinite)
			#expect(feature.matrix.d.isFinite)
		}
	}

	@Test
	func `GIVEN image heavy fixture WHEN extracting images THEN image features are discoverable`() throws {
		let document = try fixtureDocument(filename: "three-page-images-annots.pdf")
		let allImageFeatures = document.pages.flatMap { page in
			page.extract(features: .images, lookup: document.lookup)
		}

		#expect(!allImageFeatures.isEmpty)
		for feature in allImageFeatures {
			if case .image = feature.payload {
				#expect(feature.bounds.width >= 0)
				#expect(feature.bounds.height >= 0)
			} else {
				Issue.record("Expected only image payloads")
			}
		}
	}

	@Test
	func `GIVEN placeholder expected extraction fixtures WHEN loaded THEN files are available for later assertions`() throws {
		let textExpected = try #require(Bundle.module.url(forResource: "Fixtures/Extraction/single-text-line-page-1.expected.json", withExtension: nil))
		let imageExpected = try #require(Bundle.module.url(forResource: "Fixtures/Extraction/three-page-images-annots-page-1.expected.json", withExtension: nil))

		let textContent = try String(contentsOf: textExpected, encoding: .utf8)
		let imageContent = try String(contentsOf: imageExpected, encoding: .utf8)

		#expect(textContent.contains("TODO"))
		#expect(imageContent.contains("TODO"))
	}
}

private func fixtureDocument(filename: String) throws -> PdfDocument {
	let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
	let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
	return try PdfDocument(source: PdfDataSource(data))
}
