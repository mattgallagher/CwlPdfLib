// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfPage: Sendable, Hashable, Identifiable {
	public let pageIndex: Int
	public let objectLayout: PdfObjectLayout
	public let pageDictionary: PdfDictionary
	public let documentPageSize: PdfRect
	
	public var id: PdfObjectLayout {
		objectLayout
	}
	
	func rectangle(for boxName: String, lookup: PdfObjectLookup?) -> PdfRect? {
		guard let box = pageDictionary[boxName]?.array(lookup: lookup), let rect = PdfRect(
			array: box,
			lookup: lookup
		) else {
			return nil
		}
		return rect
	}
	
	/// Returns the page rectangle in PDF coordinates (typically CropBox or MediaBox)
	public func pageRect(lookup: PdfObjectLookup?) -> PdfRect {
		let cropBox = rectangle(for: .CropBox, lookup: lookup)
		let mediaBox = rectangle(for: .MediaBox, lookup: lookup)
		if let cropBox, let mediaBox {
			return cropBox.intersection(mediaBox) ?? mediaBox
		} else if let cropBox {
			return cropBox
		}

		if let mediaBox {
			return mediaBox
		}

		// If the page doesn't provide sizes, use the document size
		return documentPageSize
	}

	/// Returns the page's ordered content streams with the page resource dictionary.
	public func content(lookup: PdfObjectLookup?) -> PdfPageContent {
		let resources = pageDictionary[.Resources]?.dictionary(lookup: lookup)
		guard let contents = pageDictionary[.Contents] else {
			return PdfPageContent(streams: [], resources: resources)
		}

		if let stream = contents.stream(lookup: lookup) {
			return PdfPageContent(streams: [stream], resources: resources)
		} else if let array = contents.array(lookup: lookup) {
			return PdfPageContent(streams: array.compactMap { $0.stream(lookup: lookup) }, resources: resources)
		}

		return PdfPageContent(streams: [], resources: resources)
	}
}

extension PdfPage: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Page \(pageIndex + 1)"
	}
}
