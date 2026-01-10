// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics

extension CGContext {
	func apply(_ gstate: PdfGState, colorState: inout ColorState) {
		if let alpha = gstate.strokingAlpha {
			colorState.strokeAlpha = CGFloat(alpha)
			colorState.applyStrokeColor(to: self)
		}

		if let alpha = gstate.nonStrokingAlpha {
			colorState.fillAlpha = CGFloat(alpha)
			colorState.applyFillColor(to: self)
		}

		if let blendMode = gstate.blendMode {
			setBlendMode(blendMode.cgBlendMode)
		}

		if let lineWidth = gstate.lineWidth {
			setLineWidth(CGFloat(lineWidth))
		}

		if let lineCap = gstate.lineCap {
			let cap: CGLineCap = switch lineCap {
			case 0: .butt
			case 1: .round
			case 2: .square
			default: .butt
			}
			setLineCap(cap)
		}

		if let lineJoin = gstate.lineJoin {
			let join: CGLineJoin = switch lineJoin {
			case 0: .miter
			case 1: .round
			case 2: .bevel
			default: .miter
			}
			setLineJoin(join)
		}

		if let miterLimit = gstate.miterLimit {
			setMiterLimit(CGFloat(miterLimit))
		}

		if let (phase, lengths) = gstate.dashPattern {
			setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
		}

		if let flatness = gstate.flatness {
			setFlatness(CGFloat(flatness))
		}
	}
}

extension PdfBlendMode {
	var cgBlendMode: CGBlendMode {
		switch self {
		case .normal: .normal
		case .multiply: .multiply
		case .screen: .screen
		case .overlay: .overlay
		case .darken: .darken
		case .lighten: .lighten
		case .colorDodge: .colorDodge
		case .colorBurn: .colorBurn
		case .hardLight: .hardLight
		case .softLight: .softLight
		case .difference: .difference
		case .exclusion: .exclusion
		case .hue: .hue
		case .saturation: .saturation
		case .color: .color
		case .luminosity: .luminosity
		}
	}
}
