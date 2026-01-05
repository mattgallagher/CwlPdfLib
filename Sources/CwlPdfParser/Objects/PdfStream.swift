// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfStream: Sendable, Hashable {
	public let dictionary: PdfDictionary
	public let data: Data
}

extension PdfStream: CustomDebugStringConvertible {
	public var debugDescription: String {
		let dataDescription: String
		if dictionary.isImage(objects: nil) {
			dataDescription = "<Image: \(data.count) bytes>"
		} else {
			dataDescription = String(data: data, encoding: .utf8) ?? "<unknown: \(data.count) bytes>"
		}
		return "\(dictionary.debugDescription) stream \"\(dataDescription)\""
	}
}

public extension PdfDictionary {
	func isImage(objects: PdfObjectList?) -> Bool {
		if let type = try? self[.Type]?.name(objects: objects), type == .XObject, let subtype = try? self[.Subtype]?.name(objects: objects) {
			return subtype == .Image
		} else {
			return false
		}
	}
}
