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
	
	public init?(array: PdfArray, lookup: PdfObjectLookup?) {
		// PDF arrays for transformation matrices are [a, b, c, d, tx, ty]
		guard array.count == 6 else { return nil }
		
		let a = array[0].real(lookup: lookup).flatMap(\.self) ?? 0
		let b = array[1].real(lookup: lookup).flatMap(\.self) ?? 0
		let c = array[2].real(lookup: lookup).flatMap(\.self) ?? 0
		let d = array[3].real(lookup: lookup).flatMap(\.self) ?? 0
		let tx = array[4].real(lookup: lookup).flatMap(\.self) ?? 0
		let ty = array[5].real(lookup: lookup).flatMap(\.self) ?? 0
		
		self.init(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
	}
}
