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
			let annotations = pageDictionary[.Annots]?
				.array(lookup: lookup)?
				.compactMap { $0.dictionary(lookup: lookup) }
				?? []
			for (index, annotation) in annotations.enumerated() {
				guard
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
						payload: .annotation(annotationType: type, annotationIndex: index)
					)
				)
			}
		}

		if features.intersection([.images, .text]).isEmpty {
			return extracted
		}

		for contentStream in contentStreams(lookup: lookup) {
			extracted.append(contentsOf: contentStream.extract(features: features, lookup: lookup, initialCTM: .identity))
		}

		return extracted
	}
}
