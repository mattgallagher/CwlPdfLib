// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfFont<PlatformFont> {
	public let platformFont: PlatformFont?
	public let postScriptName: String?
	public let common: PDFFontCommon

	public enum Kind {
		case simple(SimpleFontData)
		case composite(CompositeFontData)
		case type3(Type3FontData)
	}

	public let kind: Kind
	public let extras: OptionalFontExtras

	public init(fontDictionary: PdfDictionary, lookup: PdfObjectLookup?, fontFromData: (Data) -> PlatformFont?) throws {
		guard let subtypeName = fontDictionary[.Subtype]?.name(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		let fontSubtype = try Self.parseFontSubtype(subtypeName)
		let descriptorDict = Self.fontDescriptorDictionary(
			fontDictionary: fontDictionary,
			fontSubtype: fontSubtype,
			lookup: lookup
		)

		let (platformFont, postscriptName) = try Self.buildFont(
			fontDictionary: fontDictionary,
			descriptor: descriptorDict,
			lookup: lookup,
			fontFromData: fontFromData
		)

		let common = PDFFontCommon(
			subtype: fontSubtype,
			fontMatrix: Self.parseFontMatrix(fontDictionary, lookup),
			ascent: descriptorDict?[.Ascent]?.real(lookup: lookup),
			descent: descriptorDict?[.Descent]?.real(lookup: lookup),
			capHeight: descriptorDict?[.CapHeight]?.real(lookup: lookup),
			italicAngle: descriptorDict?[.ItalicAngle]?.real(lookup: lookup)
		)

		let kind = try Self.parseKind(
			fontDictionary: fontDictionary,
			fontSubtype: fontSubtype,
			descriptor: descriptorDict,
			lookup: lookup
		)

		let toUnicode = try fontDictionary[.ToUnicode]
			.flatMap { try Self.parseToUnicodeCMap($0, lookup) }
		let verticalMetrics = try Self.parseVerticalMetrics(fontDictionary, lookup)
		let extras = OptionalFontExtras(
			toUnicode: toUnicode,
			verticalMetrics: verticalMetrics,
			writingMode: Self.writingMode(from: kind)
		)

		self.platformFont = platformFont
		self.postScriptName = postscriptName
		self.common = common
		self.kind = kind
		self.extras = extras
	}

	static func parseFontSubtype(_ subtypeName: String) throws -> FontSubtype {
		guard let fontSubtype = FontSubtype(rawValue: subtypeName) else {
			throw PdfParseError(failure: .unsupportedFontSubtype)
		}

		return fontSubtype
	}

	static func fontDescriptorDictionary(
		fontDictionary: PdfDictionary,
		fontSubtype: FontSubtype,
		lookup: PdfObjectLookup?
	) -> PdfDictionary? {
		if case .Type0 = fontSubtype {
			let descendants = fontDictionary[.DescendantFonts]?.array(lookup: lookup)
			let descendantDict = descendants?.first?.dictionary(lookup: lookup)
			return descendantDict?[.FontDescriptor]?.dictionary(lookup: lookup)
		}

		return fontDictionary[.FontDescriptor]?.dictionary(lookup: lookup)
	}

	static func parseKind(
		fontDictionary: PdfDictionary,
		fontSubtype: FontSubtype,
		descriptor: PdfDictionary?,
		lookup: PdfObjectLookup?
	) throws -> Kind {
		switch fontSubtype {
		case .Type0:
			try Self.parseCompositeKind(fontDictionary: fontDictionary, lookup: lookup)
		case .Type3:
			try Self.parseType3Kind(fontDictionary: fontDictionary, lookup: lookup)
		case .TrueType, .Type1:
			try Self.parseSimpleKind(fontDictionary: fontDictionary, descriptor: descriptor, lookup: lookup)
		}
	}

	static func buildFont(
		fontDictionary: PdfDictionary,
		descriptor: PdfDictionary?,
		lookup: PdfObjectLookup?,
		fontFromData: (Data) -> PlatformFont?
	) throws -> (PlatformFont?, String?) {
		guard let descriptor else {
			return (nil, nil)
		}

		let fontFileObject = descriptor[.FontFile] ?? descriptor[.FontFile2] ?? descriptor[.FontFile3]
		guard let stream = fontFileObject?.stream(lookup: lookup) else {
			return (nil, nil)
		}

		let platformFont = fontFromData(stream.data)
		let postScriptName = descriptor[.FontName]?.name(lookup: lookup)

		return (platformFont, postScriptName)
	}

	static func parseFontMatrix(
		_ fontDictionary: PdfDictionary,
		_ lookup: PdfObjectLookup?
	) -> PdfAffineTransform {
		guard
			let matrixArray = fontDictionary[.FontMatrix]?.array(lookup: lookup)?.compactMap({ $0.real(lookup: lookup) }),
			matrixArray.count == 6
		else {
			if fontDictionary[.Subtype]?.name(lookup: lookup) == .Type3 {
				return PdfAffineTransform(a: 0.001, b: 0, c: 0, d: 0.001, tx: 0, ty: 0)
			}

			return .identity
		}

		return PdfAffineTransform(
			a: matrixArray[0],
			b: matrixArray[1],
			c: matrixArray[2],
			d: matrixArray[3],
			tx: matrixArray[4],
			ty: matrixArray[5]
		)
	}

	static func writingMode(from kind: Kind) -> WritingMode {
		switch kind {
		case .composite(let compositeFontData):
			compositeFontData.cmap.writingMode
		case .simple, .type3:
				.horizontal
		}
	}
}

