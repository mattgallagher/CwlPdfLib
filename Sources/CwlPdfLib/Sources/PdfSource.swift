// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public protocol PdfSource: Sendable {
	var length: Int { get }
	func readNext(buffer: inout PdfSourceBuffer) throws -> UInt8
	func readPrevious(buffer: inout PdfSourceBuffer) throws -> UInt8
	func seek(to offset: Int, buffer: inout PdfSourceBuffer) throws
	func bytes<Output>(in range: Range<Int>, handler: (OffsetSlice<UnsafeRawBufferPointer>) throws -> Output) throws -> Output
}

public struct PdfSourceBuffer {
	var buffer = Data()
	var bufferStart = 0
	public internal(set) var offset: Int = 0
}
