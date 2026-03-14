// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import Foundation
import Testing

func fixtureURL(path: String) -> URL? {
	Bundle.module.url(forResource: "Fixtures/\(path)", withExtension: nil)
}

func fixtureDocument(path: String) throws -> PdfDocument {
	let fileURL = try #require(fixtureURL(path: path))
	let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
	return try PdfDocument(source: PdfDataSource(data))
}

func basicFixtureDocument(filename: String) throws -> PdfDocument {
	try fixtureDocument(path: "Basic/\(filename)")
}
