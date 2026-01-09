// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfHeader: Sendable {
	public let type: String
	public let version: String

	init(type: String, version: String) {
		self.type = type
		self.version = version
	}
}
