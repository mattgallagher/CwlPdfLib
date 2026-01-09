// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfStream: Sendable, Hashable {
	public let dictionary: PdfDictionary
	public let data: Data
}

extension PdfStream: CustomDebugStringConvertible {
	public var debugDescription: String {
		let dataDescription: String
		if dictionary.isImage(lookup: nil) {
			dataDescription = "<Image: \(data.count) bytes>"
		} else {
			dataDescription = String(data: data, encoding: .utf8) ?? "<unknown: \(data.count) bytes>"
		}
		return "\(dictionary.debugDescription) stream \"\(dataDescription)\""
	}
}

public extension PdfDictionary {
	func isImage(lookup: PdfObjectLookup?) -> Bool {
		if let type = self[.Type]?.name(lookup: lookup), type == .XObject, let subtype = self[.Subtype]?.name(lookup: lookup) {
			return subtype == .Image
		} else {
			return false
		}
	}
}
