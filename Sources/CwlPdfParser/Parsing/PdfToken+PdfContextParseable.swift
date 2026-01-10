// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfToken: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfToken {
		guard let token = try parseNext(context: &context) else {
			throw PdfParseError(context: context, failure: .expectedToken)
		}
		return token
	}
	
	static func parseNext(context: inout PdfParseContext) throws -> PdfToken? {
		context.tokenStart = context.slice.startIndex
		var token: PdfToken?
		while let byte = context.slice.popFirst() {
			switch token {
			case nil:
				switch byte {
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab:
					break
				case .closeBracket:
					token = .arrayClose
					return token
				case .openBracket:
					token = .arrayOpen
					return token
				case .greaterThan:
					token = .closeAngle
				case .lessThan:
					token = .openAngle
				case .percent:
					token = .comment(context.slice.startIndex..<context.slice.startIndex)
				case .digit0...(.digit9):
					token = .integer(sign: 1, value: Int(byte - .digit0))
				case .hyphen:
					token = .integer(sign: -1, value: 0)
				case .plus:
					token = .integer(sign: 1, value: 0)
				case .slash:
					token = .name(string: "", range: context.slice.startIndex..<context.slice.startIndex)
				case .dot:
					token = .real(sign: 1, value: 0, fraction: 0.1)
				case .openParenthesis:
					token = .string(bytes: Data(), range: context.slice.startIndex..<context.slice.startIndex)
				case .closeParenthesis, .openBrace, .closeBrace:
					throw PdfParseError(failure: .unexpectedToken, range: context.slice.indices)
				default:
					token = .identifier((context.slice.startIndex - 1)..<(context.slice.startIndex))
				}
			case .arrayOpen, .arrayClose, .dictionaryOpen, .dictionaryClose:
				fatalError("These tokens are never set as state")
			case .closeAngle:
				switch byte {
				case .greaterThan:
					token = .dictionaryClose
					return token
				default:
					throw PdfParseError(failure: .unexpectedToken, range: (context.slice.startIndex - 1)..<context.slice.startIndex)
				}
			case .openAngle:
				switch byte {
				case .lessThan:
					token = .dictionaryOpen
					return token
				case .greaterThan:
					token = .none
				default:
					guard let nybble = nybbleFromHex(byte) else {
						throw PdfParseError(failure: .invalidHexDigit, range: (context.slice.startIndex - 1)..<context.slice.startIndex)
					}
					token = try .hex(Data(), high: nybble, name: nil)
				}
			case .comment(let range):
				switch byte {
				case .carriageReturn, .formFeed, .lineFeed:
					token = .comment(range.lowerBound..<context.slice.startIndex)
					if context.skipComments {
						break
					}
					return token
				default:
					token = .comment(range.lowerBound..<context.slice.startIndex)
				}
			case .hex(var data, let high, let name):
				switch byte {
				case .greaterThan where name == nil:
					if let high {
						data.append(contentsOf: [high])
						token = .string(bytes: data, range: (context.slice.startIndex - 1)..<(context.slice.startIndex - 1))
					}
					return token
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab:
					if let name {
						if high != nil {
							data.append(contentsOf: context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.startIndex])
						}
						token = try .name(string: name + data.utf8(), range: context.slice.startIndex..<context.slice.startIndex)
						context.slice = context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.endIndex]
						return token
					} else {
						break
					}
				default:
					guard let nybble = nybbleFromHex(byte) else {
						if let name {
							if high != nil {
								data.append(contentsOf: context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.startIndex])
							}
							token = try .name(string: name + data.utf8(), range: context.slice.startIndex..<context.slice.startIndex)
							break
						} else {
							throw PdfParseError(failure: .invalidHexDigit, range: (context.slice.startIndex - 1)..<context.slice.startIndex)
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
					token = .identifier(range.lowerBound..<(context.slice.startIndex - 1))
					context.slice = context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.endIndex]
					return token
				default:
					token = .identifier(range.lowerBound..<context.slice.startIndex)
				}
			case .integer(let sign, let value):
				switch byte {
				case .dot:
					token = .real(sign: Double(sign), value: Double(value), fraction: 0.1)
				case .digit0...(.digit9):
					token = .integer(sign: sign, value: value * 10 + Int(byte - .digit0))
				default:
					context.slice = context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.endIndex]
					return token
				}
			case .name(let string, let range):
				switch byte {
				case .nul, .space, .carriageReturn, .formFeed, .lineFeed, .tab, .percent, .openParenthesis, .closeParenthesis, .openBracket, .closeBracket, .openBrace, .closeBrace, .slash, .lessThan, .greaterThan, .backslash:
					token = .name(string: string, range: range.lowerBound..<(context.slice.startIndex - 1))
					context.slice = context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.endIndex]
					return token
				case .hash:
					token = .hex(Data(), high: nil, name: context.slice[reslice: range.lowerBound..<(context.slice.startIndex - 1)].pdfTextToString())
				default:
					token = .name(string: string, range: range.lowerBound..<context.slice.startIndex)
				}
			case .real(let sign, let value, let fraction):
				switch byte {
				case .digit0...(.digit9):
					token = .real(sign: sign, value: value + fraction * Double(byte - .digit0), fraction: fraction * 0.1)
				default:
					context.slice = context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.endIndex]
					return token
				}
			case .string(let bytes, let range):
				switch byte {
				case .closeParenthesis:
					token = .string(bytes: bytes, range: range.lowerBound..<(context.slice.startIndex - 1))
					return token
				case .backslash:
					token = .stringEscape(bytes: bytes + Data(context.slice[reslice: range.lowerBound..<(context.slice.startIndex - 1)]))
				default:
					token = .string(bytes: bytes, range: range.lowerBound..<context.slice.startIndex)
				}
			case .stringEscape(let bytes):
				switch byte {
				case .carriageReturn, .lineFeed:
					token = .string(bytes: bytes, range: context.slice.startIndex..<(context.slice.startIndex))
				case .openParenthesis:
					token = .string(bytes: bytes + [.openParenthesis], range: context.slice.startIndex..<(context.slice.startIndex))
				case .closeParenthesis:
					token = .string(bytes: bytes + [.closeParenthesis], range: context.slice.startIndex..<(context.slice.startIndex))
				case .digit0...(.digit7):
					token = .stringOctal(bytes: bytes, byte: byte - .digit0, count: 1)
				case .b:
					token = .string(bytes: bytes + [.backspace], range: context.slice.startIndex..<(context.slice.startIndex))
				case .backslash:
					token = .string(bytes: bytes + [.backslash], range: context.slice.startIndex..<(context.slice.startIndex))
				case .f:
					token = .string(bytes: bytes + [.formFeed], range: context.slice.startIndex..<(context.slice.startIndex))
				case .n:
					token = .string(bytes: bytes + [.lineFeed], range: context.slice.startIndex..<(context.slice.startIndex))
				case .r:
					token = .string(bytes: bytes + [.carriageReturn], range: context.slice.startIndex..<(context.slice.startIndex))
				case .t:
					token = .string(bytes: bytes + [.tab], range: context.slice.startIndex..<(context.slice.startIndex))
				default:
					token = .string(bytes: bytes, range: context.slice.startIndex..<(context.slice.startIndex))
				}
			case .stringOctal(let bytes, let previous, let count):
				switch byte {
				case .digit0...(.digit7) where count == 2:
					token = .string(bytes: bytes + [(previous << 3) + (byte - .digit0)], range: context.slice.startIndex..<(context.slice.startIndex))
				case .digit0...(.digit7):
					token = .stringOctal(bytes: bytes, byte: (previous << 3) + (byte - .digit0), count: count + 1)
				default:
					context.slice = context.slice[reslice: (context.slice.startIndex - 1)..<context.slice.endIndex]
					token = .string(bytes: bytes + [previous], range: context.slice.startIndex..<(context.slice.startIndex))
				}
			}
		}
		if context.slice.isEmpty, context.errorIfEndOfRange {
			throw PdfParseError(failure: .endOfRange, range: context.slice.startIndex..<context.slice.endIndex)
		}
		return token
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
