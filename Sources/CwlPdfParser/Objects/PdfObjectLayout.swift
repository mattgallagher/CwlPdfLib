// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectLayout: Sendable, Hashable, Identifiable {
	public init(objectIdentifier: PdfObjectIdentifier, range: Range<Int>, revision: Int) {
		self.objectIdentifier = objectIdentifier
		self.range = range
		self.revision = revision
	}
	
	public let objectIdentifier: PdfObjectIdentifier
	public let range: Range<Int>
	public let revision: Int
	
	public var id: PdfObjectLayout { self }
}

extension PdfObjectLayout: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Obj #\(objectIdentifier.number)\(objectIdentifier.generation > 0 ? " gen \(objectIdentifier.generation)" : "")\(revision > 0 ? " rev \(revision + 1)" : "")"
	}
}
