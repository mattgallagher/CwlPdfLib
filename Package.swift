// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "CwlPdfLib",
	platforms: [.macOS(.v26)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "CwlPdfLib",
			targets: ["CwlPdfLib"]),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "CwlPdfLib",
		),
		.testTarget(
			name: "CwlPdfLibTests",
			dependencies: ["CwlPdfLib"],
			resources: [.copy("Fixtures")]
		)
	]
)
