// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser
import Foundation
import Testing

@testable import CwlPdfRenderer

struct PdfContentStreamRenderTests {
	@Test
	func `GIVEN a pending clip before graphics state restore WHEN the path ends after restore THEN the deferred clip is discarded`() throws {
		let document = try PdfDocument(source: PdfDataSource(minimalPdfData(contentStream: "0 g q 0 0 20 20 re W Q n 0 0 40 40 re f")))
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 1))

		#expect(pixel(atX: 10, y: 10, in: image) == .black)
		#expect(pixel(atX: 30, y: 30, in: image) == .black)
	}
}

private func pixel(atX x: Int, y: Int, in image: CGImage) -> PixelColor? {
	guard
		x >= 0,
		y >= 0,
		x < image.width,
		y < image.height,
		let provider = image.dataProvider,
		let data = provider.data
	else {
		return nil
	}

	let bytes = CFDataGetBytePtr(data)
	let bytesPerPixel = image.bitsPerPixel / 8
	let offset = y * image.bytesPerRow + x * bytesPerPixel
	let red = bytes?[offset]
	let green = bytes?[offset + 1]
	let blue = bytes?[offset + 2]
	let alpha = bytes?[offset + 3]

	switch (red, green, blue, alpha) {
	case (0, 0, 0, 255):
		return .black
	case (255, 255, 255, 255):
		return .white
	default:
		return .other
	}
}

private enum PixelColor {
	case black
	case other
	case white
}

private func minimalPdfData(contentStream: String) -> Data {
	let streamData = Data(contentStream.utf8)
	let objects = [
		"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
		"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
		"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 40 40] /Contents 4 0 R >>\nendobj\n",
		"4 0 obj\n<< /Length \(streamData.count) >>\nstream\n\(contentStream)\nendstream\nendobj\n"
	]

	var pdf = "%PDF-1.4\n"
	var offsets = [0]
	for object in objects {
		offsets.append(pdf.utf8.count)
		pdf += object
	}

	let xrefOffset = pdf.utf8.count
	pdf += "xref\n0 \(objects.count + 1)\n"
	pdf += "0000000000 65535 f \n"
	for offset in offsets.dropFirst() {
		pdf += String(format: "%010d 00000 n \n", offset)
	}
	pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\n"
	pdf += "startxref\n\(xrefOffset)\n%%EOF\n"
	return Data(pdf.utf8)
}
