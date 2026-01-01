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
