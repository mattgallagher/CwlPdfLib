// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics

struct ColorState {
	var strokeColorSpace: PdfColorSpace = .deviceRGB
	var strokeComponents: [CGFloat] = [0]
	var strokeAlpha: CGFloat = 1

	var fillColorSpace: PdfColorSpace = .deviceRGB
	var fillComponents: [CGFloat] = [0]
	var fillAlpha: CGFloat = 1

	mutating func setStrokeGray(_ gray: CGFloat) {
		strokeColorSpace = .deviceGray
		strokeComponents = [gray]
	}

	mutating func setFillGray(_ gray: CGFloat) {
		fillColorSpace = .deviceGray
		fillComponents = [gray]
	}

	mutating func setStrokeRGB(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
		strokeColorSpace = .deviceRGB
		strokeComponents = [r, g, b]
	}

	mutating func setFillRGB(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
		fillColorSpace = .deviceRGB
		fillComponents = [r, g, b]
	}

	mutating func setStrokeCMYK(_ c: CGFloat, _ m: CGFloat, _ y: CGFloat, _ k: CGFloat) {
		strokeColorSpace = .deviceCMYK
		strokeComponents = [c, m, y, k]
	}

	mutating func setFillCMYK(_ c: CGFloat, _ m: CGFloat, _ y: CGFloat, _ k: CGFloat) {
		fillColorSpace = .deviceCMYK
		fillComponents = [c, m, y, k]
	}

	mutating func setStrokeColor(_ components: [CGFloat]) {
		strokeComponents = components
	}

	mutating func setFillColor(_ components: [CGFloat]) {
		fillComponents = components
	}

	func applyStrokeColor(to context: CGContext) {
		if let color = createCGColor(colorSpace: strokeColorSpace, components: strokeComponents, alpha: strokeAlpha) {
			context.setStrokeColor(color)
		}
	}

	func applyFillColor(to context: CGContext) {
		if let color = createCGColor(colorSpace: fillColorSpace, components: fillComponents, alpha: fillAlpha) {
			context.setFillColor(color)
		}
	}

	private func createCGColor(colorSpace: PdfColorSpace, components: [CGFloat], alpha: CGFloat) -> CGColor? {
		switch colorSpace {
		case .deviceGray:
			let gray = components.first ?? 0
			return CGColor(gray: gray, alpha: alpha)
		case .deviceRGB:
			guard components.count >= 3 else { return nil }
			return CGColor(red: components[0], green: components[1], blue: components[2], alpha: alpha)
		case .deviceCMYK:
			guard components.count >= 4, let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else { return nil }
			var cmykComponents = components.prefix(4).map { $0 }
			cmykComponents.append(alpha)
			return CGColor(colorSpace: cmykSpace, components: cmykComponents)
		case .iccBased(let componentCount, let profile):
			guard components.count >= componentCount else { return nil }
			if let provider = CGDataProvider(data: profile as CFData),
			   let iccColorSpace = CGColorSpace(iccData: provider) {
				var colorComponents = Array(components.prefix(componentCount))
				colorComponents.append(alpha)
				return CGColor(colorSpace: iccColorSpace, components: colorComponents)
			}
			// Fallback based on component count
			return createFallbackColor(componentCount: componentCount, components: components, alpha: alpha)
		case .indexed(let base, _, let lookup):
			// For indexed colors, look up the actual color from the palette
			guard let index = components.first.map({ Int($0) }), let lookupData = lookup else {
				return createCGColor(colorSpace: base, components: components, alpha: alpha)
			}
			let baseComponents = base.componentsPerPixel
			let offset = index * baseComponents
			guard offset + baseComponents <= lookupData.count else {
				return createCGColor(colorSpace: base, components: components, alpha: alpha)
			}
			let paletteComponents = (0..<baseComponents).map { i in
				CGFloat(lookupData[offset + i]) / 255.0
			}
			return createCGColor(colorSpace: base, components: paletteComponents, alpha: alpha)
		}
	}

	private func createFallbackColor(componentCount: Int, components: [CGFloat], alpha: CGFloat) -> CGColor? {
		switch componentCount {
		case 1:
			return CGColor(gray: components.first ?? 0, alpha: alpha)
		case 3:
			guard components.count >= 3 else { return nil }
			return CGColor(red: components[0], green: components[1], blue: components[2], alpha: alpha)
		case 4:
			guard components.count >= 4, let cmykSpace = CGColorSpace(name: CGColorSpace.genericCMYK) else { return nil }
			var cmykComponents = Array(components.prefix(4))
			cmykComponents.append(alpha)
			return CGColor(colorSpace: cmykSpace, components: cmykComponents)
		default:
			return nil
		}
	}
}
