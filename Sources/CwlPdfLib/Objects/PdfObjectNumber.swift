// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectNumber: Hashable, Sendable {
	public let number: Int
	public let generation: Int
	
	public init(number: Int, generation: Int) {
		self.number = number
		self.generation = generation
	}
}

extension PdfObjectNumber: CustomDebugStringConvertible {
	public var debugDescription: String {
		return "\(number) \(generation) R"
	}
}
