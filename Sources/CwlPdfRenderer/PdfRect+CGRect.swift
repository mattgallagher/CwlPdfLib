// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

extension PdfRect {
	/// Returns a CGRect representation of this PdfRect
	public var cgRect: CGRect {
		CGRect(x: x, y: y, width: width, height: height)
	}
}
