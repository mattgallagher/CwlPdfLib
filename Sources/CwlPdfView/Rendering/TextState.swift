// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CoreText
import CwlPdfParser
import Foundation

struct TextState {
	var charSpace: CGFloat = 0
	var wordSpace: CGFloat = 0
	var horizontalScale: CGFloat = 100
	var leading: CGFloat = 0
	var font: PdfFont<CTFont>?
	var fontSize: CGFloat = 12
	var renderMode: Int = 0
	var rise: CGFloat = 0
	var lookup: PdfObjectLookup?
}

struct TextPosition {
	var textMatrix = CGAffineTransform.identity
	var lineMatrix = CGAffineTransform.identity
}

extension CGContext {
	func showText(_ data: Data, state: TextState, position: inout TextPosition) {
		guard let pdfFont = state.font else { return }

		// Handle Type3 fonts
		if case .type3(let type3Data) = pdfFont.kind {
			drawType3Text(data, font: pdfFont, type3Data: type3Data, state: state, position: &position)
			return
		}

		guard let ctFont = pdfFont.platformFont else {
			drawFallbackUnicode(data, state: state, position: &position)
			return
		}

		drawGlyphRun(GlyphRun(data, font: pdfFont, ctFont: ctFont), ctFont: ctFont, state: state, position: &position)
	}

	func drawType3Text(
		_ data: Data,
		font: PdfFont<CTFont>,
		type3Data: Type3FontData,
		state: TextState,
		position: inout TextPosition
	) {
		let fontSize = state.fontSize
		let fontMatrix = font.common.fontMatrix.cgAffineTransform
		let hScale = state.horizontalScale / 100

		for byte in data {
			let code = Int(byte)

			// Get glyph name from encoding
			let glyphName = type3Data.encoding.differences[code]
				?? type3Data.encoding.baseEncoding?.glyphName(for: code)

			guard let glyphName else { continue }

			// Look up CharProc stream
			guard let charProcStream = type3Data.charProcs[glyphName]?.stream(lookup: state.lookup) else {
				continue
			}

			// Get width for this glyph
			let index = code - type3Data.firstChar
			let width: Double = (index >= 0 && index < type3Data.widths.count)
				? type3Data.widths[index] : 0

			saveGState()

			// Apply positioning: textMatrix × fontSize × fontMatrix
			concatenate(position.textMatrix)
			concatenate(CGAffineTransform(scaleX: fontSize, y: fontSize))
			concatenate(fontMatrix)

			// Create and render the CharProc content stream
			let charProcContentStream = PdfContentStream(
				stream: charProcStream,
				resources: type3Data.resources,
				annotationRect: nil,
				lookup: state.lookup
			)
			charProcContentStream.render(in: self, lookup: state.lookup)

			restoreGState()

			// Advance text position (width is in glyph space units, typically 1000 per em)
			let advance = (width / 1000) * fontSize * hScale + state.charSpace + (code == 0x20 ? state.wordSpace : 0)
			position.textMatrix = CGAffineTransform(translationX: advance, y: 0)
				.concatenating(position.textMatrix)
		}
	}
	
	func drawFallbackUnicode(_ text: Data, state: TextState, position: inout TextPosition) {
		var chars = Array(text.pdfTextToString().utf16)
		var glyphs = [CGGlyph](repeating: 0, count: chars.count)
		var advances = [CGPoint](repeating: .zero, count: chars.count)
		let ctFont = state.font?.platformFont ?? CTFontCreateWithName("Helvetica" as CFString, 1, nil)
		CTFontGetGlyphsForCharacters(ctFont, &chars, &glyphs, chars.count)
		advances.withUnsafeMutableBufferPointer { bufferPointer in
			bufferPointer.withMemoryRebound(to: CGSize.self) { buffer in
				_ = CTFontGetAdvancesForGlyphs(ctFont, .horizontal, glyphs, buffer.baseAddress!, chars.count)
			}
		}
		var x: CGFloat = 0
		for i in 0..<chars.count {
			let advance = advances[i].x
			advances[i] = CGPoint(x: x, y: state.rise)
			x += advance * state.fontSize * state.horizontalScale / 100 + state.charSpace + (
				chars[i] == 0x0020 ? state.wordSpace : 0
			)
		}
		saveGState()
		concatenate(position.textMatrix.scaledBy(x: state.fontSize, y: state.fontSize))
		CTFontDrawGlyphs(ctFont, glyphs, advances, chars.count, self)
		restoreGState()
		position.textMatrix = CGAffineTransform(translationX: x, y: 0).concatenating(position.textMatrix)
	}
	
	func decodeSimpleFont(_ data: Data, font: PdfFont<CTFont>) -> GlyphRun {
		guard case .simple(let simple) = font.kind else { fatalError() }
		
		var glyphs: [Glyph] = []
		for byte in data {
			let code = Int(byte)
			
			let width = if simple.widths.indices.contains(code - simple.firstChar) {
				simple.widths[code - simple.firstChar]
			} else {
				simple.missingWidth ?? 0
			}
			
			let glyphName = simple.encoding.differences[code] ?? simple.encoding.baseEncoding?.glyphName(for: code)
			
			let gid = glyphName.flatMap { name in
				font.platformFont.flatMap { font in CTFontGetGlyphWithName(font, name as CFString) }
			} ?? 0
			
			glyphs.append(Glyph(gid: gid, advance: width, isSpace: code == 0x20))
		}
		
		return GlyphRun(
			glyphs: glyphs,
			writingMode: font.extras.writingMode
		)
	}
	
