// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CwlPdfRenderer
import Foundation
import Testing

struct PdfStreamCGImageTests {
	@Test
	func `GIVEN an image stream WHEN cgImage requested THEN image is created`() throws {
		let stream = PdfStream(
			objectIdentifier: PdfObjectIdentifier(number: 1, generation: 0),
			dictionary: [
				.Subtype: .name(.Image),
				.Width: .integer(1),
				.Height: .integer(1),
				.ColorSpace: .name(.DeviceRGB),
				.BitsPerComponent: .integer(8)
			],
			data: Data([255, 0, 0])
		)

		let image = try #require(stream.cgImage(lookup: nil))
		#expect(image.width == 1)
		#expect(image.height == 1)
	}

	@Test
	func `GIVEN a non image stream WHEN cgImage requested THEN nil is returned`() {
		let stream = PdfStream(
			objectIdentifier: PdfObjectIdentifier(number: 2, generation: 0),
			dictionary: [
				.Subtype: .name(.Form)
			],
			data: Data()
		)

		#expect(stream.cgImage(lookup: nil) == nil)
	}
}
