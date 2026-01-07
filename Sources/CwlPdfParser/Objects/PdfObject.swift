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
		case .array(let array): array
		case .reference(let reference): try objects?.object(for: reference)?.array(objects: objects)
		default: nil
		}
	}
	
	func boolean(objects: PdfObjectList?) throws -> Bool? {
		switch self {
		case .boolean(let boolean): boolean
		case .reference(let reference): try objects?.object(for: reference)?.boolean(objects: objects)
		default: nil
		}
	}
	
	func dictionary(objects: PdfObjectList?) throws -> PdfDictionary? {
		switch self {
		case .dictionary(let dictionary): dictionary
		case .reference(let reference): try objects?.object(for: reference)?.dictionary(objects: objects)
		default: nil
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
		case .integer(let integer): integer
		case .reference(let reference): try objects?.object(for: reference)?.integer(objects: objects)
		default: nil
		}
	}

	func name(objects: PdfObjectList?) throws -> String? {
		switch self {
		case .name(let name): name
		case .reference(let reference): try objects?.object(for: reference)?.name(objects: objects)
		default: nil
		}
	}

	func isNull(objects: PdfObjectList?) throws -> Bool {
		switch self {
		case .null: true
		case .reference(let reference): try objects?.object(for: reference)?.isNull(objects: objects) ?? true
		default: false
		}
	}

	func pdfText(objects: PdfObjectList?) throws -> String? {
		switch self {
		case .string(let string, _): string.pdfText()
		case .reference(let reference): try objects?.object(for: reference)?.pdfText(objects: objects)
		default: nil
		}
	}

	func real(objects: PdfObjectList?) throws -> Double? {
		switch self {
		case .integer(let integer): Double(integer)
		case .real(let real): real
		case .reference(let reference): try objects?.object(for: reference)?.real(objects: objects)
		default: nil
		}
	}
	
	var reference: PdfObjectIdentifier? {
		switch self {
		case .reference(let objectIdentifier): objectIdentifier
		default: nil
		}
	}

	func stream(objects: PdfObjectList?) throws -> PdfStream? {
		switch self {
		case .stream(let stream): stream
		case .reference(let reference): try objects?.object(for: reference)?.stream(objects: objects)
		default: nil
		}
	}
	
	func string(objects: PdfObjectList?) throws -> Data? {
		switch self {
		case .string(let string, _): string
		case .reference(let reference): try objects?.object(for: reference)?.string(objects: objects)
		default: nil
		}
	}
	
	func recursivelyResolve(objects: PdfObjectList?) throws -> PdfObject? {
		switch self {
		case .array(let elements):
			try elements.recursivelyResolve(objects: objects).map { .array($0) }
		case .dictionary(let dictionary):
			try dictionary.recursivelyResolve(objects: objects).map { .dictionary($0) }
		case .reference(let reference):
			try reference.recursivelyResolve(objects: objects)
		default:
			self
		}
	}
}

extension PdfObjectIdentifier {
	func recursivelyResolve(objects: PdfObjectList?) throws -> PdfObject? {
		if let resolved = try objects?.object(for: self) {
			resolved
		} else {
			nil
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
		case .array(let array): array.debugDescription
		case .boolean(let bool): bool.description
		case .dictionary(let dictionary): dictionary.debugDescription
		case .identifier(let identifier): "'\(identifier)'"
		case .integer(let integer): integer.description
		case .name(let name): "\\\(name)"
		case .null: "null"
		case .real(let real): real.description
		case .reference(let reference): reference.debugDescription
		case .stream(let stream): stream.debugDescription
		case .string(let data, false): data.pdfText()
		case .string(let data, true): "<\(data.hexString())>"
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
			ASCII.digit0 + nybble
		} else {
			ASCII.a + nybble - 10
		}
	}
}
