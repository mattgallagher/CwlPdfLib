// CwlPdfView. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Accelerate
import CoreGraphics
import CwlPdfParser

extension PdfSMask {
	/// Renders the transparency group and extracts a grayscale mask image.
	/// - Parameter lookup: The object lookup for resolving indirect references.
	/// - Returns: A grayscale CGImage to be used as a soft mask, or nil if creation fails.
	func createMaskImage(lookup: PdfObjectLookup?) -> (image: CGImage, bounds: CGRect)? {
		// Get bounding box from transparency group
		guard
			let bboxArray = transparencyGroup.dictionary[.BBox]?.array(lookup: lookup),
			let bbox = PdfRect(array: bboxArray, lookup: lookup)
		else {
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
		
		switch subtype {
		case .alpha:
			// For alpha, we need the alpha channel specifically
			// vImage is ideal here
			guard
				var sourceBuffer = try? vImage_Buffer(cgImage: image),
				var destBuffer = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
			else {
				return nil
			}
			defer {
				sourceBuffer.free()
				destBuffer.free()
			}
			vImageExtractChannel_ARGB8888(&sourceBuffer, &destBuffer, 3, vImage_Flags(kvImageNoFlags))
			
			let grayFormat = vImage_CGImageFormat(
				bitsPerComponent: 8,
				bitsPerPixel: 8,
				colorSpace: CGColorSpaceCreateDeviceGray(),
				bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
			)!
			return try? destBuffer.createCGImage(format: grayFormat)
			
		case .luminosity:
			// Let CoreGraphics handle color-managed conversion to grayscale
			let graySpace = CGColorSpaceCreateDeviceGray()
			guard let grayContext = CGContext(
				data: nil,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: width,
				space: graySpace,
				bitmapInfo: CGImageAlphaInfo.none.rawValue
			) else { return nil }
			
			grayContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
			return grayContext.makeImage()
		}
	}
}
