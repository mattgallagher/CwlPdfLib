// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfStream {
	/// Creates a CGImage from this stream when it is an image XObject.
	/// - Parameter lookup: The object lookup for resolving indirect image metadata and masks.
	/// - Returns: A CGImage if successful, nil otherwise.
	public func cgImage(lookup: PdfObjectLookup?) -> CGImage? {
		guard
			dictionary.isImage(lookup: lookup),
			let pdfImage = try? PdfImage(stream: self, lookup: lookup)
		else {
			return nil
		}
		return pdfImage.createCGImage(lookup: lookup)
	}
}
