// CwlPdfParser. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

/// A simple wrapper around a `Slice` with `Int` indexes. Indices exposed by this collection have `offset`
/// added, relative to the `base`.
public struct OffsetSlice<Base: RandomAccessCollection>: RandomAccessCollection where Base.Index == Int {
	public typealias SubSequence = OffsetSlice<Base>
	public typealias Index = Int
	public typealias Element = Base.Element

	private var underlying: Slice<Base>
	
	public var offset: Int
	
	public var base: Base {
		underlying.base
	}

	public init(_ base: Base, bounds: Range<Int>, offset: Int) {
		self.underlying = Slice(base: base, bounds: bounds)
		self.offset = offset
	}
	
	public var startIndex: Int { underlying.startIndex + offset }
	public var endIndex: Int { underlying.endIndex + offset }

	public subscript(position: Int) -> Element {
		underlying[position - offset]
	}

	public func makeIterator() -> Slice<Base>.Iterator {
		underlying.makeIterator()
	}

	public var count: Int { underlying.count }
	public var isEmpty: Bool { underlying.isEmpty }
	
	public func rangeToBase(_ range: Range<Int>) -> Range<Int> {
		(range.startIndex - offset)..<(range.endIndex - offset)
	}
	
	public subscript(bounds: Range<Index>) -> OffsetSlice<Base> {
		var duplicate = self
		duplicate.underlying = duplicate.underlying[rangeToBase(bounds)]
		return duplicate
	}
	
	/// Calling subscript(_ bounds:) will trigger a fatal error if bounds is outside the current slice.
	/// By contrast, subscript(reslice bounds:) will allow the reslice if bounds are within range for the
	/// base collection. This allows backtracking to bounds that were *previously* in range.
	public subscript(reslice bounds: Range<Index>) -> OffsetSlice<Base> {
		OffsetSlice(base, bounds: rangeToBase(bounds), offset: offset)
	}
}

extension OffsetSlice: RangeReplaceableCollection where Base: RangeReplaceableCollection {
	public init() {
		self.init(Base(), bounds: 0..<0, offset: 0)
	}
	
	public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C : Collection, Base.Element == C.Element {
		underlying.replaceSubrange(rangeToBase(subrange), with: newElements)
	}
	
	public mutating func reserveCapacity(_ n: Int) {
		underlying.reserveCapacity(n)
	}
}
