// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfObject: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfObject {
		guard let object = try parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .expectedObject)
		}
		return object
	}
	
	static func parseIndirect(objects: PdfObjectList?, context: inout PdfParseContext) throws -> PdfObject {
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
			
			let filters: [String] = if dictionary.isImage(objects: objects) {
				[]
			} else {
				switch dictionary["Filter"] {
				case nil: []
				case .name(let string): [string]
				case .array(let array): try array.compactMap { try $0.name(objects: objects) }
				default: throw PdfParseError(context: context, failure: .unexpectedToken)
				}
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

private enum ParseStackElement {
	case arrayOpen
	case dictionaryOpen
	case object(PdfObject)
}
