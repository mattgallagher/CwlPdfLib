// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

public struct PdfBrowserView: View {
	@Binding var document: PdfFileDocument
	@State var selection: SidebarSelection?
	@State var sidebarContent: SidebarContent = .pages
	
	public init(document: Binding<PdfFileDocument>) {
		self._document = document
	}
	
	public var body: some View {
		NavigationSplitView(columnVisibility: $sidebarContent.sidebarVisibility) {
			VStack {
				switch sidebarContent {
				case .objects: ObjectsTable(document: $document, selection: $selection)
				case .pages: PagesTable(document: $document, selection: $selection)
				case .hidden: EmptyView()
				}
			}
			.toolbar(removing: .sidebarToggle)
			.navigationSplitViewColumnWidth(min: 220, ideal: 250)
			.toolbar {
				ToolbarItemGroup(placement: .principal) {
					Picker("Sidebar content", selection: $sidebarContent.pickerSelection) {
						Label("Pages", systemImage: "book.pages").tag(SidebarContent.pages)
						Label("Objects", systemImage: "shippingbox").tag(SidebarContent.objects)
					}
					.pickerStyle(.segmented)
				}
			}
		} detail: {
			switch selection {
			case .object(let layout):
				ObjectView(document: $document, layout: layout)
			case .page(let identifier):
				if let page = document.pdf.page(for: identifier) {
					PageView(document: $document, page: page)
				} else {
					Text("Page not found")
				}
			case nil: Text("Nothing selected")
			}
		}
		.environment(\.navigateToObject, NavigateToObjectAction { identifier in
			guard let layout = document.pdf.lookup.allObjectLayouts
				.last(where: { $0.objectIdentifier == identifier })
			else { return }
			sidebarContent = .objects
			selection = .object(layout)
		})
		.onAppear {
			if let firstPage = document.pdf.pages.first?.id {
				selection = .page(firstPage)
			}
		}
		.animation(.default, value: sidebarContent.sidebarVisibility)
	}
}

struct NavigateToObjectAction {
	let action: (PdfObjectIdentifier) -> Void
	func callAsFunction(_ identifier: PdfObjectIdentifier) {
		action(identifier)
	}
}

extension EnvironmentValues {
	@Entry var navigateToObject: NavigateToObjectAction = NavigateToObjectAction { _ in }
}

struct ObjectIdentifierLink: View {
	let identifier: PdfObjectIdentifier
	@Environment(\.navigateToObject) private var navigateToObject

	var body: some View {
		Button(identifier.debugDescription) {
			navigateToObject(identifier)
		}
		.buttonStyle(.link)
	}
}

enum SidebarContent: Hashable {
	case objects
	case pages
	case hidden
	
	var sidebarVisibility: NavigationSplitViewVisibility {
		get {
			switch self {
			case .objects, .pages: .all
			case .hidden: .detailOnly
			}
		}
		set {
			if newValue == .all {
				if self == .hidden {
					self = .objects
				}
			} else {
				self = .hidden
			}
		}
	}
	
	var pickerSelection: SidebarContent {
		get {
			self
		}
		set {
			if self != newValue {
				self = newValue
			} else {
				self = .hidden
			}
		}
	}
}

enum SidebarSelection: Hashable {
	case object(PdfObjectLayout)
	case page(PdfPage.ID)
}
