// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

struct ObjectsTable: View {
	@Binding var document: PdfFileDocument
	@Binding var selection: SidebarSelection?
	
	var body: some View {
		Table(document.pdf.lookup.allObjectByteRanges, selection: $selection.objectlayout) {
			TableColumn("Objects", value: \.debugDescription)
		}
	}
}

extension Optional<SidebarSelection> {
	var objectlayout: Set<PdfObjectLayout.ID> {
		get {
			if case .object(let layout) = self {
				return [layout]
			}
			return []
		}
		set {
			self = newValue.first.map { .object($0) }
		}
	}
}
