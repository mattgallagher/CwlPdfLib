// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfStream: Sendable, Hashable {
	// The objectIdentifier is primarily used for debugging
	public let objectIdentifier: PdfObjectIdentifier
	
	public let dictionary: PdfDictionary
	public let data: Data
}

extension PdfStream: CustomDebugStringConvertible {
	public var debugDescription: String {
		let dataDescription = if dictionary.isImage(lookup: nil) {
			"<Image: \(data.count) bytes>"
		} else {
			String(data: data, encoding: .utf8) ?? "<unknown: \(data.count) bytes>"
		}
		return "\(dictionary.debugDescription) stream \"\(dataDescription)\""
	}
}

public extension PdfDictionary {
	func isImage(lookup: PdfObjectLookup?) -> Bool {
		if let subtype = self[.Subtype]?.name(lookup: lookup) {
			subtype == .Image
		} else {
			false
		}
	}
	
	func isForm(lookup: PdfObjectLookup?) -> Bool {
		if let subtype = self[.Subtype]?.name(lookup: lookup) {
			subtype == .Form
		} else {
			false
		}
	}
}
