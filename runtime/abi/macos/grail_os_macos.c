/*
 * macOS first-layer OS ABI backend.
 *
 * Implemented: initialization, capabilities, thread-local raw error detail,
 * clocks and sleep, environment reads/mutation/iteration, current directory,
 * executable path, and file basics (open/read/write/seek/truncate/sync/close,
 * non-blocking mode, pipe, mkdir/remove/rename, readlink, realpath).
 *
 * Metadata, directory iteration, local-time offsets, processes, sockets,
 * threads, synchronization and dynamic libraries remain explicit UNSUPPORTED in
 * grail_os_macos_stubs.c.  Darwin declarations live in grail_macos.h so the
 * backend can be compiled for Apple ARM64 on a host without the macOS SDK.
 * This is static evidence only; it has not been executed on macOS.
 */
#include <stdint.h>

#include "../../../include/grail/grail_abi.h"
#include "../../../include/grail/grail_dl.h"
#include "../../../include/grail/grail_env.h"
#include "../../../include/grail/grail_error.h"
#include "../../../include/grail/grail_fs.h"
#include "../../../include/grail/grail_path.h"
#include "../../../include/grail/grail_thread.h"
#include "../../../include/grail/grail_time.h"
#include "../grail_env_store.h"
#include "../grail_handle_table.h"
#include "../grail_internal.h"
#include "grail_macos.h"

typedef struct grail_macos_file { int descriptor; } grail_macos_file;

typedef struct grail_macos_dir_object {
    grail_macos_dir *stream;
    char current[256];
    uint64_t current_length;
    uint64_t current_kind;
    int current_valid;
    char next[256];
    uint64_t next_length;
    uint64_t next_kind;
    int next_valid;
    int eof;
} grail_macos_dir_object;

typedef struct grail_macos_thread {
    grail_macos_pthread_t thread;
    grail_thread_entry entry;
    void *user;
    uint64_t result;
    grail_macos_pthread_mutex_t gate;
    int detached;
    int finished;
    int freed;
    char name[64];
} grail_macos_thread;

typedef struct grail_macos_mutex_object {
    grail_macos_pthread_mutex_t mutex;
} grail_macos_mutex_object;

typedef struct grail_macos_condvar_object {
    grail_macos_pthread_cond_t condition;
} grail_macos_condvar_object;

typedef struct grail_macos_library {
    void *handle;
} grail_macos_library;

typedef struct grail_macos_env_iterator {
    grail_env_snapshot snapshot;
    int64_t index;
} grail_macos_env_iterator;

typedef struct grail_macos_state {
    grail_allocator allocator;
    grail_handle_table files;
    grail_handle_table directories;
    grail_handle_table env_iterators;
    grail_handle_table threads;
    grail_handle_table mutexes;
    grail_handle_table condvars;
    grail_handle_table libraries;
    grail_env_store env;
    grail_macos_unfair_lock lock;
    uint64_t capabilities;
    int initialized;
} grail_macos_state;

static grail_macos_state grail_macos = {{0, NULL, NULL, NULL, NULL},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, 0, 0, 0},
                                        {NULL, NULL, NULL, 0, 0},
                                        {0},
                                        0,
                                        0};
static _Thread_local grail_os_error grail_macos_error = {GRAIL_OS_DOMAIN_NONE, 0};
static _Thread_local char grail_macos_loader_error[512];

static void grail_macos_lock(void) { os_unfair_lock_lock(&grail_macos.lock); }
static void grail_macos_unlock(void) { os_unfair_lock_unlock(&grail_macos.lock); }

