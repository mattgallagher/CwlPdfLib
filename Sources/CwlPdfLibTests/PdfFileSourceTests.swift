// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfFileSourceTests {
	@Test(arguments: [
		("blank-page.pdf", 894),
		("single-text-line.pdf", 10848)
	])
	func `GIVEN a PdfFileSource WHEN PdfDataSource functions invoked THEN expected bytes read`(file: (name: String, length: Int)) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(file.name)", withExtension: nil))
		
		let fileSource = try PdfFileSource(url: fileURL)
		#expect(fileSource.length == file.length, "Expected length \(file.length) for file \(file.name)")
		
		var buffer = PdfSourceBuffer()
		let first = try fileSource.readNext(buffer: &buffer)
		#expect(first == 37, "Expected the file \(file.name) to start with %")
		
		let headerFound = try fileSource.bytes(in: 0..<4) { buffer in
			buffer[...].starts(with: "%PDF".utf8)
		}
		#expect(headerFound, "Failed to read %PDF header from \(file.name)")
		
		try fileSource.seek(to: fileSource.length, buffer: &buffer)
		let last = try fileSource.readPrevious(buffer: &buffer)
		#expect(last == 10, "Expected the file \(file.name) to end with %")
		
		let error = #expect(throws: PdfParseError.self) {
			try fileSource.seek(to: fileSource.length, buffer: &buffer)
			return try fileSource.readNext(buffer: &buffer)
		}
		#expect(error?.failure == .endOfFile, "Expected a PdfParseError with .endOfFile as the failure")
		
		let headerFoundAgain = try fileSource.bytes(in: 0..<4) { buffer in
			buffer[...].starts(with: "%PDF".utf8)
		}
		#expect(headerFoundAgain, "Failed to read %PDF header from \(file.name)")
	}
	
	@Test
	func `GIVEN a file source with two buffers WHEN reading from them THEN results are identical`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/blank-page.pdf", withExtension: nil))
		let fileSource = try PdfFileSource(url: fileURL)
		
		var buffer1 = PdfSourceBuffer()
		try #expect(fileSource.readNext(buffer: &buffer1) == ASCII.percent)
		try #expect(fileSource.readNext(buffer: &buffer1) == ASCII.P)
		
		var buffer2 = PdfSourceBuffer()
		try #expect(fileSource.readNext(buffer: &buffer2) == ASCII.percent)
		try #expect(fileSource.readNext(buffer: &buffer2) == ASCII.P)
	}
}
