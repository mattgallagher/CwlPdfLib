// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser
import CwlPdfRenderer
import Foundation
import ImageIO
import PDFKit
import Testing
import UniformTypeIdentifiers

struct PdfPageRenderTests {
	@Test(arguments: [
		("blank-page.pdf", 1),
		("single-text-line.pdf", 1),
		("text-shapes-shading.pdf", 1),
		("three-page-annots.pdf", 1),
		("three-page-annots.pdf", 2),
		("three-page-annots.pdf", 3)
	])
	func `GIVEN a fixture page WHEN rendered by CwlPdfRenderer and PDFKit THEN pixel difference remains below threshold`(filename: String, pageNumber: Int) throws {
		let fileURL = try #require(resolveFixtureURL(filename: filename))
		let dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		let document = try PdfDocument(source: dataSource)

		let pageIndex = pageNumber - 1
		#expect(pageIndex >= 0)
		let page = try #require(document.pages.indices.contains(pageIndex) ? document.pages[pageIndex] : nil)

		let pdfKitDocument = try #require(PDFDocument(url: fileURL))
		let pdfKitPage = try #require(pdfKitDocument.page(at: pageIndex))
		let scale: CGFloat = 2
		let renderedImage = try #require(renderCwlPdfRendererImage(page: page, lookup: document.lookup, pdfKitPage: pdfKitPage, scale: scale))
		let pdfKitImage = try #require(renderPDFKitImage(page: pdfKitPage, scale: scale))
		#expect(pdfKitImage.width == renderedImage.width)
		#expect(pdfKitImage.height == renderedImage.height)

		let debugDirectory = try makeDebugDirectory()
		let debugBaseName = "\(filename.replacingOccurrences(of: ".pdf", with: ""))-page-\(pageNumber)"
		let debugURLs = DebugImageURLs(
			ours: debugDirectory.appending(path: "\(debugBaseName)-ours.png"),
			pdfKit: debugDirectory.appending(path: "\(debugBaseName)-pdfkit.png"),
			diff: debugDirectory.appending(path: "\(debugBaseName)-diff.png")
		)
		try writePNG(image: renderedImage, to: debugURLs.ours)
		try writePNG(image: pdfKitImage, to: debugURLs.pdfKit)
		let difference = pixelDifference(lhs: renderedImage, rhs: pdfKitImage, diffURL: debugURLs.diff)
		print("Difference: \(difference)")
		#expect(
			difference.normalizedTotal < 0.00000001,
			"""
			Expected less than 0.01% pixel difference but found \(difference.normalizedTotal * 100)% for \(filename) page \(pageNumber).
			rgb=\(difference.normalizedRGB * 100)% alpha=\(difference.normalizedAlpha * 100)% differentPixels=\(difference.differentPixels)/\(difference.totalPixels)
			layout ours: \(difference.lhsLayout)
			layout pdfkit: \(difference.rhsLayout)
			Debug PNGs:
			\(debugURLs.ours.path)
			\(debugURLs.pdfKit.path)
			\(debugURLs.diff.path)
			"""
		)
	}
}

private struct DebugImageURLs {
	let ours: URL
	let pdfKit: URL
	let diff: URL
}

private struct PixelDifference {
	let normalizedTotal: Double
	let normalizedRGB: Double
	let normalizedAlpha: Double
	let differentPixels: Int
	let totalPixels: Int
	let lhsLayout: String
	let rhsLayout: String
}

private func resolveFixtureURL(filename: String) -> URL? {
	let fallback = filename == "three-page-annots.pdf" ? "three-page-images-annots.pdf" : nil
	let candidates = [filename, fallback].compactMap(\.self)
	for candidate in candidates {
		if let fileURL = Bundle.module.url(forResource: "Fixtures/Basic/\(candidate)", withExtension: nil) {
			return fileURL
		}
	}
	return nil
}

private func renderCwlPdfRendererImage(page: PdfPage, lookup: PdfObjectLookup?, pdfKitPage: PDFPage, scale: CGFloat) -> CGImage? {
	renderPageImage(pdfKitPage: pdfKitPage, scale: scale) { context in
		page.render(in: context, lookup: lookup)
	}
}

private func renderPDFKitImage(page: PDFPage, scale: CGFloat) -> CGImage? {
	renderPageImage(pdfKitPage: page, scale: scale) { context in
		page.draw(with: .cropBox, to: context)
	}
}

private func renderPageImage(pdfKitPage: PDFPage, scale: CGFloat, draw: (CGContext) -> Void) -> CGImage? {
	guard
		let pageRef = pdfKitPage.pageRef
	else {
		return nil
	}

	let cropBounds = pdfKitPage.bounds(for: .cropBox)
	guard
		scale > 0,
		cropBounds.width > 0,
		cropBounds.height > 0
	else {
		return nil
	}

	let width = Int((cropBounds.width * scale).rounded(.up))
	let height = Int((cropBounds.height * scale).rounded(.up))
	guard
		width > 0,
		height > 0,
		let context = CGContext(
			data: nil,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		)
	else {
		return nil
	}

	context.setFillColor(CGColor(gray: 1, alpha: 1))
	context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

	let targetRect = CGRect(
		x: 0,
		y: 0,
		width: cropBounds.width,
		height: cropBounds.height
	)
	let drawingTransform = pageRef.getDrawingTransform(
		.cropBox,
		rect: targetRect,
		rotate: Int32(pdfKitPage.rotation),
		preserveAspectRatio: true
	)
	context.concatenate(drawingTransform)
	context.concatenate(CGAffineTransform(scaleX: scale, y: scale))
	draw(context)
	return context.makeImage()
}

