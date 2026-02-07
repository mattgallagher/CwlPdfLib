// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

public enum PdfObjectStorage: Sendable, Hashable {
	case uncompressed(range: Range<Int>)
	case objectStream(stream: PdfObjectIdentifier, index: Int)
}

public struct PdfObjectLayout: Sendable, Hashable, Identifiable {
	public init(objectIdentifier: PdfObjectIdentifier, storage: PdfObjectStorage, revision: Int) {
		self.objectIdentifier = objectIdentifier
		self.storage = storage
		self.revision = revision
	}
	
	public let objectIdentifier: PdfObjectIdentifier
	public let storage: PdfObjectStorage
	public let revision: Int
	
	public var range: Range<Int>? {
		if case .uncompressed(let range) = storage {
			return range
		}
		return nil
	}
	
	public var id: PdfObjectLayout { self }
}

extension PdfObjectLayout: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Obj #\(objectIdentifier.number)\(objectIdentifier.generation > 0 ? " gen \(objectIdentifier.generation)" : "")\(revision > 0 ? " rev \(revision + 1)" : "")"
	}
}
