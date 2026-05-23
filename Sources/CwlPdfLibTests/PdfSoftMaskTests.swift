// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
@testable import CwlPdfParser
@testable import CwlPdfRenderer
import Foundation
import Testing

struct PdfSoftMaskTests {
	@Test
	func `GIVEN PDFUA magazine page 14 GS1 WHEN applying its soft mask THEN mask rasterization uses page scale rather than full local CTM`() throws {
		let document = try fixtureDocument(path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-01_Magazine-danish.pdf")
		let page = try #require(document.pages.indices.contains(13) ? document.pages[13] : nil)
		let foundDiagnostic = try findSoftMaskDiagnostic(on: page, lookup: document.lookup, gstateName: "GS1")
		let diagnostic = try #require(foundDiagnostic)
		let gstate = PdfExtGState(dictionary: diagnostic.gstateDictionary, lookup: document.lookup)
		let smask = try #require(gstate.softMask)
		let bboxArray = try #require(smask.transparencyGroup.dictionary[.BBox]?.array(lookup: document.lookup))
		let bbox = try #require(PdfRect(array: bboxArray, lookup: document.lookup)?.cgRect)
		let pageScale: CGFloat = 2
		let expectedWidth = Int((bbox.width * pageScale).rounded(.toNearestOrAwayFromZero))
		let expectedHeight = Int((bbox.height * pageScale).rounded(.toNearestOrAwayFromZero))
		let oversizedWidth = Int((bbox.width * diagnostic.fullCTMScaleX).rounded(.toNearestOrAwayFromZero))
		let oversizedHeight = Int((bbox.height * diagnostic.fullCTMScaleY).rounded(.toNearestOrAwayFromZero))

		guard let context = CGContext(
			data: nil,
			width: 8,
			height: 8,
			bitsPerComponent: 8,
			bytesPerRow: 0,
			space: CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
		) else {
			Issue.record("Failed to create CGContext")
			return
		}

		context.concatenate(CGAffineTransform(scaleX: pageScale, y: pageScale))
		context.concatenate(diagnostic.ctmAtApplication)

		var renderState = RenderState(
			deviceScaleX: pageScale,
			deviceScaleY: pageScale
		)
		context.apply(
			gstate,
			renderState: &renderState,
			renderStack: [],
			lookup: document.lookup
		)

		let mask = try #require(renderState.activeSoftMask)
		#expect(oversizedWidth == 31_574)
		#expect(oversizedHeight == 16_034)
		#expect(mask.width == expectedWidth)
		#expect(mask.height == expectedHeight)
		#expect(diagnostic.fullCTMScaleX > pageScale * 5)
		#expect(diagnostic.fullCTMScaleY > pageScale * 5)
	}
}

private struct SoftMaskDiagnostic {
	let gstateDictionary: PdfDictionary
	let ctmAtApplication: CGAffineTransform
	let fullCTMScaleX: CGFloat
	let fullCTMScaleY: CGFloat
}

private func findSoftMaskDiagnostic(
	on page: PdfPage,
	lookup: PdfObjectLookup?,
	gstateName: String
) throws -> SoftMaskDiagnostic? {
	let content = page.content(lookup: lookup)
	for stream in content.streams {
		if let diagnostic = try findSoftMaskDiagnostic(
			in: stream,
			resources: content,
			lookup: lookup,
			gstateName: gstateName,
			initialCTM: .identity
		) {
			return diagnostic
		}
	}
	return nil
}

private func findSoftMaskDiagnostic(
	in stream: PdfStream,
	resources: any PdfContentStream,
	lookup: PdfObjectLookup?,
	gstateName: String,
	initialCTM: CGAffineTransform
) throws -> SoftMaskDiagnostic? {
	var ctm = initialCTM
	var ctmStack = [CGAffineTransform]()
	var parseError: Error?
	var result: SoftMaskDiagnostic?

	try stream.parseContentOperators { op in
		switch op {
		case .cm(let a, let b, let c, let d, let tx, let ty):
			ctm = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty).concatenating(ctm)
		case .q:
			ctmStack.append(ctm)
		case .Q:
			ctm = ctmStack.popLast() ?? initialCTM
		case .gs(let name):
			guard
				name == gstateName,
				let gstateDictionary = resources.resolveResourceDictionary(
					category: .ExtGState,
					key: name,
					lookup: lookup
				)
			else {
				break
			}
			let scaleX = hypot(ctm.a, ctm.c)
			let scaleY = hypot(ctm.b, ctm.d)
			result = SoftMaskDiagnostic(
				gstateDictionary: gstateDictionary,
				ctmAtApplication: ctm,
				fullCTMScaleX: scaleX,
				fullCTMScaleY: scaleY
			)
			return false
		case .Do(let xobjectName):
			guard
				let xobjectStream = resources.resolveResourceStream(
					category: .XObject,
					key: xobjectName,
					lookup: lookup
				),
				xobjectStream.dictionary.isForm(lookup: lookup)
			else {
				break
			}
			let formContent = PdfFormContent(
				stream: xobjectStream,
				resources: resources.resources,
				lookup: lookup
			)
			let formInitialCTM = (formContent.contextTransform ?? .identity).concatenating(ctm)
			do {
				if let nested = try findSoftMaskDiagnostic(
					in: formContent.stream,
					resources: formContent,
					lookup: lookup,
					gstateName: gstateName,
					initialCTM: formInitialCTM
				) {
					result = nested
					return false
				}
			} catch {
				parseError = error
				return false
			}
		default:
			break
		}
		return true
	}

	if let parseError {
		throw parseError
	}

	return result
}
