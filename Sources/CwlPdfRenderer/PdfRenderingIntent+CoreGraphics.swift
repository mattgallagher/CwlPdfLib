// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CoreGraphics

extension String {
	var cgColorRenderingIntent: CGColorRenderingIntent? {
		switch self {
		case "AbsoluteColorimetric": .absoluteColorimetric
		case "Perceptual": .perceptual
		case "RelativeColorimetric": .relativeColorimetric
		case "Saturation": .saturation
		default: nil
		}
	}
}
