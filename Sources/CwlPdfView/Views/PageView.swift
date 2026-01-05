import CwlPdfParser
import SwiftUI

struct PageView: View {
	@Binding var document: PdfFileDocument
	let page: PdfPage
	
	var body: some View {
		VStack {
			Canvas { context, size in
				var rect = page.pageRect?.cgRect ?? CGRect(x: 0, y: 0, width: 612, height: 792)
				rect.origin = .zero
				
				// Calculate scale factor to fit the page within the available size
				let scaleFactor = min(size.width / rect.width, size.height / rect.height)
				let xOffset = (size.width - scaleFactor * rect.width) / 2
				let yOffset = (size.height - scaleFactor * rect.height) / 2
				
				context.translateBy(x: xOffset, y: yOffset)
				context.scaleBy(x: scaleFactor, y: scaleFactor)
				
				let path = Path(rect)
				context.fill(path, with: .color(.white))
				context.clip(to: path)
				
				page.render(in: context)
			}
			.shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
			.padding(8)
		}
	}
}
