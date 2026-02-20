// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

#if DEBUG

import CwlPdfParser
import SwiftUI

@testable import CwlPdfView

#Preview {
	let document = try! PdfFileDocument(
		data: NSDataAsset(name: "three-page-images-assets.pdf")!.data
	)
	let page = document.pdf.pages[0]

	return PageView(
		document: .constant(document),
		page: page
	)
}

#endif
