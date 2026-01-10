// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import CryptoKit
import Foundation

/// Key derivation utilities for PDF encryption.
/// Implements algorithms from PDF Reference 1.7, Section 3.5.
enum PdfKeyDerivation {
	// MARK: - Password Padding (PDF Reference Table 3.19)

	/// 32-byte padding string used in PDF password processing.
	static let passwordPadding: [UInt8] = [
		0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41,
		0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
		0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80,
		0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A
	]

	/// Pad or truncate password to 32 bytes using the PDF padding string.
	static func padPassword(_ password: String) -> Data {
		var paddedPassword = Data(password.utf8.prefix(32))
		if paddedPassword.count < 32 {
			paddedPassword.append(contentsOf: passwordPadding.prefix(32 - paddedPassword.count))
		}
		return paddedPassword
	}

	// MARK: - Algorithm 2: Computing encryption key (R=2,3,4)

	/// Compute the file encryption key for revision 2, 3, or 4.
	/// - Parameters:
	///   - password: The user or owner password
	///   - ownerKey: The O value from the encryption dictionary
	///   - permissions: The P value (permissions flags)
	///   - documentId: The first element of the ID array from the trailer
	///   - keyLength: The key length in bits (40-128)
	///   - revision: The security handler revision (2, 3, or 4)
	///   - encryptMetadata: Whether metadata is encrypted
	/// - Returns: The file encryption key
	static func computeFileEncryptionKey(
		password: String,
		ownerKey: Data,
		permissions: Int32,
		documentId: Data,
		keyLength: Int,
		revision: Int,
		encryptMetadata: Bool
	) -> Data {
		var md5 = Insecure.MD5()

		// Step a: Pad password to 32 bytes
		let paddedPassword = padPassword(password)
		md5.update(data: paddedPassword)

		// Step b: Pass O value
		md5.update(data: ownerKey)

		// Step c: Pass P value (low-order 4 bytes, little-endian)
		withUnsafeBytes(of: permissions.littleEndian) { md5.update(bufferPointer: $0) }

		// Step d: Pass document ID
		md5.update(data: documentId)

		// Step e: (R >= 4) If not encrypting metadata, pass 0xFFFFFFFF
		if revision >= 4, !encryptMetadata {
			md5.update(data: Data([0xFF, 0xFF, 0xFF, 0xFF]))
		}

		var digest = Data(md5.finalize())

		// Step f: (R >= 3) Do 50 additional MD5 rounds
		if revision >= 3 {
			let keyBytes = keyLength / 8
			for _ in 0..<50 {
				var md5Inner = Insecure.MD5()
				md5Inner.update(data: digest.prefix(keyBytes))
				digest = Data(md5Inner.finalize())
			}
		}

		// Return first n bytes where n = keyLength/8
		return Data(digest.prefix(keyLength / 8))
	}

	// MARK: - Algorithm 2.A: Computing encryption key (R=5,6 - AESV3)

