// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfObject: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfObject {
		guard let object = try parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .expectedObject)
		}
		return object
	}
	
	static func parseIndirect(lookup: PdfObjectLookup?, context: inout PdfParseContext) throws -> PdfObject {
		let number = try PdfToken
			.parse(context: &context)
			.requireNaturalNumber(context: &context)

		let generation = try PdfToken
			.parse(context: &context)
			.requireNaturalNumber(context: &context)
		
		guard number == context.objectIdentifier?.number, generation == context.objectIdentifier?.generation else {
			throw PdfParseError(context: context, failure: .objectNotFound)
		}
		
		try PdfToken
			.parse(context: &context)
			.requireIdentifier(context: &context, equals: .obj, else: .expectedIdentifierNotFound)
		
		var object = try PdfObject.parse(context: &context)
		
		var token = try PdfToken
			.parse(context: &context)
		
		if token.isIdentifier(context: context, equals: .stream) {
			guard case .dictionary(let dictionary) = object else {
				throw PdfParseError(context: context, failure: .expectedDictionary)
			}
			guard let lengthObject = dictionary["Length"], case .integer(let length) = lengthObject else {
				throw PdfParseError(context: context, failure: .missingLength)
			}
			try context.readEndOfLine()
			
			let filters = switch dictionary["Filter"] {
			case nil: [] as [String]
			case .name(let string): [string]
			case .array(let array): array.compactMap { $0.name(lookup: lookup) }
			default: throw PdfParseError(context: context, failure: .unexpectedToken)
			}
			
			let data = try context.decode(
				length: length,
				filters: filters,
				decodeParams: dictionary["DecodeParms"],
				decryption: lookup?.decryption,
				objectId: context.objectIdentifier,
				isImage: dictionary.isImage(lookup: lookup)
			)
			object = .stream(PdfStream(dictionary: dictionary, data: data))
			
			try PdfToken
				.parse(context: &context)
				.requireIdentifier(context: &context, equals: .endstream, else: .expectedIdentifierNotFound)
			
			token = try PdfToken
				.parse(context: &context)
		}
		
		try token.requireIdentifier(context: &context, equals: .endobj, else: .expectedIdentifierNotFound)
		return object
	}
	
	static func parseNext(context: inout PdfParseContext) throws -> PdfObject? {
		var stack = [ParseStackElement]()
		
		repeat {
			guard let token = try PdfToken.parseNext(context: &context) else {
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
				if context.slice[reslice: range].elementsEqual(PdfParseIdentifier.R.rawValue.utf8) {
					guard
						let generationToken = stack.popLast(),
						case .object(.integer(let generation)) = generationToken,
						let numberToken = stack.popLast(),
						case .object(.integer(let number)) = numberToken
					else {
						throw PdfParseError(context: context, failure: .unexpectedToken)
					}
					element = .object(.reference(PdfObjectIdentifier(number: number, generation: generation)))
				} else if context.slice[reslice: range].elementsEqual(PdfParseIdentifier.`true`.rawValue.utf8) {
					element = .object(.boolean(true))
				} else if context.slice[reslice: range].elementsEqual(PdfParseIdentifier.`false`.rawValue.utf8) {
					element = .object(.boolean(false))
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

private enum ParseStackElement {
	case arrayOpen
	case dictionaryOpen
	case object(PdfObject)
}
