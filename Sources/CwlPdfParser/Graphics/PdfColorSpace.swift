// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

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
			1
		case .deviceRGB:
			3
		case .deviceCMYK:
			4
		case .indexed:
			1 // Indexed uses a single index value per pixel
		case .iccBased(let components, _):
			components
		}
	}

	public static func parse(_ colorSpaceObj: PdfObject?, lookup: PdfObjectLookup?) -> PdfColorSpace? {
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
					let baseColorSpace = parse(array[1], lookup: lookup) ?? .deviceRGB
					let hival = array[2].integer(lookup: lookup) ?? 255
					let lookupData: Data? = if let data = array[3].string(lookup: lookup) {
						data
					} else if let stream = array[3].stream(lookup: lookup) {
						stream.data
					} else {
						nil
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

public extension PdfColorSpace {
	// Recursive case for Hashable conformance
	static func == (lhs: PdfColorSpace, rhs: PdfColorSpace) -> Bool {
		switch (lhs, rhs) {
		case (.deviceGray, .deviceGray),
			  (.deviceRGB, .deviceRGB),
			  (.deviceCMYK, .deviceCMYK):
			true
		case (.indexed(let base1, let hival1, let lookup1), .indexed(let base2, let hival2, let lookup2)):
			base1 == base2 && hival1 == hival2 && lookup1 == lookup2
		case (.iccBased(let c1, let p1), .iccBased(let c2, let p2)):
			c1 == c2 && p1 == p2
		default:
			false
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
