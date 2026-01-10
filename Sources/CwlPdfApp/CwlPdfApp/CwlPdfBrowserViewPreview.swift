// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

#if DEBUG

@testable import CwlPdfView
import SwiftUI

#Preview {
	try! PdfBrowserView(
		document: .constant(
			PdfFileDocument(
				data: NSDataAsset(name: "blank-page.pdf")!.data
			)
		)
	)
}

#endif
