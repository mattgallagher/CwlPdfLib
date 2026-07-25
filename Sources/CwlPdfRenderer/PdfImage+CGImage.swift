// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Accelerate
import CoreGraphics
import CwlPdfParser
import Foundation
import ImageIO
import PdfiumFxcodec

extension PdfImage {
	/// Creates a CGImage from the PDF image data.
	/// - Parameters:
	///   - lookup: The object lookup for resolving indirect references (used for SMask).
	///   - applySoftMask: Whether an image SMask should be applied to the returned image.
	/// - Returns: A CGImage if successful, nil otherwise.
	public func createCGImage(lookup: PdfObjectLookup?, applySoftMask: Bool = true) -> CGImage? {
		let baseImage = switch encoding {
		case .jbig2:
			createJBIG2Image(asMask: false)
		case .jpeg:
			createJPEGImage()
		case .jpeg2000:
			createJPEG2000Image()
		case .raw:
			createRawBitmapImage()
		}
		
		guard let baseImage else {
			return nil
		}
		
		if applySoftMask,
			let softMaskStream = softMask,
			let softMaskImage = try? PdfImage(stream: softMaskStream, lookup: lookup),
			let maskCGImage = softMaskImage.createCGImage(lookup: lookup)
		{
			return self.applySoftMask(
				to: baseImage,
				mask: maskCGImage,
				matte: matteColorRGB()
			)
		}
		
		return baseImage
	}

	/// Creates a Core Graphics stencil mask from an `/ImageMask true` image.
	public func createCGImageMask() -> CGImage? {
		guard imageMask else {
			return nil
		}
		return switch encoding {
		case .jbig2:
			createJBIG2Image(asMask: true)
		case .jpeg, .jpeg2000, .raw:
			createRawMaskImage()
		}
	}

	private func createJBIG2Image(asMask: Bool) -> CGImage? {
		guard
			let jbig2Width = UInt32(exactly: width),
			let jbig2Height = UInt32(exactly: height),
			jbig2Width > 0,
			jbig2Height > 0
		else {
			return nil
		}
		let stride = pdfium_fxcodec_jbig2_stride(jbig2Width)
		guard
			stride > 0,
			height <= Int.max / stride
		else {
			return nil
		}
		var decoded = Data(count: stride * height)
		let result = decoded.withUnsafeMutableBytes { destinationBuffer in
			data.withUnsafeBytes { sourceBuffer in
				jbig2Globals.withUnsafeBytesOrNil { globalsBuffer in
					pdfium_fxcodec_jbig2_decode(
						sourceBuffer.bindMemory(to: UInt8.self).baseAddress,
						sourceBuffer.count,
						globalsBuffer?.bindMemory(to: UInt8.self).baseAddress,
						globalsBuffer?.count ?? 0,
						jbig2Width,
						jbig2Height,
						destinationBuffer.bindMemory(to: UInt8.self).baseAddress,
						destinationBuffer.count,
						stride
					)
				}
			}
		}
		guard result == PdfiumFxcodecResultSuccess else {
			return nil
		}
		guard let provider = CGDataProvider(data: decoded as CFData) else {
			return nil
		}
		let decodeValues = decode?.map { CGFloat($0) }
		return decodeValues.withUnsafeBufferPointerOrNil { decodePointer in
			if asMask {
				return CGImage(
					maskWidth: width,
					height: height,
					bitsPerComponent: 1,
					bitsPerPixel: 1,
					bytesPerRow: stride,
					provider: provider,
					decode: decodePointer?.baseAddress,
					shouldInterpolate: interpolate
				)
			}
			let cgColorSpace = createCGColorSpace() ?? CGColorSpaceCreateDeviceGray()
			return CGImage(
				width: width,
				height: height,
				bitsPerComponent: 1,
				bitsPerPixel: 1,
				bytesPerRow: stride,
				space: cgColorSpace,
				bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
				provider: provider,
				decode: decodePointer?.baseAddress,
				shouldInterpolate: interpolate,
				intent: cgRenderingIntent
			)
		}
	}

