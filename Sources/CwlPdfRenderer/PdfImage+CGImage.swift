// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Accelerate
import CoreGraphics
import CwlPdfParser
import Foundation
import ImageIO

extension PdfImage {
	/// Creates a CGImage from the PDF image data.
	/// - Parameter lookup: The object lookup for resolving indirect references (used for SMask).
	/// - Returns: A CGImage if successful, nil otherwise.
	public func createCGImage(lookup: PdfObjectLookup?) -> CGImage? {
		switch encoding {
		case .jpeg:
			createJPEGImage()
		case .jpeg2000:
			createJPEG2000Image()
		case .raw:
			createRawBitmapImage(lookup: lookup)
		}
	}

	// MARK: - JPEG Image Creation

	private func createJPEGImage() -> CGImage? {
		// Use ImageIO for more robust JPEG decoding
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
				let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
		else {
			return nil
		}

		// CMYK JPEGs in PDFs typically have inverted color values (0=full color, 255=no color)
		// Check if we need to invert the CMYK data
		if colorSpace.isCMYK {
			return invertCMYKImage(image)
		}

		return image
	}

	/// Inverts CMYK color values in an image (255 - value for each component)
	private func invertCMYKImage(_ image: CGImage) -> CGImage? {
		let width = image.width
		let height = image.height
		let bytesPerPixel = 4
		let bytesPerRow = width * bytesPerPixel
		let totalBytes = height * bytesPerRow

		// Create a buffer for the pixel data
		var pixelData = [UInt8](repeating: 0, count: totalBytes)

		// Create a CMYK color space and bitmap context
		let cmykColorSpace = CGColorSpaceCreateDeviceCMYK()
		guard let context = CGContext(
			data: &pixelData,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: cmykColorSpace,
			bitmapInfo: CGImageAlphaInfo.none.rawValue
		) else {
			return nil
		}

		// Draw the original image into the context to get CMYK pixel data
		context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

		// Invert all CMYK values
		for i in 0..<totalBytes {
			pixelData[i] = 255 - pixelData[i]
		}

		// Create a new image from the inverted data
		guard let provider = CGDataProvider(data: Data(pixelData) as CFData) else {
			return nil
		}

		return CGImage(
			width: width,
			height: height,
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			bytesPerRow: bytesPerRow,
			space: cmykColorSpace,
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
			provider: provider,
			decode: nil,
			shouldInterpolate: interpolate,
			intent: .defaultIntent
		)
	}

	// MARK: - JPEG 2000 Image Creation

