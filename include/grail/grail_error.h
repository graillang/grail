/*
 * Portable error codes and error text.
 *
 * Codes are ABI-stable negative integers.  Backends translate their native
 * errors into this set and keep the raw detail in grail_os_error_last().
 */
#ifndef GRAIL_ERROR_H
#define GRAIL_ERROR_H

#include "grail_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GRAIL_OK ((grail_status)0)

#define GRAIL_E_INVALID_ARGUMENT ((grail_status)-1)
#define GRAIL_E_INVALID_HANDLE ((grail_status)-2)
#define GRAIL_E_INVALID_UTF8 ((grail_status)-3)
#define GRAIL_E_NOT_FOUND ((grail_status)-4)
#define GRAIL_E_ACCESS_DENIED ((grail_status)-5)
#define GRAIL_E_ALREADY_EXISTS ((grail_status)-6)
#define GRAIL_E_NOT_A_DIRECTORY ((grail_status)-7)
#define GRAIL_E_IS_A_DIRECTORY ((grail_status)-8)
#define GRAIL_E_DIRECTORY_NOT_EMPTY ((grail_status)-9)
#define GRAIL_E_NAME_TOO_LONG ((grail_status)-10)
#define GRAIL_E_NO_SPACE ((grail_status)-11)
#define GRAIL_E_QUOTA_EXCEEDED ((grail_status)-12)
#define GRAIL_E_READ_ONLY ((grail_status)-13)
#define GRAIL_E_BUSY ((grail_status)-14)
#define GRAIL_E_TIMED_OUT ((grail_status)-15)
#define GRAIL_E_WOULD_BLOCK ((grail_status)-16)
#define GRAIL_E_INTERRUPTED ((grail_status)-17)
#define GRAIL_E_CONNECTION_RESET ((grail_status)-18)
#define GRAIL_E_CONNECTION_REFUSED ((grail_status)-19)
#define GRAIL_E_CONNECTION_ABORTED ((grail_status)-20)
#define GRAIL_E_NETWORK_UNREACHABLE ((grail_status)-21)
#define GRAIL_E_ADDRESS_IN_USE ((grail_status)-22)
#define GRAIL_E_ADDRESS_INVALID ((grail_status)-23)
#define GRAIL_E_MESSAGE_TOO_LARGE ((grail_status)-24)
#define GRAIL_E_UNSUPPORTED ((grail_status)-25)
#define GRAIL_E_NOT_INITIALIZED ((grail_status)-26)
#define GRAIL_E_SYSTEM ((grail_status)-27)
#define GRAIL_E_BROKEN_PIPE ((grail_status)-28)
#define GRAIL_E_CANCELED ((grail_status)-29)
#define GRAIL_E_OVERFLOW ((grail_status)-30)
#define GRAIL_E_OUT_OF_MEMORY ((grail_status)-31)
#define GRAIL_E_TOO_MANY_HANDLES ((grail_status)-32)
#define GRAIL_E_SYMLINK_LOOP ((grail_status)-33)
#define GRAIL_E_CROSS_DEVICE ((grail_status)-34)
#define GRAIL_E_NOT_SEEKABLE ((grail_status)-35)

/*
 * Copies a stable English description into `out` and returns its byte length.
 * The returned length is the full length; if it exceeds `capacity`, nothing was
 * written.  `out` may be NULL when `capacity` is 0.  Unknown codes produce
 * "unknown error".
 */
GRAIL_API grail_result GRAIL_CALL grail_error_text(grail_status status, uint8_t *out,
                                                  uint64_t capacity);

/*
 * Returns 1 for errors that may succeed when the same operation is retried
 * (WOULD_BLOCK, INTERRUPTED, TIMED_OUT, BUSY), otherwise 0.
 */
GRAIL_API uint64_t GRAIL_CALL grail_error_is_transient(grail_status status);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_ERROR_H */
