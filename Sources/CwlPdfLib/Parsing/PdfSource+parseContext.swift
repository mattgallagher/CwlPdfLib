// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

extension PdfSource {
	mutating func parseContext<Output>(range: Range<Int>, handler: (inout PdfParseContext) throws -> Output) throws -> Output {
		return try self.bytes(in: range) { buffer in
			var context = PdfParseContext(slice: buffer[...], token: nil)
			return try handler(&context)
		}
	}
	
	mutating func parseContext<Output, S: BidirectionalCollection>(untilMatch pattern: S, limit: Int? = nil, reverse: Bool = false, handler: (inout PdfParseContext) throws -> Output) throws -> Output where S.Element == UInt8, S.Index == Int {
		guard !pattern.isEmpty else {
			let buffer = UnsafeRawBufferPointer(start: nil, count: 0)
			var context = PdfParseContext(slice: OffsetSlice(buffer, bounds: 0..<0, offset: 0), token: nil)
			return try handler(&context)
		}
		
		if reverse {
			var context = KMPMatchContext(pattern: pattern.reversed())
			let range = try advance(
				context: &context,
				limit: limit,
				reverse: true,
				includeLast: true,
				until: { byte, context in context.step(byte: byte) }
			)
			return try parseContext(range: range, handler: handler)
		} else {
			var context = KMPMatchContext(pattern: pattern)
			let range = try advance(
				context: &context,
				limit: limit,
				reverse: false,
				includeLast: true,
				until: { byte, context in context.step(byte: byte) }
			)
			return try parseContext(range: range, handler: handler)
		}
	}
	
	mutating func parseContext<Output>(lineCount: Int, limit: Int? = nil, reverse: Bool = false, handler: (inout PdfParseContext) throws -> Output) throws -> Output {
		var context = EndOfLineContext()
		context.reverse = reverse
		let start = self.offset
		var range = start..<start
		for _ in 0..<lineCount {
			context.matchCount = 0
			range = try advance(context: &context, limit: limit, reverse: reverse, includeLast: false, until: { byte, context in context.step(byte: byte) })
			if range.isEmpty, context.matchCount > 0 {
				if reverse {
					range = range.lowerBound..<(range.lowerBound + context.matchCount)
				} else {
					range = start..<(range.upperBound - context.matchCount)
				}
			}
		}
		if lineCount > 1 {
			if reverse {
				range = range.lowerBound..<start
			} else {
				range = start..<range.upperBound
			}
		}
		return try parseContext(range: range, handler: handler)
	}
}

private extension PdfSource {
	mutating func advance<Context>(context: inout Context, limit: Int? = nil, reverse: Bool, includeLast: Bool, until condition: (UInt8, inout Context) -> Bool) throws -> Range<Int> {
		let start = self.offset
		let limit = reverse ? max(self.offset - (limit ?? self.offset), 0) : min(self.offset + (limit ?? self.length), self.length)
		var byte: UInt8 = 0
		var didReadEndByte = true
		var count = 0
		repeat {
			if (!reverse && start + count >= limit) || (reverse && start - count - 1 < limit) {
				// Exceeded limit or bounds of source
				didReadEndByte = false
				break
			}
			
			if reverse {
				byte = try readPrevious()
			} else {
				byte = try readNext()
			}
			count += 1
		} while !condition(byte, &context)
		
		guard didReadEndByte else {
			// On end of limit or bounds, return an empty range at end
			return limit..<limit
		}
		if !includeLast {
			count -= 1
			try seek(to: self.offset + (reverse ? 1 : -1))
		}
		if reverse {
			return (start - count)..<start
		} else {
			return start..<(start + count)
		}
	}
}

// A basic Knuth–Morris–Pratt search, building the longest possible segment table (lps)
// and using that to avoid backtracking.
private struct KMPMatchContext<C: Collection> where C.Element == UInt8, C.Index == Int {
	let lps: [Int]
	let pattern: C
	var j = 0
	
	init(pattern: C) {
		var lps = [Int]()
		var length = 0
		var i = 1
		while i < pattern.count {
			if pattern[i] == pattern[length] {
				if lps.isEmpty {
					// Avoid allocating the buffer unless it's needed
					lps = [Int](repeating: 0, count: pattern.count)
				}
				length += 1
				lps[i] = length
				i += 1
			} else {
				if length > 0 {
					length = lps.isEmpty ? 0 : lps[length - 1]
				} else if !lps.isEmpty {
					lps[i] = 0
					i += 1
				}
			}
		}
		self.lps = lps
		self.pattern = pattern
	}
	
	mutating func step(byte: UInt8) -> Bool {
		while j > 0 && byte != pattern[j] {
			j = lps.isEmpty ? 0 : lps[j - 1] // follow failure link
		}
		if byte == pattern[j] {
			j += 1
			if j == pattern.count {
				return true // full match found
			}
		}
		return false
	}
}

private struct EndOfLineContext {
	// when scanning forward, this is the count of CR/LF bytes, when scanning backward
	// this is the count of non CR/LF bytes
	var matchCount = 0
	var reverse = false

	mutating func step(byte: UInt8) -> Bool {
		if ASCII.isEol(byte) {
			if !reverse {
				matchCount += 1
			} else if matchCount != 0 {
				return true
			}
		} else {
			if reverse {
				matchCount += 1
			} else if matchCount != 0 {
				return true
			}
		}
		return false
	}
}

