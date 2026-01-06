// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

struct GraphicsState {
	var fillColor = Color.black
	var strokeColor = Color.black
	var lineWidth: Double = 1
	var lineCap = CGLineCap.butt
	var lineJoin = CGLineJoin.miter
	var miterLimit: Double = 10
	var dashPattern = [CGFloat]()
	var dashPhase: CGFloat = 0
	var ctm = CGAffineTransform.identity
	var clippingPath = Path()
	var colorspace = CGColorSpace.sRGB
	var textState = 0
	var renderingIntent = 0
	var strokeAdjustment = 0
	var blendMode = CGBlendMode.normal
	var softMask = PdfObject.null
	var alpha: CGFloat = 1
	var alphaSource = true
	var blackPointCompensation = 0
	var overprint = true
	var overprintMode = 0
	var blackGeneration = ""
	var undercolorRemoval = ""
	var transfer = ""
	var halftone = ""
	var flatness = 0
	var smoothness = 0
}

extension PdfPage {
	func render(in context: inout GraphicsContext, objects: PdfObjectList?) {
		guard let contentStream = self.contentStream(objects: objects) else {
			return
		}
		
		var graphicsStack = [GraphicsState]()
		var graphicsState = GraphicsState()
		var path = Path()
		
		func applyStrokeStyle() -> StrokeStyle {
			if graphicsState.dashPattern.isEmpty {
				return StrokeStyle(
					lineWidth: graphicsState.lineWidth,
					lineCap: graphicsState.lineCap,
					lineJoin: graphicsState.lineJoin,
					miterLimit: graphicsState.miterLimit
				)
			} else {
				return StrokeStyle(
					lineWidth: graphicsState.lineWidth,
					lineCap: graphicsState.lineCap,
					lineJoin: graphicsState.lineJoin,
					miterLimit: graphicsState.miterLimit,
					dash: graphicsState.dashPattern,
					dashPhase: graphicsState.dashPhase
				)
			}
		}
		
		do {
			try contentStream.parse { op in
				switch op {
				case .`'`:
					break
				case .`"`(_, _, _):
					break
				case .B:
					context.fill(path, with: .color(graphicsState.fillColor))
					context.stroke(path, with: .color(graphicsState.strokeColor), style: applyStrokeStyle())
					path = Path()
				case .`B*`:
					context.fill(path, with: .color(graphicsState.fillColor), style: FillStyle(eoFill: true))
					context.stroke(path, with: .color(graphicsState.strokeColor), style: applyStrokeStyle())
					path = Path()
				case .b:
					path.closeSubpath()
					context.fill(path, with: .color(graphicsState.fillColor))
					context.stroke(path, with: .color(graphicsState.strokeColor), style: applyStrokeStyle())
					path = Path()
				case .`b*`:
					path.closeSubpath()
					context.fill(path, with: .color(graphicsState.fillColor), style: FillStyle(eoFill: true))
					context.stroke(path, with: .color(graphicsState.strokeColor), style: applyStrokeStyle())
					path = Path()
				case .BDC(_, _):
					break
				case .BI:
					break
				case .BMC(_):
					break
				case .BT:
					break
				case .BX:
					break
				case .c(let x1, let y1, let x2, let y2, let x3, let y3):
					path.addCurve(to: CGPoint(x: x3, y: y3), control1: CGPoint(x: x1, y: y1), control2: CGPoint(x: x2, y: y2))
				case .cm(let a, let b, let c, let d, let tx, let ty):
					context.concatenate(CGAffineTransform(
						a: CGFloat(a),
						b: CGFloat(b),
						c: CGFloat(c),
						d: CGFloat(d),
						tx: CGFloat(tx),
						ty: CGFloat(ty)
					))
				case .CS(_):
					break
				case .cs(_):
					break
				case .d(let phase, let array):
					graphicsState.dashPattern = array.map { CGFloat($0) }
					graphicsState.dashPhase = CGFloat(phase)
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
					break
				case .EX:
					break
				case .F:
					context.fill(path, with: .color(graphicsState.fillColor))
					path = Path()
				case .f:
					context.fill(path, with: .color(graphicsState.fillColor))
					path = Path()
				case .`f*`:
					context.fill(path, with: .color(graphicsState.fillColor), style: FillStyle(eoFill: true))
					path = Path()
				case .G(let gray):
					graphicsState.strokeColor = Color(white: gray)
				case .g(let gray):
					graphicsState.fillColor = Color(white: gray)
				case .gs(_):
					break
				case .h:
					path.closeSubpath()
				case .i(_):
					break
				case .ID:
					break
				case .J(let style):
					graphicsState.lineCap = switch style {
					case 0: .butt
					case 1: .round
					case 2: .square
					default: .butt
					}
				case .j(let style):
					graphicsState.lineJoin = switch style {
					case 0: .miter
					case 1: .round
					case 2: .bevel
					default: .miter
					}
				case .K(let c, let m, let y, let k):
					graphicsState.strokeColor = Color(.displayP3, red: 1 - c, green: 1 - m, blue: 1 - y).opacity(1 - k)
				case .k(let c, let m, let y, let k):
					graphicsState.fillColor = Color(.displayP3, red: 1 - c, green: 1 - m, blue: 1 - y).opacity(1 - k)
				case .l(let x, let y):
					path.addLine(to: CGPoint(x: x, y: y))
				case .M(let limit):
					graphicsState.miterLimit = limit
				case .m(let x, let y):
					path.move(to: CGPoint(x: x, y: y))
				case .MP(_):
					break
				case .n:
					path = Path()
				case .q:
					graphicsState.ctm = context.transform
					graphicsStack.append(graphicsState)
				case .Q:
					graphicsState = graphicsStack.popLast() ?? graphicsState
					context.transform = graphicsState.ctm
				case .re(let x, let y, let w, let h):
					path.addRect(CGRect(x: x, y: y, width: w, height: h))
				case .RG(let r, let g, let b):
					graphicsState.strokeColor = Color(.displayP3, red: r, green: g, blue: b)
				case .rg(let r, let g, let b):
					graphicsState.fillColor = Color(.displayP3, red: r, green: g, blue: b)
				case .ri(_):
					break
				case .S:
					context.stroke(path, with: .color(graphicsState.strokeColor), style: applyStrokeStyle())
					path = Path()
				case .s:
					path.closeSubpath()
					context.stroke(path, with: .color(graphicsState.strokeColor), style: applyStrokeStyle())
					path = Path()
				case .SC(let colors):
					graphicsState.strokeColor = Color(.displayP3, red: CGFloat(colors[0]), green: CGFloat(colors[1]), blue: CGFloat(colors[2]))
				case .sc(let colors):
					graphicsState.fillColor = Color(.displayP3, red: CGFloat(colors[0]), green: CGFloat(colors[1]), blue: CGFloat(colors[2]))
				case .SCN(_):
					break
				case .scn(_):
					break
				case .sh(_):
					break
				case .Tc(_):
					break
				case .Td(_, _):
					break
				case .TD(_, _):
					break
				case .Tf(_, _):
					break
				case .Tj(_):
					break
				case .TJ(_):
					break
				case .TL(_):
					break
				case .Tm(_, _, _, _, _, _):
					break
				case .Tr(_):
					break
				case .Ts(_):
					break
				case .Tw(_):
					break
				case .Tz(_):
					break
				case .`T*`:
					break
				case .v(let x2, let y2, let x3, let y3):
					let currentPoint = path.currentPoint ?? .zero
					path.addCurve(to: CGPoint(x: x3, y: y3), control1: currentPoint, control2: CGPoint(x: x2, y: y2))
				case .w(let width):
					graphicsState.lineWidth = width
				case .W:
					break
				case .`W*`:
					break
				case .y(let x2, let y2, let x3, let y3):
					let currentPoint = path.currentPoint ?? .zero
					path.addCurve(to: CGPoint(x: x3, y: y3), control1: CGPoint(x: x2, y: y2), control2: currentPoint)
				}
				return true
			}
		} catch {
			print(error)
		}
	}
}
