// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfFont<PlatformFont> {
	public let platformFont: PlatformFont?
	public let postScriptName: String?
	public let common: PDFFontCommon
	
	public enum Kind {
		case simple(SimpleFontData)
		case composite(CompositeFontData)
	}
	
	public let kind: Kind
	public let extras: OptionalFontExtras
	
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
		if let name = encodingObject.name(lookup: lookup) {
			switch name {
			case .`Identity-H`:
				return CMap(
					name: name,
					writingMode: .horizontal,
					codeSpaceRanges: [CodeSpaceRange(bound: 0x0000...0xFFFF, byteLength: 2)],
					mappings: [] 
				)
			case .`Identity-V`:
				return CMap(
					name: name,
					writingMode: .vertical,
					codeSpaceRanges: [CodeSpaceRange(bound: 0x0000...0xFFFF,byteLength: 2)],
					mappings: []
				)
			default:
				// Unknown predefined CMap — rare but allowed
				throw PdfParseError(failure: .unsupportedFontSubtype)
			}
		}
		
		guard
			let stream = encodingObject.stream(lookup: lookup)
		else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let (writingMode, codeSpaceRanges, mappings) = try stream.data.parseContext { context in
			var writingMode = WritingMode.horizontal
			var codeSpaceRanges = [CodeSpaceRange]()
			var mappings = [CMapMapping]()
			while let token = try PdfObject.parseNext(context: &context) {
				switch token {
				case .identifier(.WMode):
					if let mode = try PdfObject.parseNext(context: &context)?.integer(lookup: nil), mode == 1 {
						writingMode = .vertical
					}
				case .identifier(.begincodespacerange):
					while let token = try PdfObject.parseNext(context: &context) {
						if token == .identifier(.endcodespacerange) {
							break
						}
						guard
							let low = token.string(lookup: nil),
							let high = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
						else {
							break
						}
						codeSpaceRanges.append(
							CodeSpaceRange(
								bound: low.asBigEndianUInt32...high.asBigEndianUInt32,
								byteLength: low.count
							)
						)
					}
				case .identifier(.begincidchar):
					while let token = try PdfObject.parseNext(context: &context) {
						if token == .identifier(.endcidchar) {
							break
						}
						guard
							let code = token.string(lookup: nil),
							let cid = try PdfObject.parseNext(context: &context)?.integer(lookup: nil)
						else {
							break
						}
						mappings.append(.single(code: code.asBigEndianUInt32, cid: UInt32(cid)))
					}
				case .identifier(.begincidrange):
					while let token = try PdfObject.parseNext(context: &context) {
						if token == .identifier(.endcidrange) {
							break
						}
						guard
							let startCode = token.string(lookup: nil),
							let endCode = try PdfObject.parseNext(context: &context)?.string(lookup: nil),
							let startCID = try PdfObject.parseNext(context: &context)?.integer(lookup: nil)
						else {
							break
						}
						mappings
							.append(
								.range(startCode.asBigEndianUInt32...endCode.asBigEndianUInt32, startCID: UInt32(startCID))
							)
					}
				default:
					continue
				}
			}
			return (writingMode, codeSpaceRanges, mappings)
		}
		
		return CMap(
			name: nil,
			writingMode: writingMode,
			codeSpaceRanges: codeSpaceRanges,
			mappings: mappings
		)
	}
	
	static func parseToUnicodeCMap(
		_ object: PdfObject,
		_ lookup: PdfObjectLookup?
	) throws -> ToUnicodeCMap? {		
		guard
			let stream = object.stream(lookup: lookup)
		else {
			return nil
		}
		
		let (codeSpaceRanges, mappings) = try stream.data.parseContext { context in
			var codeSpaceRanges: [CodeSpaceRange] = []
			var mappings: [UnicodeMapping] = []
			while let token = try PdfObject.parseNext(context: &context) {
				switch token {
				case .identifier(.begincodespacerange):
					while let token = try PdfObject.parseNext(context: &context) {
						if token.identifier == .endcodespacerange {
							break
						}
						
						guard
							let lowData = token.string(lookup: nil),
							let highData = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
						else {
							throw PdfParseError(failure: .unsupportedCMap)
						}
						
						let low = lowData.asBigEndianUInt32
						let high = highData.asBigEndianUInt32
						let byteLength = lowData.count
						
						codeSpaceRanges.append(
							CodeSpaceRange(
								bound: low...high,
								byteLength: byteLength
							)
						)
					}
				case .identifier(.beginbfchar):
					while true {
						let peek = try PdfObject.parseNext(context: &context)
						if peek?.identifier == .endbfchar {
							break
						}
						
						guard
							let codeData = peek?.string(lookup: nil),
							let unicodeData = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
						else {
							throw PdfParseError(failure: .unsupportedCMap)
						}
						
						let code = codeData.asBigEndianUInt32
						let scalars = Self.decodeUnicodeScalars(unicodeData)
						
						mappings.append(
							.single(code: code, scalars: scalars)
						)
					}
				case .identifier(.beginbfrange):
					while true {
						let peek = try PdfObject.parseNext(context: &context)
						if peek?.identifier == .endbfrange {
							break
						}
						
						guard
							let startCodeData = peek?.string(lookup: nil),
							let endCodeData = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
						else {
							throw PdfParseError(failure: .unsupportedCMap)
						}
						
						let startCode = startCodeData.asBigEndianUInt32
						let endCode = endCodeData.asBigEndianUInt32
						
						let third = try PdfObject.parseNext(context: &context)
						
						if let value = third?.string(lookup: nil)?.asBigEndianUInt32, let scalar = UnicodeScalar(value) {
							mappings.append(
								.range(
									startCode...endCode,
									startScalar: scalar
								)
							)
						} else if case .array(let array)? = third {
							var code = startCode
							
							for entry in array {
								guard let data = entry.string(lookup: nil) else { continue }
								let scalars = Self.decodeUnicodeScalars(data)
								mappings.append(.single(code: code, scalars: scalars))
								code += 1
							}
						}
					}
				default:
					continue
				}
			}
			
			return (codeSpaceRanges, mappings)
		}
		
		return ToUnicodeCMap(
			codeSpaceRanges: codeSpaceRanges,
			mappings: mappings
		)
	}
	
	static func parseVerticalMetrics(
		_ fontDictionary: PdfDictionary,
		_ lookup: PdfObjectLookup?
	) throws -> VerticalMetrics {
		// Parse default vertical metrics from DW2 entry
		let defaultMetrics = Self.parseDefaultVerticalMetrics(fontDictionary[.DW2], lookup)
		
		// Parse vertical metric overrides from W2 entry
		let overrides = try Self.parseVerticalMetricOverrides(fontDictionary[.W2], lookup)
		
		return VerticalMetrics(
			defaultMetrics: defaultMetrics,
			overrides: overrides
		)
	}
	
	static func parseDefaultVerticalMetrics(
		_ dw2Object: PdfObject?,
		_ lookup: PdfObjectLookup?
	) -> VerticalMetric {
		// DW2 should be an array of two numbers: [default vertical advance, default horizontal offset]
		// According to PDF spec, default is [1000, -889] for CID fonts
		guard let dw2Array = dw2Object?.array(lookup: lookup),
				dw2Array.count >= 2
		else {
			// Return default values if DW2 is not present or invalid
			return VerticalMetric(verticalAdvance: 1000, horizontalOffset: -889)
		}
		
		let verticalAdvance = dw2Array[0].real(lookup: lookup) ?? 1000
		let horizontalOffset = dw2Array[1].real(lookup: lookup) ?? -889
		
		return VerticalMetric(
			verticalAdvance: verticalAdvance,
			horizontalOffset: horizontalOffset
		)
	}
	
	static func parseVerticalMetricOverrides(
		_ w2Object: PdfObject?,
		_ lookup: PdfObjectLookup?
	) throws -> [CIDRange: VerticalMetric] {
		guard let w2Array = w2Object?.array(lookup: lookup) else {
			return [:]
		}
		
		var overrides: [CIDRange: VerticalMetric] = [:]
		var index = 0
		
		while index < w2Array.count {
			if index + 1 < w2Array.count {
				// W2 entries can have two formats:
				// 1. [cid1 cid2 vAdvance hOffset] - range mapping
				// 2. [cid1 vAdvance1 hOffset1 cid2 vAdvance2 hOffset2 ...] - individual mappings
				
				let firstValue = w2Array[index]
				
				if let startCID = firstValue.integer(lookup: lookup),
					index + 2 < w2Array.count
				{
					let secondValue = w2Array[index + 1]
					
					if let endCID = secondValue.integer(lookup: lookup),
						index + 3 < w2Array.count
					{
						// Format 1: Range mapping [cid1 cid2 vAdvance hOffset]
						let verticalAdvance = w2Array[index + 2].real(lookup: lookup) ?? 1000
						let horizontalOffset = w2Array[index + 3].real(lookup: lookup) ?? -889
						
						let range: CIDRange = UInt32(startCID)...UInt32(endCID)
						overrides[range] = VerticalMetric(
							verticalAdvance: verticalAdvance,
							horizontalOffset: horizontalOffset
						)
						
						index += 4
					} else if let vAdvance = secondValue.real(lookup: lookup),
								 index + 1 < w2Array.count
					{
						// Format 2: Individual mapping [cid vAdvance hOffset]
						let hOffset = w2Array[index + 2].real(lookup: lookup) ?? -889
						
						let cidRange: CIDRange = UInt32(startCID)...UInt32(startCID)
						overrides[cidRange] = VerticalMetric(
							verticalAdvance: vAdvance,
							horizontalOffset: hOffset
						)
						
						index += 3
					} else {
						// Unexpected format, skip
						index += 1
					}
				} else {
					// Not a CID, skip this entry
					index += 1
				}
			} else {
				index += 1
			}
		}
		
		return overrides
	}
	
	static func writingMode(from kind: Kind) -> WritingMode {
		switch kind {
		case .composite(let compositeFontData):
			// The writing mode is determined by the CMap
			compositeFontData.cmap.writingMode
		case .simple:
			// Simple fonts are always horizontal
				.horizontal
		}
	}
	
	static func parseCIDWidths(_ wObject: PdfObject?, _ lookup: PdfObjectLookup?) throws -> CIDWidthMap {
		guard let wArray = wObject?.array(lookup: lookup) else {
			return []
		}
		
		var widthMap: CIDWidthMap = []
		var index = 0
		
		while index < wArray.count {
			guard index + 1 < wArray.count else { break }
			
			let firstValue = wArray[index]
			
			// Check if first value is a CID (integer)
			if let startCID = firstValue.integer(lookup: lookup) {
				let secondValue = wArray[index + 1]
				
				// Check if second value is also a CID (range format)
				if let endCID = secondValue.integer(lookup: lookup) {
					// Format 1: [cid1 cid2 width] - single width for range
					guard index + 2 < wArray.count else { break }
					
					if let width = wArray[index + 2].real(lookup: lookup) {
						let range: CIDRange = UInt32(startCID)...UInt32(endCID)
						widthMap.append((range, width))
					}
					
					index += 3
				}
				// Check if second value is a real number (individual format)
				else if let width = secondValue.real(lookup: lookup) {
					// Format 2: [cid1 width1 cid2 width2 ...] - individual widths
					let range: CIDRange = UInt32(startCID)...UInt32(startCID)
					widthMap.append((range, width))
					
					index += 2
				}
				// Check if second value is an array (array format)
				else if let widthArray = secondValue.array(lookup: lookup) {
					// Format 3: [cid1 cid2 [width1 width2 ...]] - array of widths for range
					guard index + 1 < wArray.count else { break }
					
					let thirdValue = wArray[index + 2]
					if let endCID = thirdValue.integer(lookup: lookup) {
						// Create individual mappings for each width in the array
						var currentCID = startCID
						for widthValue in widthArray {
							if let width = widthValue.real(lookup: lookup) {
								let range: CIDRange = UInt32(currentCID)...UInt32(currentCID)
								widthMap.append((range, width))
							}
							currentCID += 1
							if currentCID > endCID { break }
						}
					}
					
					index += 3
				} else {
					// Unknown format, skip
					index += 1
				}
			} else {
				// First value is not a CID, skip
				index += 1
			}
		}
		
		return widthMap
	}
	
	static func parseCIDToGIDMap(_ CIDToGIDMapObject: PdfObject?, _ lookup: PdfObjectLookup?) throws -> CIDToGIDMap {
		// Check if it's the string "Identity"
		if let identityName = CIDToGIDMapObject?.name(lookup: lookup), identityName == .Identity {
			return .identity
		}
		
		// Check if it's a stream containing binary mapping data
		guard let stream = CIDToGIDMapObject?.stream(lookup: lookup) else {
			// If no CIDToGIDMap is present, it's considered identity for TrueType fonts
			return .identity
		}
		
		let data = stream.data
		
		// The data should contain UInt16 values (2 bytes each) where index = CID, value = GID
		guard data.count % 2 == 0 else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let count = data.count / 2
		var gidArray: [UInt16] = []
		gidArray.reserveCapacity(count)
		
		// Read each 2-byte value as a UInt16 (big-endian according to PDF spec)
		for i in 0..<count {
			let startIndex = i * 2
			guard startIndex + 2 <= data.count else { break }
			
			let value = data.withUnsafeBytes { bytes in
				let uint16Ptr = bytes.bindMemory(to: UInt16.self)
				return UInt16(bigEndian: uint16Ptr[startIndex])
			}
			
			gidArray.append(value)
		}
		
		return .mapped(gidArray)
	}
	
	static func decodeUnicodeScalars(_ data: Data) -> [UnicodeScalar] {

		 // PDF ToUnicode uses UTF-16BE by spec
		 guard data.count >= 2, data.count % 2 == 0 else {
			  return []
		 }

		 var scalars: [UnicodeScalar] = []
		 scalars.reserveCapacity(data.count / 2)

		 var index = data.startIndex

		 while index < data.endIndex {
			  let hi = UInt16(data[index]) << 8
			  let lo = UInt16(data[index + 1])
			  let value = hi | lo
			  index += 2

			  if let scalar = UnicodeScalar(value) {
					scalars.append(scalar)
			  }
		 }

		 return scalars
	}
}

