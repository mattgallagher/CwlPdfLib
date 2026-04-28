// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CwlPdfParser

public struct PdfExtractedFeatureKind: OptionSet, Sendable, Hashable {
	public let rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static let annotations = PdfExtractedFeatureKind(rawValue: 1 << 0)
	public static let images = PdfExtractedFeatureKind(rawValue: 1 << 1)
	public static let text = PdfExtractedFeatureKind(rawValue: 1 << 2)
	public static let all: PdfExtractedFeatureKind = [.annotations, .images, .text]
}

public struct PdfExtractedFeature: Sendable {
	public let bounds: PdfRect
	public let matrix: PdfAffineTransform
	public let payload: Payload

	public init(bounds: PdfRect, matrix: PdfAffineTransform, payload: Payload) {
		self.bounds = bounds
		self.matrix = matrix
		self.payload = payload
	}

	public enum Payload: Sendable {
		case annotation(annotationType: String?, annotationIndex: Int, objectIdentifier: PdfObjectIdentifier?)
		case image(stream: PdfStream, objectIdentifier: PdfObjectIdentifier?)
		case text(utf8Text: String, font: PdfExtractedFont)
	}
}

public struct PdfExtractedFont: Sendable {
	public let postScriptName: String?
	public let size: Double

	public init(postScriptName: String?, size: Double) {
		self.postScriptName = postScriptName
		self.size = size
	}
}

extension CGAffineTransform {
	var pdfOrientationMatrix: PdfAffineTransform {
		let xLength = hypot(a, b)
		let yLength = hypot(c, d)
		guard xLength > 0, yLength > 0 else {
			return .identity
		}

		let normalized = PdfAffineTransform(
			a: a / xLength,
			b: b / xLength,
			c: c / yLength,
			d: d / yLength,
			tx: 0,
			ty: 0
		)
		if
			abs(normalized.a - 1) < 0.000_001,
			abs(normalized.b) < 0.000_001,
			abs(normalized.c) < 0.000_001,
			abs(normalized.d - 1) < 0.000_001
		{
			return .identity
		}
		return normalized
	}
}

extension PdfRect {
	init(_ rect: CGRect) {
		self.init(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
	}
}
