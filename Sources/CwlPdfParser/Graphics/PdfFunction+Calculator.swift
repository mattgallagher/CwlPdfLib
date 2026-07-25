// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public extension PdfFunction {
	/// A bounded representation of a PDF Type 4 calculator function.
	struct CalculatorFunction: Sendable, Hashable {
		let domain: [Double]
		let range: [Double]
		let instructions: [CalculatorInstruction]

		func evaluate(_ inputs: [Double]) -> [Double]? {
			let inputCount = domain.count / 2
			let outputCount = range.count / 2
			guard inputs.count >= inputCount else {
				return nil
			}

			var stack = (0..<inputCount).map { index in
				let minimum = domain[index * 2]
				let maximum = domain[index * 2 + 1]
				return CalculatorValue.real(max(minimum, min(maximum, inputs[index])))
			}
			var remainingOperations = 10_000
			guard
				execute(
					instructions,
					stack: &stack,
					remainingOperations: &remainingOperations,
					depth: 0
				),
				stack.count == outputCount
			else {
				return nil
			}

			var outputs = [Double]()
			outputs.reserveCapacity(outputCount)
			for (index, value) in stack.enumerated() {
				guard let number = value.number else {
					return nil
				}
				let minimum = range[index * 2]
				let maximum = range[index * 2 + 1]
				outputs.append(max(minimum, min(maximum, number)))
			}
			return outputs
		}
	}
}

extension PdfFunction {
	indirect enum CalculatorInstruction: Sendable, Hashable {
		case boolean(Bool)
		case integer(Int)
		case operation(CalculatorOperator)
		case procedure([CalculatorInstruction])
		case real(Double)
	}

	enum CalculatorOperator: String, Sendable, Hashable {
		case abs, add, and, atan, bitshift, ceiling, copy, cos, cvi, cvr, div, dup, eq, exch
		case exp, floor, ge, gt, idiv, `if`, ifelse, index, le, ln, log, lt, mod, mul, ne, neg
		case not, or, pop, roll, round, sin, sqrt, sub, truncate, xor
	}

	static func parseCalculator(
		dictionary: PdfDictionary,
		data: Data?,
		lookup: PdfObjectLookup?
	) -> PdfFunction? {
		guard
			let domain = parseCalculatorArray(dictionary[.Domain], lookup: lookup),
			let range = parseCalculatorArray(dictionary[.Range], lookup: lookup),
			!domain.isEmpty,
			!range.isEmpty,
			domain.count.isMultiple(of: 2),
			range.count.isMultiple(of: 2),
			let data
		else {
			return nil
		}
		var parser = CalculatorParser(data: data)
		guard let instructions = parser.parse() else {
			return nil
		}

		return .calculator(
			CalculatorFunction(
				domain: domain,
				range: range,
				instructions: instructions
			)
		)
	}

	private static func parseCalculatorArray(_ object: PdfObject?, lookup: PdfObjectLookup?) -> [Double]? {
		guard let array = object?.array(lookup: lookup) else {
			return nil
		}
		let values = array.compactMap { $0.real(lookup: lookup) }
		return values.count == array.count ? values : nil
	}
}

private enum CalculatorValue {
	case boolean(Bool)
	case integer(Int)
	case procedure([PdfFunction.CalculatorInstruction])
	case real(Double)

	var number: Double? {
		switch self {
		case .integer(let value): Double(value)
		case .real(let value): value
		default: nil
		}
	}

	var integer: Int? {
		if case .integer(let value) = self {
			value
		} else {
			nil
		}
	}
}

private extension PdfFunction.CalculatorFunction {
	static let maximumStackDepth = 1_024
	static let maximumProcedureDepth = 64

	func execute(
		_ instructions: [PdfFunction.CalculatorInstruction],
		stack: inout [CalculatorValue],
		remainingOperations: inout Int,
		depth: Int
	) -> Bool {
		guard depth <= Self.maximumProcedureDepth else {
			return false
		}

		for instruction in instructions {
			remainingOperations -= 1
			guard remainingOperations >= 0 else {
				return false
			}
			switch instruction {
			case .boolean(let value):
				stack.append(.boolean(value))
			case .integer(let value):
				stack.append(.integer(value))
			case .real(let value):
				stack.append(.real(value))
			case .procedure(let procedure):
				stack.append(.procedure(procedure))
			case .operation(let operation):
				guard execute(
					operation,
					stack: &stack,
					remainingOperations: &remainingOperations,
					depth: depth
				) else {
					return false
				}
			}
			guard stack.count <= Self.maximumStackDepth else {
				return false
			}
		}
		return true
	}

