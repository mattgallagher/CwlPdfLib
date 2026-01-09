// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

public struct PdfXRefTable: Sendable {
	public let trailer: PdfDictionary
	public var objectLocations: [PdfObjectIdentifier: Int]

	init(trailerDictionary: PdfDictionary, objectLocations: [PdfObjectIdentifier: Int] = [:]) {
		self.trailer = trailerDictionary
		self.objectLocations = objectLocations
	}
}
