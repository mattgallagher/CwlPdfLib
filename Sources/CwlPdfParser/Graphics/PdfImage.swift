// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

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
	/// Decoded global segments referenced by `/DecodeParms/JBIG2Globals`.
	public let jbig2Globals: Data?
	public let softMask: PdfStream?
	public let matte: [Double]?

	/// Creates an image from a PDF image stream.
	///
	/// - Parameters:
	///   - stream: The image XObject stream.
	///   - lookup: The object lookup used to resolve indirect image metadata.
	///   - resolvedColorSpace: The color space resolved through the containing resource dictionary,
	///     including any applicable `DefaultGray`, `DefaultRGB`, or `DefaultCMYK` substitution.
	public init(
		stream: PdfStream,
		lookup: PdfObjectLookup?,
		resolvedColorSpace: PdfColorSpace? = nil
	) throws {
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
			self.colorSpace = resolvedColorSpace ?? PdfColorSpace.parse(dict[.ColorSpace], lookup: lookup) ?? .deviceRGB
		}

		// Parse the filter to determine encoding
		self.encoding = Self.parseEncoding(dict[.Filter], lookup: lookup)
		self.jbig2Globals = Self.parseJbig2Globals(
			filters: Self.parseFilters(dict[.Filter], lookup: lookup),
			decodeParameters: dict[.DecodeParms],
			lookup: lookup
		)

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

		// Optional matte color for images associated with a soft mask
		self.matte = dict[.Matte]?.array(lookup: lookup)?.compactMap { $0.real(lookup: lookup) }
	}

	static func parseEncoding(_ filterObj: PdfObject?, lookup: PdfObjectLookup?) -> ImageEncoding {
		let filters = parseFilters(filterObj, lookup: lookup)

		// Check for JPEG encoding
		if filters.contains("DCTDecode") || filters.contains("DCT") {
			return .jpeg
		}

		// Check for JPEG2000 encoding
		if filters.contains("JPXDecode") {
			return .jpeg2000
		}

		if filters.contains("JBIG2Decode") {
			return .jbig2
		}

		// FlateDecode or other filters result in raw bitmap data after decoding
		return .raw
	}

	private static func parseFilters(_ filterObj: PdfObject?, lookup: PdfObjectLookup?) -> [String] {
		guard let filterObj else {
			return []
		}
		if let name = filterObj.name(lookup: lookup) {
			return [name]
		}
		return filterObj.array(lookup: lookup)?.compactMap { $0.name(lookup: lookup) } ?? []
	}

	private static func parseJbig2Globals(
		filters: [String],
		decodeParameters: PdfObject?,
		lookup: PdfObjectLookup?
	) -> Data? {
		guard let filterIndex = filters.firstIndex(of: "JBIG2Decode") else {
			return nil
		}
		let parameterArray = decodeParameters?.array(lookup: lookup)
		let parameters = parameterArray.flatMap { array in
			array.indices.contains(filterIndex) ? array[filterIndex] : nil
		} ?? decodeParameters
		return parameters?
			.dictionary(lookup: lookup)?[.JBIG2Globals]?
			.stream(lookup: lookup)?
			.data
	}

}

public enum ImageEncoding: Sendable, Hashable {
	/// JBIG2 compressed bi-level image data.
	case jbig2
	case raw // Uncompressed bitmap data
	case jpeg // DCTDecode - JPEG compressed
	case jpeg2000 // JPXDecode - JPEG 2000 compressed
}
