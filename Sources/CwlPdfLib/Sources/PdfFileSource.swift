// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfFileSource: PdfSource {
	private let url: URL
	private var uncheckedFile: FileHandle
	
	public let length: Int
	public private(set) var offset: Int = 0
	
	private static let bufferSize = 4096
	private var buffer = Data()
	private var bufferStart = 0
	
	public init(url: URL) throws {
		self.url = url
		self.uncheckedFile = try FileHandle(forReadingFrom: url)
		self.length = try Int(uncheckedFile.seekToEnd())
	}
	
	public mutating func readNext() throws -> UInt8 {
		guard offset < length else {
			throw PdfParseError(failure: .endOfFile, range: offset..<(offset + 1))
		}
		let byte = try read(at: offset, reverse: false)
		offset += 1
		return byte
	}
	
	public mutating func readPrevious() throws -> UInt8 {
		guard offset > 0 else {
			throw PdfParseError(failure: .endOfFile, range: offset..<(offset + 1))
		}
		offset -= 1
		return try read(at: offset, reverse: true)
	}
	
	public mutating func seek(to newOffset: Int) throws {
		guard newOffset >= 0, newOffset <= length else {
			throw PdfParseError(failure: .endOfFile, range: newOffset..<newOffset)
		}
		offset = newOffset
	}
	
	public mutating func bytes<Output>(in range: Range<Int>, handler: (OffsetSlice<UnsafeRawBufferPointer>) throws -> Output) throws -> Output {
		guard range.lowerBound >= 0, range.upperBound <= length else {
			throw PdfParseError(failure: .endOfFile, range: range)
		}
		
		if (bufferStart..<(bufferStart + buffer.count)).contains(range) {
			return try buffer[(range.lowerBound - bufferStart)..<(range.upperBound - bufferStart)].withUnsafeBytes { buffer in
				try handler(OffsetSlice(buffer, bounds: buffer.startIndex..<buffer.endIndex, offset: bufferStart))
			}
		}
		
		let data = try read(fromOffset: UInt64(range.lowerBound), length: range.count)
		return try data.withUnsafeBytes { buffer in
			try handler(OffsetSlice(buffer, bounds: buffer.startIndex..<buffer.endIndex, offset: range.lowerBound))
		}
	}
	
	private mutating func read(at index: Int, reverse: Bool) throws -> UInt8 {
		if !(bufferStart..<(bufferStart + buffer.count)).contains(index) {
			try refillBuffer(containing: index, reverse: reverse)
		}
		return buffer[index - bufferStart]
	}
	
	private mutating func refillBuffer(containing index: Int, reverse: Bool) throws {
		let start = max(0, index - (reverse ? Self.bufferSize - 1 : 0))
		let count = min(Self.bufferSize, (reverse ? index - start + 1 : length - start))
		buffer = try read(fromOffset: UInt64(start), length: count)
		bufferStart = start
	}

	// NOTE: all functions that access the `file` must call `try ensureUniqueFileHandle()` to
	// ensure thread safety (otherwise calls to seek and read will not ensure atomicity
	// between threads).
	private mutating func checkedFile() throws -> FileHandle {
		if !isKnownUniquelyReferenced(&uncheckedFile) {
			uncheckedFile = try FileHandle(forReadingFrom: url)
		}
		return uncheckedFile
	}

	private mutating func read(fromOffset offset: UInt64, length: Int) throws -> Data {
		let file = try checkedFile()
		try file.seek(toOffset: offset)
		return try file.read(upToCount: length) ?? Data()
	}
}
