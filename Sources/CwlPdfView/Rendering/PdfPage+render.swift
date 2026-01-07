// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics
import AppKit

struct TextState {
	var charSpace: CGFloat = 0
	var wordSpace: CGFloat = 0
	var horizontalScale: CGFloat = 100
	var leading: CGFloat = 0
	var font: CTFont = CTFont(.system, size: 12)
	var fontSize: CGFloat = 12
	var renderMode: Int = 0
	var rise: CGFloat = 0
}

struct TextPosition {
	var textMatrix = CGAffineTransform.identity
	var lineMatrix = CGAffineTransform.identity
}

extension CGContext {
	func showPdfText(_ text: String, state: inout TextState, position: inout TextPosition) {
		var chars = Array(text.utf16)
		var glyphs = Array<CGGlyph>(repeating: 0, count: chars.count)
		var advances = [CGPoint](repeating: .zero, count: chars.count )
		CTFontGetGlyphsForCharacters(state.font, &chars, &glyphs, chars.count)
		let total = advances.withUnsafeMutableBufferPointer { bufferPointer in
			bufferPointer.withMemoryRebound(to: CGSize.self) { buffer in
				CTFontGetAdvancesForGlyphs(state.font, .horizontal, glyphs, buffer.baseAddress!, chars.count)
			}
		}
		var x: CGFloat = 0
		for i in 0..<chars.count {
			let advance = advances[i].x
			advances[i] = CGPoint(x: x, y: state.rise)
			x += advance * state.horizontalScale / 100 + state.charSpace + (
				chars[i] == 0x0020 ? state.wordSpace : 0
			)
		}
		saveGState()
		concatenate(position.textMatrix)
		CTFontDrawGlyphs(state.font, glyphs, advances, chars.count, self)
		restoreGState()
		position.textMatrix = CGAffineTransform(translationX: total, y: 0).concatenating(position.textMatrix)
	}
	
	func nextTextLine(state: inout TextState, position: inout TextPosition) {
	}
}

