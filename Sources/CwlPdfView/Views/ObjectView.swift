// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

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
				DictionaryTable(layout: layout, dictionary: dictionary)
			case .stream(let pdfStream):
				VSplitView {
					DictionaryTable(layout: layout, dictionary: pdfStream.dictionary)
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
	let keyColumnTitle: String
	let rows: [DictionaryTableRow]

	init(layout: PdfObjectLayout, dictionary: PdfDictionary) {
		self.keyColumnTitle = "\(layout.debugDescription): Keys"
		self.rows = dictionary
			.sorted { $0.key < $1.key }
			.flatMap { DictionaryTableRow.rows(key: $0.key, value: $0.value) }
	}

	var body: some View {
		Table(rows) {
			TableColumn(keyColumnTitle) { row in
				Text(row.displayKey)
			}
			.width(200)
			TableColumn("Value") { row in
				DictionaryValueCell(row: row)
			}
		}
	}
}

struct DictionaryTableRow: Identifiable {
	let id: String
	let key: String?
	let valueKeyPath: String?
	let indentLevel: Int
	let value: PdfObject

	var displayKey: String {
		key ?? ""
	}

	static func rows(key: String, value: PdfObject) -> [DictionaryTableRow] {
		rows(
			key: key,
			valueKeyPath: nil,
			indentLevel: 0,
			value: value,
			idPrefix: key
		)
	}

	private static func rows(
		key: String?,
		valueKeyPath: String?,
		indentLevel: Int,
		value: PdfObject,
		idPrefix: String
	) -> [DictionaryTableRow] {
		switch value {
		case .array(let array):
			if array.isEmpty {
				return [DictionaryTableRow(id: idPrefix, key: key, valueKeyPath: valueKeyPath, indentLevel: indentLevel, value: value)]
			}

			return array.enumerated().reduce(into: [DictionaryTableRow]()) { result, entry in
				let childIndentLevel: Int = if entry.offset == 0 {
					indentLevel
				} else {
					indentLevel + ((valueKeyPath != nil || indentLevel > 0) ? 1 : 0)
				}

				result.append(contentsOf: rows(
					key: entry.offset == 0 ? key : nil,
					valueKeyPath: entry.offset == 0 ? valueKeyPath : nil,
					indentLevel: childIndentLevel,
					value: entry.element,
					idPrefix: "\(idPrefix)-\(entry.offset)"
				))
			}
		case .dictionary(let dictionary):
			if dictionary.isEmpty {
				return [DictionaryTableRow(id: idPrefix, key: key, valueKeyPath: valueKeyPath, indentLevel: indentLevel, value: value)]
			}

			return dictionary
				.sorted { $0.key < $1.key }
				.enumerated()
				.reduce(into: [DictionaryTableRow]()) { result, entry in
					result.append(contentsOf: rows(
						key: entry.offset == 0 ? key : nil,
						valueKeyPath: [valueKeyPath, entry.element.key].compactMap(\.self).joined(separator: "."),
						indentLevel: indentLevel,
						value: entry.element.value,
						idPrefix: "\(idPrefix).\(entry.element.key)"
					))
				}
		default:
			return [DictionaryTableRow(id: idPrefix, key: key, valueKeyPath: valueKeyPath, indentLevel: indentLevel, value: value)]
		}
	}
}

private struct DictionaryValueCell: View {
	let row: DictionaryTableRow

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			Color.clear
				.frame(width: CGFloat(row.indentLevel) * 16)
			if let valueKeyPath = row.valueKeyPath {
				Text("\(valueKeyPath):")
					.foregroundStyle(.secondary)
			}
			PdfObjectValueCell(value: row.value)
		}
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
		var id: Int {
			index
		}
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
		var id: Int {
			0
		}
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