private func makeDebugDirectory() throws -> URL {
	let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appending(path: "CwlPdfRenderDebug", directoryHint: .isDirectory)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	return directory
}

private func writePNG(image: CGImage, to url: URL) throws {
	guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
		throw CocoaError(.fileWriteUnknown)
	}
	CGImageDestinationAddImage(destination, image, nil)
	guard CGImageDestinationFinalize(destination) else {
		throw CocoaError(.fileWriteUnknown)
	}
}

private func pixelDifference(lhs: CGImage, rhs: CGImage, diffURL: URL) -> PixelDifference {
	guard
		lhs.width == rhs.width,
		lhs.height == rhs.height
	else {
		return PixelDifference(
			normalizedTotal: 1,
			normalizedRGB: 1,
			normalizedAlpha: 1,
			differentPixels: lhs.width * lhs.height,
			totalPixels: lhs.width * lhs.height,
			lhsLayout: imageLayoutDescription(lhs),
			rhsLayout: imageLayoutDescription(rhs)
		)
	}

	guard
		let lhsBuffer = canonicalRGBAData(from: lhs),
		let rhsBuffer = canonicalRGBAData(from: rhs)
	else {
		return PixelDifference(
			normalizedTotal: 1,
			normalizedRGB: 1,
			normalizedAlpha: 1,
			differentPixels: lhs.width * lhs.height,
			totalPixels: lhs.width * lhs.height,
			lhsLayout: imageLayoutDescription(lhs),
			rhsLayout: imageLayoutDescription(rhs)
		)
	}

	let pixelCount = lhs.width * lhs.height
	var totalDifference = 0
	var totalRGBDifference = 0
	var totalAlphaDifference = 0
	var differentPixels = 0
	let halfEightBit = Int(UInt8.max / 2)
	var diffPixels = [UInt8](repeating: UInt8(halfEightBit), count: pixelCount * 4)

	for pixelIndex in 0..<pixelCount {
		let base = pixelIndex * 4
		let redDiff = Int(lhsBuffer.pixels[base]) - Int(rhsBuffer.pixels[base])
		let greenDiff = Int(lhsBuffer.pixels[base + 1]) - Int(rhsBuffer.pixels[base + 1])
		let blueDiff = Int(lhsBuffer.pixels[base + 2]) - Int(rhsBuffer.pixels[base + 2])
		let alphaDiff = Int(lhsBuffer.pixels[base + 3]) - Int(rhsBuffer.pixels[base + 3])
		let pixelDifference = abs(redDiff) + abs(greenDiff) + abs(blueDiff) + abs(alphaDiff)

		totalDifference += pixelDifference
		totalRGBDifference += abs(redDiff) + abs(greenDiff) + abs(blueDiff)
		totalAlphaDifference += abs(alphaDiff)
		if pixelDifference != 0 {
			differentPixels += 1
		}

		let rgbDelta = halfEightBit + 2 * (redDiff / 2 + greenDiff / 2 + blueDiff / 2) / 3
		let grayscale = UInt8(max(0, min(255, rgbDelta)))
		diffPixels[base] = grayscale
		diffPixels[base + 1] = grayscale
		diffPixels[base + 2] = grayscale
		diffPixels[base + 3] = 255
	}

	if let diffContext = CGContext(
		data: &diffPixels,
		width: lhs.width,
		height: lhs.height,
		bitsPerComponent: 8,
		bytesPerRow: lhs.width * 4,
		space: CGColorSpaceCreateDeviceRGB(),
		bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
	),
		let diffImage = diffContext.makeImage()
	{
		try? writePNG(image: diffImage, to: diffURL)
	}

	return PixelDifference(
		normalizedTotal: Double(totalDifference) / (Double(pixelCount * 4) * 255),
		normalizedRGB: Double(totalRGBDifference) / (Double(pixelCount * 3) * 255),
		normalizedAlpha: Double(totalAlphaDifference) / (Double(pixelCount) * 255),
		differentPixels: differentPixels,
		totalPixels: pixelCount,
		lhsLayout: "\(imageLayoutDescription(lhs)); canonicalBytesPerRow=\(lhsBuffer.bytesPerRow)",
		rhsLayout: "\(imageLayoutDescription(rhs)); canonicalBytesPerRow=\(rhsBuffer.bytesPerRow)"
	)
}

private struct CanonicalRGBAData {
	let pixels: [UInt8]
	let bytesPerRow: Int
}

private func canonicalRGBAData(from image: CGImage) -> CanonicalRGBAData? {
	let width = image.width
	let height = image.height
	guard
		width > 0,
		height > 0
	else {
		return nil
	}

	let bytesPerRow = width * 4
	var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
	guard
		let context = CGContext(
			data: &pixels,
			width: width,
			height: height,
			bitsPerComponent: 8,
			bytesPerRow: bytesPerRow,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
		)
	else {
		return nil
	}
	context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
	return CanonicalRGBAData(pixels: pixels, bytesPerRow: bytesPerRow)
}

private func imageLayoutDescription(_ image: CGImage) -> String {
	"w=\(image.width) h=\(image.height) bpr=\(image.bytesPerRow) bpc=\(image.bitsPerComponent) bpp=\(image.bitsPerPixel) alpha=\(image.alphaInfo.rawValue) bitmapInfo=\(image.bitmapInfo.rawValue)"
}
