# CwlPdfLib

This checklist maps major ISO 32000-1 (PDF 1.7) areas to the current implementation in this repository.
Each item includes status, key files, and whether implementation is custom or platform-backed.

Legend: Implemented, Partial, Not Implemented.

## 1. File Structure and Syntax
- Implemented: Header parsing (%PDF-x.y) in `Sources/CwlPdfParser/Parsing/PdfHeader+PdfContextParseable.swift` (custom parser).
- Implemented: startxref and EOF marker parsing in `Sources/CwlPdfParser/Parsing/PdfStartXrefAndEof+PdfContextParseable.swift` (custom parser).
- Implemented: Classic xref tables and trailers in `Sources/CwlPdfParser/Parsing/PdfXRefTable+PdfContextParseable.swift` (custom parser).
- Implemented: Indirect objects and basic object grammar in `Sources/CwlPdfParser/Parsing/PdfObject+PdfContextParseable.swift` and `Sources/CwlPdfParser/Parsing/PdfToken+PdfContextParseable.swift` (custom parser).
- Implemented: Null object tokenization exists but is not converted into `.null` in the object parser; extend `PdfObject.parseNext` in `Sources/CwlPdfParser/Parsing/PdfObject+PdfContextParseable.swift` (custom).
- Implemented: XRef streams and object streams (PDF 1.5+) should be added to `Sources/CwlPdfParser/Parsing/` alongside `PdfXRefTable` parsing; custom implementation (no platform feature).
- Implemented: Hybrid-reference files (xref table + xref stream) should be handled in `PdfDocument`/`PdfXRefTable.parseXrefTables`; custom implementation.

## 2. Filters and Stream Decoding
- Implemented: FlateDecode with TIFF/PNG predictors in `Sources/CwlPdfParser/Encodings/StreamFilters.swift` (custom; uses zlib/Compression).
- Partial: DCTDecode and JPXDecode are accepted only for images; non-image streams reject these filters in `Sources/CwlPdfParser/Encodings/StreamFilters.swift` (custom; decoding uses ImageIO in view layer).
- Not Implemented: ASCII85Decode, ASCIIHexDecode, LZWDecode, RunLengthDecode, CCITTFaxDecode, JBIG2Decode; add to `Sources/CwlPdfParser/Encodings/StreamFilters.swift` (custom, common libraries: zlib for LZW variants, libtiff/libjbig2dec for CCITT/JBIG2, or implement in Swift).

## 3. Document Structure
- Implemented: Catalog and Page Tree traversal in `Sources/CwlPdfParser/Document/PdfDocument.swift` (custom).
- Implemented: Page boxes (CropBox/MediaBox) in `Sources/CwlPdfParser/Document/PdfPage.swift` (custom).
- Not Implemented: Outlines (bookmarks) should be added to `Sources/CwlPdfParser/Document/` as a new model and parsed from catalog `Outlines`; custom.
- Not Implemented: Name trees / number trees should be added in `Sources/CwlPdfParser/Objects/` with helper parsing (custom).
- Not Implemented: Metadata (XMP) should be exposed in `PdfDocument` from the catalog `/Metadata` stream; parsing can use a platform XML parser (Foundation XMLParser).
- Not Implemented: Tagged PDF structure tree should be added in `Sources/CwlPdfParser/Document/` (custom).
- Not Implemented: Optional Content Groups (layers) should be parsed in `Sources/CwlPdfParser/Document/` and integrated into rendering state; custom.

## 4. Graphics Operators and Rendering
- Implemented: Most core content stream operators in `Sources/CwlPdfParser/Objects/PdfOperator.swift` and `Sources/CwlPdfParser/Parsing/PdfOperator+PdfContextOptionalParseable.swift` (custom parsing).
- Implemented: Rendering of paths, color ops, text ops, XObject Do, clipping, and basic graphics state in `Sources/CwlPdfView/Rendering/PdfContentStream+render.swift` (platform: CoreGraphics).
- Partial: Inline images (`BI/ID/EI`) are parsed but ignored in rendering; implement in `PdfContentStream+render.swift` (platform: CoreGraphics for image draw, custom inline-image decoding).
- Partial: Compatibility operators (`BX/EX`) are ignored; should affect operator error handling in `PdfContentStream+render.swift` (custom).
- Not Implemented: Pattern paint (`Pattern` colorspace and `sh` pattern resources) should be implemented in `Sources/CwlPdfParser/Graphics/` and `Sources/CwlPdfView/Rendering/` (custom + CoreGraphics patterns).

## 5. Color Spaces and Shadings
- Implemented: DeviceGray/RGB/CMYK in `Sources/CwlPdfParser/Graphics/PdfColorSpace.swift` (custom) and `Sources/CwlPdfView/Rendering/ColorState.swift` (platform: CoreGraphics color spaces).
- Implemented: Indexed and ICCBased color spaces in `Sources/CwlPdfParser/Graphics/PdfColorSpace.swift` and image rendering in `Sources/CwlPdfView/Rendering/PdfImage+CGImage.swift` (custom parse; platform: CoreGraphics).
- Partial: Shadings Type 2 (axial) and Type 3 (radial) in `Sources/CwlPdfParser/Graphics/PdfShading.swift` and `Sources/CwlPdfView/Rendering/PdfShading+CGShading.swift` (custom parse; platform: CoreGraphics shading).
- Not Implemented: CalGray, CalRGB, Lab, Separation, DeviceN color spaces should be added to `Sources/CwlPdfParser/Graphics/PdfColorSpace.swift`; custom (optional use of ColorSync/CGColorSpace for conversions).
- Not Implemented: Shading Types 4-7 (mesh) should be added to `Sources/CwlPdfParser/Graphics/PdfShading.swift` and rendered in `Sources/CwlPdfView/Rendering/` (custom; can use CoreGraphics gradients only for simplified cases).