static int grail_macos_has_zero(const uint8_t *bytes, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static int grail_macos_env_name_valid(const uint8_t *name, uint64_t length) {
    if (name == NULL || length == 0 || grail_macos_has_zero(name, length)) {
        return 0;
    }
    for (uint64_t i = 0; i < length; i++) {
        if (name[i] == '=') {
            return 0;
        }
    }
    return 1;
}

static uint64_t grail_macos_text_length(const char *text) {
    uint64_t length = 0;
    while (text[length] != '\0') {
        length++;
    }
    return length;
}

static void *grail_macos_allocate(uint64_t size) {
    if (size == 0) {
        size = 1;
    }
    return grail_macos.allocator.allocate(grail_macos.allocator.context, size, 8);
}

static void grail_macos_release(void *pointer, uint64_t size) {
    if (pointer != NULL) {
        grail_macos.allocator.release(grail_macos.allocator.context, pointer, size, 8);
    }
}

static grail_status grail_macos_status(int error_number) {
    grail_status status;
    switch (error_number) {
    case 0: status = GRAIL_OK; break;
    case GRAIL_MACOS_EPERM:
    case GRAIL_MACOS_EACCES: status = GRAIL_E_ACCESS_DENIED; break;
    case GRAIL_MACOS_EBUSY: status = GRAIL_E_BUSY; break;
    case GRAIL_MACOS_ENOENT:
    case GRAIL_MACOS_ESRCH: status = GRAIL_E_NOT_FOUND; break;
    case GRAIL_MACOS_EEXIST: status = GRAIL_E_ALREADY_EXISTS; break;
    case GRAIL_MACOS_ENOTDIR: status = GRAIL_E_NOT_A_DIRECTORY; break;
    case GRAIL_MACOS_EISDIR: status = GRAIL_E_IS_A_DIRECTORY; break;
    case GRAIL_MACOS_ENOTEMPTY: status = GRAIL_E_DIRECTORY_NOT_EMPTY; break;
    case GRAIL_MACOS_ENAMETOOLONG: status = GRAIL_E_NAME_TOO_LONG; break;
    case GRAIL_MACOS_ENOSPC: status = GRAIL_E_NO_SPACE; break;
    case GRAIL_MACOS_EROFS: status = GRAIL_E_READ_ONLY; break;
    case GRAIL_MACOS_ETIMEDOUT: status = GRAIL_E_TIMED_OUT; break;
    case GRAIL_MACOS_EAGAIN:
    case GRAIL_MACOS_EINPROGRESS:
    case GRAIL_MACOS_EALREADY: status = GRAIL_E_WOULD_BLOCK; break;
    case GRAIL_MACOS_EINTR: status = GRAIL_E_INTERRUPTED; break;
    case GRAIL_MACOS_ECONNRESET: status = GRAIL_E_CONNECTION_RESET; break;
    case GRAIL_MACOS_ECONNREFUSED: status = GRAIL_E_CONNECTION_REFUSED; break;
    case GRAIL_MACOS_ECONNABORTED: status = GRAIL_E_CONNECTION_ABORTED; break;
    case GRAIL_MACOS_ENETUNREACH: status = GRAIL_E_NETWORK_UNREACHABLE; break;
    case GRAIL_MACOS_EADDRINUSE: status = GRAIL_E_ADDRESS_IN_USE; break;
    case GRAIL_MACOS_EADDRNOTAVAIL:
    case GRAIL_MACOS_ENOTSOCK:
    case GRAIL_MACOS_EAFNOSUPPORT: status = GRAIL_E_ADDRESS_INVALID; break;
    case GRAIL_MACOS_EMSGSIZE: status = GRAIL_E_MESSAGE_TOO_LARGE; break;
    case GRAIL_MACOS_ENOTSUP:
    case GRAIL_MACOS_ENOPROTOOPT:
    case GRAIL_MACOS_EPROTONOSUPPORT:
    case GRAIL_MACOS_ENOSYS: status = GRAIL_E_UNSUPPORTED; break;
    case GRAIL_MACOS_EPIPE:
    case GRAIL_MACOS_ESHUTDOWN: status = GRAIL_E_BROKEN_PIPE; break;
    case GRAIL_MACOS_ENOTCONN: status = GRAIL_E_CONNECTION_ABORTED; break;
    case GRAIL_MACOS_ENOMEM: status = GRAIL_E_OUT_OF_MEMORY; break;
    case GRAIL_MACOS_EMFILE: status = GRAIL_E_TOO_MANY_HANDLES; break;
    case GRAIL_MACOS_ELOOP: status = GRAIL_E_SYMLINK_LOOP; break;
    case GRAIL_MACOS_EXDEV: status = GRAIL_E_CROSS_DEVICE; break;
    case GRAIL_MACOS_ESPIPE: status = GRAIL_E_NOT_SEEKABLE; break;
    case GRAIL_MACOS_EOVERFLOW:
    case GRAIL_MACOS_ERANGE: status = GRAIL_E_OVERFLOW; break;
    case GRAIL_MACOS_ECANCELED: status = GRAIL_E_CANCELED; break;
    default: status = GRAIL_E_SYSTEM; break;
    }
    grail_macos_error.domain = GRAIL_OS_DOMAIN_ERRNO;
    grail_macos_error.code = (uint64_t)(int64_t)error_number;
    return status;
}

static grail_status grail_macos_fail(int error_number) {
    if (error_number == 0) {
        error_number = GRAIL_MACOS_EIO;
    }
    return grail_macos_status(error_number);
}

static char *grail_macos_copy_text(const uint8_t *bytes, uint64_t length) {
    if (length > (uint64_t)INT64_MAX || (bytes == NULL && length != 0) ||
        grail_macos_has_zero(bytes, length)) {
        return NULL;
    }
    char *text = (char *)grail_macos_allocate(length + 1);
    if (text == NULL) {
        return NULL;
    }
    for (uint64_t i = 0; i < length; i++) {
        text[i] = (char)bytes[i];
    }
    text[length] = '\0';
    return text;
}

static void grail_macos_free_text(char *text) {
    if (text != NULL) {
        grail_macos_release(text, grail_macos_text_length(text) + 1);
    }
}

static grail_status grail_macos_wrap_file(int descriptor, grail_file *out) {
    grail_macos_file *file = (grail_macos_file *)grail_macos_allocate(sizeof(*file));
    if (file == NULL) {
        (void)close(descriptor);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    file->descriptor = descriptor;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    const grail_status status = grail_handle_table_allocate(&grail_macos.files, file, &handle);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        (void)close(descriptor);
        grail_macos_release(file, sizeof(*file));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static grail_status grail_macos_file_lookup(grail_file handle, grail_macos_file **out) {
    if (!grail_macos.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_macos.files, handle, (void **)out);
    grail_macos_unlock();
    return status;
}

grail_status grail_os_init(const grail_allocator *allocator, const grail_startup *startup) {
    if (allocator == NULL || allocator->allocate == NULL || allocator->release == NULL ||
        allocator->struct_size < sizeof(grail_allocator)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (grail_macos.initialized) {
        return GRAIL_E_UNSUPPORTED;
    }
    grail_macos.allocator = *allocator;
    grail_macos.lock.opaque = 0;
    grail_status status = grail_handle_table_init(&grail_macos.files, &grail_macos.allocator,
                                                  GRAIL_HANDLE_KIND_FILE);
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_macos.directories, &grail_macos.allocator,
                                         GRAIL_HANDLE_KIND_DIR);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_macos.env_iterators, &grail_macos.allocator,
                                         GRAIL_HANDLE_KIND_ENV_ITER);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_macos.threads, &grail_macos.allocator,
                                         GRAIL_HANDLE_KIND_THREAD);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_macos.mutexes, &grail_macos.allocator,
                                         GRAIL_HANDLE_KIND_MUTEX);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_macos.condvars, &grail_macos.allocator,
                                         GRAIL_HANDLE_KIND_CONDVAR);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_macos.libraries, &grail_macos.allocator,
                                         GRAIL_HANDLE_KIND_LIBRARY);
    }
    if (status == GRAIL_OK) {
        status = grail_env_store_init(&grail_macos.env, &grail_macos.allocator);
    }
    if (status == GRAIL_OK) {
        status = grail_env_store_seed(&grail_macos.env, startup);
    }
    if (status != GRAIL_OK) {
        grail_handle_table_destroy(&grail_macos.files);
        grail_handle_table_destroy(&grail_macos.directories);
        grail_handle_table_destroy(&grail_macos.env_iterators);
        grail_handle_table_destroy(&grail_macos.threads);
        grail_handle_table_destroy(&grail_macos.mutexes);
        grail_handle_table_destroy(&grail_macos.condvars);
        grail_handle_table_destroy(&grail_macos.libraries);
        grail_env_store_free(&grail_macos.env);
        return status;
    }
    grail_macos.capabilities = GRAIL_CAP_FILES | GRAIL_CAP_FILE_NONBLOCKING | GRAIL_CAP_PATHS |
                               GRAIL_CAP_UNICODE | GRAIL_CAP_ENVIRONMENT |
                               GRAIL_CAP_ENV_MUTATION | GRAIL_CAP_TIME | GRAIL_CAP_CPU_TIME |
                               GRAIL_CAP_SYMLINKS | GRAIL_CAP_DIRECTORIES |
                               GRAIL_CAP_THREADS | GRAIL_CAP_SYNC_PRIMITIVES |
                               GRAIL_CAP_DYNAMIC_LIBRARIES;
    grail_macos.initialized = 1;
    return GRAIL_OK;
}

grail_status grail_os_shutdown(void) {
    if (!grail_macos.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_handle_table_destroy(&grail_macos.files);
    grail_handle_table_destroy(&grail_macos.directories);
    grail_handle_table_destroy(&grail_macos.env_iterators);
    grail_handle_table_destroy(&grail_macos.threads);
    grail_handle_table_destroy(&grail_macos.mutexes);
    grail_handle_table_destroy(&grail_macos.condvars);
    grail_handle_table_destroy(&grail_macos.libraries);
    grail_env_store_free(&grail_macos.env);
    grail_macos.capabilities = 0;
    grail_macos.initialized = 0;
    return GRAIL_OK;
}

uint64_t grail_os_capabilities(void) {
    return grail_macos.initialized ? grail_macos.capabilities : 0;
}

grail_status grail_os_error_last(grail_os_error *out) {
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *out = grail_macos_error;
    return GRAIL_OK;
}

static int grail_macos_clock(uint64_t clock, int *out) {
    if (clock == GRAIL_CLOCK_MONOTONIC) { *out = GRAIL_MACOS_CLOCK_MONOTONIC; return 1; }
    if (clock == GRAIL_CLOCK_REALTIME) { *out = GRAIL_MACOS_CLOCK_REALTIME; return 1; }
    if (clock == GRAIL_CLOCK_PROCESS_CPU) { *out = GRAIL_MACOS_CLOCK_PROCESS_CPUTIME_ID; return 1; }
    if (clock == GRAIL_CLOCK_THREAD_CPU) { *out = GRAIL_MACOS_CLOCK_THREAD_CPUTIME_ID; return 1; }
    return 0;
}

grail_status grail_os_time_now(uint64_t clock, int64_t *nanoseconds) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    int identifier;
    if (nanoseconds == NULL || !grail_macos_clock(clock, &identifier)) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_timespec value;
    if (clock_gettime(identifier, &value) != 0) return grail_macos_fail(*__error());
    if (value.tv_sec > INT64_MAX / 1000000000) return GRAIL_E_OVERFLOW;
    *nanoseconds = value.tv_sec * 1000000000 + value.tv_nsec;
    return GRAIL_OK;
}