public struct PDFFontCommon {
	public let subtype: FontSubtype
	public let fontMatrix: PdfAffineTransform
	public let ascent: Double?
	public let descent: Double?
	public let capHeight: Double?
	public let italicAngle: Double?
}

public enum FontSubtype: String {
	case Type0
	case Type1
	case Type3
	case TrueType
}

public enum CIDFontSubtype: String {
	case CIDFontType0
	case CIDFontType2
}

public struct SimpleFontData {
	public let encoding: EncodingDictionary
	public let firstChar: Int
	public let widths: [Double]
	public let missingWidth: Double?
}

public struct Type3FontData {
	public let encoding: EncodingDictionary
	public let firstChar: Int
	public let widths: [Double]
	public let fontBBox: PdfRect
	public let charProcs: PdfDictionary
	public let resources: PdfDictionary?
}

public struct EncodingDictionary {
	public let baseEncoding: BaseEncoding?
	public let differences: [Int: String]
}

public enum BaseEncoding: String {
	case ExpertEncoding
	case MacExpertEncoding
	case MacRomanEncoding
	case StandardEncoding
	case SymbolEncoding
	case WinAnsiEncoding
	case ZapfDingbatsEncoding

	public var glyphNames: [String?] {
		switch self {
		case .ExpertEncoding: FontEncodingGlyphNames.Expert
		case .MacExpertEncoding: FontEncodingGlyphNames.MacExpert
		case .MacRomanEncoding: FontEncodingGlyphNames.MacRoman
		case .StandardEncoding: FontEncodingGlyphNames.Standard
		case .SymbolEncoding: FontEncodingGlyphNames.Symbol
		case .WinAnsiEncoding: FontEncodingGlyphNames.WinAnsi
		case .ZapfDingbatsEncoding: FontEncodingGlyphNames.ZapfDingbats
		}
	}

	public func glyphName(for code: Int) -> String? {
		(0...255).contains(code) ? glyphNames[code] : nil
	}
}

public struct CompositeFontData {
	public let cmap: CMap
	public let descendantFont: CIDFontData
}

public struct CIDFontData {
	public let cidSystemInfo: CIDSystemInfo
	public let defaultWidth: Double
	public let widths: CIDWidthMap
	public let cidToGIDMap: CIDToGIDMap?
	public let subtype: CIDFontSubtype
}

public typealias CIDWidthMap = [(CIDRange, Double)]