	private func createRawMaskImage() -> CGImage? {
		guard encoding == .raw else {
			return nil
		}
		let bytesPerRow = (width + 7) / 8
		guard let provider = CGDataProvider(data: data as CFData) else {
			return nil
		}
		let decodeValues = decode?.map { CGFloat($0) }
		return decodeValues.withUnsafeBufferPointerOrNil { decodePointer in
			CGImage(
				maskWidth: width,
				height: height,
				bitsPerComponent: 1,
				bitsPerPixel: 1,
				bytesPerRow: bytesPerRow,
				provider: provider,
				decode: decodePointer?.baseAddress,
				shouldInterpolate: interpolate
			)
		}
	}
	
	// MARK: - JPEG Image Creation
	
	private func createJPEGImage() -> CGImage? {
		guard let provider = CGDataProvider(data: data as CFData) else {
			return nil
		}
		let defaultDecode: [CGFloat]? = colorSpace.isCMYK ? [
			0, 1,
			0, 1,
			0, 1,
			0, 1
		] : nil
		let decodeValues = decode?.map { CGFloat($0) } ?? defaultDecode
		let image = decodeValues.withUnsafeBufferPointerOrNil { decodePointer in
			CGImage(
				jpegDataProviderSource: provider,
				decode: decodePointer?.baseAddress,
				shouldInterpolate: interpolate,
				intent: cgRenderingIntent
			)
		}
		guard let image else {
			return nil
		}
		return imageWithResolvedColorSpace(image)
	}
	
	// MARK: - JPEG 2000 Image Creation
	
	private func createJPEG2000Image() -> CGImage? {
		guard
			let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
			let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
		else {
			return nil
		}
		return imageWithResolvedColorSpace(image)
	}
	
	// MARK: - Raw Bitmap Image Creation
	
	private func createRawBitmapImage() -> CGImage? {
		guard let cgColorSpace = createCGColorSpace() else {
			return nil
		}
		
		let componentsPerPixel = colorSpace.componentsPerPixel
		let bitsPerPixel = bitsPerComponent * componentsPerPixel
		let bytesPerRow = (width * bitsPerPixel + 7) / 8
		
		let alphaInfo: CGImageAlphaInfo = .none
		
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
		
		return decodeArray.withUnsafeBufferPointerOrNil { decodePtr in
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
				intent: cgRenderingIntent
			)
		}
	}

	private var cgRenderingIntent: CGColorRenderingIntent {
		intent?.cgColorRenderingIntent ?? .defaultIntent
	}

	private func createCGColorSpace() -> CGColorSpace? {
		switch colorSpace {
		case .deviceGray:
			return CGColorSpaceCreateDeviceGray()
		case .deviceRGB:
			return CGColorSpaceCreateDeviceRGB()
		case .deviceCMYK:
			return CGColorSpaceCreateDeviceCMYK()
		case .indexed(let base, let hival, let lookupTable):
			guard
				let lookupTable,
				let baseColorSpace = base.createCGColorSpaceForImage()
			else {
				return nil
			}
			return CGColorSpace(
				indexedBaseSpace: baseColorSpace,
				last: hival,
				colorTable: [UInt8](lookupTable)
			)
		case .iccBased(let components, let profile):
			if let iccColorSpace = CGColorSpace(iccData: profile as CFData) {
				return iccColorSpace
			}
			return switch components {
			case 1: CGColorSpaceCreateDeviceGray()
			case 3: CGColorSpaceCreateDeviceRGB()
			case 4: CGColorSpaceCreateDeviceCMYK()
			default: nil
			}
		case .deviceN, .separation:
			return nil
		}
	}

	private func imageWithResolvedColorSpace(_ image: CGImage) -> CGImage? {
		let resolvedImage: CGImage
		if let cgColorSpace = createCGColorSpace() {
			resolvedImage = image.copy(colorSpace: cgColorSpace) ?? image
		} else {
			resolvedImage = image
		}
		guard
			resolvedImage.renderingIntent != cgRenderingIntent,
			let colorSpace = resolvedImage.colorSpace,
			let provider = resolvedImage.dataProvider
		else {
			return resolvedImage
		}
		return CGImage(
			width: resolvedImage.width,
			height: resolvedImage.height,
			bitsPerComponent: resolvedImage.bitsPerComponent,
			bitsPerPixel: resolvedImage.bitsPerPixel,
			bytesPerRow: resolvedImage.bytesPerRow,
			space: colorSpace,
			bitmapInfo: resolvedImage.bitmapInfo,
			provider: provider,
			decode: resolvedImage.decode,
			shouldInterpolate: interpolate,
			intent: cgRenderingIntent
		) ?? resolvedImage
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
	
	private func applySoftMask(
		to baseImage: CGImage,
		mask maskImage: CGImage,
		matte: (r: UInt8, g: UInt8, b: UInt8)? = nil
	) -> CGImage? {
		let width = baseImage.width
		let height = baseImage.height
		
		// -------------------------------------------------------------------------
		// 1. Decode base image → interleaved ARGB8888
		// -------------------------------------------------------------------------
		guard var baseBuffer = try? vImage_Buffer(cgImage: baseImage, format: .nonPremultipliedARGB) else { return nil }
		defer { baseBuffer.free() }
		
		// -------------------------------------------------------------------------
		// 2. Decode mask → Planar8 (already grayscale, no luminance step needed)
		// -------------------------------------------------------------------------
		guard var maskBuffer = try? vImage_Buffer(cgImage: maskImage, format: .gray8) else { return nil }
		defer { maskBuffer.free() }
		
		// -------------------------------------------------------------------------
		// 3. Scale mask to base image dimensions if needed
		// -------------------------------------------------------------------------
		if maskBuffer.width != vImagePixelCount(width) || maskBuffer.height != vImagePixelCount(height) {
			guard var scaled = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8) else { return nil }
			defer { scaled.free() }
			let err = vImageScale_Planar8(&maskBuffer, &scaled, nil, vImage_Flags(kvImageHighQualityResampling))
			guard err == kvImageNoError else { return nil }
			swap(&scaled, &maskBuffer)
		}
		
		// -------------------------------------------------------------------------
		// 4. vImageOverwriteChannels_ARGB8888 sets the alpha
		// -------------------------------------------------------------------------
		let err = vImageOverwriteChannels_ARGB8888(
			&maskBuffer,
			&baseBuffer,
			&baseBuffer,
			0x8, // value 0x8 represents channel 0, aka alpha
			vImage_Flags(kvImageNoFlags)
		)
		guard err == kvImageNoError else { return nil }
		
		// -------------------------------------------------------------------------
		// 5. If there's a matte — vImageAlphaBlend_ARGB8888 over the matte
		// -------------------------------------------------------------------------
		if let matte {
			guard var matteBuffer = try? vImage_Buffer(width: width, height: height, bitsPerPixel: 8) else { return nil }
			defer { matteBuffer.free() }
			vImageBufferFill_ARGB8888(&matteBuffer, [1, matte.r, matte.g, matte.b], vImage_Flags(kvImageNoFlags))
			vImageAlphaBlend_ARGB8888(&baseBuffer, &matteBuffer, &baseBuffer, vImage_Flags(kvImageNoFlags))
		}
		
		return try? baseBuffer.createCGImage(format: .nonPremultipliedARGB)
	}
}

