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
			try parse { op in
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
						let formContentStream = PdfContentStream(
							stream: xobjectStream,
							resources: nil,
							annotationRect: nil,
							lookup: lookup
						)
						extracted.append(contentsOf: formContentStream.extract(features: features, lookup: lookup, initialCTM: state.ctm))
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
					guard let fontDictionary = resolveResourceDictionary(category: .Font, key: fontKey, lookup: lookup) else {
						state.textState.font = nil
						break
					}
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
								let displacement = -(offset / 1000) * (state.textState.horizontalScale / 100)
								let translation = CGAffineTransform(translationX: displacement, y: 0)
								state.textPosition.textMatrix = translation.concatenating(state.textPosition.textMatrix)
							}
						}
						break
					}
					for item in array {
						switch item {
						case .offset(let offset):
							let displacement = -(offset / 1000) * (state.textState.horizontalScale / 100)
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
		} catch {
			print(error)
		}

		return extracted
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

	let metrics = textMetrics(data: data, state: state.textState)
	let ascent = metrics.ascent
	let descent = metrics.descent
	let localRect = CGRect(
		x: 0,
		y: descent,
		width: max(metrics.advance, 0),
		height: max(ascent - descent, 0)
	)

	let transformedRect = localRect.applying(textTransform).standardized
	let text = decodeText(data: data, font: state.textState.font)
	let font = PdfExtractedFont(
		postScriptName: state.textState.font?.postScriptName,
		size: Double(state.textState.fontSize)
	)

	let advanceTransform = CGAffineTransform(translationX: metrics.advance, y: 0)
	state.textPosition.textMatrix = advanceTransform.concatenating(state.textPosition.textMatrix)

	guard !text.isEmpty || metrics.advance > 0 else {
		return nil
	}

	return PdfExtractedFeature(
		bounds: PdfRect(transformedRect),
		matrix: textTransform.pdfOrientationMatrix,
		payload: .text(utf8Text: text, font: font)
	)
}

private func textMetrics(data: Data, state: TextState) -> (advance: CGFloat, ascent: CGFloat, descent: CGFloat) {
	let hScale = state.horizontalScale / 100

	let (ascentGlyphSpace, descentGlyphSpace) = if let font = state.font {
		(font.common.ascent ?? 800, font.common.descent ?? -200)
	} else {
		(800, -200)
	}
	let ascent = CGFloat(ascentGlyphSpace) / 1000
	let descent = CGFloat(descentGlyphSpace) / 1000

	guard let font = state.font else {
		let fallbackAdvance = CGFloat(data.count) * 0.6 * hScale
		return (fallbackAdvance, ascent, descent)
	}

	switch font.kind {
	case .simple(let simple):
		var cursor: CGFloat = 0
		for byte in data {
			let code = Int(byte)
			let width = if simple.widths.indices.contains(code - simple.firstChar) {
				simple.widths[code - simple.firstChar]
			} else {
				simple.missingWidth ?? 0
			}
			cursor += CGFloat(width / 1000) * hScale
			cursor += (state.charSpace + (code == 0x20 ? state.wordSpace : 0)) * hScale
		}
		return (cursor, ascent, descent)
	case .composite(let composite):
		var cursor: CGFloat = 0
		for cid in composite.cmap.decode(data) {
			let width = composite.descendantFont.widths.width(for: cid) ?? composite.descendantFont.defaultWidth
			cursor += CGFloat(width / 1000) * hScale
			cursor += (state.charSpace + (cid == 0x20 ? state.wordSpace : 0)) * hScale
		}
		return (cursor, ascent, descent)
	case .type3(let type3):
		var cursor: CGFloat = 0
		for byte in data {
			let code = Int(byte)
			let index = code - type3.firstChar
			let width = if type3.widths.indices.contains(index) { type3.widths[index] } else { 0.0 }
			cursor += CGFloat(width / 1000) * hScale
			cursor += (state.charSpace + (code == 0x20 ? state.wordSpace : 0)) * hScale
		}
		return (cursor, ascent, descent)
	}
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
