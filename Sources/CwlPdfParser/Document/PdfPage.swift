// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfPage: Sendable, Hashable, Identifiable {
	public let pageIndex: Int
	public let objectLayout: PdfObjectLayout
	public let pageDictionary: PdfDictionary
	
	public var id: PdfObjectLayout {
		objectLayout
	}
}

extension PdfPage: CustomDebugStringConvertible {
	public var debugDescription: String {
		return "Page \(pageIndex + 1), \(objectLayout.objectIdentifier.debugDescription)"
	}
}
