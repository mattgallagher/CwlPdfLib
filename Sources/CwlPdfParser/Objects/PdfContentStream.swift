// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfContentStream {
	public let stream: PdfStream
	public let resources: PdfDictionary?
	public let bbox: PdfRect?
	public let matrix: PdfAffineTransform?
	public let annotationRect: PdfRect?
	
	public init(stream: PdfStream, resources: PdfDictionary?, annotationRect: PdfRect?, lookup: PdfObjectLookup?) {
		self.stream = stream
		self.resources = resources ?? stream.dictionary[.Resources]?.dictionary(lookup: lookup)
		self.annotationRect = annotationRect
		
		if stream.dictionary[.Subtype]?.name(lookup: lookup) == .Form {
			self.bbox = stream
				.dictionary[.BBox]?
				.array(lookup: lookup)
				.flatMap { PdfRect(array: $0, lookup: lookup) }
			self.matrix = stream
				.dictionary[.Matrix]?
				.array(lookup: lookup)
				.flatMap { PdfAffineTransform(array: $0, lookup: lookup) }
		} else {
			self.bbox = nil
			self.matrix = nil
		}
	}
	
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
