// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser
import CwlPdfRenderer
import Foundation
import Testing

struct PdfFeatureExtractionTests {
	@Test
	func `GIVEN page annotations WHEN extracting annotations only THEN only annotation features are returned`() throws {
		let document = try basicFixtureDocument(filename: "three-page-images-annots.pdf")
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
		let document = try basicFixtureDocument(filename: "single-text-line.pdf")
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
		let document = try basicFixtureDocument(filename: "three-page-images-annots.pdf")
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
	func `GIVEN PDFUA magazine page 3 WHEN extracting text THEN mixed embedded fonts decode readable spans`() throws {
		let document = try fixtureDocument(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-01_Magazine-danish.pdf"
		)
		let page = try #require(document.pages.indices.contains(2) ? document.pages[2] : nil)

		let textFeatures: [ExtractedTextSample] = page.extract(features: .text, lookup: document.lookup).compactMap { feature in
			guard case .text(let utf8Text, let font) = feature.payload else {
				return nil
			}

			return ExtractedTextSample(
				text: utf8Text,
				postScriptName: font.postScriptName
			)
		}
		let textByFont = Dictionary(grouping: textFeatures, by: { $0.postScriptName ?? "" }).mapValues { samples in
			samples.map { $0.text }.joined()
		}

		#expect(textByFont["Georgia2"]?.contains("I Dansk Blindesamfund hjælper") == true)
		#expect(textByFont["AGWEKG+Georgia"]?.contains("mange flere, der kunne have brug") == true)
		#expect(textByFont["GIXFJO+Georgia-Bold"]?.contains("Aktivitetsmedlemskabet kan tegnes") == true)
		#expect(textByFont["YMVHKH+Georgia-BoldItalic"]?.contains("Vi glæder os til at byde") == true)

		for sample in textFeatures {
			#expect(!sample.text.contains("\u{FFFD}"))
		}
	}
}

private struct ExtractedTextSample {
	let text: String
	let postScriptName: String?
}
