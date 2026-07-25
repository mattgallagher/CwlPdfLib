// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Synchronization

public struct PdfObjectLookup: Sendable {
	let source: any PdfSource
	let xrefTables: [PdfXRefTable]
	let objectLayoutFromOffset: [Int: PdfObjectLayout]
	let objectLayoutFromObjectStream: [PdfObjectIdentifier: PdfObjectLayout]
	let mutableState = PdfObjectCache()

	/// Decryption handler for encrypted documents. Set after initialization when encryption is detected.
	var decryption: PdfDecryption?
	
	public func objectLayout(for objectIdentifier: PdfObjectIdentifier) throws -> PdfObjectLayout? {
		for table in xrefTables {
			if let location = table.objectLocations[objectIdentifier] {
				guard let layout = objectLayoutFromOffset[location] else {
					throw PdfParseError(failure: .missingLayoutForObject, objectIdentifier: objectIdentifier, range: 0..<source.length)
				}
				return layout
			}
			if table.objectStreamLocations[objectIdentifier] != nil {
				guard let layout = objectLayoutFromObjectStream[objectIdentifier] else {
					throw PdfParseError(failure: .missingLayoutForObject, objectIdentifier: objectIdentifier, range: 0..<source.length)
				}
				return layout
			}
		}
		return nil
	}
	
	public func object(layout: PdfObjectLayout) throws -> PdfObject {
		switch layout.storage {
		case .uncompressed(let range):
			try source.parseContext(range: range) { context in
				context.decryption = decryption
				context.objectIdentifier = layout.objectIdentifier
				return try PdfObject.parseIndirect(lookup: self, context: &context)
			}
		case .objectStream(let streamIdentifier, let index):
			try objectFromObjectStream(streamIdentifier: streamIdentifier, index: index, expectedIdentifier: layout.objectIdentifier)
		}
	}
	
	public func object(for objectIdentifier: PdfObjectIdentifier) throws -> PdfObject? {
		if let cachedObject = mutableState.cachedObject(for: objectIdentifier) {
			return cachedObject
		}
		guard let layout = try objectLayout(for: objectIdentifier) else { return nil }
		let object = try object(layout: layout)
		mutableState.cache(object, for: objectIdentifier)
		return object
	}
	
	public var allObjectByteRanges: [PdfObjectLayout] {
		objectLayoutFromOffset.sorted { lhs, rhs in
			if lhs.value.objectIdentifier.number == rhs.value.objectIdentifier.number {
				let lhsRange = lhs.value.range?.lowerBound ?? 0
				let rhsRange = rhs.value.range?.lowerBound ?? 0
				return lhsRange < rhsRange
			}
			return lhs.value.objectIdentifier.number < rhs.value.objectIdentifier.number
		}.map(\.value)
	}

	public var allObjectLayouts: [PdfObjectLayout] {
		var seenLayouts = Set<PdfObjectLayout>()
		var layouts = [PdfObjectLayout]()

		for layout in objectLayoutFromOffset.values {
			if seenLayouts.insert(layout).inserted {
				layouts.append(layout)
			}
		}

		for layout in objectLayoutFromObjectStream.values {
			if seenLayouts.insert(layout).inserted {
				layouts.append(layout)
			}
		}

		return layouts.sorted { lhs, rhs in
			if lhs.objectIdentifier.number != rhs.objectIdentifier.number {
				return lhs.objectIdentifier.number < rhs.objectIdentifier.number
			}
			if lhs.objectIdentifier.generation != rhs.objectIdentifier.generation {
				return lhs.objectIdentifier.generation < rhs.objectIdentifier.generation
			}
			if lhs.revision != rhs.revision {
				return lhs.revision < rhs.revision
			}
			let lhsRange = lhs.range?.lowerBound ?? 0
			let rhsRange = rhs.range?.lowerBound ?? 0
			return lhsRange < rhsRange
		}
	}
	
