// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Represents a crypt filter method used for encryption.
public enum PdfCryptMethod: Sendable, Hashable {
	/// No encryption (Identity filter).
	case none

	/// RC4 encryption with specified key length in bits (40-128).
	case v2(keyLength: Int)

	/// AES-128-CBC encryption.
	case aesv2

	/// AES-256-CBC encryption.
	case aesv3
}

/// Main decryption handler for encrypted PDF documents.
/// This type is immutable and Sendable for thread-safe concurrent use.
public struct PdfDecryption: Sendable {
	/// The computed file encryption key.
	private let fileEncryptionKey: Data

	/// The encryption version (V value).
	let version: Int

	/// The security handler revision (R value).
	let revision: Int

	/// The default crypt method for streams.
	let streamCryptMethod: PdfCryptMethod

	/// The default crypt method for strings.
	let stringCryptMethod: PdfCryptMethod

	/// Whether metadata streams should be encrypted.
	let encryptMetadata: Bool

	/// The object identifier of the encryption dictionary itself (never decrypted).
	let encryptionDictionaryId: PdfObjectIdentifier?

	/// Named crypt filters from the CF dictionary.
	private let cryptFilters: [String: PdfCryptMethod]

	/// Initialize decryption from encryption dictionary and optional password.
	/// - Parameters:
	///   - encryptDictionary: The encryption dictionary from the trailer
	///   - trailer: The document trailer dictionary
	///   - encryptionDictionaryId: The object identifier of the encryption dictionary (if indirect)
	///   - password: The document password (nil to try empty password first)
	/// - Throws: `PdfDecryptionError` if decryption setup fails
	public init(
		encryptDictionary: PdfDictionary,
		trailer: PdfDictionary,
		encryptionDictionaryId: PdfObjectIdentifier?,
		password: String?
	) throws {
		self.encryptionDictionaryId = encryptionDictionaryId

		// Parse encryption version
		guard let version = encryptDictionary[.V]?.integer(lookup: nil) else {
			throw PdfDecryptionError.invalidEncryptionDictionary("Missing V value")
		}
		self.version = version

		// Parse revision
		guard let revision = encryptDictionary[.R]?.integer(lookup: nil) else {
			throw PdfDecryptionError.invalidEncryptionDictionary("Missing R value")
		}
		self.revision = revision

		// Parse required encryption values
		guard let ownerKey = encryptDictionary[.O]?.string(lookup: nil) else {
			throw PdfDecryptionError.invalidEncryptionDictionary("Missing O value")
		}
		guard let userKey = encryptDictionary[.U]?.string(lookup: nil) else {
			throw PdfDecryptionError.invalidEncryptionDictionary("Missing U value")
		}
		guard let permissions = encryptDictionary[.P]?.integer(lookup: nil) else {
			throw PdfDecryptionError.invalidEncryptionDictionary("Missing P value")
		}

		// Get document ID from trailer
		guard
			let idArray = trailer[.ID]?.array(lookup: nil),
			let documentId = idArray.first?.string(lookup: nil)
		else {
			throw PdfDecryptionError.missingDocumentId
		}

		// Parse EncryptMetadata (default true)
		self.encryptMetadata = encryptDictionary[.EncryptMetadata]?.boolean(lookup: nil) ?? true

		// Determine key length
		let keyLength: Int = if let length = encryptDictionary[.Length]?.integer(lookup: nil) {
			length
		} else if version == 1 {
			40
		} else if revision >= 5 {
			256
		} else {
			128
		}

		// Parse crypt filters for V4+
		var cryptFilters: [String: PdfCryptMethod] = [:]
		if version >= 4 {
			if let cfDict = encryptDictionary[.CF]?.dictionary(lookup: nil) {
				for (name, filterObj) in cfDict {
					if
						let filterDict = filterObj.dictionary(lookup: nil),
						let cfm = filterDict[.CFM]?.name(lookup: nil)
					{
						// Check AuthEvent (only DocOpen is supported)
						if let authEvent = filterDict[.AuthEvent]?.name(lookup: nil), authEvent != .DocOpen {
							continue // Skip non-DocOpen filters
						}
						cryptFilters[name] = try Self.parseCryptMethod(cfm, keyLength: keyLength)
					}
				}
			}
		}
		self.cryptFilters = cryptFilters

		// Determine default stream/string crypt methods
		if version >= 4 {
			let stmfName = encryptDictionary[.StmF]?.name(lookup: nil) ?? .Identity
			let strfName = encryptDictionary[.StrF]?.name(lookup: nil) ?? .Identity

			if stmfName == .Identity {
				self.streamCryptMethod = .none
			} else if let method = cryptFilters[stmfName] {
				self.streamCryptMethod = method
			} else {
				throw PdfDecryptionError.unknownCryptFilter(stmfName)
			}

			if strfName == .Identity {
				self.stringCryptMethod = .none
			} else if let method = cryptFilters[strfName] {
				self.stringCryptMethod = method
			} else {
				throw PdfDecryptionError.unknownCryptFilter(strfName)
			}
		} else if version == 2 || version == 3 {
			// V2/V3: RC4 encryption
			self.streamCryptMethod = .v2(keyLength: keyLength)
			self.stringCryptMethod = .v2(keyLength: keyLength)
		} else if version == 1 {
			// V1: 40-bit RC4
			self.streamCryptMethod = .v2(keyLength: 40)
			self.stringCryptMethod = .v2(keyLength: 40)
		} else {
			throw PdfDecryptionError.unsupportedEncryptionVersion(version)
		}

		// Compute file encryption key and verify password
		let passwordToTry = password ?? ""

		if revision >= 5 {
			// AESV3 (R=5,6)
			guard
				let ownerEncryption = encryptDictionary[.OE]?.string(lookup: nil),
				let userEncryption = encryptDictionary[.UE]?.string(lookup: nil)
			else {
				throw PdfDecryptionError.invalidEncryptionDictionary("Missing OE or UE value for R>=5")
			}

			// Try user password first, then owner
			do {
				self.fileEncryptionKey = try PdfKeyDerivation.computeFileEncryptionKeyAESV3(
					password: passwordToTry,
					ownerKey: ownerKey,
					userKey: userKey,
					ownerEncryption: ownerEncryption,
					userEncryption: userEncryption,
					isOwner: false
				)
			} catch PdfDecryptionError.invalidPassword {
				// Try as owner password
				self.fileEncryptionKey = try PdfKeyDerivation.computeFileEncryptionKeyAESV3(
					password: passwordToTry,
					ownerKey: ownerKey,
					userKey: userKey,
					ownerEncryption: ownerEncryption,
					userEncryption: userEncryption,
					isOwner: true
				)
			}
		} else {
			// R=2,3,4: MD5-based key derivation
			let fileKey = PdfKeyDerivation.computeFileEncryptionKey(
				password: passwordToTry,
				ownerKey: ownerKey,
				permissions: Int32(truncatingIfNeeded: permissions),
				documentId: documentId,
				keyLength: keyLength,
				revision: revision,
				encryptMetadata: encryptMetadata
			)

			// Verify password by computing expected U value
			let expectedU: Data
			if revision == 2 {
				expectedU = PdfKeyDerivation.computeUserKeyR2(fileEncryptionKey: fileKey)
				guard expectedU == userKey else {
					throw PdfDecryptionError.invalidPassword
				}
			} else {
				expectedU = PdfKeyDerivation.computeUserKeyR3R4(fileEncryptionKey: fileKey, documentId: documentId)
				// Only compare first 16 bytes for R=3,4
				guard expectedU == userKey.prefix(16) else {
					throw PdfDecryptionError.invalidPassword
				}
			}

			self.fileEncryptionKey = fileKey
		}
	}