	func execute(
		_ operation: PdfFunction.CalculatorOperator,
		stack: inout [CalculatorValue],
		remainingOperations: inout Int,
		depth: Int
	) -> Bool {
		switch operation {
		case .abs:
			return unaryNumber(&stack) { value in
				switch value {
				case .integer(let integer): integer == Int.min ? .real(-Double(integer)) : .integer(Swift.abs(integer))
				case .real(let real): .real(Swift.abs(real))
				default: nil
				}
			}
		case .add:
			return binaryNumber(&stack, integer: { adding($0, $1) }, real: +)
		case .and:
			return binaryBooleanOrInteger(&stack, boolean: { $0 && $1 }, integer: &)
		case .atan:
			return binaryReal(&stack) { numerator, denominator in
				guard numerator != 0 || denominator != 0 else { return nil }
				let angle = atan2(numerator, denominator) * 180 / .pi
				return angle < 0 ? angle + 360 : angle
			}
		case .bitshift:
			guard
				let shift = stack.popLast()?.integer,
				let value = stack.popLast()?.integer,
				Swift.abs(shift) < Int.bitWidth
			else {
				return false
			}
			stack.append(.integer(shift >= 0 ? value << shift : value >> -shift))
			return true
		case .ceiling:
			return unaryNumber(&stack) { value in
				switch value {
				case .integer: value
				case .real(let real): .real(ceil(real))
				default: nil
				}
			}
		case .copy:
			guard
				let count = stack.popLast()?.integer,
				count >= 0,
				count <= stack.count,
				stack.count + count <= Self.maximumStackDepth
			else {
				return false
			}
			stack.append(contentsOf: stack.suffix(count))
			return true
		case .cos:
			return unaryReal(&stack) { cos($0 * .pi / 180) }
		case .cvi:
			guard let number = stack.popLast()?.number, let value = exactInt(number.rounded(.towardZero)) else {
				return false
			}
			stack.append(.integer(value))
			return true
		case .cvr:
			guard let number = stack.popLast()?.number else {
				return false
			}
			stack.append(.real(number))
			return true
		case .div:
			return binaryReal(&stack) { numerator, denominator in
				guard denominator != 0 else { return nil }
				return numerator / denominator
			}
		case .dup:
			guard let value = stack.last else { return false }
			stack.append(value)
			return true
		case .eq, .ne:
			guard let rhs = stack.popLast(), let lhs = stack.popLast(), let equal = equal(lhs, rhs) else {
				return false
			}
			stack.append(.boolean(operation == .eq ? equal : !equal))
			return true
		case .exch:
			guard stack.count >= 2 else { return false }
			stack.swapAt(stack.count - 1, stack.count - 2)
			return true
		case .exp:
			return binaryReal(&stack) { base, exponent in pow(base, exponent) }
		case .floor:
			return unaryNumber(&stack) { value in
				switch value {
				case .integer: value
				case .real(let real): .real(floor(real))
				default: nil
				}
			}
		case .ge, .gt, .le, .lt:
			return comparison(operation, stack: &stack)
		case .idiv:
			guard
				let denominator = stack.popLast()?.integer,
				let numerator = stack.popLast()?.integer,
				denominator != 0,
				!(numerator == Int.min && denominator == -1)
			else {
				return false
			}
			stack.append(.integer(numerator / denominator))
			return true
		case .if:
			guard
				case .procedure(let procedure)? = stack.popLast(),
				case .boolean(let condition)? = stack.popLast()
			else {
				return false
			}
			return !condition || execute(
				procedure,
				stack: &stack,
				remainingOperations: &remainingOperations,
				depth: depth + 1
			)
		case .ifelse:
			guard
				case .procedure(let falseProcedure)? = stack.popLast(),
				case .procedure(let trueProcedure)? = stack.popLast(),
				case .boolean(let condition)? = stack.popLast()
			else {
				return false
			}
			return execute(
				condition ? trueProcedure : falseProcedure,
				stack: &stack,
				remainingOperations: &remainingOperations,
				depth: depth + 1
			)
		case .index:
			guard
				let index = stack.popLast()?.integer,
				index >= 0,
				index < stack.count
			else {
				return false
			}
			stack.append(stack[stack.count - index - 1])
			return true
		case .ln:
			return unaryReal(&stack) { $0 > 0 ? log($0) : nil }
		case .log:
			return unaryReal(&stack) { $0 > 0 ? log10($0) : nil }
		case .mod:
			guard
				let divisor = stack.popLast()?.integer,
				let dividend = stack.popLast()?.integer,
				divisor != 0,
				!(dividend == Int.min && divisor == -1)
			else {
				return false
			}
			stack.append(.integer(dividend % divisor))
			return true
		case .mul:
			return binaryNumber(&stack, integer: { multiplying($0, $1) }, real: *)
		case .neg:
			return unaryNumber(&stack) { value in
				switch value {
				case .integer(let integer): integer == Int.min ? .real(-Double(integer)) : .integer(-integer)
				case .real(let real): .real(-real)
				default: nil
				}
			}
		case .not:
			guard let value = stack.popLast() else { return false }
			switch value {
			case .boolean(let boolean): stack.append(.boolean(!boolean))
			case .integer(let integer): stack.append(.integer(~integer))
			default: return false
			}
			return true
		case .or:
			return binaryBooleanOrInteger(&stack, boolean: { $0 || $1 }, integer: |)
		case .pop:
			return stack.popLast() != nil
		case .roll:
			guard
				let shift = stack.popLast()?.integer,
				let count = stack.popLast()?.integer,
				count >= 0,
				count <= stack.count
			else {
				return false
			}
			guard count > 1 else { return true }
			let normalizedShift = ((shift % count) + count) % count
			guard normalizedShift != 0 else { return true }
			let start = stack.count - count
			let values = Array(stack[start...])
			let rolled = Array(values.suffix(normalizedShift)) + Array(values.dropLast(normalizedShift))
			stack.replaceSubrange(start..., with: rolled)
			return true
		case .round:
			return unaryNumber(&stack) { value in
				switch value {
				case .integer: value
				case .real(let real): .real(real.rounded(.toNearestOrAwayFromZero))
				default: nil
				}
			}
		case .sin:
			return unaryReal(&stack) { sin($0 * .pi / 180) }
		case .sqrt:
			return unaryReal(&stack) { $0 >= 0 ? Foundation.sqrt($0) : nil }
		case .sub:
			return binaryNumber(&stack, integer: { subtracting($0, $1) }, real: -)
		case .truncate:
			return unaryNumber(&stack) { value in
				switch value {
				case .integer: value
				case .real(let real): .real(real.rounded(.towardZero))
				default: nil
				}
			}
		case .xor:
			return binaryBooleanOrInteger(&stack, boolean: !=, integer: ^)
		}
	}

