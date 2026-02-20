// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI
import UniformTypeIdentifiers

public nonisolated struct PdfFileDocument: FileDocument {
	let pdf: PdfDocument
	
	init(data: Data) throws {
		self.pdf = try PdfDocument(source: PdfDataSource(data))
	}
	
	public static let readableContentTypes = [
		UTType.pdf
	]
	
	public init(configuration: ReadConfiguration) throws {
		guard let data = configuration.file.regularFileContents else {
			throw CocoaError(.fileReadCorruptFile)
		}
		try self.init(data: data)
	}
	
	public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		return try FileWrapper(regularFileWithContents: pdf.fileData())
	}
}