grail_status grail_os_time_resolution(uint64_t clock, int64_t *nanoseconds) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    int identifier;
    if (nanoseconds == NULL || !grail_macos_clock(clock, &identifier)) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_timespec value;
    if (clock_getres(identifier, &value) != 0) return grail_macos_fail(*__error());
    *nanoseconds = value.tv_sec * 1000000000 + value.tv_nsec;
    return GRAIL_OK;
}

grail_status grail_os_time_sleep(int64_t nanoseconds, int64_t *remaining_nanoseconds) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (nanoseconds < 0) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_timespec request;
    request.tv_sec = nanoseconds / 1000000000;
    request.tv_nsec = nanoseconds % 1000000000;
    grail_macos_timespec remainder;
    while (nanosleep(&request, &remainder) != 0) {
        if (*__error() == GRAIL_MACOS_EINTR) {
            if (remaining_nanoseconds != NULL) {
                *remaining_nanoseconds = remainder.tv_sec * 1000000000 + remainder.tv_nsec;
            }
            return grail_macos_fail(GRAIL_MACOS_EINTR);
        }
        return grail_macos_fail(*__error());
    }
    if (remaining_nanoseconds != NULL) *remaining_nanoseconds = 0;
    return GRAIL_OK;
}

grail_result grail_os_env_get(const uint8_t *name, uint64_t name_length, uint8_t *out,
                              uint64_t capacity) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    const char *value = NULL;
    uint64_t length = 0;
    grail_macos_lock();
    const grail_status status = grail_env_store_get(&grail_macos.env, name, name_length, &value, &length);
    grail_result result = status == GRAIL_OK
                              ? grail_abi_copy_out((const uint8_t *)value, length, out, capacity)
                              : status;
    grail_macos_unlock();
    return result;
}

grail_status grail_os_env_set(const uint8_t *name, uint64_t name_length, const uint8_t *value,
                              uint64_t value_length) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (!grail_macos_env_name_valid(name, name_length) ||
        (value == NULL && value_length != 0) || grail_macos_has_zero(value, value_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *name_text = grail_macos_copy_text(name, name_length);
    char *value_text = grail_macos_copy_text(value, value_length);
    if (name_text == NULL || value_text == NULL) {
        grail_macos_free_text(name_text);
        grail_macos_free_text(value_text);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (setenv(name_text, value_text, 1) != 0) {
        const int error_number = *__error();
        grail_macos_free_text(name_text);
        grail_macos_free_text(value_text);
        return grail_macos_fail(error_number);
    }
    grail_macos_lock();
    const grail_status status = grail_env_store_set(&grail_macos.env, name, name_length, value, value_length);
    grail_macos_unlock();
    grail_macos_free_text(name_text);
    grail_macos_free_text(value_text);
    return status;
}

grail_status grail_os_env_unset(const uint8_t *name, uint64_t name_length) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (!grail_macos_env_name_valid(name, name_length)) return GRAIL_E_INVALID_ARGUMENT;
    char *name_text = grail_macos_copy_text(name, name_length);
    if (name_text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    if (unsetenv(name_text) != 0) {
        const int error_number = *__error();
        grail_macos_free_text(name_text);
        return grail_macos_fail(error_number);
    }
    grail_macos_lock();
    const grail_status status = grail_env_store_unset(&grail_macos.env, name, name_length);
    grail_macos_unlock();
    grail_macos_free_text(name_text);
    return status;
}

grail_status grail_os_env_iter_open(grail_env_iter *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_env_iterator *iterator =
        (grail_macos_env_iterator *)grail_macos_allocate(sizeof(*iterator));
    if (iterator == NULL) return GRAIL_E_OUT_OF_MEMORY;
    iterator->index = -1;
    grail_macos_lock();
    grail_status status = grail_env_snapshot_take(&grail_macos.env, &iterator->snapshot);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        grail_macos_release(iterator, sizeof(*iterator));
        return status;
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    status = grail_handle_table_allocate(&grail_macos.env_iterators, iterator, &handle);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        grail_env_snapshot_free(&iterator->snapshot);
        grail_macos_release(iterator, sizeof(*iterator));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static grail_status grail_macos_env_iterator_lookup(grail_env_iter handle,
                                                    grail_macos_env_iterator **out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_macos.env_iterators, handle, (void **)out);
    grail_macos_unlock();
    return status;
}

grail_status grail_os_env_iter_next(grail_env_iter handle, uint64_t *is_last) {
    grail_macos_env_iterator *iterator = NULL;
    const grail_status status = grail_macos_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) return status;
    if (is_last == NULL) return GRAIL_E_INVALID_ARGUMENT;
    if (iterator->index + 1 >= (int64_t)iterator->snapshot.count) {
        iterator->index = (int64_t)iterator->snapshot.count;
        *is_last = 1;
        return GRAIL_OK;
    }
    iterator->index++;
    *is_last = 0;
    return GRAIL_OK;
}

grail_result grail_os_env_iter_name(grail_env_iter handle, uint8_t *out, uint64_t capacity) {
    grail_macos_env_iterator *iterator = NULL;
    const grail_status status = grail_macos_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) return status;
    if (iterator->index < 0 || iterator->index >= (int64_t)iterator->snapshot.count) return GRAIL_E_NOT_FOUND;
    const char *name = iterator->snapshot.names[iterator->index];
    return grail_abi_copy_out((const uint8_t *)name, grail_macos_text_length(name), out, capacity);
}

grail_result grail_os_env_iter_value(grail_env_iter handle, uint8_t *out, uint64_t capacity) {
    grail_macos_env_iterator *iterator = NULL;
    const grail_status status = grail_macos_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) return status;
    if (iterator->index < 0 || iterator->index >= (int64_t)iterator->snapshot.count) return GRAIL_E_NOT_FOUND;
    const char *value = iterator->snapshot.values[iterator->index];
    return grail_abi_copy_out((const uint8_t *)value, grail_macos_text_length(value), out, capacity);
}

grail_status grail_os_env_iter_close(grail_env_iter handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_env_iterator *iterator = NULL;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_release(&grail_macos.env_iterators, handle, (void **)&iterator);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    grail_env_snapshot_free(&iterator->snapshot);
    grail_macos_release(iterator, sizeof(*iterator));
    return GRAIL_OK;
}

