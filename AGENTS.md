# CwlPdfLib Agent Guidelines

## Build and Test Commands

Use the Xcode MCP tools for all building, testing and project exploration. Avoid command line tools unless strictly necessary.

## Code Style Guidelines

### Copyright inclusion

- All Swift files should start with the header line:

```swift
// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.
```

### Whitespace

Use tabs for indentation and do not trim whitespace from empty lines.

Never use code alignment (multiple spaces outside the indentation intended to create
columns). If you need to break a function call over multiple lines, insert a newline
immediately after an open parenthesis and increase the indentation level until
the closing parenthesis.

```swift
someFunction(
    someParameter: someValue
    someOtherParam: someOtherValue
)
```

If you need a multi-line conditional statement (if or guard), always insert a newline
immediately after the conditional or loop statement keyword and indent each line, then
move the end of conditional (the else and/or opening brace) to a non-indented line after
the multi-line block.

```swift
guard
    someVariable == someValue,
    someOtherVariable == someOtherValue
else {
    // ...
}
```

### Reformatting

- Do NOT use the swift built-in "swift format" command.
- If reformatting is required use swiftformat as follows:

```bash
swiftformat --swiftversion 6 --config .swiftformat "Sources/CwlPdfParser/Document/PdfDocument.swift"
```

### Swift Language Conventions
- Use Swift 6+ features and syntax
- Prefer value types and the `Sendable` protocol for thread-safe types

### Import Organization
- Keep imports in alphabetical order

### Type Definitions and Aliases
- Use type aliases for clarity when dealing with complex PDF structures:
  - `PdfArray` = `[PdfObject]`
  - `PdfDictionary` = `[String: PdfObject]`

### Documentation and Comments
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
