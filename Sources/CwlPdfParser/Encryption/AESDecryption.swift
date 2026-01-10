// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CommonCrypto
import Foundation

/// AES-CBC decryption utilities using CommonCrypto.
enum AESDecryption {
	/// Decrypt AES-128-CBC with IV prepended to ciphertext.
	/// - Parameters:
	///   - data: The encrypted data (16-byte IV followed by ciphertext)
	///   - key: The 16-byte AES key
	/// - Returns: The decrypted data
	/// - Throws: `PdfDecryptionError` if decryption fails
	static func decryptAES128CBC(data: Data, key: Data) throws -> Data {
		guard data.count >= 16 else {
			throw PdfDecryptionError.invalidCiphertext
		}
		let iv = data.prefix(16)
		let ciphertext = data.dropFirst(16)
		return try decryptCBC(ciphertext: Data(ciphertext), key: key, iv: Data(iv))
	}

	/// Decrypt AES-256-CBC with IV prepended to ciphertext.
	/// - Parameters:
	///   - data: The encrypted data (16-byte IV followed by ciphertext)
	///   - key: The 32-byte AES key
	/// - Returns: The decrypted data
	/// - Throws: `PdfDecryptionError` if decryption fails
	static func decryptAES256CBC(data: Data, key: Data) throws -> Data {
		guard data.count >= 16 else {
			throw PdfDecryptionError.invalidCiphertext
		}
		let iv = data.prefix(16)
		let ciphertext = data.dropFirst(16)
		return try decryptCBC(ciphertext: Data(ciphertext), key: key, iv: Data(iv))
	}

	/// Decrypt AES-256-CBC with explicit IV (used for key derivation).
	/// - Parameters:
	///   - data: The ciphertext (no IV prefix)
	///   - key: The 32-byte AES key
	///   - iv: The 16-byte initialization vector
	/// - Returns: The decrypted data
	/// - Throws: `PdfDecryptionError` if decryption fails
	static func decryptAES256CBCWithIV(data: Data, key: Data, iv: Data) throws -> Data {
		try decryptCBC(ciphertext: data, key: key, iv: iv)
	}

	/// Internal CBC decryption using CommonCrypto.
	private static func decryptCBC(ciphertext: Data, key: Data, iv: Data) throws -> Data {
		// Handle empty ciphertext
		guard !ciphertext.isEmpty else {
			return Data()
		}

		// Ciphertext must be a multiple of block size for CBC
		guard ciphertext.count % kCCBlockSizeAES128 == 0 else {
			throw PdfDecryptionError.invalidCiphertext
		}

		// Allocate buffer for decrypted data (same size as ciphertext, may be smaller after padding removal)
		let bufferSize = ciphertext.count + kCCBlockSizeAES128
		var decrypted = Data(count: bufferSize)
		var numBytesDecrypted = 0

		let status = decrypted.withUnsafeMutableBytes { decryptedPtr in
			ciphertext.withUnsafeBytes { ciphertextPtr in
				key.withUnsafeBytes { keyPtr in
					iv.withUnsafeBytes { ivPtr in
						CCCrypt(
							CCOperation(kCCDecrypt),
							CCAlgorithm(kCCAlgorithmAES),
							CCOptions(kCCOptionPKCS7Padding),
							keyPtr.baseAddress, key.count,
							ivPtr.baseAddress,
							ciphertextPtr.baseAddress, ciphertext.count,
							decryptedPtr.baseAddress, bufferSize,
							&numBytesDecrypted
						)
					}
				}
			}
		}

		guard status == kCCSuccess else {
			throw PdfDecryptionError.decryptionFailed
		}

		decrypted.count = numBytesDecrypted
		return decrypted
	}
}