grail_result grail_os_path_current_directory(uint8_t *out, uint64_t capacity) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    uint64_t size = 256;
    while (size <= 1048576) {
        char *buffer = (char *)grail_macos_allocate(size);
        if (buffer == NULL) return GRAIL_E_OUT_OF_MEMORY;
        if (getcwd(buffer, size) != NULL) {
            const grail_result result =
                grail_abi_copy_out((const uint8_t *)buffer, grail_macos_text_length(buffer), out, capacity);
            grail_macos_release(buffer, size);
            return result;
        }
        const int error_number = *__error();
        grail_macos_release(buffer, size);
        if (error_number != GRAIL_MACOS_ERANGE) return grail_macos_fail(error_number);
        size *= 2;
    }
    return GRAIL_E_NAME_TOO_LONG;
}

grail_status grail_os_path_set_current_directory(const uint8_t *path, uint64_t length) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *text = grail_macos_copy_text(path, length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    const int result = chdir(text);
    const int error_number = *__error();
    grail_macos_free_text(text);
    return result == 0 ? GRAIL_OK : grail_macos_fail(error_number);
}

grail_result grail_os_path_executable(uint8_t *out, uint64_t capacity) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    uint64_t size = 256;
    while (size <= 1048576) {
        char *buffer = (char *)grail_macos_allocate(size);
        if (buffer == NULL) return GRAIL_E_OUT_OF_MEMORY;
        uint32_t requested = (uint32_t)size;
        if (_NSGetExecutablePath(buffer, &requested) == 0) {
            char *resolved = (char *)grail_macos_allocate(4096);
            uint8_t *text = (uint8_t *)buffer;
            uint64_t text_length = grail_macos_text_length(buffer);
            if (resolved != NULL && realpath(buffer, resolved) != NULL) {
                text = (uint8_t *)resolved;
                text_length = grail_macos_text_length(resolved);
            }
            const grail_result result = grail_abi_copy_out(text, text_length, out, capacity);
            if (resolved != NULL) grail_macos_release(resolved, 4096);
            grail_macos_release(buffer, size);
            return result;
        }
        grail_macos_release(buffer, size);
        size *= 2;
    }
    return GRAIL_E_NAME_TOO_LONG;
}

grail_status grail_os_file_open(const uint8_t *path, uint64_t path_length, uint64_t flags,
                                uint64_t mode, grail_file *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL || (flags & (GRAIL_OPEN_READ | GRAIL_OPEN_WRITE)) == 0) return GRAIL_E_INVALID_ARGUMENT;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    const int read = (flags & GRAIL_OPEN_READ) != 0;
    const int write = (flags & GRAIL_OPEN_WRITE) != 0;
    int open_flags = (read && write) ? GRAIL_MACOS_O_RDWR
                                     : (write ? GRAIL_MACOS_O_WRONLY : GRAIL_MACOS_O_RDONLY);
    open_flags |= GRAIL_MACOS_O_CLOEXEC;
    if ((flags & GRAIL_OPEN_CREATE) != 0) open_flags |= GRAIL_MACOS_O_CREAT;
    if ((flags & GRAIL_OPEN_TRUNCATE) != 0) open_flags |= GRAIL_MACOS_O_TRUNC;
    if ((flags & GRAIL_OPEN_APPEND) != 0) open_flags |= GRAIL_MACOS_O_APPEND;
    if ((flags & GRAIL_OPEN_EXCLUSIVE) != 0) open_flags |= GRAIL_MACOS_O_EXCL;
    if ((flags & GRAIL_OPEN_DIRECTORY) != 0) open_flags |= GRAIL_MACOS_O_DIRECTORY;
    if ((flags & GRAIL_OPEN_NO_FOLLOW) != 0) open_flags |= GRAIL_MACOS_O_NOFOLLOW;
    if ((flags & GRAIL_OPEN_SYNC) != 0) open_flags |= GRAIL_MACOS_O_SYNC;
    if ((flags & GRAIL_OPEN_NONBLOCKING) != 0) open_flags |= GRAIL_MACOS_O_NONBLOCK;
    const uint64_t permission = mode == 0 ? 0666 : (mode & 07777);
    const grail_macos_mode_t creation = (grail_macos_mode_t)permission;
    const int descriptor = open(text, open_flags, creation);
    const int error_number = *__error();
    grail_macos_free_text(text);
    if (descriptor < 0) return grail_macos_fail(error_number);
    return grail_macos_wrap_file(descriptor, out);
}

grail_status grail_os_file_read(grail_file handle, uint8_t *buffer, uint64_t capacity,
                                uint64_t *read_length) {
    grail_macos_file *file = NULL;
    const grail_status status = grail_macos_file_lookup(handle, &file);
    if (status != GRAIL_OK) return status;
    if (read_length == NULL || (buffer == NULL && capacity != 0) || capacity > (uint64_t)INT64_MAX) return GRAIL_E_INVALID_ARGUMENT;
    if (capacity == 0) { *read_length = 0; return GRAIL_OK; }
    const grail_macos_ssize_t count = read(file->descriptor, buffer, capacity);
    if (count < 0) return grail_macos_fail(*__error());
    *read_length = (uint64_t)count;
    return GRAIL_OK;
}

grail_status grail_os_file_write(grail_file handle, const uint8_t *buffer, uint64_t length,
                                 uint64_t *written_length) {
    grail_macos_file *file = NULL;
    const grail_status status = grail_macos_file_lookup(handle, &file);
    if (status != GRAIL_OK) return status;
    if (written_length == NULL || (buffer == NULL && length != 0) || length > (uint64_t)INT64_MAX) return GRAIL_E_INVALID_ARGUMENT;
    if (length == 0) { *written_length = 0; return GRAIL_OK; }
    const grail_macos_ssize_t count = write(file->descriptor, buffer, length);
    if (count < 0) return grail_macos_fail(*__error());
    *written_length = (uint64_t)count;
    return GRAIL_OK;
}

grail_status grail_os_file_seek(grail_file handle, int64_t offset, uint64_t whence,
                                uint64_t *position) {
    grail_macos_file *file = NULL;
    const grail_status status = grail_macos_file_lookup(handle, &file);
    if (status != GRAIL_OK) return status;
    if (position == NULL) return GRAIL_E_INVALID_ARGUMENT;
    int origin;
    if (whence == GRAIL_SEEK_SET) origin = GRAIL_MACOS_SEEK_SET;
    else if (whence == GRAIL_SEEK_CURRENT) origin = GRAIL_MACOS_SEEK_CURRENT;
    else if (whence == GRAIL_SEEK_END) origin = GRAIL_MACOS_SEEK_END;
    else return GRAIL_E_INVALID_ARGUMENT;
    const grail_macos_off_t result = lseek(file->descriptor, offset, origin);
    if (result < 0) return grail_macos_fail(*__error());
    *position = (uint64_t)result;
    return GRAIL_OK;
}

grail_status grail_os_file_truncate(grail_file handle, uint64_t length) {
    grail_macos_file *file = NULL;
    const grail_status status = grail_macos_file_lookup(handle, &file);
    if (status != GRAIL_OK) return status;
    if (length > (uint64_t)INT64_MAX) return GRAIL_E_INVALID_ARGUMENT;
    if (ftruncate(file->descriptor, (grail_macos_off_t)length) != 0) return grail_macos_fail(*__error());
    return GRAIL_OK;
}

