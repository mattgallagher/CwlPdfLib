import CoreGraphics
import CwlPdfParser

extension PdfAffineTransform {
	/// Returns a CGAffineTransform representation of this PdfAffineTransform
	public var cgAffineTransform: CGAffineTransform {
		CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
	}
}
