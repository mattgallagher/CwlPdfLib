// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

struct PageView: View {
	@Binding var document: PdfFileDocument
	let page: PdfPage
	
	var body: some View {
		Text(verbatim: page.pageDictionary.debugDescription)
	}
}