	/// Compute the file encryption key for revision 5 or 6 (AESV3).
	/// - Parameters:
	///   - password: The password to try
	///   - ownerKey: The O value (48 bytes)
	///   - userKey: The U value (48 bytes)
	///   - ownerEncryption: The OE value (32 bytes)
	///   - userEncryption: The UE value (32 bytes)
	///   - isOwner: Whether to try as owner password
	/// - Returns: The 32-byte file encryption key
	/// - Throws: `PdfDecryptionError.invalidPassword` if password verification fails
	static func computeFileEncryptionKeyAESV3(
		password: String,
		ownerKey: Data,
		userKey: Data,
		ownerEncryption: Data,
		userEncryption: Data,
		isOwner: Bool
	) throws -> Data {
		let passwordData = Data(password.utf8.prefix(127))

		if isOwner {
			// Try owner password
			// Validation: SHA-256(password || O[32:40] || U)
			let validationSalt = ownerKey[32..<40]
			let keySalt = ownerKey[40..<48]

			var sha = SHA256()
			sha.update(data: passwordData)
			sha.update(data: validationSalt)
			sha.update(data: userKey)
			let hash = Data(sha.finalize())

			// Check against O[0:32]
			guard hash == ownerKey.prefix(32) else {
				throw PdfDecryptionError.invalidPassword
			}

			// Derive key: SHA-256(password || keySalt || U)
			var keySha = SHA256()
			keySha.update(data: passwordData)
			keySha.update(data: keySalt)
			keySha.update(data: userKey)
			let intermediateKey = Data(keySha.finalize())

			// Decrypt OE with AES-256 CBC (zero IV)
			return try AESDecryption.decryptAES256CBCWithIV(
				data: ownerEncryption,
				key: intermediateKey,
				iv: Data(count: 16)
			)
		} else {
			// Try user password
			// Validation: SHA-256(password || U[32:40])
			let validationSalt = userKey[32..<40]
			let keySalt = userKey[40..<48]

			var sha = SHA256()
			sha.update(data: passwordData)
			sha.update(data: validationSalt)
			let hash = Data(sha.finalize())

			// Check against U[0:32]
			guard hash == userKey.prefix(32) else {
				throw PdfDecryptionError.invalidPassword
			}

			// Derive key: SHA-256(password || keySalt)
			var keySha = SHA256()
			keySha.update(data: passwordData)
			keySha.update(data: keySalt)
			let intermediateKey = Data(keySha.finalize())

			// Decrypt UE with AES-256 CBC (zero IV)
			return try AESDecryption.decryptAES256CBCWithIV(
				data: userEncryption,
				key: intermediateKey,
				iv: Data(count: 16)
			)
		}
	}

	// MARK: - Algorithm 4: Computing U value (R=2)

	/// Compute the expected U value for revision 2 (for password verification).
	/// - Parameters:
	///   - fileEncryptionKey: The computed file encryption key
	/// - Returns: The expected 32-byte U value
	static func computeUserKeyR2(fileEncryptionKey: Data) -> Data {
		RC4.process(data: Data(passwordPadding), key: fileEncryptionKey)
	}

	// MARK: - Algorithm 5: Computing U value (R=3,4)

	/// Compute the expected U value for revision 3 or 4 (for password verification).
	/// - Parameters:
	///   - fileEncryptionKey: The computed file encryption key
	///   - documentId: The first element of the ID array
	/// - Returns: The expected 16-byte U value (first 16 bytes of full U)
	static func computeUserKeyR3R4(fileEncryptionKey: Data, documentId: Data) -> Data {
		// MD5(padding || documentId)
		var md5 = Insecure.MD5()
		md5.update(data: Data(passwordPadding))
		md5.update(data: documentId)
		var digest = Data(md5.finalize())

		// 20 iterations of RC4 with modified keys
		for i in 0..<20 {
			let iterKey = Data(fileEncryptionKey.map { $0 ^ UInt8(i) })
			digest = RC4.process(data: digest, key: iterKey)
		}

		return digest
	}

	// MARK: - Algorithm 1: Object Key Derivation

	/// Derive the encryption key for a specific object.
	/// - Parameters:
	///   - fileKey: The file encryption key
	///   - objectNumber: The object number
	///   - generation: The generation number
	///   - isAES: Whether AES encryption is used (adds "sAlT" marker)
	/// - Returns: The object-specific encryption key
	static func deriveObjectKey(
		fileKey: Data,
		objectNumber: Int,
		generation: Int,
		isAES: Bool
	) -> Data {
		var md5 = Insecure.MD5()
		md5.update(data: fileKey)

		// Append object number (3 bytes, little-endian)
		let objBytes: [UInt8] = [
			UInt8(objectNumber & 0xFF),
			UInt8((objectNumber >> 8) & 0xFF),
			UInt8((objectNumber >> 16) & 0xFF)
		]
		md5.update(data: Data(objBytes))

		// Append generation (2 bytes, little-endian)
		let genBytes: [UInt8] = [
			UInt8(generation & 0xFF),
			UInt8((generation >> 8) & 0xFF)
		]
		md5.update(data: Data(genBytes))

		// For AES, append "sAlT" marker
		if isAES {
			md5.update(data: Data([0x73, 0x41, 0x6C, 0x54])) // "sAlT"
		}

		let digest = Data(md5.finalize())

		// Key length is min(fileKey.count + 5, 16)
		let keyLength = min(fileKey.count + 5, 16)
		return Data(digest.prefix(keyLength))
	}
}
