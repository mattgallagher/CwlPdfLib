// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfAffineTransform: Sendable {
	public let a: Double
	public let b: Double
	public let c: Double
	public let d: Double
	public let tx: Double
	public let ty: Double
	
	public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
		self.a = a
		self.b = b
		self.c = c
		self.d = d
		self.tx = tx
		self.ty = ty
	}
	
	public static var identity: PdfAffineTransform {
		PdfAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
	}
}