extension PdfPage {
	func render(in context: CGContext, objects: PdfObjectList?) {
		guard let contentStream = self.contentStream(objects: objects) else {
			return
		}
		
		var textState = TextState()
		var textPosition = TextPosition()
		
		do {
			try contentStream.parse { op in
				switch op {
				case .`'`(let text):
					context.nextTextLine(state: &textState, position: &textPosition)
					context.showPdfText(text, state: &textState, position: &textPosition)
				case .`"`(let text, let cSpacing, let wSpacing):
					textState.charSpace = cSpacing
					textState.wordSpace = wSpacing
					
					context.nextTextLine(state: &textState, position: &textPosition)
					context.showPdfText(text, state: &textState, position: &textPosition)
				case .B:
					context.fillPath(using: .winding)
					context.strokePath()
				case .`B*`:
					context.fillPath(using: .evenOdd)
					context.strokePath()
				case .b:
					context.closePath()
					context.fillPath(using: .winding)
					context.strokePath()
				case .`b*`:
					context.closePath()
					context.fillPath(using: .evenOdd)
					context.strokePath()
				case .BDC(_, _):
					break
				case .BI:
					break
				case .BMC(_):
					break
				case .BT:
					textPosition = TextPosition()
				case .BX:
					break
				case .c(let x1, let y1, let x2, let y2, let x3, let y3):
					context.addCurve(
						to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)),
						control1: CGPoint(x: CGFloat(x1), y: CGFloat(y1)),
						control2: CGPoint(x: CGFloat(x2), y: CGFloat(y2))
					)
				case .cm(let a, let b, let c, let d, let tx, let ty):
					let transform = CGAffineTransform(
						a: CGFloat(a),
						b: CGFloat(b),
						c: CGFloat(c),
						d: CGFloat(d),
						tx: CGFloat(tx),
						ty: CGFloat(ty)
					)
					context.concatenate(transform)
				case .CS(_):
					break
				case .cs(_):
					break
				case .d(let phase, let array):
					let dashArray = array.map { CGFloat($0) }
					context.setLineDash(phase: CGFloat(phase), lengths: dashArray)
				case .d0:
					break
				case .d1:
					break
				case .Do(_):
					break
				case .DP(_, _):
					break
				case .EI:
					break
				case .EMC:
					break
				case .ET:
					// No effect needed (text positioning will be cleared on next BT)
					break
				case .EX:
					break
				case .F:
					context.fillPath(using: .winding)
				case .f:
					context.fillPath(using: .winding)
				case .`f*`:
					context.fillPath(using: .evenOdd)
				case .G(let gray):
					context.setStrokeColor(CGColor(gray: CGFloat(gray), alpha: 1))
				case .g(let gray):
					context.setFillColor(CGColor(gray: CGFloat(gray), alpha: 1))
				case .gs(_):
					break
				case .h:
					context.closePath()
				case .i(_):
					break
				case .ID:
					break
				case .J(let style):
					let lineCap: CGLineCap = switch style {
					case 0: .butt
					case 1: .round
					case 2: .square
					default: .butt
					}
					context.setLineCap(lineCap)
				case .j(let style):
					let lineJoin: CGLineJoin = switch style {
					case 0: .miter
					case 1: .round
					case 2: .bevel
					default: .miter
					}
					context.setLineJoin(lineJoin)
				case .K(let c, let m, let y, let k):
					context.setStrokeColor(CGColor(red: CGFloat(1 - c), green: CGFloat(1 - m), blue: CGFloat(1 - y), alpha: CGFloat(1 - k)))
				case .k(let c, let m, let y, let k):
					context.setFillColor(CGColor(red: CGFloat(1 - c), green: CGFloat(1 - m), blue: CGFloat(1 - y), alpha: CGFloat(1 - k)))
				case .l(let x, let y):
					context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
				case .M(let limit):
					context.setMiterLimit(CGFloat(limit))
				case .m(let x, let y):
					context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
				case .MP(_):
					break
				case .n:
					context.beginPath()
				case .q:
					context.saveGState()
				case .Q:
					context.restoreGState()
				case .re(let x, let y, let w, let h):
					context.addRect(CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)))
				case .RG(let r, let g, let b):
					context.setStrokeColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1))
				case .rg(let r, let g, let b):
					context.setFillColor(CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1))
				case .ri(_):
					break
				case .S:
					context.strokePath()
				case .s:
					context.closePath()
					context.strokePath()
				case .SC(let colors):
					guard colors.count >= 3 else { break }
					context.setStrokeColor(CGColor(red: colors[0], green: colors[1], blue: colors[2], alpha: 1))
				case .sc(let colors):
					guard colors.count >= 3 else { break }
					context.setFillColor(CGColor(red: colors[0], green: colors[1], blue: colors[2], alpha: 1))
				case .SCN(_):
					break
				case .scn(_):
					break
				case .sh(_):
					break
				case .Tc(let spacing):
					textState.charSpace = spacing
				case .Td(let tx, let ty):
					textPosition.textMatrix = textPosition.textMatrix.translatedBy(x: CGFloat(tx), y: CGFloat(ty))
				case .TD(let tx, let ty):
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: CGFloat(tx), y: 0)
					textState.leading = -CGFloat(ty)
				case .Tf(_, let size):
					textState.font = CTFont(.system, size: size)
					textState.fontSize = size
				case .Tj(let text):
					context.showPdfText(text, state: &textState, position: &textPosition)
				case .TJ(let array):
					for item in array {
						switch item {
						case .offset(let offset):
							textPosition.textMatrix.tx += offset * textState.fontSize / CGFloat(1000)
						case .text(let text):
							context.showPdfText(text, state: &textState, position: &textPosition)
						}
					}
				case .TL(let lead):
					textState.leading = lead
				case .Tm(let a, let b, let c, let d, let tx, let ty):
					textPosition.textMatrix = CGAffineTransform(
						a: CGFloat(a),
						b: CGFloat(b),
						c: CGFloat(c),
						d: CGFloat(d),
						tx: CGFloat(tx),
						ty: CGFloat(ty)
					)
				case .Tr(let mode):
					if let mode = CGTextDrawingMode(rawValue: Int32(mode)) {
						context.setTextDrawingMode(mode)
					}
				case .Ts(let rise):
					textState.rise = rise
				case .Tw(let wSpacing):
					textState.wordSpace = wSpacing
				case .Tz(let scaling):
					textState.horizontalScale = CGFloat(scaling)
				case .`T*`:
					context.nextTextLine(state: &textState, position: &textPosition)
				case .v(let x2, let y2, let x3, let y3):
					context.addCurve(
						to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)),
						control1: context.currentPointOfPath,
						control2: CGPoint(x: CGFloat(x2), y: CGFloat(y2))
					)
				case .w(let width):
					context.setLineWidth(CGFloat(width))
				case .W:
					break
				case .`W*`:
					break
				case .y(let x2, let y2, let x3, let y3):
					context.addCurve(
						to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)),
						control1: CGPoint(x: CGFloat(x2), y: CGFloat(y2)),
						control2: context.currentPointOfPath
					)
				}
				return true
			}
		} catch {
			print(error)
		}
	}
}
