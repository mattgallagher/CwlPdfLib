// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfXRefTable: Sendable {
	public let trailer: PdfDictionary
	public var objectLocations: [PdfObjNum: Int]

	init(trailer: PdfDictionary, objectLocations: [PdfObjNum: Int] = [:]) {
		self.trailer = trailer
		self.objectLocations = objectLocations
	}
}

extension PdfXRefTable: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfXRefTable {
		var objects: [PdfObjNum: Int] = [:]

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
				return PdfXRefTable(trailer: dictionary, objectLocations: objects)
			}
			
			let firstNumber = try context.naturalNumber()
			try context.nextToken()
			let fieldCount = try context.naturalNumber()
			for number in firstNumber..<(firstNumber + fieldCount) {
				try context.nextToken()
				let location = try context.naturalNumber()
				try context.nextToken()
				let generation = try context.naturalNumber()
				try context.nextToken()
				if context.identifier(equals: .f) || location == 0 {
					continue
				} else if context.identifier(equals: .n) {
					objects[PdfObjNum(number: number, generation: generation)] = location
				} else {
					throw PdfParseError(context: context, failure: .unexpectedToken)
				}
			}
		} while true
	}
}
