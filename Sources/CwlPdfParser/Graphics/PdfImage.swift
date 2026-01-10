// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfImage: Sendable {
	public let width: Int
	public let height: Int
	public let bitsPerComponent: Int
	public let colorSpace: PdfColorSpace
	public let data: Data
	public let encoding: ImageEncoding
	public let decode: [Double]?
	public let interpolate: Bool
	public let intent: String?
	public let imageMask: Bool
	public let softMask: PdfStream?

	public init(stream: PdfStream, lookup: PdfObjectLookup?) throws {
		let dict = stream.dictionary

		guard
			let width = dict[.Width]?.integer(lookup: lookup),
			let height = dict[.Height]?.integer(lookup: lookup)
		else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		self.width = width
		self.height = height

		// ImageMask images don't have BitsPerComponent (implicitly 1) or ColorSpace
		self.imageMask = dict[.ImageMask]?.boolean(lookup: lookup) ?? false

		if imageMask {
			self.bitsPerComponent = 1
			self.colorSpace = .deviceGray
		} else {
			self.bitsPerComponent = dict[.BitsPerComponent]?.integer(lookup: lookup) ?? 8
			self.colorSpace = Self.parseColorSpace(dict[.ColorSpace], lookup: lookup) ?? .deviceRGB
		}

		// Parse the filter to determine encoding
		self.encoding = Self.parseEncoding(dict[.Filter], lookup: lookup)

		// The stream data - may be encoded (JPEG) or decoded (raw bitmap)
		self.data = stream.data

		// Optional decode array for mapping sample values
		self.decode = dict[.Decode]?.array(lookup: lookup)?.compactMap { $0.real(lookup: lookup) }

		// Interpolation hint
		self.interpolate = dict[.Interpolate]?.boolean(lookup: lookup) ?? false

		// Rendering intent
		self.intent = dict[.Intent]?.name(lookup: lookup)

		// Soft mask for transparency
		self.softMask = dict[.SMask]?.stream(lookup: lookup)
	}

	static func parseEncoding(_ filterObj: PdfObject?, lookup: PdfObjectLookup?) -> ImageEncoding {
		guard let filterObj else {
			return .raw
		}

		// Filter can be a single name or an array of names
		let filters: [String]
		if let name = filterObj.name(lookup: lookup) {
			filters = [name]
		} else if let array = filterObj.array(lookup: lookup) {
			filters = array.compactMap { $0.name(lookup: lookup) }
		} else {
			return .raw
		}

		// Check for JPEG encoding
		if filters.contains("DCTDecode") || filters.contains("DCT") {
			return .jpeg
		}

		// Check for JPEG2000 encoding
		if filters.contains("JPXDecode") {
			return .jpeg2000
		}

		// FlateDecode or other filters result in raw bitmap data after decoding
		return .raw
	}

	static func parseColorSpace(_ colorSpaceObj: PdfObject?, lookup: PdfObjectLookup?) -> PdfColorSpace? {
		guard let colorSpaceObj else {
			return nil
		}

		// ColorSpace can be a name or an array
		if let name = colorSpaceObj.name(lookup: lookup) {
			return PdfColorSpace(name: name)
		}

		if let array = colorSpaceObj.array(lookup: lookup), let firstElement = array.first {
			// Array format: [/ColorSpaceType params...]
			if let typeName = firstElement.name(lookup: lookup) {
				switch typeName {
				case .Indexed:
					// [/Indexed baseColorSpace hival lookupData]
					guard array.count >= 4 else { return nil }
					let baseColorSpace = parseColorSpace(array[1], lookup: lookup) ?? .deviceRGB
					let hival = array[2].integer(lookup: lookup) ?? 255
					let lookupData: Data?
					if let data = array[3].string(lookup: lookup) {
						lookupData = data
					} else if let stream = array[3].stream(lookup: lookup) {
						lookupData = stream.data
					} else {
						lookupData = nil
					}
					return .indexed(base: baseColorSpace, hival: hival, lookup: lookupData)

				case .ICCBased:
					// [/ICCBased streamRef]
					guard array.count >= 2, let iccStream = array[1].stream(lookup: lookup) else {
						return nil
					}
					let n = iccStream.dictionary[.N]?.integer(lookup: lookup) ?? 3
					return .iccBased(components: n, profile: iccStream.data)

				default:
					// Unknown array color space, try to interpret as device color space
					return PdfColorSpace(name: typeName)
				}
			}
		}

		return nil
	}
}

public enum ImageEncoding: Sendable, Hashable {
	case raw       // Uncompressed bitmap data
	case jpeg      // DCTDecode - JPEG compressed
	case jpeg2000  // JPXDecode - JPEG 2000 compressed
}

public enum PdfColorSpace: Sendable, Hashable {
	case deviceGray
	case deviceRGB
	case deviceCMYK
	indirect case indexed(base: PdfColorSpace, hival: Int, lookup: Data?)
	case iccBased(components: Int, profile: Data)

	public init?(name: String) {
		switch name {
		case "DeviceGray", "G":
			self = .deviceGray
		case "DeviceRGB", "RGB":
			self = .deviceRGB
		case "DeviceCMYK", "CMYK":
			self = .deviceCMYK
		default:
			return nil
		}
	}

	public var componentsPerPixel: Int {
		switch self {
		case .deviceGray:
			return 1
		case .deviceRGB:
			return 3
		case .deviceCMYK:
			return 4
		case .indexed:
			return 1  // Indexed uses a single index value per pixel
		case .iccBased(let components, _):
			return components
		}
	}
}

public extension PdfColorSpace {
	// Recursive case for Hashable conformance
	static func == (lhs: PdfColorSpace, rhs: PdfColorSpace) -> Bool {
		switch (lhs, rhs) {
		case (.deviceGray, .deviceGray),
			 (.deviceRGB, .deviceRGB),
			 (.deviceCMYK, .deviceCMYK):
			return true
		case let (.indexed(base1, hival1, lookup1), .indexed(base2, hival2, lookup2)):
			return base1 == base2 && hival1 == hival2 && lookup1 == lookup2
		case let (.iccBased(c1, p1), .iccBased(c2, p2)):
			return c1 == c2 && p1 == p2
		default:
			return false
		}
	}

	func hash(into hasher: inout Hasher) {
		switch self {
		case .deviceGray:
			hasher.combine(0)
		case .deviceRGB:
			hasher.combine(1)
		case .deviceCMYK:
			hasher.combine(2)
		case .indexed(let base, let hival, let lookup):
			hasher.combine(3)
			hasher.combine(base)
			hasher.combine(hival)
			hasher.combine(lookup)
		case .iccBased(let components, let profile):
			hasher.combine(4)
			hasher.combine(components)
			hasher.combine(profile)
		}
	}
}
