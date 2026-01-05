// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public enum PdfObject: Sendable, Hashable {
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
	func array(objects: PdfObjectList?) throws -> PdfArray? {
		switch self {
		case .array(let array): return array
		case .reference(let reference): return try objects?.object(for: reference)?.array(objects: objects)
		default: return nil
		}
	}
	
	func boolean(objects: PdfObjectList?) throws -> Bool? {
		switch self {
		case .boolean(let boolean): return boolean
		case .reference(let reference): return try objects?.object(for: reference)?.boolean(objects: objects)
		default: return nil
		}
	}
	
	func dictionary(objects: PdfObjectList?) throws -> PdfDictionary? {
		switch self {
		case .dictionary(let dictionary): return dictionary
		case .reference(let reference): return try objects?.object(for: reference)?.dictionary(objects: objects)
		default: return nil
		}
	}
	
	var identifier: String? {
		guard case .identifier(let string) = self else {
			return nil
		}
		return string
	}

	func integer(objects: PdfObjectList?) throws -> Int? {
		switch self {
		case .integer(let integer): return integer
		case .reference(let reference): return try objects?.object(for: reference)?.integer(objects: objects)
		default: return nil
		}
	}

	func name(objects: PdfObjectList?) throws -> String? {
		switch self {
		case .name(let name): return name
		case .reference(let reference): return try objects?.object(for: reference)?.name(objects: objects)
		default: return nil
		}
	}

	func number(objects: PdfObjectList?) throws -> Double? {
		switch self {
		case .integer(let integer): return Double(integer)
		case .real(let real): return real
		case .reference(let reference): return try objects?.object(for: reference)?.number(objects: objects)
		default: return nil
		}
	}

	func isNull(objects: PdfObjectList?) throws -> Bool {
		switch self {
		case .null: return true
		case .reference(let reference): return try objects?.object(for: reference)?.isNull(objects: objects) ?? true
		default: return false
		}
	}

	func pdfText(objects: PdfObjectList?) throws -> String? {
		switch self {
		case .string(let string, _): return string.pdfText()
		case .reference(let reference): return try objects?.object(for: reference)?.pdfText(objects: objects)
		default: return nil
		}
	}

	func real(objects: PdfObjectList?) throws -> Double? {
		switch self {
		case .real(let real): return real
		case .reference(let reference): return try objects?.object(for: reference)?.real(objects: objects)
		default: return nil
		}
	}
	
	var reference: PdfObjectIdentifier? {
		switch self {
		case .reference(let objectIdentifier): return objectIdentifier
		default: return nil
		}
	}

	func stream(objects: PdfObjectList?) throws -> PdfStream? {
		switch self {
		case .stream(let stream): return stream
		case .reference(let reference): return try objects?.object(for: reference)?.stream(objects: objects)
		default: return nil
		}
	}
	
	func string(objects: PdfObjectList?) throws -> Data? {
		switch self {
		case .string(let string, _): return string
		case .reference(let reference): return try objects?.object(for: reference)?.string(objects: objects)
		default: return nil
		}
	}
	
	func recursivelyResolve(objects: PdfObjectList?) throws -> PdfObject? {
		switch self {
		case .array(let elements):
			return try elements.recursivelyResolve(objects: objects).map { .array($0) }
		case .dictionary(let dictionary):
			return try dictionary.recursivelyResolve(objects: objects).map { .dictionary($0) }
		case .reference(let reference):
			return try reference.recursivelyResolve(objects: objects)
		default:
			return self
		}
	}
}

extension PdfObjectIdentifier {
	func recursivelyResolve(objects: PdfObjectList?) throws -> PdfObject? {
		if let resolved = try objects?.object(for: self) {
			return resolved
		} else {
			return nil
		}
	}
}

extension PdfDictionary {
	func recursivelyResolve(objects: PdfObjectList?) throws -> PdfDictionary? {
		try PdfDictionary(uniqueKeysWithValues: compactMap { key, value in try value.recursivelyResolve(objects: objects).map { (key, $0) } })
	}
}

extension PdfArray {
	func recursivelyResolve(objects: PdfObjectList?) throws -> PdfArray? {
		try PdfArray(compactMap { try $0.recursivelyResolve(objects: objects) })
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
