// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfFont {
	static func parseType3Kind(
		fontDictionary: PdfDictionary,
		lookup: PdfObjectLookup?
	) throws -> Kind {
		let encoding = try Self.parseEncoding(fontDictionary[.Encoding], lookup)
		let firstChar = fontDictionary[.FirstChar]?.integer(lookup: lookup) ?? 0
		let widths = fontDictionary[.Widths]?
			.array(lookup: lookup)?
			.compactMap { $0.real(lookup: lookup) }
		?? []

		guard
			let fontBBoxArray = fontDictionary[.FontBBox]?.array(lookup: lookup),
			let fontBBox = PdfRect(array: fontBBoxArray, lookup: lookup)
		else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		guard let charProcs = fontDictionary[.CharProcs]?.dictionary(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		let resources = fontDictionary[.Resources]?.dictionary(lookup: lookup)

		return .type3(
			Type3FontData(
				encoding: encoding,
				firstChar: firstChar,
				widths: widths,
				fontBBox: fontBBox,
				charProcs: charProcs,
				resources: resources
			)
		)
	}
}
