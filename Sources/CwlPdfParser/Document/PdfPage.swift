// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfPage: Sendable, Hashable, Identifiable {
	public let pageIndex: Int
	public let objectLayout: PdfObjectLayout
	public let pageDictionary: PdfDictionary
	public let documentPageSize: PdfRect
	
	public var id: PdfObjectLayout {
		objectLayout
	}
	
	/// Returns the page rectangle in PDF coordinates (typically CropBox or MediaBox)
	public func pageRect(lookup: PdfObjectLookup?) -> PdfRect {
		// Try to get CropBox first (PDF specification preference)
		if let cropBox = pageDictionary[.CropBox]?.array(lookup: lookup), let rect = PdfRect(
			array: cropBox,
			lookup: lookup
		) {
			return rect
		}
		
		// Fall back to MediaBox if CropBox is not present
		if let mediaBox = pageDictionary[.MediaBox]?.array(lookup: lookup), let rect = PdfRect(
			array: mediaBox,
			lookup: lookup
		) {
			return rect
		}
		
		// If the page doesn't provide sizes, use the document size
		return documentPageSize
	}
	
	public func contentStream(lookup: PdfObjectLookup?) -> PdfContentStream? {
		guard let contents = pageDictionary[.Contents]?.stream(lookup: lookup) else {
			return nil
		}
		return PdfContentStream(
			stream: contents,
			resources: pageDictionary[.Resources]?.dictionary(lookup: lookup),
			lookup: lookup
		)
	}
}

extension PdfPage: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Page \(pageIndex + 1)"
	}
}