	/// Parse a CFM value into a PdfCryptMethod.
	private static func parseCryptMethod(_ cfm: String, keyLength: Int) throws -> PdfCryptMethod {
		switch cfm {
		case .None, .Identity:
			return .none
		case "V2":
			return .v2(keyLength: keyLength)
		case .AESV2:
			return .aesv2
		case .AESV3:
			return .aesv3
		default:
			throw PdfDecryptionError.unknownCryptFilter(cfm)
		}
	}

	/// Check if an object should be decrypted.
	/// - Parameter objectId: The object identifier to check
	/// - Returns: `true` if the object should be decrypted
	public func shouldDecrypt(objectId: PdfObjectIdentifier) -> Bool {
		// Don't decrypt the encryption dictionary itself
		if let encryptionDictionaryId, objectId == encryptionDictionaryId {
			return false
		}
		return true
	}

	/// Decrypt stream data for a specific object.
	/// - Parameters:
	///   - data: The encrypted stream data
	///   - objectId: The object identifier
	///   - cryptFilterName: Optional explicit crypt filter name from DecodeParms
	/// - Returns: The decrypted data
	/// - Throws: `PdfDecryptionError` if decryption fails
	public func decryptStream(
		data: Data,
		objectId: PdfObjectIdentifier,
		cryptFilterName: String?
	) throws -> Data {
		guard shouldDecrypt(objectId: objectId) else {
			return data
		}

		let method: PdfCryptMethod
		if let filterName = cryptFilterName {
			if filterName == .Identity {
				return data
			} else if let filter = cryptFilters[filterName] {
				method = filter
			} else {
				method = streamCryptMethod
			}
		} else {
			method = streamCryptMethod
		}

		return try decrypt(data: data, objectId: objectId, method: method)
	}

	/// Decrypt string data for a specific object.
	/// - Parameters:
	///   - data: The encrypted string data
	///   - objectId: The object identifier
	/// - Returns: The decrypted data
	/// - Throws: `PdfDecryptionError` if decryption fails
	public func decryptString(
		data: Data,
		objectId: PdfObjectIdentifier
	) throws -> Data {
		guard shouldDecrypt(objectId: objectId) else {
			return data
		}
		return try decrypt(data: data, objectId: objectId, method: stringCryptMethod)
	}

	/// Internal decryption using the specified method.
	private func decrypt(data: Data, objectId: PdfObjectIdentifier, method: PdfCryptMethod) throws -> Data {
		guard !data.isEmpty else { return data }

		switch method {
		case .none:
			return data

		case .v2:
			// RC4: derive object key and decrypt
			let objectKey = PdfKeyDerivation.deriveObjectKey(
				fileKey: fileEncryptionKey,
				objectNumber: objectId.number,
				generation: objectId.generation,
				isAES: false
			)
			return RC4.process(data: data, key: objectKey)

		case .aesv2:
			// AES-128: derive object key and decrypt
			let objectKey = PdfKeyDerivation.deriveObjectKey(
				fileKey: fileEncryptionKey,
				objectNumber: objectId.number,
				generation: objectId.generation,
				isAES: true
			)
			return try AESDecryption.decryptAES128CBC(data: data, key: objectKey)

		case .aesv3:
			// AES-256: use file key directly (no object key derivation)
			return try AESDecryption.decryptAES256CBC(data: data, key: fileEncryptionKey)
		}
	}
}
