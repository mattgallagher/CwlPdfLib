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
		var stack = [PdfObject]()
		
		repeat {
			guard let object = try PdfObject.parseNext(context: &context) else {
				if stack.isEmpty {
					return nil
				} else {
					throw PdfParseError(context: context, failure: .expectedOperator)
				}
			}
			
			if case .identifier(let string) = object {
				guard let operatorIdentifier = PdfOperatorIdentifier(rawValue: string) else {
					throw PdfParseError(context: context, failure: .unknownOperator)
				}
				switch operatorIdentifier {
				case .`'`:
					return PdfOperator.`'`
				case .`"`:
					guard
						let text = try? stack.popLast()?.string(objects: nil)?.pdfText(),
						let cSpacing = try? stack.popLast()?.real(objects: nil),
						let wSpacing = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.`"`(text, cSpacing, wSpacing)
				case .B:
					return PdfOperator.B
				case .`B*`:
					return PdfOperator.`B*`
				case .b:
					return PdfOperator.b
				case .`b*`:
					return PdfOperator.`b*`
				case .BDC:
					guard
						let properties = try? stack.popLast()?.dictionary(objects: nil),
						let tag = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.BDC(properties, tag)
				case .BI:
					return PdfOperator.BI
				case .BMC:
					guard let tag = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.BMC(tag)
				case .BT:
					return PdfOperator.BT
				case .BX:
					return PdfOperator.BX
				case .c:
					guard
						let y3 = try? stack.popLast()?.real(objects: nil),
						let x3 = try? stack.popLast()?.real(objects: nil),
						let y2 = try? stack.popLast()?.real(objects: nil),
						let x2 = try? stack.popLast()?.real(objects: nil),
						let y1 = try? stack.popLast()?.real(objects: nil),
						let x1 = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.c(x1, y1, x2, y2, x3, y3)
				case .cm:
					guard
						let ty = try? stack.popLast()?.real(objects: nil),
						let tx = try? stack.popLast()?.real(objects: nil),
						let d = try? stack.popLast()?.real(objects: nil),
						let c = try? stack.popLast()?.real(objects: nil),
						let b = try? stack.popLast()?.real(objects: nil),
						let a = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.cm(a, b, c, d, tx, ty)
				case .CS:
					guard let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.CS(name)
				case .cs:
					guard let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.cs(name)
				case .d:
					guard
						let dashPhase = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					let dashArray = stack.compactMap { try? $0.real(objects: nil) }
					return PdfOperator.d(dashPhase, dashArray)
				case .d0:
					return PdfOperator.d0
				case .d1:
					return PdfOperator.d1
				case .Do:
					guard let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Do(name)
				case .DP:
					guard
						let properties = try? stack.popLast()?.dictionary(objects: nil),
						let tag = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.DP(properties, tag)
				case .EI:
					return PdfOperator.EI
				case .EMC:
					return PdfOperator.EMC
				case .ET:
					return PdfOperator.ET
				case .EX:
					return PdfOperator.EX
				case .F:
					return PdfOperator.F
				case .f:
					return PdfOperator.f
				case .`f*`:
					return PdfOperator.`f*`
				case .G:
					guard let gray = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.G(gray)
				case .g:
					guard let gray = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.g(gray)
				case .gs:
					guard let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.gs(name)
				case .h:
					return PdfOperator.h
				case .i:
					guard let flatness = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.i(flatness)
				case .ID:
					return PdfOperator.ID
				case .J:
					guard
						let style = try? stack.popLast()?.integer(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.J(style)
				case .j:
					guard
						let style = try? stack.popLast()?.integer(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.j(style)
				case .K:
					guard
						let k = try? stack.popLast()?.real(objects: nil),
						let y = try? stack.popLast()?.real(objects: nil),
						let m = try? stack.popLast()?.real(objects: nil),
						let c = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.K(c, m, y, k)
				case .k:
					guard
						let k = try? stack.popLast()?.real(objects: nil),
						let y = try? stack.popLast()?.real(objects: nil),
						let m = try? stack.popLast()?.real(objects: nil),
						let c = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.k(c, m, y, k)
				case .l:
					guard
						let y = try? stack.popLast()?.real(objects: nil),
						let x = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.l(x, y)
				case .M:
					guard let miterLimit = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.M(miterLimit)
				case .m:
					guard
						let y = try? stack.popLast()?.real(objects: nil),
						let x = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.m(x, y)
				case .MP:
					guard let tag = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.MP(tag)
				case .n:
					return PdfOperator.n
				case .q:
					return PdfOperator.q
				case .Q:
					return PdfOperator.Q
				case .re:
					guard
						let height = try? stack.popLast()?.real(objects: nil),
						let width = try? stack.popLast()?.real(objects: nil),
						let y = try? stack.popLast()?.real(objects: nil),
						let x = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.re(x, y, width, height)
				case .RG:
					guard
						let b = try? stack.popLast()?.real(objects: nil),
						let g = try? stack.popLast()?.real(objects: nil),
						let r = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.RG(r, g, b)
				case .rg:
					guard
						let b = try? stack.popLast()?.real(objects: nil),
						let g = try? stack.popLast()?.real(objects: nil),
						let r = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.rg(r, g, b)
				case .ri:
					guard let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.ri(name)
				case .S:
					return PdfOperator.S
				case .s:
					return PdfOperator.s
				case .SC:
					let colorArray = stack.compactMap { try? $0.real(objects: nil) }
					return PdfOperator.SC(colorArray)
				case .sc:
					let colorArray = stack.compactMap { try? $0.real(objects: nil) }
					return PdfOperator.sc(colorArray)
				case .SCN:
					let colorArray = stack.compactMap { try? $0.real(objects: nil) }
					return PdfOperator.SCN(colorArray)
				case .scn:
					let colorArray = stack.compactMap { try? $0.real(objects: nil) }
					return PdfOperator.scn(colorArray)
				case .sh:
					guard let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.sh(name)
				case .Tc:
					guard let charSpacing = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tc(charSpacing)
				case .Td:
					guard
						let y = try? stack.popLast()?.real(objects: nil),
						let x = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Td(x, y)
				case .TD:
					guard
						let y = try? stack.popLast()?.real(objects: nil),
						let x = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.TD(x, y)
				case .Tf:
					guard
						let size = try? stack.popLast()?.real(objects: nil),
						let name = try? stack.popLast()?.name(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tf(name, size)
				case .Tj:
					guard let string = try? stack.popLast()?.string(objects: nil)?.pdfText() else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tj(string)
				case .TJ:
					return PdfOperator.TJ(stack)
				case .TL:
					guard let leading = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.TL(leading)
				case .Tm:
					guard
						let f = try? stack.popLast()?.real(objects: nil),
						let e = try? stack.popLast()?.real(objects: nil),
						let d = try? stack.popLast()?.real(objects: nil),
						let c = try? stack.popLast()?.real(objects: nil),
						let b = try? stack.popLast()?.real(objects: nil),
						let a = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tm(a, b, c, d, e, f)
				case .Tr:
					guard
						let mode = try? stack.popLast()?.integer(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tr(mode)
				case .Ts:
					guard let rise = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Ts(rise)
				case .Tw:
					guard let wordSpacing = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tw(wordSpacing)
				case .Tz:
					guard let scale = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tz(scale)
				case .`T*`:
					return PdfOperator.`T*`
				case .v:
					guard
						let y3 = try? stack.popLast()?.real(objects: nil),
						let x3 = try? stack.popLast()?.real(objects: nil),
						let y2 = try? stack.popLast()?.real(objects: nil),
						let x2 = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.v(x2, y2, x3, y3)
				case .w:
					guard let lineWidth = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.w(lineWidth)
				case .W:
					return PdfOperator.W
				case .`W*`:
					return PdfOperator.`W*`
				case .y:
					guard
						let y3 = try? stack.popLast()?.real(objects: nil),
						let x3 = try? stack.popLast()?.real(objects: nil),
						let y2 = try? stack.popLast()?.real(objects: nil),
						let x2 = try? stack.popLast()?.real(objects: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.y(x2, y2, x3, y3)
				}
			} else {
				stack.append(object)
			}
		} while true
	}
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

enum PdfOperatorIdentifier: String {
	case `'`
	case `"`
	case B
	case `B*`
	case b
	case `b*`
	case BDC
	case BI
	case BMC
	case BT
	case BX
	case c
	case cm
	case CS
	case cs
	case d
	case d0
	case d1
	case Do
	case DP
	case EI
	case EMC
	case ET
	case EX
	case F
	case f
	case `f*`
	case G
	case g
	case gs
	case h
	case i
	case ID
	case J
	case j
	case K
	case k
	case l
	case M
	case m
	case MP
	case n
	case q
	case Q
	case re
	case RG
	case rg
	case ri
	case S
	case s
	case SC
	case sc
	case SCN
	case scn
	case sh
	case Tc
	case Td
	case TD
	case Tf
	case Tj
	case TJ
	case TL
	case Tm
	case Tr
	case Ts
	case Tw
	case Tz
	case `T*`
	case v
	case w
	case W
	case `W*`
	case y
}
