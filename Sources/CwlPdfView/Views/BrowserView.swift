// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CwlPdfParser
import SwiftUI

public struct PdfBrowserView: View {
	@Binding var document: PdfFileDocument
	@State var selection: SidebarSelection?
	@State var sidebarContent: SidebarContent = .pages
	@State private var history = BrowserHistory()
	
	public init(document: Binding<PdfFileDocument>) {
		self._document = document
	}
	
	public var body: some View {
		NavigationSplitView(columnVisibility: $sidebarContent.sidebarVisibility) {
			VStack {
				switch sidebarContent {
				case .objects:
					ObjectsTable(document: $document, selection: objectSelectionBinding)
				case .pages:
					PagesTable(document: $document, selection: pageSelectionBinding)
				case .hidden: EmptyView()
				}
			}
			.navigationSplitViewColumnWidth(min: 220, ideal: 250)
			.toolbar {
				ToolbarItemGroup(placement: .navigation) {
					Button {
						guard let location = history.goBack() else { return }
						apply(location, replayingHistory: true)
					} label: {
						Label("Back", systemImage: "chevron.backward")
					}
					.disabled(!history.canGoBack)

					Button {
						guard let location = history.goForward() else { return }
						apply(location, replayingHistory: true)
					} label: {
						Label("Forward", systemImage: "chevron.forward")
					}
					.disabled(!history.canGoForward)
				}

				ToolbarItemGroup(placement: .principal) {
					Picker("Sidebar content", selection: $sidebarContent.pickerSelection) {
						Label("Pages", systemImage: "book.pages").tag(SidebarContent.pages)
						Label("Objects", systemImage: "shippingbox").tag(SidebarContent.objects)
					}
					.pickerStyle(.menu)
					.labelStyle(.titleAndIcon)
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
			navigate(to: BrowserLocation(sidebarContent: .objects, selection: .object(layout)))
		})
		.onAppear {
			guard
				selection == nil,
				let firstPage = document.pdf.pages.first?.id
			else { return }
			Task {
				// Avoid an "action tried to update multiple times per frame" warning by doing this
				// in a Task
				navigate(to: BrowserLocation(sidebarContent: .pages, selection: .page(firstPage)))
			}
		}
		.animation(.default, value: sidebarContent.sidebarVisibility)
	}

	private var objectSelectionBinding: Binding<SidebarSelection?> {
		Binding(
			get: { selection },
			set: { newValue in
				guard case .object(let layout) = newValue else { return }
				navigate(to: BrowserLocation(sidebarContent: .objects, selection: .object(layout)))
			}
		)
	}

	private var pageSelectionBinding: Binding<SidebarSelection?> {
		Binding(
			get: { selection },
			set: { newValue in
				guard case .page(let page) = newValue else { return }
				navigate(to: BrowserLocation(sidebarContent: .pages, selection: .page(page)))
			}
		)
	}

	private func navigate(to location: BrowserLocation) {
		apply(location, replayingHistory: false)
	}

	private func apply(_ location: BrowserLocation, replayingHistory: Bool) {
		sidebarContent = location.sidebarContent
		selection = location.selection
		if !replayingHistory {
			history.record(location)
		}
	}
}

struct BrowserLocation: Equatable {
	let sidebarContent: SidebarContent
	let selection: SidebarSelection
}

struct BrowserHistory {
	private(set) var locations = [BrowserLocation]()
	private(set) var currentIndex: Int?

	var canGoBack: Bool {
		guard let currentIndex else { return false }
		return currentIndex > 0
	}

	var canGoForward: Bool {
		guard let currentIndex else { return false }
		return currentIndex < locations.endIndex - 1
	}

	mutating func record(_ location: BrowserLocation) {
		if currentLocation == location {
			return
		}
		if let currentIndex {
			locations.removeSubrange((currentIndex + 1)..<locations.endIndex)
		}
		locations.append(location)
		self.currentIndex = locations.endIndex - 1
	}

	mutating func goBack() -> BrowserLocation? {
		guard
			let currentIndex,
			currentIndex > 0
		else { return nil }
		let updatedIndex = currentIndex - 1
		self.currentIndex = updatedIndex
		return locations[updatedIndex]
	}

	mutating func goForward() -> BrowserLocation? {
		guard
			let currentIndex,
			currentIndex < locations.endIndex - 1
		else { return nil }
		let updatedIndex = currentIndex + 1
		self.currentIndex = updatedIndex
		return locations[updatedIndex]
	}

	var currentLocation: BrowserLocation? {
		guard let currentIndex else { return nil }
		return locations[currentIndex]
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
