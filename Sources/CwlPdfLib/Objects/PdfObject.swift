// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public enum PdfObject: Sendable, Equatable {
	case array(PdfArray)
	case boolean(Bool)
	case dictionary([String: PdfObject])
	case identifier(String)
	case integer(Int)
	case name(String)
	case null
	case real(Double)
	case reference(PdfObjectNumber)
	case stream(PdfStream)
	case string(Data)
}

public typealias PdfArray = [PdfObject]
public typealias PdfDictionary = [String: PdfObject]
public typealias PdfNameTree = [(String, value: PdfObject)]
public typealias PdfNumberTree = [(key: Int, value: PdfObject)]

public extension PdfObject {
	var array: PdfArray? {
		guard case .array(let pdfArray) = self else {
			return nil
		}
		return pdfArray
	}
	
	var boolean: Bool? {
		guard case .boolean(let boolean) = self else {
			return nil
		}
		return boolean
	}
	
	var dictionary: PdfDictionary? {
		guard case .dictionary(let pdfDictionary) = self else {
			return nil
		}
		return pdfDictionary
	}
	
	var name: String? {
		guard case .name(let string) = self else {
			return nil
		}
		return string
	}
	
	var number: Double? {
		switch self {
		case .integer(let integer): return Double(integer)
		case .real(let real): return real
		default: return nil
		}
	}

	var pdfText: String? {
		guard case .string(let string) = self else {
			return nil
		}
		return string.pdfText()
	}
	
	var stream: PdfStream? {
		guard case .stream(let stream) = self else {
			return nil
		}
		return stream
	}
}

extension PdfObject: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfObject {
		guard let object = try parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .expectedObject)
		}
		return object
	}
	
	static func parseIndirect(context: inout PdfParseContext) throws -> PdfObject {
		try context.nextToken()
		let number = try context.naturalNumber()
		try context.nextToken()
		let generation = try context.naturalNumber()
		guard number == context.objectNumber?.number, generation == context.objectNumber?.generation else {
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
			let data = try context.decode(length: length, filter: dictionary["Filter"], decodeParams: dictionary["DecodeParms"])
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
				element = .object(.string(bytes))
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
					element = .object(.reference(PdfObjectNumber(number: number, generation: generation)))
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
				element = .object(.string(bytes + context.data(range: range)))
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
		case .string(let data): return data.pdfText()
		}
	}
}

private enum ParseStackElement {
	case arrayOpen
	case dictionaryOpen
	case object(PdfObject)
}
