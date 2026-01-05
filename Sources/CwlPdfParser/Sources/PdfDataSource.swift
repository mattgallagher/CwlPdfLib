// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDataSource: PdfSource {
	public var data: Data
	
	public init(_ data: Data) {
		self.data = data
	}
	
	public var length: Int { data.count }

	public func readNext(buffer: inout PdfSourceBuffer) throws -> UInt8 {
		guard buffer.offset < data.count else {
			throw PdfParseError(failure: .endOfFile, range: buffer.offset..<(buffer.offset + 1))
		}
		defer {
			buffer.offset += 1
		}
		return data[buffer.offset]
	}
	
	public func readPrevious(buffer: inout PdfSourceBuffer) throws -> UInt8 {
		guard buffer.offset > 0 else {
			throw PdfParseError(failure: .endOfFile, range: buffer.offset..<(buffer.offset + 1))
		}
		buffer.offset -= 1
		return data[buffer.offset]
	}
	
	public func seek(to newOffset: Int, buffer: inout PdfSourceBuffer) throws {
		guard newOffset >= 0, newOffset <= data.count else {
			throw PdfParseError(failure: .endOfFile, range: newOffset..<newOffset)
		}
		buffer.offset = newOffset
	}
	
	public func bytes<Output>(in range: Range<Int>, handler: (OffsetSlice<UnsafeRawBufferPointer>) throws -> Output) throws -> Output {
		guard range.lowerBound >= 0, range.upperBound <= data.count else {
			throw PdfParseError(failure: .endOfFile, range: range)
		}
		return try data[range].withUnsafeBytes {
			try handler(OffsetSlice($0, bounds: $0.startIndex..<$0.endIndex, offset: range.lowerBound - $0.startIndex))
		}
	}
}
