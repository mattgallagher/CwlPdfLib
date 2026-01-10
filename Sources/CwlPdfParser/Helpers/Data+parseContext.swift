// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension Data {
	func parseContext<Output>(handler: (inout PdfParseContext) throws -> Output) throws -> Output {
		return try withUnsafeBytes { bufferPointer in
			let buffer = OffsetSlice(bufferPointer, bounds: bufferPointer.indices, offset: 0)
			var context = PdfParseContext(slice: buffer[...])
			return try handler(&context)
		}
	}
}
