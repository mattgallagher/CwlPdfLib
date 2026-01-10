// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfPage {
	func render(in context: CGContext, lookup: PdfObjectLookup?) {
		guard let contentStream = contentStream(lookup: lookup) else {
			return
		}
		
		contentStream.render(in: context, lookup: lookup)
	}
}
