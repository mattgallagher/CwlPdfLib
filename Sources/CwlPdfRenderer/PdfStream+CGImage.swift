// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfStream {
	/// Creates a CGImage from this stream when it is an image XObject.
	/// - Parameters:
	///   - lookup: The object lookup for resolving indirect image metadata and masks.
	///   - resolvedColorSpace: The image color space after resolution through its containing resources.
	///   - applySoftMask: Whether an image SMask should be applied to the returned image.
	/// - Returns: A CGImage if successful, nil otherwise.
	public func cgImage(
		lookup: PdfObjectLookup?,
		resolvedColorSpace: PdfColorSpace? = nil,
		applySoftMask: Bool = true
	) -> CGImage? {
		guard
			dictionary.isImage(lookup: lookup),
			let pdfImage = try? PdfImage(
				stream: self,
				lookup: lookup,
				resolvedColorSpace: resolvedColorSpace
			)
		else {
			return nil
		}
		return pdfImage.createCGImage(lookup: lookup, applySoftMask: applySoftMask)
	}
}