grail_status grail_os_file_sync(grail_file handle, uint64_t data_only) {
    (void)data_only;
    grail_macos_file *file = NULL;
    const grail_status status = grail_macos_file_lookup(handle, &file);
    if (status != GRAIL_OK) return status;
    if (fsync(file->descriptor) != 0) return grail_macos_fail(*__error());
    return GRAIL_OK;
}

grail_status grail_os_file_set_nonblocking(grail_file handle, uint64_t enabled) {
    grail_macos_file *file = NULL;
    const grail_status status = grail_macos_file_lookup(handle, &file);
    if (status != GRAIL_OK) return status;
    const int current = fcntl(file->descriptor, GRAIL_MACOS_F_GETFL, 0);
    if (current < 0) return grail_macos_fail(*__error());
    const int next = enabled != 0 ? (current | GRAIL_MACOS_O_NONBLOCK)
                                  : (current & ~GRAIL_MACOS_O_NONBLOCK);
    if (fcntl(file->descriptor, GRAIL_MACOS_F_SETFL, next) != 0) return grail_macos_fail(*__error());
    return GRAIL_OK;
}

grail_status grail_os_file_close(grail_file handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_file *file = NULL;
    grail_macos_lock();
    const grail_status status = grail_handle_table_release(&grail_macos.files, handle, (void **)&file);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    const int result = close(file->descriptor);
    const int error_number = *__error();
    grail_macos_release(file, sizeof(*file));
    return result == 0 ? GRAIL_OK : grail_macos_fail(error_number);
}

grail_status grail_os_pipe(grail_pipe *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    int descriptors[2];
    if (pipe(descriptors) != 0) return grail_macos_fail(*__error());
    (void)fcntl(descriptors[0], GRAIL_MACOS_F_SETFD, GRAIL_MACOS_FD_CLOEXEC);
    (void)fcntl(descriptors[1], GRAIL_MACOS_F_SETFD, GRAIL_MACOS_FD_CLOEXEC);
    grail_file read_end = GRAIL_HANDLE_NONE;
    grail_status status = grail_macos_wrap_file(descriptors[0], &read_end);
    if (status != GRAIL_OK) { (void)close(descriptors[1]); return status; }
    grail_file write_end = GRAIL_HANDLE_NONE;
    status = grail_macos_wrap_file(descriptors[1], &write_end);
    if (status != GRAIL_OK) {
        grail_macos_file *file = NULL;
        grail_macos_lock();
        (void)grail_handle_table_release(&grail_macos.files, read_end, (void **)&file);
        grail_macos_unlock();
        if (file != NULL) { (void)close(file->descriptor); grail_macos_release(file, sizeof(*file)); }
        return status;
    }
    out->read_end = read_end;
    out->write_end = write_end;
    return GRAIL_OK;
}


static uint64_t grail_macos_kind_from_dtype(uint8_t type) {
    switch (type) {
    case GRAIL_MACOS_DT_FIFO: return GRAIL_FILE_KIND_FIFO;
    case GRAIL_MACOS_DT_CHR: return GRAIL_FILE_KIND_CHARACTER;
    case GRAIL_MACOS_DT_DIR: return GRAIL_FILE_KIND_DIRECTORY;
    case GRAIL_MACOS_DT_BLK: return GRAIL_FILE_KIND_BLOCK;
    case GRAIL_MACOS_DT_REG: return GRAIL_FILE_KIND_FILE;
    case GRAIL_MACOS_DT_LNK: return GRAIL_FILE_KIND_SYMLINK;
    case GRAIL_MACOS_DT_SOCK: return GRAIL_FILE_KIND_SOCKET;
    default: return GRAIL_FILE_KIND_UNKNOWN;
    }
}

static int grail_macos_dir_read(grail_macos_dir *stream, char name[256], uint64_t *length,
                                uint64_t *kind, grail_status *error) {
    for (;;) {
        *__error() = 0;
        grail_macos_dirent *entry = readdir(stream);
        if (entry == NULL) {
            if (*__error() != 0) {
                *error = grail_macos_fail(*__error());
                return -1;
            }
            return 0;
        }
        uint64_t count = entry->d_namlen;
        if (count == 0) {
            while (count < 256 && entry->d_name[count] != '\0') {
                count++;
            }
        }
        if (count > 255) {
            count = 255;
        }
        if ((count == 1 && entry->d_name[0] == '.') ||
            (count == 2 && entry->d_name[0] == '.' && entry->d_name[1] == '.')) {
            continue;
        }
        for (uint64_t i = 0; i < count; i++) {
            name[i] = entry->d_name[i];
        }
        name[count] = '\0';
        *length = count;
        *kind = grail_macos_kind_from_dtype(entry->d_type);
        return 1;
    }
}

static grail_status grail_macos_dir_lookup(grail_dir handle, grail_macos_dir_object **out) {
    if (!grail_macos.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_macos.directories, handle, (void **)out);
    grail_macos_unlock();
    return status;
}

