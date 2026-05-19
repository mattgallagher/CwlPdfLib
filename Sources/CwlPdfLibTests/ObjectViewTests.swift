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
		#expect(rows[0].value == .integer(2))
	}

	@Test
	func `GIVEN an array value WHEN dictionary rows built THEN each element gets its own row`() {
		let rows = DictionaryTableRow.rows(
			key: "Kids",
			value: .array([
				.reference(PdfObjectIdentifier(number: 1, generation: 0)),
				.reference(PdfObjectIdentifier(number: 2, generation: 0)),
				.integer(3)
			])
		)

		#expect(rows.count == 3)
		#expect(rows.map(\.key) == ["Kids", nil, nil])
		#expect(rows.map(\.valueKeyPath) == [nil, nil, nil])
		#expect(rows.map(\.indentLevel) == [0, 0, 0])
		#expect(rows.map(\.value) == [
			.reference(PdfObjectIdentifier(number: 1, generation: 0)),
			.reference(PdfObjectIdentifier(number: 2, generation: 0)),
			.integer(3)
		])
	}

	@Test
	func `GIVEN a dictionary value WHEN dictionary rows built THEN each nested key value pair gets its own row`() {
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

		#expect(rows.count == 3)
		#expect(rows.map(\.key) == ["Resources", nil, nil])
		#expect(rows.map(\.valueKeyPath) == ["Font", "ProcSet", nil])
		#expect(rows.map(\.indentLevel) == [0, 0, 1])
		#expect(rows.map(\.value) == [
			.reference(PdfObjectIdentifier(number: 4, generation: 0)),
			.name("PDF"),
			.reference(PdfObjectIdentifier(number: 5, generation: 0))
		])
	}
}
