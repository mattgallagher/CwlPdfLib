// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
@testable import CwlPdfRenderer
import Testing

struct PdfJBIG2Tests {
	@Test
	func `GIVEN PDFUA magazine page 27 WHEN JBIG2 stencils are loaded THEN each stencil decodes`() throws {
		let document = try fixtureDocument(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-01_Magazine-danish.pdf"
		)
		let page = try #require(document.pages.indices.contains(26) ? document.pages[26] : nil)
		let content = page.content(lookup: document.lookup)
		let expectedDimensions = [
			"Im1": (width: 310, height: 368),
			"Im2": (width: 337, height: 357),
			"Im3": (width: 336, height: 367),
			"Im4": (width: 355, height: 331)
		]

		for (name, dimensions) in expectedDimensions {
			let stream = try #require(
				content.resolveResourceStream(
					category: .XObject,
					key: name,
					lookup: document.lookup
				)
			)
			let image = try PdfImage(stream: stream, lookup: document.lookup)
			#expect(image.encoding == .jbig2)
			#expect(image.imageMask)
			let mask = try #require(image.createCGImageMask())
			#expect(mask.width == dimensions.width)
			#expect(mask.height == dimensions.height)
		}
	}
}
