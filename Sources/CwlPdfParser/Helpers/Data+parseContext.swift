// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension Data {
	func parseContext<Output>(
		intent: PdfParseIntent,
		handler: (inout PdfParseContext) throws -> Output
	) throws -> Output {
		try withUnsafeBytes { bufferPointer in
			let buffer = OffsetSlice(bufferPointer, bounds: bufferPointer.indices, offset: 0)
			var context = PdfParseContext(
				slice: buffer[...],
				intent: intent
			)
				do {
					return try handler(&context)
				} catch var error as PdfParseError {
					error.intent = error.intent ?? context.intent
				throw error
			}
		}
	}
}
