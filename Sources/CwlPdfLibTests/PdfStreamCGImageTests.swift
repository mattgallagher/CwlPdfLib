// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser
@testable import CwlPdfRenderer
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

	@Test
	func `GIVEN PDFUA page 5 image WHEN color space is resolved THEN DefaultCMYK ICC profile and intent reach CGImage`() throws {
		let document = try fixtureDocument(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-08_BookChapter.pdf"
		)
		let page = try #require(document.pages.indices.contains(4) ? document.pages[4] : nil)
		let content = page.content(lookup: document.lookup)
		let stream = try #require(content.resolveResourceStream(
			category: .XObject,
			key: "Im0",
			lookup: document.lookup
		))
		let renderer = PdfRenderer(deviceScaleX: 1, deviceScaleY: 1)
		let colorSpace = try #require(renderer.resolveColorSpace(
			stream.dictionary[.ColorSpace],
			content: content,
			lookup: document.lookup
		))
		guard case .iccBased(let components, let profile) = colorSpace else {
			Issue.record("Expected the page DefaultCMYK ICC color space")
			return
		}
		let pdfImage = try PdfImage(
			stream: stream,
			lookup: document.lookup,
			resolvedColorSpace: colorSpace
		)
		let cgImage = try #require(pdfImage.createCGImage(lookup: document.lookup))
		let cgProfile = try #require(cgImage.colorSpace?.copyICCData())

		#expect(components == 4)
		#expect(cgProfile as Data == profile)
		#expect(cgImage.renderingIntent == .relativeColorimetric)
	}

	@Test
	func `GIVEN PDF image intents WHEN raw images are created THEN colorimetric intents reach CGImage`() throws {
		let intents: [(pdf: String, cg: CGColorRenderingIntent)] = [
			("AbsoluteColorimetric", .absoluteColorimetric),
			("Perceptual", .perceptual),
			("RelativeColorimetric", .relativeColorimetric),
			("Saturation", .saturation)
		]

		for (index, intent) in intents.enumerated() {
			let stream = PdfStream(
				objectIdentifier: PdfObjectIdentifier(number: index + 10, generation: 0),
				dictionary: [
					.BitsPerComponent: .integer(8),
					.ColorSpace: .name(.DeviceRGB),
					.Height: .integer(1),
					.Intent: .name(intent.pdf),
					.Subtype: .name(.Image),
					.Width: .integer(1)
				],
				data: Data([255, 0, 0])
			)
			let image = try #require(stream.cgImage(lookup: nil))

			#expect(image.renderingIntent == intent.cg)
		}
	}
}
