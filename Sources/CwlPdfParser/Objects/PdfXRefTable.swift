// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfObjectStreamLocation: Sendable, Hashable {
	public let objectStream: PdfObjectIdentifier
	public let index: Int
	
	public init(objectStream: PdfObjectIdentifier, index: Int) {
		self.objectStream = objectStream
		self.index = index
	}
}

public struct PdfXRefTable: Sendable {
	public let trailer: PdfDictionary
	public var objectLocations: [PdfObjectIdentifier: Int]
	public var objectStreamLocations: [PdfObjectIdentifier: PdfObjectStreamLocation]

	init(
		trailerDictionary: PdfDictionary,
		objectLocations: [PdfObjectIdentifier: Int] = [:],
		objectStreamLocations: [PdfObjectIdentifier: PdfObjectStreamLocation] = [:]
	) {
		self.trailer = trailerDictionary
		self.objectLocations = objectLocations
		self.objectStreamLocations = objectStreamLocations
	}
}
