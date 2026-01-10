// CwlPdfView. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

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
			return createJPEGImage()
		case .jpeg2000:
			return createJPEG2000Image()
		case .raw:
			return createRawBitmapImage(lookup: lookup)
		}
	}

	// MARK: - JPEG Image Creation

	private func createJPEGImage() -> CGImage? {
		guard let provider = CGDataProvider(data: data as CFData) else {
			return nil
		}
		return CGImage(
			jpegDataProviderSource: provider,
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
		let bitmapInfo: CGBitmapInfo
		switch colorSpace {
		case .deviceCMYK:
			bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
		case .iccBased(let components, _) where components == 4:
			bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
		default:
			bitmapInfo = CGBitmapInfo(rawValue: alphaInfo.rawValue)
		}

		guard let provider = CGDataProvider(data: data as CFData) else {
			return nil
		}

		// Create decode array for CGImage if needed
		var decodeArray: [CGFloat]?
		if let decode = self.decode {
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
		   let maskCGImage = softMaskImage.createCGImage(lookup: lookup) {
			return baseImage.masking(maskCGImage)
		}

		return baseImage
	}
}

// MARK: - Helper Extensions

private extension Optional where Wrapped: Collection {
	func withUnsafeBufferPointerOrNil<R>(_ body: (UnsafeBufferPointer<Wrapped.Element>?) throws -> R) rethrows -> R {
		guard let self = self else {
			return try body(nil)
		}
		return try Array(self).withUnsafeBufferPointer { ptr in
			try body(ptr)
		}
	}
}
