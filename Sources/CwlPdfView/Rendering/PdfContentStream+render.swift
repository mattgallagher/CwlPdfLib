// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics
import AppKit

extension PdfContentStream {
	func render(in context: CGContext, pageBounds: CGRect?, lookup: PdfObjectLookup?) {
		context.saveGState()
		
		var renderState = RenderState()
		var renderStateStack = [RenderState]()

		if let contextTransform {
			context.concatenate(contextTransform)
		}

		if let bbox = bbox?.cgRect ?? pageBounds {
			let bboxPath = CGPath(rect: bbox, transform: nil)
			context.addPath(bboxPath)
			context.clip()
			renderState.addClipPath(bboxPath, ctm: context.ctm, fillRule: .winding)
		}
		
		var textState = TextState()
		var textPosition = TextPosition()
		var pendingClip: CGPathFillRule?
		
		do {
			try parse { op in
				switch op {
				case .`'`(let text):
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
					context.showText(text, state: textState, position: &textPosition, lookup: lookup)
				case .`"`(let text, let cSpacing, let wSpacing):
					textState.charSpace = cSpacing
					textState.wordSpace = wSpacing
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
					context.showText(text, state: textState, position: &textPosition, lookup: lookup)
				case .B:
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.drawPath(using: .fillStroke)
				case .`B*`:
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.drawPath(using: .eoFillStroke)
				case .b:
					context.closePath()
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.drawPath(using: .fillStroke)
				case .`b*`:
					context.closePath()
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.drawPath(using: .eoFillStroke)
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
				case .CS(let name):
					if let deviceColorSpace = PdfColorSpace(name: name) {
						renderState.colorState.strokeColorSpace = deviceColorSpace
					} else if
						let colorSpaceArray = resolveResourceArray(category: .ColorSpace, key: name, lookup: lookup),
						let colorSpace = PdfColorSpace.parse(.array(colorSpaceArray), lookup: lookup)
					{
						renderState.colorState.strokeColorSpace = colorSpace
					}
				case .cs(let name):
					if let deviceColorSpace = PdfColorSpace(name: name) {
						renderState.colorState.fillColorSpace = deviceColorSpace
					} else if
						let colorSpaceArray = resolveResourceArray(category: .ColorSpace, key: name, lookup: lookup),
						let colorSpace = PdfColorSpace.parse(.array(colorSpaceArray), lookup: lookup)
					{
						renderState.colorState.fillColorSpace = colorSpace
					}
				case .d(let phase, let array):
					let dashArray = array.map { CGFloat($0) }
					context.setLineDash(phase: CGFloat(phase), lengths: dashArray)
				case .d0:
					break
				case .d1:
					break
				case .Do(let xobjectName):
					guard let xobjectStream = resolveResourceStream(
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
					// Handle Form XObjects (nested content streams)
					else if xobjectStream.dictionary.isForm(lookup: lookup) {
						let formContentStream = PdfContentStream(
							stream: xobjectStream,
							resources: nil,
							annotationRect: nil,
							lookup: lookup
						)
						formContentStream.render(in: context, pageBounds: nil, lookup: lookup)
					}
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
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.fillPath(using: .winding)
				case .f:
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.fillPath(using: .winding)
				case .`f*`:
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.fillPath(using: .evenOdd)
				case .G(let gray):
					renderState.colorState.setStrokeGray(CGFloat(gray))
					renderState.colorState.applyStrokeColor(to: context)
				case .g(let gray):
					renderState.colorState.setFillGray(CGFloat(gray))
					renderState.colorState.applyFillColor(to: context)
				case .gs(let name):
					guard let gstateDictionary = resolveResourceDictionary(
						category: .ExtGState,
						key: name,
						lookup: lookup
					) else {
						break
					}
					let gstate = PdfExtGState(dictionary: gstateDictionary, lookup: lookup)
					context.apply(gstate, renderState: &renderState, renderStack: renderStateStack, lookup: lookup)
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
					renderState.colorState.setStrokeCMYK(CGFloat(c), CGFloat(m), CGFloat(y), CGFloat(k))
					renderState.colorState.applyStrokeColor(to: context)
				case .k(let c, let m, let y, let k):
					renderState.colorState.setFillCMYK(CGFloat(c), CGFloat(m), CGFloat(y), CGFloat(k))
					renderState.colorState.applyFillColor(to: context)
				case .l(let x, let y):
					context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
				case .M(let limit):
					context.setMiterLimit(CGFloat(limit))
				case .m(let x, let y):
					context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
				case .MP(_):
					break
				case .n:
					if let clipRule = pendingClip {
						if let path = context.path?.copy() {
							renderState.addClipPath(path, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
					} else {
						context.beginPath()
					}
				case .q:
					context.saveGState()
					renderStateStack.append(renderState)
				case .Q:
					renderState = renderStateStack.popLast() ?? RenderState()
					context.restoreGState()
					pendingClip = nil
				case .re(let x, let y, let w, let h):
					context.addRect(CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)))
				case .RG(let r, let g, let b):
					renderState.colorState.setStrokeRGB(CGFloat(r), CGFloat(g), CGFloat(b))
					renderState.colorState.applyStrokeColor(to: context)
				case .rg(let r, let g, let b):
					renderState.colorState.setFillRGB(CGFloat(r), CGFloat(g), CGFloat(b))
					renderState.colorState.applyFillColor(to: context)
				case .ri(_):
					break
				case .S:
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.strokePath()
				case .s:
					context.closePath()
					if let clipRule = pendingClip {
						let path = context.path
						if let pathCopy = path?.copy() {
							renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
						}
						context.clip(using: clipRule)
						pendingClip = nil
						if let path { context.addPath(path) }
					}
					context.strokePath()
				case .SC(let colors):
					renderState.colorState.setStrokeColor(colors.map { CGFloat($0) })
					renderState.colorState.applyStrokeColor(to: context)
				case .sc(let colors):
					renderState.colorState.setFillColor(colors.map { CGFloat($0) })
					renderState.colorState.applyFillColor(to: context)
				case .SCN(let colors):
					renderState.colorState.setStrokeColor(colors.map { CGFloat($0) })
					renderState.colorState.applyStrokeColor(to: context)
				case .scn(let colors):
					renderState.colorState.setFillColor(colors.map { CGFloat($0) })
					renderState.colorState.applyFillColor(to: context)
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
						let fontDictionary = resolveResourceDictionary(category: .Font, key: fontKey, lookup: lookup)
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
					context.showText(text, state: textState, position: &textPosition, lookup: lookup)
				case .TJ(let array):
					for item in array {
						switch item {
						case .offset(let offset):
							// Offset is in thousandths of text space units
							// Must use matrix concatenation to account for textMatrix scaling
							let displacement = -(offset / 1000) * (textState.horizontalScale / 100)
							let translation = CGAffineTransform(translationX: displacement, y: 0)
							textPosition.textMatrix = translation.concatenating(textPosition.textMatrix)
						case .text(let text):
							context.showText(text, state: textState, position: &textPosition, lookup: lookup)
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
					pendingClip = .winding
				case .`W*`:
					pendingClip = .evenOdd
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

		context.restoreGState()
	}
	
	var contextTransform: CGAffineTransform? {
		guard let rect = annotationRect?.cgRect, let bbox = bbox?.cgRect else {
			return matrix?.cgAffineTransform
		}

		let matrix = matrix?.cgAffineTransform ?? .identity
		let transformedBBox = bbox.applying(matrix)
		let scaleX = rect.width / transformedBBox.width
		let scaleY = rect.height / transformedBBox.height
		let translateX = rect.minX - transformedBBox.minX * scaleX
		let translateY = rect.minY - transformedBBox.minY * scaleY

		var AA = CGAffineTransform.identity
		AA = AA.translatedBy(x: translateX, y: translateY)
		AA = AA.scaledBy(x: scaleX, y: scaleY)
		AA = AA.concatenating(matrix)
		return AA
	}

}
