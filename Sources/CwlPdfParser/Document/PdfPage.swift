// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfPage: Sendable, Hashable, Identifiable {
	public let pageIndex: Int
	public let objectLayout: PdfObjectLayout
	public let pageDictionary: PdfDictionary
	
	public var id: PdfObjectLayout {
		objectLayout
	}
	
	/// Returns the page rectangle in PDF coordinates (typically CropBox or MediaBox)
	public var pageRect: PdfRect? {
		// Try to get CropBox first (PDF specification preference)
		if let cropBox = pageDictionary["CropBox"], let cropBoxArray = try? cropBox.array(objects: nil) {
			if cropBoxArray.count == 4 {
				return PdfRect(array: cropBoxArray)
			}
		}
		
		// Fall back to MediaBox if CropBox is not present
		if let mediaBox = pageDictionary["MediaBox"],
			let mediaBoxArray = try? mediaBox.array(objects: nil)
		{
			if mediaBoxArray.count == 4 {
				return PdfRect(array: mediaBoxArray)
			}
		}
		
		// Default to standard US Letter size if no dimensions found
		return PdfRect(x: 0, y: 0, width: 612, height: 792)
	}
}

extension PdfPage: CustomDebugStringConvertible {
	public var debugDescription: String {
		"Page \(pageIndex + 1), \(objectLayout.objectIdentifier.debugDescription)"
	}
}
