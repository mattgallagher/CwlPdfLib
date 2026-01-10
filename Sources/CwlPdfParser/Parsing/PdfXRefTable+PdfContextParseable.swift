// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

extension PdfXRefTable: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfXRefTable {
		var locations: [PdfObjectIdentifier: Int] = [:]

		try PdfToken
			.parse(context: &context)
			.requireIdentifier(context: &context, equals: .xref, else: .xrefNotFound)

		repeat {
			let token = try PdfToken.parse(context: &context)
			
			if token.isIdentifier(context: context, equals: .trailer) {
				guard let dictionary = try PdfObject.parse(context: &context).dictionary(lookup: nil) else {
					throw PdfParseError(context: context, failure: .expectedDictionary)
				}
				return PdfXRefTable(trailerDictionary: dictionary, objectLocations: locations)
			}
			
			let firstNumber = try token.requireNaturalNumber(context: &context)
			let fieldCount = try PdfToken
				.parse(context: &context)
				.requireNaturalNumber(context: &context)
			
			for number in firstNumber..<(firstNumber + fieldCount) {
				let location = try PdfToken
					.parse(context: &context)
					.requireNaturalNumber(context: &context)
				
				let generation = try PdfToken
					.parse(context: &context)
					.requireNaturalNumber(context: &context)
				
				let token = try PdfToken.parse(context: &context)
				if token.isIdentifier(context: context, equals: .f) || location == 0 {
					continue
				} else if token.isIdentifier(context: context, equals: .n) {
					locations[PdfObjectIdentifier(number: number, generation: generation)] = location
				} else {
					throw PdfParseError(context: context, failure: .unexpectedToken)
				}
			}
		} while true
	}
	
	static func parseXrefTables(source: any PdfSource, firstXrefRange: Range<Int>, initialXrefTableLimit: Int = 16384) throws -> ([PdfXRefTable], PdfDictionary, [Int: PdfObjectLayout]) {
		var xrefTables = [PdfXRefTable]()
		var nextRange = firstXrefRange
		var revisions = [PdfObjectIdentifier: Int]()
		
		repeat {
			if nextRange.count > initialXrefTableLimit {
				nextRange = nextRange.lowerBound..<nextRange.lowerBound + initialXrefTableLimit
			}
			
			let nextTable: PdfXRefTable
			repeat {
				do {
					nextTable = try source.parseContext(range: nextRange) { context in
						context.errorIfEndOfRange = true
						return try PdfXRefTable.parse(context: &context)
					}
					break
				} catch let error as PdfParseError where error.failure == .endOfRange {
					if nextRange.upperBound == firstXrefRange.endIndex {
						throw PdfParseError(failure: .xrefNotFound)
					}
					nextRange = nextRange.lowerBound..<min(
						nextRange.lowerBound + nextRange.count * 4,
						firstXrefRange.endIndex
					)
					continue
				}
			} while true 
			
			xrefTables.append(nextTable)
			guard case .integer(let previousStart) = nextTable.trailer[.Prev] else {
				break
			}
			
			if previousStart > nextRange.startIndex {
				nextRange = previousStart..<firstXrefRange.endIndex
			} else {
				nextRange = previousStart..<nextRange.startIndex
			}
		} while true
		
		guard let trailerDictionary = xrefTables.first?.trailer else {
			throw PdfParseError(failure: .xrefNotFound, range: firstXrefRange)
		}
		
		var objectRanges = [Int: PdfObjectLayout]()
		let allObjectByteRanges = xrefTables.flatMap { $0.objectLocations }.sorted { $0.value < $1.value }
		for (previous, next) in zip(allObjectByteRanges, [allObjectByteRanges.dropFirst(), [(PdfObjectIdentifier(number: 0, generation: 0), firstXrefRange.upperBound)]].joined()) {
			let revision = revisions[previous.key].map { $0 + 1 } ?? 0
			objectRanges[previous.value] = PdfObjectLayout(objectIdentifier: previous.key, range: previous.value..<next.value, revision: revision)
			revisions[previous.key] = revision
		}
		
		return (xrefTables, trailerDictionary, objectRanges)
	}
}
