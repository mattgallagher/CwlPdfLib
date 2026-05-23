// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CwlPdfRenderer
import SwiftUI

struct PageView: View {
	@Binding var document: PdfFileDocument
	let page: PdfPage
	@State private var extractedFeatures = [PdfExtractedFeature]()
	@State private var inspectorVisible = false
	@State private var selectedFeatureIndex: Int?
	
	var body: some View {
		HSplitView {
			PageCanvas(
				lookup: document.pdf.lookup,
				page: page,
				extractedFeatures: extractedFeatures,
				inspectorVisible: $inspectorVisible,
				selectedFeatureIndex: $selectedFeatureIndex
			)
			.layoutPriority(1)

			if inspectorVisible {
				FeatureInspectorView(
					page: page,
					extractedFeatures: extractedFeatures,
					selectedFeatureIndex: selectedFeatureIndex
				)
				.frame(minWidth: 200, maxWidth: 300, alignment: .leading)
			}
		}
		.background {
			Color(white: 0.95).ignoresSafeArea(edges: .horizontal)
		}
		.toolbar {
			ToolbarItem(placement: .automatic) {
				Button {
					inspectorVisible.toggle()
				} label: {
					Label("Inspector", systemImage: inspectorVisible ? "sidebar.right" : "sidebar.right")
				}
			}
		}
		.onAppear {
			refreshExtractedFeatures()
		}
		.id(page.id)
	}

	private func refreshExtractedFeatures() {
		extractedFeatures = page.extract(features: .all, lookup: document.pdf.lookup)
		
		if
			let selectedFeatureIndex,
			!extractedFeatures.indices.contains(selectedFeatureIndex)
		{
			self.selectedFeatureIndex = nil
		}
	}
}

private struct PageCanvas: View {
	private static let canvasInset: CGFloat = 8

	let lookup: PdfObjectLookup
	let page: PdfPage
	let extractedFeatures: [PdfExtractedFeature]
	@Binding var inspectorVisible: Bool
	@Binding var selectedFeatureIndex: Int?

	var body: some View {
		GeometryReader { proxy in
			let pageRect = page.renderBounds(lookup: lookup)
			let layout = PageViewLayout(
				size: proxy.size,
				pageRect: pageRect,
				inset: Self.canvasInset
			)
			ZStack(alignment: .topLeading) {
				Canvas { context, _ in
					context.concatenate(layout.pageTransform)
					context.fill(Path(pageRect), with: .color(.white))
					context.withCGContext { cgContext in
						page.render(in: cgContext, lookup: lookup)
					}
				}

				ForEach(Array(extractedFeatures.enumerated()), id: \.offset) { index, feature in
					let viewRect = layout.viewRect(for: feature.bounds)
					let isSelected = index == selectedFeatureIndex
					let color = inspectorVisible ? Color.accentColor : Color.clear
					Rectangle()
						.fill(color.opacity(isSelected ? 0.3 : 0))
						.overlay(Rectangle().stroke(color, lineWidth: isSelected ? 2 : 1))
						.contentShape(Rectangle())
						.onTapGesture {
							selectedFeatureIndex = index
							inspectorVisible = true
						}
						.frame(width: viewRect.width, height: viewRect.height)
						.position(x: viewRect.midX, y: viewRect.midY)
				}
			}
			.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
		}
		.contentShape(Rectangle())
		.onTapGesture {
			selectedFeatureIndex = nil
		}
	}
}

private struct FeatureInspectorView: View {
	let page: PdfPage
	let extractedFeatures: [PdfExtractedFeature]
	let selectedFeatureIndex: Int?

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			if
				let selectedFeatureIndex,
				extractedFeatures.indices.contains(selectedFeatureIndex)
			{
				let feature = extractedFeatures[selectedFeatureIndex]
				let boundsDescription = "x=\(feature.bounds.x), y=\(feature.bounds.y), w=\(feature.bounds.width), h=\(feature.bounds.height)"
				let matrixDescription = "[\(feature.matrix.a), \(feature.matrix.b), \(feature.matrix.c), \(feature.matrix.d), \(feature.matrix.tx), \(feature.matrix.ty)]"

				switch feature.payload {
				case .image(let stream, let objectIdentifier):
					HStack(spacing: 4) {
						Text("Image object:")
						ObjectIdentifierLabel(identifier: objectIdentifier)
					}
					Text(verbatim: "Image stream: \(stream.dictionary)")
				case .text(let utf8Text, let font):
					let fontName = font.postScriptName ?? "unknown"
					HStack(spacing: 4) {
						Text(verbatim: "Font: \(fontName)")
						ObjectIdentifierLabel(identifier: font.objectIdentifier)
					}
					Text(verbatim: "Size: \(font.size)")
					Text(verbatim: "Text: \(utf8Text)")
						.textSelection(.enabled)
				case .annotation(let type, let annotationIndex, let objectIdentifier):
					let annotationType = type ?? "unknown"
					Text(verbatim: "Annotation type: \(annotationType)")
					Text(verbatim: "Annotation index: \(annotationIndex)")
					HStack(spacing: 4) {
						Text("Annotation object:")
						ObjectIdentifierLabel(identifier: objectIdentifier)
					}
				}

				Group {
					Text(verbatim: "Bounds: \(boundsDescription)")
					Text(verbatim: "Matrix: \(matrixDescription)")
				}
				.font(.caption)
				.foregroundStyle(.secondary)
			} else {
				HStack(spacing: 4) {
					Text("Page object:")
					ObjectIdentifierLink(identifier: page.objectLayout.objectIdentifier)
				}
				Text(verbatim: "Page dictionary: \(page.pageDictionary)")
			}
		}
		.frame(maxHeight: .infinity, alignment: .top)
		.padding(12)
	}
}

private struct ObjectIdentifierLabel: View {
	let identifier: PdfObjectIdentifier?

	var body: some View {
		if let identifier {
			ObjectIdentifierLink(identifier: identifier)
		} else {
			Text("inline")
		}
	}
}

private struct PageViewLayout {
	let pageRect: CGRect
	let pageTransform: CGAffineTransform

	init(size: CGSize, pageRect: CGRect, inset: CGFloat) {
		self.pageRect = pageRect
		let availableSize = CGSize(
			width: max(size.width - inset * 2, 0),
			height: max(size.height - inset * 2, 0)
		)
		let scaleFactor = min(
			availableSize.width / pageRect.width,
			availableSize.height / pageRect.height
		)
		let xMargin = inset + (availableSize.width - scaleFactor * pageRect.width) / 2
		let yMargin = inset + (availableSize.height - scaleFactor * pageRect.height) / 2
		self.pageTransform = CGAffineTransform(
			a: scaleFactor,
			b: 0,
			c: 0,
			d: -scaleFactor,
			tx: xMargin - scaleFactor * pageRect.minX,
			ty: yMargin + scaleFactor * pageRect.maxY
		)
	}

	func viewRect(for pdfRect: PdfRect) -> CGRect {
		pdfRect.cgRect.applying(pageTransform).standardized
	}
}
