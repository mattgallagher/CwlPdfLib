// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

#ifndef PDFIUM_FXCODEC_H
#define PDFIUM_FXCODEC_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum PdfiumFxcodecResult {
	PdfiumFxcodecResultSuccess = 0,
	PdfiumFxcodecResultInvalidArgument = 1,
	PdfiumFxcodecResultInvalidData = 2,
	PdfiumFxcodecResultOutputTooLarge = 3,
	PdfiumFxcodecResultAllocationFailure = 4
} PdfiumFxcodecResult;

/** Returns the required four-byte-aligned destination stride for a 1-bit image. */
size_t pdfium_fxcodec_jbig2_stride(uint32_t width);

/**
 * Decodes a PDF-embedded JBIG2 stream into a packed 1-bit image.
 *
 * The destination must contain at least `destination_stride * height` bytes.
 * `destination_stride` must be at least the value returned by
 * `pdfium_fxcodec_jbig2_stride(width)` and must be divisible by four.
 */
PdfiumFxcodecResult pdfium_fxcodec_jbig2_decode(
	const uint8_t *source,
	size_t source_length,
	const uint8_t *globals,
	size_t globals_length,
	uint32_t width,
	uint32_t height,
	uint8_t *destination,
	size_t destination_length,
	size_t destination_stride
);

#ifdef __cplusplus
}
#endif

#endif  // PDFIUM_FXCODEC_H
