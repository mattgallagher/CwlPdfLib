// CwlPdfLib. Copyright © 2026 Matt Gallagher. See LICENSE file for usage permissions.

#include "PdfiumFxcodec.h"

#include <limits>
#include <new>

#include "core/fxcodec/jbig2/JBig2_DocumentContext.h"
#include "core/fxcodec/jbig2/jbig2_decoder.h"
#include "core/fxcrt/span.h"

namespace {

constexpr size_t kMaximumDecodedBytes = 512u * 1024u * 1024u;

}  // namespace

size_t pdfium_fxcodec_jbig2_stride(uint32_t width) {
	if (width == 0 || width > std::numeric_limits<uint32_t>::max() - 31u) {
		return 0;
	}
	return static_cast<size_t>((width + 31u) / 32u) * 4u;
}

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
) {
	const size_t minimum_stride = pdfium_fxcodec_jbig2_stride(width);
	if (
		source == nullptr || source_length == 0 || destination == nullptr ||
		width == 0 || height == 0 || minimum_stride == 0 ||
		destination_stride < minimum_stride || destination_stride % 4u != 0 ||
		(globals == nullptr && globals_length != 0)
	) {
		return PdfiumFxcodecResultInvalidArgument;
	}
	if (
		height > std::numeric_limits<size_t>::max() / destination_stride ||
		destination_stride * static_cast<size_t>(height) > kMaximumDecodedBytes
	) {
		return PdfiumFxcodecResultOutputTooLarge;
	}
	const size_t required_length = destination_stride * static_cast<size_t>(height);
	if (
		destination_length < required_length ||
		destination_stride > std::numeric_limits<uint32_t>::max()
	) {
		return PdfiumFxcodecResultInvalidArgument;
	}

	try {
		JBig2_DocumentContext document_context;
		Jbig2Context context;
		const pdfium::span<const uint8_t> source_span(source, source_length);
		const pdfium::span<const uint8_t> globals_span = globals == nullptr
			? pdfium::span<const uint8_t>()
			: pdfium::span<const uint8_t>(globals, globals_length);
		pdfium::span<uint8_t> destination_span(destination, required_length);

		FXCODEC_STATUS status = Jbig2Decoder::StartDecode(
			&context,
			&document_context,
			width,
			height,
			source_span,
			1,
			globals_span,
			1,
			destination_span,
			static_cast<uint32_t>(destination_stride),
			nullptr,
			false
		);
		while (status == FXCODEC_STATUS::kDecodeToBeContinued) {
			status = Jbig2Decoder::ContinueDecode(&context, nullptr);
		}
		return status == FXCODEC_STATUS::kDecodeFinished
			? PdfiumFxcodecResultSuccess
			: PdfiumFxcodecResultInvalidData;
	} catch (const std::bad_alloc&) {
		return PdfiumFxcodecResultAllocationFailure;
	} catch (...) {
		return PdfiumFxcodecResultInvalidData;
	}
}
