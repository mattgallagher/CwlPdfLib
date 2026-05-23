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
		let content = page.content(lookup: document.lookup)
		let fontDictionary = try #require(
			content.resolveResourceDictionary(category: .Font, key: "TT0", lookup: document.lookup)
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

	@Test
	func `GIVEN CTFont glyph run WHEN drawing THEN text matrix advance includes font size`() throws {
		let ctFont = CTFontCreateWithName("Helvetica" as CFString, 1, nil)
		let glyph = try #require(glyphForTest(character: "A", font: ctFont))
		let run = GlyphRun(
			glyphs: [Glyph(gid: glyph, advance: 500, isSpace: false)],
			writingMode: .horizontal
		)
		let state = TextState(fontSize: 12)
		let measurement = measureTextRun(Data([0x41]), state: state)

		#expect(abs(measurement.advanceInUserSpace - 7.2) < 0.000_001)

		guard let context = CGContext(
			data: nil,
			width: 32,
			height: 32,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			Issue.record("Failed to create CGContext")
			return
		}

		var position = TextPosition()
		context.drawGlyphRun(run, ctFont: ctFont, state: state, position: &position)

		#expect(position.textMatrix.tx == 6)
	}

	@Test
	func `GIVEN TJ offset WHEN measured for rendering and extraction THEN font size is included`() {
		let state = TextState(horizontalScale: 100, fontSize: 9)

		#expect(textDisplacementForTJOffset(277.7778, state: state) == -2.5000002)
	}
}

private func glyphForTest(character: Character, font: CTFont) -> CGGlyph? {
	guard let scalar = character.unicodeScalars.onlyElement else {
		return nil
	}
	var uniChar = UniChar(scalar.value)
	var glyph: CGGlyph = 0
	let success = CTFontGetGlyphsForCharacters(font, &uniChar, &glyph, 1)
	return success && glyph != 0 ? glyph : nil
}

private extension Collection {
	var onlyElement: Element? {
		count == 1 ? first : nil
	}
}