	func decodeCompositeFont(_ data: Data, font: PdfFont<CTFont>) -> GlyphRun {
		guard case .composite(let composite) = font.kind else { fatalError() }
		
		let codes = composite.cmap.decode(data)
		var glyphs: [Glyph] = []
		
		for cid in codes {
			let gid: CGGlyph = switch composite.descendantFont.cidToGIDMap {
			case .identity, .none:
				CGGlyph(cid)
			case .mapped(let map):
				cid < map.count ? CGGlyph(map[Int(cid)]) : 0
			}
			
			let width =
				composite.descendantFont.widths.width(for: cid)
					?? composite.descendantFont.defaultWidth
			
			glyphs.append(Glyph(gid: gid, advance: width, isSpace: cid == 0x20))
		}
		
		return GlyphRun(
			glyphs: glyphs,
			writingMode: composite.cmap.writingMode
		)
	}
	
	func drawGlyphRun(
		_ run: GlyphRun,
		ctFont: CTFont,
		state: TextState,
		position: inout TextPosition
	) {
		let fontSize = CGFloat(state.fontSize)
		let hScale = CGFloat(state.horizontalScale / 100)
		
		var positions: [CGPoint] = []
		var cursor: CGFloat = 0
		
		for glyph in run.glyphs {
			let adv = glyph.advance / 1000
			
			positions.append(CGPoint(
				x: cursor,
				y: CGFloat(state.rise)
			))
			
			cursor += adv * fontSize * hScale
			cursor += CGFloat(state.charSpace)
			
			if glyph.isSpace {
				cursor += CGFloat(state.wordSpace)
			}
		}
		
		saveGState()
		
		// PDF text rendering matrix:
		// textMatrix × fontSize × CTM
		concatenate(
			position.textMatrix
				.scaledBy(x: fontSize, y: fontSize)
		)
		
		CTFontDrawGlyphs(
			ctFont,
			run.glyphs.map(\.gid),
			positions,
			run.glyphs.count,
			self
		)
		
		restoreGState()
		
		// Advance text matrix
		position.textMatrix = CGAffineTransform(translationX: cursor / fontSize, y: 0).concatenating(position.textMatrix)
	}
}

struct GlyphRun {
	let glyphs: [Glyph]
	let writingMode: WritingMode
	
	init(_ data: Data, font: PdfFont<CTFont>, ctFont: CTFont) {
		switch font.kind {
		case .simple:
			self = Self.decodeSimpleGlyphRun(data, font: font, ctFont: ctFont)
		case .composite:
			self = Self.decodeCompositeGlyphRun(data, font: font)
		case .type3:
			fatalError("Type3 fonts should not use GlyphRun")
		}
	}

	init(glyphs: [Glyph], writingMode: WritingMode) {
		self.glyphs = glyphs
		self.writingMode = writingMode
	}
	
	private static func decodeSimpleGlyphRun(
		_ data: Data,
		font: PdfFont<CTFont>,
		ctFont: CTFont
	) -> GlyphRun {
		guard case .simple(let simple) = font.kind else {
			fatalError("Expected simple font")
		}
		
		var glyphs: [Glyph] = []
		
		glyphs.reserveCapacity(data.count)
		
		for byte in data {
			let code = Int(byte)
			
			// --- Width (glyph space)
			let index = code - simple.firstChar
			let width: Double = if index >= 0, index < simple.widths.count {
				simple.widths[index]
			} else {
				simple.missingWidth ?? 0
			}
			
			// --- Glyph name
			let glyphName: String? = simple.encoding.differences[code] ?? simple.encoding.baseEncoding?.glyphName(for: code)
			
			// --- GID
			let gid: CGGlyph = if let name = glyphName {
				CTFontGetGlyphWithName(ctFont, name as CFString)
			} else {
				decodeSimpleGlyph(code: byte, ctFont: ctFont)
			}
			
			glyphs.append(Glyph(gid: gid, advance: width, isSpace: code == 0x20))
		}
		
		return GlyphRun(
			glyphs: glyphs,
			writingMode: font.extras.writingMode
		)
	}

	private static func decodeSimpleGlyph(
		code: UInt8,
		ctFont: CTFont
	) -> CGGlyph {
		var utf16 = UInt16(code)
		var glyph: CGGlyph = 0
		let success = CTFontGetGlyphsForCharacters(ctFont, &utf16, &glyph, 1)
		return success ? glyph : CGGlyph(0)
	}

	private static func decodeCompositeGlyphRun(
		_ data: Data,
		font: PdfFont<CTFont>
	) -> GlyphRun {
		guard case .composite(let composite) = font.kind else {
			fatalError("Expected composite font")
		}
		
		let cmap = composite.cmap
		let descendant = composite.descendantFont
		
		let cids = cmap.decode(data)
		
		var glyphs: [Glyph] = []
		
		glyphs.reserveCapacity(cids.count)
		
		for cid in cids {
			// --- CID → GID
			let gid: CGGlyph = switch descendant.cidToGIDMap {
			case .identity, .none:
				CGGlyph(cid)
			case .mapped(let map):
				if cid >= 0, Int(cid) < map.count {
					CGGlyph(map[Int(cid)])
				} else {
					CGGlyph(0)
				}
			}
			
			// --- Width (glyph space)
			let width: Double = descendant.widths.width(for: cid) ?? descendant.defaultWidth
			
			glyphs.append(Glyph(gid: gid, advance: width, isSpace: cid == 0x20))
		}
		
		return GlyphRun(
			glyphs: glyphs,
			writingMode: cmap.writingMode
		)
	}
}

struct Glyph {
	let gid: CGGlyph
	let advance: CGFloat
	let isSpace: Bool
}
