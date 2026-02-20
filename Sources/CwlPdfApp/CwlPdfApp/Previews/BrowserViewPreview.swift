// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

#if DEBUG

import SwiftUI

@testable import CwlPdfView

#Preview {
	PdfBrowserView(
		document: .constant(
			try! PdfFileDocument(
				data: NSDataAsset(name: "three-page-images-assets.pdf")!.data
			)
		)
	)
}

#endif
