// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

@testable import CwlPdfParser
import Foundation
import Testing

struct PdfStringEncodingTests {
	@Test
	func `GIVEN PDFDocEncoding bytes WHEN pdfTextToString THEN bytes decode without BOM`() {
		let data = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x80, 0x20, 0x93, 0x94, 0x20, 0xA0])

		#expect(data.pdfTextToString() == "Hello • ﬁﬂ ₢")
	}
}
