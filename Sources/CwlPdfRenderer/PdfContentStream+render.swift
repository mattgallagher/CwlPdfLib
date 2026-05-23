// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfContentStream {
	func render(
		in context: CGContext,
		pageBounds: CGRect? = nil,
		lookup: PdfObjectLookup?,
		deviceScaleX: CGFloat? = nil,
		deviceScaleY: CGFloat? = nil
	) {
		context.saveGState()
		defer {
			context.restoreGState()
		}

		var state = PdfRenderer(
			deviceScaleX: deviceScaleX ?? max(hypot(context.ctm.a, context.ctm.c), 1),
			deviceScaleY: deviceScaleY ?? max(hypot(context.ctm.b, context.ctm.d), 1)
		)

		if let contextTransform {
			context.concatenate(contextTransform)
		}

		if let bbox = renderBBox ?? pageBounds {
			let bboxPath = CGPath(rect: bbox, transform: nil)
			context.addPath(bboxPath)
			context.clip()
			state.renderState.addClipPath(bboxPath, ctm: context.ctm, fillRule: .winding)
		}

		for stream in streams {
			state.render(stream, resources: self, in: context, lookup: lookup)
		}
	}
}

private extension PdfContentStream {
	var renderBBox: CGRect? {
		switch self {
		case let annotationAppearance as PdfAnnotationAppearanceContent:
			annotationAppearance.form.bbox?.cgRect
		case let formContent as PdfFormContent:
			formContent.bbox?.cgRect
		default:
			nil
		}
	}

	var contextTransform: CGAffineTransform? {
		switch self {
		case let annotationAppearance as PdfAnnotationAppearanceContent:
			annotationAppearance.contextTransform
		case let formContent as PdfFormContent:
			formContent.contextTransform
		default:
			nil
		}
	}
}

private extension PdfAnnotationAppearanceContent {
	var contextTransform: CGAffineTransform? {
		guard let bbox = form.bbox?.cgRect else {
			return form.contextTransform
		}

		let rect = annotationRect.cgRect
		let matrix = form.matrix?.cgAffineTransform ?? .identity
		let transformedBBox = bbox.applying(matrix)
		let scaleX = rect.width / transformedBBox.width
		let scaleY = rect.height / transformedBBox.height
		let translateX = rect.minX - transformedBBox.minX * scaleX
		let translateY = rect.minY - transformedBBox.minY * scaleY

		var AA = CGAffineTransform.identity
		AA = AA.translatedBy(x: translateX, y: translateY)
		AA = AA.scaledBy(x: scaleX, y: scaleY)
		AA = AA.concatenating(matrix)
		return AA
	}
}

extension PdfFormContent {
	var contextTransform: CGAffineTransform? {
		matrix?.cgAffineTransform
	}
}
