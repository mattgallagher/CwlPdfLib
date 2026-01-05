// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

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
