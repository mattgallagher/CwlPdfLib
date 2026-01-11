// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfPage {
	func renderBounds(lookup: PdfObjectLookup?) -> CGRect {
		var rect = pageRect(lookup: lookup).cgRect
		rect.origin = .zero
		return rect
	}

	func render(in context: CGContext, lookup: PdfObjectLookup?) {
		let rect = renderBounds(lookup: lookup)
		context.addRect(rect)
		context.clip()
		
		for contentStream in contentStreams(lookup: lookup) {
			contentStream.render(in: context, pageBounds: rect, lookup: lookup)
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
			contentStream.render(in: context, pageBounds: rect, lookup: lookup)
		}
	}
}
