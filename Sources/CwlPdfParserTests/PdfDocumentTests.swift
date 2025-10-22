// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfDocumentTests {
	@Test(arguments: [
		"blank-page.pdf",
		"single-text-line.pdf"
	])
	func `GIVEN a pdf filename WHEN PdfHeader.parse THEN pdf and version number extracted`(filename: String) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/\(filename)", withExtension: nil))
		var dataSource = try PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)) as any PdfSource
		try dataSource.seek(to: 0)
		let header = try dataSource.parseContext(lineCount: 1) { context in
			try PdfHeader.parse(context: &context)
		}
		#expect(header.type == "PDF")
		#expect(header.version == "1.3")
	}
}
