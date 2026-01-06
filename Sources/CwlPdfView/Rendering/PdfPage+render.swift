// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

extension PdfPage {
	func render(in context: GraphicsContext, objects: PdfObjectList?) {
		guard let contentStream = self.contentStream(objects: objects) else {
			return
		}
		do {
			try contentStream.parse { op in
				return true
			}
		} catch {
			print(error)
		}
	}
}
