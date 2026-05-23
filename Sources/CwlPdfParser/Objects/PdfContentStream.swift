// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Provides the resource dictionary used while interpreting PDF content operators.
public protocol PdfContentStream {
	var streams: [PdfStream] { get }
	var resources: PdfDictionary? { get }
}

extension PdfContentStream {
	/// Resolves a named resource array in the specified resource category.
	public func resolveResourceArray(category: PdfResourceCategory, key: String, lookup: PdfObjectLookup?) -> PdfArray? {
		resources?[category.rawValue]?.dictionary(lookup: lookup)?[key]?.array(lookup: lookup)
	}

	/// Resolves a named resource dictionary in the specified resource category.
	public func resolveResourceDictionary(category: PdfResourceCategory, key: String, lookup: PdfObjectLookup?) -> PdfDictionary? {
		resources?[category.rawValue]?.dictionary(lookup: lookup)?[key]?.dictionary(lookup: lookup)
	}

	/// Resolves a named resource stream in the specified resource category.
	public func resolveResourceStream(category: PdfResourceCategory, key: String, lookup: PdfObjectLookup?) -> PdfStream? {
		resources?[category.rawValue]?.dictionary(lookup: lookup)?[key]?.stream(lookup: lookup)
	}
}

/// Represents a page's ordered content streams and shared page resources.
public struct PdfPageContent: PdfContentStream {
	public let streams: [PdfStream]
	public let resources: PdfDictionary?

	/// Creates page content from ordered streams and the page resource dictionary.
	public init(streams: [PdfStream], resources: PdfDictionary?) {
		self.streams = streams
		self.resources = resources
	}
}

/// Represents a Form XObject or form-like content stream with placement metadata.
public struct PdfFormContent: PdfContentStream {
	public let stream: PdfStream
	public let resources: PdfDictionary?
	public let bbox: PdfRect?
	public let matrix: PdfAffineTransform?

	/// Creates form content, preferring the stream's own resources over fallback resources.
	public init(stream: PdfStream, resources: PdfDictionary?, lookup: PdfObjectLookup?) {
		self.stream = stream
		self.resources = stream.dictionary[.Resources]?.dictionary(lookup: lookup) ?? resources

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
	
	public var streams: [PdfStream] { [stream] }
}

/// Represents an annotation appearance stream mapped into an annotation rectangle.
public struct PdfAnnotationAppearanceContent: PdfContentStream {
	public let form: PdfFormContent
	public let annotationRect: PdfRect

	public var streams: [PdfStream] {
		form.streams
	}

	public var resources: PdfDictionary? {
		form.resources
	}

	/// Creates annotation appearance content from an appearance stream and annotation rectangle.
	public init(stream: PdfStream, annotationRect: PdfRect, resources: PdfDictionary?, lookup: PdfObjectLookup?) {
		self.form = PdfFormContent(stream: stream, resources: resources, lookup: lookup)
		self.annotationRect = annotationRect
	}
}

extension PdfStream {
	/// Parses PDF content stream operators from the stream data.
	public func parseContentOperators(_ visitor: (PdfOperator) throws -> Bool) throws {
		try data.parseContext { context in
			repeat {
				guard let nextOperator = try PdfOperator.parseNext(context: &context) else {
					return
				}
				if try !visitor(nextOperator) {
					return
				}
			} while true
		}
	}
}
