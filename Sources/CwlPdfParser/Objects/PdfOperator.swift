// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Represents a single PDF content stream operator and its operands.
/// The enum cases are named exactly as the operator symbols defined in Annex A of ISO 32000‑2.
public enum PdfOperator: Sendable, Equatable {
	case `'`(Data) // move to next line and show text
	case `"`(Data, Double, Double) // Set word and character spacing, move to next line and show text
	case B // fill, stroke
	case `B*` // eofill, stroke
	case b // closepath, fill, stroke
	case `b*` // closepath, eofill, stroke
	case BDC(PdfDictionary, String) // begin marked sequence with property list
	case BI // being inline image
	case BMC(String) // begin marked content sequence
	case BT // begin text object
	case BX // begin compatibility section
	case c(Double, Double, Double, Double, Double, Double) // cubic
	case cm(Double, Double, Double, Double, Double, Double)  // concat matrix
	case CS(String) // set colorspace
	case cs(String) // set colorspace non-stroking
	case d(Double, [Double]) // set dash 
	case d0 // set char width, Type 3 font
	case d1 // set glyph width, Type 3 font
	case Do(String) // draw XObject 
	case DP(PdfDictionary, String) // define marked content point with property list
	case EI // end inline image
	case EMC // end marked content sequence
	case ET // end text object
	case EX // end compatibility section
	case F // fill (obsolete)
	case f // fill
	case `f*` // eofill
	case G(Double) // set gray stroking
	case g(Double) // set gray non-stroking
	case gs(String) // set graphics state parameters
	case h // closepath
	case i(Double) // set flatness tolerance
	case ID // begin inline image data
	case J(Int) // set line cap
	case j(Int) // set line join
	case K(Double, Double, Double, Double) // set CMYK stroking
	case k(Double, Double, Double, Double) // set CMYK non-stroking
	case l(Double, Double) // lineto
	case M(Double) // set miter limit
	case m(Double, Double) // moveto
	case MP(String) // define marked content point
	case n // end path without painting
	case q // save graphics state
	case Q // restore graphics state
	case re(Double, Double, Double, Double) // append rectangle
	case RG(Double, Double, Double) // set RGB stroking
	case rg(Double, Double, Double) // set RGB non-stroking
	case ri(String) // set color rendering intent
	case S // stroke
	case s // closepath and stroke
	case SC([Double]) // set color stroking
	case sc([Double]) // set color non-stroking
	case SCN([Double]) // set color stroking (special)
	case scn([Double]) // set color non-stroking (special)
	case sh(String) // paint shading pattern
	case Tc(Double) // set character spacing
	case Td(Double, Double) // move text position
	case TD(Double, Double) // move text position and set leading
	case Tf(String, Double) // set text font and size
	case Tj(Data) // show text
	case TJ([TJElement]) // show text with individual glyph adjustments
	case TL(Double) // set text leading
	case Tm(Double, Double, Double, Double, Double, Double) // set text matrix
	case Tr(Int) // set text rendering mode
	case Ts(Double) // set text rise
	case Tw(Double) // set word spacing
	case Tz(Double) // set horizontal text scaling
	case `T*` // move to next line
	case v(Double, Double, Double, Double) // cubic bezier (current point)
	case w(Double) // set line width
	case W // clip path
	case `W*` // clip path even-odd
	case y(Double, Double, Double, Double) // cubic bezier (current and control)
}

public enum TJElement: Sendable, Equatable {
	case text(Data)
	case offset(Double)
}
