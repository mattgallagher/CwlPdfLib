// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfFont<PlatformFont> {
	public let platformFont: PlatformFont?
	let postScriptName: String?
	let common: PDFFontCommon
	
	enum Kind {
		case simple(SimpleFontData)
		case composite(CompositeFontData)
	}
	
	let kind: Kind
	let extras: OptionalFontExtras
	
	public init(fontDictionary: PdfDictionary, lookup: PdfObjectLookup?, fontFromData: (Data) -> PlatformFont?) throws {
		guard let subtypeName = fontDictionary[.Subtype]?.name(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let fontSubtype = FontSubtype(rawValue: subtypeName)
		guard let fontSubtype else {
			throw PdfParseError(failure: .unsupportedFontSubtype)
		}
		
		let descriptorDict = fontDictionary[.FontDescriptor]?.dictionary(lookup: lookup)
		
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
		
		let kind: PdfFont.Kind
		if case .Type0 = fontSubtype {
			guard let encodingObj = fontDictionary[.Encoding] else {
				throw PdfParseError(failure: .missingRequiredParameters)
			}
			
			let cmap = try Self.parseCMap(encodingObj, lookup)
			guard
				let descendants = fontDictionary[.DescendantFonts]?.array(lookup: lookup),
				let descendantDict = descendants.first?.dictionary(lookup: lookup)
			else {
				throw PdfParseError(failure: .unsupportedFontSubtype)
			}
			
			let cidFont = try Self.parseCIDFont(descendantDict, lookup)
			kind = .composite(CompositeFontData(cmap: cmap, descendantFont: cidFont))
		} else {
			let encoding = try Self.parseEncoding(fontDictionary[.Encoding], lookup)
			let firstChar = fontDictionary[.FirstChar]?.integer(lookup: lookup) ?? 0
			let missingWidth = descriptorDict?[.MissingWidth]?.real(lookup: lookup)
			let widths = fontDictionary[.Widths]?
				.array(lookup: lookup)?
				.compactMap { $0.real(lookup: lookup) }
				?? []
			
			kind = .simple(
				SimpleFontData(
					encoding: encoding,
					firstChar: firstChar,
					widths: widths,
					missingWidth: missingWidth
				)
			)
		}
		
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
	
	static func parseEncoding(
		_ object: PdfObject?,
		_ lookup: PdfObjectLookup?
	) throws -> EncodingDictionary {
		guard let object else {
			return EncodingDictionary(baseEncoding: nil, differences: [:])
		}
		
		if let name = object.name(lookup: lookup) {
			return EncodingDictionary(
				baseEncoding: BaseEncoding(rawValue: name),
				differences: [:]
			)
		}
		
		guard let dict = object.dictionary(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let baseEncoding = dict[.BaseEncoding]?.name(lookup: lookup)
			.flatMap(BaseEncoding.init)
		
		let differences = try Self.parseDifferences(dict[.Differences], lookup)
		
		return EncodingDictionary(
			baseEncoding: baseEncoding,
			differences: differences
		)
	}
	
	static func parseDifferences(
		_ object: PdfObject?,
		_ lookup: PdfObjectLookup?
	) throws -> [Int: String] {
		guard let array = object?.array(lookup: lookup) else {
			return [:]
		}
		
		var result: [Int: String] = [:]
		var currentCode: Int?
		for element in array {
			if let code = element.integer(lookup: lookup) {
				currentCode = code
			} else if let name = element.name(lookup: lookup), let code = currentCode {
				result[code] = name
				currentCode = code + 1
			}
		}
		
		return result
	}
	
	static func parseCIDFont(
		_ dict: PdfDictionary,
		_ lookup: PdfObjectLookup?
	) throws -> CIDFontData {
		guard let subtypeName = dict[.Subtype]?.name(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let subtype = CIDFontSubtype(rawValue: subtypeName)
		guard let subtype else {
			throw PdfParseError(failure: .unsupportedFontSubtype)
		}
		
		let defaultWidth = dict[.DW]?.real(lookup: lookup) ?? 1000
		let widths = try Self.parseCIDWidths(dict[.W], lookup)
		let cidToGIDMap = try Self.parseCIDToGIDMap(dict[.CIDToGIDMap], lookup)
		let systemInfoDict = dict[.CIDSystemInfo]?.dictionary(lookup: lookup)
		let systemInfo = CIDSystemInfo(
			registry: systemInfoDict?[.Registry]?.string(lookup: lookup)
				.flatMap { String(decoding: $0, as: UTF8.self) } ?? "",
			ordering: systemInfoDict?[.Ordering]?.string(lookup: lookup)
				.flatMap { String(decoding: $0, as: UTF8.self) } ?? "",
			supplement: systemInfoDict?[.Supplement]?
				.integer(lookup: lookup) ?? 0
		)
		
		return CIDFontData(
			cidSystemInfo: systemInfo,
			defaultWidth: defaultWidth,
			widths: widths,
			cidToGIDMap: cidToGIDMap,
			subtype: subtype
		)
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
	
	static func parseCMap(
		 _ encodingObject: PdfObject,
		 _ lookup: PdfObjectLookup?
	) throws -> CMap {
		fatalError("Not implemented")
	}
	
	static func parseToUnicodeCMap(
		_ toUnicodeObject: PdfObject,
		_ lookup: PdfObjectLookup?
	) throws -> ToUnicodeCMap {
		fatalError("Not implemented")
	}
	
	static func parseVerticalMetrics(
		_ fontDictionary: PdfDictionary,
		_ lookup: PdfObjectLookup?
	) throws -> VerticalMetrics {
		fatalError("Not implemented")
	}
	
	static func writingMode(from: Kind) -> WritingMode {
		fatalError("Not implemented")
	}
	
	static func parseCIDWidths(_ wObject: PdfObject?, _ lookup: PdfObjectLookup?) throws -> CIDWidthMap {
		fatalError("Not implemented")
	}
	
	static func parseCIDToGIDMap(_ CIDToGIDMapObject: PdfObject?, _ lookup: PdfObjectLookup?) throws -> CIDToGIDMap {
		fatalError("Not implemented")
	}
}

struct PDFFontCommon {
	let subtype: FontSubtype
	let fontMatrix: PdfAffineTransform // usually from font program
	let ascent: Double?
	let descent: Double?
	let capHeight: Double?
	let italicAngle: Double?
}

enum FontSubtype: String {
	case Type1
	case TrueType
	case Type3
	case Type0
}

enum CIDFontSubtype: String {
	case CIDFontType0 // Type 1 outlines
	case CIDFontType2 // TrueType outlines
}

struct SimpleFontData {
	let encoding: EncodingDictionary
	let firstChar: Int
	let widths: [Double]
	let missingWidth: Double?
}

struct EncodingDictionary {
	let baseEncoding: BaseEncoding?
	let differences: [Int: String] // code → glyph name
}

enum BaseEncoding: String {
	case Standard
	case WinAnsi
	case MacRoman
	case MacExpert
}

struct CompositeFontData {
	let cmap: CMap // Encoding entry
	let descendantFont: CIDFontData
}

struct CIDFontData {
	let cidSystemInfo: CIDSystemInfo
	let defaultWidth: Double // DW
	let widths: CIDWidthMap // W
	let cidToGIDMap: CIDToGIDMap?
	let subtype: CIDFontSubtype
}

typealias CIDWidthMap = [(CIDRange, Double)]

struct OptionalFontExtras {
	let toUnicode: ToUnicodeCMap? // extraction only
	let verticalMetrics: VerticalMetrics?
	let writingMode: WritingMode // Horizontal / Vertical
}

struct ToUnicodeCMap {
	let codeSpaceRanges: [CodeSpaceRange]
	let mappings: [UnicodeMapping]
}

enum UnicodeMapping {
	case single(code: UInt32, scalars: [UnicodeScalar])
	case range(ClosedRange<UInt32>, startScalar: UnicodeScalar)
}

struct VerticalMetrics {
	let defaultMetrics: VerticalMetric
	let overrides: [CIDRange: VerticalMetric]
}

struct VerticalMetric {
	let verticalAdvance: Double // usually in glyph space
	let horizontalOffset: Double // x displacement when writing vertically
}

struct CMap {
	let name: String?
	let writingMode: WritingMode
	let codeSpaceRanges: [CodeSpaceRange]
	let mappings: [CMapMapping]
}

enum WritingMode: Int {
	case horizontal
	case vertical
}

struct CodeSpaceRange {
	let bound: ClosedRange<UInt32>
	let byteLength: Int
}

enum CMapMapping {
	case single(code: UInt32, cid: UInt32)
	case range(ClosedRange<UInt32>, startCID: UInt32)
}

struct CIDSystemInfo {
	let registry: String
	let ordering: String
	let supplement: Int
}

typealias CIDRange = ClosedRange<UInt32>

enum CIDToGIDMap {
	case identity
	case mapped([UInt16])  // index = CID, value = GID
}
