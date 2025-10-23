// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfDataSource: PdfSource {
	public var data: Data
	public var offset: Int = 0
	
	init(_ data: Data) {
		self.data = data
	}
	
	public var length: Int { data.count }

	public mutating func readNext() throws -> UInt8 {
		guard offset < data.count else {
			throw PdfParseError(failure: .endOfFile, range: offset..<(offset + 1))
		}
		defer {
			offset += 1
		}
		return data[offset]
	}
	
	public mutating func readPrevious() throws -> UInt8 {
		guard offset > 0 else {
			throw PdfParseError(failure: .endOfFile, range: offset..<(offset + 1))
		}
		offset -= 1
		return data[offset]
	}
	
	public mutating func seek(to newOffset: Int) throws {
		guard newOffset >= 0, newOffset <= data.count else {
			throw PdfParseError(failure: .endOfFile, range: newOffset..<newOffset)
		}
		offset = newOffset
	}
	
	public mutating func bytes<Output>(in range: Range<Int>, handler: (OffsetSlice<UnsafeRawBufferPointer>) throws -> Output) throws -> Output {
		guard range.lowerBound >= 0, range.upperBound <= data.count else {
			throw PdfParseError(failure: .endOfFile, range: range)
		}
		defer {
			offset = range.upperBound
		}
		return try data[range].withUnsafeBytes {
			try handler(OffsetSlice($0, bounds: $0.startIndex..<$0.endIndex, offset: range.lowerBound - $0.startIndex))
		}
	}
}
