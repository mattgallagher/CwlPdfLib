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
			self.colorSpace = PdfColorSpace.parse(dict[.ColorSpace], lookup: lookup) ?? .deviceRGB
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

}

public enum ImageEncoding: Sendable, Hashable {
	case raw // Uncompressed bitmap data
	case jpeg // DCTDecode - JPEG compressed
	case jpeg2000 // JPXDecode - JPEG 2000 compressed
}
