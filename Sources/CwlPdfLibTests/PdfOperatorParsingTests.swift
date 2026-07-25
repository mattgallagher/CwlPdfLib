// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

import Foundation
import Testing

@testable import CwlPdfParser

struct PdfOperatorParsingTests {
	@Test(arguments: [
		("blank-page.pdf", blankFileOperators),
		("text-shapes-shading.pdf", textShapesShadingOperators)
	])
	func `GIVEN a blank page WHEN content stream THEN q Q extracted`(filename: String, operators: @Sendable () -> [PdfOperator]) throws {
		let fileURL = try #require(Bundle.module.url(forResource: "Fixtures/Basic/\(filename)", withExtension: nil))
		let document = try PdfDocument(source: PdfDataSource(Data(contentsOf: fileURL, options: .mappedIfSafe)))
		let page = try #require(document.pages.first)
		let stream = try #require(page.content(lookup: document.lookup).streams.first)
		
		var parsed = [PdfOperator]()
		try stream.parseContentOperators { op in
			parsed.append(op)
			return true
		}
		
		let operators = operators()
		
		#expect(parsed.count == operators.count)
		for (op, parse) in zip(operators, parsed) {
			#expect(op == parse)
		}
	}

	@Test
	func `GIVEN a content stream WHEN parsed repeatedly THEN completed operators are cached and replayed`() throws {
		let document = try basicFixtureDocument(filename: "blank-page.pdf")
		let page = try #require(document.pages.first)
		let stream = try #require(page.content(lookup: document.lookup).streams.first)
		var parsed = [PdfOperator]()

		try stream.parseContentOperators(lookup: document.lookup) { op in
			parsed.append(op)
			return true
		}

		#expect(document.lookup.mutableState.cachedContentOperators(for: stream.objectIdentifier) == parsed)

		document.lookup.mutableState.cacheContentOperators([.Q], for: stream.objectIdentifier)
		var replayed = [PdfOperator]()
		try stream.parseContentOperators(lookup: document.lookup) { op in
			replayed.append(op)
			return true
		}
		#expect(replayed == [.Q])
	}

	@Test
	func `GIVEN a content stream WHEN parsing stops early THEN partial operators are not cached`() throws {
		let document = try basicFixtureDocument(filename: "blank-page.pdf")
		let stream = PdfStream(
			objectIdentifier: PdfObjectIdentifier(number: 10_000, generation: 0),
			dictionary: [:],
			data: Data("q Q".utf8)
		)

		try stream.parseContentOperators(lookup: document.lookup) { _ in false }

		#expect(document.lookup.mutableState.cachedContentOperators(for: stream.objectIdentifier) == nil)
	}

	@Test
	func `GIVEN an invalid content stream WHEN parsing fails THEN error identifies parse intent and stream object`() throws {
		let document = try fixtureDocument(
			path: "PDFUA-Reference-Files_1-1_2024_02/PDFUA-Ref-2-03_AcademicAbstract.pdf"
		)
		let objectIdentifier = PdfObjectIdentifier(number: 269, generation: 0)
		let object = try #require(try document.lookup.object(for: objectIdentifier))
		let stream = try #require(object.stream(lookup: document.lookup))

		let error = #expect(throws: PdfParseError.self) {
			try stream.parseContentOperators { _ in true }
		}

		#expect(error?.failure == .expectedOperator)
		#expect(error?.intent == .contentOperatorStream(streamObject: objectIdentifier))
		#expect(String(describing: error).contains("contentOperatorStream(streamObject: 269 0 R)"))
	}
}

@Sendable
func blankFileOperators() -> [PdfOperator] {
	[
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.Q
	]
}