	private func objectFromObjectStream(
		streamIdentifier: PdfObjectIdentifier,
		index: Int,
		expectedIdentifier: PdfObjectIdentifier
	) throws -> PdfObject {
		guard let streamObject = try object(for: streamIdentifier) else {
			throw PdfParseError(failure: .objectNotFound, objectIdentifier: streamIdentifier, range: 0..<source.length)
		}
		guard case .stream(let stream) = streamObject else {
			throw PdfParseError(failure: .expectedDictionary, objectIdentifier: streamIdentifier, range: 0..<source.length)
		}
		return try parseObjectFromObjectStream(
			stream: stream,
			index: index,
			expectedIdentifier: expectedIdentifier
		)
	}
	
	private func parseObjectFromObjectStream(
		stream: PdfStream,
		index: Int,
		expectedIdentifier: PdfObjectIdentifier
	) throws -> PdfObject {
		guard
			let count = stream.dictionary[.N]?.integer(lookup: nil),
			let first = stream.dictionary[.First]?.integer(lookup: nil)
		else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		guard count > 0, index >= 0, index < count else {
			throw PdfParseError(failure: .objectNotFound, objectIdentifier: expectedIdentifier, range: 0..<stream.data.count)
		}
		guard first >= 0, first <= stream.data.count else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let headerData = stream.data.prefix(first)
		var values = [Int]()
		values.reserveCapacity(count * 2)
		try headerData.parseContext { context in
			for _ in 0..<(count * 2) {
				let token = try PdfToken.parse(context: &context)
				try values.append(token.requireNaturalNumber(context: &context))
			}
		}
		guard values.count == count * 2 else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		var objectNumbers = [Int]()
		var objectOffsets = [Int]()
		objectNumbers.reserveCapacity(count)
		objectOffsets.reserveCapacity(count)
		for pairIndex in stride(from: 0, to: values.count, by: 2) {
			objectNumbers.append(values[pairIndex])
			objectOffsets.append(values[pairIndex + 1])
		}
		let objectStart = first + objectOffsets[index]
		let objectEnd = index + 1 < count ? first + objectOffsets[index + 1] : stream.data.count
		guard objectStart <= objectEnd, objectEnd <= stream.data.count else {
			throw PdfParseError(failure: .missingRequiredParameters)
		}
		
		let objectData = stream.data.subdata(in: objectStart..<objectEnd)
		return try objectData.parseContext { context in
			context.decryption = decryption
			let objectIdentifier = PdfObjectIdentifier(number: objectNumbers[index], generation: 0)
			if objectIdentifier != expectedIdentifier {
				throw PdfParseError(failure: .objectNotFound, objectIdentifier: expectedIdentifier, range: 0..<stream.data.count)
			}
			context.objectIdentifier = objectIdentifier
			return try PdfObject.parse(context: &context)
		}
	}
}

final class PdfObjectCache: Sendable {
	struct State: Sendable {
		var cachedObjects = [PdfObjectIdentifier: PdfObject]()
		var contentOperators = [PdfObjectIdentifier: [PdfOperator]]()
		
		// Changed objects exist only in the cachedObjects dictionary and must not be evicted until file save
		var changedObjects = Set<PdfObjectIdentifier>()
	}

	private let state = Mutex(State())

	func cachedObject(for objectIdentifier: PdfObjectIdentifier) -> PdfObject? {
		state.withLock { $0.cachedObjects[objectIdentifier] }
	}

	func cache(_ object: PdfObject, for objectIdentifier: PdfObjectIdentifier) {
		state.withLock { $0.cachedObjects[objectIdentifier] = object }
	}

	func cachedContentOperators(for objectIdentifier: PdfObjectIdentifier) -> [PdfOperator]? {
		state.withLock { $0.contentOperators[objectIdentifier] }
	}

	func cacheContentOperators(_ operators: [PdfOperator], for objectIdentifier: PdfObjectIdentifier) {
		state.withLock { $0.contentOperators[objectIdentifier] = operators }
	}

	func isChanged(for objectIdentifier: PdfObjectIdentifier) -> Bool {
		state.withLock { $0.changedObjects.contains(objectIdentifier) }
	}
}
