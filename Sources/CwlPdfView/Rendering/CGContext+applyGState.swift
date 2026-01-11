// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics

/// Represents a single clip operation applied to the graphics state
struct ClipEntry: Sendable {
	let deviceSpacePath: CGPath
	let fillRule: CGPathFillRule
}

/// Tracks the active soft mask state during rendering.
struct RenderState {
	var activeSoftMask: CGImage?
	var softMaskBounds: CGRect?
	var colorState = ColorState()
	var clipPaths: [ClipEntry] = []

	mutating func applySoftMask(_ smaskData: PdfSMask?, lookup: PdfObjectLookup?) {
		if let smaskData, let result = smaskData.createMaskImage(lookup: lookup) {
			activeSoftMask = result.image
			softMaskBounds = result.bounds
		} else {
			clearSoftMask()
		}
	}

	mutating func clearSoftMask() {
		activeSoftMask = nil
		softMaskBounds = nil
	}

	mutating func addClipPath(_ path: CGPath, ctm: CGAffineTransform, fillRule: CGPathFillRule) {
		var ctm = ctm
		guard let deviceSpacePath = path.copy(using: &ctm) else { return }
		clipPaths.append(ClipEntry(deviceSpacePath: deviceSpacePath, fillRule: fillRule))
	}
}

extension CGContext {
	func reapplyClips(renderState: RenderState, renderStack: [RenderState]) {
		let pathBackup = path
		beginPath()
		
		guard ctm.isInvertible else { return }
		var invertedCTM = ctm.inverted()
		
		for entry in [renderState.clipPaths, renderStack.flatMap(\.clipPaths)].joined() {
			let userSpacePath = entry.deviceSpacePath.copy(using: &invertedCTM) ?? entry.deviceSpacePath
			addPath(userSpacePath)
			clip(using: entry.fillRule)
		}
		
		if let pathBackup {
			addPath(pathBackup)
		}
	}

	func apply(
		_ gstate: PdfExtGState,
		renderState: inout RenderState,
		renderStack: [RenderState],
		lookup: PdfObjectLookup?
	) {
		if let alpha = gstate.strokingAlpha {
			renderState.colorState.strokeAlpha = CGFloat(alpha)
			renderState.colorState.applyStrokeColor(to: self)
		}

		if let alpha = gstate.nonStrokingAlpha {
			renderState.colorState.fillAlpha = CGFloat(alpha)
			renderState.colorState.applyFillColor(to: self)
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

		// Handle soft mask
		if gstate.softMaskNone {
			renderState.clearSoftMask()
			resetClip()
			reapplyClips(renderState: renderState, renderStack:  renderStack)
		} else if let smaskData = gstate.softMask {
			renderState.applySoftMask(smaskData, lookup: lookup)
			// Apply the mask as a clip to the current graphics context
			if let mask = renderState.activeSoftMask, let bounds = renderState.softMaskBounds {
				clip(to: bounds, mask: mask)
			}
		}
		// If neither softMaskNone nor softMask, inherit from parent (no change to renderState)
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

extension CGAffineTransform {
	var isInvertible: Bool {
		let det = a * d - b * c
		return det != 0
	}
}
