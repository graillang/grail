/* Core ABI contract checks: version, error text, errno mapping, Unicode. */
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "../../include/grail/grail_abi.h"
#include "../../include/grail/grail_error.h"
#include "../../include/grail/grail_unicode.h"
#include "../../runtime/abi/grail_internal.h"

static int failures;
static int checks;

#define CHECK(condition)                                                       \
    do {                                                                       \
        checks++;                                                              \
        if (!(condition)) {                                                    \
            fprintf(stderr, "%s:%d: CHECK failed: %s\n", __FILE__, __LINE__,   \
                    #condition);                                               \
            failures++;                                                        \
        }                                                                      \
    } while (0)

static void check_text(grail_status status, const char *expected) {
    uint8_t buffer[64];
    const uint64_t expected_length = (uint64_t)strlen(expected);
    memset(buffer, 0xAA, sizeof(buffer));
    const grail_result result = grail_error_text(status, buffer, sizeof(buffer));
    CHECK(result == (grail_result)expected_length);
    CHECK(memcmp(buffer, expected, (size_t)expected_length) == 0);
    CHECK(grail_error_text(status, NULL, 0) == (grail_result)expected_length);
    if (expected_length > 0) {
        uint8_t small[64];
        memset(small, 0xAA, sizeof(small));
        CHECK(grail_error_text(status, small, expected_length - 1) ==
              (grail_result)expected_length);
        CHECK(small[0] == 0xAA);
    }
}

static void test_version(void) {
    CHECK(grail_abi_version() == GRAIL_ABI_VERSION);
    CHECK((grail_abi_version() >> 32) == GRAIL_ABI_MAJOR);
    CHECK((grail_abi_version() & 0xFFFFFFFFu) == GRAIL_ABI_MINOR);
    CHECK(grail_abi_check(GRAIL_ABI_MAJOR, GRAIL_ABI_MINOR) == GRAIL_OK);
    CHECK(grail_abi_check(GRAIL_ABI_MAJOR, 0) == GRAIL_OK);
    CHECK(grail_abi_check(GRAIL_ABI_MAJOR, GRAIL_ABI_MINOR + 1) == GRAIL_E_UNSUPPORTED);
    CHECK(grail_abi_check(GRAIL_ABI_MAJOR + 1, 0) == GRAIL_E_UNSUPPORTED);
}

static void test_errors(void) {
    check_text(GRAIL_OK, "success");
    check_text(GRAIL_E_INVALID_ARGUMENT, "invalid argument");
    check_text(GRAIL_E_NOT_FOUND, "not found");
    check_text(GRAIL_E_ACCESS_DENIED, "access denied");
    check_text(GRAIL_E_ALREADY_EXISTS, "already exists");
    check_text(GRAIL_E_DIRECTORY_NOT_EMPTY, "directory not empty");
    check_text(GRAIL_E_UNSUPPORTED, "operation not supported");
    check_text(GRAIL_E_SYSTEM, "system error");
    check_text((grail_status)-9999, "unknown error");

    CHECK(grail_error_is_transient(GRAIL_E_WOULD_BLOCK) == 1);
    CHECK(grail_error_is_transient(GRAIL_E_INTERRUPTED) == 1);
    CHECK(grail_error_is_transient(GRAIL_E_TIMED_OUT) == 1);
    CHECK(grail_error_is_transient(GRAIL_E_BUSY) == 1);
    CHECK(grail_error_is_transient(GRAIL_E_NOT_FOUND) == 0);
    CHECK(grail_error_is_transient(GRAIL_OK) == 0);

    CHECK(grail_os_status_from_errno(0) == GRAIL_OK);
    CHECK(grail_os_status_from_errno(ENOENT) == GRAIL_E_NOT_FOUND);
    CHECK(grail_os_status_from_errno(EACCES) == GRAIL_E_ACCESS_DENIED);
    CHECK(grail_os_status_from_errno(EPERM) == GRAIL_E_ACCESS_DENIED);
    CHECK(grail_os_status_from_errno(EEXIST) == GRAIL_E_ALREADY_EXISTS);
    CHECK(grail_os_status_from_errno(ENOTDIR) == GRAIL_E_NOT_A_DIRECTORY);
    CHECK(grail_os_status_from_errno(EISDIR) == GRAIL_E_IS_A_DIRECTORY);
    CHECK(grail_os_status_from_errno(ENOTEMPTY) == GRAIL_E_DIRECTORY_NOT_EMPTY);
    CHECK(grail_os_status_from_errno(ENAMETOOLONG) == GRAIL_E_NAME_TOO_LONG);
    CHECK(grail_os_status_from_errno(ENOSPC) == GRAIL_E_NO_SPACE);
    CHECK(grail_os_status_from_errno(EROFS) == GRAIL_E_READ_ONLY);
    CHECK(grail_os_status_from_errno(EBUSY) == GRAIL_E_BUSY);
    CHECK(grail_os_status_from_errno(ETIMEDOUT) == GRAIL_E_TIMED_OUT);
    CHECK(grail_os_status_from_errno(EAGAIN) == GRAIL_E_WOULD_BLOCK);
    CHECK(grail_os_status_from_errno(EINTR) == GRAIL_E_INTERRUPTED);
    CHECK(grail_os_status_from_errno(ECONNRESET) == GRAIL_E_CONNECTION_RESET);
    CHECK(grail_os_status_from_errno(ECONNREFUSED) == GRAIL_E_CONNECTION_REFUSED);
    CHECK(grail_os_status_from_errno(ECONNABORTED) == GRAIL_E_CONNECTION_ABORTED);
    CHECK(grail_os_status_from_errno(ENETUNREACH) == GRAIL_E_NETWORK_UNREACHABLE);
    CHECK(grail_os_status_from_errno(EADDRINUSE) == GRAIL_E_ADDRESS_IN_USE);
    CHECK(grail_os_status_from_errno(EADDRNOTAVAIL) == GRAIL_E_ADDRESS_INVALID);
    CHECK(grail_os_status_from_errno(EMSGSIZE) == GRAIL_E_MESSAGE_TOO_LARGE);
    CHECK(grail_os_status_from_errno(ENOTSUP) == GRAIL_E_UNSUPPORTED);
    CHECK(grail_os_status_from_errno(EPIPE) == GRAIL_E_BROKEN_PIPE);
    CHECK(grail_os_status_from_errno(ENOMEM) == GRAIL_E_OUT_OF_MEMORY);
    CHECK(grail_os_status_from_errno(EMFILE) == GRAIL_E_TOO_MANY_HANDLES);
    CHECK(grail_os_status_from_errno(ELOOP) == GRAIL_E_SYMLINK_LOOP);
    CHECK(grail_os_status_from_errno(EXDEV) == GRAIL_E_CROSS_DEVICE);
    CHECK(grail_os_status_from_errno(ESPIPE) == GRAIL_E_NOT_SEEKABLE);
    CHECK(grail_os_status_from_errno(9999) == GRAIL_E_SYSTEM);
#ifdef EDQUOT
    CHECK(grail_os_status_from_errno(EDQUOT) == GRAIL_E_QUOTA_EXCEEDED);
#endif
    CHECK(grail_os_status_from_win32(2) == GRAIL_E_NOT_FOUND);
    CHECK(grail_os_status_from_win32(5) == GRAIL_E_ACCESS_DENIED);
    CHECK(grail_os_status_from_win32(183) == GRAIL_E_ALREADY_EXISTS);
    CHECK(grail_os_status_from_win32(10061) == GRAIL_E_CONNECTION_REFUSED);
    CHECK(grail_os_status_from_win32(8) == GRAIL_E_OUT_OF_MEMORY);
    CHECK(grail_os_status_from_win32(87) == GRAIL_E_INVALID_ARGUMENT);
    CHECK(grail_os_status_from_win32(9999) == GRAIL_E_SYSTEM);
    CHECK(grail_os_status_from_mach(0) == GRAIL_OK);
    CHECK(grail_os_status_from_mach(3) == GRAIL_E_ACCESS_DENIED);
    CHECK(grail_os_status_from_mach(15) == GRAIL_E_INTERRUPTED);
    CHECK(grail_os_status_from_mach(9999) == GRAIL_E_SYSTEM);
}

static void test_utf8_validation(void) {
    uint64_t offset = 12345;
    const uint8_t valid[] = {'a', 0xC3, 0xA9, 0xE2, 0x82, 0xAC, 0xF0, 0x9F, 0x98, 0x80};
    const uint8_t max_scalar[] = {0xF4, 0x8F, 0xBF, 0xBF};
    CHECK(grail_os_utf8_validate(valid, sizeof(valid), &offset) == GRAIL_OK);
    CHECK(offset == 0);
    CHECK(grail_os_utf8_validate(max_scalar, sizeof(max_scalar), NULL) == GRAIL_OK);
    CHECK(grail_os_utf8_validate(NULL, 0, NULL) == GRAIL_OK);

    const struct {
        uint8_t bytes[6];
        uint64_t length;
        uint64_t offset;
    } invalid[] = {
        {{0xC0, 0x80, 0, 0, 0, 0}, 2, 0},             /* overlong NUL */
        {{0xE0, 0x80, 0x80, 0, 0, 0}, 3, 0},          /* overlong */
        {{0xED, 0xA0, 0x80, 0, 0, 0}, 3, 0},          /* surrogate */
        {{0xF4, 0x90, 0x80, 0x80, 0, 0}, 4, 0},       /* above U+10FFFF */
        {{0xF8, 0x88, 0x80, 0x80, 0x80, 0}, 5, 0},    /* five-byte form */
        {{0xE2, 0x82, 0, 0, 0, 0}, 2, 0},             /* truncated */
        {{0x80, 0, 0, 0, 0, 0}, 1, 0},                /* lone continuation */
        {{'a', 0xC0, 0x80, 0, 0, 0}, 3, 1},           /* offset after 'a' */
    };
    for (uint64_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
        offset = 999;
        CHECK(grail_os_utf8_validate(invalid[i].bytes, invalid[i].length, &offset) ==
              GRAIL_E_INVALID_UTF8);
        CHECK(offset == invalid[i].offset);
    }
}

static void test_utf16(void) {
    const uint8_t source[] = {'A', 0xC3, 0xA9, 0xF0, 0x9F, 0x98, 0x80};
    uint16_t units[8];
    memset(units, 0xFF, sizeof(units));
    CHECK(grail_os_utf8_to_utf16(source, sizeof(source), NULL, 0) == 4);
    CHECK(grail_os_utf8_to_utf16(source, sizeof(source), units, 3) == 4);
    CHECK(units[0] == 0xFFFF);
    CHECK(grail_os_utf8_to_utf16(source, sizeof(source), units, 8) == 4);
    CHECK(units[0] == 0x0041);
    CHECK(units[1] == 0x00E9);
    CHECK(units[2] == 0xD83D);
    CHECK(units[3] == 0xDE00);

    uint8_t roundtrip[16];
    memset(roundtrip, 0xAA, sizeof(roundtrip));
    CHECK(grail_os_utf16_to_utf8(units, 4, NULL, 0) == (grail_result)sizeof(source));
    CHECK(grail_os_utf16_to_utf8(units, 4, roundtrip, sizeof(source) - 1) ==
          (grail_result)sizeof(source));
    CHECK(roundtrip[0] == 0xAA);
    CHECK(grail_os_utf16_to_utf8(units, 4, roundtrip, sizeof(roundtrip)) ==
          (grail_result)sizeof(source));
    CHECK(memcmp(roundtrip, source, sizeof(source)) == 0);

    const uint16_t lone_high[] = {0xD800};
    const uint16_t lone_low[] = {0xDC00};
    const uint16_t reversed[] = {0xDC00, 0xD800};
    CHECK(grail_os_utf16_to_utf8(lone_high, 1, roundtrip, sizeof(roundtrip)) ==
          GRAIL_E_INVALID_UTF8);
    CHECK(grail_os_utf16_to_utf8(lone_low, 1, roundtrip, sizeof(roundtrip)) ==
          GRAIL_E_INVALID_UTF8);
    CHECK(grail_os_utf16_to_utf8(reversed, 2, roundtrip, sizeof(roundtrip)) ==
          GRAIL_E_INVALID_UTF8);

    CHECK(grail_os_utf8_to_utf16(NULL, 0, NULL, 0) == 0);
    CHECK(grail_os_utf16_to_utf8(NULL, 0, NULL, 0) == 0);
    const uint8_t bad[] = {0xC0, 0x80};
    CHECK(grail_os_utf8_to_utf16(bad, sizeof(bad), units, 8) == GRAIL_E_INVALID_UTF8);
}

int main(void) {
    test_version();
    test_errors();
    test_utf8_validation();
    test_utf16();
    if (failures != 0) {
        fprintf(stderr, "core: %d of %d checks failed\n", failures, checks);
        return 1;
    }
    printf("core: %d checks passed\n", checks);
    return 0;
}
