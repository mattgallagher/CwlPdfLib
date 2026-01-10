// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

/// The subtype of a soft mask, determining how the mask values are derived.
public enum PdfSMaskSubtype: String, Sendable {
	/// Use the alpha channel of the transparency group
	case alpha = "Alpha"
	/// Convert RGB values to luminosity for the mask
	case luminosity = "Luminosity"
}

/// Represents a PDF Soft Mask dictionary used in ExtGState.
/// This is different from PdfImage.softMask which is just a stream reference.
public struct PdfSMask: Sendable {
	/// Required: The subtype determining how mask values are derived
	public let subtype: PdfSMaskSubtype

	/// Required: The transparency group XObject (Form XObject with /Group dictionary)
	public let transparencyGroup: PdfStream

	/// Optional: Backdrop color array (in the transparency group's color space)
	public let backdropColor: [Double]?

	/// Optional: Transfer function (stream or name)
	public let transferFunction: PdfObject?

	public init?(dictionary: PdfDictionary, lookup: PdfObjectLookup?) {
		// Parse /S (Subtype) - required
		guard let subtypeName = dictionary[.S]?.name(lookup: lookup),
			  let subtype = PdfSMaskSubtype(rawValue: subtypeName) else {
			return nil
		}
		self.subtype = subtype

		// Parse /G - required transparency group stream
		guard let groupStream = dictionary[.G]?.stream(lookup: lookup) else {
			return nil
		}
		self.transparencyGroup = groupStream

		// Parse /BC - optional backdrop color
		self.backdropColor = dictionary[.BC]?.array(lookup: lookup)?
			.compactMap { $0.real(lookup: lookup) }

		// Parse /TR - optional transfer function
		self.transferFunction = dictionary[.TR]
	}
}
