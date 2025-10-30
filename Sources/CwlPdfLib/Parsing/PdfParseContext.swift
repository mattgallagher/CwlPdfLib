// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

struct PdfParseContext {
	var slice: OffsetSlice<UnsafeRawBufferPointer>
	var objectNumber: PdfObjectNumber?
	var skipComments = true
	var token: PdfToken?
	var tokenStart: Int?
}
