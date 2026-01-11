// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Represents a PDF function (Types 0, 2, 3, 4) used for color interpolation in shadings.
public enum PdfFunction: Sendable {
	/// Type 0: Sampled function - uses a table of sample values
	case sampled(SampledFunction)
	/// Type 2: Exponential interpolation function
	case exponential(ExponentialFunction)
	/// Type 3: Stitching function - combines multiple functions
	case stitching(StitchingFunction)

	public struct SampledFunction: Sendable {
		public let domain: [Double]
		public let range: [Double]
		public let size: [Int]
		public let bitsPerSample: Int
		public let samples: Data
		public let encode: [Double]?
		public let decode: [Double]?
	}

	public struct ExponentialFunction: Sendable {
		public let domain: [Double]
		public let range: [Double]?
		public let c0: [Double]
		public let c1: [Double]
		public let exponent: Double
	}

	public struct StitchingFunction: Sendable {
		public let domain: [Double]
		public let range: [Double]?
		public let functions: [PdfFunction]
		public let bounds: [Double]
		public let encode: [Double]
	}

	public static func parse(_ obj: PdfObject?, lookup: PdfObjectLookup?) -> PdfFunction? {
		guard let obj else { return nil }

		// Function can be a dictionary or a stream (for sampled functions)
		let dictionary: PdfDictionary?
		let streamData: Data?

		if let stream = obj.stream(lookup: lookup) {
			dictionary = stream.dictionary
			streamData = stream.data
		} else if let dict = obj.dictionary(lookup: lookup) {
			dictionary = dict
			streamData = nil
		} else {
			return nil
		}

		guard let dictionary else { return nil }
		guard let functionType = dictionary[.FunctionType]?.integer(lookup: lookup) else { return nil }

		switch functionType {
		case 0:
			return parseSampled(dictionary: dictionary, data: streamData, lookup: lookup)
		case 2:
			return parseExponential(dictionary: dictionary, lookup: lookup)
		case 3:
			return parseStitching(dictionary: dictionary, lookup: lookup)
		default:
			// Type 4 (PostScript calculator) not supported
			return nil
		}
	}

	private static func parseSampled(dictionary: PdfDictionary, data: Data?, lookup: PdfObjectLookup?) -> PdfFunction? {
		guard let domain = parseDoubleArray(dictionary[.Domain], lookup: lookup),
			  let range = parseDoubleArray(dictionary[.Range], lookup: lookup),
			  let sizeArray = dictionary[.Size]?.array(lookup: lookup),
			  let bitsPerSample = dictionary[.BitsPerSample]?.integer(lookup: lookup),
			  let data else {
			return nil
		}

		let size = sizeArray.compactMap { $0.integer(lookup: lookup) }
		let encode = parseDoubleArray(dictionary[.Encode], lookup: lookup)
		let decode = parseDoubleArray(dictionary[.Decode], lookup: lookup)

		return .sampled(SampledFunction(
			domain: domain,
			range: range,
			size: size,
			bitsPerSample: bitsPerSample,
			samples: data,
			encode: encode,
			decode: decode
		))
	}

	private static func parseExponential(dictionary: PdfDictionary, lookup: PdfObjectLookup?) -> PdfFunction? {
		guard let domain = parseDoubleArray(dictionary[.Domain], lookup: lookup) else {
			return nil
		}

		let range = parseDoubleArray(dictionary[.Range], lookup: lookup)
		let c0 = parseDoubleArray(dictionary[.C0], lookup: lookup) ?? [0.0]
		let c1 = parseDoubleArray(dictionary[.C1], lookup: lookup) ?? [1.0]
		let exponent = dictionary[.N]?.real(lookup: lookup) ?? 1.0

		return .exponential(ExponentialFunction(
			domain: domain,
			range: range,
			c0: c0,
			c1: c1,
			exponent: exponent
		))
	}

	private static func parseStitching(dictionary: PdfDictionary, lookup: PdfObjectLookup?) -> PdfFunction? {
		guard let domain = parseDoubleArray(dictionary[.Domain], lookup: lookup),
			  let functionsArray = dictionary[.Functions]?.array(lookup: lookup),
			  let bounds = parseDoubleArray(dictionary[.Bounds], lookup: lookup),
			  let encode = parseDoubleArray(dictionary[.Encode], lookup: lookup) else {
			return nil
		}

		let range = parseDoubleArray(dictionary[.Range], lookup: lookup)
		let functions = functionsArray.compactMap { parse($0, lookup: lookup) }

		guard functions.count == functionsArray.count else { return nil }

		return .stitching(StitchingFunction(
			domain: domain,
			range: range,
			functions: functions,
			bounds: bounds,
			encode: encode
		))
	}

	private static func parseDoubleArray(_ obj: PdfObject?, lookup: PdfObjectLookup?) -> [Double]? {
		guard let array = obj?.array(lookup: lookup) else { return nil }
		let result = array.compactMap { $0.real(lookup: lookup) }
		guard result.count == array.count else { return nil }
		return result
	}

	/// Evaluate the function at the given input values.
	public func evaluate(_ inputs: [Double]) -> [Double]? {
		switch self {
		case .exponential(let f):
			return evaluateExponential(f, inputs: inputs)
		case .sampled(let f):
			return evaluateSampled(f, inputs: inputs)
		case .stitching(let f):
			return evaluateStitching(f, inputs: inputs)
		}
	}

