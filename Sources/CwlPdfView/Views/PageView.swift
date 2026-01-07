import CwlPdfParser
import SwiftUI

struct PageView: View {
	@Binding var document: PdfFileDocument
	let page: PdfPage
	
	var body: some View {
		VStack {
			Canvas { context, size in
				var rect = page.pageRect(objects: document.pdf.objects).cgRect
				rect.origin = .zero
				
				// Calculate scale factor to fit the page within the available size
				let scaleFactor = min(size.width / rect.width, size.height / rect.height)
				let xOffset = (size.width - scaleFactor * rect.width) / 2
				let yOffset = (size.height - scaleFactor * rect.height) / 2
				
				context.concatenate(
					CGAffineTransform(a: scaleFactor, b: 0, c: 0, d: -scaleFactor, tx: xOffset, ty: yOffset + scaleFactor * rect.height)
				)
				
				let path = Path(rect)
				context.fill(path, with: .color(.white))
				context.clip(to: path)
				
				context.withCGContext { cgContext in
					page.render(in: cgContext, objects: document.pdf.objects)
				}
			}
			.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
			.padding(8)
		}
		.background {
			Color(white: 0.95).ignoresSafeArea(edges: .horizontal)
		}
	}
}
