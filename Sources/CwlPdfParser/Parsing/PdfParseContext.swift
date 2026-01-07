// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

struct PdfParseContext {
	var slice: OffsetSlice<UnsafeRawBufferPointer>
	var objectIdentifier: PdfObjectIdentifier?
	var skipComments = true
	var errorIfEndOfRange = false
	var token: PdfToken?
	var tokenStart: Int?
}