// MARK: - vImage_CGImageFormat extensions

extension vImage_CGImageFormat {
	static var nonPremultipliedARGB: vImage_CGImageFormat {
		vImage_CGImageFormat(
			bitsPerComponent: 8,
			bitsPerPixel: 32,
			colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceRGB()),
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.first.rawValue).union(.byteOrder32Big),
			version: 0,
			decode: nil,
			renderingIntent: .defaultIntent
		)
	}
	
	static var gray8: vImage_CGImageFormat {
		vImage_CGImageFormat(
			bitsPerComponent: 8,
			bitsPerPixel: 8,
			colorSpace: Unmanaged.passRetained(CGColorSpaceCreateDeviceGray()),
			bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
			version: 0,
			decode: nil,
			renderingIntent: .defaultIntent
		)
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

private extension Optional where Wrapped == Data {
	func withUnsafeBytesOrNil<R>(_ body: (UnsafeRawBufferPointer?) throws -> R) rethrows -> R {
		guard let self else {
			return try body(nil)
		}
		return try self.withUnsafeBytes { buffer in
			try body(buffer)
		}
	}
}

private extension PdfColorSpace {
	func createCGColorSpaceForImage() -> CGColorSpace? {
		switch self {
		case .deviceGray:
			CGColorSpaceCreateDeviceGray()
		case .deviceRGB:
			CGColorSpaceCreateDeviceRGB()
		case .deviceCMYK:
			CGColorSpaceCreateDeviceCMYK()
		case .iccBased(_, let profile):
			CGColorSpace(iccData: profile as CFData)
		case .deviceN, .indexed, .separation:
			nil
		}
	}
}
