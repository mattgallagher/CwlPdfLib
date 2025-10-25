// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfXRefTable: Sendable {
	public let trailer: PdfDictionary
	public var objectLocations: [PdfObjectNumber: Int]

	init(trailerDictionary: PdfDictionary, objectLocations: [PdfObjectNumber: Int] = [:]) {
		self.trailer = trailerDictionary
		self.objectLocations = objectLocations
	}
}

extension PdfXRefTable: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfXRefTable {
		var objects: [PdfObjectNumber: Int] = [:]

		try context.nextToken()
		try context.identifier(equals: .xref, else: .xrefNotFound)
		repeat {
			try context.nextToken()
			if context.identifier(equals: .trailer) {
				// parse trailer dictionary
				let object = try PdfObject.parseNext(context: &context)
				guard case .dictionary(let dictionary) = object else {
					throw PdfParseError(context: context, failure: .expectedDictionary)
				}
				return PdfXRefTable(trailerDictionary: dictionary, objectLocations: objects)
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
					objects[PdfObjectNumber(number: number, generation: generation)] = location
				} else {
					throw PdfParseError(context: context, failure: .unexpectedToken)
				}
			}
		} while true
	}
	
	static func parseXrefTables(source: inout any PdfSource, firstXrefRange: Range<Int>) throws -> ([PdfXRefTable], PdfDictionary, [Int: Int]) {
		var finalObjectCutoff: Int?
		var xrefTables = [PdfXRefTable]()
		var nextRange = firstXrefRange
		repeat {
			let nextTable = try source.parseContext(range: nextRange) { context in
				try PdfXRefTable.parse(context: &context)
			}
			xrefTables.append(nextTable)
			if finalObjectCutoff == nil, !nextTable.objectLocations.isEmpty {
				finalObjectCutoff = nextRange.lowerBound
			}
			guard case .integer(let previousStart) = nextTable.trailer["Prev"] else {
				break
			}
			nextRange = previousStart..<nextRange.startIndex
		} while true
		
		guard let trailerDictionary = xrefTables.first?.trailer else {
			throw PdfParseError(failure: .xrefNotFound, range: firstXrefRange)
		}
		
		var objectEnds = [Int: Int]()
		if let finalObjectCutoff {
			let allObjectRanges = xrefTables.flatMap { $0.objectLocations.values }.sorted()
			for (previous, next) in zip(allObjectRanges, [allObjectRanges.dropFirst(), [finalObjectCutoff]].joined()) {
				objectEnds[previous] = next
			}
		}
		
		return (xrefTables, trailerDictionary, objectEnds)
	}
}