	private func createJPEG2000Image() -> CGImage? {
		// Use ImageIO for JPEG 2000 decoding
		guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
			return nil
		}
		return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
	}

	// MARK: - Raw Bitmap Image Creation

	private func createRawBitmapImage(lookup: PdfObjectLookup?) -> CGImage? {
		let cgColorSpace: CGColorSpace

		switch colorSpace {
		case .deviceGray:
			cgColorSpace = CGColorSpaceCreateDeviceGray()

		case .deviceRGB:
			cgColorSpace = CGColorSpaceCreateDeviceRGB()

		case .deviceCMYK:
			cgColorSpace = CGColorSpaceCreateDeviceCMYK()

		case .indexed(let base, let hival, let lookupTable):
			// Create indexed color space
			guard let lookupTable else {
				return nil
			}
			let baseColorSpace: CGColorSpace
			switch base {
			case .deviceGray:
				baseColorSpace = CGColorSpaceCreateDeviceGray()
			case .deviceRGB:
				baseColorSpace = CGColorSpaceCreateDeviceRGB()
			case .deviceCMYK:
				baseColorSpace = CGColorSpaceCreateDeviceCMYK()
			default:
				// Nested indexed or ICC-based not supported as indexed base
				return nil
			}

			guard let indexedSpace = CGColorSpace(
				indexedBaseSpace: baseColorSpace,
				last: hival,
				colorTable: [UInt8](lookupTable)
			) else {
				return nil
			}
			cgColorSpace = indexedSpace

		case .iccBased(let components, let profile):
			// Try to create color space from ICC profile using modern API
			if let iccColorSpace = profile.withUnsafeBytes({ bytes in
				CGColorSpace(iccData: Data(bytes) as CFData)
			}) {
				cgColorSpace = iccColorSpace
			} else {
				// Fallback based on component count
				switch components {
				case 1: cgColorSpace = CGColorSpaceCreateDeviceGray()
				case 3: cgColorSpace = CGColorSpaceCreateDeviceRGB()
				case 4: cgColorSpace = CGColorSpaceCreateDeviceCMYK()
				default: return nil
				}
			}
		}

		let componentsPerPixel = colorSpace.componentsPerPixel
		let bitsPerPixel = bitsPerComponent * componentsPerPixel
		let bytesPerRow = (width * bitsPerPixel + 7) / 8

		// Handle soft mask if present
		var alphaInfo: CGImageAlphaInfo = .none
		if softMask != nil {
			// We'll apply the soft mask after creating the base image
			alphaInfo = .none
		}

		// Determine bitmap info based on color space
		let bitmapInfo = switch colorSpace {
		case .deviceCMYK:
			CGBitmapInfo(rawValue: alphaInfo.rawValue)
		case .iccBased(let components, _) where components == 4:
			CGBitmapInfo(rawValue: alphaInfo.rawValue)
		default:
			CGBitmapInfo(rawValue: alphaInfo.rawValue)
		}

		guard let provider = CGDataProvider(data: data as CFData) else {
			return nil
		}

		// Create decode array for CGImage if needed
		var decodeArray: [CGFloat]?
		if let decode {
			decodeArray = decode.map { CGFloat($0) }
		}

		let baseImage = decodeArray.withUnsafeBufferPointerOrNil { decodePtr in
			CGImage(
				width: width,
				height: height,
				bitsPerComponent: bitsPerComponent,
				bitsPerPixel: bitsPerPixel,
				bytesPerRow: bytesPerRow,
				space: cgColorSpace,
				bitmapInfo: bitmapInfo,
				provider: provider,
				decode: decodePtr?.baseAddress,
				shouldInterpolate: interpolate,
				intent: .defaultIntent
			)
		}

		guard let baseImage else {
			return nil
		}

		// Apply soft mask if present
		if let softMaskStream = softMask,
			let softMaskImage = try? PdfImage(stream: softMaskStream, lookup: lookup),
			let maskCGImage = softMaskImage.createCGImage(lookup: lookup)
		{
			if let matteColor = matteColorRGB() {
				return applySoftMaskWithMatte(baseImage: baseImage, maskImage: maskCGImage, matteColor: matteColor)
			} else {
				return baseImage.masking(maskCGImage)
			}
		}

		return baseImage
	}

	private func matteColorRGB() -> (r: UInt8, g: UInt8, b: UInt8)? {
		guard let matte else {
			return nil
		}

		switch colorSpace {
		case .deviceGray:
			guard let value = matte.first else { return nil }
			let gray = UInt8((min(1, max(0, value)) * 255).rounded())
			return (gray, gray, gray)
		case .deviceRGB, .iccBased(3, _), .indexed(.deviceRGB, _, _):
			guard matte.count >= 3 else { return nil }
			return (
				UInt8((min(1, max(0, matte[0])) * 255).rounded()),
				UInt8((min(1, max(0, matte[1])) * 255).rounded()),
				UInt8((min(1, max(0, matte[2])) * 255).rounded())
			)
		case .deviceCMYK, .iccBased(4, _):
			guard matte.count >= 4 else { return nil }
			let c = min(1, max(0, matte[0]))
			let m = min(1, max(0, matte[1]))
			let y = min(1, max(0, matte[2]))
			let k = min(1, max(0, matte[3]))
			let r = UInt8((((1 - c) * (1 - k)) * 255).rounded())
			let g = UInt8((((1 - m) * (1 - k)) * 255).rounded())
			let b = UInt8((((1 - y) * (1 - k)) * 255).rounded())
			return (r, g, b)
		default:
			guard matte.count >= 3 else { return nil }
			return (
				UInt8((min(1, max(0, matte[0])) * 255).rounded()),
				UInt8((min(1, max(0, matte[1])) * 255).rounded()),
				UInt8((min(1, max(0, matte[2])) * 255).rounded())
			)
		}
	}

	private func applySoftMaskWithMatte(baseImage: CGImage, maskImage: CGImage, matteColor: (r: UInt8, g: UInt8, b: UInt8)) -> CGImage? {
		let width = baseImage.width
		let height = baseImage.height
		guard
			width > 0,
			height > 0
		else {
			return nil
		}

		var argbPixels = [UInt8](repeating: 0, count: width * height * 4)
		guard
			let argbContext = CGContext(
				data: &argbPixels,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: width * 4,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
			)
		else {
			return nil
		}
		argbContext.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

		var maskPixels = [UInt8](repeating: 0, count: width * height)
		guard
			let maskContext = CGContext(
				data: &maskPixels,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: width,
				space: CGColorSpaceCreateDeviceGray(),
				bitmapInfo: CGImageAlphaInfo.none.rawValue
			)
		else {
			return nil
		}
		maskContext.draw(maskImage, in: CGRect(x: 0, y: 0, width: width, height: height))

		var argbBuffer = argbPixels.withUnsafeMutableBufferPointer {
			vImage_Buffer(
				data: $0.baseAddress,
				height: vImagePixelCount(height),
				width: vImagePixelCount(width),
				rowBytes: width * 4
			)
		}

		var alphaBuffer = maskPixels.withUnsafeMutableBufferPointer {
			vImage_Buffer(
				data: $0.baseAddress,
				height: vImagePixelCount(height),
				width: vImagePixelCount(width),
				rowBytes: width
			)
		}

		guard
			var red = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8),
			var green = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8),
			var blue = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8),
			var alpha = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8)
		else {
			return nil
		}
		defer {
			red.free()
			green.free()
			blue.free()
			alpha.free()
		}

		vImageConvert_ARGB8888toPlanar8(&argbBuffer, &alpha, &red, &green, &blue, vImage_Flags(kvImageNoFlags))
		vImageCopyBuffer(&alphaBuffer, &alpha, 1, vImage_Flags(kvImageNoFlags))

		let pixelCount = width * height
		let redPtr = red.data.assumingMemoryBound(to: UInt8.self)
		let greenPtr = green.data.assumingMemoryBound(to: UInt8.self)
		let bluePtr = blue.data.assumingMemoryBound(to: UInt8.self)
		let alphaPtr = alpha.data.assumingMemoryBound(to: UInt8.self)
		let matteR = Int(matteColor.r)
		let matteG = Int(matteColor.g)
		let matteB = Int(matteColor.b)

		for index in 0..<pixelCount {
			let alphaValue = Int(alphaPtr[index])
			let invAlpha = 255 - alphaValue

			let correctedR = Int(redPtr[index]) - (invAlpha * matteR + 127) / 255
			let correctedG = Int(greenPtr[index]) - (invAlpha * matteG + 127) / 255
			let correctedB = Int(bluePtr[index]) - (invAlpha * matteB + 127) / 255

			redPtr[index] = UInt8(min(255, max(0, correctedR)))
			greenPtr[index] = UInt8(min(255, max(0, correctedG)))
			bluePtr[index] = UInt8(min(255, max(0, correctedB)))
		}

		vImageConvert_Planar8toARGB8888(&alpha, &red, &green, &blue, &argbBuffer, vImage_Flags(kvImageNoFlags))

		guard
			let outputContext = CGContext(
				data: &argbPixels,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: width * 4,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
			)
		else {
			return nil
		}

		return outputContext.makeImage()
	}
}

// MARK: - Helper Extensions

private extension Optional where Wrapped: Collection {
	func withUnsafeBufferPointerOrNil<R>(_ body: (UnsafeBufferPointer<Wrapped.Element>?) throws -> R) rethrows -> R {
		guard let self else {
			return try body(nil)
		}
		return try Array(self).withUnsafeBufferPointer { ptr in
			try body(ptr)
		}
	}
}
