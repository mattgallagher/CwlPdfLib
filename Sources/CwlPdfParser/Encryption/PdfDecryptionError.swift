// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Errors that can occur during PDF decryption.
public enum PdfDecryptionError: Error, Sendable {
	/// The provided password is incorrect.
	case invalidPassword

	/// The encryption dictionary is malformed or missing required fields.
	case invalidEncryptionDictionary(String)

	/// The document ID is missing from the trailer.
	case missingDocumentId

	/// Unsupported encryption version.
	case unsupportedEncryptionVersion(Int)

	/// Unsupported security handler revision.
	case unsupportedRevision(Int)

	/// Unknown crypt filter name.
	case unknownCryptFilter(String)

	/// Ciphertext is invalid (wrong length, missing IV, etc.).
	case invalidCiphertext

	/// Decryption operation failed.
	case decryptionFailed

	/// Password required but not provided.
	case passwordRequired
}
