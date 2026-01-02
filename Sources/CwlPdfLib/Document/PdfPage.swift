// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfPage: Sendable, Hashable {
	public let pageIndex: Int
	public let objectIdentifier: PdfObjectIdentifier
	public let pageDictionary: PdfDictionary
}
