// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import CoreText
import CwlPdfParser
import Foundation

extension PdfContentStream {
	public func extract(features: PdfExtractedFeatureKind, lookup: PdfObjectLookup?) -> [PdfExtractedFeature] {
		guard !features.isEmpty else {
			return []
		}
		return extract(features: features, lookup: lookup, initialCTM: .identity)
	}

	func extract(features: PdfExtractedFeatureKind, lookup: PdfObjectLookup?, initialCTM: CGAffineTransform) -> [PdfExtractedFeature] {
		guard !features.isEmpty else {
			return []
		}

		var state = ExtractionGraphicsState(
			ctm: initialCTM,
			textState: TextState(),
			textPosition: TextPosition()
		)
		var stack = [ExtractionGraphicsState]()
		var extracted = [PdfExtractedFeature]()

		if let contextTransform {
			state.ctm = contextTransform.concatenating(state.ctm)
		}

		do {
			for stream in streams {
				try stream.parseContentOperators { op in
					switch op {
					case .`'`(let text):
						state.textPosition.lineMatrix = state.textPosition.lineMatrix.translatedBy(x: 0, y: -state.textState.leading)
						state.textPosition.textMatrix = state.textPosition.lineMatrix
						if features.contains(.text), let feature = extractTextFeature(text, state: &state, lookup: lookup) {
							extracted.append(feature)
						}
					case .`"`(let text, let cSpacing, let wSpacing):
						state.textState.charSpace = cSpacing
						state.textState.wordSpace = wSpacing
						state.textPosition.lineMatrix = state.textPosition.lineMatrix.translatedBy(x: 0, y: -state.textState.leading)
						state.textPosition.textMatrix = state.textPosition.lineMatrix
						if features.contains(.text), let feature = extractTextFeature(text, state: &state, lookup: lookup) {
							extracted.append(feature)
						}
					case .BT:
						state.textPosition = TextPosition()
					case .cm(let a, let b, let c, let d, let tx, let ty):
						let transform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
						state.ctm = transform.concatenating(state.ctm)
					case .Do(let xobjectName):
						guard let xobject = resolveResourceXObject(key: xobjectName, lookup: lookup) else {
							break
						}
						let xobjectStream = xobject.stream

						if features.contains(.images), xobjectStream.dictionary.isImage(lookup: lookup) {
							let transformedBounds = unitBounds.applying(state.ctm)
							extracted.append(
								PdfExtractedFeature(
									bounds: PdfRect(transformedBounds.standardized),
									matrix: state.ctm.pdfOrientationMatrix,
									payload: .image(stream: xobjectStream, objectIdentifier: xobject.objectIdentifier)
								)
							)
						} else if xobjectStream.dictionary.isForm(lookup: lookup) {
							let formContent = PdfFormContent(
								stream: xobjectStream,
								resources: resources,
								lookup: lookup
							)
							extracted.append(contentsOf: formContent.extract(features: features, lookup: lookup, initialCTM: state.ctm))
						}
					case .q:
						stack.append(state)
					case .Q:
						state = stack.popLast() ?? ExtractionGraphicsState(ctm: initialCTM, textState: TextState(), textPosition: TextPosition())
					case .Td(let tx, let ty):
						state.textPosition.lineMatrix = state.textPosition.lineMatrix.translatedBy(x: tx, y: ty)
						state.textPosition.textMatrix = state.textPosition.lineMatrix
					case .TD(let tx, let ty):
						state.textState.leading = -CGFloat(ty)
						state.textPosition.lineMatrix = state.textPosition.lineMatrix.translatedBy(x: tx, y: ty)
						state.textPosition.textMatrix = state.textPosition.lineMatrix
					case .Tf(let fontKey, let size):
						guard features.contains(.text) else {
							state.textState.fontSize = size
							break
						}
						state.textState.fontSize = size
						guard let fontObject = resources?[PdfResourceCategory.Font.rawValue]?.dictionary(lookup: lookup)?[fontKey] else {
							state.textState.font = nil
							state.textState.fontObjectIdentifier = nil
							break
						}
						guard let fontDictionary = fontObject.dictionary(lookup: lookup) else {
							state.textState.font = nil
							state.textState.fontObjectIdentifier = nil
							break
						}
						state.textState.fontObjectIdentifier = fontObject.reference
						state.textState.font = try? PdfFont(fontDictionary: fontDictionary, lookup: lookup) { data in
							CGDataProvider(data: data as CFData)
								.flatMap(CGFont.init)
								.map { CTFontCreateWithGraphicsFont($0, 1.0, nil, nil) }
						}
					case .Tj(let text):
						if features.contains(.text), let feature = extractTextFeature(text, state: &state, lookup: lookup) {
							extracted.append(feature)
						}
					case .TJ(let array):
						guard features.contains(.text) else {
							for item in array {
								if case .offset(let offset) = item {
									let displacement = textDisplacementForTJOffset(offset, state: state.textState)
									let translation = CGAffineTransform(translationX: displacement, y: 0)
									state.textPosition.textMatrix = translation.concatenating(state.textPosition.textMatrix)
								}
							}
							break
						}
						for item in array {
							switch item {
							case .offset(let offset):
								let displacement = textDisplacementForTJOffset(offset, state: state.textState)
								let translation = CGAffineTransform(translationX: displacement, y: 0)
								state.textPosition.textMatrix = translation.concatenating(state.textPosition.textMatrix)
							case .text(let text):
								if let feature = extractTextFeature(text, state: &state, lookup: lookup) {
									extracted.append(feature)
								}
							}
						}
					case .TL(let lead):
						state.textState.leading = lead
					case .Tm(let a, let b, let c, let d, let tx, let ty):
						state.textPosition.lineMatrix = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
						state.textPosition.textMatrix = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
					case .Ts(let rise):
						state.textState.rise = rise
					case .Tw(let wSpacing):
						state.textState.wordSpace = wSpacing
					case .Tz(let scaling):
						state.textState.horizontalScale = CGFloat(scaling)
					case .`T*`:
						state.textPosition.lineMatrix = state.textPosition.lineMatrix.translatedBy(x: 0, y: -state.textState.leading)
						state.textPosition.textMatrix = state.textPosition.lineMatrix
					default:
						break
					}
					return true
				}
			}
		} catch {
			print(error)
		}

		return extracted
	}
}

