// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public enum PdfObject: Sendable {
	case array(PdfArray)
	case boolean(Bool)
	case dictionary([String: PdfObject])
	case identifier(String)
	case integer(Int)
	case name(String)
	case null
	case real(Double)
	case reference(PdfObjectIdentifier)
	case stream(PdfStream)
	case string(Data, hex: Bool = false)
}

public typealias PdfArray = [PdfObject]
public typealias PdfDictionary = [String: PdfObject]
public typealias PdfNameTree = [(String, value: PdfObject)]
public typealias PdfNumberTree = [(key: Int, value: PdfObject)]

public extension PdfObject {
	func array(document: PdfDocument?) throws -> PdfArray? {
		switch self {
		case .array(let array): return array
		case .reference(let reference): return try document?.object(for: reference)?.array(document: document)
		default: return nil
		}
	}
	
	func boolean(document: PdfDocument?) throws -> Bool? {
		switch self {
		case .boolean(let boolean): return boolean
		case .reference(let reference): return try document?.object(for: reference)?.boolean(document: document)
		default: return nil
		}
	}
	
	func dictionary(document: PdfDocument?) throws -> PdfDictionary? {
		switch self {
		case .dictionary(let dictionary): return dictionary
		case .reference(let reference): return try document?.object(for: reference)?.dictionary(document: document)
		default: return nil
		}
	}
	
	var identifier: String? {
		guard case .identifier(let string) = self else {
			return nil
		}
		return string
	}

	func integer(document: PdfDocument?) throws -> Int? {
		switch self {
		case .integer(let integer): return integer
		case .reference(let reference): return try document?.object(for: reference)?.integer(document: document)
		default: return nil
		}
	}

	func name(document: PdfDocument?) throws -> String? {
		switch self {
		case .name(let name): return name
		case .reference(let reference): return try document?.object(for: reference)?.name(document: document)
		default: return nil
		}
	}

	func number(document: PdfDocument?) throws -> Double? {
		switch self {
		case .integer(let integer): return Double(integer)
		case .real(let real): return real
		case .reference(let reference): return try document?.object(for: reference)?.number(document: document)
		default: return nil
		}
	}

	func isNull(document: PdfDocument?) throws -> Bool {
		switch self {
		case .null: return true
		case .reference(let reference): return try document?.object(for: reference)?.isNull(document: document) ?? true
		default: return false
		}
	}

	func pdfText(document: PdfDocument?) throws -> String? {
		switch self {
		case .string(let string, _): return string.pdfText()
		case .reference(let reference): return try document?.object(for: reference)?.pdfText(document: document)
		default: return nil
		}
	}

	func real(document: PdfDocument?) throws -> Double? {
		switch self {
		case .real(let real): return real
		case .reference(let reference): return try document?.object(for: reference)?.real(document: document)
		default: return nil
		}
	}
	
	var reference: PdfObjectIdentifier? {
		switch self {
		case .reference(let objectIdentifier): return objectIdentifier
		default: return nil
		}
	}

	func stream(document: PdfDocument?) throws -> PdfStream? {
		switch self {
		case .stream(let stream): return stream
		case .reference(let reference): return try document?.object(for: reference)?.stream(document: document)
		default: return nil
		}
	}
	
	func string(document: PdfDocument?) throws -> Data? {
		switch self {
		case .string(let string, _): return string
		case .reference(let reference): return try document?.object(for: reference)?.string(document: document)
		default: return nil
		}
	}
}

