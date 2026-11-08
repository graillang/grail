/*
 * Grail cross-platform OS ABI: core definitions.
 *
 * This header is the stable contract between the Grail runtime, its native
 * OS backends, and C code reached through `extern "C"`.  It is not a C
 * implementation of the runtime and is not linked into Grail programs.
 *
 * Boundary rules (normative; see docs/design/runtime-abi.md):
 *  - every scalar argument and result is 64 bits wide;
 *  - no structure is passed or returned by value; structures cross by pointer;
 *  - no floating-point value crosses this ABI;
 *  - byte inputs are (pointer, length) pairs, never NUL-terminated text;
 *  - byte outputs are (pointer, capacity) pairs and return the required length;
 *  - a negative grail_status/grail_result is a portable error code;
 *  - handles are non-zero opaque 64-bit identifiers owned by exactly one closer.
 *
 * All supported targets are 64-bit: x86_64 and AArch64 on Linux, macOS and
 * Windows, and RISC-V 64 on Linux.  The header deliberately refuses 32-bit
 * targets.
 */
#ifndef GRAIL_ABI_H
#define GRAIL_ABI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GRAIL_ABI_MAJOR 1u
#define GRAIL_ABI_MINOR 0u
#define GRAIL_ABI_VERSION (((uint64_t)GRAIL_ABI_MAJOR << 32) | (uint64_t)GRAIL_ABI_MINOR)

#if defined(_WIN32) && !defined(GRAIL_ABI_STATIC)
#  if defined(GRAIL_ABI_BUILD)
#    define GRAIL_API __declspec(dllexport)
#  else
#    define GRAIL_API __declspec(dllimport)
#  endif
#  define GRAIL_CALL __cdecl
#else
#  if defined(__GNUC__) && (__GNUC__ >= 4) && !defined(_WIN32)
#    define GRAIL_API __attribute__((visibility("default")))
#  else
#    define GRAIL_API
#  endif
#  define GRAIL_CALL
#endif

/* All scalars are one machine word. */
typedef int64_t grail_i64;
typedef uint64_t grail_u64;
typedef uint64_t grail_len;

/* 0 is success; every negative value is a portable error (grail_error.h). */
typedef int64_t grail_status;

/*
 * A length-or-error result used by byte-output and enumeration calls.
 * Non-negative values are a length or item count.  A value greater than the
 * caller's capacity means "required capacity"; nothing was written.  Negative
 * values are portable errors.
 */
typedef int64_t grail_result;

/* Opaque, process-local resource identifier.  Zero is never valid. */
typedef uint64_t grail_handle;
#define GRAIL_HANDLE_NONE ((grail_handle)0)

/* Sentinel for "wait forever" timeouts. */
#define GRAIL_INFINITE ((int64_t)-1)

#if defined(__cplusplus) && (__cplusplus >= 201103L)
#  define GRAIL_STATIC_ASSERT(condition, message) static_assert(condition, message)
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L)
#  define GRAIL_STATIC_ASSERT(condition, message) _Static_assert(condition, message)
#else
#  define GRAIL_STATIC_ASSERT(condition, message) /* C11 or later required */
#endif

GRAIL_STATIC_ASSERT(sizeof(void *) == 8, "the Grail OS ABI requires 64-bit pointers");
GRAIL_STATIC_ASSERT(sizeof(grail_status) == 8, "grail_status must be one word");
GRAIL_STATIC_ASSERT(sizeof(grail_handle) == 8, "grail_handle must be one word");

/*
 * Allocation hooks supplied by the Grail runtime so that backend bookkeeping
 * is visible to the runtime's allocation accounting.  `allocate` must return
 * memory aligned to `alignment` (a power of two) and must not return NULL for
 * a non-zero size; `release` must accept the same size and alignment that
 * produced the block.  `reallocate` may be NULL, in which case the backend
 * emulates it with allocate/copy/release.
 */
typedef struct grail_allocator {
    uint64_t struct_size; /* sizeof(grail_allocator) */
    void *context;
    void *(*allocate)(void *context, uint64_t size, uint64_t alignment);
    void *(*reallocate)(void *context, void *pointer, uint64_t old_size, uint64_t new_size,
                        uint64_t alignment);
    void (*release)(void *context, void *pointer, uint64_t size, uint64_t alignment);
} grail_allocator;