	func unaryNumber(
		_ stack: inout [CalculatorValue],
		operation: (CalculatorValue) -> CalculatorValue?
	) -> Bool {
		guard let value = stack.popLast(), let result = operation(value) else {
			return false
		}
		stack.append(result)
		return true
	}

	func unaryReal(_ stack: inout [CalculatorValue], operation: (Double) -> Double?) -> Bool {
		guard
			let value = stack.popLast()?.number,
			let result = operation(value),
			result.isFinite
		else {
			return false
		}
		stack.append(.real(result))
		return true
	}

	func binaryNumber(
		_ stack: inout [CalculatorValue],
		integer: (Int, Int) -> CalculatorValue,
		real: (Double, Double) -> Double
	) -> Bool {
		guard let rhs = stack.popLast(), let lhs = stack.popLast() else {
			return false
		}
		if case .integer(let lhsInteger) = lhs, case .integer(let rhsInteger) = rhs {
			stack.append(integer(lhsInteger, rhsInteger))
			return true
		}
		guard let lhsNumber = lhs.number, let rhsNumber = rhs.number else {
			return false
		}
		let result = real(lhsNumber, rhsNumber)
		guard result.isFinite else { return false }
		stack.append(.real(result))
		return true
	}

	func binaryReal(_ stack: inout [CalculatorValue], operation: (Double, Double) -> Double?) -> Bool {
		guard
			let rhs = stack.popLast()?.number,
			let lhs = stack.popLast()?.number,
			let result = operation(lhs, rhs),
			result.isFinite
		else {
			return false
		}
		stack.append(.real(result))
		return true
	}

	func binaryBooleanOrInteger(
		_ stack: inout [CalculatorValue],
		boolean: (Bool, Bool) -> Bool,
		integer: (Int, Int) -> Int
	) -> Bool {
		guard let rhs = stack.popLast(), let lhs = stack.popLast() else {
			return false
		}
		switch (lhs, rhs) {
		case (.boolean(let lhsValue), .boolean(let rhsValue)):
			stack.append(.boolean(boolean(lhsValue, rhsValue)))
		case (.integer(let lhsValue), .integer(let rhsValue)):
			stack.append(.integer(integer(lhsValue, rhsValue)))
		default:
			return false
		}
		return true
	}

