// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

/// Represents a PDF shading dictionary.
/// Supports Type 2 (axial) and Type 3 (radial) shadings.
public enum PdfShading: Sendable {
	/// Type 2: Axial shading (linear gradient)
	case axial(AxialShading)
	/// Type 3: Radial shading (circular gradient)
	case radial(RadialShading)

	public struct AxialShading: Sendable {
		public let colorSpace: PdfColorSpace
		public let background: [Double]?
		public let bbox: PdfRect?
		public let antiAlias: Bool
		public let coords: (x0: Double, y0: Double, x1: Double, y1: Double)
		public let domain: (t0: Double, t1: Double)
		public let function: PdfFunction
		public let extend: (start: Bool, end: Bool)
	}

	public struct RadialShading: Sendable {
		public let colorSpace: PdfColorSpace
		public let background: [Double]?
		public let bbox: PdfRect?
		public let antiAlias: Bool
		public let coords: (x0: Double, y0: Double, r0: Double, x1: Double, y1: Double, r1: Double)
		public let domain: (t0: Double, t1: Double)
		public let function: PdfFunction
		public let extend: (start: Bool, end: Bool)
	}

	public static func parse(_ dictionary: PdfDictionary, lookup: PdfObjectLookup?) -> PdfShading? {
		guard let shadingType = dictionary[.ShadingType]?.integer(lookup: lookup) else {
			return nil
		}

		// Parse common properties
		guard let colorSpace = PdfColorSpace.parse(dictionary[.ColorSpace], lookup: lookup) else {
			return nil
		}

		let background = parseDoubleArray(dictionary[.Background], lookup: lookup)
		let bbox = dictionary[.BBox]?.array(lookup: lookup).flatMap { PdfRect(array: $0, lookup: lookup) }
		let antiAlias = dictionary[.AntiAlias]?.boolean(lookup: lookup) ?? false

		// Parse domain (defaults to [0, 1])
		let domainArray = parseDoubleArray(dictionary[.Domain], lookup: lookup)
		let domain = (
			t0: domainArray?.first ?? 0.0,
			t1: domainArray?.last ?? 1.0
		)

		// Parse extend (defaults to [false, false])
		let extendArray = dictionary[.Extend]?.array(lookup: lookup)
		let extend = (
			start: extendArray?.first?.boolean(lookup: lookup) ?? false,
			end: extendArray?.last?.boolean(lookup: lookup) ?? false
		)

		// Parse function (required for Types 2 and 3)
		guard let function = parseFunction(dictionary[.Function], lookup: lookup) else {
			return nil
		}

		switch shadingType {
		case 2:
			// Axial shading
			guard let coordsArray = parseDoubleArray(dictionary[.Coords], lookup: lookup),
				  coordsArray.count >= 4 else {
				return nil
			}

			let coords = (
				x0: coordsArray[0],
				y0: coordsArray[1],
				x1: coordsArray[2],
				y1: coordsArray[3]
			)

			return .axial(AxialShading(
				colorSpace: colorSpace,
				background: background,
				bbox: bbox,
				antiAlias: antiAlias,
				coords: coords,
				domain: domain,
				function: function,
				extend: extend
			))

		case 3:
			// Radial shading
			guard let coordsArray = parseDoubleArray(dictionary[.Coords], lookup: lookup),
				  coordsArray.count >= 6 else {
				return nil
			}

			let coords = (
				x0: coordsArray[0],
				y0: coordsArray[1],
				r0: coordsArray[2],
				x1: coordsArray[3],
				y1: coordsArray[4],
				r1: coordsArray[5]
			)

			return .radial(RadialShading(
				colorSpace: colorSpace,
				background: background,
				bbox: bbox,
				antiAlias: antiAlias,
				coords: coords,
				domain: domain,
				function: function,
				extend: extend
			))

		default:
			// Types 1, 4, 5, 6, 7 not supported
			return nil
		}
	}

	private static func parseDoubleArray(_ obj: PdfObject?, lookup: PdfObjectLookup?) -> [Double]? {
		guard let array = obj?.array(lookup: lookup) else { return nil }
		let result = array.compactMap { $0.real(lookup: lookup) }
		guard result.count == array.count else { return nil }
		return result
	}

	private static func parseFunction(_ obj: PdfObject?, lookup: PdfObjectLookup?) -> PdfFunction? {
		guard let obj else { return nil }

		// Function can be a single function or an array of functions
		// For multiple functions, we create a synthetic stitching-like evaluation
		if let array = obj.array(lookup: lookup), !array.isEmpty {
			// Array of functions - each produces one output component
			let functions = array.compactMap { PdfFunction.parse($0, lookup: lookup) }
			guard functions.count == array.count else { return nil }

			if functions.count == 1 {
				return functions[0]
			}

			// Create a wrapper that evaluates all functions and concatenates results
			return .arrayWrapper(functions)
		}

		return PdfFunction.parse(obj, lookup: lookup)
	}
}

extension PdfFunction {
	/// Wrapper for an array of functions where each function provides part of the output
	static func arrayWrapper(_ functions: [PdfFunction]) -> PdfFunction {
		// We'll handle this specially in evaluate
		.stitching(StitchingFunction(
			domain: [0, 1],
			range: nil,
			functions: functions,
			bounds: [],
			encode: functions.enumerated().flatMap { _ in [0.0, 1.0] }
		))
	}

	/// Evaluate for array-of-functions case where we concatenate outputs
	func evaluateArray(_ inputs: [Double], functionCount: Int) -> [Double]? {
		guard case .stitching(let f) = self, f.bounds.isEmpty else {
			return evaluate(inputs)
		}

		// This is our special array wrapper - evaluate each function and concatenate
		var result = [Double]()
		for function in f.functions {
			if let output = function.evaluate(inputs) {
				result.append(contentsOf: output)
			} else {
				return nil
			}
		}
		return result
	}
}
