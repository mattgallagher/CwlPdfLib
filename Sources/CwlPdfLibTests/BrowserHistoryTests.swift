// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

@testable import CwlPdfParser
@testable import CwlPdfView
import Testing

@MainActor
struct BrowserHistoryTests {
	@Test
	func `GIVEN the first location WHEN recorded THEN it becomes the current location and navigation is unavailable`() {
		var history = BrowserHistory()
		let firstLocation = pageLocation(pageNumber: 1)

		history.record(firstLocation)

		#expect(history.locations == [firstLocation])
		#expect(history.currentIndex == 0)
		#expect(history.currentLocation == firstLocation)
		#expect(history.canGoBack == false)
		#expect(history.canGoForward == false)
	}

	@Test
	func `GIVEN the same location twice WHEN recorded THEN no duplicate history entry is added`() {
		var history = BrowserHistory()
		let firstLocation = pageLocation(pageNumber: 1)

		history.record(firstLocation)
		history.record(firstLocation)

		#expect(history.locations == [firstLocation])
		#expect(history.currentIndex == 0)
	}

	@Test
	func `GIVEN multiple locations WHEN moving backward and forward THEN the expected entries are restored`() {
		var history = BrowserHistory()
		let firstLocation = pageLocation(pageNumber: 1)
		let secondLocation = objectLocation(objectNumber: 8)
		let thirdLocation = pageLocation(pageNumber: 2)

		history.record(firstLocation)
		history.record(secondLocation)
		history.record(thirdLocation)

		#expect(history.canGoBack == true)
		#expect(history.canGoForward == false)
		#expect(history.goBack() == secondLocation)
		#expect(history.currentLocation == secondLocation)
		#expect(history.canGoBack == true)
		#expect(history.canGoForward == true)
		#expect(history.goBack() == firstLocation)
		#expect(history.currentLocation == firstLocation)
		#expect(history.canGoBack == false)
		#expect(history.canGoForward == true)
		#expect(history.goForward() == secondLocation)
		#expect(history.currentLocation == secondLocation)
	}

	@Test
	func `GIVEN forward history WHEN a new location is recorded THEN the forward entries are discarded`() {
		var history = BrowserHistory()
		let firstLocation = pageLocation(pageNumber: 1)
		let secondLocation = objectLocation(objectNumber: 8)
		let thirdLocation = pageLocation(pageNumber: 2)
		let replacementLocation = objectLocation(objectNumber: 12)

		history.record(firstLocation)
		history.record(secondLocation)
		history.record(thirdLocation)
		_ = history.goBack()

		history.record(replacementLocation)

		#expect(history.locations == [firstLocation, secondLocation, replacementLocation])
		#expect(history.currentIndex == 2)
		#expect(history.currentLocation == replacementLocation)
		#expect(history.canGoForward == false)
	}

	@Test
	func `GIVEN no available history movement WHEN moving beyond the ends THEN nil is returned`() {
		var history = BrowserHistory()
		let firstLocation = pageLocation(pageNumber: 1)

		history.record(firstLocation)

		#expect(history.goBack() == nil)
		#expect(history.goForward() == nil)
	}
}

private func pageLocation(pageNumber: Int) -> BrowserLocation {
	BrowserLocation(
		sidebarContent: .pages,
		selection: .page(
			PdfObjectLayout(
				objectIdentifier: PdfObjectIdentifier(number: pageNumber, generation: 0),
				storage: .uncompressed(range: (pageNumber * 100)..<(pageNumber * 100 + 10)),
				revision: 0
			)
		)
	)
}

private func objectLocation(objectNumber: Int) -> BrowserLocation {
	BrowserLocation(
		sidebarContent: .objects,
		selection: .object(
			PdfObjectLayout(
				objectIdentifier: PdfObjectIdentifier(number: objectNumber, generation: 0),
				storage: .uncompressed(range: (objectNumber * 100)..<(objectNumber * 100 + 10)),
				revision: 0
			)
		)
	)
}