private extension PdfContentStream {
	var contextTransform: CGAffineTransform? {
		switch self {
		case let annotationAppearance as PdfAnnotationAppearanceContent:
			annotationAppearance.contextTransform
		case let formContent as PdfFormContent:
			formContent.contextTransform
		default:
			nil
		}
	}
}

private extension PdfAnnotationAppearanceContent {
	var contextTransform: CGAffineTransform? {
		guard let bbox = form.bbox?.cgRect else {
			return form.contextTransform
		}

		let rect = annotationRect.cgRect
		let matrix = form.matrix?.cgAffineTransform ?? .identity
		let transformedBBox = bbox.applying(matrix)
		let scaleX = rect.width / transformedBBox.width
		let scaleY = rect.height / transformedBBox.height
		let translateX = rect.minX - transformedBBox.minX * scaleX
		let translateY = rect.minY - transformedBBox.minY * scaleY

		var AA = CGAffineTransform.identity
		AA = AA.translatedBy(x: translateX, y: translateY)
		AA = AA.scaledBy(x: scaleX, y: scaleY)
		AA = AA.concatenating(matrix)
		return AA
	}
}

private struct ExtractionGraphicsState {
	var ctm: CGAffineTransform
	var textState: TextState
	var textPosition: TextPosition
}

private struct ResolvedXObject {
	let objectIdentifier: PdfObjectIdentifier?
	let stream: PdfStream
}

private let unitBounds = CGRect(x: 0, y: 0, width: 1, height: 1)

private func extractTextFeature(
	_ data: Data,
	state: inout ExtractionGraphicsState,
	lookup: PdfObjectLookup?
) -> PdfExtractedFeature? {
	let fontSize = max(CGFloat(state.textState.fontSize), 0.000_001)
	let textTransform = state.textPosition.textMatrix.scaledBy(x: fontSize, y: fontSize).concatenating(state.ctm)

	let measurement = measureTextRun(data, state: state.textState)
	let ascent = measurement.ascentInTextSpace
	let descent = measurement.descentInTextSpace
	let localRect = CGRect(
		x: 0,
		y: descent,
		width: max(measurement.advanceInTextSpace, 0),
		height: max(ascent - descent, 0)
	)

	let transformedRect = localRect.applying(textTransform).standardized
	let text = decodeText(data: data, font: state.textState.font)
	let font = PdfExtractedFont(
		objectIdentifier: state.textState.fontObjectIdentifier,
		postScriptName: state.textState.font?.postScriptName,
		size: Double(state.textState.fontSize)
	)

	let advanceTransform = CGAffineTransform(translationX: measurement.advanceInUserSpace, y: 0)
	state.textPosition.textMatrix = advanceTransform.concatenating(state.textPosition.textMatrix)

	guard !text.isEmpty || measurement.advanceInTextSpace > 0 else {
		return nil
	}

	return PdfExtractedFeature(
		bounds: PdfRect(transformedRect),
		matrix: textTransform.pdfOrientationMatrix,
		payload: .text(utf8Text: text, font: font)
	)
}

private func decodeText(data: Data, font: PdfFont<CTFont>?) -> String {
	guard let font else {
		return data.pdfTextToString()
	}

	if let decoded = font.extras.toUnicode?.decodeString(data) {
		return decoded
	}

	return data.pdfTextToString()
}

private extension PdfContentStream {
	func resolveResourceXObject(key: String, lookup: PdfObjectLookup?) -> ResolvedXObject? {
		guard let object = resources?[PdfResourceCategory.XObject.rawValue]?.dictionary(lookup: lookup)?[key] else {
			return nil
		}
		switch object {
		case .reference(let objectIdentifier):
			guard let stream = object.stream(lookup: lookup) else {
				return nil
			}
			return ResolvedXObject(objectIdentifier: objectIdentifier, stream: stream)
		case .stream(let stream):
			return ResolvedXObject(objectIdentifier: nil, stream: stream)
		default:
			return nil
		}
	}
}
