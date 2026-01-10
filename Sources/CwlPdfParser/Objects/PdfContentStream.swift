// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfContentStream {
	let stream: PdfStream
	let resources: PdfDictionary?
	
	public func parse(_ visitor: (PdfOperator) -> Bool) throws {
		try stream.data.parseContext { context in
			repeat {
				guard let nextOperator = try PdfOperator.parseNext(context: &context) else {
					return
				}
				if !visitor(nextOperator) {
					return
				}
			} while true
		}
	}
	
	public func resolveResource(category: PdfResourceCategory, key: String, lookup: PdfObjectLookup?) -> PdfDictionary? {
		resources?[category.rawValue]?.dictionary(lookup: lookup)?[key]?.dictionary(lookup: lookup)
	}

	public func resolveResourceStream(category: PdfResourceCategory, key: String, lookup: PdfObjectLookup?) -> PdfStream? {
		resources?[category.rawValue]?.dictionary(lookup: lookup)?[key]?.stream(lookup: lookup)
	}
}
