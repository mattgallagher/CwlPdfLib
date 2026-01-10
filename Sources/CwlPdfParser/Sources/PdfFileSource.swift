// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Synchronization

public final class PdfFileSource: PdfSource {
	private let url: URL
	
	// Even though `FileHandle` is `Sendable` and theoretically threadsafe, in practice,
	// it is necessary to use a lock to ensure seek and read calls are performed atomically.
	private let fileHandle: Mutex<FileHandle>
	
	public let length: Int
	private static let bufferSize = 4096

	public init(url: URL) throws {
		self.url = url
		let fileHandle = try FileHandle(forReadingFrom: url)
		self.length = try Int(fileHandle.seekToEnd())
		self.fileHandle = Mutex(fileHandle)
	}
	
	public func readNext(buffer: inout PdfSourceBuffer) throws -> UInt8 {
		guard buffer.offset < length else {
			throw PdfParseError(failure: .endOfFile, range: buffer.offset..<(buffer.offset + 1))
		}
		let byte = try read(at: buffer.offset, reverse: false, buffer: &buffer)
		buffer.offset += 1
		return byte
	}
	
	public func readPrevious(buffer: inout PdfSourceBuffer) throws -> UInt8 {
		guard buffer.offset > 0 else {
			throw PdfParseError(failure: .endOfFile, range: buffer.offset..<(buffer.offset + 1))
		}
		buffer.offset -= 1
		return try read(at: buffer.offset, reverse: true, buffer: &buffer)
	}
	
	public func seek(to newOffset: Int, buffer: inout PdfSourceBuffer) throws {
		guard newOffset >= 0, newOffset <= length else {
			throw PdfParseError(failure: .endOfFile, range: newOffset..<newOffset)
		}
		buffer.offset = newOffset
	}
	
	public func bytes<Output>(in range: Range<Int>, handler: (OffsetSlice<UnsafeRawBufferPointer>) throws -> Output) throws -> Output {
		guard range.lowerBound >= 0, range.upperBound <= length else {
			throw PdfParseError(failure: .endOfFile, range: range)
		}
		
		let data = try read(fromOffset: UInt64(range.lowerBound), length: range.count)
		return try data.withUnsafeBytes { buffer in
			try handler(OffsetSlice(buffer, bounds: buffer.startIndex..<buffer.endIndex, offset: range.lowerBound))
		}
	}
	
	private func read(at index: Int, reverse: Bool, buffer: inout PdfSourceBuffer) throws -> UInt8 {
		if !(buffer.bufferStart..<(buffer.bufferStart + buffer.buffer.count)).contains(index) {
			try refillBuffer(containing: index, reverse: reverse, buffer: &buffer)
		}
		return buffer.buffer[index - buffer.bufferStart]
	}
	
	private func refillBuffer(containing index: Int, reverse: Bool, buffer: inout PdfSourceBuffer) throws {
		let start = max(0, index - (reverse ? Self.bufferSize - 1 : 0))
		let count = min(Self.bufferSize, reverse ? index - start + 1 : length - start)
		buffer.buffer = try read(fromOffset: UInt64(start), length: count)
		buffer.bufferStart = start
	}

	private func read(fromOffset offset: UInt64, length: Int) throws -> Data {
		try fileHandle.withLock {
			try $0.seek(toOffset: offset)
			return try $0.read(upToCount: length) ?? Data()
		}
	}
}