	private func evaluateExponential(_ f: ExponentialFunction, inputs: [Double]) -> [Double]? {
		guard !inputs.isEmpty else { return nil }

		// Clamp input to domain
		let x = max(f.domain[0], min(f.domain[1], inputs[0]))

		// Compute interpolation: result[i] = c0[i] + x^N * (c1[i] - c0[i])
		var result = [Double]()
		let outputCount = f.c0.count

		for i in 0..<outputCount {
			let c0i = f.c0[i]
			let c1i = i < f.c1.count ? f.c1[i] : 1.0
			let value = c0i + pow(x, f.exponent) * (c1i - c0i)
			result.append(value)
		}

		// Clamp to range if specified
		if let range = f.range {
			for i in 0..<result.count {
				let rangeIndex = i * 2
				if rangeIndex + 1 < range.count {
					result[i] = max(range[rangeIndex], min(range[rangeIndex + 1], result[i]))
				}
			}
		}

		return result
	}

	private func evaluateSampled(_ f: SampledFunction, inputs: [Double]) -> [Double]? {
		guard !inputs.isEmpty, !f.size.isEmpty else { return nil }

		// Number of input and output dimensions
		let m = f.domain.count / 2  // Number of inputs
		let n = f.range.count / 2   // Number of outputs

		guard inputs.count >= m else { return nil }

		// For simplicity, handle 1D input case (most common for shadings)
		guard m == 1 else { return nil }

		// Encode input
		let domainMin = f.domain[0]
		let domainMax = f.domain[1]
		let x = max(domainMin, min(domainMax, inputs[0]))

		// Map to sample indices
		let encodeMin = f.encode?[0] ?? 0.0
		let encodeMax = f.encode?[1] ?? Double(f.size[0] - 1)
		let encoded = encodeMin + ((x - domainMin) / (domainMax - domainMin)) * (encodeMax - encodeMin)

		// Clamp to valid sample range
		let sampleIndex = max(0, min(Double(f.size[0] - 1), encoded))
		let i0 = Int(floor(sampleIndex))
		let i1 = min(i0 + 1, f.size[0] - 1)
		let fraction = sampleIndex - Double(i0)

		// Read samples and interpolate
		var result = [Double](repeating: 0, count: n)
		let bytesPerSample = f.bitsPerSample / 8
		let maxSampleValue = Double((1 << f.bitsPerSample) - 1)

		for j in 0..<n {
			let offset0 = (i0 * n + j) * bytesPerSample
			let offset1 = (i1 * n + j) * bytesPerSample

			let sample0 = readSample(from: f.samples, offset: offset0, bytesPerSample: bytesPerSample)
			let sample1 = readSample(from: f.samples, offset: offset1, bytesPerSample: bytesPerSample)

			// Normalize to [0, 1]
			let normalized0 = Double(sample0) / maxSampleValue
			let normalized1 = Double(sample1) / maxSampleValue

			// Linear interpolation
			let interpolated = normalized0 + fraction * (normalized1 - normalized0)

			// Decode to output range
			let decodeMin = f.decode?[j * 2] ?? f.range[j * 2]
			let decodeMax = f.decode?[j * 2 + 1] ?? f.range[j * 2 + 1]
			result[j] = decodeMin + interpolated * (decodeMax - decodeMin)

			// Clamp to range
			result[j] = max(f.range[j * 2], min(f.range[j * 2 + 1], result[j]))
		}

		return result
	}

	private func readSample(from data: Data, offset: Int, bytesPerSample: Int) -> UInt32 {
		guard offset + bytesPerSample <= data.count else { return 0 }

		var value: UInt32 = 0
		for i in 0..<bytesPerSample {
			value = (value << 8) | UInt32(data[offset + i])
		}
		return value
	}

	private func evaluateStitching(_ f: StitchingFunction, inputs: [Double]) -> [Double]? {
		guard !inputs.isEmpty, !f.functions.isEmpty else { return nil }

		// Clamp input to domain
		let x = max(f.domain[0], min(f.domain[1], inputs[0]))

		// Find which subdomain/function to use
		var functionIndex = 0
		var subdomainMin = f.domain[0]
		var subdomainMax = f.bounds.first ?? f.domain[1]

		for i in 0..<f.bounds.count {
			if x < f.bounds[i] {
				functionIndex = i
				subdomainMax = f.bounds[i]
				break
			}
			subdomainMin = f.bounds[i]
			functionIndex = i + 1
		}

		if functionIndex >= f.functions.count {
			functionIndex = f.functions.count - 1
			subdomainMin = f.bounds.last ?? f.domain[0]
			subdomainMax = f.domain[1]
		}

		// Encode the input for the selected function
		let encodeMin = f.encode[functionIndex * 2]
		let encodeMax = f.encode[functionIndex * 2 + 1]

		let encoded: Double
		if subdomainMax - subdomainMin > 0 {
			encoded = encodeMin + ((x - subdomainMin) / (subdomainMax - subdomainMin)) * (encodeMax - encodeMin)
		} else {
			encoded = encodeMin
		}

		// Evaluate the selected function
		return f.functions[functionIndex].evaluate([encoded])
	}
}