public struct PDFFontCommon {
	public let subtype: FontSubtype
	public let fontMatrix: PdfAffineTransform // usually from font program
	public let ascent: Double?
	public let descent: Double?
	public let capHeight: Double?
	public let italicAngle: Double?
}

public enum FontSubtype: String {
	case Type1
	case TrueType
	case Type3
	case Type0
}

public enum CIDFontSubtype: String {
	case CIDFontType0 // Type 1 outlines
	case CIDFontType2 // TrueType outlines
}

public struct SimpleFontData {
	public let encoding: EncodingDictionary
	public let firstChar: Int
	public let widths: [Double]
	public let missingWidth: Double?
}

public struct EncodingDictionary {
	public let baseEncoding: BaseEncoding?
	public let differences: [Int: String] // code → glyph name
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
	public let cmap: CMap // Encoding entry
	public let descendantFont: CIDFontData
}

public struct CIDFontData {
	public let cidSystemInfo: CIDSystemInfo
	public let defaultWidth: Double // DW
	public let widths: CIDWidthMap // W
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
	public let toUnicode: ToUnicodeCMap? // extraction only
	public let verticalMetrics: VerticalMetrics?
	public let writingMode: WritingMode // Horizontal / Vertical
}

public struct ToUnicodeCMap {
	public let codeSpaceRanges: [CodeSpaceRange]
	public let mappings: [UnicodeMapping]
}

public enum UnicodeMapping {
	case single(code: UInt32, scalars: [UnicodeScalar])
	case range(ClosedRange<UInt32>, startScalar: UnicodeScalar)
}

public struct VerticalMetrics {
	public let defaultMetrics: VerticalMetric
	public let overrides: [CIDRange: VerticalMetric]
}

public struct VerticalMetric {
	public let verticalAdvance: Double // usually in glyph space
	public let horizontalOffset: Double // x displacement when writing vertically
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
				guard index + length <= data.endIndex else { continue }
				
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
				// Invalid byte → skip
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
		return 0
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
	case mapped([UInt16]) // index = CID, value = GID
}
