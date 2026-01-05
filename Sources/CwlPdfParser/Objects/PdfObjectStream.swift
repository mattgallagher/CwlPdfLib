// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation

public struct PdfContentStream {
	let stream: PdfStream
	let resources: PdfDictionary?
	
	public func parse(_ visitor: (PdfOperator) -> Bool) throws {
		try stream.data.parseContext { context in
			repeat {
				guard let nextOperator = try PdfOperator.parseNext(context: &context) else {
					return
				}
				if !visitor(nextOperator) {
					return
				}
			} while true
		}
	}
}

extension PdfOperator {
	static func parseNext(context: inout PdfParseContext) throws -> PdfOperator? {
		var stack = [ContentStreamStackElement]()
		
		repeat {
			guard let object = try PdfObject.parseNext(context: &context) else {
				if stack.isEmpty {
					return nil
				} else {
					throw PdfParseError(context: context, failure: .expectedOperator)
				}
			}
			
			if case .identifier(let string) = object {
				
			} else {
				stack.append(ContentStreamStackElement.object(object))
			}
		} while true
	}
}

enum ContentStreamStackElement {
	case object(PdfObject)
}

extension Data {
	func parseContext<Output>(handler: (inout PdfParseContext) throws -> Output) throws -> Output {
		return try withUnsafeBytes { bufferPointer in
			let buffer = OffsetSlice(bufferPointer, bounds: bufferPointer.indices, offset: 0)
			var context = PdfParseContext(slice: buffer[...], token: nil)
			return try handler(&context)
		}
	}
}
