# CwlPdfLib Agent Guidelines

## Build and Test Commands

### Building the Package
```bash
swift build
```

### Running Tests
To run all tests:
```bash
swift test
```

To run a single test case:
```bash
swift test --filter "GIVEN a pdf file WHEN PdfDocument.init THEN trailer parsed"
```

To run a specific test file:
```bash
swift test --filter "PdfDocumentTests"
```

To run tests with code coverage:
```bash
swift test --enable-code-coverage
```

## Code Style Guidelines

### Code Formatting

- Do NOT use the swift built-in "swift format" command.

- DO use swiftformat as follows:

```bash
swiftformat --swiftversion 6 --config .swiftformat "Sources/CwlPdfParser/Document/PdfDocument.swift"
```

- All Swift files should start with the header line:
```swift
// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.
```

- Tab indentation with 3 spaces
- Empty lines must contain the correct tab indentation for their scope (do not trim
  whitespace from empty lines)
- Consistent spacing around operators
- Type and function attributes should be on previous line
- Property attributes should be on the same line

### Swift Language Conventions
- Use Swift 6+ features and syntax
- Prefer value types and the `Sendable` protocol for thread-safe types

### Naming Conventions
- Use PascalCase for types and protocols (e.g., `PdfDocument`, `PdfParseError`)
- Use camelCase for properties and methods (e.g., `objectLayoutFromOffset`, `parseContext`)
- Use descriptive names that clearly indicate purpose
- Prefix public types with `Pdf` for PDF-related structures

### Import Organization
- Keep imports in alphabetical order

### Type Definitions and Aliases
- Use type aliases for clarity when dealing with complex PDF structures:
  - `PdfArray` = `[PdfObject]`
  - `PdfDictionary` = `[String: PdfObject]`

### Documentation and Comments
- Include clear comments on PDF-specific functionality
- Use JSDoc-style documentation for public APIs
- Document complex parsing logic with inline comments

### Error Handling
- Use the `PdfParseError` type to bundle context with the error reason, given by `PdfParseFailure`.
- Parsing functions should throw an error on failure. Higher level document functions (opening a
  document, getting pages, rendering pages) should attempt to recover from failure where possible.

### Memory Management and Performance
- On opening, the `PdfObjectList` builds an accurate map of object locations within the file
  so object loading can accurately read the require range for the object.
- The `PdfObjectList` should maintain a cache of loaded objects for efficiency.
- Large blobs of data from `PdfStream` objects should be handled in a streaming manner to
  optimize memory use and improve performance of compression and encryption filters.

### Testing Approach
- Use Swift's `@Test` attribute for unit testing
- Test with multiple PDF fixtures (blank-page.pdf, single-text-line.pdf, etc.)
- Verify parsing of headers, xref tables, trailers, and streams
- Validate object extraction from various PDF structures

## Package Structure

- This project is a Swift Package
- The files in `CwlPdfApp` are not built as part of the Swift Package

### PDF handling
- Most logic should be kept in the `CwlPdfParser` module but all views should be kept out of
  this module
- `CwlPdfParser` should not use CoreGraphics types but its own types that closely resemble
  CoreGraphics (e.g. `PdfRect` instead of `CGRect`). In the view, these types can be
  extended to convert to CoreGraphics types.
- Structure files by PDF component (Document, Page, Stream, etc.)
- Organize tests by functionality (PdfDocumentTests, PdfFileSourceTests, etc.)

### View Components
- SwiftUI views should be isolated in `CwlPdfView` module
- `CwlPdfView` uses a default isolation of `@MainActor`
- Handle view state properly with `@State` and `@Binding`
- Prefer SwiftUI code that runs on both iOS and macOS