	func comparison(
		_ operation: PdfFunction.CalculatorOperator,
		stack: inout [CalculatorValue]
	) -> Bool {
		guard let rhs = stack.popLast()?.number, let lhs = stack.popLast()?.number else {
			return false
		}
		let result = switch operation {
		case .ge: lhs >= rhs
		case .gt: lhs > rhs
		case .le: lhs <= rhs
		case .lt: lhs < rhs
		default: false
		}
		stack.append(.boolean(result))
		return true
	}

	func equal(_ lhs: CalculatorValue, _ rhs: CalculatorValue) -> Bool? {
		if let lhsNumber = lhs.number, let rhsNumber = rhs.number {
			return lhsNumber == rhsNumber
		}
		switch (lhs, rhs) {
		case (.boolean(let lhsValue), .boolean(let rhsValue)):
			return lhsValue == rhsValue
		default:
			return nil
		}
	}

	func adding(_ lhs: Int, _ rhs: Int) -> CalculatorValue {
		let (result, overflow) = lhs.addingReportingOverflow(rhs)
		return overflow ? .real(Double(lhs) + Double(rhs)) : .integer(result)
	}

	func subtracting(_ lhs: Int, _ rhs: Int) -> CalculatorValue {
		let (result, overflow) = lhs.subtractingReportingOverflow(rhs)
		return overflow ? .real(Double(lhs) - Double(rhs)) : .integer(result)
	}

	func multiplying(_ lhs: Int, _ rhs: Int) -> CalculatorValue {
		let (result, overflow) = lhs.multipliedReportingOverflow(by: rhs)
		return overflow ? .real(Double(lhs) * Double(rhs)) : .integer(result)
	}

	func exactInt(_ value: Double) -> Int? {
		guard value.isFinite, value >= Double(Int.min), value <= Double(Int.max) else {
			return nil
		}
		return Int(value)
	}
}

private struct CalculatorParser {
	static let maximumInstructionCount = 10_000
	static let maximumProcedureDepth = 64

	let data: Data
	var index = 0
	var instructionCount = 0

	mutating func parse() -> [PdfFunction.CalculatorInstruction]? {
		skipWhitespaceAndComments()
		guard consume(UInt8(ascii: "{")), let instructions = parseProcedure(depth: 0) else {
			return nil
		}
		skipWhitespaceAndComments()
		return index == data.count ? instructions : nil
	}

	private mutating func parseProcedure(depth: Int) -> [PdfFunction.CalculatorInstruction]? {
		guard depth <= Self.maximumProcedureDepth else {
			return nil
		}
		var instructions = [PdfFunction.CalculatorInstruction]()
		while true {
			skipWhitespaceAndComments()
			guard index < data.count else { return nil }
			if consume(UInt8(ascii: "}")) {
				return instructions
			}
			if consume(UInt8(ascii: "{")) {
				guard let procedure = parseProcedure(depth: depth + 1), recordInstruction() else { return nil }
				instructions.append(.procedure(procedure))
				continue
			}
			guard
				let token = parseToken(),
				let instruction = instruction(token: token),
				recordInstruction()
			else {
				return nil
			}
			instructions.append(instruction)
		}
	}

	private mutating func recordInstruction() -> Bool {
		instructionCount += 1
		return instructionCount <= Self.maximumInstructionCount
	}

	private mutating func parseToken() -> String? {
		let start = index
		while index < data.count, !isDelimiter(data[index]) {
			index += 1
		}
		guard index > start else { return nil }
		return String(data: data[start..<index], encoding: .ascii)
	}

	private func instruction(token: String) -> PdfFunction.CalculatorInstruction? {
		if token == "false" { return .boolean(false) }
		if token == "true" { return .boolean(true) }
		if let integer = Int(token) { return .integer(integer) }
		if let real = Double(token), real.isFinite { return .real(real) }
		if let operation = PdfFunction.CalculatorOperator(rawValue: token) {
			return .operation(operation)
		}
		return nil
	}

	private mutating func skipWhitespaceAndComments() {
		while index < data.count {
			if isWhitespace(data[index]) {
				index += 1
			} else if data[index] == UInt8(ascii: "%") {
				while index < data.count, data[index] != 10, data[index] != 13 {
					index += 1
				}
			} else {
				return
			}
		}
	}

	private mutating func consume(_ byte: UInt8) -> Bool {
		guard index < data.count, data[index] == byte else { return false }
		index += 1
		return true
	}

	private func isDelimiter(_ byte: UInt8) -> Bool {
		isWhitespace(byte) || byte == UInt8(ascii: "{") || byte == UInt8(ascii: "}") || byte == UInt8(ascii: "%")
	}

	private func isWhitespace(_ byte: UInt8) -> Bool {
		byte == 0 || byte == 9 || byte == 10 || byte == 12 || byte == 13 || byte == 32
	}
}
