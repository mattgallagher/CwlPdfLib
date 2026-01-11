# CwlPdfLib

A standalone Swift package that implements large parts of PDF 1.4 parsing and rendering via CGContext. It's bigger than a simple "toy" parser but it's not really thorough enough for any serious use without substantial additional work. I was just curious to explore how PDF content streams were structured.

The core tokenising and parsing is handwritten Swift, with reference taken from Onyx2D from The Cocotron, Poppler, xpdf and pdfium. Some of the peripheral features I didn't really care about (encryption, font support, colorspaces, images, SMasks) came from some experiments with different agentic LLM models.
