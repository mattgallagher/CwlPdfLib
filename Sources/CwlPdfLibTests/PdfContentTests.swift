// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfContentTests {
	@Test
	func `GIVEN a pdf with form xobjects WHEN parsing the first page content stream THEN form xobjects are resolved and parsed`() throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/flattened-layers.pdf", withExtension: nil))
		let document = try PdfDocument(
			source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe))
		)
		let page = try #require(document.pages.first)
		let content = page.content(lookup: document.lookup)
		let stream = try #require(content.streams.first)

		var operators = [PdfOperator]()
		try stream.parseContentOperators { op in
			operators.append(op)
			return true
		}

		let expectedNames: Set<String> = ["Fm0", "Fm1", "Fm2"]
		let xobjectNames = Set(operators.compactMap { op -> String? in
			guard case .Do(let name) = op else {
				return nil
			}
			return name
		})

		#expect(xobjectNames == expectedNames)

		for name in expectedNames {
			let xobjectStream = content.resolveResourceStream(
				category: .XObject,
				key: name,
				lookup: document.lookup
			)
			#expect(xobjectStream != nil)
			guard let xobjectStream else {
				continue
			}

			#expect(xobjectStream.dictionary.isForm(lookup: document.lookup))

			var formOperators = [PdfOperator]()
			try xobjectStream.parseContentOperators { op in
				formOperators.append(op)
				return true
			}
			#expect(!formOperators.isEmpty)
		}
	}
}
