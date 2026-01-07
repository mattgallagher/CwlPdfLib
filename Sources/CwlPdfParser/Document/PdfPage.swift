// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

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
	public func pageRect(objects: PdfObjectList?) -> PdfRect {
		// Try to get CropBox first (PDF specification preference)
		if let cropBox = try? pageDictionary[.CropBox]?.array(objects: objects), let rect = PdfRect(
			array: cropBox,
			objects: objects
		) {
			return rect
		}
		
		// Fall back to MediaBox if CropBox is not present
		if let mediaBox = try? pageDictionary[.MediaBox]?.array(objects: objects), let rect = PdfRect(
			array: mediaBox,
			objects: objects
		) {
			return rect
		}
		
		// If the page doesn't provide sizes, use the document size
		return self.documentPageSize
	}
	
	public func contentStream(objects: PdfObjectList?) -> PdfContentStream? {
		guard let contents = try? pageDictionary[.Contents]?.stream(objects: objects) else {
			return nil
		}
		return PdfContentStream(
			stream: contents,
			resources: try? pageDictionary[.Resources]?.dictionary(objects: objects)
		)
	}
}

extension PdfPage: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Page \(pageIndex + 1)"
	}
}
