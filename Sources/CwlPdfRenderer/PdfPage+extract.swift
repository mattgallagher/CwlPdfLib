// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfPage {
	public func extract(features: PdfExtractedFeatureKind, lookup: PdfObjectLookup?) -> [PdfExtractedFeature] {
		guard !features.isEmpty else {
			return []
		}

		var extracted = [PdfExtractedFeature]()

		if features.contains(.annotations) {
			let annotationObjects = pageDictionary[.Annots]?.array(lookup: lookup) ?? []
			for (index, annotationObject) in annotationObjects.enumerated() {
				guard
					let annotation = annotationObject.dictionary(lookup: lookup),
					let rectArray = annotation[.Rect]?.array(lookup: lookup),
					let rect = PdfRect(array: rectArray, lookup: lookup)
				else {
					continue
				}
				let type = annotation[.Subtype]?.name(lookup: lookup)
				extracted.append(
					PdfExtractedFeature(
						bounds: rect,
						matrix: .identity,
						payload: .annotation(annotationType: type, annotationIndex: index, objectIdentifier: annotationObject.reference)
					)
				)
			}
		}

		if features.intersection([.images, .text]).isEmpty {
			return extracted
		}

		extracted.append(
			contentsOf: content(lookup: lookup).extract(features: features, lookup: lookup, initialCTM: .identity)
		)

		return extracted
	}
}
