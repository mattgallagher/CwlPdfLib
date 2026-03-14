// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CoreText
import CwlPdfParser
@testable import CwlPdfRenderer
import Foundation
import Testing

struct PdfFontRenderingTests {
	@Test
	func `GIVEN embedded Georgia2 font WHEN decoding WinAnsi text THEN glyph run uses real glyphs instead of notdef`() throws {
		let document = try fixtureDocument(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-01_Magazine-danish.pdf"
		)
		let page = try #require(document.pages.indices.contains(2) ? document.pages[2] : nil)
		let contentStream = try #require(page.contentStreams(lookup: document.lookup).first)
		let fontDictionary = try #require(
			contentStream.resolveResourceDictionary(category: .Font, key: "TT0", lookup: document.lookup)
		)

		let font = try PdfFont(fontDictionary: fontDictionary, lookup: document.lookup) { data in
			CGDataProvider(data: data as CFData)
				.flatMap(CGFont.init)
				.map { CTFontCreateWithGraphicsFont($0, 1.0, nil, nil) }
		}
		let ctFont = try #require(font.platformFont)
		let sampleData = try #require("hjælper og rådgiver".data(using: .windowsCP1252))

		let glyphRun = GlyphRun(sampleData, font: font, ctFont: ctFont)
		#expect(glyphRun.glyphs.count == sampleData.count)

		for (byte, glyph) in zip(sampleData, glyphRun.glyphs) {
			#expect(glyph.gid != 0, "Expected byte \(byte) to map to a real glyph")
		}
	}
}
