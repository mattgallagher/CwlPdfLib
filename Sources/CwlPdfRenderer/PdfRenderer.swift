// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import AppKit
import CoreGraphics
import CwlPdfParser

struct PdfRenderer {
	var renderState: RenderState
	var renderStateStack = [RenderState]()
	var textState = TextState()
	var textStateStack = [TextState]()
	var textPosition = TextPosition()
	var pendingClip: CGPathFillRule?
	var pathState = PdfGraphicsPathState()
	let inheritedDeviceScaleX: CGFloat
	let inheritedDeviceScaleY: CGFloat

	init(deviceScaleX: CGFloat, deviceScaleY: CGFloat) {
		renderState = RenderState(deviceScaleX: deviceScaleX, deviceScaleY: deviceScaleY)
		inheritedDeviceScaleX = deviceScaleX
		inheritedDeviceScaleY = deviceScaleY
	}

	mutating func applyPendingClipIfNeeded(
		in context: CGContext,
		preservePath: Bool
	) {
		guard let clipRule = pendingClip else {
			return
		}

		defer {
			pendingClip = nil
		}

		guard pathState.hasDrawableSegments else {
			context.beginPath()
			return
		}

		let path = context.path
		if let pathCopy = path?.copy() {
			renderState.addClipPath(pathCopy, ctm: context.ctm, fillRule: clipRule)
		}
		context.clip(using: clipRule)
		if preservePath, let path {
			context.addPath(path)
		}
	}

	mutating func render(
		_ stream: PdfStream,
		resources: any PdfContentStream,
		in context: CGContext,
		lookup: PdfObjectLookup?
	) {
		try? render(
			stream,
			resources: resources,
			in: context,
			lookup: lookup,
			cancellationCheck: {}
		)
	}

