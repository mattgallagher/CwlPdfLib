// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

@testable import CwlPdfParser
@testable import CwlPdfView
import Testing

@MainActor
struct ObjectViewTests {
	@Test
	func `GIVEN a scalar value WHEN dictionary rows built THEN a single keyed row is returned`() {
		let rows = DictionaryTableRow.rows(key: "Count", value: .integer(2))

		#expect(rows.count == 1)
		#expect(rows[0].key == "Count")
		#expect(rows[0].valueKeyPath == nil)
		#expect(rows[0].indentLevel == 0)
		#expect(rows[0].prefixText == nil)
		#expect(rows[0].suffixText == nil)
		#expect(rows[0].value == .integer(2))
	}

	@Test
	func `GIVEN a single value array WHEN dictionary rows built THEN the array is shown inline`() {
		let rows = DictionaryTableRow.rows(
			key: "Kids",
			value: .array([
				.reference(PdfObjectIdentifier(number: 1, generation: 0))
			])
		)

		#expect(rows.count == 1)
		#expect(rows[0].key == "Kids")
		#expect(rows[0].valueKeyPath == nil)
		#expect(rows[0].indentLevel == 0)
		#expect(rows[0].prefixText == "[")
		#expect(rows[0].suffixText == "]")
		#expect(rows[0].value == .reference(PdfObjectIdentifier(number: 1, generation: 0)))
	}

	@Test
	func `GIVEN a multi value array WHEN dictionary rows built THEN bracket rows surround the elements`() {
		let rows = DictionaryTableRow.rows(
			key: "Kids",
			value: .array([
				.reference(PdfObjectIdentifier(number: 1, generation: 0)),
				.reference(PdfObjectIdentifier(number: 2, generation: 0)),
				.integer(3)
			])
		)

		#expect(rows.count == 5)
		#expect(rows.map(\.key) == ["Kids", nil, nil, nil, nil])
		#expect(rows.map(\.valueKeyPath) == [nil, nil, nil, nil, nil])
		#expect(rows.map(\.indentLevel) == [0, 1, 1, 1, 0])
		#expect(rows.map(\.prefixText) == ["[", nil, nil, nil, "]"])
		#expect(rows.map(\.suffixText) == [nil, nil, nil, nil, nil])
		#expect(rows.map(\.value) == [
			nil,
			.reference(PdfObjectIdentifier(number: 1, generation: 0)),
			.reference(PdfObjectIdentifier(number: 2, generation: 0)),
			.integer(3),
			nil
		])
	}

	@Test
	func `GIVEN a dictionary value WHEN dictionary rows built THEN bracket rows surround nested content`() {
		let rows = DictionaryTableRow.rows(
			key: "Resources",
			value: .dictionary([
				"Font": .reference(PdfObjectIdentifier(number: 4, generation: 0)),
				"ProcSet": .array([
					.name("PDF"),
					.reference(PdfObjectIdentifier(number: 5, generation: 0))
				])
			])
		)

		#expect(rows.count == 7)
		#expect(rows.map(\.key) == ["Resources", nil, nil, nil, nil, nil, nil])
		#expect(rows.map(\.valueKeyPath) == [nil, "Font", "ProcSet", nil, nil, nil, nil])
		#expect(rows.map(\.indentLevel) == [0, 1, 1, 2, 2, 1, 0])
		#expect(rows.map(\.prefixText) == ["<<", nil, "[", nil, nil, "]", ">>"])
		#expect(rows.map(\.suffixText) == [nil, nil, nil, nil, nil, nil, nil])
		#expect(rows.map(\.value) == [
			nil,
			.reference(PdfObjectIdentifier(number: 4, generation: 0)),
			nil,
			.name("PDF"),
			.reference(PdfObjectIdentifier(number: 5, generation: 0)),
			nil,
			nil
		])
	}
}
