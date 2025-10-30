// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension RandomAccessCollection where Element == UInt8 {
	func utf8() -> String {
		String(decoding: self, as: UTF8.self)
	}

	func pdfText() -> String {
		// Check for UTF-16BE BOM
		if self.starts(with: [0xFE, 0xFF]), let result = String(bytes: self.dropFirst(2), encoding: .utf16BigEndian) {
			return result
		}
		// Check for UTF-16LE BOM
		else if self.starts(with: [0xFF, 0xFE]), let result = String(bytes: self.dropFirst(2), encoding: .utf16LittleEndian) {
			return result
		}
		// Check for UTF-8 BOM
		else if self.starts(with: [0xEF, 0xBB, 0xBF]), let result = String(bytes: self.dropFirst(3), encoding: .utf8) {
			return result
		}
		// Use PDFDocEncoding
		return String(String.UnicodeScalarView(map(pdfDocEncodingToUnicodeScalar)))
	}
}

extension String {
	func pdfData() -> Data {
		return Data(unicodeScalars.map(unicodeScalarToPdfDocEncoding))
	}
}

func pdfDocEncodingToUnicodeScalar(_ byte: UInt8) -> UnicodeScalar {
	switch byte {
	case 0x00...0x17: return UnicodeScalar(byte) // Direct mapping for control characters
	case 0x20...0x7D: return UnicodeScalar(byte) // Direct mapping for ASCII range
	case 0xA1...0xAC: return UnicodeScalar(byte) // Direct mapping for Windows Latin-1 range
	case 0xAE...0xFF: return UnicodeScalar(byte) // Direct mapping for Windows Latin-1 range
	case 0x18: return "\u{02D8}" // Breve
	case 0x19: return "\u{02C7}" // Caron
	case 0x1A: return "\u{02C6}" // Modifier Letter Circumflex Accent
	case 0x1B: return "\u{02D9}" // Dot Above
	case 0x1C: return "\u{02DD}" // Double Acute Accent
	case 0x1D: return "\u{02DB}" // Ogonek
	case 0x1E: return "\u{02DA}" // Ring Above
	case 0x1F: return "\u{02DC}" // Small Tilde
	case 0x80: return "\u{2022}" // Bullet
	case 0x81: return "\u{2020}" // Dagger
	case 0x82: return "\u{2021}" // Double Dagger
	case 0x83: return "\u{2026}" // Horizontal Ellipsis
	case 0x84: return "\u{2014}" // Em Dash
	case 0x85: return "\u{2013}" // En Dash
	case 0x86: return "\u{0192}" // Latin Small Letter F with Hook
	case 0x87: return "\u{2044}" // Fraction Slash
	case 0x88: return "\u{2039}" // Single Left-Pointing Angle Quotation Mark
	case 0x89: return "\u{203A}" // Single Right-Pointing Angle Quotation Mark
	case 0x8A: return "\u{2212}" // Latin Small Letter S with Caron
	case 0x8B: return "\u{2030}" // Per Mille Sign
	case 0x8C: return "\u{201E}" // Double Low-9 Quotation Mark
	case 0x8D: return "\u{201C}" // Left Double Quotation Mark
	case 0x8E: return "\u{201D}" // Right Double Quotation Mark
	case 0x8F: return "\u{2018}" // Left Single Quotation Mark
	case 0x90: return "\u{2019}" // Right Single Quotation Mark
	case 0x91: return "\u{201A}" // Single Low-9 Quotation Mark
	case 0x92: return "\u{2122}" // Trade Mark Sign
	case 0x93: return "\u{FB01}" // Latin Small Ligature Fi
	case 0x94: return "\u{FB02}" // Latin Small Ligature Fl
	case 0x95: return "\u{0141}" // Latin Capital Letter L with Stroke
	case 0x96: return "\u{0152}" // Latin Capital Ligature Oe
	case 0x97: return "\u{0160}" // Latin Capital Letter S with Caron
	case 0x98: return "\u{0178}" // Latin Capital Letter Y with Diaeresis
	case 0x99: return "\u{017D}" // Latin Capital Letter Z with Caron
	case 0x9A: return "\u{0131}" // Latin Small Letter Dotless I
	case 0x9B: return "\u{0142}" // Latin Small Letter L with Stroke
	case 0x9C: return "\u{0153}" // Latin Small Ligature Oe
	case 0x9D: return "\u{0161}" // Latin Small Letter S with Caron
	case 0x9E: return "\u{017E}" // Latin Small Letter Z with Caron
	case 0xA0: return "\u{20A2}" // Euro Sign
	default: // 0x7F, 0x9F, 0xAD
		return UnicodeScalar(byte) // Direct mapping for undefined chars
	}
}

