/*
 * Internal helpers shared by Grail OS backends and the ABI tests.  Not part of
 * the public contract: no symbol declared here is exported to Grail programs
 * or to C hosts.
 */
#ifndef GRAIL_INTERNAL_H
#define GRAIL_INTERNAL_H

#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Maps a POSIX errno value to the portable status set. */
grail_status grail_os_status_from_errno(int64_t error_number);

/* Maps a Win32 GetLastError()/WSA error value to the portable status set. */
grail_status grail_os_status_from_win32(int64_t error_number);

/* Maps a Mach kern_return_t value to the portable status set. */
grail_status grail_os_status_from_mach(int64_t error_number);

/*
 * Writes `length` bytes to a caller buffer following the ABI output rule:
 * returns `length`, and writes nothing when `capacity` is too small.
 * `out` may be NULL only when `capacity` is 0.
 */
grail_result grail_abi_copy_out(const uint8_t *bytes, uint64_t length, uint8_t *out,
                                uint64_t capacity);

/* Length of a NUL-terminated string, without crossing `limit`. */
uint64_t grail_abi_bounded_length(const char *text, uint64_t limit);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_INTERNAL_H */
