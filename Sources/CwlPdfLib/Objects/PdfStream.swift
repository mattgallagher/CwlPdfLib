// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfStream: Sendable {
	let dictionary: PdfDictionary
	let data: Data
}

extension PdfStream: CustomDebugStringConvertible {
	public var debugDescription: String {
		return "\(dictionary.debugDescription)\nstream \(data.count) bytes endstream"
	}
}
