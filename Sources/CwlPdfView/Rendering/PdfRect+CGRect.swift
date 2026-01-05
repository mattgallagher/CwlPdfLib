import CwlPdfParser
import SwiftUI

extension PdfRect {
	/// Returns a CGRect representation of this PdfRect
	public var cgRect: CGRect {
		CGRect(x: x, y: y, width: width, height: height)
	}
}
