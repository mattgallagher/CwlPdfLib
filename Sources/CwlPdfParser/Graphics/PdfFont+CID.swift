// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfFont {
	static func parseCompositeKind(
		fontDictionary: PdfDictionary,
		lookup: PdfObjectLookup?
	) throws -> Kind {
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
		return .composite(CompositeFontData(cmap: cmap, descendantFont: cidFont))
	}

	static func parseCIDFont(
		_ dict: PdfDictionary,
		_ lookup: PdfObjectLookup?
	) throws -> CIDFontData {
		guard let subtypeName = dict[.Subtype]?.name(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		guard let subtype = CIDFontSubtype(rawValue: subtypeName) else {
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
			supplement: systemInfoDict?[.Supplement]?.integer(lookup: lookup) ?? 0
		)

		return CIDFontData(
			cidSystemInfo: systemInfo,
			defaultWidth: defaultWidth,
			widths: widths,
			cidToGIDMap: cidToGIDMap,
			subtype: subtype
		)
	}

	static func parseVerticalMetrics(
		_ fontDictionary: PdfDictionary,
		_ lookup: PdfObjectLookup?
	) throws -> VerticalMetrics {
		let defaultMetrics = Self.parseDefaultVerticalMetrics(fontDictionary[.DW2], lookup)
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
		guard
			let dw2Array = dw2Object?.array(lookup: lookup),
			dw2Array.count >= 2
		else {
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
				let firstValue = w2Array[index]

				if let startCID = firstValue.integer(lookup: lookup), index + 2 < w2Array.count {
					let secondValue = w2Array[index + 1]

					if let endCID = secondValue.integer(lookup: lookup), index + 3 < w2Array.count {
						let verticalAdvance = w2Array[index + 2].real(lookup: lookup) ?? 1000
						let horizontalOffset = w2Array[index + 3].real(lookup: lookup) ?? -889
						let range: CIDRange = UInt32(startCID)...UInt32(endCID)
						overrides[range] = VerticalMetric(
							verticalAdvance: verticalAdvance,
							horizontalOffset: horizontalOffset
						)
						index += 4
					} else if let verticalAdvance = secondValue.real(lookup: lookup), index + 1 < w2Array.count {
						let horizontalOffset = w2Array[index + 2].real(lookup: lookup) ?? -889
						let range: CIDRange = UInt32(startCID)...UInt32(startCID)
						overrides[range] = VerticalMetric(
							verticalAdvance: verticalAdvance,
							horizontalOffset: horizontalOffset
						)
						index += 3
					} else {
						index += 1
					}
				} else {
					index += 1
				}
			} else {
				index += 1
			}
		}

		return overrides
	}

	static func parseCIDWidths(
		_ wObject: PdfObject?,
		_ lookup: PdfObjectLookup?
	) throws -> CIDWidthMap {
		guard let wArray = wObject?.array(lookup: lookup) else {
			return []
		}

		var widthMap: CIDWidthMap = []
		var index = 0

		while index < wArray.count {
			guard let startCID = wArray[index].integer(lookup: lookup) else {
				index += 1
				continue
			}

			guard index + 1 < wArray.count else {
				break
			}

			let secondValue = wArray[index + 1]
			if let widthArray = secondValue.array(lookup: lookup) {
				var currentCID = startCID
				for widthValue in widthArray {
					if let width = widthValue.real(lookup: lookup) {
						let range: CIDRange = UInt32(currentCID)...UInt32(currentCID)
						widthMap.append((range, width))
					}
					currentCID += 1
				}
				index += 2
			} else if let endCID = secondValue.integer(lookup: lookup) {
				guard index + 2 < wArray.count else {
					break
				}

				if let width = wArray[index + 2].real(lookup: lookup) {
					let range: CIDRange = UInt32(startCID)...UInt32(endCID)
					widthMap.append((range, width))
				}
				index += 3
			} else {
				index += 1
			}
		}

		return widthMap
	}

	static func parseCIDToGIDMap(
		_ cidToGIDMapObject: PdfObject?,
		_ lookup: PdfObjectLookup?
	) throws -> CIDToGIDMap {
		if let identityName = cidToGIDMapObject?.name(lookup: lookup), identityName == .Identity {
			return .identity
		}

		guard let stream = cidToGIDMapObject?.stream(lookup: lookup) else {
			return .identity
		}

		let data = stream.data
		guard data.count % 2 == 0 else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		let count = data.count / 2
		var gidArray: [UInt16] = []
		gidArray.reserveCapacity(count)

		for i in 0..<count {
			let startIndex = i * 2
			guard startIndex + 2 <= data.count else {
				break
			}

			let value = data.withUnsafeBytes { bytes in
				let uint16Ptr = bytes.bindMemory(to: UInt16.self)
				return UInt16(bigEndian: uint16Ptr[startIndex])
			}

			gidArray.append(value)
		}

		return .mapped(gidArray)
	}
}
