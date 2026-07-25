// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

@testable import CwlPdfParser
import Testing

struct PdfRectTests {
	@Test
	func `GIVEN overlapping rectangles WHEN intersected THEN shared rectangle returned`() {
		let first = PdfRect(x: 0, y: 0, width: 100, height: 80)
		let second = PdfRect(x: 25, y: 10, width: 100, height: 100)

		#expect(first.intersection(second) == PdfRect(x: 25, y: 10, width: 75, height: 70))
	}

	@Test
	func `GIVEN disjoint rectangles WHEN intersected THEN nil returned`() {
		let first = PdfRect(x: 0, y: 0, width: 10, height: 10)
		let second = PdfRect(x: 20, y: 20, width: 10, height: 10)

		#expect(first.intersection(second) == nil)
	}
}
