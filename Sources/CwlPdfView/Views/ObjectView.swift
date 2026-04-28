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
			switch object {
			case .dictionary(let dictionary):
				DictionaryTable(dictionary: dictionary)
			case .stream(let pdfStream):
				VSplitView {
					DictionaryTable(dictionary: pdfStream.dictionary)
					VStack(alignment: .leading) {
						Text("Stream content").font(.headline)
						if pdfStream.dictionary.isImage(lookup: nil), let image = NSImage(data: pdfStream.data) {
							Image(nsImage: image)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
						} else {
							TextView(text: String(data: pdfStream.data, encoding: .utf8) ?? "<unknown: \(pdfStream.data.count) bytes>")
						}
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			case .array(let array):
				ArrayTable(array: array)
			default:
				SingleValueTable(value: object)
			}
		case .failure(let error):
			Text("Failed to parse \(error.localizedDescription)")
		}
	}
}

private struct DictionaryTable: View {
	let entries: [Entry]

	init(dictionary: PdfDictionary) {
		self.entries = dictionary
			.sorted { $0.key < $1.key }
			.map { Entry(key: $0.key, value: $0.value) }
	}

	var body: some View {
		Table(entries) {
			TableColumn("Key", value: \.key)
			TableColumn("Value") { entry in
				PdfObjectValueCell(value: entry.value)
			}
		}
	}

	struct Entry: Identifiable {
		let key: String
		let value: PdfObject
		var id: String { key }
	}
}

private struct ArrayTable: View {
	let entries: [Entry]

	init(array: PdfArray) {
		self.entries = array.enumerated().map { Entry(index: $0.offset, value: $0.element) }
	}

	var body: some View {
		Table(entries) {
			TableColumn(PdfObject.array([]).typeName) { entry in
				PdfObjectValueCell(value: entry.value)
			}
		}
	}

	struct Entry: Identifiable {
		let index: Int
		let value: PdfObject
		var id: Int { index }
	}
}

private struct SingleValueTable: View {
	let entry: Entry
	let typeName: String

	init(value: PdfObject) {
		self.entry = Entry(value: value)
		self.typeName = value.typeName
	}

	var body: some View {
		Table([entry]) {
			TableColumn(typeName) { entry in
				PdfObjectValueCell(value: entry.value)
			}
		}
	}

	struct Entry: Identifiable {
		let value: PdfObject
		var id: Int { 0 }
	}
}

private struct PdfObjectValueCell: View {
	let value: PdfObject

	var body: some View {
		if case .reference(let identifier) = value {
			ObjectIdentifierLink(identifier: identifier)
		} else {
			Text(value.debugDescription)
		}
	}
}

private struct TextView: NSViewRepresentable {
	let text: String

	func makeNSView(context: Context) -> NSScrollView {
		let scrollView = NSTextView.scrollableTextView()
		if let textView = scrollView.documentView as? NSTextView {
			textView.isEditable = false
			textView.isSelectable = true
			textView.isRichText = false
			textView.usesFindBar = true
			textView.isIncrementalSearchingEnabled = true
			textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
			textView.textContainerInset = NSSize(width: 4, height: 4)
		}
		return scrollView
	}

	func updateNSView(_ scrollView: NSScrollView, context: Context) {
		guard let textView = scrollView.documentView as? NSTextView else { return }
		if textView.string != text {
			textView.string = text
		}
	}
}

private extension PdfObject {
	var typeName: String {
		switch self {
		case .array: "Array"
		case .boolean: "Boolean"
		case .dictionary: "Dictionary"
		case .identifier: "Identifier"
		case .integer: "Integer"
		case .name: "Name"
		case .null: "Null"
		case .real: "Real"
		case .reference: "Reference"
		case .stream: "Stream"
		case .string: "String"
		}
	}
}
