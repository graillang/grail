/*
 * OS threads and blocking synchronization primitives.
 *
 * These are runtime/FFI building blocks, not the Grail language concurrency
 * surface.  Grail tasks, structured scopes, Atomic<T> and the task-aware
 * Mutex<T> stay in the runtime and must not be implemented by handing these
 * primitives to safe code.
 *
 * Thread and primitive handles are linear.  join and detach consume a thread
 * handle on success; mutex and condition-variable handles are destroyed
 * explicitly.  None of these handles may be closed twice.
 */
#ifndef GRAIL_THREAD_H
#define GRAIL_THREAD_H

#include "grail_abi.h"
#include "grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef grail_handle grail_thread;
typedef grail_handle grail_mutex;
typedef grail_handle grail_condvar;

/*
 * Entry point for a native thread.  The return value becomes the join result.
 * It is a C function pointer; capturing closures are not representable.
 */
typedef uint64_t (*grail_thread_entry)(void *user);

#define GRAIL_THREAD_DETACHED (1ull << 0)

typedef struct grail_thread_options {
    uint64_t struct_size; /* sizeof(grail_thread_options) */
    uint64_t abi_version;
    uint64_t flags;       /* GRAIL_THREAD_* */
    uint64_t stack_size;  /* 0 selects the platform default */
    const uint8_t *name;  /* UTF-8; may be NULL when name_length is 0 */
    uint64_t name_length;
} grail_thread_options;

/* `options` may be NULL for defaults. */
GRAIL_API grail_status GRAIL_CALL grail_os_thread_spawn(grail_thread_entry entry, void *user,
                                                        const grail_thread_options *options,
                                                        grail_thread *out);
/* Blocks until the thread exits, then consumes the handle. */
GRAIL_API grail_status GRAIL_CALL grail_os_thread_join(grail_thread thread, uint64_t *exit_code);
/* Detaches and consumes the handle. */
GRAIL_API grail_status GRAIL_CALL grail_os_thread_detach(grail_thread thread);
/* Opaque identifier of the calling thread; valid for diagnostics only. */
GRAIL_API grail_status GRAIL_CALL grail_os_thread_id(uint64_t *out);
GRAIL_API grail_status GRAIL_CALL grail_os_thread_yield(void);

GRAIL_API grail_status GRAIL_CALL grail_os_mutex_create(grail_mutex *out);
GRAIL_API grail_status GRAIL_CALL grail_os_mutex_lock(grail_mutex mutex);
/* Returns OK with *acquired = 0 when the mutex is already held. */
GRAIL_API grail_status GRAIL_CALL grail_os_mutex_try_lock(grail_mutex mutex, uint64_t *acquired);
GRAIL_API grail_status GRAIL_CALL grail_os_mutex_unlock(grail_mutex mutex);
/* The mutex must be unlocked and have no waiters. */
GRAIL_API grail_status GRAIL_CALL grail_os_mutex_destroy(grail_mutex mutex);

GRAIL_API grail_status GRAIL_CALL grail_os_condvar_create(grail_condvar *out);
/*
 * Atomically releases `mutex` and waits.  `timeout_ns` < 0 waits forever; 0
 * checks immediately.  Returns OK with *signaled = 0 on timeout.  Spurious
 * wakeups are permitted, so callers re-check their predicate in a loop.
 */
GRAIL_API grail_status GRAIL_CALL grail_os_condvar_wait(grail_condvar condvar, grail_mutex mutex,
                                                        int64_t timeout_ns, uint64_t *signaled);
GRAIL_API grail_status GRAIL_CALL grail_os_condvar_signal(grail_condvar condvar);
GRAIL_API grail_status GRAIL_CALL grail_os_condvar_broadcast(grail_condvar condvar);
/* No thread may be waiting when this is called. */
GRAIL_API grail_status GRAIL_CALL grail_os_condvar_destroy(grail_condvar condvar);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_THREAD_H */