extension PdfObject: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfObject {
		guard let object = try parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .expectedObject)
		}
		return object
	}
	
	static func parseIndirect(document: PdfDocument, context: inout PdfParseContext) throws -> PdfObject {
		try context.nextToken()
		let number = try context.naturalNumber()
		try context.nextToken()
		let generation = try context.naturalNumber()
		guard number == context.objectIdentifier?.number, generation == context.objectIdentifier?.generation else {
			throw PdfParseError(context: context, failure: .objectNotFound)
		}
		try context.nextToken()
		try context.identifier(equals: .obj, else: .expectedIdentifierNotFound)
		var object = try PdfObject.parse(context: &context)
		try context.nextToken()
		if context.identifier(equals: .stream) {
			guard case .dictionary(let dictionary) = object else {
				throw PdfParseError(context: context, failure: .expectedDictionary)
			}
			guard let lengthObject = dictionary["Length"], case .integer(let length) = lengthObject else {
				throw PdfParseError(context: context, failure: .missingLength)
			}
			try context.readEndOfLine()
			
			let filters: [String] = switch dictionary["Filter"] as PdfObject? {
			case nil: []
			case .name(let string): [string]
			case .array(let array): try array.compactMap { try $0.name(document: document) }
			default: throw PdfParseError(context: context, failure: .unexpectedToken)
			}
			
			let data = try context.decode(length: length, filters: filters, decodeParams: dictionary["DecodeParms"])
			object = .stream(PdfStream(dictionary: dictionary, data: data))
			try context.nextToken()
			try context.identifier(equals: .endstream, else: .expectedIdentifierNotFound)
			try context.nextToken()
		}
		try context.identifier(equals: .endobj, else: .expectedIdentifierNotFound)
		return object
	}
	
	static func parseNext(context: inout PdfParseContext) throws -> PdfObject? {
		var stack = [ParseStackElement]()
		
		repeat {
			try context.nextToken()
			guard let token = context.token else {
				if stack.isEmpty {
					return nil
				} else {
					throw PdfParseError(context: context, failure: .missingEndOfScope)
				}
			}
			
			var element: ParseStackElement
			switch token {
			case .arrayClose:
				let index = stack.lastIndex { token in
					if case .arrayOpen = token {
						return true
					}
					return false
				}
				guard let index else {
					throw PdfParseError(context: context, failure: .unexpectedToken)
				}
				let array = try stack[(index + 1)...].map {
					guard case .object(let object) = $0 else {
						throw PdfParseError(context: context, failure: .unexpectedToken)
					}
					return object
				}
				stack.removeSubrange(index...)
				element = .object(.array(array))
			case .arrayOpen:
				element = .arrayOpen
			case .comment:
				continue
			case .dictionaryClose:
				var dictionary = PdfDictionary()
				var complete = false
				while let next = stack.popLast() {
					if case .dictionaryOpen = next {
						complete = true
						break
					}
					guard case .object(let value) = next else {
						throw PdfParseError(context: context, failure: .unexpectedToken)
					}
					guard let next = stack.popLast(), case .object(.name(let key)) = next else {
						throw PdfParseError(context: context, failure: .unexpectedToken)
					}
					dictionary[key] = value
				}
				if !complete {
					throw PdfParseError(context: context, failure: .unexpectedToken)
				}
				element = .object(.dictionary(dictionary))
			case .dictionaryOpen:
				element = .dictionaryOpen
			case .hex(let bytes, _, _):
				element = .object(.string(bytes, hex: true))
			case .identifier(let range):
				if context.slice[reslice: range].elementsEqual(PdfIdentifier.R.rawValue.utf8) {
					guard
						let generationToken = stack.popLast(),
						case .object(.integer(let generation)) = generationToken,
						let numberToken = stack.popLast(),
						case .object(.integer(let number)) = numberToken
					else {
						throw PdfParseError(context: context, failure: .unexpectedToken)
					}
					element = .object(.reference(PdfObjectIdentifier(number: number, generation: generation)))
				} else {
					element = .object(.identifier(context.pdfText(range: range)))
				}
			case .integer(let sign, let value):
				element = .object(.integer(sign * value))
			case .name(let string, let range):
				element = .object(.name(string + context.pdfText(range: range)))
			case .real(let sign, let value, _):
				element = .object(.real(sign * value))
			case .string(let bytes, let range):
				element = .object(.string(bytes + context.data(range: range), hex: false))
			case .closeAngle, .openAngle, .stringEscape, .stringOctal:
				// These types are internal only and returned only if an end-of-range is
				// encountered, unexpectedly.
				throw PdfParseError(context: context, failure: .objectEndedUnexpectedly)
			}
			
			switch element {
			case .arrayOpen:
				stack.append(element)
			case .dictionaryOpen:
				stack.append(element)
			case .object(let object):
				if stack.isEmpty {
					return object
				} else {
					stack.append(element)
				}
			}
		} while true
	}
}

extension PdfObject: CustomDebugStringConvertible {
	public var debugDescription: String {
		switch self {
		case .array(let array): return array.debugDescription
		case .boolean(let bool): return bool.description
		case .dictionary(let dictionary): return dictionary.debugDescription
		case .identifier(let identifier): return "'\(identifier)'"
		case .integer(let integer): return integer.description
		case .name(let name): return "\\\(name)"
		case .null: return "null"
		case .real(let real): return real.description
		case .reference(let reference): return reference.debugDescription
		case .stream(let stream): return stream.debugDescription
		case .string(let data, false): return data.pdfText()
		case .string(let data, true): return "<\(data.hexString())>"
		}
	}
}

private enum ParseStackElement {
	case arrayOpen
	case dictionaryOpen
	case object(PdfObject)
}

private extension Data {
	 func hexString() -> String {
		  var chars: [UInt8] = []
		  chars.reserveCapacity(count * 2)
		  for byte in self {
			  chars.append(hexFromNybble(nybble: byte / 16))
			  chars.append(hexFromNybble(nybble: byte % 16))
		  }
		  return String(bytes: chars, encoding: .utf8)!
	 }
	
	func hexFromNybble(nybble: UInt8) -> UInt8 {
		if nybble < 10 {
			return ASCII.digit0 + nybble
		} else {
			return ASCII.a + nybble - 10
		}
	}
}
