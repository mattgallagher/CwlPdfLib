// CwlPdfView. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfSMask {
	/// Renders the transparency group and extracts a grayscale mask image.
	/// - Parameter lookup: The object lookup for resolving indirect references.
	/// - Returns: A grayscale CGImage to be used as a soft mask, or nil if creation fails.
	func createMaskImage(lookup: PdfObjectLookup?) -> (image: CGImage, bounds: CGRect)? {
		// Get bounding box from transparency group
		guard let bboxArray = transparencyGroup.dictionary[.BBox]?.array(lookup: lookup),
			  let bbox = PdfRect(array: bboxArray, lookup: lookup) else {
			return nil
		}

		let cgBBox = bbox.cgRect
		let width = Int(ceil(cgBBox.width))
		let height = Int(ceil(cgBBox.height))

		guard width > 0, height > 0 else { return nil }

		// Create RGBA bitmap context to render the transparency group
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		guard let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width * 4,
			space: colorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			return nil
		}

		// Apply backdrop color if specified
		if let bc = backdropColor {
			let bcColor = createBackdropCGColor(bc)
			context.setFillColor(bcColor)
			context.fill(CGRect(x: 0, y: 0, width: width, height: height))
		}

		// Transform to match bbox coordinate system
		context.translateBy(x: -cgBBox.minX, y: -cgBBox.minY)

		// Render the transparency group
		let contentStream = PdfContentStream(
			stream: transparencyGroup,
			resources: nil,
			annotationRect: nil,
			lookup: lookup
		)
		contentStream.render(in: context, lookup: lookup)

		// Extract mask based on subtype
		guard let renderedImage = context.makeImage() else {
			return nil
		}

		guard let maskImage = extractMask(from: renderedImage) else {
			return nil
		}

		return (maskImage, cgBBox)
	}

	private func createBackdropCGColor(_ components: [Double]) -> CGColor {
		switch components.count {
		case 1:
			return CGColor(gray: CGFloat(components[0]), alpha: 1.0)
		case 3:
			return CGColor(
				red: CGFloat(components[0]),
				green: CGFloat(components[1]),
				blue: CGFloat(components[2]),
				alpha: 1.0
			)
		case 4:
			if let space = CGColorSpace(name: CGColorSpace.genericCMYK) {
				let cmykComponents = components.map { CGFloat($0) } + [1.0]
				return CGColor(colorSpace: space, components: cmykComponents) ?? .black
			}
			return .black
		default:
			return .black
		}
	}

	private func extractMask(from image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height

		// Create grayscale context for mask
		let graySpace = CGColorSpaceCreateDeviceGray()
		guard let grayContext = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: width,
			space: graySpace,
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		) else {
			return nil
		}

		// Get pixel data from rendered image
		guard let rgbaData = image.dataProvider?.data,
			  let rgbaPtr = CFDataGetBytePtr(rgbaData) else {
			return nil
		}

		// Get gray context pixel buffer
		guard let grayData = grayContext.data else {
			return nil
		}
		let grayPtr = grayData.bindMemory(to: UInt8.self, capacity: width * height)

		let rgbaLength = CFDataGetLength(rgbaData)
		let expectedLength = width * height * 4

		// Verify we have enough data
		guard rgbaLength >= expectedLength else {
			return nil
		}

		// Convert based on subtype
		for y in 0..<height {
			for x in 0..<width {
				let rgbaOffset = (y * width + x) * 4
				let grayOffset = y * width + x

				let r = rgbaPtr[rgbaOffset]
				let g = rgbaPtr[rgbaOffset + 1]
				let b = rgbaPtr[rgbaOffset + 2]
				let a = rgbaPtr[rgbaOffset + 3]

				let maskValue: UInt8
				switch subtype {
				case .alpha:
					// Use alpha channel directly
					maskValue = a
				case .luminosity:
					// Convert RGB to luminosity
					// L = 0.2126*R + 0.7152*G + 0.0722*B
					let luminosity = 0.2126 * Double(r) + 0.7152 * Double(g) + 0.0722 * Double(b)
					maskValue = UInt8(min(255, max(0, luminosity)))
				}

				grayPtr[grayOffset] = maskValue
			}
		}

		return grayContext.makeImage()
	}
}
