// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfStream: Sendable {
	public let dictionary: PdfDictionary
	public let data: Data
}

extension PdfStream: CustomDebugStringConvertible {
	public var debugDescription: String {
		let dataDescription: String
		if dictionary.isImage(document: nil) {
			dataDescription = "<Image: \(data.count) bytes>"
		} else {
			dataDescription = String(data: data, encoding: .utf8) ?? "<unknown: \(data.count) bytes>"
		}
		return "\(dictionary.debugDescription) stream \"\(dataDescription)\""
	}
}

public extension PdfDictionary {
	func isImage(document: PdfDocument?) -> Bool {
		if let type = try? self[.Type]?.name(document: document), type == .XObject, let subtype = try? self[.Subtype]?.name(document: document) {
			return subtype == .Image
		} else {
			return false
		}
	}
}