	mutating func render(
		_ stream: PdfStream,
		resources: any PdfContentStream,
		in context: CGContext,
		lookup: PdfObjectLookup?,
		cancellationCheck: () throws -> Void
	) throws {
		do {
			try stream.parseContentOperators(lookup: lookup) { op in
				try cancellationCheck()
				
				switch op {
				case .`'`(let text):
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
					try context.showText(
						text,
						state: textState,
						position: &textPosition,
						lookup: lookup,
						cancellationCheck: cancellationCheck
					)
				case .`"`(let text, let cSpacing, let wSpacing):
					textState.charSpace = cSpacing
					textState.wordSpace = wSpacing
					textPosition.lineMatrix = textPosition.lineMatrix.translatedBy(x: 0, y: -textState.leading)
					textPosition.textMatrix = textPosition.lineMatrix
					try context.showText(
						text,
						state: textState,
						position: &textPosition,
						lookup: lookup,
						cancellationCheck: cancellationCheck
					)
				case .B:
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.drawPath(using: .fillStroke)
					pathState.beginPath()
				case .`B*`:
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.drawPath(using: .eoFillStroke)
					pathState.beginPath()
				case .b:
					if pathState.closeSubpath() {
						context.closePath()
					}
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.drawPath(using: .fillStroke)
					pathState.beginPath()
				case .`b*`:
					if pathState.closeSubpath() {
						context.closePath()
					}
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.drawPath(using: .eoFillStroke)
					pathState.beginPath()
				case .BDC:
					break
				case .BI:
					break
				case .BMC:
					break
				case .BT:
					textPosition = TextPosition()
				case .BX:
					break
				case .c(let x1, let y1, let x2, let y2, let x3, let y3):
					guard pathState.addCurve(to: CGPoint(x: CGFloat(x3), y: CGFloat(y3))) else {
						break
					}
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
						let colorSpaceArray = resources.resolveResourceArray(category: .ColorSpace, key: name, lookup: lookup),
						let colorSpace = PdfColorSpace.parse(.array(colorSpaceArray), lookup: lookup)
					{
						renderState.colorState.strokeColorSpace = colorSpace
					}
				case .cs(let name):
					if let deviceColorSpace = PdfColorSpace(name: name) {
						renderState.colorState.fillColorSpace = deviceColorSpace
					} else if
						let colorSpaceArray = resources.resolveResourceArray(category: .ColorSpace, key: name, lookup: lookup),
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
					guard let xobjectStream = resources.resolveResourceStream(
						category: .XObject,
						key: xobjectName,
						lookup: lookup
					) else {
						break
					}
					try cancellationCheck()
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
						let formContent = PdfFormContent(
							stream: xobjectStream,
							resources: resources.resources,
							lookup: lookup
						)
						try formContent.render(
							in: context,
							lookup: lookup,
							deviceScaleX: inheritedDeviceScaleX,
							deviceScaleY: inheritedDeviceScaleY,
							cancellationCheck: cancellationCheck
						)
					}
				case .DP:
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
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.fillPath(using: .winding)
					pathState.beginPath()
				case .f:
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.fillPath(using: .winding)
					pathState.beginPath()
				case .`f*`:
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.fillPath(using: .evenOdd)
					pathState.beginPath()
				case .G(let gray):
					renderState.colorState.setStrokeGray(CGFloat(gray))
					renderState.colorState.applyStrokeColor(to: context)
				case .g(let gray):
					renderState.colorState.setFillGray(CGFloat(gray))
					renderState.colorState.applyFillColor(to: context)
				case .gs(let name):
					guard let gstateDictionary = resources.resolveResourceDictionary(
						category: .ExtGState,
						key: name,
						lookup: lookup
					) else {
						break
					}
					let gstate = PdfExtGState(dictionary: gstateDictionary, lookup: lookup)
					context.apply(gstate, renderState: &renderState, renderStack: renderStateStack, lookup: lookup)
				case .h:
					if pathState.closeSubpath() {
						context.closePath()
					}
				case .i:
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
					guard pathState.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y))) else {
						break
					}
					context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
				case .M(let limit):
					context.setMiterLimit(CGFloat(limit))
				case .m(let x, let y):
					pathState.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
					context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(y)))
				case .MP:
					break
				case .n:
					if pendingClip != nil {
						applyPendingClipIfNeeded(in: context, preservePath: false)
					} else {
						context.beginPath()
					}
					pathState.beginPath()
				case .q:
					context.saveGState()
					renderStateStack.append(renderState)
					textStateStack.append(textState)
				case .Q:
					renderState = renderStateStack.popLast() ?? RenderState()
					textState = textStateStack.popLast() ?? TextState()
					context.restoreGState()
					pendingClip = nil
				case .re(let x, let y, let w, let h):
					pathState.addRect(CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)))
					let minX = CGFloat(x)
					let minY = CGFloat(y)
					let maxX = CGFloat(x + w)
					let maxY = CGFloat(y + h)
					context.move(to: CGPoint(x: minX, y: minY))
					context.addLine(to: CGPoint(x: maxX, y: minY))
					context.addLine(to: CGPoint(x: maxX, y: maxY))
					context.addLine(to: CGPoint(x: minX, y: maxY))
					context.closePath()
				case .RG(let r, let g, let b):
					renderState.colorState.setStrokeRGB(CGFloat(r), CGFloat(g), CGFloat(b))
					renderState.colorState.applyStrokeColor(to: context)
				case .rg(let r, let g, let b):
					renderState.colorState.setFillRGB(CGFloat(r), CGFloat(g), CGFloat(b))
					renderState.colorState.applyFillColor(to: context)
				case .ri:
					break
				case .S:
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.strokePath()
					pathState.beginPath()
				case .s:
					if pathState.closeSubpath() {
						context.closePath()
					}
					applyPendingClipIfNeeded(in: context, preservePath: true)
					context.strokePath()
					pathState.beginPath()
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
				case .sh(let shadingName):
					guard let shadingDictionary = resources.resolveResourceDictionary(
						category: .Shading,
						key: shadingName,
						lookup: lookup
					) else {
						break
					}
					try cancellationCheck()
					guard
						let shading = PdfShading.parse(shadingDictionary, lookup: lookup),
						let cgShading = shading.createCGShading()
					else {
						break
					}
					context.drawShading(cgShading)
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
						let fontDictionary = resources.resolveResourceDictionary(category: .Font, key: fontKey, lookup: lookup)
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
					try context.showText(
						text,
						state: textState,
						position: &textPosition,
						lookup: lookup,
						cancellationCheck: cancellationCheck
					)
				case .TJ(let array):
					for item in array {
						try cancellationCheck()
						switch item {
						case .offset(let offset):
							// Offset is in thousandths of text space units
							let displacement = textDisplacementForTJOffset(offset, state: textState)
							let translation = CGAffineTransform(translationX: displacement, y: 0)
							textPosition.textMatrix = translation.concatenating(textPosition.textMatrix)
						case .text(let text):
							try context.showText(
								text,
								state: textState,
								position: &textPosition,
								lookup: lookup,
								cancellationCheck: cancellationCheck
							)
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
					guard let currentPoint = pathState.currentPoint else {
						break
					}
					_ = pathState.addCurve(to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)))
					context.addCurve(
						to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)),
						control1: currentPoint,
						control2: CGPoint(x: CGFloat(x2), y: CGFloat(y2))
					)
				case .w(let width):
					context.setLineWidth(CGFloat(width))
				case .W:
					pendingClip = .winding
				case .`W*`:
					pendingClip = .evenOdd
				case .y(let x2, let y2, let x3, let y3):
					guard let currentPoint = pathState.currentPoint else {
						break
					}
					_ = pathState.addCurve(to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)))
					context.addCurve(
						to: CGPoint(x: CGFloat(x3), y: CGFloat(y3)),
						control1: CGPoint(x: CGFloat(x2), y: CGFloat(y2)),
						control2: currentPoint
					)
				}
				return true
			}
		} catch is CancellationError {
			throw CancellationError()
		} catch {
			print(error)
		}

	}
}