/*
 * Process startup data captured by the entry shim before the runtime starts.
 *
 * `arguments` and `environment` are UTF-8 byte blocks.  Each entry starts at
 * the corresponding offset and ends at the next offset (or the end of the
 * block); every entry is terminated by one zero byte, which is not part of the
 * entry.  `environment` entries have the form NAME=VALUE.  On Windows the shim
 * converts the UTF-16 command line and environment block to this form; on
 * POSIX it validates the incoming bytes.
 *
 * The backend uses this record to seed the deterministic environment copy.  The
 * argument block belongs to the runtime's entry shim; this ABI deliberately has
 * no argv accessor, because Windows obtains it from the wide command line and
 * POSIX from main().
 */
typedef struct grail_startup {
    uint64_t struct_size; /* sizeof(grail_startup) */
    uint64_t abi_version;
    const uint8_t *arguments;
    uint64_t arguments_length;
    const uint64_t *argument_offsets;
    uint64_t argument_count;
    const uint8_t *environment;
    uint64_t environment_length;
    const uint64_t *environment_offsets;
    uint64_t environment_count;
} grail_startup;

/* Raw platform error detail for a call that returned GRAIL_E_SYSTEM. */
typedef struct grail_os_error {
    uint64_t domain; /* GRAIL_OS_DOMAIN_* */
    uint64_t code;   /* errno, Win32 error, kern_return_t or HRESULT value */
} grail_os_error;

#define GRAIL_OS_DOMAIN_NONE 0u
#define GRAIL_OS_DOMAIN_ERRNO 1u
#define GRAIL_OS_DOMAIN_WIN32 2u
#define GRAIL_OS_DOMAIN_MACH 3u
#define GRAIL_OS_DOMAIN_HRESULT 4u

/* Capability bits reported by the initialized backend. */
#define GRAIL_CAP_FILES (1ull << 0)
#define GRAIL_CAP_DIRECTORIES (1ull << 1)
#define GRAIL_CAP_PATHS (1ull << 2)
#define GRAIL_CAP_UNICODE (1ull << 3)
#define GRAIL_CAP_ENVIRONMENT (1ull << 4)
#define GRAIL_CAP_ENV_MUTATION (1ull << 5)
#define GRAIL_CAP_TIME (1ull << 6)
#define GRAIL_CAP_LOCAL_TIME_OFFSET (1ull << 7)
#define GRAIL_CAP_PROCESSES (1ull << 8)
#define GRAIL_CAP_SOCKETS (1ull << 9)
#define GRAIL_CAP_SOCKET_IPV6 (1ull << 10)
#define GRAIL_CAP_SOCKET_UDP (1ull << 11)
#define GRAIL_CAP_RESOLVE (1ull << 12)
#define GRAIL_CAP_THREADS (1ull << 13)
#define GRAIL_CAP_SYNC_PRIMITIVES (1ull << 14)
#define GRAIL_CAP_DYNAMIC_LIBRARIES (1ull << 15)
#define GRAIL_CAP_SYMLINKS (1ull << 16)
#define GRAIL_CAP_CPU_TIME (1ull << 17)

/* Returns GRAIL_ABI_VERSION: major in the high 32 bits, minor in the low. */
GRAIL_API uint64_t GRAIL_CALL grail_abi_version(void);

/*
 * Returns 0 when this library can satisfy a caller requiring `major.minor`.
 * Different major versions and newer minor versions return GRAIL_E_UNSUPPORTED.
 */
GRAIL_API grail_status GRAIL_CALL grail_abi_check(uint64_t required_major, uint64_t required_minor);

/*
 * Initializes the OS backend.  `allocator` is required; `startup` may be NULL
 * to start with empty argument and environment tables.  Safe to call once;
 * a second call without an intervening shutdown returns GRAIL_E_UNSUPPORTED.
 * All blocking, thread and resource entry points require initialization;
 * the pure helpers (error text, Unicode, lexical paths) do not.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_init(const grail_allocator *allocator,
                                               const grail_startup *startup);

/* Releases backend bookkeeping.  Handles must already be closed. */
GRAIL_API grail_status GRAIL_CALL grail_os_shutdown(void);

/* Capability bits for this backend; 0 before initialization. */
GRAIL_API uint64_t GRAIL_CALL grail_os_capabilities(void);

/*
 * Copies the calling thread's most recent raw OS error detail.  Returns 0 and
 * zeros `out` when no detail was recorded.  The detail is never cleared by a
 * successful call and is thread-local.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_error_last(grail_os_error *out);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_ABI_H */
