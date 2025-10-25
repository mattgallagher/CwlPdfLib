// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public protocol PdfSource: Sendable {
	var length: Int { get }
	var offset: Int { get }
	mutating func readNext() throws -> UInt8
	mutating func readPrevious() throws -> UInt8
	mutating func seek(to offset: Int) throws
	mutating func bytes<Output>(in range: Range<Int>, handler: (OffsetSlice<UnsafeRawBufferPointer>) throws -> Output) throws -> Output
}
