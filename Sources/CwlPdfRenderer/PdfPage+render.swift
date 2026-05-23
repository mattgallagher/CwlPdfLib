// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfPage {
	public func renderBounds(lookup: PdfObjectLookup?) -> CGRect {
		return pageRect(lookup: lookup).cgRect
	}

	public func render(in context: CGContext, lookup: PdfObjectLookup?) {
		let rect = renderBounds(lookup: lookup)
		let deviceScaleX = max(hypot(context.ctm.a, context.ctm.c), 1)
		let deviceScaleY = max(hypot(context.ctm.b, context.ctm.d), 1)
		
		let contentStreams = contentStreams(lookup: lookup)
		if let firstContentStream = contentStreams.first {
			PdfRenderer.performWithRenderState(
				for: firstContentStream,
				in: context,
				pageBounds: rect,
				deviceScaleX: deviceScaleX,
				deviceScaleY: deviceScaleY
			) { state in
				for contentStream in contentStreams {
					state.render(contentStream, in: context, lookup: lookup)
				}
			}
		}
		
		for
			annotation in pageDictionary[.Annots]?
				.array(lookup: lookup)?
				.compactMap({ $0.dictionary(lookup: lookup) }) ?? []
		{
			guard
				let appearanceStream = annotation[.AP]?.dictionary(lookup: lookup)?[.N]?.stream(lookup: lookup),
				let annotationRect = annotation[.Rect]?.array(lookup: lookup).map({ PdfRect(array: $0, lookup: lookup) })
			else {
				continue
			}
			
			let contentStream = PdfContentStream(
				stream: appearanceStream,
				resources: nil,
				annotationRect: annotationRect,
				lookup: lookup
			)
			contentStream.render(
				in: context,
				pageBounds: rect,
				lookup: lookup,
				deviceScaleX: deviceScaleX,
				deviceScaleY: deviceScaleY
			)
		}
	}

	public func renderedImage(
		lookup: PdfObjectLookup?,
		scale: CGFloat = 1,
		backgroundColor: CGColor? = CGColor(gray: 1, alpha: 1)
	) -> CGImage? {
		guard
			scale > 0
		else {
			return nil
		}
		
		let bounds = renderBounds(lookup: lookup)
		let pixelWidth = Int((bounds.width * scale).rounded(.up))
		let pixelHeight = Int((bounds.height * scale).rounded(.up))
		guard
			pixelWidth > 0,
			pixelHeight > 0,
			let context = CGContext(
				data: nil,
				width: pixelWidth,
				height: pixelHeight,
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			)
		else {
			return nil
		}
		
		if let backgroundColor {
			context.setFillColor(backgroundColor)
			// Fill the full bitmap extent in device space so fractional page bounds
			// don't leave a transparent strip on the top/right edges.
			context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
		}
		context.scaleBy(x: scale, y: scale)
		context.translateBy(x: -bounds.minX, y: -bounds.minY + bounds.height)
		context.scaleBy(x: 1, y: -1)
		render(in: context, lookup: lookup)
		return context.makeImage()
	}
}
