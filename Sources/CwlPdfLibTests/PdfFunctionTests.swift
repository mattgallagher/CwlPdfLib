// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import Foundation
import Testing

struct PdfFunctionTests {
	@Test
	func `GIVEN chart tint transforms WHEN calculator functions are evaluated THEN expected CMYK values are returned`() throws {
		let black = try #require(calculatorFunction(
			program: "{0 0 0 4 -1 roll}",
			domain: [0, 1],
			range: [0, 1, 0, 1, 0, 1, 0, 1]
		))
		let cyanMagenta = try #require(calculatorFunction(
			program: "{0 0}",
			domain: [0, 1, 0, 1],
			range: [0, 1, 0, 1, 0, 1, 0, 1]
		))
		let magentaYellow = try #require(calculatorFunction(
			program: "{0 3 1 roll 0}",
			domain: [0, 1, 0, 1],
			range: [0, 1, 0, 1, 0, 1, 0, 1]
		))

		#expect(black.evaluate([0.7]) == [0, 0, 0, 0.7])
		#expect(cyanMagenta.evaluate([0.8, 0.6]) == [0.8, 0.6, 0, 0])
		#expect(magentaYellow.evaluate([0.8, 0.6]) == [0, 0.8, 0.6, 0])
	}

	@Test
	func `GIVEN arithmetic calculator operators WHEN evaluated THEN numeric results are correct`() throws {
		try expectCalculator(
			program: "{pop -2 abs 3 4 add add 2 sub 3 mul 2 div 2 exp sqrt}",
			expected: [10.5]
		)
		try expectCalculator(
			program: "{pop 1 1 atan 60 cos add 3.2 ceiling add 3.8 floor add -3.8 truncate add}",
			expected: [49.5]
		)
		try expectCalculator(
			program: "{pop 7 3 idiv 7 3 mod add 100 ln add 100 log add 3.8 cvi cvr add}",
			expected: [12.605170185988092]
		)
		try expectCalculator(
			program: "{pop 30 sin 4 sqrt add 2.5 round add -2.5 round neg add}",
			expected: [8.5]
		)
	}

	@Test
	func `GIVEN boolean conditional and bitwise operators WHEN evaluated THEN typed results are correct`() throws {
		try expectCalculator(
			program: "{dup 0.5 ge exch 0.75 lt and {2} {3} ifelse}",
			input: 0.6,
			expected: [2]
		)
		try expectCalculator(
			program: "{pop 6 3 and 8 or 3 xor 1 bitshift}",
			expected: [18]
		)
		try expectCalculator(
			program: "{pop true false or not {1} if false true xor {2} {3} ifelse}",
			expected: [2]
		)
		try expectCalculator(
			program: "{dup 0 gt exch 0 le or {4} if}",
			input: 0.4,
			expected: [4]
		)
		try expectCalculator(
			program: "{pop 2 2 eq 2 3 ne and {5} {6} ifelse}",
			expected: [5]
		)
	}

	@Test
	func `GIVEN stack calculator operators WHEN evaluated THEN stack ordering is correct`() throws {
		try expectCalculator(
			program: "{pop 1 2 3 3 1 roll}",
			range: repeatedRange(count: 3),
			expected: [3, 1, 2]
		)
		try expectCalculator(
			program: "{pop 1 2 exch dup 1 index 3 copy pop pop}",
			range: repeatedRange(count: 5),
			expected: [2, 1, 1, 1, 1]
		)
	}

	@Test
	func `GIVEN invalid calculator programs WHEN parsed or evaluated THEN they fail safely`() throws {
		#expect(calculatorFunction(program: "{1 unknown}") == nil)
		#expect(calculatorFunction(program: "{1 2") == nil)
		let divisionByZero = try #require(calculatorFunction(program: "{pop 1 0 div}"))
		#expect(divisionByZero.evaluate([0]) == nil)
		let wrongOutputCount = try #require(calculatorFunction(program: "{1 2}"))
		#expect(wrongOutputCount.evaluate([0]) == nil)
	}
}

private func expectCalculator(
	program: String,
	input: Double = 0,
	range: [Double] = [-1_000, 1_000],
	expected: [Double]
) throws {
	let function = try #require(calculatorFunction(program: program, range: range))
	let result = try #require(function.evaluate([input]))
	#expect(result.count == expected.count)
	for (actual, expected) in zip(result, expected) {
		#expect(abs(actual - expected) < 0.000_000_001)
	}
}

private func calculatorFunction(
	program: String,
	domain: [Double] = [0, 1],
	range: [Double] = [-1_000, 1_000]
) -> PdfFunction? {
	let stream = PdfStream(
		objectIdentifier: PdfObjectIdentifier(number: 20_000, generation: 0),
		dictionary: [
			.Domain: .array(domain.map(PdfObject.real)),
			.FunctionType: .integer(4),
			.Range: .array(range.map(PdfObject.real))
		],
		data: Data(program.utf8)
	)
	return PdfFunction.parse(.stream(stream), lookup: nil)
}

private func repeatedRange(count: Int) -> [Double] {
	Array(repeating: [-1_000.0, 1_000.0], count: count).flatMap(\.self)
}
