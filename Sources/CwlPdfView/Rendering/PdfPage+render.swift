// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfPage {
	func render(in context: CGContext, lookup: PdfObjectLookup?) {
		for contentStream in contentStreams(lookup: lookup) {
			contentStream.render(in: context, lookup: lookup)
		}
		
		for
			annotation in pageDictionary[.Annots]?
				.array(lookup: lookup)?
				.compactMap({ $0.dictionary(lookup: lookup) }) ?? []
		{
			guard
				let appearanceStream = annotation[.AP]?.dictionary(lookup: lookup)?[.N]?.stream(lookup: lookup),
				let annotationRect = annotation[.Rect]?.array(lookup: lookup).map({ PdfRect(array: $0, lookup: lookup) })
			else {
				continue
			}
			let contentStream = PdfContentStream(
				stream: appearanceStream,
				resources: nil,
				annotationRect: annotationRect,
				lookup: lookup
			)
			contentStream.render(in: context, lookup: lookup)
		}
	}
}
