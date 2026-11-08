/*
 * Dynamic library loading.
 *
 * An empty library name refers to the running program's global symbol scope.
 * The returned symbol is a raw code/data address; invoking it is the FFI
 * layer's responsibility and requires a correctly typed extern declaration.
 */
#ifndef GRAIL_DL_H
#define GRAIL_DL_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef grail_handle grail_library;

#define GRAIL_DL_LAZY (1ull << 0)
#define GRAIL_DL_GLOBAL (1ull << 1)

GRAIL_API grail_status GRAIL_CALL grail_os_dl_open(const uint8_t *name, uint64_t name_length,
                                                   uint64_t flags, grail_library *out);
GRAIL_API grail_status GRAIL_CALL grail_os_dl_symbol(grail_library library, const uint8_t *name,
                                                     uint64_t name_length, void **symbol);
/* Consumes the handle; symbols obtained from it become invalid. */
GRAIL_API grail_status GRAIL_CALL grail_os_dl_close(grail_library library);
/*
 * Copies the calling thread's most recent loader message.  The value is a
 * snapshot and is replaced by the next loader call on the same thread.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_dl_error(uint8_t *out, uint64_t capacity);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_DL_H */
