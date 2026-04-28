// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics
import Testing

@testable import CwlPdfRenderer

struct PdfGraphicsPathStateTests {
	@Test
	func `GIVEN a path state without a current point WHEN line and curve operators are applied THEN they are rejected`() {
		var state = PdfGraphicsPathState()
		let addedLine = state.addLine(to: CGPoint(x: 10, y: 20))
		let addedCurve = state.addCurve(to: CGPoint(x: 30, y: 40))

		#expect(!addedLine)
		#expect(!addedCurve)
		#expect(state.currentPoint == nil)
		#expect(!state.hasDrawableSegments)
	}

	@Test
	func `GIVEN a moved subpath WHEN it is closed THEN the current point returns to the subpath start`() {
		var state = PdfGraphicsPathState()

		state.move(to: CGPoint(x: 5, y: 6))
		let closed = state.closeSubpath()

		#expect(closed)
		#expect(state.currentPoint == CGPoint(x: 5, y: 6))
		#expect(state.hasDrawableSegments)
	}

	@Test
	func `GIVEN a consumed path WHEN beginPath is applied THEN the current path state resets`() {
		var state = PdfGraphicsPathState()

		state.move(to: CGPoint(x: 1, y: 2))
		let addedLine = state.addLine(to: CGPoint(x: 3, y: 4))

		#expect(addedLine)
		state.beginPath()

		#expect(state.currentPoint == nil)
		#expect(!state.hasDrawableSegments)
	}
}