grail_status grail_os_dir_open(const uint8_t *path, uint64_t path_length, grail_dir *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_dir *stream = opendir(text);
    const int error_number = *__error();
    grail_macos_free_text(text);
    if (stream == NULL) return grail_macos_fail(error_number);
    grail_macos_dir_object *dir =
        (grail_macos_dir_object *)grail_macos_allocate(sizeof(*dir));
    if (dir == NULL) {
        (void)closedir(stream);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < sizeof(*dir); i++) ((uint8_t *)dir)[i] = 0;
    dir->stream = stream;
    grail_status status = GRAIL_OK;
    int read = grail_macos_dir_read(stream, dir->current, &dir->current_length,
                                    &dir->current_kind, &status);
    if (read < 0) {
        (void)closedir(stream);
        grail_macos_release(dir, sizeof(*dir));
        return status;
    }
    if (read == 0) {
        dir->eof = 1;
        dir->current_valid = 0;
    } else {
        dir->current_valid = 1;
        read = grail_macos_dir_read(stream, dir->next, &dir->next_length, &dir->next_kind,
                                    &status);
        if (read < 0) {
            (void)closedir(stream);
            grail_macos_release(dir, sizeof(*dir));
            return status;
        }
        dir->next_valid = read;
        if (read == 0) dir->eof = 1;
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    status = grail_handle_table_allocate(&grail_macos.directories, dir, &handle);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        (void)closedir(stream);
        grail_macos_release(dir, sizeof(*dir));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_result grail_os_dir_next(grail_dir handle, uint8_t *name, uint64_t capacity,
                               grail_dir_entry *out) {
    grail_macos_dir_object *dir = NULL;
    grail_status status = grail_macos_dir_lookup(handle, &dir);
    if (status != GRAIL_OK) return status;
    if (out == NULL || (name == NULL && capacity != 0)) return GRAIL_E_INVALID_ARGUMENT;
    if (!dir->current_valid) {
        for (uint64_t i = 0; i < sizeof(*out); i++) ((uint8_t *)out)[i] = 0;
        out->struct_size = sizeof(*out);
        out->abi_version = GRAIL_ABI_VERSION;
        out->is_last = 1;
        return 0;
    }
    if (!dir->next_valid && !dir->eof) {
        const int read = grail_macos_dir_read(dir->stream, dir->next, &dir->next_length,
                                              &dir->next_kind, &status);
        if (read < 0) return status;
        dir->next_valid = read;
        if (read == 0) dir->eof = 1;
    }
    for (uint64_t i = 0; i < sizeof(*out); i++) ((uint8_t *)out)[i] = 0;
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    out->name_length = dir->current_length;
    out->kind = dir->current_kind;
    out->is_last = (!dir->next_valid && dir->eof) ? 1 : 0;
    if (dir->current_length > capacity || name == NULL) {
        return (grail_result)dir->current_length;
    }
    for (uint64_t i = 0; i < dir->current_length; i++) name[i] = (uint8_t)dir->current[i];
    for (uint64_t i = 0; i < 256; i++) dir->current[i] = dir->next[i];
    dir->current_length = dir->next_length;
    dir->current_kind = dir->next_kind;
    dir->current_valid = dir->next_valid;
    dir->next_valid = 0;
    return (grail_result)out->name_length;
}

grail_status grail_os_dir_close(grail_dir handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_dir_object *dir = NULL;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_release(&grail_macos.directories, handle, (void **)&dir);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    (void)closedir(dir->stream);
    grail_macos_release(dir, sizeof(*dir));
    return GRAIL_OK;
}

static void *grail_macos_thread_main(void *argument) {
    grail_macos_thread *thread = (grail_macos_thread *)argument;
    if (thread->name[0] != '\0') {
        (void)pthread_setname_np(thread->name);
    }
    const uint64_t result = thread->entry(thread->user);
    pthread_mutex_lock(&thread->gate);
    thread->result = result;
    thread->finished = 1;
    const int release = thread->detached && !thread->freed;
    if (release) thread->freed = 1;
    pthread_mutex_unlock(&thread->gate);
    if (release) {
        (void)pthread_mutex_destroy(&thread->gate);
        grail_macos_release(thread, sizeof(*thread));
    }
    return NULL;
}

grail_status grail_os_thread_spawn(grail_thread_entry entry, void *user,
                                   const grail_thread_options *options, grail_thread *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (entry == NULL || out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    uint64_t stack_size = 0;
    char name[64];
    name[0] = '\0';
    if (options != NULL) {
        if (options->struct_size < sizeof(*options) || options->abi_version != GRAIL_ABI_VERSION) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        if (options->flags != 0) return GRAIL_E_UNSUPPORTED;
        stack_size = options->stack_size;
        if ((options->name == NULL && options->name_length != 0) ||
            options->name_length > (uint64_t)INT64_MAX) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        if (options->name != NULL) {
            uint64_t count = options->name_length < 63 ? options->name_length : 63;
            for (uint64_t i = 0; i < count; i++) name[i] = (char)options->name[i];
            name[count] = '\0';
        }
    }
    grail_macos_thread *thread = (grail_macos_thread *)grail_macos_allocate(sizeof(*thread));
    if (thread == NULL) return GRAIL_E_OUT_OF_MEMORY;
    for (uint64_t i = 0; i < sizeof(*thread); i++) ((uint8_t *)thread)[i] = 0;
    thread->entry = entry;
    thread->user = user;
    for (uint64_t i = 0; i < sizeof(name); i++) thread->name[i] = name[i];
    if (pthread_mutex_init(&thread->gate, NULL) != 0) {
        grail_macos_release(thread, sizeof(*thread));
        return GRAIL_E_SYSTEM;
    }
    grail_macos_pthread_attr_t attributes;
    if (pthread_attr_init(&attributes) != 0) {
        (void)pthread_mutex_destroy(&thread->gate);
        grail_macos_release(thread, sizeof(*thread));
        return GRAIL_E_SYSTEM;
    }
    if (stack_size != 0) {
        (void)pthread_attr_setstacksize(&attributes, stack_size);
    }
    const int created = pthread_create(&thread->thread, &attributes, grail_macos_thread_main, thread);
    (void)pthread_attr_destroy(&attributes);
    if (created != 0) {
        (void)pthread_mutex_destroy(&thread->gate);
        grail_macos_release(thread, sizeof(*thread));
        return grail_macos_fail(created);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    grail_status status = grail_handle_table_allocate(&grail_macos.threads, thread, &handle);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        const grail_macos_pthread_t thread_handle = thread->thread;
        int release = 0;
        pthread_mutex_lock(&thread->gate);
        if (thread->finished && !thread->freed) {
            thread->freed = 1;
            release = 1;
        } else {
            thread->detached = 1;
        }
        pthread_mutex_unlock(&thread->gate);
        (void)pthread_detach(thread_handle);
        if (release) {
            (void)pthread_mutex_destroy(&thread->gate);
            grail_macos_release(thread, sizeof(*thread));
        }
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static grail_status grail_macos_thread_lookup(grail_thread handle, grail_macos_thread **out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_macos.threads, handle, (void **)out);
    grail_macos_unlock();
    return status;
}

grail_status grail_os_thread_join(grail_thread handle, uint64_t *exit_code) {
    grail_macos_thread *thread = NULL;
    grail_status status = grail_macos_thread_lookup(handle, &thread);
    if (status != GRAIL_OK) return status;
    const int joined = pthread_join(thread->thread, NULL);
    if (joined != 0) return grail_macos_fail(joined);
    pthread_mutex_lock(&thread->gate);
    const uint64_t result = thread->result;
    thread->freed = 1;
    pthread_mutex_unlock(&thread->gate);
    grail_macos_lock();
    status = grail_handle_table_release(&grail_macos.threads, handle, NULL);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    (void)pthread_mutex_destroy(&thread->gate);
    grail_macos_release(thread, sizeof(*thread));
    if (exit_code != NULL) *exit_code = result;
    return GRAIL_OK;
}

grail_status grail_os_thread_detach(grail_thread handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_thread *thread = NULL;
    grail_macos_lock();
    grail_status status = grail_handle_table_release(&grail_macos.threads, handle, (void **)&thread);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    const int detached = pthread_detach(thread->thread);
    int release = 0;
    pthread_mutex_lock(&thread->gate);
    if (thread->finished && !thread->freed) {
        thread->freed = 1;
        release = 1;
    } else if (!thread->finished) {
        thread->detached = 1;
    }
    pthread_mutex_unlock(&thread->gate);
    if (release) {
        (void)pthread_mutex_destroy(&thread->gate);
        grail_macos_release(thread, sizeof(*thread));
    }
    return detached == 0 ? GRAIL_OK : grail_macos_fail(detached);
}

grail_status grail_os_thread_id(uint64_t *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    *out = (uint64_t)(uintptr_t)pthread_self();
    return GRAIL_OK;
}

grail_status grail_os_thread_yield(void) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (sched_yield() != 0) return grail_macos_fail(*__error());
    return GRAIL_OK;
}

static grail_status grail_macos_mutex_lookup(grail_mutex handle, grail_macos_mutex_object **out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_macos.mutexes, handle, (void **)out);
    grail_macos_unlock();
    return status;
}

grail_status grail_os_mutex_create(grail_mutex *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_mutex_object *mutex =
        (grail_macos_mutex_object *)grail_macos_allocate(sizeof(*mutex));
    if (mutex == NULL) return GRAIL_E_OUT_OF_MEMORY;
    const int initialized = pthread_mutex_init(&mutex->mutex, NULL);
    if (initialized != 0) {
        grail_macos_release(mutex, sizeof(*mutex));
        return grail_macos_fail(initialized);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    grail_status status = grail_handle_table_allocate(&grail_macos.mutexes, mutex, &handle);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        (void)pthread_mutex_destroy(&mutex->mutex);
        grail_macos_release(mutex, sizeof(*mutex));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_mutex_lock(grail_mutex handle) {
    grail_macos_mutex_object *mutex = NULL;
    const grail_status status = grail_macos_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) return status;
    return grail_macos_fail(pthread_mutex_lock(&mutex->mutex));
}

grail_status grail_os_mutex_try_lock(grail_mutex handle, uint64_t *acquired) {
    grail_macos_mutex_object *mutex = NULL;
    const grail_status status = grail_macos_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) return status;
    if (acquired == NULL) return GRAIL_E_INVALID_ARGUMENT;
    const int result = pthread_mutex_trylock(&mutex->mutex);
    if (result == 0) { *acquired = 1; return GRAIL_OK; }
    if (result == GRAIL_MACOS_EBUSY) { *acquired = 0; return GRAIL_OK; }
    return grail_macos_fail(result);
}

grail_status grail_os_mutex_unlock(grail_mutex handle) {
    grail_macos_mutex_object *mutex = NULL;
    const grail_status status = grail_macos_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) return status;
    return grail_macos_fail(pthread_mutex_unlock(&mutex->mutex));
}

grail_status grail_os_mutex_destroy(grail_mutex handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_mutex_object *mutex = NULL;
    grail_macos_lock();
    grail_status status = grail_handle_table_lookup(&grail_macos.mutexes, handle, (void **)&mutex);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    const int destroyed = pthread_mutex_destroy(&mutex->mutex);
    if (destroyed != 0) return grail_macos_fail(destroyed);
    grail_macos_lock();
    status = grail_handle_table_release(&grail_macos.mutexes, handle, NULL);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    grail_macos_release(mutex, sizeof(*mutex));
    return GRAIL_OK;
}

static grail_status grail_macos_condvar_lookup(grail_condvar handle,
                                               grail_macos_condvar_object **out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_macos.condvars, handle, (void **)out);
    grail_macos_unlock();
    return status;
}

