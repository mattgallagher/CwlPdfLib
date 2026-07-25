// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import CwlPdfRenderer
import SwiftUI

struct PageCanvas: View {
	private static let canvasInset: CGFloat = 8
	
	let lookup: PdfObjectLookup
	let page: PdfPage
	let extractedFeatures: [PdfExtractedFeature]
	@Binding var inspectorVisible: Bool
	@Binding var selectedFeatureIndex: Int?
	@Environment(\.displayScale) private var displayScale
	@State private var renderedImage: CGImage?
	
	var body: some View {
		let pageRect = page.renderBounds(lookup: lookup)
		GeometryReader { proxy in
			let layout = PageViewLayout(
				size: proxy.size,
				pageRect: pageRect,
				inset: Self.canvasInset
			)
			let renderKey = PageRenderKey(
				pageID: page.id,
				pixelSize: layout.pixelSize(displayScale: displayScale)
			)
			ZStack(alignment: .topLeading) {
				renderedPage(
					image: renderedImage,
					layout: layout
				)
				
				ForEach(Array(extractedFeatures.enumerated()), id: \.offset) { index, feature in
					let viewRect = layout.viewRect(for: feature.bounds)
					let isSelected = index == selectedFeatureIndex
					let color = inspectorVisible ? Color.accentColor : Color.clear
					Rectangle()
						.fill(color.opacity(isSelected ? 0.3 : 0))
						.overlay {
							if selectedFeatureIndex != nil {
								Rectangle().stroke(color, lineWidth: isSelected ? 2 : 1)
							}
						}
						.contentShape(Rectangle())
						.onTapGesture {
							selectedFeatureIndex = index
							inspectorVisible = true
						}
						.frame(width: viewRect.width, height: viewRect.height)
						.position(x: viewRect.midX, y: viewRect.midY)
				}
			}
			.task(id: renderKey) {
				await renderImage(
					pageRect: pageRect,
					key: renderKey
				)
			}
		}
		.contentShape(Rectangle())
		.onTapGesture {
			selectedFeatureIndex = nil
		}
	}
	
	@ViewBuilder
	private func renderedPage(image: CGImage?, layout: PageViewLayout) -> some View {
		ZStack {
			Rectangle()
				.fill(.white)
			
			if let image {
				Image(decorative: image, scale: displayScale, orientation: .up)
					.resizable()
			} else {
				ProgressView()
			}
		}
		.frame(width: layout.pageViewRect.width, height: layout.pageViewRect.height)
		.position(x: layout.pageViewRect.midX, y: layout.pageViewRect.midY)
		.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
	}
	
	private func renderImage(pageRect: CGRect, key: PageRenderKey) async {
		guard key.pixelSize.width > 0, key.pixelSize.height > 0 else {
			renderedImage = nil
			return
		}
		
		do {
			let image = try await renderImage(
				page: page,
				lookup: lookup,
				pageRect: pageRect,
				pixelSize: key.pixelSize
			)
			try Task.checkCancellation()
			
			renderedImage = image
		} catch is CancellationError {
		} catch {
			renderedImage = nil
		}
	}
	
	@concurrent
	private func renderImage(
		page: PdfPage,
		lookup: PdfObjectLookup,
		pageRect: CGRect,
		pixelSize: PagePixelSize
	) async throws -> CGImage {
		try page.renderedImage(
			lookup: lookup,
			bounds: pageRect,
			pixelWidth: pixelSize.width,
			pixelHeight: pixelSize.height,
			destinationColorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
			cancellationCheck: Task.checkCancellation
		)
	}
}

private struct PageRenderKey: Hashable {
	let pageID: PdfObjectLayout
	let pixelSize: PagePixelSize
}

private struct PagePixelSize: Hashable, Sendable {
	let width: Int
	let height: Int
}

private struct PageViewLayout {
	let pageRect: CGRect
	let pageTransform: CGAffineTransform
	let pageViewRect: CGRect

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
		self.pageViewRect = pageRect.applying(pageTransform).standardized
	}

	func viewRect(for pdfRect: PdfRect) -> CGRect {
		pdfRect.cgRect.applying(pageTransform).standardized
	}
	
	func pixelSize(displayScale: CGFloat) -> PagePixelSize {
		PagePixelSize(
			width: max(Int((pageViewRect.width * displayScale).rounded(.up)), 0),
			height: max(Int((pageViewRect.height * displayScale).rounded(.up)), 0)
		)
	}
}
