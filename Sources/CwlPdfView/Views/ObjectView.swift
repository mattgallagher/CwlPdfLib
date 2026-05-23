// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CwlPdfRenderer
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
				DictionaryTable(layout: layout, dictionary: dictionary, isStream: false)
			case .stream(let pdfStream):
				VSplitView {
					DictionaryTable(layout: layout, dictionary: pdfStream.dictionary, isStream: true)
					VStack(alignment: .leading) {
						Text("Stream content").font(.headline)
						if let image = pdfStream.cgImage(lookup: document.pdf.lookup) {
							Image(decorative: image, scale: 1, orientation: .up)
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
				ArrayTable(layout: layout, array: array)
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

	init(layout: PdfObjectLayout, dictionary: PdfDictionary, isStream: Bool) {
		let name = if isStream {
			PdfObject.stream(PdfStream(objectIdentifier: PdfObjectIdentifier(number: 0, generation: 0), dictionary: [:], data: Data())).typeName
		} else {
			PdfObject.dictionary([:]).typeName
		}
		self.keyColumnTitle = "\(layout.debugDescription) (\(name))"
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
	let prefixText: String?
	let suffixText: String?
	let value: PdfObject?

	var displayKey: String {
		key ?? ""
	}

	static func rows(key: String, value: PdfObject) -> [DictionaryTableRow] {
		rows(
			key: key,
			valueKeyPath: nil,
			indentLevel: 0,
			prefixText: nil,
			suffixText: nil,
			value: value,
			idPrefix: key
		)
	}

	private static func rows(
		key: String?,
		valueKeyPath: String?,
		indentLevel: Int,
		prefixText: String?,
		suffixText: String?,
		value: PdfObject,
		idPrefix: String
	) -> [DictionaryTableRow] {
		switch value {
		case .array(let array):
			if array.isEmpty || array.count == 1, let inlineValue = array.first {
				return [DictionaryTableRow(
					id: idPrefix,
					key: key,
					valueKeyPath: valueKeyPath,
					indentLevel: indentLevel,
					prefixText: [prefixText, "["].compactMap(\.self).joined(separator: " "),
					suffixText: ["]", suffixText].compactMap(\.self).joined(separator: " "),
					value: inlineValue
				)]
			} else if array.isEmpty {
				return [DictionaryTableRow(
					id: idPrefix,
					key: key,
					valueKeyPath: valueKeyPath,
					indentLevel: indentLevel,
					prefixText: [prefixText, "["].compactMap(\.self).joined(separator: " "),
					suffixText: ["]", suffixText].compactMap(\.self).joined(separator: " "),
					value: nil
				)]
			}

			var result = [DictionaryTableRow(
				id: idPrefix,
				key: key,
				valueKeyPath: valueKeyPath,
				indentLevel: indentLevel,
				prefixText: [prefixText, "["].compactMap(\.self).joined(separator: " "),
				suffixText: nil,
				value: nil
			)]

			for entry in array.enumerated() {
				result.append(contentsOf: rows(
					key: nil,
					valueKeyPath: nil,
					indentLevel: indentLevel + 1,
					prefixText: nil,
					suffixText: nil,
					value: entry.element,
					idPrefix: "\(idPrefix)-\(entry.offset)"
				))
			}

			result.append(DictionaryTableRow(
				id: "\(idPrefix)-close",
				key: nil,
				valueKeyPath: nil,
				indentLevel: indentLevel,
				prefixText: "]",
				suffixText: suffixText,
				value: nil
			))

			return result
		case .dictionary(let dictionary):
			if dictionary.isEmpty {
				return [DictionaryTableRow(
					id: idPrefix,
					key: key,
					valueKeyPath: valueKeyPath,
					indentLevel: indentLevel,
					prefixText: [prefixText, "<<"].compactMap(\.self).joined(separator: " "),
					suffixText: [">>", suffixText].compactMap(\.self).joined(separator: " "),
					value: nil
				)]
			}

			var result = [DictionaryTableRow(
				id: idPrefix,
				key: key,
				valueKeyPath: valueKeyPath,
				indentLevel: indentLevel,
				prefixText: [prefixText, "<<"].compactMap(\.self).joined(separator: " "),
				suffixText: nil,
				value: nil
			)]

			for entry in dictionary.sorted(by: { $0.key < $1.key }) {
				result.append(contentsOf: rows(
					key: nil,
					valueKeyPath: entry.key,
					indentLevel: indentLevel + 1,
					prefixText: nil,
					suffixText: nil,
					value: entry.value,
					idPrefix: "\(idPrefix).\(entry.key)"
				))
			}

			result.append(DictionaryTableRow(
				id: "\(idPrefix)-close",
				key: nil,
				valueKeyPath: nil,
				indentLevel: indentLevel,
				prefixText: ">>",
				suffixText: suffixText,
				value: nil
			))

			return result
		default:
			return [DictionaryTableRow(
				id: idPrefix,
				key: key,
				valueKeyPath: valueKeyPath,
				indentLevel: indentLevel,
				prefixText: prefixText,
				suffixText: suffixText,
				value: value
			)]
		}
	}
}

private struct DictionaryValueCell: View {
	let row: DictionaryTableRow

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 6) {
			if row.indentLevel > 0 {
				HStack(spacing: 0) {
					ForEach(0..<row.indentLevel, id: \.self) { _ in
						Color.clear.frame(width: 8)
						Divider()
						Color.clear.frame(width: 8)
					}
				}
				.padding(.vertical, -8)
			}
			if let valueKeyPath = row.valueKeyPath {
				Text("\(valueKeyPath):")
					.foregroundStyle(.secondary)
			}
			if let prefixText = row.prefixText {
				Text(prefixText)
			}
			if let value = row.value {
				PdfObjectValueCell(value: value)
			}
			if let suffixText = row.suffixText {
				Text(suffixText)
			}
		}
	}
}

private struct ArrayTable: View {
	let entries: [Entry]
	let layout: PdfObjectLayout

	init(layout: PdfObjectLayout, array: PdfArray) {
		self.layout = layout
		self.entries = array.enumerated().map { Entry(index: $0.offset, value: $0.element) }
	}

	var body: some View {
		Table(entries) {
			TableColumn("\(layout.debugDescription) (\(PdfObject.array([]).typeName))") { entry in
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
