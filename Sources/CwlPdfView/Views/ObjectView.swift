// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CwlPdfRenderer
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

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
						if pdfStream.dictionary.isImage(lookup: document.pdf.lookup) {
							ImageStreamView(
								stream: pdfStream,
								lookup: document.pdf.lookup
							)
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

struct ImageStreamExport {
	let data: Data
	let contentType: UTType
	let fileExtension: String

	static func export(
		stream: PdfStream,
		lookup: PdfObjectLookup?,
		applySoftMask: Bool
	) -> ImageStreamExport? {
		guard let pdfImage = try? PdfImage(stream: stream, lookup: lookup) else {
			return nil
		}

		if applySoftMask == false || pdfImage.softMask == nil {
			switch pdfImage.encoding {
			case .jpeg:
				return ImageStreamExport(data: pdfImage.data, contentType: .jpeg, fileExtension: "jpg")
			case .jpeg2000:
				return ImageStreamExport(
					data: pdfImage.data,
					contentType: UTType(filenameExtension: "jp2") ?? .data,
					fileExtension: "jp2"
				)
			case .raw:
				break
			}
		}

		guard
			let image = pdfImage.createCGImage(lookup: lookup, applySoftMask: applySoftMask),
			let data = pngData(image: image)
		else {
			return nil
		}

		return ImageStreamExport(data: data, contentType: .png, fileExtension: "png")
	}

	private static func pngData(image: CGImage) -> Data? {
		let data = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
			return nil
		}
		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else {
			return nil
		}
		return data as Data
	}
}

private struct ImageStreamView: View {
	let stream: PdfStream
	let lookup: PdfObjectLookup?
	@State private var applySoftMask = true

	private var hasSoftMask: Bool {
		stream.dictionary[.SMask]?.stream(lookup: lookup) != nil
	}

	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				if hasSoftMask {
					maskToggle
				}
				Button("Save...") {
					saveImage()
				}
			}

			if let image = stream.cgImage(lookup: lookup, applySoftMask: !hasSoftMask || applySoftMask) {
				Image(decorative: image, scale: 1, orientation: .up)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				Text("<unknown image: \(stream.data.count) bytes>")
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}

	@ViewBuilder
	private var maskToggle: some View {
		#if os(macOS)
		Toggle("Apply mask", isOn: $applySoftMask)
			.toggleStyle(.checkbox)
		#else
		Toggle("Apply mask", isOn: $applySoftMask)
		#endif
	}

	private func saveImage() {
		guard let export = ImageStreamExport.export(
			stream: stream,
			lookup: lookup,
			applySoftMask: !hasSoftMask || applySoftMask
		) else {
			return
		}

		#if os(macOS)
		let panel = NSSavePanel()
		panel.allowedContentTypes = [export.contentType]
		panel.nameFieldStringValue = [
			stream.objectIdentifier.number.description,
			stream.objectIdentifier.generation.description
		].joined(separator: "-") + ".\(export.fileExtension)"
		panel.canCreateDirectories = true
		if panel.runModal() == .OK, let url = panel.url {
			try? export.data.write(to: url)
		}
		#endif
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
