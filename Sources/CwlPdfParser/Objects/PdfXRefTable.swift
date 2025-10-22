// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfXRefTable: Sendable {
	public let trailer: PdfDictionary
	public let objectRanges: [PdfObjNum: Range<Int>]

	init(trailer: PdfDictionary, objectRanges: [PdfObjNum: Range<Int>] = [:]) {
		self.trailer = trailer
		self.objectRanges = objectRanges
	}
}

extension PdfXRefTable: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfXRefTable {
		var objects: [PdfObjNum: Range<Int>] = [:]

		try context.nextToken()
		try context.identifier(equals: .xref, else: .xrefNotFound)
		repeat {
			try context.nextToken()
			if context.identifier(equals: .trailer) {
				// parse trailer dictionary
				let object = try PdfObject.parseIfNext(context: &context)
				guard case .dictionary(let dictionary) = object else {
					throw PdfParseError(context: context, failure: .expectedDictionary)
				}
				return PdfXRefTable(trailer: dictionary, objectRanges: objects)
			}
			
			let firstNumber = try context.naturalNumber()
			try context.nextToken()
			let fieldCount = try context.naturalNumber()
			for number in firstNumber..<fieldCount {
				try context.nextToken()
				let location = try context.naturalNumber()
				try context.nextToken()
				let generation = try context.naturalNumber()
				try context.nextToken()
				if context.identifier(equals: .f) {
					break
				} else if context.identifier(equals: .n) {
					let objNum = PdfObjNum(number: number, generation: generation)
					if objects[objNum] == nil {
						objects[objNum] = location..<location
					}
				} else {
					throw PdfParseError(context: context, failure: .unexpectedToken)
				}
			}
		} while true
	}
}
