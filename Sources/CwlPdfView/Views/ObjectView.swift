// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

struct ObjectView: View {
	@Binding var document: PdfFileDocument
	let layout: PdfObjectLayout
	let result: Result<PdfObject, Error>

	init(document: Binding<PdfFileDocument>, layout: PdfObjectLayout) {
		self._document = document
		self.layout = layout
		self.result = Result {
			try document.wrappedValue.pdf.lookup.object(layout: layout)
		}
	}
	
	var body: some View {
		switch result {
		case .success(let object):
			if case .stream(let pdfStream) = object, pdfStream.dictionary.isImage(lookup: nil), let image = NSImage(data: pdfStream.data) {
				Text(verbatim: pdfStream.dictionary.debugDescription)
				Image(nsImage: image).resizable().aspectRatio(nil, contentMode: .fit)
			} else {
				Text(verbatim: object.debugDescription)
			}
		case .failure(let error):
			Text("Failed to parse \(error.localizedDescription)")
		}
	}
}
