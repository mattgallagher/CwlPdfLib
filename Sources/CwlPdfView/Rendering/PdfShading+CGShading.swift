// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CoreGraphics

extension PdfShading {
	/// Creates a CGShading from this PDF shading definition.
	func createCGShading() -> CGShading? {
		switch self {
		case .axial(let axial):
			return createAxialShading(axial)
		case .radial(let radial):
			return createRadialShading(radial)
		}
	}

	private func createAxialShading(_ shading: AxialShading) -> CGShading? {
		guard let cgColorSpace = createCGColorSpace(from: shading.colorSpace) else {
			return nil
		}

		let componentCount = shading.colorSpace.componentsPerPixel

		// Create the shading function that evaluates the PDF function
		guard let cgFunction = createShadingFunction(
			function: shading.function,
			domain: shading.domain,
			componentCount: componentCount
		) else {
			return nil
		}

		return CGShading(
			axialSpace: cgColorSpace,
			start: CGPoint(x: shading.coords.x0, y: shading.coords.y0),
			end: CGPoint(x: shading.coords.x1, y: shading.coords.y1),
			function: cgFunction,
			extendStart: shading.extend.start,
			extendEnd: shading.extend.end
		)
	}

	private func createRadialShading(_ shading: RadialShading) -> CGShading? {
		guard let cgColorSpace = createCGColorSpace(from: shading.colorSpace) else {
			return nil
		}

		let componentCount = shading.colorSpace.componentsPerPixel

		// Create the shading function that evaluates the PDF function
		guard let cgFunction = createShadingFunction(
			function: shading.function,
			domain: shading.domain,
			componentCount: componentCount
		) else {
			return nil
		}

		return CGShading(
			radialSpace: cgColorSpace,
			start: CGPoint(x: shading.coords.x0, y: shading.coords.y0),
			startRadius: CGFloat(shading.coords.r0),
			end: CGPoint(x: shading.coords.x1, y: shading.coords.y1),
			endRadius: CGFloat(shading.coords.r1),
			function: cgFunction,
			extendStart: shading.extend.start,
			extendEnd: shading.extend.end
		)
	}

	private func createCGColorSpace(from colorSpace: PdfColorSpace) -> CGColorSpace? {
		switch colorSpace {
		case .deviceGray:
			return CGColorSpaceCreateDeviceGray()
		case .deviceRGB:
			return CGColorSpaceCreateDeviceRGB()
		case .deviceCMYK:
			return CGColorSpace(name: CGColorSpace.genericCMYK)
		case .iccBased(let components, let profile):
			if let provider = CGDataProvider(data: profile as CFData),
			   let iccColorSpace = CGColorSpace(iccData: provider) {
				return iccColorSpace
			}
			// Fallback based on component count
			switch components {
			case 1: return CGColorSpaceCreateDeviceGray()
			case 3: return CGColorSpaceCreateDeviceRGB()
			case 4: return CGColorSpace(name: CGColorSpace.genericCMYK)
			default: return CGColorSpaceCreateDeviceRGB()
			}
		case .indexed:
			// Indexed color spaces need special handling - use base color space
			return CGColorSpaceCreateDeviceRGB()
		}
	}

	private func createShadingFunction(
		function: PdfFunction,
		domain: (t0: Double, t1: Double),
		componentCount: Int
	) -> CGFunction? {
		// Allocate info on the heap so it survives beyond this function
		let info = ShadingFunctionInfo(function: function, componentCount: componentCount)
		let infoPtr = UnsafeMutablePointer<ShadingFunctionInfo>.allocate(capacity: 1)
		infoPtr.initialize(to: info)

		var callbacks = CGFunctionCallbacks(
			version: 0,
			evaluate: { infoPtr, input, output in
				guard let infoPtr else { return }
				let info = infoPtr.assumingMemoryBound(to: ShadingFunctionInfo.self).pointee
				let t = Double(input[0])

				if let result = info.function.evaluate([t]) {
					for i in 0..<min(result.count, info.componentCount) {
						output[i] = CGFloat(result[i])
					}
					// Fill remaining components with 0 if function returns fewer values
					for i in result.count..<info.componentCount {
						output[i] = 0
					}
				} else {
					// Default to black/transparent on error
					for i in 0..<info.componentCount {
						output[i] = 0
					}
				}
			},
			releaseInfo: { infoPtr in
				guard let infoPtr else { return }
				let typed = infoPtr.assumingMemoryBound(to: ShadingFunctionInfo.self)
				typed.deinitialize(count: 1)
				typed.deallocate()
			}
		)

		let domainValues: [CGFloat] = [CGFloat(domain.t0), CGFloat(domain.t1)]
		let rangeValues: [CGFloat] = (0..<componentCount).flatMap { _ in [CGFloat(0), CGFloat(1)] }

		return CGFunction(
			info: infoPtr,
			domainDimension: 1,
			domain: domainValues,
			rangeDimension: componentCount,
			range: rangeValues,
			callbacks: &callbacks
		)
	}
}

/// Helper class to pass function info to the CGFunction callback
private struct ShadingFunctionInfo {
	let function: PdfFunction
	let componentCount: Int
}
