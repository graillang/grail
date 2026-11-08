/*
 * Wall, monotonic and CPU clocks.
 *
 * Every time value is a signed count of nanoseconds.  `grail_os_time_sleep`
 * blocks the calling OS thread; it is not the Grail green-task suspend
 * operation, which stays in the runtime's reactor.
 */
#ifndef GRAIL_TIME_H
#define GRAIL_TIME_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GRAIL_CLOCK_MONOTONIC 0u
#define GRAIL_CLOCK_REALTIME 1u
#define GRAIL_CLOCK_PROCESS_CPU 2u
#define GRAIL_CLOCK_THREAD_CPU 3u

/* Absolute time from `clock`, in nanoseconds.  REALTIME is UTC since 1970. */
GRAIL_API grail_status GRAIL_CALL grail_os_time_now(uint64_t clock, int64_t *nanoseconds);

/* Nominal resolution of `clock` in nanoseconds. */
GRAIL_API grail_status GRAIL_CALL grail_os_time_resolution(uint64_t clock, int64_t *nanoseconds);

/*
 * Sleeps for a non-negative duration.  On GRAIL_E_INTERRUPTED, `remaining`
 * (when non-NULL) receives the unslept duration.  A negative duration returns
 * GRAIL_E_INVALID_ARGUMENT.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_time_sleep(int64_t nanoseconds,
                                                     int64_t *remaining_nanoseconds);

/*
 * UTC offset in effect for `utc_nanoseconds` at the process time zone, in
 * nanoseconds.  Returns GRAIL_E_UNSUPPORTED when the backend cannot compute a
 * historical offset.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_time_local_offset(int64_t utc_nanoseconds,
                                                            int64_t *offset_nanoseconds);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_TIME_H */
