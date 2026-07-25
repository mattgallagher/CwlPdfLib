// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "CwlPdfLib",
	platforms: [.iOS(.v26), .macOS(.v26)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "CwlPdfParser",
			targets: ["CwlPdfParser"]
		),
		.library(
			name: "CwlPdfRenderer",
			targets: ["CwlPdfRenderer"]
		),
		.library(
			name: "CwlPdfView",
			targets: ["CwlPdfView"]
		)
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "PdfiumFxcodec",
			path: "Sources/PdfiumFxcodec",
			publicHeadersPath: "include",
			cxxSettings: [
				.headerSearchPath("Vendor/pdfium")
			]
		),
		.target(
			name: "CwlPdfParser"
		),
		.target(
			name: "CwlPdfRenderer",
			dependencies: ["CwlPdfParser", "PdfiumFxcodec"]
		),
		.target(
			name: "CwlPdfView",
			dependencies: ["CwlPdfParser", "CwlPdfRenderer"],
			swiftSettings: [
				.defaultIsolation(MainActor.self)
			]
		),
		.testTarget(
			name: "CwlPdfLibTests",
			dependencies: ["CwlPdfParser", "CwlPdfRenderer", "CwlPdfView"],
			resources: [.copy("Fixtures")]
		)
	],
	cxxLanguageStandard: .cxx20
)
