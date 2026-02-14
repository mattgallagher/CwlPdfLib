# CwlPdfLib

This is a Swift Package implementing PDF parsing, rendering and object inspection; targetting macOS 26; compiling using Swift 6.2

## Definition of Done

A task is complete when all of the following are true:

- The requested behavior change is implemented and matches existing architecture.
- `swift build` succeeds.
- `swift test` succeeds, or any failures are reported with clear scope.
- New or changed behavior has tests (unless the task is explicitly docs-only or refactor-only).
- Diffs are minimal and limited to relevant files (no unrelated reformatting).

## Build and Test Commands

### Build package
```bash
swift build
```

### Run tests
All tests:
```bash
swift test
```

Single test case:
```bash
swift test --filter "GIVEN a pdf file WHEN PdfDocument.init THEN trailer parsed"
```

Specific test file/suite:
```bash
swift test --filter "PdfDocumentTests"
```

Tests with coverage:
```bash
swift test --enable-code-coverage
```

## Version and Platform Baseline

- Swift tools version is `6.2` (see `Package.swift`).
- Target platforms are iOS 26 and macOS 26.
- Use Swift 6+ language features compatible with the package baseline.

## Architecture Map (Common Types and Entry Points)

Use this as a fast navigation guide before broad searching.

- `PdfDocument` (document loading/trailer/root): `Sources/CwlPdfParser/Document/PdfDocument.swift`
- `PdfPage` (page model): `Sources/CwlPdfParser/Document/PdfPage.swift`
- `PdfObjectLookup` (object offset map and object loading support): `Sources/CwlPdfParser/Objects/PdfObjectLookup.swift`
- `PdfObject`, `PdfStream`, `PdfContentStream` (core object model):
  - `Sources/CwlPdfParser/Objects/PdfObject.swift`
  - `Sources/CwlPdfParser/Objects/PdfStream.swift`
  - `Sources/CwlPdfParser/Objects/PdfContentStream.swift`
- Parse context and errors:
  - `Sources/CwlPdfParser/Helpers/PdfParseContext.swift`
  - `Sources/CwlPdfParser/Helpers/PdfParseError.swift`
- Source abstractions:
  - `Sources/CwlPdfParser/Sources/PdfSource.swift`
  - `Sources/CwlPdfParser/Sources/PdfFileSource.swift`
  - `Sources/CwlPdfParser/Sources/PdfDataSource.swift`
- Parser boundary (token/object/xref/header parseables): `Sources/CwlPdfParser/Parsing/`
- Renderer bridge from parser types to CoreGraphics:
  - `Sources/CwlPdfRenderer/PdfPage+render.swift`
  - `Sources/CwlPdfRenderer/PdfContentStream+render.swift`
  - `Sources/CwlPdfRenderer/PdfRect+CGRect.swift`
- View layer (SwiftUI only): `Sources/CwlPdfView/`
- Test suites and fixtures:
  - `Sources/CwlPdfLibTests/*.swift`
  - `Sources/CwlPdfLibTests/Fixtures/`

## File Touch Policy

- Keep edits tightly scoped to the requested task.
- Do not make opportunistic renames or moves unless requested.
- Avoid unrelated formatting churn.
- Preserve existing public APIs unless change is required by the task.

## Code Style Guidelines

- Keep imports, enum cases, and similar lists in alphabetical order where practical.

### Copyright inclusion

- All Swift files should start with:

```swift
// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.
```

### Whitespace

Do not trim whitespace from empty lines.

Never use code alignment (multiple spaces outside indentation intended to create columns).
If breaking a function call over multiple lines, place a newline immediately after `(` and
indent until `)`.

```swift
someFunction(
    someParameter: someValue,
    someOtherParam: someOtherValue
)
```

If a conditional statement must span multiple lines (`if`, `guard`, loops), insert a newline
immediately after the keyword, keep each condition on its own line, and place `else`/`{` after
the condition block.

```swift
guard
    someVariable == someValue,
    someOtherVariable == someOtherValue
else {
    // ...
}
```

### Reformatting

- Do not use `swift format`.
- If reformatting is needed, use:

```bash
swiftformat --swiftversion 6 --config .swiftformat "Sources/CwlPdfParser/Document/PdfDocument.swift"
```

## Swift Language and Type Guidance

- Prefer value types and `Sendable` for thread-safe types.
- Use type aliases for complex PDF structures:
  - `PdfArray` = `[PdfObject]`
  - `PdfDictionary` = `[String: PdfObject]`

## Documentation and Comments

- Use JSDoc-style documentation for new or changed public APIs.
- When touching existing undocumented public APIs, document only those directly involved in the change.
- Add inline comments only for non-obvious parsing logic or invariants.

## Testing Guidance

- Use Swift Testing (`@Test`) for unit tests.
- Prefer extending existing test files by functionality (for example, `PdfDocumentTests`, `PdfFileSourceTests`).
- Fixtures live in `Sources/CwlPdfLibTests/Fixtures/`.
- Reuse existing fixtures when possible; add new fixtures only when they uniquely exercise behavior.
- Keep fixture names descriptive and consistent with existing patterns.

## Package Structure and Boundaries

### PDF handling

- Keep PDF parsing and model logic in `CwlPdfParser`.
- Keep all UI/view logic out of `CwlPdfParser`.
- `CwlPdfParser` must not depend on CoreGraphics types. Use parser-native types (for example `PdfRect`),
  then convert in renderer/view layers.
- Structure parser files by component (Document, Page, Stream, Objects, Parsing, Graphics).

### View components

- Keep SwiftUI views in `CwlPdfView`.
- `CwlPdfView` uses default isolation of `@MainActor`.
- Handle view state with `@State` and `@Binding`.
- Prefer SwiftUI code that runs on both iOS and macOS.

### Error handling

- Use `PdfParseError` to bundle context with `PdfParseFailure` reasons.
- Lower-level parsing functions should throw on failure.
- Higher-level document functions (open/get pages/render) should recover where possible.

### Memory management and performance

- On open, `PdfObjectLookup` builds an accurate object-location map so object loading can read required ranges.
- Avoid eager full-stream/object loading when targeted reads are possible.
- Treat `PdfObjectLookup` as the basis for future caching behavior.

## Guardrails (Do Not Do)

- Do not introduce CoreGraphics dependencies into `CwlPdfParser`.
- Do not move parser logic into `CwlPdfView`.
- Do not replace targeted parsing with broad eager loading without strong justification.

## Commit and PR Conventions

- Use concise commit messages focused on intent and behavior change.
- Keep commits logically scoped.
- In PR descriptions, include:
  - Summary of behavior changes
  - Test coverage added/updated
  - Build/test commands run
