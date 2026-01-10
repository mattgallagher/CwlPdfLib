// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

extension RandomAccessCollection where Element == UInt8 {
	func utf8() -> String {
		String(decoding: self, as: UTF8.self)
	}
	
	var asBigEndianUInt32: UInt32 {
		var code: UInt32 = 0
		for byte in prefix(4) {
			code = (code << 8) + UInt32(byte)
		}
		return code
	}
}

public extension RandomAccessCollection where Element == UInt8 {
	func pdfTextToString() -> String {
		// Check for UTF-16BE BOM
		if starts(with: [0xFE, 0xFF]), let result = String(bytes: dropFirst(2), encoding: .utf16BigEndian) {
			return result
		}
		// Check for UTF-16LE BOM
		else if starts(with: [0xFF, 0xFE]), let result = String(bytes: dropFirst(2), encoding: .utf16LittleEndian) {
			return result
		}
		// Check for UTF-8 BOM
		else if starts(with: [0xEF, 0xBB, 0xBF]), let result = String(bytes: dropFirst(3), encoding: .utf8) {
			return result
		}
		// Use PDFDocEncoding
		return String(String.UnicodeScalarView(map(pdfDocEncodingToUnicodeScalar)))
	}
}

extension String {
	func toPdfText() -> Data {
		Data(unicodeScalars.map(unicodeScalarToPdfDocEncoding))
	}
}

func pdfDocEncodingToUnicodeScalar(_ byte: UInt8) -> UnicodeScalar {
	switch byte {
	case 0x00...0x17: UnicodeScalar(byte) // Direct mapping for control characters
	case 0x20...0x7D: UnicodeScalar(byte) // Direct mapping for ASCII range
	case 0xA1...0xAC: UnicodeScalar(byte) // Direct mapping for Windows Latin-1 range
	case 0xAE...0xFF: UnicodeScalar(byte) // Direct mapping for Windows Latin-1 range
	case 0x18: "\u{02D8}" // Breve
	case 0x19: "\u{02C7}" // Caron
	case 0x1A: "\u{02C6}" // Modifier Letter Circumflex Accent
	case 0x1B: "\u{02D9}" // Dot Above
	case 0x1C: "\u{02DD}" // Double Acute Accent
	case 0x1D: "\u{02DB}" // Ogonek
	case 0x1E: "\u{02DA}" // Ring Above
	case 0x1F: "\u{02DC}" // Small Tilde
	case 0x80: "\u{2022}" // Bullet
	case 0x81: "\u{2020}" // Dagger
	case 0x82: "\u{2021}" // Double Dagger
	case 0x83: "\u{2026}" // Horizontal Ellipsis
	case 0x84: "\u{2014}" // Em Dash
	case 0x85: "\u{2013}" // En Dash
	case 0x86: "\u{0192}" // Latin Small Letter F with Hook
	case 0x87: "\u{2044}" // Fraction Slash
	case 0x88: "\u{2039}" // Single Left-Pointing Angle Quotation Mark
	case 0x89: "\u{203A}" // Single Right-Pointing Angle Quotation Mark
	case 0x8A: "\u{2212}" // Latin Small Letter S with Caron
	case 0x8B: "\u{2030}" // Per Mille Sign
	case 0x8C: "\u{201E}" // Double Low-9 Quotation Mark
	case 0x8D: "\u{201C}" // Left Double Quotation Mark
	case 0x8E: "\u{201D}" // Right Double Quotation Mark
	case 0x8F: "\u{2018}" // Left Single Quotation Mark
	case 0x90: "\u{2019}" // Right Single Quotation Mark
	case 0x91: "\u{201A}" // Single Low-9 Quotation Mark
	case 0x92: "\u{2122}" // Trade Mark Sign
	case 0x93: "\u{FB01}" // Latin Small Ligature Fi
	case 0x94: "\u{FB02}" // Latin Small Ligature Fl
	case 0x95: "\u{0141}" // Latin Capital Letter L with Stroke
	case 0x96: "\u{0152}" // Latin Capital Ligature Oe
	case 0x97: "\u{0160}" // Latin Capital Letter S with Caron
	case 0x98: "\u{0178}" // Latin Capital Letter Y with Diaeresis
	case 0x99: "\u{017D}" // Latin Capital Letter Z with Caron
	case 0x9A: "\u{0131}" // Latin Small Letter Dotless I
	case 0x9B: "\u{0142}" // Latin Small Letter L with Stroke
	case 0x9C: "\u{0153}" // Latin Small Ligature Oe
	case 0x9D: "\u{0161}" // Latin Small Letter S with Caron
	case 0x9E: "\u{017E}" // Latin Small Letter Z with Caron
	case 0xA0: "\u{20A2}" // Euro Sign
	default: // 0x7F, 0x9F, 0xAD
		UnicodeScalar(byte) // Direct mapping for undefined chars
	}
}

