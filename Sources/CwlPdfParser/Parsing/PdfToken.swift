// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

enum PdfToken {
	case arrayClose
	case arrayOpen
	case closeAngle
	case comment(_ range: Range<Int>)
	case dictionaryClose
	case dictionaryOpen
	case hex(Data, high: UInt8?, name: String?)
	case identifier(_ range: Range<Int>)
	case integer(sign: Int, value: Int)
	case name(string: String, range: Range<Int>)
	case openAngle
	case real(sign: Double, value: Double, fraction: Double)
	case string(bytes: Data, range: Range<Int>)
	case stringEscape(bytes: Data)
	case stringOctal(bytes: Data, byte: UInt8, count: UInt8)
}

extension PdfParseContext {
	mutating func nextToken() throws {
		tokenStart = slice.startIndex
		token = nil
		while let byte = slice.popFirst() {
			switch token {
			case nil:
				switch byte {
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab:
					break
				case .closeBracket:
					token = .arrayClose
					return
				case .openBracket:
					token = .arrayOpen
					return
				case .lessThan:
					token = .closeAngle
				case .lessThan:
					token = .openAngle
				case .percent:
					token = .comment(slice.startIndex..<slice.startIndex)
				case .digit0...(.digit9):
					token = .integer(sign: 1, value: Int(byte - .digit0))
				case .hyphen:
					token = .integer(sign: -1, value: 0)
				case .plus:
					token = .integer(sign: 1, value: 0)
				case .slash:
					token = .name(string: "", range: slice.startIndex..<slice.startIndex)
				case .dot:
					token = .real(sign: 1, value: 0, fraction: 0.1)
				case .openParenthesis:
					token = .string(bytes: Data(), range: slice.startIndex..<slice.startIndex)
				case .closeParenthesis, .openBrace, .closeBrace:
					throw PdfParseError(failure: .unexpectedToken, range: slice.indices)
				default:
					token = .identifier((slice.startIndex - 1)..<(slice.startIndex))
				}
			case .arrayOpen, .arrayClose, .dictionaryOpen, .dictionaryClose:
				fatalError("These tokens are never set as state")
			case .closeAngle:
				switch byte {
				case .greaterThan:
					token = .dictionaryClose
					return
				default:
					throw PdfParseError(failure: .unexpectedToken, range: (slice.startIndex - 1)..<slice.startIndex)
				}
			case .openAngle:
				switch byte {
				case .lessThan:
					token = .dictionaryOpen
					return
				case .greaterThan:
					token = .none
				default:
					guard let nybble = nybbleFromHex(byte) else {
						throw PdfParseError(failure: .invalidHexDigit, range: (slice.startIndex - 1)..<slice.startIndex)
					}
					token = try .hex(Data(), high: nybble, name: nil)
				}
			case .comment(let range):
				switch byte {
				case .carriageReturn, .formFeed, .lineFeed:
					token = .comment(range.lowerBound..<(slice.startIndex - 1))
					return
				default:
					break
				}
			case .hex(var data, let high, let name):
				switch byte {
				case .greaterThan where name == nil:
					if let high {
						data.append(contentsOf: [high])
						token = .string(bytes: data, range: (slice.startIndex - 1)..<(slice.startIndex - 1))
					}
					return
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab:
					if let name {
						if high != nil {
							data.append(contentsOf: [slice.base[slice.startIndex - 1]])
						}
						token = try .name(string: name + data.utf8(), range: slice.startIndex..<slice.startIndex)
						return
					} else {
						break
					}
				default:
					guard let nybble = nybbleFromHex(byte) else {
						if let name {
							if high != nil {
								data.append(contentsOf: [slice.base[slice.startIndex - 1]])
							}
							token = try .name(string: name + data.utf8(), range: slice.startIndex..<slice.startIndex)
							break
						} else {
							throw PdfParseError(failure: .invalidHexDigit, range: (slice.startIndex - 1)..<slice.startIndex)
						}
					}
					if let high {
						data.append(contentsOf: [(high << 4) + nybble])
						token = try .hex(data, high: nil, name: name)
					} else {
						token = try .hex(data, high: nybble, name: name)
					}
				}
			case .identifier(let range):
				switch byte {
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab, .percent, .openParenthesis, .closeParenthesis, .openBracket, .closeBracket, .openBrace, .closeBrace, .slash, .lessThan, .greaterThan, .backslash:
					token = .identifier(range.lowerBound..<(slice.startIndex - 1))
					return
				default:
					break
				}
			case .integer(let sign, let value):
				switch byte {
				case .dot:
					token = .real(sign: Double(sign), value: Double(value), fraction: 0.1)
				case .digit0...(.digit9):
					token = .integer(sign: sign, value: value * 10 + Int(byte - .digit0))
				default:
					return
				}
			case .name(let string, let range):
				switch byte {
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab, .percent, .openParenthesis, .closeParenthesis, .openBracket, .closeBracket, .openBrace, .closeBrace, .slash, .lessThan, .greaterThan, .backslash:
					token = .name(string: string, range: range.lowerBound..<(slice.startIndex - 1))
					return
				case .hash:
					token = .hex(Data(), high: nil, name: slice.base[range.lowerBound..<(slice.startIndex - 1)].pdfText())
				default:
					break
				}
			case .real(let sign, let value, let fraction):
				switch byte {
				case .digit0...(.digit9):
					token = .real(sign: sign, value: value + fraction * Double(byte - .digit0), fraction: fraction * 0.1)
				default:
					return
				}
			case .string(let bytes, let range):
				switch byte {
				case .closeParenthesis:
					token = .string(bytes: bytes, range: range.lowerBound..<(slice.startIndex - 1))
					return
				case .backslash:
					token = .stringEscape(bytes: Data(slice.base[range.lowerBound..<(slice.startIndex - 1)]))
				default:
					break
				}
			case .stringEscape(let bytes):
				switch byte {
				case .carriageReturn, .lineFeed:
					token = .string(bytes: bytes, range: slice.startIndex..<(slice.startIndex))
				case .openParenthesis:
					token = .string(bytes: bytes + [.openParenthesis], range: slice.startIndex..<(slice.startIndex))
				case .closeParenthesis:
					token = .string(bytes: bytes + [.closeParenthesis], range: slice.startIndex..<(slice.startIndex))
				case .digit0...(.digit7):
					token = .stringOctal(bytes: bytes, byte: byte - .digit0, count: 1)
				case .b:
					token = .string(bytes: bytes + [.backspace], range: slice.startIndex..<(slice.startIndex))
				case .backslash:
					token = .string(bytes: bytes + [.backslash], range: slice.startIndex..<(slice.startIndex))
				case .f:
					token = .string(bytes: bytes + [.formFeed], range: slice.startIndex..<(slice.startIndex))
				case .n:
					token = .string(bytes: bytes + [.lineFeed], range: slice.startIndex..<(slice.startIndex))
				case .r:
					token = .string(bytes: bytes + [.carriageReturn], range: slice.startIndex..<(slice.startIndex))
				case .t:
					token = .string(bytes: bytes + [.tab], range: slice.startIndex..<(slice.startIndex))
				default:
					token = .string(bytes: bytes, range: slice.startIndex..<(slice.startIndex))
				}
			case .stringOctal(let bytes, let previous, let count):
				switch byte {
				case .digit0...(.digit7) where count == 2:
					token = .string(bytes: bytes + [(previous << 3) + (byte - .digit0)], range: slice.startIndex..<(slice.startIndex))
				case .digit0...(.digit7):
					token = .stringOctal(bytes: bytes, byte: (previous << 3) + (byte - .digit0), count: count + 1)
				default:
					slice = slice[reslice: (slice.startIndex - 1)..<slice.endIndex]
					token = .string(bytes: bytes + [previous], range: slice.startIndex..<(slice.startIndex))
				}
			}
		}
	}
}

func nybbleFromHex(_ byte: UInt8) -> UInt8? {
	switch byte {
	case .a...(.f):
		return (byte - .a) + 10
	case .A...(.F):
		return (byte - .A) + 10
	case .digit0...(.digit9):
		return byte - .digit0
	default:
		return nil
	}
}
