// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

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

	/// Returns the rectangle shared by this rectangle and `other`, or `nil` when they do not overlap.
	public func intersection(_ other: PdfRect) -> PdfRect? {
		let intersectionX = max(x, other.x)
		let intersectionY = max(y, other.y)
		let intersectionMaxX = min(x + width, other.x + other.width)
		let intersectionMaxY = min(y + height, other.y + other.height)
		guard
			intersectionX < intersectionMaxX,
			intersectionY < intersectionMaxY
		else {
			return nil
		}

		return PdfRect(
			x: intersectionX,
			y: intersectionY,
			width: intersectionMaxX - intersectionX,
			height: intersectionMaxY - intersectionY
		)
	}
	
	public init?(array: PdfArray, lookup: PdfObjectLookup?) {
		// PDF arrays for rectangles are [x1, y1, x2, y2]
		// Convert to CoreGraphics coordinates where (0,0) is bottom-left of page
		guard array.count == 4 else { return nil }
		
		var x1 = array[0].real(lookup: lookup).flatMap(\.self) ?? 0
		var y1 = array[1].real(lookup: lookup).flatMap(\.self) ?? 0
		let x2 = array[2].real(lookup: lookup).flatMap(\.self) ?? 0
		let y2 = array[3].real(lookup: lookup).flatMap(\.self) ?? 0
		
		// Normalize the rect to have non-negative width and height
		var width = x2 - x1
		var height = y2 - y1
		if width < 0 {
			x1 = x1 + width
			width = -width
		}
		if height < 0 {
			y1 = y1 + height
			height = -height
		}
		
		self.init(x: x1, y: y1, width: width, height: height)
	}
}
