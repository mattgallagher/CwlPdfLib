// CwlPdfApp. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfView
import SwiftUI

@main
struct CwlPdfApp: App {
	var body: some Scene {
		DocumentGroup(viewing: PdfFileDocument.self) { file in
			PdfBrowserView(document: file.$document)
		}
	}
}
