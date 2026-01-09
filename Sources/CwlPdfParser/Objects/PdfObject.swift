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
	case string(Data)
}

public typealias PdfArray = [PdfObject]
public typealias PdfDictionary = [String: PdfObject]
public typealias PdfNameTree = [(String, value: PdfObject)]
public typealias PdfNumberTree = [(key: Int, value: PdfObject)]

public extension PdfObject {
	func array(lookup: PdfObjectLookup?) -> PdfArray? {
		switch self {
		case .array(let array): array
		case .reference(let reference): try? lookup?.object(for: reference)?.array(lookup: lookup)
		default: nil
		}
	}
	
	func boolean(lookup: PdfObjectLookup?) -> Bool? {
		switch self {
		case .boolean(let boolean): boolean
		case .reference(let reference): try? lookup?.object(for: reference)?.boolean(lookup: lookup)
		default: nil
		}
	}
	
	func dictionary(lookup: PdfObjectLookup?) -> PdfDictionary? {
		switch self {
		case .dictionary(let dictionary): dictionary
		case .reference(let reference): try? lookup?.object(for: reference)?.dictionary(lookup: lookup)
		default: nil
		}
	}
	
	var identifier: String? {
		guard case .identifier(let string) = self else {
			return nil
		}
		return string
	}

	func integer(lookup: PdfObjectLookup?) -> Int? {
		switch self {
		case .integer(let integer): integer
		case .reference(let reference): try? lookup?.object(for: reference)?.integer(lookup: lookup)
		default: nil
		}
	}

	func name(lookup: PdfObjectLookup?) -> String? {
		switch self {
		case .name(let name): name
		case .reference(let reference): try? lookup?.object(for: reference)?.name(lookup: lookup)
		default: nil
		}
	}

	func isNull(lookup: PdfObjectLookup?) -> Bool {
		switch self {
		case .null: true
		case .reference(let reference): (try? lookup?.object(for: reference)?.isNull(lookup: lookup)) ?? true
		default: false
		}
	}

	func pdfText(lookup: PdfObjectLookup?) -> String? {
		switch self {
		case .string(let string): string.pdfTextToString()
		case .reference(let reference): try? lookup?.object(for: reference)?.pdfText(lookup: lookup)
		default: nil
		}
	}

	func real(lookup: PdfObjectLookup?) -> Double? {
		switch self {
		case .integer(let integer): Double(integer)
		case .real(let real): real
		case .reference(let reference): try? lookup?.object(for: reference)?.real(lookup: lookup)
		default: nil
		}
	}
	
	var reference: PdfObjectIdentifier? {
		switch self {
		case .reference(let objectIdentifier): objectIdentifier
		default: nil
		}
	}

	func stream(lookup: PdfObjectLookup?) -> PdfStream? {
		switch self {
		case .stream(let stream): stream
		case .reference(let reference): try? lookup?.object(for: reference)?.stream(lookup: lookup)
		default: nil
		}
	}
	
	func string(lookup: PdfObjectLookup?) -> Data? {
		switch self {
		case .string(let string): string
		case .reference(let reference): try? lookup?.object(for: reference)?.string(lookup: lookup)
		default: nil
		}
	}
	
	func recursivelyResolve(lookup: PdfObjectLookup?) -> PdfObject? {
		switch self {
		case .array(let elements):
			elements.recursivelyResolve(lookup: lookup).map { .array($0) }
		case .dictionary(let dictionary):
			dictionary.recursivelyResolve(lookup: lookup).map { .dictionary($0) }
		case .reference(let reference):
			reference.recursivelyResolve(lookup: lookup)
		default:
			self
		}
	}
}

extension PdfObjectIdentifier {
	func recursivelyResolve(lookup: PdfObjectLookup?) -> PdfObject? {
		if let resolved = try? lookup?.object(for: self) {
			resolved
		} else {
			nil
		}
	}
}

extension PdfDictionary {
	func recursivelyResolve(lookup: PdfObjectLookup?) -> PdfDictionary? {
		PdfDictionary(uniqueKeysWithValues: compactMap { key, value in
			if key != "Parent", key != "Prev", key != "P" {
				value.recursivelyResolve(lookup: lookup).map { (key, $0) }
			} else {
				(key, value)
			}
		})
	}
}

extension PdfArray {
	func recursivelyResolve(lookup: PdfObjectLookup?) -> PdfArray? {
		PdfArray(compactMap { $0.recursivelyResolve(lookup: lookup) })
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
		case .string(let data): data.pdfTextToString()
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
