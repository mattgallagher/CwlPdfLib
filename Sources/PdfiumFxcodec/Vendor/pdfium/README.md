# PDFium fxcodec source subset

This directory contains a minimally modified subset of PDFium's fax and JBIG2
decoders. It was imported from the local PDFium checkout at revision:

`639553c55c040427f9ff54d7485bd1a89d150164`

Upstream repository: <https://pdfium.googlesource.com/pdfium/>

Imported components:

- `core/fxcodec/jbig2/`
- `core/fxcodec/fax/faxmodule.{h,cpp}`
- `core/fxcodec/scanlinedecoder.{h,cpp}`
- `core/fxcodec/fx_codec_def.h`
- The minimal `core/fxcrt/` support subset required by those decoders
- `core/fxge/calculate_pitch.{h,cpp}` and its format declarations

Local compatibility files and changes:

- `build/build_config.h` supplies the Apple/Clang build definitions normally
  supplied by Chromium's build system.
- Windows-only fax encoder dependencies are not shipped. The fax decoder and
  JBIG2 decoder source remain otherwise unchanged.

PDFium is distributed under the BSD-style license in `LICENSE`.