public extension CIDWidthMap {
	func width(for cid: UInt32) -> Double? {
		for (range, width) in self where range.contains(cid) {
			return width
		}

		return nil
	}
}

public struct OptionalFontExtras {
	public let toUnicode: ToUnicodeCMap?
	public let verticalMetrics: VerticalMetrics?
	public let writingMode: WritingMode
}

public struct ToUnicodeCMap {
	public let codeSpaceRanges: [CodeSpaceRange]
	public let mappings: [UnicodeMapping]

	public func decodeString(_ data: Data) -> String? {
		let scalars = decodeScalars(data)
		guard !scalars.isEmpty else {
			return nil
		}

		return String(String.UnicodeScalarView(scalars))
	}

	public func decodeScalars(_ data: Data) -> [UnicodeScalar] {
		var result: [UnicodeScalar] = []
		var index = data.startIndex

		while index < data.endIndex {
			var matched = false

			for range in codeSpaceRanges {
				let length = range.byteLength
				guard index + length <= data.endIndex else {
					continue
				}

				var code: UInt32 = 0
				for i in 0..<length {
					code = (code << 8) | UInt32(data[index + i])
				}

				guard range.bound.contains(code) else {
					continue
				}

				result.append(contentsOf: UnicodeMapping.scalars(for: code, mappings: mappings))
				index += length
				matched = true
				break
			}

			if !matched {
				index += 1
			}
		}

		return result
	}
}

public enum UnicodeMapping {
	case single(code: UInt32, scalars: [UnicodeScalar])
	case range(ClosedRange<UInt32>, startScalar: UnicodeScalar)

	public static func scalars(for code: UInt32, mappings: [UnicodeMapping]) -> [UnicodeScalar] {
		for mapping in mappings {
			switch mapping {
			case .single(let singleCode, let scalars) where singleCode == code:
				return scalars
			case .range(let range, let startScalar) where range.contains(code):
				if let scalar = UnicodeScalar(startScalar.value + (code - range.lowerBound)) {
					return [scalar]
				}
				return []
			default:
				continue
			}
		}

		return []
	}
}

public struct VerticalMetrics {
	public let defaultMetrics: VerticalMetric
	public let overrides: [CIDRange: VerticalMetric]
}

public struct VerticalMetric {
	public let verticalAdvance: Double
	public let horizontalOffset: Double
}

public struct CMap {
	public let name: String?
	public let writingMode: WritingMode
	public let codeSpaceRanges: [CodeSpaceRange]
	public let mappings: [CMapMapping]

	public func decode(_ data: Data) -> [UInt32] {
		var result: [UInt32] = []
		var index = data.startIndex

		while index < data.endIndex {
			var matched = false

			for range in codeSpaceRanges {
				let length = range.byteLength
				guard index + length <= data.endIndex else {
					continue
				}

				var code: UInt32 = 0
				for i in 0..<length {
					code = (code << 8) | UInt32(data[index + i])
				}

				if range.bound.contains(code) {
					result.append(map(code))
					index += length
					matched = true
					break
				}
			}

			if !matched {
				index += 1
			}
		}

		return result
	}

	public func map(_ code: UInt32) -> UInt32 {
		for mapping in mappings {
			switch mapping {
			case .single(let c, let cid) where c == code:
				return cid
			case .range(let r, let start) where r.contains(code):
				return start + (code - r.lowerBound)
			default:
				continue
			}
		}

		return code
	}
}

public enum WritingMode: Int {
	case horizontal
	case vertical
}

public struct CodeSpaceRange {
	public let bound: ClosedRange<UInt32>
	public let byteLength: Int
}

public enum CMapMapping {
	case single(code: UInt32, cid: UInt32)
	case range(ClosedRange<UInt32>, startCID: UInt32)
}

public struct CIDSystemInfo {
	public let registry: String
	public let ordering: String
	public let supplement: Int
}

public typealias CIDRange = ClosedRange<UInt32>

public enum CIDToGIDMap {
	case identity
	case mapped([UInt16])
}
