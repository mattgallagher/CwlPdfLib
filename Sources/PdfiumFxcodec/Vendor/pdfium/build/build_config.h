// Copyright 2026 Matt Gallagher.
// Compatibility definitions for the vendored PDFium fxcodec subset.

#ifndef BUILD_BUILD_CONFIG_H_
#define BUILD_BUILD_CONFIG_H_

#if defined(__clang__)
#define COMPILER_CLANG 1
#define COMPILER_GCC 1
#endif

#if defined(__aarch64__) || defined(__arm64__)
#define ARCH_CPU_ARM64 1
#elif defined(__x86_64__)
#define ARCH_CPU_X86_64 1
#define ARCH_CPU_X86_FAMILY 1
#else
#error Unsupported architecture for PdfiumFxcodec
#endif

#define BUILDFLAG_CAT_INDIRECT(a, b) a##b
#define BUILDFLAG_CAT(a, b) BUILDFLAG_CAT_INDIRECT(a, b)
#define BUILDFLAG(flag) (BUILDFLAG_CAT(BUILDFLAG_INTERNAL_, flag)())

#define BUILDFLAG_INTERNAL_IS_ANDROID() (0)
#define BUILDFLAG_INTERNAL_IS_APPLE() (1)
#define BUILDFLAG_INTERNAL_IS_WIN() (0)

#endif  // BUILD_BUILD_CONFIG_H_