func unicodeScalarToPdfDocEncoding(_ scalar: UnicodeScalar) -> UInt8 {
	switch scalar.value {
	case 0x00...0x17: UInt8(scalar.value) // Direct mapping for control characters
	case 0x20...0x7D: UInt8(scalar.value) // Direct mapping for ASCII range
	case 0xA1...0xAC: UInt8(scalar.value) // Direct mapping for Windows Latin-1 range
	case 0xAE...0xFF: UInt8(scalar.value) // Direct mapping for Windows Latin-1 range
	case 0x02D8: 0x18 // Breve
	case 0x02C7: 0x19 // Caron
	case 0x02C6: 0x1A // Modifier Letter Circumflex Accent
	case 0x02D9: 0x1B // Dot Above
	case 0x02DD: 0x1C // Double Acute Accent
	case 0x02DB: 0x1D // Ogonek
	case 0x02DA: 0x1E // Ring Above
	case 0x02DC: 0x1F // Small Tilde
	case 0x2022: 0x80 // Bullet
	case 0x2020: 0x81 // Dagger
	case 0x2021: 0x82 // Double Dagger
	case 0x2026: 0x83 // Horizontal Ellipsis
	case 0x2014: 0x84 // Em Dash
	case 0x2013: 0x85 // En Dash
	case 0x0192: 0x86 // Latin Small Letter F with Hook
	case 0x2044: 0x87 // Fraction Slash
	case 0x2039: 0x88 // Single Left-Pointing Angle Quotation Mark
	case 0x203A: 0x89 // Single Right-Pointing Angle Quotation Mark
	case 0x2212: 0x8A // Latin Small Letter S with Caron
	case 0x2030: 0x8B // Per Mille Sign
	case 0x201E: 0x8C // Double Low-9 Quotation Mark
	case 0x201C: 0x8D // Left Double Quotation Mark
	case 0x201D: 0x8E // Right Double Quotation Mark
	case 0x2018: 0x8F // Left Single Quotation Mark
	case 0x2019: 0x90 // Right Single Quotation Mark
	case 0x201A: 0x91 // Single Low-9 Quotation Mark
	case 0x2122: 0x92 // Trade Mark Sign
	case 0xFB01: 0x93 // Latin Small Ligature Fi
	case 0xFB02: 0x94 // Latin Small Ligature Fl
	case 0x0141: 0x95 // Latin Capital Letter L with Stroke
	case 0x0152: 0x96 // Latin Capital Ligature Oe
	case 0x0160: 0x97 // Latin Capital Letter S with Caron
	case 0x0178: 0x98 // Latin Capital Letter Y with Diaeresis
	case 0x017D: 0x99 // Latin Capital Letter Z with Caron
	case 0x0131: 0x9A // Latin Small Letter Dotless I
	case 0x0142: 0x9B // Latin Small Letter L with Stroke
	case 0x0153: 0x9C // Latin Small Ligature Oe
	case 0x0161: 0x9D // Latin Small Letter S with Caron
	case 0x017E: 0x9E // Latin Small Letter Z with Caron
	case 0x20A2: 0xA0 // Euro Sign
	default:
		UInt8(UnicodeScalar("X").value) // Emit uppercase X as replacement char
	}
}