func unicodeScalarToPdfDocEncoding(_ scalar: UnicodeScalar) -> UInt8 {
	switch scalar.value {
	case 0x00...0x17: return UInt8(scalar.value) // Direct mapping for control characters
	case 0x20...0x7D: return UInt8(scalar.value) // Direct mapping for ASCII range
	case 0xA1...0xAC: return UInt8(scalar.value) // Direct mapping for Windows Latin-1 range
	case 0xAE...0xFF: return UInt8(scalar.value) // Direct mapping for Windows Latin-1 range
	case 0x02D8: return 0x18 // Breve
	case 0x02C7: return 0x19 // Caron
	case 0x02C6: return 0x1A // Modifier Letter Circumflex Accent
	case 0x02D9: return 0x1B // Dot Above
	case 0x02DD: return 0x1C // Double Acute Accent
	case 0x02DB: return 0x1D // Ogonek
	case 0x02DA: return 0x1E // Ring Above
	case 0x02DC: return 0x1F // Small Tilde
	case 0x2022: return 0x80 // Bullet
	case 0x2020: return 0x81 // Dagger
	case 0x2021: return 0x82 // Double Dagger
	case 0x2026: return 0x83 // Horizontal Ellipsis
	case 0x2014: return 0x84 // Em Dash
	case 0x2013: return 0x85 // En Dash
	case 0x0192: return 0x86 // Latin Small Letter F with Hook
	case 0x2044: return 0x87 // Fraction Slash
	case 0x2039: return 0x88 // Single Left-Pointing Angle Quotation Mark
	case 0x203A: return 0x89 // Single Right-Pointing Angle Quotation Mark
	case 0x2212: return 0x8A // Latin Small Letter S with Caron
	case 0x2030: return 0x8B // Per Mille Sign
	case 0x201E: return 0x8C // Double Low-9 Quotation Mark
	case 0x201C: return 0x8D // Left Double Quotation Mark
	case 0x201D: return 0x8E // Right Double Quotation Mark
	case 0x2018: return 0x8F // Left Single Quotation Mark
	case 0x2019: return 0x90 // Right Single Quotation Mark
	case 0x201A: return 0x91 // Single Low-9 Quotation Mark
	case 0x2122: return 0x92 // Trade Mark Sign
	case 0xFB01: return 0x93 // Latin Small Ligature Fi
	case 0xFB02: return 0x94 // Latin Small Ligature Fl
	case 0x0141: return 0x95 // Latin Capital Letter L with Stroke
	case 0x0152: return 0x96 // Latin Capital Ligature Oe
	case 0x0160: return 0x97 // Latin Capital Letter S with Caron
	case 0x0178: return 0x98 // Latin Capital Letter Y with Diaeresis
	case 0x017D: return 0x99 // Latin Capital Letter Z with Caron
	case 0x0131: return 0x9A // Latin Small Letter Dotless I
	case 0x0142: return 0x9B // Latin Small Letter L with Stroke
	case 0x0153: return 0x9C // Latin Small Ligature Oe
	case 0x0161: return 0x9D // Latin Small Letter S with Caron
	case 0x017E: return 0x9E // Latin Small Letter Z with Caron
	case 0x20A2: return 0xA0 // Euro Sign
	default:
		return UInt8(UnicodeScalar("X").value) // Emit uppercase X as replacement char
	}
}
