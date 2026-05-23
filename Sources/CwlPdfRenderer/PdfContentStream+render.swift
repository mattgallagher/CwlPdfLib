// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfContentStream {
	func render(
		in context: CGContext,
		pageBounds: CGRect?,
		lookup: PdfObjectLookup?,
		deviceScaleX: CGFloat? = nil,
		deviceScaleY: CGFloat? = nil
	) {
		PdfRenderer.performWithRenderState(
			for: self,
			in: context,
			pageBounds: pageBounds,
			deviceScaleX: deviceScaleX,
			deviceScaleY: deviceScaleY
		) { state in
			state.render(self, in: context, lookup: lookup)
		}
	}

	var contextTransform: CGAffineTransform? {
		guard let rect = annotationRect?.cgRect, let bbox = bbox?.cgRect else {
			return matrix?.cgAffineTransform
		}

		let matrix = matrix?.cgAffineTransform ?? .identity
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
