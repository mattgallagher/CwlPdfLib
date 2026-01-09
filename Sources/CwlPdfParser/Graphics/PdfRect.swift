// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfRect: Sendable, Hashable {
	public let x: Double
	public let y: Double
	public let width: Double
	public let height: Double

	public init(x: Double, y: Double, width: Double, height: Double) {
		self.x = x
		self.y = y
		self.width = width
		self.height = height
	}
	
	public init?(array: PdfArray, lookup: PdfObjectLookup?) {
		// PDF arrays for rectangles are [x1, y1, x2, y2]
		// Convert to CoreGraphics coordinates where (0,0) is bottom-left of page
		guard array.count == 4 else { return nil }
		
		let x1 = array[0].real(lookup: lookup).flatMap { $0 } ?? 0
		let y1 = array[1].real(lookup: lookup).flatMap { $0 } ?? 0
		let x2 = array[2].real(lookup: lookup).flatMap { $0 } ?? 0
		let y2 = array[3].real(lookup: lookup).flatMap { $0 } ?? 0
		
		let width = x2 - x1
		let height = y2 - y1
		
		self.init(x: x1, y: y1, width: width, height: height)
	}
}
