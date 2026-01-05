// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Represents a single PDF content stream operator and its operands.
/// The enum cases are named exactly as the operator symbols defined in Annex A of ISO 32000‑2.
public enum PdfOperator: Sendable, Equatable {
	// Graphics State
	case q
	case Q
	case cm([PdfObject])
	case w(PdfObject)
	case J(Int)
	case j(Int)
	case M(PdfObject)
	case d([PdfObject])
	case ri(Int)
	case i(PdfObject)
	case gs(String)
	
	// Path Construction
	case m([PdfObject])
	case l([PdfObject])
	case c([PdfObject])
	case v([PdfObject])
	case y([PdfObject])
	case h
	case re([PdfObject])
	
	// Path Painting
	case S
	case s
	case f
	case F
	case fstar
	case Bstar
	case bstar
	case b
	case B
	case n
	
	// Clipping Paths
	case W
	case Wstar
	
	// Color Operators
	case CS(String)
	case cs(String)
	case SC([PdfObject])
	case SCN([PdfObject])
	case sc([PdfObject])
	case scn([PdfObject])
	case G(PdfObject)
	case g(PdfObject)
	case RG([PdfObject])
	case rg([PdfObject])
	case K([PdfObject])
	case k([PdfObject])
	case sh(String)
	
	// Text State
	case Tc(PdfObject)
	case Tw(PdfObject)
	case Tz(PdfObject)
	case TL(PdfObject)
	case Tf(String, PdfObject)
	case Tr(Int)
	case Ts(PdfObject)
	
	// Text Positioning
	case Td([PdfObject])
	case TD([PdfObject])
	case Tm([PdfObject])
	case Tstar
	
	// Text Showing
	case Tj(String)
	case TJ([PdfObject])
	case quote(String)
	case doublequote([PdfObject])
	
	// Text Object
	case BT
	case ET
	
	// Type 3 Font
	case d0
	case d1(String)
	
	// XObject
	case Do(String)
	
	// Inline Image
	case BI
	case ID
	case EI
	
	// Marked Content
	case MP(String)
	case DP(String, PdfDictionary)
	case BDC(String, PdfDictionary)
	case BMC(String)
	case EMC
	
	// Compatibility
	case BX
	case EX
}
