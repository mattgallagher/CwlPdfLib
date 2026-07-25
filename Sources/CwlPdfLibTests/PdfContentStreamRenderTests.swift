// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser
@testable import CwlPdfRenderer
import Foundation
import Testing

struct PdfContentStreamRenderTests {
	@Test
	func `GIVEN content without a color operator WHEN rendered over a white background THEN PDF initial black is used`() throws {
		let document = try PdfDocument(
			source: PdfDataSource(minimalPdfData(contentStream: "0 0 40 40 re f"))
		)
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 1))

		#expect(pixel(atX: 20, y: 20, in: image) == .black)
	}

	@Test
	func `GIVEN a zero length round dash WHEN rendered THEN separated dots are drawn`() throws {
		let document = try PdfDocument(
			source: PdfDataSource(
				minimalPdfData(contentStream: "1 J 1 w [0 5] 0 d 5 20 m 35 20 l S")
			)
		)
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 2))
		let firstDot = try #require(rgbaPixel(atX: 10, y: 40, in: image))
		let secondDot = try #require(rgbaPixel(atX: 20, y: 40, in: image))

		#expect(firstDot.red < 128)
		#expect(pixel(atX: 15, y: 40, in: image) == .white)
		#expect(secondDot.red < 128)
	}

	@Test
	func `GIVEN a caller graphics state WHEN a page is rendered THEN PDF initial values are isolated from the caller`() throws {
		let document = try PdfDocument(
			source: PdfDataSource(
				minimalPdfData(contentStream: "0 0 20 40 re f 30 0 m 30 40 l S")
			)
		)
		let page = try #require(document.pages.first)
		guard let context = CGContext(
			data: nil,
			width: 40,
			height: 40,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			Issue.record("Failed to create CGContext")
			return
		}
		context.setFillColor(CGColor(gray: 1, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
		context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
		context.setLineDash(phase: 0, lengths: [2, 2])
		context.setLineWidth(9)
		context.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))

		try page.render(in: context, lookup: document.lookup, cancellationCheck: {})
		context.fill(CGRect(x: 35, y: 0, width: 5, height: 40))
		let image = try #require(context.makeImage())
		let initialStroke = try #require(rgbaPixel(atX: 30, y: 20, in: image))
		let restoredColor = try #require(rgbaPixel(atX: 37, y: 20, in: image))

		#expect(pixel(atX: 10, y: 20, in: image) == .black)
		#expect(pixel(atX: 26, y: 20, in: image) == .white)
		#expect(initialStroke.red == initialStroke.green)
		#expect(initialStroke.green == initialStroke.blue)
		#expect(initialStroke.red < 255)
		#expect(restoredColor.red > 200)
		#expect(restoredColor.green < 100)
		#expect(restoredColor.blue < 100)
	}

	@Test
	func `GIVEN an image render request WHEN page renderer completes THEN image has requested dimensions`() async throws {
		let document = try PdfDocument(source: PdfDataSource(minimalPdfData(contentStream: "0 g 0 0 40 40 re f")))
		let page = try #require(document.pages.first)
		let image = try page.renderedImage(
			lookup: document.lookup,
			bounds: page.renderBounds(lookup: document.lookup),
			pixelWidth: 80,
			pixelHeight: 60,
			cancellationCheck: {}
		)
		
		#expect(image.width == 80)
		#expect(image.height == 60)
	}
	
	@Test
	func `GIVEN a cancelled render WHEN operators are processed THEN render stops with cancellation`() throws {
		let contentStream = Array(repeating: "0 0 1 rg 0 0 40 40 re f", count: 100).joined(separator: "\n")
		let document = try PdfDocument(source: PdfDataSource(minimalPdfData(contentStream: contentStream)))
		let page = try #require(document.pages.first)
		guard let context = CGContext(
			data: nil,
			width: 40,
			height: 40,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			Issue.record("Failed to create CGContext")
			return
		}
		var checks = 0
		
		#expect(throws: CancellationError.self) {
			try page.render(in: context, lookup: document.lookup) {
				checks += 1
				if checks > 10 {
					throw CancellationError()
				}
			}
		}
		#expect(checks == 11)
	}
	
	@Test
	func `GIVEN a pending clip before graphics state restore WHEN the path ends after restore THEN the deferred clip is discarded`() throws {
		let document = try PdfDocument(source: PdfDataSource(minimalPdfData(contentStream: "0 g q 0 0 20 20 re W Q n 0 0 40 40 re f")))
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 1))

		#expect(pixel(atX: 10, y: 10, in: image) == .black)
		#expect(pixel(atX: 30, y: 30, in: image) == .black)
	}

	@Test
	func `GIVEN a font change inside graphics state save WHEN restored THEN previous text state is restored`() throws {
		let resources = """
		/Resources << /Font <<
		/F1 << /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>
		/F2 << /Type /Font /Subtype /Type1 /BaseFont /Symbol /Encoding /MacRomanEncoding >>
		>> >>
		"""
		let document = try PdfDocument(
			source: PdfDataSource(
				minimalPdfData(
					contentStream: "/F1 1 Tf q /F2 1 Tf Q",
					pageResources: resources
				)
			)
		)
		let page = try #require(document.pages.first)
		let content = page.content(lookup: document.lookup)
		let stream = try #require(content.streams.first)
		guard let context = CGContext(
			data: nil,
			width: 40,
			height: 40,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			Issue.record("Failed to create CGContext")
			return
		}
		var renderer = PdfRenderer(deviceScaleX: 1, deviceScaleY: 1)

		try renderer.render(stream, resources: content, in: context, lookup: document.lookup, cancellationCheck: {})

		guard case .simple(let simple)? = renderer.textState.font?.kind else {
			Issue.record("Expected a simple font")
			return
		}
		#expect(simple.encoding.baseEncoding == .WinAnsiEncoding)
	}

	@Test
	func `GIVEN a path split across page content streams WHEN rendered THEN graphics state is preserved`() throws {
		let document = try PdfDocument(
			source: PdfDataSource(
				minimalPdfData(
					contentStreams: [
						"0 g 10 10 m 30 10 l ",
						"30 30 l 10 30 l h f"
					]
				)
			)
		)
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 1))

		#expect(pixel(atX: 20, y: 20, in: image) == .black)
		#expect(pixel(atX: 5, y: 5, in: image) == .white)
	}

	@Test
	func `GIVEN a compound rectangle with reversed winding WHEN filled THEN the inner rectangle is hollow`() throws {
		let document = try PdfDocument(
			source: PdfDataSource(minimalPdfData(contentStream: "0 g 5 5 30 30 re 10 30 20 -20 re f"))
		)
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 1))

		#expect(pixel(atX: 7, y: 7, in: image) == .black)
		#expect(pixel(atX: 20, y: 20, in: image) == .white)
	}

	@Test
	func `GIVEN a separation color space WHEN filled THEN the tint transform supplies the color`() throws {
		let resources = """
		/Resources << /ColorSpace << /CS0 [
		/Separation /Silver /DeviceCMYK
		<< /FunctionType 2 /Domain [0 1] /C0 [0 0 0 0]
		/C1 [0.288243 0.214786 0.223178 0.0285039]
		/N 1 /Range [0 1 0 1 0 1 0 1] >>
		] >> >>
		"""
		let document = try PdfDocument(
			source: PdfDataSource(
				minimalPdfData(
					contentStream: "/CS0 cs 1 scn 0 0 40 40 re f",
					pageResources: resources
				)
			)
		)
		let page = try #require(document.pages.first)
		let image = try #require(page.renderedImage(lookup: document.lookup, scale: 1))
		let color = try #require(rgbaPixel(atX: 20, y: 20, in: image))

		#expect(color.red > 120)
		#expect(color.green > 120)
		#expect(color.blue > 120)
	}

	@Test
	func `GIVEN an inherited clip and no local soft mask WHEN SMask None is applied THEN the inherited clip remains active`() throws {
		guard let context = CGContext(
			data: nil,
			width: 40,
			height: 40,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			Issue.record("Failed to create CGContext")
			return
		}

		context.setFillColor(CGColor(gray: 1, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
		context.clip(to: CGRect(x: 0, y: 0, width: 20, height: 40))

		let gstate = PdfExtGState(
			dictionary: [
				.SMask: .name(.None)
			],
			lookup: nil
		)
		var renderState = RenderState()
		context.apply(gstate, renderState: &renderState, renderStack: [], lookup: nil)

		context.setFillColor(CGColor(gray: 0, alpha: 1))
		context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
		let image = try #require(context.makeImage())

		#expect(pixel(atX: 10, y: 10, in: image) == .black)
		#expect(pixel(atX: 30, y: 10, in: image) == .white)
	}
}

private func pixel(atX x: Int, y: Int, in image: CGImage) -> PixelColor? {
	guard let pixel = rgbaPixel(atX: x, y: y, in: image) else {
		return nil
	}

	switch (pixel.red, pixel.green, pixel.blue, pixel.alpha) {
	case (0, 0, 0, 255):
		return .black
	case (255, 255, 255, 255):
		return .white
	default:
		return .other
	}
}

private func rgbaPixel(atX x: Int, y: Int, in image: CGImage) -> RGBAPixel? {
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
	return RGBAPixel(
		red: bytes?[offset] ?? 0,
		green: bytes?[offset + 1] ?? 0,
		blue: bytes?[offset + 2] ?? 0,
		alpha: bytes?[offset + 3] ?? 0
	)
}

private struct RGBAPixel {
	let red: UInt8
	let green: UInt8
	let blue: UInt8
	let alpha: UInt8
}

private enum PixelColor {
	case black
	case other
	case white
}

private func minimalPdfData(contentStream: String, pageResources: String = "") -> Data {
	minimalPdfData(contentStreams: [contentStream], pageResources: pageResources)
}

private func minimalPdfData(contentStreams: [String], pageResources: String = "") -> Data {
	let contentReferences = (0..<contentStreams.count)
		.map { "\($0 + 4) 0 R" }
		.joined(separator: " ")
	let objects = [
		"1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
		"2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
		"3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 40 40] /Contents [\(contentReferences)] \(pageResources) >>\nendobj\n"
	] + contentStreams.enumerated().map { index, contentStream in
		let streamData = Data(contentStream.utf8)
		return "\((index + 4)) 0 obj\n<< /Length \(streamData.count) >>\nstream\n\(contentStream)\nendstream\nendobj\n"
	}

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
