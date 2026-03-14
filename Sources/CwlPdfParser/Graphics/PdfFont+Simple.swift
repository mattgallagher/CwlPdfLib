// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfFont {
	static func parseSimpleKind(
		fontDictionary: PdfDictionary,
		descriptor: PdfDictionary?,
		lookup: PdfObjectLookup?
	) throws -> Kind {
		let encoding = try Self.parseEncoding(fontDictionary[.Encoding], lookup)
		let firstChar = fontDictionary[.FirstChar]?.integer(lookup: lookup) ?? 0
		let missingWidth = descriptor?[.MissingWidth]?.real(lookup: lookup)
		let widths = fontDictionary[.Widths]?
			.array(lookup: lookup)?
			.compactMap { $0.real(lookup: lookup) }
		?? []

		return .simple(
			SimpleFontData(
				encoding: encoding,
				firstChar: firstChar,
				widths: widths,
				missingWidth: missingWidth
			)
		)
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
}
