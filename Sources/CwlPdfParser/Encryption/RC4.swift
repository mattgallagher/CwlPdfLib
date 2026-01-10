// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Bespoke RC4 implementation for PDF decryption.
/// RC4 is a stream cipher where encryption and decryption are the same operation.
enum RC4 {
	/// Encrypt or decrypt data using RC4.
	/// - Parameters:
	///   - data: The data to process
	///   - key: The encryption key (1-256 bytes)
	/// - Returns: The processed data
	static func process(data: Data, key: Data) -> Data {
		guard !data.isEmpty, !key.isEmpty else { return data }

		// Key-scheduling algorithm (KSA)
		var state = [UInt8](repeating: 0, count: 256)
		for i in 0..<256 {
			state[i] = UInt8(i)
		}

		var j = 0
		for i in 0..<256 {
			j = (j + Int(state[i]) + Int(key[i % key.count])) & 0xFF
			state.swapAt(i, j)
		}

		// Pseudo-random generation algorithm (PRGA)
		var i = 0
		j = 0
		var output = Data(count: data.count)

		for k in 0..<data.count {
			i = (i + 1) & 0xFF
			j = (j + Int(state[i])) & 0xFF
			state.swapAt(i, j)
			let keyStreamByte = state[(Int(state[i]) + Int(state[j])) & 0xFF]
			output[k] = data[k] ^ keyStreamByte
		}

		return output
	}
}
