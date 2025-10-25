// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectLayout: Sendable, Hashable, Identifiable {
	public let objectNumber: PdfObjectNumber
	public let range: Range<Int>
	public let revision: Int
	
	public var id: Int {
		range.lowerBound
	}
}
