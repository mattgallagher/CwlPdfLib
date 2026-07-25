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
		("Basic/blank-page.pdf", 1, nil, 0.0004),
		("Basic/single-text-line.pdf", 1, nil, 0.0004),
		("Basic/text-shapes-shading.pdf", 1, nil, 0.0004),
		("Basic/three-page-images-annots.pdf", 1, nil, 0.0004),
		("Basic/three-page-images-annots.pdf", 2, nil, 0.0004),
		("Basic/three-page-images-annots.pdf", 3, nil, 0.0004),
		("PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-01_Magazine-danish.pdf", 3, CGRect(x: 24, y: 126, width: 334, height: 430), 0.0006),
		("PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-01_Magazine-danish.pdf", 27, CGRect(x: 950, y: 530, width: 180, height: 200), 0.003),
		("PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-03_AcademicAbstract.pdf", 1, nil, 0.0002),
		("PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-03_AcademicAbstract.pdf", 2, nil, 0.0002)
	])
	func `GIVEN a fixture page WHEN rendered by CwlPdfRenderer and PDFKit THEN pixel difference remains below threshold`(fixturePath: String, pageNumber: Int, cropRect: CGRect?, threshold: Double) throws {
		let fileURL = try #require(fixtureURL(path: fixturePath))
		let dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		let document = try PdfDocument(source: dataSource)

		let pageIndex = pageNumber - 1
		let page = try #require(document.pages.indices.contains(pageIndex) ? document.pages[pageIndex] : nil)
		let pdfKitDocument = try #require(PDFDocument(url: fileURL))
		let pdfKitPage = try #require(pdfKitDocument.page(at: pageIndex))
		let scale: CGFloat = 2
		var renderedImage = try #require(renderCwlPdfRendererImage(page: page, lookup: document.lookup, pdfKitPage: pdfKitPage, scale: scale))
		var pdfKitImage = try #require(renderPDFKitImage(page: pdfKitPage, scale: scale))
		#expect(pdfKitImage.width == renderedImage.width)
		#expect(pdfKitImage.height == renderedImage.height)
		if let cropRect {
			renderedImage = try #require(renderedImage.cropping(to: cropRect))
			pdfKitImage = try #require(pdfKitImage.cropping(to: cropRect))
		}

		// When a test fails, set this to `true` to capture the rendered images and diffs for debugging
		#if false
		let debugDirectory = try makeDebugDirectory()
		let debugBaseName = "\(fixturePath.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".pdf", with: ""))-page-\(pageNumber)"
		let debugURLs = DebugImageURLs(
			ours: debugDirectory.appending(path: "\(debugBaseName)-ours.png"),
			pdfKit: debugDirectory.appending(path: "\(debugBaseName)-pdfkit.png"),
			diff: debugDirectory.appending(path: "\(debugBaseName)-diff.png")
		)
		try writePNG(image: renderedImage, to: debugURLs.ours)
		try writePNG(image: pdfKitImage, to: debugURLs.pdfKit)
		let difference = pixelDifference(lhs: renderedImage, rhs: pdfKitImage, diffURL: debugURLs.diff)
		let debugOutput = """
			Debug PNGs:
			\(debugURLs.ours.path)
			\(debugURLs.pdfKit.path)
			\(debugURLs.diff.path)
			"""
		#else
		let difference = pixelDifference(lhs: renderedImage, rhs: pdfKitImage, diffURL: nil)
		let debugOutput = "Debug PNGs disabled in PdfPageRenderTests.swift."
		#endif
		
		#expect(
			difference.normalizedTotal < threshold,
			"""
			Expected less than \(threshold * 100)% pixel difference but found \(difference.normalizedTotal * 100)% for \(fixturePath) page \(pageNumber).
			rgb=\(difference.normalizedRGB * 100)% alpha=\(difference.normalizedAlpha * 100)% differentPixels=\(difference.differentPixels)/\(difference.totalPixels)
			layout ours: \(difference.lhsLayout)
			layout pdfkit: \(difference.rhsLayout)
			\(debugOutput)
			"""
		)
	}

	@Test
	func `GIVEN the page 2 chart WHEN rendered THEN its colors and text match PDFKit`() throws {
		let fileURL = try #require(fixtureURL(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-08_BookChapter.pdf"
		))
		let document = try PdfDocument(
			source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		)
		let page = try #require(document.pages.indices.contains(1) ? document.pages[1] : nil)
		let pdfKitDocument = try #require(PDFDocument(url: fileURL))
		let pdfKitPage = try #require(pdfKitDocument.page(at: 1))
		let scale: CGFloat = 2
		let renderedImage = try #require(renderCwlPdfRendererImage(
			page: page,
			lookup: document.lookup,
			pdfKitPage: pdfKitPage,
			scale: scale
		))
		let pdfKitImage = try #require(renderPDFKitImage(page: pdfKitPage, scale: scale))

		// CwlPdfRenderer currently positions the MediaBox origin differently from PDFKit. Offset the
		// crops so this regression remains focused on the chart's color spaces and text rendering.
		let cropSize = CGSize(width: 482, height: 440)
		let renderedChart = try #require(renderedImage.cropping(to: CGRect(
			origin: CGPoint(x: 204, y: 892),
			size: cropSize
		)))
		let pdfKitChart = try #require(pdfKitImage.cropping(to: CGRect(
			origin: CGPoint(x: 138, y: 958),
			size: cropSize
		)))
		let difference = pixelDifference(lhs: renderedChart, rhs: pdfKitChart, diffURL: nil)

		#expect(
			difference.normalizedTotal < 0.005,
			"Expected less than 0.5% chart pixel difference but found \(difference.normalizedTotal * 100)%"
		)
	}

	@Test
	func `GIVEN the page 5 CMYK photograph WHEN rendered THEN its ICC colors match PDFKit`() throws {
		let fileURL = try #require(fixtureURL(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-08_BookChapter.pdf"
		))
		let document = try PdfDocument(
			source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		)
		let page = try #require(document.pages.indices.contains(4) ? document.pages[4] : nil)
		let pdfKitDocument = try #require(PDFDocument(url: fileURL))
		let pdfKitPage = try #require(pdfKitDocument.page(at: 4))
		let scale: CGFloat = 2
		let renderedImage = try #require(renderCwlPdfRendererImage(
			page: page,
			lookup: document.lookup,
			pdfKitPage: pdfKitPage,
			scale: scale
		))
		let pdfKitImage = try #require(renderPDFKitImage(page: pdfKitPage, scale: scale))

		// CwlPdfRenderer currently positions the MediaBox origin differently from PDFKit. Offset the
		// crops so this regression remains focused on the photograph's color conversion.
		let cropSize = CGSize(width: 590, height: 380)
		let renderedPhotograph = try #require(renderedImage.cropping(to: CGRect(
			origin: CGPoint(x: 206, y: 99),
			size: cropSize
		)))
		let pdfKitPhotograph = try #require(pdfKitImage.cropping(to: CGRect(
			origin: CGPoint(x: 140, y: 165),
			size: cropSize
		)))
		let difference = pixelDifference(lhs: renderedPhotograph, rhs: pdfKitPhotograph, diffURL: nil)

		#expect(
			difference.normalizedTotal < 0.003,
			"Expected less than 0.3% photograph pixel difference but found \(difference.normalizedTotal * 100)%"
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

private func pixelDifference(lhs: CGImage, rhs: CGImage, diffURL: URL?) -> PixelDifference {
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

		let rgbDelta = halfEightBit + (redDiff / 2 + greenDiff / 2 + blueDiff / 2) / 3
		let grayscale = UInt8(max(0, min(255, rgbDelta)))
		diffPixels[base] = grayscale
		diffPixels[base + 1] = grayscale
		diffPixels[base + 2] = grayscale
		diffPixels[base + 3] = 255
	}

	if let diffURL,
		let diffContext = CGContext(
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
