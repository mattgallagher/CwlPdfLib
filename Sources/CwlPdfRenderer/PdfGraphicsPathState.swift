// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics

struct PdfGraphicsPathState {
	private(set) var currentPoint: CGPoint?
	private var subpathStart: CGPoint?
	private(set) var hasDrawableSegments = false

	mutating func beginPath() {
		currentPoint = nil
		subpathStart = nil
		hasDrawableSegments = false
	}

	mutating func move(to point: CGPoint) {
		currentPoint = point
		subpathStart = point
	}

	mutating func addLine(to point: CGPoint) -> Bool {
		guard currentPoint != nil else {
			return false
		}

		currentPoint = point
		hasDrawableSegments = true
		return true
	}

	mutating func addCurve(to point: CGPoint) -> Bool {
		guard currentPoint != nil else {
			return false
		}

		currentPoint = point
		hasDrawableSegments = true
		return true
	}

	mutating func addRect(_ rect: CGRect) {
		subpathStart = CGPoint(x: rect.minX, y: rect.minY)
		currentPoint = subpathStart
		hasDrawableSegments = true
	}

	mutating func closeSubpath() -> Bool {
		guard let subpathStart, currentPoint != nil else {
			return false
		}

		currentPoint = subpathStart
		hasDrawableSegments = true
		return true
	}
}
