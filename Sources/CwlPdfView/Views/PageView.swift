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
			GeometryReader { proxy in
				let pageRect = page.renderBounds(lookup: document.pdf.lookup)
				let layout = PageViewLayout(size: proxy.size, pageRect: pageRect)
				ZStack(alignment: .topLeading) {
					Canvas { context, _ in
						context.concatenate(layout.pageTransform)
						context.fill(Path(pageRect), with: .color(.white))
						context.withCGContext { cgContext in
							page.render(in: cgContext, lookup: document.pdf.lookup)
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
				.padding(8)
			}
			.frame(maxWidth: .infinity)

			if inspectorVisible {
				featureInspector
					.frame(minWidth: 150, idealWidth: 250, maxWidth: 400)
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

	private var featureInspector: some View {
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
					let objectDescription = objectIdentifier?.debugDescription ?? "inline"
					Text(verbatim: "Image object: \(objectDescription)")
					Text(verbatim: "Image stream: \(stream.dictionary)")
				case .text(let utf8Text, let font):
					let fontName = font.postScriptName ?? "unknown"
					Text(verbatim: "Font: \(fontName)")
					Text(verbatim: "Size: \(font.size)")
					Text(verbatim: "Text: \(utf8Text)")
						.textSelection(.enabled)
				case .annotation(let type, let annotationIndex):
					let annotationType = type ?? "unknown"
					Text(verbatim: "Annotation type: \(annotationType)")
					Text(verbatim: "Annotation index: \(annotationIndex)")
				}
				
				Group {
					Text(verbatim: "Bounds: \(boundsDescription)")
					Text(verbatim: "Matrix: \(matrixDescription)")
				}
				.font(.caption)
				.foregroundStyle(.secondary)
			} else {
				Text("Click a text region to inspect extracted details.")
					.foregroundStyle(.secondary)
			}

			Spacer()
		}
		.padding(12)
	}

	private func refreshExtractedFeatures() {
		extractedFeatures = page.extract(features: .all, lookup: document.pdf.lookup)
		
		for feature in extractedFeatures {
			switch feature.payload {
			case .text(let utf8, _):
				print("Text \(utf8) bounds \(feature.bounds)")
			case .image:
				print("Image bounds \(feature.bounds)")
			case .annotation(let type, _):
				print("Annotation \(type ?? "unknown") bounds \(feature.bounds)")
			}
		}
		
		if
			let selectedFeatureIndex,
			!extractedFeatures.indices.contains(selectedFeatureIndex)
		{
			self.selectedFeatureIndex = nil
		}
	}
}

private struct PageViewLayout {
	let pageRect: CGRect
	let pageTransform: CGAffineTransform

	init(size: CGSize, pageRect: CGRect) {
		self.pageRect = pageRect
		let scaleFactor = min(size.width / pageRect.width, size.height / pageRect.height)
		let xOffset = -pageRect.origin.x + (size.width - scaleFactor * pageRect.width) / 2
		let yOffset = -pageRect.origin.y + (size.height - scaleFactor * pageRect.height) / 2
		self.pageTransform = CGAffineTransform(
			a: scaleFactor,
			b: 0,
			c: 0,
			d: -scaleFactor,
			tx: xOffset,
			ty: yOffset + scaleFactor * pageRect.height
		)
	}

	func viewRect(for pdfRect: PdfRect) -> CGRect {
		pdfRect.cgRect.applying(pageTransform).standardized
	}
}
