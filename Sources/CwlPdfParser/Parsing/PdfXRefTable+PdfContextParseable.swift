// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension PdfXRefTable: PdfContextParseable {
	static func parse(context: inout PdfParseContext) throws -> PdfXRefTable {
		var locations: [PdfObjectIdentifier: Int] = [:]

		// Expect the "xref" keyword at the start of a classic xref table.
		try PdfToken
			.parse(context: &context)
			.requireIdentifier(context: &context, equals: .xref, else: .xrefNotFound)

		repeat {
			// Read either the next subsection header or the "trailer" keyword.
			let token = try PdfToken.parse(context: &context)
			
			if token.isIdentifier(context: context, equals: .trailer) {
				// Trailer dictionary follows the xref sections.
				guard let dictionary = try PdfObject.parse(context: &context).dictionary(lookup: nil) else {
					throw PdfParseError(context: context, failure: .expectedDictionary)
				}
				return PdfXRefTable(trailerDictionary: dictionary, objectLocations: locations)
			}
			
			// Subsection header: first object number and count of entries.
			let firstNumber = try token.requireNaturalNumber(context: &context)
			let fieldCount = try PdfToken
				.parse(context: &context)
				.requireNaturalNumber(context: &context)
			
			// Parse each fixed-width entry in the subsection.
			for number in firstNumber..<(firstNumber + fieldCount) {
				let location = try PdfToken
					.parse(context: &context)
					.requireNaturalNumber(context: &context)
				
				let generation = try PdfToken
					.parse(context: &context)
					.requireNaturalNumber(context: &context)
				
				// Final flag: "n" for in-use, "f" for free.
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
	
	static func parseXrefTables(
		source: any PdfSource,
		firstXrefRange: Range<Int>,
		initialXrefTableLimit: Int = 16384
	) throws -> ([PdfXRefTable], PdfDictionary, [Int: PdfObjectLayout], [PdfObjectIdentifier: PdfObjectLayout]) {
		var xrefTables = [PdfXRefTable]()
		var nextRange = firstXrefRange
		var parsedOffsets = Set<Int>()
		var revisionCounts = [PdfObjectIdentifier: Int]()
		var uncompressedEntries: [(offset: Int, objectIdentifier: PdfObjectIdentifier, revision: Int)] = []
		var objectStreamLayouts: [PdfObjectIdentifier: PdfObjectLayout] = [:]
		
		// Collect object locations and track the revision number per object.
		func recordEntries(from table: PdfXRefTable) {
			for (objectIdentifier, offset) in table.objectLocations {
				let revision = revisionCounts[objectIdentifier, default: 0]
				revisionCounts[objectIdentifier] = revision + 1
				uncompressedEntries.append((offset: offset, objectIdentifier: objectIdentifier, revision: revision))
			}
			for (objectIdentifier, streamLocation) in table.objectStreamLocations {
				let revision = revisionCounts[objectIdentifier, default: 0]
				revisionCounts[objectIdentifier] = revision + 1
				if objectStreamLayouts[objectIdentifier] == nil {
					objectStreamLayouts[objectIdentifier] = PdfObjectLayout(
						objectIdentifier: objectIdentifier,
						storage: .objectStream(
							stream: streamLocation.objectStream,
							index: streamLocation.index
						),
						revision: revision
					)
				}
			}
		}
		
		// Walk the xref chain, including any incremental updates.
		repeat {
			// Stop if this xref offset has already been parsed.
			if parsedOffsets.contains(nextRange.lowerBound) {
				break
			}
			parsedOffsets.insert(nextRange.lowerBound)
			
			// Parse either a classic xref table or an xref stream at this offset.
			let nextTable = try parseXrefSection(
				source: source,
				range: nextRange,
				initialXrefTableLimit: initialXrefTableLimit,
				upperBound: firstXrefRange.endIndex
			)
			xrefTables.append(nextTable)
			recordEntries(from: nextTable)
			
			// If the trailer points to an XRefStm, parse that too (PDF 1.5+).
			if let xrefStreamOffset = nextTable.trailer[.XRefStm]?.integer(lookup: nil), !parsedOffsets.contains(xrefStreamOffset) {
				if xrefStreamOffset < nextRange.upperBound {
					parsedOffsets.insert(xrefStreamOffset)
					let streamRange = xrefStreamOffset..<nextRange.upperBound
					let streamTable = try parseXrefSection(
						source: source,
						range: streamRange,
						initialXrefTableLimit: initialXrefTableLimit,
						upperBound: nextRange.upperBound
					)
					xrefTables.append(streamTable)
					recordEntries(from: streamTable)
				}
			}
			
			// Follow the Prev chain to earlier xref sections.
			guard let previousStart = nextTable.trailer[.Prev]?.integer(lookup: nil) else {
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
		
		// Build contiguous ranges for uncompressed objects from sorted offsets.
		var objectRanges = [Int: PdfObjectLayout]()
		let sortedEntries = uncompressedEntries.sorted { $0.offset < $1.offset }
		for index in sortedEntries.indices {
			let entry = sortedEntries[index]
			let nextOffset = index + 1 < sortedEntries.count ? sortedEntries[index + 1].offset : firstXrefRange.upperBound
			objectRanges[entry.offset] = PdfObjectLayout(
				objectIdentifier: entry.objectIdentifier,
				storage: .uncompressed(range: entry.offset..<nextOffset),
				revision: entry.revision
			)
		}
		
		return (xrefTables, trailerDictionary, objectRanges, objectStreamLayouts)
	}

    static func parseWithoutXref(
        source: any PdfSource
    ) throws -> ([PdfXRefTable], PdfDictionary, [Int: PdfObjectLayout], [PdfObjectIdentifier: PdfObjectLayout]) {
        let scanResult = try scanForObjectsAndTrailer(source: source)
        let objectRanges = buildObjectRanges(
            objectLocations: scanResult.objectLocations,
            upperBound: source.length
        )
        var trailer = scanResult.trailer ?? [:]
        if trailer[.Size] == nil {
            let maxObjectNumber = scanResult.objectLocations.keys.map(\.number).max() ?? 0
            trailer[.Size] = .integer(maxObjectNumber + 1)
        }
        if trailer[.Root] == nil {
            if let catalogId = try findCatalogObjectId(
                source: source,
                objectRanges: objectRanges
            ) {
                trailer[.Root] = .reference(catalogId)
            }
        }
        let xrefTable = PdfXRefTable(
            trailerDictionary: trailer,
            objectLocations: scanResult.objectLocations
        )
        return ([xrefTable], trailer, objectRanges, [:])
    }
}

private extension PdfXRefTable {
    struct ScanResult: Sendable {
        let objectLocations: [PdfObjectIdentifier: Int]
        let trailer: PdfDictionary?
    }

    static func scanForObjectsAndTrailer(source: any PdfSource) throws -> ScanResult {
        try source.bytes(in: 0..<source.length) { buffer in
            var context = PdfParseContext(
                slice: buffer
            )
            var objectLocations: [PdfObjectIdentifier: Int] = [:]
            var trailer: PdfDictionary?

            while let token = try PdfToken.parseNext(context: &context) {
                if token.isIdentifier(context: context, equals: .trailer) {
                    if let dictionary = try PdfObject.parse(context: &context).dictionary(lookup: nil) {
                        trailer = dictionary
                    }
                    continue
                }

                if token.isIdentifier(context: context, equals: .stream) {
                    try skipStreamData(context: &context)
                    continue
                }

                if case .integer = token, let tokenStart = context.tokenStart {
                    var probeContext = context
                    probeContext.slice = context.slice[reslice: tokenStart..<context.slice.endIndex]
                    do {
                        let number = try PdfToken
                            .parse(context: &probeContext)
                            .requireNaturalNumber(context: &probeContext)
                        let generation = try PdfToken
                            .parse(context: &probeContext)
                            .requireNaturalNumber(context: &probeContext)
                        let objToken = try PdfToken.parse(context: &probeContext)
                        guard objToken.isIdentifier(context: probeContext, equals: .obj) else {
                            continue
                        }
                        let objectIdentifier = PdfObjectIdentifier(number: number, generation: generation)
                        objectLocations[objectIdentifier] = tokenStart
                        context = probeContext
                    } catch {
                        continue
                    }
                }
            }

            return ScanResult(objectLocations: objectLocations, trailer: trailer)
        }
    }

    static func buildObjectRanges(
        objectLocations: [PdfObjectIdentifier: Int],
        upperBound: Int
    ) -> [Int: PdfObjectLayout] {
        let sortedEntries = objectLocations
            .map { (offset: $0.value, objectIdentifier: $0.key) }
            .sorted { $0.offset < $1.offset }
        var objectRanges: [Int: PdfObjectLayout] = [:]
        for index in sortedEntries.indices {
            let entry = sortedEntries[index]
            let nextOffset = index + 1 < sortedEntries.count
                ? sortedEntries[index + 1].offset
                : upperBound
            objectRanges[entry.offset] = PdfObjectLayout(
                objectIdentifier: entry.objectIdentifier,
                storage: .uncompressed(range: entry.offset..<nextOffset),
                revision: 0
            )
        }
        return objectRanges
    }

    static func findCatalogObjectId(
        source: any PdfSource,
        objectRanges: [Int: PdfObjectLayout]
    ) throws -> PdfObjectIdentifier? {
        let sortedLayouts = objectRanges
            .values
            .sorted { ($0.range?.lowerBound ?? 0) < ($1.range?.lowerBound ?? 0) }
        for layout in sortedLayouts {
            guard let range = layout.range else { continue }
            do {
                let object = try source.parseContext(range: range) { context in
                    context.objectIdentifier = layout.objectIdentifier
                    return try PdfObject.parseIndirect(lookup: nil, context: &context)
                }
                if
                    let dictionary = object.dictionary(lookup: nil),
                    dictionary[.Type]?.name(lookup: nil) == .Catalog
                {
                    return layout.objectIdentifier
                }
            } catch {
                continue
            }
        }
        return nil
    }

    static func skipStreamData(context: inout PdfParseContext) throws {
        try context.readEndOfLine()
        let pattern = Array(PdfParseIdentifier.endstream.rawValue.utf8)
        var index = context.slice.startIndex
        let lastStart = context.slice.endIndex - pattern.count
        if lastStart < index {
            throw PdfParseError(failure: .objectEndedUnexpectedly, range: context.slice.indices)
        }
        while index <= lastStart {
            if context.slice[index] == pattern[0] {
                var matched = true
                for offset in 1..<pattern.count {
                    if context.slice[index + offset] != pattern[offset] {
                        matched = false
                        break
                    }
                }
                if matched {
                    let after = index + pattern.count
                    context.slice = context.slice[reslice: after..<context.slice.endIndex]
                    return
                }
            }
            index += 1
        }
        throw PdfParseError(failure: .objectEndedUnexpectedly, range: context.slice.indices)
    }

	static func parseXrefSection(
		source: any PdfSource,
		range: Range<Int>,
		initialXrefTableLimit: Int,
		upperBound: Int
	) throws -> PdfXRefTable {
		var nextRange = range
		// Probe a limited range first to avoid scanning too much data.
		if nextRange.count > initialXrefTableLimit {
			nextRange = nextRange.lowerBound..<nextRange.lowerBound + initialXrefTableLimit
		}
		
		repeat {
			do {
				// Parse either a classic "xref" table or an xref stream.
				return try source.parseContext(range: nextRange) { context in
					context.errorIfEndOfRange = true
					var probeContext = context
					if let token = try PdfToken.parseNext(context: &probeContext), token.isIdentifier(context: probeContext, equals: .xref) {
						return try PdfXRefTable.parse(context: &context)
					}
					return try PdfXRefTable.parseXrefStream(context: &context)
				}
			} catch let error as PdfParseError where error.failure == .endOfRange {
				// Grow the probe window until we hit upperBound or find an xref section.
				if nextRange.upperBound == upperBound {
					throw PdfParseError(failure: .xrefNotFound)
				}
				nextRange = nextRange.lowerBound..<min(
					nextRange.lowerBound + nextRange.count * 4,
					upperBound
				)
				continue
			}
		} while true
	}
	
	static func parseXrefStream(context: inout PdfParseContext) throws -> PdfXRefTable {
		// Xref streams are indirect objects whose payload is a stream with Type == XRef.
		let (_, object) = try PdfObject.parseIndirectObject(lookup: nil, context: &context)
		guard case .stream(let stream) = object else {
			throw PdfParseError(context: context, failure: .expectedDictionary)
		}
		guard stream.dictionary[.Type]?.name(lookup: nil) == .XRef else {
			throw PdfParseError(context: context, failure: .expectedType)
		}
		let (objectLocations, objectStreamLocations) = try parseXrefStreamEntries(stream: stream)
		return PdfXRefTable(
			trailerDictionary: stream.dictionary,
			objectLocations: objectLocations,
			objectStreamLocations: objectStreamLocations
		)
	}
	
	static func parseXrefStreamEntries(
		stream: PdfStream
	) throws -> ([PdfObjectIdentifier: Int], [PdfObjectIdentifier: PdfObjectStreamLocation]) {
		// W defines the byte widths of the three fields per entry.
		guard
			let wArray = stream.dictionary[.W]?.array(lookup: nil),
			wArray.count == 3
		else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		let w = try wArray.map { object in
			guard let value = object.integer(lookup: nil) else {
				throw PdfParseError(failure: .missingRequiredParameters)
			}
			return value
		}
		
		// Index defines object number spans; default to 0..Size if omitted.
		let indexArray: [Int]
		if let indexObjects = stream.dictionary[.Index]?.array(lookup: nil) {
			indexArray = try indexObjects.map { object in
				guard let value = object.integer(lookup: nil) else {
					throw PdfParseError(failure: .missingRequiredParameters)
				}
				return value
			}
		} else if let size = stream.dictionary[.Size]?.integer(lookup: nil) {
			indexArray = [0, size]
		} else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		guard indexArray.count % 2 == 0 else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		// Iterate entries for each span, decoding fields into object locations.
		let entryLength = w.reduce(0, +)
		var offset = 0
		var objectLocations: [PdfObjectIdentifier: Int] = [:]
		var objectStreamLocations: [PdfObjectIdentifier: PdfObjectStreamLocation] = [:]
		
		for index in stride(from: 0, to: indexArray.count, by: 2) {
			let firstObject = indexArray[index]
			let count = indexArray[index + 1]
			for objectIndex in 0..<count {
				if offset + entryLength > stream.data.count {
					throw PdfParseError(failure: .objectEndedUnexpectedly)
				}
				// Field layout: type, field2, field3 (interpretation depends on type).
				let typeField = readXrefField(data: stream.data, offset: &offset, length: w[0])
				let field2 = readXrefField(data: stream.data, offset: &offset, length: w[1])
				let field3 = readXrefField(data: stream.data, offset: &offset, length: w[2])
				let entryType = w[0] == 0 ? 1 : typeField
				let objectNumber = firstObject + objectIndex
				if objectNumber == 0 {
					continue
				}
				
				switch entryType {
				case 0:
					continue
				case 1:
					// Uncompressed object: field2 is offset, field3 is generation.
					objectLocations[PdfObjectIdentifier(number: objectNumber, generation: field3)] = field2
				case 2:
					// Object stream entry: field2 is stream object number, field3 is index in stream.
					let objectIdentifier = PdfObjectIdentifier(number: objectNumber, generation: 0)
					objectStreamLocations[objectIdentifier] = PdfObjectStreamLocation(
						objectStream: PdfObjectIdentifier(number: field2, generation: 0),
						index: field3
					)
				default:
					continue
				}
			}
		}
		
		return (objectLocations, objectStreamLocations)
	}
	
	static func readXrefField(data: Data, offset: inout Int, length: Int) -> Int {
		guard length > 0 else { return 0 }
		var value = 0
		// Big-endian decode of a fixed-width field.
		for _ in 0..<length {
			value = (value << 8) + Int(data[offset])
			offset += 1
		}
		return value
	}
}