@Sendable
func textShapesShadingOperators() -> [PdfOperator] {
	[
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.Q,
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.re(0.0, 0.0, 1920.0, 1080.0),
		CwlPdfParser.PdfOperator.W,
		CwlPdfParser.PdfOperator.n,
		CwlPdfParser.PdfOperator.cs("Cs1"),
		CwlPdfParser.PdfOperator.sc([0.9999966, 1.0, 1.0]),
		CwlPdfParser.PdfOperator.m(0.0, 1080.0),
		CwlPdfParser.PdfOperator.l(1920.0, 1080.0),
		CwlPdfParser.PdfOperator.l(1920.0, 0.0),
		CwlPdfParser.PdfOperator.l(0.0, 0.0),
		CwlPdfParser.PdfOperator.h,
		CwlPdfParser.PdfOperator.f,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(1)]), "P"),
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(2)]), "P"),
		CwlPdfParser.PdfOperator.sc([0.0, 0.0, 0.0]),
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.cm(1.0, 0.0, 0.0, 1.0, 501.80629999999996, 723.9427999999999),
		CwlPdfParser.PdfOperator.BT,
		CwlPdfParser.PdfOperator.Tm(48.0, 0.0, 0.0, 48.0, 0.0, 0.0),
		CwlPdfParser.PdfOperator.Tf("TT1", 1.0),
		CwlPdfParser.PdfOperator.Tj("A line of text".toPdfText()),
		CwlPdfParser.PdfOperator.ET,
		CwlPdfParser.PdfOperator.Q,
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(3)]), "P"),
		CwlPdfParser.PdfOperator.w(7.0),
		CwlPdfParser.PdfOperator.M(4.0),
		CwlPdfParser.PdfOperator.CS("Cs1"),
		CwlPdfParser.PdfOperator.SC([0.0, 0.0, 0.0]),
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.cm(1.0, 0.0, 0.0, -1.0, 692.1248, 509.09069999999997),
		CwlPdfParser.PdfOperator.m(0.8333332999999999, 100.8333),
		CwlPdfParser.PdfOperator.c(-5.8333330000000005, 27.5, 27.5, -5.8333330000000005, 100.8333, 0.8333332999999999),
		CwlPdfParser.PdfOperator.S,
		CwlPdfParser.PdfOperator.Q,
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(4)]), "P"),
		CwlPdfParser.PdfOperator.sc([0.0, 0.6332163, 1.0]),
		CwlPdfParser.PdfOperator.m(1065.47, 846.6574999999999),
		CwlPdfParser.PdfOperator.l(1077.819, 808.6549),
		CwlPdfParser.PdfOperator.l(1117.778, 808.6534),
		CwlPdfParser.PdfOperator.l(1085.451, 785.165),
		CwlPdfParser.PdfOperator.l(1097.798, 747.1614999999999),
		CwlPdfParser.PdfOperator.l(1065.47, 770.6474999999999),
		CwlPdfParser.PdfOperator.l(1033.1409999999998, 747.1614999999999),
		CwlPdfParser.PdfOperator.l(1045.488, 785.165),
		CwlPdfParser.PdfOperator.l(1013.1619999999999, 808.6534),
		CwlPdfParser.PdfOperator.l(1053.12, 808.6549),
		CwlPdfParser.PdfOperator.h,
		CwlPdfParser.PdfOperator.f,
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(5)]), "P"),
		CwlPdfParser.PdfOperator.sc([0.3773232000000001, 0.8497244000000002, 0.21446420000000005]),
		CwlPdfParser.PdfOperator.re(1201.105, 451.105, 100.0, 100.0),
		CwlPdfParser.PdfOperator.f,
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(6)]), "P"),
		CwlPdfParser.PdfOperator.w(8.0),
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.cm(1.0, 0.0, 0.0, -1.0, 908.4083, 344.8619),
		CwlPdfParser.PdfOperator.m(85.35533999999998, 14.644659999999998),
		CwlPdfParser.PdfOperator.c(104.8816, 34.17088, 104.8816, 65.82912, 85.35533999999998, 85.35533999999998),
		CwlPdfParser.PdfOperator.c(65.82912, 104.8816, 34.17088, 104.8816, 14.644659999999998, 85.35533999999998),
		CwlPdfParser.PdfOperator.c(-4.8815539999999995, 65.82912, -4.8815539999999995, 34.17088, 14.644659999999998, 14.644659999999998),
		CwlPdfParser.PdfOperator.c(34.17088, -4.8815539999999995, 65.82912, -4.8815539999999995, 85.35533999999998, 14.644659999999998),
		CwlPdfParser.PdfOperator.h,
		CwlPdfParser.PdfOperator.m(85.35533999999998, 14.644659999999998),
		CwlPdfParser.PdfOperator.S,
		CwlPdfParser.PdfOperator.Q,
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.BDC(.dictionary(["MCID": .integer(7)]), "P"),
		CwlPdfParser.PdfOperator.Q,
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.m(932.93, 590.0),
		CwlPdfParser.PdfOperator.l(987.07, 590.0),
		CwlPdfParser.PdfOperator.c(993.7988000000001, 590.0, 997.8360999999999, 590.0, 1000.528, 588.8763),
		CwlPdfParser.PdfOperator.c(1004.408, 587.4640999999999, 1007.4639999999999, 584.4075999999999, 1008.876, 580.5275999999999),
		CwlPdfParser.PdfOperator.c(1010.0, 577.8360999999999, 1010.0, 573.7988000000001, 1010.0, 567.07),
		CwlPdfParser.PdfOperator.l(1010.0, 512.93),
		CwlPdfParser.PdfOperator.c(1010.0, 506.2012, 1010.0, 502.1639, 1008.876, 499.4724),
		CwlPdfParser.PdfOperator.c(1007.4639999999999, 495.5924, 1004.408, 492.53589999999997, 1000.528, 491.1237),
		CwlPdfParser.PdfOperator.c(997.8360999999999, 490.0, 993.7988000000001, 490.0, 987.07, 490.0),
		CwlPdfParser.PdfOperator.l(932.93, 490.0),
		CwlPdfParser.PdfOperator.c(926.2012, 490.0, 922.1639, 490.0, 919.4724, 491.1237),
		CwlPdfParser.PdfOperator.c(915.5924, 492.53589999999997, 912.5359, 495.5924, 911.1237000000001, 499.4724),
		CwlPdfParser.PdfOperator.c(910.0, 502.1639, 910.0, 506.2012, 910.0, 512.93),
		CwlPdfParser.PdfOperator.l(910.0, 567.07),
		CwlPdfParser.PdfOperator.c(910.0, 573.7988000000001, 910.0, 577.8360999999999, 911.1237000000001, 580.5275999999999),
		CwlPdfParser.PdfOperator.c(912.5359, 584.4075999999999, 915.5924, 587.4640999999999, 919.4724, 588.8763),
		CwlPdfParser.PdfOperator.c(922.1639, 590.0, 926.2012, 590.0, 932.93, 590.0),
		CwlPdfParser.PdfOperator.h,
		CwlPdfParser.PdfOperator.m(932.93, 590.0),
		CwlPdfParser.PdfOperator.W,
		CwlPdfParser.PdfOperator.n,
		CwlPdfParser.PdfOperator.m(932.93, 590.0),
		CwlPdfParser.PdfOperator.l(987.07, 590.0),
		CwlPdfParser.PdfOperator.c(993.7988000000001, 590.0, 997.8360999999999, 590.0, 1000.528, 588.8763),
		CwlPdfParser.PdfOperator.c(1004.408, 587.4640999999999, 1007.4639999999999, 584.4075999999999, 1008.876, 580.5275999999999),
		CwlPdfParser.PdfOperator.c(1010.0, 577.8360999999999, 1010.0, 573.7988000000001, 1010.0, 567.07),
		CwlPdfParser.PdfOperator.l(1010.0, 512.93),
		CwlPdfParser.PdfOperator.c(1010.0, 506.2012, 1010.0, 502.1639, 1008.876, 499.4724),
		CwlPdfParser.PdfOperator.c(1007.4639999999999, 495.5924, 1004.408, 492.53589999999997, 1000.528, 491.1237),
		CwlPdfParser.PdfOperator.c(997.8360999999999, 490.0, 993.7988000000001, 490.0, 987.07, 490.0),
		CwlPdfParser.PdfOperator.l(932.93, 490.0),
		CwlPdfParser.PdfOperator.c(926.2012, 490.0, 922.1639, 490.0, 919.4724, 491.1237),
		CwlPdfParser.PdfOperator.c(915.5924, 492.53589999999997, 912.5359, 495.5924, 911.1237000000001, 499.4724),
		CwlPdfParser.PdfOperator.c(910.0, 502.1639, 910.0, 506.2012, 910.0, 512.93),
		CwlPdfParser.PdfOperator.l(910.0, 567.07),
		CwlPdfParser.PdfOperator.c(910.0, 573.7988000000001, 910.0, 577.8360999999999, 911.1237000000001, 580.5275999999999),
		CwlPdfParser.PdfOperator.c(912.5359, 584.4075999999999, 915.5924, 587.4640999999999, 919.4724, 588.8763),
		CwlPdfParser.PdfOperator.c(922.1639, 590.0, 926.2012, 590.0, 932.93, 590.0),
		CwlPdfParser.PdfOperator.h,
		CwlPdfParser.PdfOperator.m(932.93, 590.0),
		CwlPdfParser.PdfOperator.W,
		CwlPdfParser.PdfOperator.n,
		CwlPdfParser.PdfOperator.re(0.0, 0.0, 1920.0, 1080.0),
		CwlPdfParser.PdfOperator.W,
		CwlPdfParser.PdfOperator.n,
		CwlPdfParser.PdfOperator.ri("Perceptual"),
		CwlPdfParser.PdfOperator.q,
		CwlPdfParser.PdfOperator.cm(0.0, -1.02, -1.02, 0.0, 960.0, 591.0),
		CwlPdfParser.PdfOperator.sh("Sh1"),
		CwlPdfParser.PdfOperator.Q,
		CwlPdfParser.PdfOperator.EMC,
		CwlPdfParser.PdfOperator.Q
	]
}
