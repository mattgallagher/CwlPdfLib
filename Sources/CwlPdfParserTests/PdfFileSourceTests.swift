// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

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
		
		var fileSource = try PdfFileSource(url: fileURL)
		#expect(fileSource.length == file.length, "Expected length \(file.length) for file \(file.name)")
		
		let first = try fileSource.readNext()
		#expect(first == 37, "Expected the file \(file.name) to start with %")
		
		let headerFound = try fileSource.bytes(in: 0..<4) { buffer in
			buffer[...].starts(with: [ASCII.percent, ASCII.P, ASCII.D, ASCII.F])
		}
		#expect(headerFound, "Failed to read %PDF header from \(file.name)")
		
		try fileSource.seek(to: fileSource.length)
		let last = try fileSource.readPrevious()
		#expect(last == 10, "Expected the file \(file.name) to end with %")
		
		let error = #expect(throws: PdfParseError.self) {
			try fileSource.seek(to: fileSource.length)
			return try fileSource.readNext()
		}
		#expect(error?.failure == .endOfFile, "Expected a PdfParseError with .endOfFile as the failure")
		
		let headerFoundAgain = try fileSource.bytes(in: 0..<4) { buffer in
			buffer[...].starts(with: [ASCII.percent, ASCII.P, ASCII.D, ASCII.F])
		}
		#expect(headerFoundAgain, "Failed to read %PDF header from \(file.name)")
	}
	
	@Test
	func `GIVEN a file source with two copies WHEN reading from them THEN results are identical`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/blank-page.pdf", withExtension: nil))
		var fileSource1 = try PdfFileSource(url: fileURL)
		
		var fileSource2 = fileSource1
		
		try #expect(fileSource1.readNext() == ASCII.percent)
		try #expect(fileSource1.readNext() == ASCII.P)
		
		try #expect(fileSource2.readNext() == ASCII.percent)
		try #expect(fileSource2.readNext() == ASCII.P)
	}
}
