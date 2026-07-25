// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

/// Describes failures that can occur while rendering a PDF page into a `CGImage`.
public enum PdfPageImageRenderError: Error, Sendable {
	case contextCreationFailed
	case imageCreationFailed
	case invalidSize
}

extension PdfPage {
	public func renderBounds(lookup: PdfObjectLookup?) -> CGRect {
		return pageRect(lookup: lookup).cgRect
	}

	public func render(in context: CGContext, lookup: PdfObjectLookup?) {
		try? render(in: context, lookup: lookup, cancellationCheck: {})
	}

	/// Renders the page into the context and periodically invokes `cancellationCheck`.
	public func render(
		in context: CGContext,
		lookup: PdfObjectLookup?,
		cancellationCheck: () throws -> Void
	) throws {
		try cancellationCheck()
		
		context.saveGState()
		defer {
			context.restoreGState()
		}
		context.applyPdfInitialGraphicsState(colorState: ColorState())

		let rect = renderBounds(lookup: lookup)
		let deviceScaleX = max(hypot(context.ctm.a, context.ctm.c), 1)
		let deviceScaleY = max(hypot(context.ctm.b, context.ctm.d), 1)
		
		let content = content(lookup: lookup)
		if !content.streams.isEmpty {
			try content.render(
				in: context,
				pageBounds: rect,
				lookup: lookup,
				deviceScaleX: deviceScaleX,
				deviceScaleY: deviceScaleY,
				cancellationCheck: cancellationCheck
			)
		}
		
		for
			annotation in pageDictionary[.Annots]?
				.array(lookup: lookup)?
				.compactMap({ $0.dictionary(lookup: lookup) }) ?? []
		{
			try cancellationCheck()
			
			guard
				let appearanceStream = annotation[.AP]?.dictionary(lookup: lookup)?[.N]?.stream(lookup: lookup),
				let annotationRect = annotation[.Rect]?.array(lookup: lookup).flatMap({ PdfRect(array: $0, lookup: lookup) })
			else {
				continue
			}
			
			let appearance = PdfAnnotationAppearanceContent(
				stream: appearanceStream,
				annotationRect: annotationRect,
				resources: nil,
				lookup: lookup
			)
			try appearance.render(
				in: context,
				pageBounds: rect,
				lookup: lookup,
				deviceScaleX: deviceScaleX,
				deviceScaleY: deviceScaleY,
				cancellationCheck: cancellationCheck
			)
		}
	}

	/// Renders the page into a `CGImage` at the supplied scale.
	///
	/// - Parameters:
	///   - lookup: The object lookup used while rendering page content.
	///   - scale: The number of output pixels per page-space unit.
	///   - backgroundColor: The color painted behind the page, or `nil` for transparency.
	///   - destinationColorSpace: The RGB color space of the rendered bitmap. Defaults to sRGB.
	public func renderedImage(
		lookup: PdfObjectLookup?,
		scale: CGFloat = 1,
		backgroundColor: CGColor? = CGColor(gray: 1, alpha: 1),
		destinationColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
	) -> CGImage? {
		guard
			scale > 0
		else {
			return nil
		}
		
		let bounds = renderBounds(lookup: lookup)
		let pixelWidth = Int((bounds.width * scale).rounded(.up))
		let pixelHeight = Int((bounds.height * scale).rounded(.up))
		return try? renderedImage(
			pixelWidth: pixelWidth,
			pixelHeight: pixelHeight,
			backgroundColor: backgroundColor,
			destinationColorSpace: destinationColorSpace,
			cancellationCheck: {}
		) { context in
			context.scaleBy(x: scale, y: scale)
			context.translateBy(x: -bounds.minX, y: -bounds.minY + bounds.height)
			context.scaleBy(x: 1, y: -1)
			render(in: context, lookup: lookup)
		}
	}
	
	/// Renders the page into a `CGImage` with the supplied pixel dimensions.
	///
	/// - Parameters:
	///   - lookup: The object lookup used while rendering page content.
	///   - bounds: The page-space bounds to render.
	///   - pixelWidth: The output image width in pixels.
	///   - pixelHeight: The output image height in pixels.
	///   - backgroundColor: The color painted behind the page, or `nil` for transparency.
	///   - destinationColorSpace: The RGB color space of the rendered bitmap. Defaults to sRGB.
	///   - cancellationCheck: A closure invoked periodically to stop cancelled renders.
	public func renderedImage(
		lookup: PdfObjectLookup?,
		bounds: CGRect,
		pixelWidth: Int,
		pixelHeight: Int,
		backgroundColor: CGColor? = CGColor(gray: 1, alpha: 1),
		destinationColorSpace: CGColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!,
		cancellationCheck: () throws -> Void
	) throws -> CGImage {
		try cancellationCheck()
		
		guard
			bounds.width > 0,
			bounds.height > 0,
			pixelWidth > 0,
			pixelHeight > 0
		else {
			throw PdfPageImageRenderError.invalidSize
		}
		
		return try renderedImage(
			pixelWidth: pixelWidth,
			pixelHeight: pixelHeight,
			backgroundColor: backgroundColor,
			destinationColorSpace: destinationColorSpace,
			cancellationCheck: cancellationCheck
		) { context in
			context.scaleBy(
				x: CGFloat(pixelWidth) / bounds.width,
				y: CGFloat(pixelHeight) / bounds.height
			)
			context.translateBy(x: -bounds.minX, y: -bounds.minY)
			try render(in: context, lookup: lookup, cancellationCheck: cancellationCheck)
		}
	}
	
	private func renderedImage(
		pixelWidth: Int,
		pixelHeight: Int,
		backgroundColor: CGColor?,
		destinationColorSpace: CGColorSpace,
		cancellationCheck: () throws -> Void,
		render: (CGContext) throws -> Void
	) throws -> CGImage {
		try cancellationCheck()
		
		guard
			pixelWidth > 0,
			pixelHeight > 0
		else {
			throw PdfPageImageRenderError.invalidSize
		}
		
		guard let context = CGContext(
			data: nil,
			width: pixelWidth,
			height: pixelHeight,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: destinationColorSpace,
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			throw PdfPageImageRenderError.contextCreationFailed
		}
		
		if let backgroundColor {
			context.saveGState()
			context.setFillColor(backgroundColor)
			context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
			context.restoreGState()
		}
		
		try cancellationCheck()
		try render(context)
		
		guard let image = context.makeImage() else {
			throw PdfPageImageRenderError.imageCreationFailed
		}
		
		return image
	}
}
