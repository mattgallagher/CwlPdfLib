// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

struct PagesTable: View {
	@Binding var document: PdfFileDocument
	@Binding var selection: SidebarSelection?
	
	var body: some View {
		Table(document.pdf.pages, selection: $selection.page) {
			TableColumn("Pages", value: \.debugDescription)
		}
	}
}

extension Optional<SidebarSelection> {
	var page: Set<PdfPage.ID> {
		get {
			if case .page(let page) = self {
				return [page]
			}
			return []
		}
		set {
			self = newValue.first.map { .page($0) }
		}
	}
}
