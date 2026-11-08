/*
 * Strict Unicode conversion helpers used by every backend and by the runtime
 * when it crosses an OS boundary.
 *
 * Rules: strict UTF-8 (no overlongs, no surrogates, at most U+10FFFF, no
 * truncated sequences); UTF-16 is a host-endian array of code units, not a
 * byte stream, and unpaired surrogates are rejected.  There is no BOM
 * handling, no CESU-8 and no replacement-character mode.
 */
#ifndef GRAIL_UNICODE_H
#define GRAIL_UNICODE_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Returns GRAIL_OK or GRAIL_E_INVALID_UTF8.  On failure `error_offset`, when
 * non-NULL, receives the byte offset of the first invalid sequence.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_utf8_validate(const uint8_t *text, uint64_t length,
                                                        uint64_t *error_offset);

/*
 * Converts UTF-8 to UTF-16 code units.  Returns the required unit count; if it
 * exceeds `capacity_units`, nothing was written.  `out` may be NULL when the
 * capacity is 0.  Invalid UTF-8 returns GRAIL_E_INVALID_UTF8.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_utf8_to_utf16(const uint8_t *text, uint64_t length,
                                                       uint16_t *out, uint64_t capacity_units);

/*
 * Converts UTF-16 code units to UTF-8 bytes.  Returns the required byte count;
 * if it exceeds `capacity`, nothing was written.  Unpaired surrogates return
 * GRAIL_E_INVALID_UTF8.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_utf16_to_utf8(const uint16_t *units, uint64_t count,
                                                       uint8_t *out, uint64_t capacity);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_UNICODE_H */