grail_status grail_os_condvar_create(grail_condvar *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_condvar_object *condvar =
        (grail_macos_condvar_object *)grail_macos_allocate(sizeof(*condvar));
    if (condvar == NULL) return GRAIL_E_OUT_OF_MEMORY;
    const int initialized = pthread_cond_init(&condvar->condition, NULL);
    if (initialized != 0) {
        grail_macos_release(condvar, sizeof(*condvar));
        return grail_macos_fail(initialized);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    grail_status status = grail_handle_table_allocate(&grail_macos.condvars, condvar, &handle);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        (void)pthread_cond_destroy(&condvar->condition);
        grail_macos_release(condvar, sizeof(*condvar));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_condvar_wait(grail_condvar condvar_handle, grail_mutex mutex_handle,
                                   int64_t timeout_ns, uint64_t *signaled) {
    grail_macos_condvar_object *condvar = NULL;
    grail_status status = grail_macos_condvar_lookup(condvar_handle, &condvar);
    if (status != GRAIL_OK) return status;
    grail_macos_mutex_object *mutex = NULL;
    status = grail_macos_mutex_lookup(mutex_handle, &mutex);
    if (status != GRAIL_OK) return status;
    if (signaled == NULL) return GRAIL_E_INVALID_ARGUMENT;
    int result;
    if (timeout_ns < 0) {
        result = pthread_cond_wait(&condvar->condition, &mutex->mutex);
    } else {
        grail_macos_timespec timeout;
        timeout.tv_sec = timeout_ns / 1000000000;
        timeout.tv_nsec = timeout_ns % 1000000000;
        result = pthread_cond_timedwait_relative_np(&condvar->condition, &mutex->mutex, &timeout);
    }
    if (result == 0) { *signaled = 1; return GRAIL_OK; }
    if (result == GRAIL_MACOS_ETIMEDOUT) { *signaled = 0; return GRAIL_OK; }
    return grail_macos_fail(result);
}

grail_status grail_os_condvar_signal(grail_condvar handle) {
    grail_macos_condvar_object *condvar = NULL;
    const grail_status status = grail_macos_condvar_lookup(handle, &condvar);
    if (status != GRAIL_OK) return status;
    return grail_macos_fail(pthread_cond_signal(&condvar->condition));
}

grail_status grail_os_condvar_broadcast(grail_condvar handle) {
    grail_macos_condvar_object *condvar = NULL;
    const grail_status status = grail_macos_condvar_lookup(handle, &condvar);
    if (status != GRAIL_OK) return status;
    return grail_macos_fail(pthread_cond_broadcast(&condvar->condition));
}

grail_status grail_os_condvar_destroy(grail_condvar handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_condvar_object *condvar = NULL;
    grail_macos_lock();
    grail_status status = grail_handle_table_lookup(&grail_macos.condvars, handle, (void **)&condvar);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    const int destroyed = pthread_cond_destroy(&condvar->condition);
    if (destroyed != 0) return grail_macos_fail(destroyed);
    grail_macos_lock();
    status = grail_handle_table_release(&grail_macos.condvars, handle, NULL);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    grail_macos_release(condvar, sizeof(*condvar));
    return GRAIL_OK;
}

static void grail_macos_capture_loader_error(void) {
    char *message = dlerror();
    if (message == NULL) {
        grail_macos_loader_error[0] = '\0';
        return;
    }
    uint64_t length = 0;
    while (message[length] != '\0' && length < sizeof(grail_macos_loader_error) - 1) {
        length++;
    }
    for (uint64_t i = 0; i < length; i++) grail_macos_loader_error[i] = message[i];
    grail_macos_loader_error[length] = '\0';
}

grail_status grail_os_dl_open(const uint8_t *name, uint64_t name_length, uint64_t flags,
                              grail_library *out) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (out == NULL || (name == NULL && name_length != 0)) return GRAIL_E_INVALID_ARGUMENT;
    char *text = NULL;
    if (name_length != 0) {
        text = grail_macos_copy_text(name, name_length);
        if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    }
    int mode = (flags & GRAIL_DL_LAZY) != 0 ? GRAIL_MACOS_RTLD_LAZY : GRAIL_MACOS_RTLD_NOW;
    mode |= (flags & GRAIL_DL_GLOBAL) != 0 ? GRAIL_MACOS_RTLD_GLOBAL : GRAIL_MACOS_RTLD_LOCAL;
    (void)dlerror();
    void *handle = dlopen(text, mode);
    grail_macos_capture_loader_error();
    grail_macos_free_text(text);
    if (handle == NULL) return GRAIL_E_NOT_FOUND;
    grail_macos_library *library = (grail_macos_library *)grail_macos_allocate(sizeof(*library));
    if (library == NULL) {
        (void)dlclose(handle);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    library->handle = handle;
    grail_handle result = GRAIL_HANDLE_NONE;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_macos.libraries, library, &result);
    grail_macos_unlock();
    if (status != GRAIL_OK) {
        (void)dlclose(handle);
        grail_macos_release(library, sizeof(*library));
        return status;
    }
    *out = result;
    return GRAIL_OK;
}

grail_status grail_os_dl_symbol(grail_library handle, const uint8_t *name, uint64_t name_length,
                                void **symbol) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    if (name == NULL || name_length == 0 || symbol == NULL ||
        grail_macos_has_zero(name, name_length)) return GRAIL_E_INVALID_ARGUMENT;
    grail_macos_library *library = NULL;
    grail_macos_lock();
    grail_status status = grail_handle_table_lookup(&grail_macos.libraries, handle, (void **)&library);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    char *text = grail_macos_copy_text(name, name_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    (void)dlerror();
    void *address = dlsym(library->handle, text);
    grail_macos_capture_loader_error();
    grail_macos_free_text(text);
    if (address == NULL && grail_macos_loader_error[0] != '\0') return GRAIL_E_NOT_FOUND;
    *symbol = address;
    return GRAIL_OK;
}

grail_status grail_os_dl_close(grail_library handle) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    grail_macos_library *library = NULL;
    grail_macos_lock();
    const grail_status status =
        grail_handle_table_release(&grail_macos.libraries, handle, (void **)&library);
    grail_macos_unlock();
    if (status != GRAIL_OK) return status;
    (void)dlerror();
    const int result = dlclose(library->handle);
    grail_macos_capture_loader_error();
    grail_macos_release(library, sizeof(*library));
    return result == 0 ? GRAIL_OK : GRAIL_E_SYSTEM;
}

