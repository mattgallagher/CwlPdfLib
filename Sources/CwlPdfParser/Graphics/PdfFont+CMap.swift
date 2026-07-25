// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfFont {
	static func parseCMap(
		_ encodingObject: PdfObject,
		_ lookup: PdfObjectLookup?
	) throws -> CMap {
		if let name = encodingObject.name(lookup: lookup) {
			switch name {
			case .`Identity-H`:
				return CMap(
					name: name,
					writingMode: .horizontal,
					codeSpaceRanges: [CodeSpaceRange(bound: 0x0000...0xFFFF, byteLength: 2)],
					mappings: []
				)
			case .`Identity-V`:
				return CMap(
					name: name,
					writingMode: .vertical,
					codeSpaceRanges: [CodeSpaceRange(bound: 0x0000...0xFFFF, byteLength: 2)],
					mappings: []
				)
			default:
				throw PdfParseError(failure: .unsupportedFontSubtype)
			}
		}

		guard let stream = encodingObject.stream(lookup: lookup) else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}

		let (writingMode, codeSpaceRanges, mappings) = try stream.data.parseContext(
			intent: .encodingCMap(streamObject: stream.objectIdentifier)
		) { context in
			var writingMode = WritingMode.horizontal
			var codeSpaceRanges = [CodeSpaceRange]()
			var mappings = [CMapMapping]()

			while let token = try PdfObject.parseNext(context: &context) {
				switch token {
				case .identifier(.WMode):
					if let mode = try PdfObject.parseNext(context: &context)?.integer(lookup: nil), mode == 1 {
						writingMode = .vertical
					}
				case .identifier(.begincodespacerange):
					try Self.parseCodeSpaceRanges(context: &context, into: &codeSpaceRanges)
				case .identifier(.begincidchar):
					try Self.parseCIDCharMappings(context: &context, into: &mappings)
				case .identifier(.begincidrange):
					try Self.parseCIDRangeMappings(context: &context, into: &mappings)
				default:
					continue
				}
			}

			return (writingMode, codeSpaceRanges, mappings)
		}

		return CMap(
			name: nil,
			writingMode: writingMode,
			codeSpaceRanges: codeSpaceRanges,
			mappings: mappings
		)
	}

	static func parseToUnicodeCMap(
		_ object: PdfObject,
		_ lookup: PdfObjectLookup?
	) throws -> ToUnicodeCMap? {
		guard let stream = object.stream(lookup: lookup) else {
			return nil
		}

		let (codeSpaceRanges, mappings) = try stream.data.parseContext(
			intent: .toUnicodeCMap(streamObject: stream.objectIdentifier)
		) { context in
			var codeSpaceRanges = [CodeSpaceRange]()
			var mappings = [UnicodeMapping]()

			while let token = try PdfObject.parseNext(context: &context) {
				switch token {
				case .identifier(.begincodespacerange):
					try Self.parseCodeSpaceRanges(context: &context, into: &codeSpaceRanges)
				case .identifier(.beginbfchar):
					try Self.parseBFCharMappings(context: &context, into: &mappings)
				case .identifier(.beginbfrange):
					try Self.parseBFRangeMappings(context: &context, into: &mappings)
				default:
					continue
				}
			}

			return (codeSpaceRanges, mappings)
		}

		return ToUnicodeCMap(
			codeSpaceRanges: codeSpaceRanges,
			mappings: mappings
		)
	}

	static func decodeUnicodeScalars(_ data: Data) -> [UnicodeScalar] {
		guard data.count >= 2, data.count % 2 == 0 else {
			return []
		}

		var scalars: [UnicodeScalar] = []
		scalars.reserveCapacity(data.count / 2)

		var index = data.startIndex
		while index < data.endIndex {
			let hi = UInt16(data[index]) << 8
			let lo = UInt16(data[index + 1])
			let value = hi | lo
			index += 2

			if let scalar = UnicodeScalar(value) {
				scalars.append(scalar)
			}
		}

		return scalars
	}
}

private extension PdfFont {
	static func parseCodeSpaceRanges(
		context: inout PdfParseContext,
		into codeSpaceRanges: inout [CodeSpaceRange]
	) throws {
		while let token = try PdfObject.parseNext(context: &context) {
			if token.identifier == .endcodespacerange {
				break
			}

			guard
				let lowData = token.string(lookup: nil),
				let highData = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
			else {
				throw PdfParseError(failure: .unsupportedCMap)
			}

			codeSpaceRanges.append(
				CodeSpaceRange(
					bound: lowData.asBigEndianUInt32...highData.asBigEndianUInt32,
					byteLength: lowData.count
				)
			)
		}
	}

	static func parseCIDCharMappings(
		context: inout PdfParseContext,
		into mappings: inout [CMapMapping]
	) throws {
		while let token = try PdfObject.parseNext(context: &context) {
			if token.identifier == .endcidchar {
				break
			}

			guard
				let code = token.string(lookup: nil),
				let cid = try PdfObject.parseNext(context: &context)?.integer(lookup: nil)
			else {
				throw PdfParseError(failure: .unsupportedCMap)
			}

			mappings.append(.single(code: code.asBigEndianUInt32, cid: UInt32(cid)))
		}
	}

	static func parseCIDRangeMappings(
		context: inout PdfParseContext,
		into mappings: inout [CMapMapping]
	) throws {
		while let token = try PdfObject.parseNext(context: &context) {
			if token.identifier == .endcidrange {
				break
			}

			guard
				let startCode = token.string(lookup: nil),
				let endCode = try PdfObject.parseNext(context: &context)?.string(lookup: nil),
				let startCID = try PdfObject.parseNext(context: &context)?.integer(lookup: nil)
			else {
				throw PdfParseError(failure: .unsupportedCMap)
			}

			mappings.append(
				.range(startCode.asBigEndianUInt32...endCode.asBigEndianUInt32, startCID: UInt32(startCID))
			)
		}
	}

	static func parseBFCharMappings(
		context: inout PdfParseContext,
		into mappings: inout [UnicodeMapping]
	) throws {
		while true {
			let peek = try PdfObject.parseNext(context: &context)
			if peek?.identifier == .endbfchar {
				break
			}

			guard
				let codeData = peek?.string(lookup: nil),
				let unicodeData = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
			else {
				throw PdfParseError(failure: .unsupportedCMap)
			}

			mappings.append(
				.single(code: codeData.asBigEndianUInt32, scalars: Self.decodeUnicodeScalars(unicodeData))
			)
		}
	}

	static func parseBFRangeMappings(
		context: inout PdfParseContext,
		into mappings: inout [UnicodeMapping]
	) throws {
		while true {
			let peek = try PdfObject.parseNext(context: &context)
			if peek?.identifier == .endbfrange {
				break
			}

			guard
				let startCodeData = peek?.string(lookup: nil),
				let endCodeData = try PdfObject.parseNext(context: &context)?.string(lookup: nil)
			else {
				throw PdfParseError(failure: .unsupportedCMap)
			}

			let startCode = startCodeData.asBigEndianUInt32
			let endCode = endCodeData.asBigEndianUInt32
			let third = try PdfObject.parseNext(context: &context)

			if let value = third?.string(lookup: nil)?.asBigEndianUInt32, let scalar = UnicodeScalar(value) {
				mappings.append(.range(startCode...endCode, startScalar: scalar))
			} else if case .array(let array)? = third {
				var code = startCode
				for entry in array {
					guard let data = entry.string(lookup: nil) else {
						continue
					}

					mappings.append(.single(code: code, scalars: Self.decodeUnicodeScalars(data)))
					code += 1
				}
			}
		}
	}
}
