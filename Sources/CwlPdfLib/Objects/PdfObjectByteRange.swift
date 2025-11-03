// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectByteRange: Sendable, Hashable, Identifiable {
	public let objectIdentifier: PdfObjectIdentifier
	public let range: Range<Int>
	public let revision: Int
	
	public var id: Int {
		range.lowerBound
	}
}

extension PdfObjectByteRange: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Obj #\(objectIdentifier.number) \(objectIdentifier.generation).\(revision)"
	}
}
