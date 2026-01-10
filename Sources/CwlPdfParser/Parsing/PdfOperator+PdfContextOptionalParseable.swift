// CwlPdfLib. Copyright © 2025 Matt Gallagher. See LICENSE file for usage permissions.

extension PdfOperator: PdfContextOptionalParseable {
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
					guard
						let text = stack.popLast()?.string(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.`'`(text)
				case .`"`:
					guard
						let text = stack.popLast()?.string(lookup: nil),
						let cSpacing = stack.popLast()?.real(lookup: nil),
						let wSpacing = stack.popLast()?.real(lookup: nil) else {
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
						let properties = stack.popLast()?.dictionary(lookup: nil),
						let tag = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.BDC(properties, tag)
				case .BI:
					return PdfOperator.BI
				case .BMC:
					guard let tag = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.BMC(tag)
				case .BT:
					return PdfOperator.BT
				case .BX:
					return PdfOperator.BX
				case .c:
					guard
						let y3 = stack.popLast()?.real(lookup: nil),
						let x3 = stack.popLast()?.real(lookup: nil),
						let y2 = stack.popLast()?.real(lookup: nil),
						let x2 = stack.popLast()?.real(lookup: nil),
						let y1 = stack.popLast()?.real(lookup: nil),
						let x1 = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.c(x1, y1, x2, y2, x3, y3)
				case .cm:
					guard
						let ty = stack.popLast()?.real(lookup: nil),
						let tx = stack.popLast()?.real(lookup: nil),
						let d = stack.popLast()?.real(lookup: nil),
						let c = stack.popLast()?.real(lookup: nil),
						let b = stack.popLast()?.real(lookup: nil),
						let a = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.cm(a, b, c, d, tx, ty)
				case .CS:
					guard let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.CS(name)
				case .cs:
					guard let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.cs(name)
				case .d:
					guard
						let dashPhase = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					let dashArray = stack.compactMap { $0.real(lookup: nil) }
					return PdfOperator.d(dashPhase, dashArray)
				case .d0:
					return PdfOperator.d0
				case .d1:
					return PdfOperator.d1
				case .Do:
					guard let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Do(name)
				case .DP:
					guard
						let properties = stack.popLast()?.dictionary(lookup: nil),
						let tag = stack.popLast()?.name(lookup: nil) else {
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
					guard let gray = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.G(gray)
				case .g:
					guard let gray = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.g(gray)
				case .gs:
					guard let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.gs(name)
				case .h:
					return PdfOperator.h
				case .i:
					guard let flatness = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.i(flatness)
				case .ID:
					return PdfOperator.ID
				case .J:
					guard
						let style = stack.popLast()?.integer(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.J(style)
				case .j:
					guard
						let style = stack.popLast()?.integer(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.j(style)
				case .K:
					guard
						let k = stack.popLast()?.real(lookup: nil),
						let y = stack.popLast()?.real(lookup: nil),
						let m = stack.popLast()?.real(lookup: nil),
						let c = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.K(c, m, y, k)
				case .k:
					guard
						let k = stack.popLast()?.real(lookup: nil),
						let y = stack.popLast()?.real(lookup: nil),
						let m = stack.popLast()?.real(lookup: nil),
						let c = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.k(c, m, y, k)
				case .l:
					guard
						let y = stack.popLast()?.real(lookup: nil),
						let x = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.l(x, y)
				case .M:
					guard let miterLimit = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.M(miterLimit)
				case .m:
					guard
						let y = stack.popLast()?.real(lookup: nil),
						let x = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.m(x, y)
				case .MP:
					guard let tag = stack.popLast()?.name(lookup: nil) else {
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
						let height = stack.popLast()?.real(lookup: nil),
						let width = stack.popLast()?.real(lookup: nil),
						let y = stack.popLast()?.real(lookup: nil),
						let x = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.re(x, y, width, height)
				case .RG:
					guard
						let b = stack.popLast()?.real(lookup: nil),
						let g = stack.popLast()?.real(lookup: nil),
						let r = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.RG(r, g, b)
				case .rg:
					guard
						let b = stack.popLast()?.real(lookup: nil),
						let g = stack.popLast()?.real(lookup: nil),
						let r = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.rg(r, g, b)
				case .ri:
					guard let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.ri(name)
				case .S:
					return PdfOperator.S
				case .s:
					return PdfOperator.s
				case .SC:
					let colorArray = stack.compactMap { $0.real(lookup: nil) }
					return PdfOperator.SC(colorArray)
				case .sc:
					let colorArray = stack.compactMap { $0.real(lookup: nil) }
					return PdfOperator.sc(colorArray)
				case .SCN:
					let colorArray = stack.compactMap { $0.real(lookup: nil) }
					return PdfOperator.SCN(colorArray)
				case .scn:
					let colorArray = stack.compactMap { $0.real(lookup: nil) }
					return PdfOperator.scn(colorArray)
				case .sh:
					guard let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.sh(name)
				case .Tc:
					guard let charSpacing = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tc(charSpacing)
				case .Td:
					guard
						let y = stack.popLast()?.real(lookup: nil),
						let x = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Td(x, y)
				case .TD:
					guard
						let y = stack.popLast()?.real(lookup: nil),
						let x = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.TD(x, y)
				case .Tf:
					guard
						let size = stack.popLast()?.real(lookup: nil),
						let name = stack.popLast()?.name(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tf(name, size)
				case .Tj:
					guard let string = stack.popLast()?.string(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tj(string)
				case .TJ:
					guard let elements = stack.popLast()?.array(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					} 
					var result = [TJElement]()
					for element in elements {
						if let text = element.string(lookup: nil) {
							result.append(.text(text))
						} else if let offset = element.real(lookup: nil) {
							result.append(.offset(offset))
						}
					}
					return PdfOperator.TJ(result)
				case .TL:
					guard let leading = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.TL(leading)
				case .Tm:
					guard
						let f = stack.popLast()?.real(lookup: nil),
						let e = stack.popLast()?.real(lookup: nil),
						let d = stack.popLast()?.real(lookup: nil),
						let c = stack.popLast()?.real(lookup: nil),
						let b = stack.popLast()?.real(lookup: nil),
						let a = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tm(a, b, c, d, e, f)
				case .Tr:
					guard
						let mode = stack.popLast()?.integer(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tr(mode)
				case .Ts:
					guard let rise = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Ts(rise)
				case .Tw:
					guard let wordSpacing = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tw(wordSpacing)
				case .Tz:
					guard let scale = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.Tz(scale)
				case .`T*`:
					return PdfOperator.`T*`
				case .v:
					guard
						let y3 = stack.popLast()?.real(lookup: nil),
						let x3 = stack.popLast()?.real(lookup: nil),
						let y2 = stack.popLast()?.real(lookup: nil),
						let x2 = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.v(x2, y2, x3, y3)
				case .w:
					guard let lineWidth = stack.popLast()?.real(lookup: nil) else {
						throw PdfParseError(context: context, failure: .missingRequiredParameters)
					}
					return PdfOperator.w(lineWidth)
				case .W:
					return PdfOperator.W
				case .`W*`:
					return PdfOperator.`W*`
				case .y:
					guard
						let y3 = stack.popLast()?.real(lookup: nil),
						let x3 = stack.popLast()?.real(lookup: nil),
						let y2 = stack.popLast()?.real(lookup: nil),
						let x2 = stack.popLast()?.real(lookup: nil) else {
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
