// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics
import AppKit

struct TextState {
	var charSpace: CGFloat = 0
	var wordSpace: CGFloat = 0
	var horizontalScale: CGFloat = 100
	var leading: CGFloat = 0
	var font: PdfFont<CTFont>?
	var fontSize: CGFloat = 12
	var renderMode: Int = 0
	var rise: CGFloat = 0
}

struct TextPosition {
	var textMatrix = CGAffineTransform.identity
	var lineMatrix = CGAffineTransform.identity
}

extension PdfPage {
	func render(in context: CGContext, lookup: PdfObjectLookup?) {
		guard let contentStream = self.contentStream(lookup: lookup) else {
			return
		}
		
		var textState = TextState()
		var textPosition = TextPosition()
		
		do {
			try contentStream.parse { op in
				switch op {
				case .`'`(let text):
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
					context.showText(text, state: textState, position: &textPosition)
				case .`"`(let text, let cSpacing, let wSpacing):
					textState.charSpace = cSpacing
					textState.wordSpace = wSpacing
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
					context.showText(text, state: textState, position: &textPosition)
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
					let transform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
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
				case .Do(let xobjectName):
					guard let xobjectStream = contentStream.resolveResourceStream(
						category: .XObject,
						key: xobjectName,
						lookup: lookup
					) else {
						break
					}
					// Check if this is an image XObject
					if xobjectStream.dictionary.isImage(lookup: lookup) {
						guard
							let pdfImage = try? PdfImage(stream: xobjectStream, lookup: lookup),
							let cgImage = pdfImage.createCGImage(lookup: lookup)
						else {
							break
						}
						// Images are drawn in a 1x1 unit square; the CTM positions and scales them
						context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
					}
					// TODO: Handle Form XObjects (nested content streams)
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
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: tx, y: ty)
					textPosition.textMatrix = textPosition.lineMatrix
				case .TD(let tx, let ty):
					textState.leading = -CGFloat(ty)
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: tx, y: ty)
					textPosition.textMatrix = textPosition.lineMatrix
				case .Tf(let fontKey, let size):
					textState.fontSize = size
					guard
						let fontDictionary = contentStream.resolveResource(category: .Font, key: fontKey, lookup: lookup)
					else {
						textState.font = nil
						break
					}
					textState.font = try? PdfFont(fontDictionary: fontDictionary, lookup: lookup) { data in
						CGDataProvider(data: data as CFData)
							.flatMap(CGFont.init)
							.map { CTFontCreateWithGraphicsFont($0, 1.0, nil, nil) }
					}
				case .Tj(let text):
					context.showText(text, state: textState, position: &textPosition)
				case .TJ(let array):
					for item in array {
						switch item {
						case .offset(let offset):
							textPosition.textMatrix.tx -= offset / 1000
						case .text(let text):
							context.showText(text, state: textState, position: &textPosition)
						}
					}
				case .TL(let lead):
					textState.leading = lead
				case .Tm(let a, let b, let c, let d, let tx, let ty):
					textPosition.lineMatrix = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
					textPosition.textMatrix = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
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
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
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

extension PdfDictionary {
	func ctFont(lookup: PdfObjectLookup?) -> CTFont {
		guard
			let fontDescriptor = self[.FontDescriptor]?.dictionary(lookup: lookup),
			let fontStream = (fontDescriptor[.FontFile3] ?? fontDescriptor[.FontFile2] ?? fontDescriptor[.FontFile])?.stream(lookup: lookup),
			let provider = CGDataProvider(data: fontStream.data as CFData),
			let cgFont = CGFont(provider)
		else {
			let postScriptName = "Helvetica" // derived from /BaseFont
			return CTFontCreateWithName(postScriptName as CFString, 1.0, nil)
		}
		return CTFontCreateWithGraphicsFont(cgFont, 1.0, nil, nil)
	}
}