## 6. Images
- Implemented: Image XObjects with raw/Flate, DCT (JPEG), JPX (JPEG2000) in `Sources/CwlPdfParser/Graphics/PdfImage.swift` and `Sources/CwlPdfView/Rendering/PdfImage+CGImage.swift` (custom parse; platform: ImageIO/CoreGraphics).
- Partial: ImageMask is parsed but not rendered as a stencil mask; implement in `PdfImage+CGImage.swift` and `PdfContentStream+render.swift` (platform: CoreGraphics masking).
- Partial: Soft mask (`/SMask`) for images is supported in `PdfImage+CGImage.swift`, but color key masks (`/Mask`) are not; add in `PdfImage+CGImage.swift` (platform: CoreGraphics image masking).
- Not Implemented: Inline images should be decoded from content streams in `Sources/CwlPdfParser/Objects/PdfContentStream.swift` and rendered in `PdfContentStream+render.swift` (custom + CoreGraphics).

## 7. Fonts and Text
- Implemented: Type1, TrueType, Type0, Type3 parsing and metrics in `Sources/CwlPdfParser/Graphics/PdfFont.swift` (custom parse).
- Implemented: Simple encodings and Differences in `Sources/CwlPdfParser/Graphics/PdfFont.swift` (custom).
- Implemented: ToUnicode CMap parsing in `Sources/CwlPdfParser/Graphics/PdfFont.swift` (custom).
- Implemented: Text rendering via CoreText in `Sources/CwlPdfView/Rendering/TextState.swift` (platform: CoreText/CoreGraphics).
- Partial: Predefined CMaps limited to Identity-H/Identity-V; add more in `PdfFont.parseCMap` in `Sources/CwlPdfParser/Graphics/PdfFont.swift` (custom; could use Adobe CMap resources if available).
- Partial: CMap parsing ignores `usecmap` and many operators; extend `parseCMap` in `Sources/CwlPdfParser/Graphics/PdfFont.swift` (custom).
- Not Implemented: Font substitution for missing embedded fonts should be added in `PdfFont.buildFont` or rendering fallback in `TextState` (platform: CoreText font fallback, custom mapping).
- Not Implemented: Type 1C/CFF and OpenType CFF parsing beyond CoreText handling should be added in `Sources/CwlPdfParser/Graphics/` if needed (custom or use a CFF library).

## 8. Transparency and Extended Graphics State
- Implemented: ExtGState alpha, blend modes, line attributes, dash, flatness, soft masks in `Sources/CwlPdfParser/Graphics/PdfExtGState.swift` and `Sources/CwlPdfView/Rendering/CGContext+applyGState.swift` (custom parse; platform: CoreGraphics).
- Partial: Soft mask rendering uses the transparency group but does not model full transparency group isolation/knockout; extend `PdfSMask` and rendering in `Sources/CwlPdfView/Rendering/` (custom; CoreGraphics compositing).
- Not Implemented: Transparency groups (`/Group` with I/K) for general XObjects should be handled in `PdfContentStream+render.swift` (custom; CoreGraphics group compositing).

## 9. Annotations and Forms
- Implemented: Annotation appearance streams are rendered for `/AP` normal appearances in `Sources/CwlPdfView/Rendering/PdfPage+render.swift` (custom parse; platform: CoreGraphics).
- Not Implemented: Annotation types, actions, borders, and interactive behavior should be implemented in `Sources/CwlPdfView/Views/` or a new interaction layer (platform: AppKit/SwiftUI as needed).
- Not Implemented: AcroForm parsing and widget appearances should be added to `Sources/CwlPdfParser/Document/` with rendering in `Sources/CwlPdfView/Rendering/` (custom; platform for UI widgets if interactive).

## 10. Encryption and Security
- Implemented: Standard security handler V1-5 (RC4, AESV2, AESV3), crypt filters, and password validation in `Sources/CwlPdfParser/Encryption/` (custom; uses CommonCrypto).
- Partial: Only DocOpen AuthEvent is respected for crypt filters; extend `PdfDecryption` for other AuthEvent values if needed (custom).
- Not Implemented: Public-key security (PKI) should be added under `Sources/CwlPdfParser/Encryption/` (custom; could use platform Security framework).

## 11. Linearization and Incremental Updates
- Partial: Incremental update chain via `/Prev` trailer is supported for classic xref tables in `Sources/CwlPdfParser/Parsing/PdfXRefTable+PdfContextParseable.swift` (custom).
- Not Implemented: Linearized PDFs (fast web view) should be detected and parsed near `PdfDocument.init` and `PdfXRefTable.parseXrefTables` (custom).
- Not Implemented: Incremental updates for xref streams should be added once xref streams are supported (custom).

## 12. Miscellaneous Features
- Not Implemented: Digital signatures (`/Sig`) should be added to `Sources/CwlPdfParser/Document/` and validation can use platform Security/Crypto APIs.
- Not Implemented: File attachments, embedded files, and file specs should be parsed in `Sources/CwlPdfParser/Document/` (custom; platform for file handling).
- Not Implemented: JavaScript actions and multimedia features should be explicitly ignored or sandboxed in `Sources/CwlPdfParser/Document/` (custom; avoid execution by default).

