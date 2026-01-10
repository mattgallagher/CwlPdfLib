// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectIdentifier: Hashable, Sendable {
	public let number: Int
	public let generation: Int
	
	public init(number: Int, generation: Int) {
		self.number = number
		self.generation = generation
	}
}

extension PdfObjectIdentifier: CustomDebugStringConvertible {
	public var debugDescription: String {
		"\(number) \(generation) R"
	}
}
