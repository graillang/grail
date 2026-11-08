/*
 * Process environment.
 *
 * The runtime owns a deterministic copy of the environment seeded from
 * grail_startup.  Reads and iteration consult that copy; set/unset also update
 * the native environment so spawned children inherit the change.  Names are
 * non-empty UTF-8 without '=' or a zero byte; values are UTF-8 without a zero
 * byte and may be empty.  A missing name is GRAIL_E_NOT_FOUND and is distinct
 * from a present but empty value.
 */
#ifndef GRAIL_ENV_H
#define GRAIL_ENV_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef grail_handle grail_env_iter;

/*
 * Returns the value length.  A length greater than `capacity`, or a NULL
 * `out`, means nothing was written and the caller must retry.  Missing
 * variables return GRAIL_E_NOT_FOUND.
 */
GRAIL_API grail_result GRAIL_CALL grail_os_env_get(const uint8_t *name, uint64_t name_length,
                                                  uint8_t *out, uint64_t capacity);

/* Sets or replaces a variable.  Requires GRAIL_CAP_ENV_MUTATION. */
GRAIL_API grail_status GRAIL_CALL grail_os_env_set(const uint8_t *name, uint64_t name_length,
                                                   const uint8_t *value, uint64_t value_length);

/* Removes a variable; unsetting a missing variable succeeds. */
GRAIL_API grail_status GRAIL_CALL grail_os_env_unset(const uint8_t *name, uint64_t name_length);

/*
 * Opens an iterator over a snapshot taken at open time.  Iteration order is
 * unspecified and is not required to be stable across platforms.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_env_iter_open(grail_env_iter *out);

/*
 * Advances to the next entry.  Sets `is_last` to 1 after the final entry; once
 * exhausted, name/value return GRAIL_E_NOT_FOUND.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_env_iter_next(grail_env_iter iterator,
                                                        uint64_t *is_last);

/* Current entry's name/value; same capacity and retry rule as env_get. */
GRAIL_API grail_result GRAIL_CALL grail_os_env_iter_name(grail_env_iter iterator, uint8_t *out,
                                                        uint64_t capacity);
GRAIL_API grail_result GRAIL_CALL grail_os_env_iter_value(grail_env_iter iterator, uint8_t *out,
                                                         uint64_t capacity);

GRAIL_API grail_status GRAIL_CALL grail_os_env_iter_close(grail_env_iter iterator);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_ENV_H */