grail_result grail_os_dl_error(uint8_t *out, uint64_t capacity) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    return grail_abi_copy_out((const uint8_t *)grail_macos_loader_error,
                              grail_macos_text_length(grail_macos_loader_error), out, capacity);
}

grail_status grail_os_fs_mkdir(const uint8_t *path, uint64_t path_length, uint64_t mode,
                               uint64_t flags) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    if (path_length == 0) {
        grail_macos_free_text(text);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const uint64_t permission = mode == 0 ? 0777 : (mode & 07777);
    const grail_macos_mode_t creation = (grail_macos_mode_t)permission;
    if ((flags & GRAIL_MKDIR_PARENTS) == 0) {
        const int result = mkdir(text, creation);
        const int error_number = *__error();
        grail_macos_free_text(text);
        return result == 0 ? GRAIL_OK : grail_macos_fail(error_number);
    }
    char *cursor = text;
    if (*cursor == '/') cursor++;
    for (;;) {
        if (*cursor == '/' || *cursor == '\0') {
            const char saved = *cursor;
            *cursor = '\0';
            if (text[0] != '\0' && mkdir(text, creation) != 0 && *__error() != GRAIL_MACOS_EEXIST) {
                const int error_number = *__error();
                *cursor = saved;
                grail_macos_free_text(text);
                return grail_macos_fail(error_number);
            }
            *cursor = saved;
            if (saved == '\0') break;
        }
        cursor++;
    }
    grail_macos_free_text(text);
    return GRAIL_OK;
}

grail_status grail_os_fs_remove_file(const uint8_t *path, uint64_t path_length) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    const int result = unlink(text);
    const int error_number = *__error();
    grail_macos_free_text(text);
    return result == 0 ? GRAIL_OK : grail_macos_fail(error_number);
}

grail_status grail_os_fs_remove_dir(const uint8_t *path, uint64_t path_length) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    const int result = rmdir(text);
    const int error_number = *__error();
    grail_macos_free_text(text);
    return result == 0 ? GRAIL_OK : grail_macos_fail(error_number);
}

grail_status grail_os_fs_rename(const uint8_t *from, uint64_t from_length, const uint8_t *to,
                                uint64_t to_length, uint64_t flags) {
    (void)flags;
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *from_text = grail_macos_copy_text(from, from_length);
    char *to_text = grail_macos_copy_text(to, to_length);
    if (from_text == NULL || to_text == NULL) {
        grail_macos_free_text(from_text);
        grail_macos_free_text(to_text);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((flags & GRAIL_RENAME_REPLACE) == 0) {
        if (access(to_text, 0) == 0) {
            grail_macos_free_text(from_text);
            grail_macos_free_text(to_text);
            return GRAIL_E_ALREADY_EXISTS;
        }
        if (*__error() != GRAIL_MACOS_ENOENT) {
            const int error_number = *__error();
            grail_macos_free_text(from_text);
            grail_macos_free_text(to_text);
            return grail_macos_fail(error_number);
        }
    }
    const int result = rename(from_text, to_text);
    const int error_number = *__error();
    grail_macos_free_text(from_text);
    grail_macos_free_text(to_text);
    return result == 0 ? GRAIL_OK : grail_macos_fail(error_number);
}

grail_result grail_os_fs_readlink(const uint8_t *path, uint64_t path_length, uint8_t *out,
                                  uint64_t capacity) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    uint64_t size = 256;
    while (size <= 1048576) {
        char *buffer = (char *)grail_macos_allocate(size);
        if (buffer == NULL) { grail_macos_free_text(text); return GRAIL_E_OUT_OF_MEMORY; }
        const grail_macos_ssize_t length = readlink(text, buffer, size - 1);
        if (length >= 0) {
            if ((uint64_t)length < size - 1) {
                buffer[length] = '\0';
                const grail_result result =
                    grail_abi_copy_out((const uint8_t *)buffer, (uint64_t)length, out, capacity);
                grail_macos_release(buffer, size);
                grail_macos_free_text(text);
                return result;
            }
            grail_macos_release(buffer, size);
            size *= 2;
            continue;
        }
        const int error_number = *__error();
        grail_macos_release(buffer, size);
        if (error_number != GRAIL_MACOS_ENAMETOOLONG) { grail_macos_free_text(text); return grail_macos_fail(error_number); }
        size *= 2;
    }
    grail_macos_free_text(text);
    return GRAIL_E_NAME_TOO_LONG;
}

grail_result grail_os_fs_realpath(const uint8_t *path, uint64_t path_length, uint8_t *out,
                                  uint64_t capacity) {
    if (!grail_macos.initialized) return GRAIL_E_NOT_INITIALIZED;
    char *text = grail_macos_copy_text(path, path_length);
    if (text == NULL) return GRAIL_E_INVALID_ARGUMENT;
    char *resolved = (char *)grail_macos_allocate(4096);
    if (resolved == NULL) { grail_macos_free_text(text); return GRAIL_E_OUT_OF_MEMORY; }
    char *result_path = realpath(text, resolved);
    const int error_number = *__error();
    grail_macos_free_text(text);
    if (result_path == NULL) { grail_macos_release(resolved, 4096); return grail_macos_fail(error_number); }
    const grail_result result =
        grail_abi_copy_out((const uint8_t *)result_path, grail_macos_text_length(result_path), out, capacity);
    grail_macos_release(resolved, 4096);
    return result;
}
