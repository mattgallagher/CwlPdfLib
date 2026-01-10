// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Represents a PDF Extended Graphics State (ExtGState) dictionary.
/// Used by the `gs` operator to set multiple graphics state parameters at once.
public struct PdfGState: Sendable {
	/// Stroking alpha (opacity). Range: 0.0 to 1.0
	public let strokingAlpha: Double?

	/// Non-stroking alpha (opacity). Range: 0.0 to 1.0
	public let nonStrokingAlpha: Double?

	/// Blend mode for transparency
	public let blendMode: PdfBlendMode?

	/// Line width
	public let lineWidth: Double?

	/// Line cap style (0 = butt, 1 = round, 2 = square)
	public let lineCap: Int?

	/// Line join style (0 = miter, 1 = round, 2 = bevel)
	public let lineJoin: Int?

	/// Miter limit
	public let miterLimit: Double?

	/// Dash pattern: (phase, array)
	public let dashPattern: (Double, [Double])?

	/// Rendering intent
	public let renderingIntent: String?

	/// Overprint for stroking operations
	public let overprintStroking: Bool?

	/// Overprint for non-stroking operations
	public let overprintNonStroking: Bool?

	/// Overprint mode
	public let overprintMode: Int?

	/// Stroke adjustment
	public let strokeAdjustment: Bool?

	/// Flatness tolerance
	public let flatness: Double?

	/// Alpha is shape flag
	public let alphaIsShape: Bool?

	/// Text knockout flag
	public let textKnockout: Bool?

	/// Soft mask for transparency
	public let softMask: PdfSMask?

	/// Whether SMask was explicitly set to /None (to clear a previous mask)
	public let softMaskNone: Bool

	public init(dictionary: PdfDictionary, lookup: PdfObjectLookup?) {
		self.strokingAlpha = dictionary[.CA]?.real(lookup: lookup)
		self.nonStrokingAlpha = dictionary[.ca]?.real(lookup: lookup)

		if let bmName = dictionary[.BM]?.name(lookup: lookup) {
			self.blendMode = PdfBlendMode(rawValue: bmName)
		} else if let bmArray = dictionary[.BM]?.array(lookup: lookup),
				  let firstName = bmArray.first?.name(lookup: lookup) {
			// PDF allows an array of blend modes; use the first supported one
			self.blendMode = PdfBlendMode(rawValue: firstName)
		} else {
			self.blendMode = nil
		}

		self.lineWidth = dictionary[.LW]?.real(lookup: lookup)
		self.lineCap = dictionary[.LC]?.integer(lookup: lookup)
		self.lineJoin = dictionary[.LJ]?.integer(lookup: lookup)
		self.miterLimit = dictionary[.ML]?.real(lookup: lookup)

		if let dashArray = dictionary[.D]?.array(lookup: lookup), dashArray.count >= 2,
		   let dashValues = dashArray[0].array(lookup: lookup),
		   let phase = dashArray[1].real(lookup: lookup) {
			let lengths = dashValues.compactMap { $0.real(lookup: lookup) }
			self.dashPattern = (phase, lengths)
		} else {
			self.dashPattern = nil
		}

		self.renderingIntent = dictionary[.RI]?.name(lookup: lookup)
		self.overprintStroking = dictionary[.OP]?.boolean(lookup: lookup)
		self.overprintNonStroking = dictionary[.op]?.boolean(lookup: lookup)
		self.overprintMode = dictionary[.OPM]?.integer(lookup: lookup)
		self.strokeAdjustment = dictionary[.SA]?.boolean(lookup: lookup)
		self.flatness = dictionary[.FL]?.real(lookup: lookup)
		self.alphaIsShape = dictionary[.AIS]?.boolean(lookup: lookup)
		self.textKnockout = dictionary[.TK]?.boolean(lookup: lookup)

		// Parse SMask
		if let smaskObj = dictionary[.SMask] {
			if smaskObj.name(lookup: lookup) == .None {
				// SMask /None explicitly clears the soft mask
				self.softMask = nil
				self.softMaskNone = true
			} else if let smaskDict = smaskObj.dictionary(lookup: lookup) {
				self.softMask = PdfSMask(dictionary: smaskDict, lookup: lookup)
				self.softMaskNone = false
			} else {
				self.softMask = nil
				self.softMaskNone = false
			}
		} else {
			self.softMask = nil
			self.softMaskNone = false
		}
	}
}

/// PDF blend modes that map to CGBlendMode
public enum PdfBlendMode: String, Sendable {
	case normal = "Normal"
	case multiply = "Multiply"
	case screen = "Screen"
	case overlay = "Overlay"
	case darken = "Darken"
	case lighten = "Lighten"
	case colorDodge = "ColorDodge"
	case colorBurn = "ColorBurn"
	case hardLight = "HardLight"
	case softLight = "SoftLight"
	case difference = "Difference"
	case exclusion = "Exclusion"
	case hue = "Hue"
	case saturation = "Saturation"
	case color = "Color"
	case luminosity = "Luminosity"
}
