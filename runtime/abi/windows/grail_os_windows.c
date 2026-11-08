/*
 * Windows first-layer OS ABI backend.
 *
 * Implemented: initialization, capabilities, thread-local raw error detail,
 * monotonic/realtime/CPU clocks and sleep, environment reads/mutation/iteration,
 * current directory, executable path, and file basics (open/read/write/seek/
 * truncate/sync/stat/close, pipe, attributes, mkdir/remove/rename).
 *
 * Sockets, processes, threads, synchronization, dynamic libraries, directory
 * iteration, symlink reads and realpath remain explicit UNSUPPORTED in
 * grail_os_windows_stubs.c.  The Win32 declarations live in grail_win32.h so
 * the backend can be compiled for Win64 on a host without the Windows SDK.
 * This is static evidence only; it has not been executed on Windows.
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
#include "grail_win32.h"

typedef struct grail_win32_file {
    HANDLE handle;
} grail_win32_file;

typedef struct grail_win32_dir {
    HANDLE handle;
    WIN32_FIND_DATAW current;
    WIN32_FIND_DATAW next;
    int current_valid;
    int next_valid;
    int eof;
} grail_win32_dir;

typedef struct grail_win32_thread {
    HANDLE handle;
    grail_thread_entry entry;
    void *user;
    uint64_t result;
    SRWLOCK gate;
    int detached;
    int finished;
    int freed;
} grail_win32_thread;

typedef struct grail_win32_mutex {
    SRWLOCK lock;
} grail_win32_mutex;

typedef struct grail_win32_condvar {
    CONDITION_VARIABLE condition;
} grail_win32_condvar;

typedef struct grail_win32_library {
    HANDLE module;
} grail_win32_library;

typedef struct grail_win32_env_iterator {
    grail_env_snapshot snapshot;
    int64_t index;
} grail_win32_env_iterator;

typedef struct grail_win32_state {
    grail_allocator allocator;
    grail_handle_table files;
    grail_handle_table directories;
    grail_handle_table env_iterators;
    grail_handle_table threads;
    grail_handle_table mutexes;
    grail_handle_table condvars;
    grail_handle_table libraries;
    grail_env_store env;
    SRWLOCK lock;
    uint64_t capabilities;
    int initialized;
} grail_win32_state;

static grail_win32_state grail_windows = {{0, NULL, NULL, NULL, NULL},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, NULL, 0, 0},
                                          {NULL},
                                          0,
                                          0};
static _Thread_local grail_os_error grail_windows_error = {GRAIL_OS_DOMAIN_NONE, 0};
static _Thread_local char grail_windows_loader_error[512];

static void grail_windows_lock(void) {
    AcquireSRWLockExclusive(&grail_windows.lock);
}

static void grail_windows_unlock(void) {
    ReleaseSRWLockExclusive(&grail_windows.lock);
}

static int grail_windows_has_zero(const uint8_t *bytes, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static int grail_windows_env_name_valid(const uint8_t *name, uint64_t length) {
    if (name == NULL || length == 0 || grail_windows_has_zero(name, length)) {
        return 0;
    }
    for (uint64_t i = 0; i < length; i++) {
        if (name[i] == '=') {
            return 0;
        }
    }
    return 1;
}

static uint64_t grail_windows_text_length(const char *text) {
    uint64_t length = 0;
    while (text[length] != '\0') {
        length++;
    }
    return length;
}

static void *grail_windows_allocate(uint64_t size) {
    if (size == 0) {
        size = 1;
    }
    return grail_windows.allocator.allocate(grail_windows.allocator.context, size, 8);
}

static void grail_windows_release(void *pointer, uint64_t size) {
    if (pointer != NULL) {
        grail_windows.allocator.release(grail_windows.allocator.context, pointer, size, 8);
    }
}

static grail_status grail_windows_fail(DWORD code) {
    if (code == GRAIL_ERROR_SUCCESS) {
        code = GRAIL_ERROR_GEN_FAILURE;
    }
    grail_windows_error.domain = GRAIL_OS_DOMAIN_WIN32;
    grail_windows_error.code = (uint64_t)code;
    return grail_os_status_from_win32((int64_t)code);
}

static grail_status grail_windows_invalid_utf8(void) {
    grail_windows_error.domain = GRAIL_OS_DOMAIN_WIN32;
    grail_windows_error.code = GRAIL_ERROR_NO_UNICODE_TRANSLATION;
    return GRAIL_E_INVALID_UTF8;
}

static grail_status grail_windows_to_wide(const uint8_t *bytes, uint64_t length, WCHAR **out,
                                          uint64_t *units) {
    if (out == NULL || units == NULL || length > (uint64_t)INT32_MAX ||
        (bytes == NULL && length != 0) || grail_windows_has_zero(bytes, length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (length == 0) {
        WCHAR *empty = (WCHAR *)grail_windows_allocate(sizeof(WCHAR));
        if (empty == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        empty[0] = 0;
        *out = empty;
        *units = 0;
        return GRAIL_OK;
    }
    const int32_t needed = MultiByteToWideChar(GRAIL_CP_UTF8, GRAIL_MB_ERR_INVALID_CHARS,
                                               (const char *)bytes, (int32_t)length, NULL, 0);
    if (needed <= 0) {
        const DWORD error = GetLastError();
        return error == GRAIL_ERROR_NO_UNICODE_TRANSLATION ? grail_windows_invalid_utf8()
                                                           : grail_windows_fail(error);
    }
    WCHAR *wide = (WCHAR *)grail_windows_allocate(((uint64_t)needed + 1) * sizeof(WCHAR));
    if (wide == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    const int32_t written = MultiByteToWideChar(GRAIL_CP_UTF8, GRAIL_MB_ERR_INVALID_CHARS,
                                                (const char *)bytes, (int32_t)length, wide, needed);
    if (written != needed) {
        const DWORD error = GetLastError();
        grail_windows_release(wide, ((uint64_t)needed + 1) * sizeof(WCHAR));
        return error == GRAIL_ERROR_NO_UNICODE_TRANSLATION ? grail_windows_invalid_utf8()
                                                           : grail_windows_fail(error);
    }
    wide[needed] = 0;
    *out = wide;
    *units = (uint64_t)needed;
    return GRAIL_OK;
}

static void grail_windows_free_wide(WCHAR *wide, uint64_t units) {
    grail_windows_release(wide, (units + 1) * sizeof(WCHAR));
}

static grail_status grail_windows_from_wide(const WCHAR *wide, uint64_t units, uint8_t **out,
                                            uint64_t *length) {
    if (out == NULL || length == NULL || units > (uint64_t)INT32_MAX ||
        (wide == NULL && units != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (units == 0) {
        *out = NULL;
        *length = 0;
        return GRAIL_OK;
    }
    const int32_t needed = WideCharToMultiByte(GRAIL_CP_UTF8, GRAIL_WC_ERR_INVALID_CHARS, wide,
                                               (int32_t)units, NULL, 0, NULL, NULL);
    if (needed <= 0) {
        return grail_windows_fail(GetLastError());
    }
    uint8_t *text = (uint8_t *)grail_windows_allocate((uint64_t)needed);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    const int32_t written = WideCharToMultiByte(GRAIL_CP_UTF8, GRAIL_WC_ERR_INVALID_CHARS, wide,
                                                (int32_t)units, (char *)text, needed, NULL, NULL);
    if (written != needed) {
        const DWORD error = GetLastError();
        grail_windows_release(text, (uint64_t)needed);
        return grail_windows_fail(error);
    }
    *out = text;
    *length = (uint64_t)needed;
    return GRAIL_OK;
}

static grail_status grail_windows_wrap_file(HANDLE handle, grail_file *out) {
    grail_win32_file *file = (grail_win32_file *)grail_windows_allocate(sizeof(*file));
    if (file == NULL) {
        (void)CloseHandle(handle);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    file->handle = handle;
    grail_handle result = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_windows.files, file, &result);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        (void)CloseHandle(handle);
        grail_windows_release(file, sizeof(*file));
        return status;
    }
    *out = result;
    return GRAIL_OK;
}

static grail_status grail_windows_file_lookup(grail_file handle, grail_win32_file **out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_windows.files, handle, (void **)out);
    grail_windows_unlock();
    return status;
}

static uint64_t grail_windows_ticks(FILETIME time) {
    return ((uint64_t)time.dwHighDateTime << 32) | (uint64_t)time.dwLowDateTime;
}

static int64_t grail_windows_unix_ns(FILETIME time) {
    const uint64_t ticks = grail_windows_ticks(time);
    const uint64_t epoch = 116444736000000000ull;
    if (ticks < epoch) {
        return 0;
    }
    if (ticks - epoch > (uint64_t)INT64_MAX / 100u) {
        return 0;
    }
    return (int64_t)((ticks - epoch) * 100u);
}

static int64_t grail_windows_duration_ns(FILETIME time) {
    const uint64_t ticks = grail_windows_ticks(time);
    if (ticks > (uint64_t)INT64_MAX / 100u) {
        return 0;
    }
    return (int64_t)(ticks * 100u);
}

static uint64_t grail_windows_size(DWORD high, DWORD low) {
    return ((uint64_t)high << 32) | (uint64_t)low;
}

static void grail_windows_fill_stat(DWORD attributes, uint64_t size, FILETIME created,
                                    FILETIME accessed, FILETIME modified,
                                    grail_file_stat *out) {
    for (uint64_t i = 0; i < sizeof(*out); i++) {
        ((uint8_t *)out)[i] = 0;
    }
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    if ((attributes & GRAIL_FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
        out->kind = GRAIL_FILE_KIND_SYMLINK;
    } else if ((attributes & GRAIL_FILE_ATTRIBUTE_DIRECTORY) != 0) {
        out->kind = GRAIL_FILE_KIND_DIRECTORY;
    } else {
        out->kind = GRAIL_FILE_KIND_FILE;
    }
    if ((attributes & GRAIL_FILE_ATTRIBUTE_READONLY) != 0) {
        out->flags |= GRAIL_STAT_READ_ONLY;
    }
    if ((attributes & GRAIL_FILE_ATTRIBUTE_HIDDEN) != 0) {
        out->flags |= GRAIL_STAT_HIDDEN;
    }
    if (out->kind == GRAIL_FILE_KIND_SYMLINK) {
        out->flags |= GRAIL_STAT_SYMLINK;
    }
    if (out->kind == GRAIL_FILE_KIND_DIRECTORY) {
        out->mode = (attributes & GRAIL_FILE_ATTRIBUTE_READONLY) != 0 ? 0555 : 0777;
    } else {
        out->mode = (attributes & GRAIL_FILE_ATTRIBUTE_READONLY) != 0 ? 0444 : 0666;
    }
    out->size = size;
    out->created_ns = grail_windows_unix_ns(created);
    out->accessed_ns = grail_windows_unix_ns(accessed);
    out->modified_ns = grail_windows_unix_ns(modified);
}

grail_status grail_os_init(const grail_allocator *allocator, const grail_startup *startup) {
    if (allocator == NULL || allocator->allocate == NULL || allocator->release == NULL ||
        allocator->struct_size < sizeof(grail_allocator)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (grail_windows.initialized) {
        return GRAIL_E_UNSUPPORTED;
    }
    grail_windows.allocator = *allocator;
    InitializeSRWLock(&grail_windows.lock);
    grail_status status =
        grail_handle_table_init(&grail_windows.files, &grail_windows.allocator,
                                GRAIL_HANDLE_KIND_FILE);
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_windows.directories, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_DIR);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_windows.env_iterators, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_ENV_ITER);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_windows.threads, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_THREAD);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_windows.mutexes, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_MUTEX);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_windows.condvars, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_CONDVAR);
    }
    if (status == GRAIL_OK) {
        status = grail_handle_table_init(&grail_windows.libraries, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_LIBRARY);
    }
    if (status == GRAIL_OK) {
        status = grail_env_store_init(&grail_windows.env, &grail_windows.allocator);
    }
    if (status == GRAIL_OK) {
        status = grail_env_store_seed(&grail_windows.env, startup);
    }
    if (status != GRAIL_OK) {
        grail_handle_table_destroy(&grail_windows.files);
        grail_handle_table_destroy(&grail_windows.directories);
        grail_handle_table_destroy(&grail_windows.env_iterators);
        grail_handle_table_destroy(&grail_windows.threads);
        grail_handle_table_destroy(&grail_windows.mutexes);
        grail_handle_table_destroy(&grail_windows.condvars);
        grail_handle_table_destroy(&grail_windows.libraries);
        grail_env_store_free(&grail_windows.env);
        return status;
    }
    grail_windows.capabilities = GRAIL_CAP_FILES | GRAIL_CAP_FILE_METADATA | GRAIL_CAP_PATHS |
                                 GRAIL_CAP_UNICODE | GRAIL_CAP_ENVIRONMENT |
                                 GRAIL_CAP_ENV_MUTATION | GRAIL_CAP_TIME | GRAIL_CAP_CPU_TIME |
                                 GRAIL_CAP_DIRECTORIES | GRAIL_CAP_THREADS |
                                 GRAIL_CAP_SYNC_PRIMITIVES | GRAIL_CAP_DYNAMIC_LIBRARIES;
    grail_windows.initialized = 1;
    return GRAIL_OK;
}

grail_status grail_os_shutdown(void) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_handle_table_destroy(&grail_windows.files);
    grail_handle_table_destroy(&grail_windows.directories);
    grail_handle_table_destroy(&grail_windows.env_iterators);
    grail_handle_table_destroy(&grail_windows.threads);
    grail_handle_table_destroy(&grail_windows.mutexes);
    grail_handle_table_destroy(&grail_windows.condvars);
    grail_handle_table_destroy(&grail_windows.libraries);
    grail_env_store_free(&grail_windows.env);
    grail_windows.capabilities = 0;
    grail_windows.initialized = 0;
    return GRAIL_OK;
}

uint64_t grail_os_capabilities(void) {
    return grail_windows.initialized ? grail_windows.capabilities : 0;
}

grail_status grail_os_error_last(grail_os_error *out) {
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *out = grail_windows_error;
    return GRAIL_OK;
}

grail_status grail_os_time_now(uint64_t clock, int64_t *nanoseconds) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (nanoseconds == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (clock == GRAIL_CLOCK_MONOTONIC) {
        LARGE_INTEGER counter;
        LARGE_INTEGER frequency;
        if (!QueryPerformanceCounter(&counter) || !QueryPerformanceFrequency(&frequency) ||
            frequency.QuadPart <= 0 || counter.QuadPart < 0) {
            return grail_windows_fail(GetLastError());
        }
        const unsigned __int128 value =
            (unsigned __int128)(uint64_t)counter.QuadPart * 1000000000u /
            (uint64_t)frequency.QuadPart;
        if (value > (unsigned __int128)INT64_MAX) {
            return GRAIL_E_OVERFLOW;
        }
        *nanoseconds = (int64_t)value;
        return GRAIL_OK;
    }
    if (clock == GRAIL_CLOCK_REALTIME) {
        FILETIME value;
        GetSystemTimePreciseAsFileTime(&value);
        *nanoseconds = grail_windows_unix_ns(value);
        return GRAIL_OK;
    }
    if (clock == GRAIL_CLOCK_PROCESS_CPU || clock == GRAIL_CLOCK_THREAD_CPU) {
        FILETIME creation;
        FILETIME exit;
        FILETIME kernel;
        FILETIME user;
        const BOOL ok = clock == GRAIL_CLOCK_PROCESS_CPU
                            ? GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel,
                                              &user)
                            : GetThreadTimes(GetCurrentThread(), &creation, &exit, &kernel, &user);
        if (!ok) {
            return grail_windows_fail(GetLastError());
        }
        const int64_t kernel_ns = grail_windows_duration_ns(kernel);
        const int64_t user_ns = grail_windows_duration_ns(user);
        if (kernel_ns > INT64_MAX - user_ns) {
            return GRAIL_E_OVERFLOW;
        }
        *nanoseconds = kernel_ns + user_ns;
        return GRAIL_OK;
    }
    return GRAIL_E_INVALID_ARGUMENT;
}

grail_status grail_os_time_resolution(uint64_t clock, int64_t *nanoseconds) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (nanoseconds == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (clock == GRAIL_CLOCK_MONOTONIC) {
        LARGE_INTEGER frequency;
        if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0) {
            return grail_windows_fail(GetLastError());
        }
        *nanoseconds = (int64_t)(1000000000u / (uint64_t)frequency.QuadPart);
        return GRAIL_OK;
    }
    if (clock == GRAIL_CLOCK_REALTIME || clock == GRAIL_CLOCK_PROCESS_CPU ||
        clock == GRAIL_CLOCK_THREAD_CPU) {
        *nanoseconds = 100;
        return GRAIL_OK;
    }
    return GRAIL_E_INVALID_ARGUMENT;
}

grail_status grail_os_time_sleep(int64_t nanoseconds, int64_t *remaining_nanoseconds) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (nanoseconds < 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t milliseconds = ((uint64_t)nanoseconds + 999999u) / 1000000u;
    if (milliseconds == 0 && nanoseconds > 0) {
        milliseconds = 1;
    }
    if (milliseconds > 0xFFFFFFFEu) {
        milliseconds = 0xFFFFFFFEu;
    }
    Sleep((DWORD)milliseconds);
    if (remaining_nanoseconds != NULL) {
        *remaining_nanoseconds = 0;
    }
    return GRAIL_OK;
}

grail_result grail_os_env_get(const uint8_t *name, uint64_t name_length, uint8_t *out,
                              uint64_t capacity) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    const char *value = NULL;
    uint64_t length = 0;
    grail_windows_lock();
    const grail_status status =
        grail_env_store_get(&grail_windows.env, name, name_length, &value, &length);
    grail_result result;
    if (status == GRAIL_OK) {
        result = grail_abi_copy_out((const uint8_t *)value, length, out, capacity);
    } else {
        result = status;
    }
    grail_windows_unlock();
    return result;
}

grail_status grail_os_env_set(const uint8_t *name, uint64_t name_length, const uint8_t *value,
                              uint64_t value_length) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (!grail_windows_env_name_valid(name, name_length) ||
        (value == NULL && value_length != 0) || grail_windows_has_zero(value, value_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    WCHAR *wide_name = NULL;
    WCHAR *wide_value = NULL;
    uint64_t name_units = 0;
    uint64_t value_units = 0;
    grail_status status = grail_windows_to_wide(name, name_length, &wide_name, &name_units);
    if (status == GRAIL_OK) {
        status = grail_windows_to_wide(value, value_length, &wide_value, &value_units);
    }
    if (status == GRAIL_OK && !SetEnvironmentVariableW(wide_name, wide_value)) {
        status = grail_windows_fail(GetLastError());
    }
    if (status == GRAIL_OK) {
        grail_windows_lock();
        status = grail_env_store_set(&grail_windows.env, name, name_length, value, value_length);
        grail_windows_unlock();
    }
    grail_windows_free_wide(wide_name, name_units);
    grail_windows_free_wide(wide_value, value_units);
    return status;
}

grail_status grail_os_env_unset(const uint8_t *name, uint64_t name_length) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (!grail_windows_env_name_valid(name, name_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    WCHAR *wide_name = NULL;
    uint64_t name_units = 0;
    grail_status status = grail_windows_to_wide(name, name_length, &wide_name, &name_units);
    if (status == GRAIL_OK && !SetEnvironmentVariableW(wide_name, NULL)) {
        status = grail_windows_fail(GetLastError());
    }
    if (status == GRAIL_OK) {
        grail_windows_lock();
        status = grail_env_store_unset(&grail_windows.env, name, name_length);
        grail_windows_unlock();
    }
    grail_windows_free_wide(wide_name, name_units);
    return status;
}

grail_status grail_os_env_iter_open(grail_env_iter *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_win32_env_iterator *iterator =
        (grail_win32_env_iterator *)grail_windows_allocate(sizeof(*iterator));
    if (iterator == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    iterator->index = -1;
    grail_windows_lock();
    grail_status status = grail_env_snapshot_take(&grail_windows.env, &iterator->snapshot);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        grail_windows_release(iterator, sizeof(*iterator));
        return status;
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    status = grail_handle_table_allocate(&grail_windows.env_iterators, iterator, &handle);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        grail_env_snapshot_free(&iterator->snapshot);
        grail_windows_release(iterator, sizeof(*iterator));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static grail_status grail_windows_env_iterator_lookup(grail_env_iter handle,
                                                      grail_win32_env_iterator **out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_windows.env_iterators, handle, (void **)out);
    grail_windows_unlock();
    return status;
}

grail_status grail_os_env_iter_next(grail_env_iter handle, uint64_t *is_last) {
    grail_win32_env_iterator *iterator = NULL;
    const grail_status status = grail_windows_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) {
        return status;
    }
    if (is_last == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
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
    grail_win32_env_iterator *iterator = NULL;
    const grail_status status = grail_windows_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) {
        return status;
    }
    if (iterator->index < 0 || iterator->index >= (int64_t)iterator->snapshot.count) {
        return GRAIL_E_NOT_FOUND;
    }
    const char *name = iterator->snapshot.names[iterator->index];
    return grail_abi_copy_out((const uint8_t *)name, grail_windows_text_length(name), out,
                              capacity);
}

grail_result grail_os_env_iter_value(grail_env_iter handle, uint8_t *out, uint64_t capacity) {
    grail_win32_env_iterator *iterator = NULL;
    const grail_status status = grail_windows_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) {
        return status;
    }
    if (iterator->index < 0 || iterator->index >= (int64_t)iterator->snapshot.count) {
        return GRAIL_E_NOT_FOUND;
    }
    const char *value = iterator->snapshot.values[iterator->index];
    return grail_abi_copy_out((const uint8_t *)value, grail_windows_text_length(value), out,
                              capacity);
}

grail_status grail_os_env_iter_close(grail_env_iter handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_env_iterator *iterator = NULL;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_release(&grail_windows.env_iterators, handle, (void **)&iterator);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_env_snapshot_free(&iterator->snapshot);
    grail_windows_release(iterator, sizeof(*iterator));
    return GRAIL_OK;
}

grail_result grail_os_path_current_directory(uint8_t *out, uint64_t capacity) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    uint64_t size = 256;
    while (size <= 1048576) {
        WCHAR *buffer = (WCHAR *)grail_windows_allocate(size * sizeof(WCHAR));
        if (buffer == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        const DWORD length = GetCurrentDirectoryW((DWORD)size, buffer);
        if (length == 0) {
            const DWORD error = GetLastError();
            grail_windows_release(buffer, size * sizeof(WCHAR));
            return grail_windows_fail(error);
        }
        if (length < size) {
            uint8_t *text = NULL;
            uint64_t text_length = 0;
            const grail_status status =
                grail_windows_from_wide(buffer, length, &text, &text_length);
            grail_windows_release(buffer, size * sizeof(WCHAR));
            if (status != GRAIL_OK) {
                return status;
            }
            const grail_result result = grail_abi_copy_out(text, text_length, out, capacity);
            grail_windows_release(text, text_length);
            return result;
        }
        grail_windows_release(buffer, size * sizeof(WCHAR));
        size *= 2;
    }
    return GRAIL_E_NAME_TOO_LONG;
}

grail_status grail_os_path_set_current_directory(const uint8_t *path, uint64_t length) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    const grail_status status = grail_windows_to_wide(path, length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    const BOOL result = SetCurrentDirectoryW(wide);
    const DWORD error = GetLastError();
    grail_windows_free_wide(wide, units);
    return result ? GRAIL_OK : grail_windows_fail(error);
}

grail_result grail_os_path_executable(uint8_t *out, uint64_t capacity) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    uint64_t size = 256;
    while (size <= 1048576) {
        WCHAR *buffer = (WCHAR *)grail_windows_allocate(size * sizeof(WCHAR));
        if (buffer == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        const DWORD length = GetModuleFileNameW(NULL, buffer, (DWORD)size);
        if (length == 0) {
            const DWORD error = GetLastError();
            grail_windows_release(buffer, size * sizeof(WCHAR));
            return grail_windows_fail(error);
        }
        if (length < size) {
            uint8_t *text = NULL;
            uint64_t text_length = 0;
            const grail_status status =
                grail_windows_from_wide(buffer, length, &text, &text_length);
            grail_windows_release(buffer, size * sizeof(WCHAR));
            if (status != GRAIL_OK) {
                return status;
            }
            const grail_result result = grail_abi_copy_out(text, text_length, out, capacity);
            grail_windows_release(text, text_length);
            return result;
        }
        grail_windows_release(buffer, size * sizeof(WCHAR));
        size *= 2;
    }
    return GRAIL_E_NAME_TOO_LONG;
}

grail_status grail_os_file_open(const uint8_t *path, uint64_t path_length, uint64_t flags,
                                uint64_t mode, grail_file *out) {
    (void)mode;
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL || (flags & (GRAIL_OPEN_READ | GRAIL_OPEN_WRITE)) == 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((flags & GRAIL_OPEN_NONBLOCKING) != 0) {
        return GRAIL_E_UNSUPPORTED;
    }
    if ((flags & GRAIL_OPEN_TRUNCATE) != 0 && (flags & GRAIL_OPEN_WRITE) == 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    DWORD access = 0;
    if ((flags & GRAIL_OPEN_READ) != 0) {
        access |= GRAIL_GENERIC_READ;
    }
    if ((flags & GRAIL_OPEN_WRITE) != 0) {
        access |= (flags & GRAIL_OPEN_APPEND) != 0 ? GRAIL_FILE_APPEND_DATA : GRAIL_GENERIC_WRITE;
    }
    DWORD creation = GRAIL_OPEN_EXISTING;
    if ((flags & GRAIL_OPEN_CREATE) != 0) {
        if ((flags & GRAIL_OPEN_EXCLUSIVE) != 0) {
            creation = GRAIL_CREATE_NEW;
        } else if ((flags & GRAIL_OPEN_TRUNCATE) != 0) {
            creation = GRAIL_CREATE_ALWAYS;
        } else {
            creation = GRAIL_OPEN_ALWAYS;
        }
    } else if ((flags & GRAIL_OPEN_TRUNCATE) != 0) {
        creation = GRAIL_TRUNCATE_EXISTING;
    }
    DWORD attributes = GRAIL_FILE_ATTRIBUTE_NORMAL;
    if ((flags & GRAIL_OPEN_DIRECTORY) != 0) {
        attributes |= GRAIL_FILE_FLAG_BACKUP_SEMANTICS;
    }
    if ((flags & GRAIL_OPEN_NO_FOLLOW) != 0) {
        attributes |= GRAIL_FILE_FLAG_OPEN_REPARSE_POINT;
    }
    if ((flags & GRAIL_OPEN_SYNC) != 0) {
        attributes |= GRAIL_FILE_FLAG_WRITE_THROUGH;
    }
    const HANDLE handle =
        CreateFileW(wide, access,
                    GRAIL_FILE_SHARE_READ | GRAIL_FILE_SHARE_WRITE | GRAIL_FILE_SHARE_DELETE,
                    NULL, creation, attributes, NULL);
    const DWORD error = GetLastError();
    grail_windows_free_wide(wide, units);
    if (handle == GRAIL_INVALID_HANDLE_VALUE) {
        return grail_windows_fail(error);
    }
    return grail_windows_wrap_file(handle, out);
}

grail_status grail_os_file_read(grail_file handle, uint8_t *buffer, uint64_t capacity,
                                uint64_t *read_length) {
    grail_win32_file *file = NULL;
    const grail_status status = grail_windows_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (read_length == NULL || (buffer == NULL && capacity != 0) ||
        capacity > (uint64_t)0xFFFFFFFFu) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (capacity == 0) {
        *read_length = 0;
        return GRAIL_OK;
    }
    DWORD count = 0;
    if (!ReadFile(file->handle, buffer, (DWORD)capacity, &count, NULL)) {
        return grail_windows_fail(GetLastError());
    }
    *read_length = (uint64_t)count;
    return GRAIL_OK;
}

grail_status grail_os_file_write(grail_file handle, const uint8_t *buffer, uint64_t length,
                                 uint64_t *written_length) {
    grail_win32_file *file = NULL;
    const grail_status status = grail_windows_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (written_length == NULL || (buffer == NULL && length != 0) ||
        length > (uint64_t)0xFFFFFFFFu) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (length == 0) {
        *written_length = 0;
        return GRAIL_OK;
    }
    DWORD count = 0;
    if (!WriteFile(file->handle, buffer, (DWORD)length, &count, NULL)) {
        return grail_windows_fail(GetLastError());
    }
    *written_length = (uint64_t)count;
    return GRAIL_OK;
}

grail_status grail_os_file_seek(grail_file handle, int64_t offset, uint64_t whence,
                                uint64_t *position) {
    grail_win32_file *file = NULL;
    const grail_status status = grail_windows_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (position == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    DWORD method;
    if (whence == GRAIL_SEEK_SET) {
        method = GRAIL_FILE_BEGIN;
    } else if (whence == GRAIL_SEEK_CURRENT) {
        method = GRAIL_FILE_CURRENT;
    } else if (whence == GRAIL_SEEK_END) {
        method = GRAIL_FILE_END;
    } else {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    LARGE_INTEGER distance;
    distance.QuadPart = offset;
    LARGE_INTEGER result;
    if (!SetFilePointerEx(file->handle, distance, &result, method)) {
        return grail_windows_fail(GetLastError());
    }
    if (result.QuadPart < 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *position = (uint64_t)result.QuadPart;
    return GRAIL_OK;
}

grail_status grail_os_file_truncate(grail_file handle, uint64_t length) {
    grail_win32_file *file = NULL;
    const grail_status status = grail_windows_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (length > (uint64_t)INT64_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    LARGE_INTEGER distance;
    distance.QuadPart = (int64_t)length;
    if (!SetFilePointerEx(file->handle, distance, NULL, GRAIL_FILE_BEGIN)) {
        return grail_windows_fail(GetLastError());
    }
    if (!SetEndOfFile(file->handle)) {
        return grail_windows_fail(GetLastError());
    }
    return GRAIL_OK;
}

grail_status grail_os_file_sync(grail_file handle, uint64_t data_only) {
    (void)data_only;
    grail_win32_file *file = NULL;
    const grail_status status = grail_windows_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (!FlushFileBuffers(file->handle)) {
        return grail_windows_fail(GetLastError());
    }
    return GRAIL_OK;
}

grail_status grail_os_file_stat(grail_file handle, grail_file_stat *out) {
    grail_win32_file *file = NULL;
    const grail_status status = grail_windows_file_lookup(handle, &file);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    BY_HANDLE_FILE_INFORMATION info;
    if (!GetFileInformationByHandle(file->handle, &info)) {
        return grail_windows_fail(GetLastError());
    }
    grail_windows_fill_stat(info.dwFileAttributes,
                            grail_windows_size(info.nFileSizeHigh, info.nFileSizeLow),
                            info.ftCreationTime, info.ftLastAccessTime, info.ftLastWriteTime, out);
    out->link_count = info.nNumberOfLinks;
    out->device = info.dwVolumeSerialNumber;
    out->inode = grail_windows_size(info.nFileIndexHigh, info.nFileIndexLow);
    return GRAIL_OK;
}

grail_status grail_os_file_close(grail_file handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_file *file = NULL;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_release(&grail_windows.files, handle, (void **)&file);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const BOOL closed = CloseHandle(file->handle);
    const DWORD error = GetLastError();
    grail_windows_release(file, sizeof(*file));
    return closed ? GRAIL_OK : grail_windows_fail(error);
}

grail_status grail_os_pipe(grail_pipe *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    HANDLE read_end = NULL;
    HANDLE write_end = NULL;
    if (!CreatePipe(&read_end, &write_end, NULL, 0)) {
        return grail_windows_fail(GetLastError());
    }
    grail_file read_handle = GRAIL_HANDLE_NONE;
    grail_status status = grail_windows_wrap_file(read_end, &read_handle);
    if (status != GRAIL_OK) {
        (void)CloseHandle(write_end);
        return status;
    }
    grail_file write_handle = GRAIL_HANDLE_NONE;
    status = grail_windows_wrap_file(write_end, &write_handle);
    if (status != GRAIL_OK) {
        grail_win32_file *file = NULL;
        grail_windows_lock();
        (void)grail_handle_table_release(&grail_windows.files, read_handle, (void **)&file);
        grail_windows_unlock();
        if (file != NULL) {
            (void)CloseHandle(file->handle);
            grail_windows_release(file, sizeof(*file));
        }
        return status;
    }
    out->read_end = read_handle;
    out->write_end = write_handle;
    return GRAIL_OK;
}


static uint32_t grail_windows_thread_main(void *argument) {
    grail_win32_thread *thread = (grail_win32_thread *)argument;
    const uint64_t result = thread->entry(thread->user);
    int release = 0;
    AcquireSRWLockExclusive(&thread->gate);
    thread->result = result;
    thread->finished = 1;
    if (thread->detached && !thread->freed) {
        thread->freed = 1;
        release = 1;
    }
    ReleaseSRWLockExclusive(&thread->gate);
    if (release) {
        grail_windows_release(thread, sizeof(*thread));
    }
    return (uint32_t)result;
}

grail_status grail_os_thread_spawn(grail_thread_entry entry, void *user,
                                   const grail_thread_options *options, grail_thread *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (entry == NULL || out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t stack_size = 0;
    if (options != NULL) {
        if (options->struct_size < sizeof(*options) || options->abi_version != GRAIL_ABI_VERSION) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        if (options->flags != 0) {
            return GRAIL_E_UNSUPPORTED;
        }
        stack_size = options->stack_size;
    }
    grail_win32_thread *thread = (grail_win32_thread *)grail_windows_allocate(sizeof(*thread));
    if (thread == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < sizeof(*thread); i++) {
        ((uint8_t *)thread)[i] = 0;
    }
    thread->entry = entry;
    thread->user = user;
    InitializeSRWLock(&thread->gate);
    DWORD identifier = 0;
    thread->handle = CreateThread(NULL, stack_size, grail_windows_thread_main, thread, 0,
                                  &identifier);
    if (thread->handle == NULL) {
        const DWORD error = GetLastError();
        grail_windows_release(thread, sizeof(*thread));
        return grail_windows_fail(error);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_windows.threads, thread, &handle);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        const HANDLE thread_handle = thread->handle;
        int release = 0;
        AcquireSRWLockExclusive(&thread->gate);
        if (thread->finished && !thread->freed) {
            thread->freed = 1;
            release = 1;
        } else {
            thread->detached = 1;
        }
        ReleaseSRWLockExclusive(&thread->gate);
        (void)CloseHandle(thread_handle);
        if (release) {
            grail_windows_release(thread, sizeof(*thread));
        }
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static grail_status grail_windows_thread_lookup(grail_thread handle, grail_win32_thread **out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_windows.threads, handle, (void **)out);
    grail_windows_unlock();
    return status;
}

grail_status grail_os_thread_join(grail_thread handle, uint64_t *exit_code) {
    grail_win32_thread *thread = NULL;
    grail_status status = grail_windows_thread_lookup(handle, &thread);
    if (status != GRAIL_OK) {
        return status;
    }
    if (WaitForSingleObject(thread->handle, GRAIL_WIN32_INFINITE) != GRAIL_WAIT_OBJECT_0) {
        return grail_windows_fail(GetLastError());
    }
    AcquireSRWLockExclusive(&thread->gate);
    const uint64_t result = thread->result;
    thread->freed = 1;
    ReleaseSRWLockExclusive(&thread->gate);
    grail_windows_lock();
    status = grail_handle_table_release(&grail_windows.threads, handle, NULL);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    (void)CloseHandle(thread->handle);
    grail_windows_release(thread, sizeof(*thread));
    if (exit_code != NULL) {
        *exit_code = result;
    }
    return GRAIL_OK;
}

grail_status grail_os_thread_detach(grail_thread handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_thread *thread = NULL;
    grail_windows_lock();
    grail_status status = grail_handle_table_release(&grail_windows.threads, handle, (void **)&thread);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const HANDLE thread_handle = thread->handle;
    int release = 0;
    AcquireSRWLockExclusive(&thread->gate);
    if (thread->finished && !thread->freed) {
        thread->freed = 1;
        release = 1;
    } else if (!thread->finished) {
        thread->detached = 1;
    }
    ReleaseSRWLockExclusive(&thread->gate);
    if (release) {
        grail_windows_release(thread, sizeof(*thread));
    }
    if (!CloseHandle(thread_handle)) {
        return grail_windows_fail(GetLastError());
    }
    return GRAIL_OK;
}

grail_status grail_os_thread_id(uint64_t *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *out = (uint64_t)GetCurrentThreadId();
    return GRAIL_OK;
}

grail_status grail_os_thread_yield(void) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    (void)SwitchToThread();
    return GRAIL_OK;
}

static grail_status grail_windows_mutex_lookup(grail_mutex handle, grail_win32_mutex **out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_windows.mutexes, handle, (void **)out);
    grail_windows_unlock();
    return status;
}

grail_status grail_os_mutex_create(grail_mutex *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_win32_mutex *mutex = (grail_win32_mutex *)grail_windows_allocate(sizeof(*mutex));
    if (mutex == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    InitializeSRWLock(&mutex->lock);
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_windows.mutexes, mutex, &handle);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        grail_windows_release(mutex, sizeof(*mutex));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_mutex_lock(grail_mutex handle) {
    grail_win32_mutex *mutex = NULL;
    const grail_status status = grail_windows_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    AcquireSRWLockExclusive(&mutex->lock);
    return GRAIL_OK;
}

grail_status grail_os_mutex_try_lock(grail_mutex handle, uint64_t *acquired) {
    grail_win32_mutex *mutex = NULL;
    const grail_status status = grail_windows_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    if (acquired == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *acquired = TryAcquireSRWLockExclusive(&mutex->lock) ? 1 : 0;
    return GRAIL_OK;
}

grail_status grail_os_mutex_unlock(grail_mutex handle) {
    grail_win32_mutex *mutex = NULL;
    const grail_status status = grail_windows_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    ReleaseSRWLockExclusive(&mutex->lock);
    return GRAIL_OK;
}

grail_status grail_os_mutex_destroy(grail_mutex handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_mutex *mutex = NULL;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_release(&grail_windows.mutexes, handle, (void **)&mutex);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_windows_release(mutex, sizeof(*mutex));
    return GRAIL_OK;
}

static grail_status grail_windows_condvar_lookup(grail_condvar handle,
                                                 grail_win32_condvar **out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_windows.condvars, handle, (void **)out);
    grail_windows_unlock();
    return status;
}

grail_status grail_os_condvar_create(grail_condvar *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_win32_condvar *condvar =
        (grail_win32_condvar *)grail_windows_allocate(sizeof(*condvar));
    if (condvar == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    InitializeConditionVariable(&condvar->condition);
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_windows.condvars, condvar, &handle);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        grail_windows_release(condvar, sizeof(*condvar));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_condvar_wait(grail_condvar condvar_handle, grail_mutex mutex_handle,
                                   int64_t timeout_ns, uint64_t *signaled) {
    grail_win32_condvar *condvar = NULL;
    grail_status status = grail_windows_condvar_lookup(condvar_handle, &condvar);
    if (status != GRAIL_OK) {
        return status;
    }
    grail_win32_mutex *mutex = NULL;
    status = grail_windows_mutex_lookup(mutex_handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    if (signaled == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    DWORD milliseconds;
    if (timeout_ns < 0) {
        milliseconds = GRAIL_WIN32_INFINITE;
    } else {
        uint64_t value = ((uint64_t)timeout_ns + 999999u) / 1000000u;
        if (value == 0 && timeout_ns > 0) {
            value = 1;
        }
        milliseconds = value > 0xFFFFFFFEu ? 0xFFFFFFFEu : (DWORD)value;
    }
    if (SleepConditionVariableSRW(&condvar->condition, &mutex->lock, milliseconds, 0)) {
        *signaled = 1;
        return GRAIL_OK;
    }
    if (GetLastError() == GRAIL_ERROR_TIMEOUT) {
        *signaled = 0;
        return GRAIL_OK;
    }
    return grail_windows_fail(GetLastError());
}

grail_status grail_os_condvar_signal(grail_condvar handle) {
    grail_win32_condvar *condvar = NULL;
    const grail_status status = grail_windows_condvar_lookup(handle, &condvar);
    if (status != GRAIL_OK) {
        return status;
    }
    WakeConditionVariable(&condvar->condition);
    return GRAIL_OK;
}

grail_status grail_os_condvar_broadcast(grail_condvar handle) {
    grail_win32_condvar *condvar = NULL;
    const grail_status status = grail_windows_condvar_lookup(handle, &condvar);
    if (status != GRAIL_OK) {
        return status;
    }
    WakeAllConditionVariable(&condvar->condition);
    return GRAIL_OK;
}

grail_status grail_os_condvar_destroy(grail_condvar handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_condvar *condvar = NULL;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_release(&grail_windows.condvars, handle, (void **)&condvar);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_windows_release(condvar, sizeof(*condvar));
    return GRAIL_OK;
}

static void grail_windows_set_loader_error(DWORD code) {
    WCHAR message[512];
    const DWORD length = FormatMessageW(GRAIL_FORMAT_MESSAGE_FROM_SYSTEM |
                                            GRAIL_FORMAT_MESSAGE_IGNORE_INSERTS,
                                        NULL, code, 0, message, 512, NULL);
    if (length == 0) {
        grail_windows_loader_error[0] = '\0';
        return;
    }
    uint64_t units = length;
    while (units > 0 && (message[units - 1] == '\r' || message[units - 1] == '\n' ||
                         message[units - 1] == ' ')) {
        units--;
    }
    uint8_t *text = NULL;
    uint64_t text_length = 0;
    if (grail_windows_from_wide(message, units, &text, &text_length) != GRAIL_OK) {
        grail_windows_loader_error[0] = '\0';
        return;
    }
    const uint64_t limit = text_length < sizeof(grail_windows_loader_error) - 1
                               ? text_length
                               : sizeof(grail_windows_loader_error) - 1;
    for (uint64_t i = 0; i < limit; i++) {
        grail_windows_loader_error[i] = (char)text[i];
    }
    grail_windows_loader_error[limit] = '\0';
    grail_windows_release(text, text_length);
}

grail_status grail_os_dl_open(const uint8_t *name, uint64_t name_length, uint64_t flags,
                              grail_library *out) {
    (void)flags;
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL || (name == NULL && name_length != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    HANDLE module = NULL;
    if (name_length == 0) {
        module = GetModuleHandleW(NULL);
        if (module == NULL) {
            const DWORD error = GetLastError();
            grail_windows_set_loader_error(error);
            return grail_windows_fail(error);
        }
    } else {
        WCHAR *wide = NULL;
        uint64_t units = 0;
        const grail_status status = grail_windows_to_wide(name, name_length, &wide, &units);
        if (status != GRAIL_OK) {
            return status;
        }
        module = LoadLibraryExW(wide, NULL, 0);
        const DWORD error = GetLastError();
        grail_windows_free_wide(wide, units);
        if (module == NULL) {
            grail_windows_set_loader_error(error);
            if (error == 2 || error == 3 || error == 126) {
                return GRAIL_E_NOT_FOUND;
            }
            return grail_windows_fail(error);
        }
    }
    grail_win32_library *library =
        (grail_win32_library *)grail_windows_allocate(sizeof(*library));
    if (library == NULL) {
        (void)FreeLibrary(module);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    library->module = module;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_windows.libraries, library, &handle);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        (void)FreeLibrary(module);
        grail_windows_release(library, sizeof(*library));
        return status;
    }
    grail_windows_loader_error[0] = '\0';
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_dl_symbol(grail_library handle, const uint8_t *name, uint64_t name_length,
                                void **symbol) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (name == NULL || name_length == 0 || symbol == NULL ||
        grail_windows_has_zero(name, name_length) || name_length > (uint64_t)INT32_MAX) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_win32_library *library = NULL;
    grail_windows_lock();
    grail_status status =
        grail_handle_table_lookup(&grail_windows.libraries, handle, (void **)&library);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    char *text = (char *)grail_windows_allocate(name_length + 1);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < name_length; i++) {
        text[i] = (char)name[i];
    }
    text[name_length] = '\0';
    void *address = GetProcAddress(library->module, text);
    const DWORD error = GetLastError();
    grail_windows_release(text, name_length + 1);
    if (address == NULL) {
        grail_windows_set_loader_error(error);
        return GRAIL_E_NOT_FOUND;
    }
    grail_windows_loader_error[0] = '\0';
    *symbol = address;
    return GRAIL_OK;
}

grail_status grail_os_dl_close(grail_library handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_library *library = NULL;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_release(&grail_windows.libraries, handle, (void **)&library);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const BOOL closed = FreeLibrary(library->module);
    const DWORD error = GetLastError();
    grail_windows_release(library, sizeof(*library));
    if (!closed) {
        grail_windows_set_loader_error(error);
        return grail_windows_fail(error);
    }
    return GRAIL_OK;
}

grail_result grail_os_dl_error(uint8_t *out, uint64_t capacity) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    return grail_abi_copy_out((const uint8_t *)grail_windows_loader_error,
                              grail_windows_text_length(grail_windows_loader_error), out,
                              capacity);
}

grail_status grail_os_fs_stat(const uint8_t *path, uint64_t path_length, uint64_t flags,
                              grail_file_stat *out) {
    (void)flags;
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    WIN32_FILE_ATTRIBUTE_DATA data;
    const BOOL ok = GetFileAttributesExW(wide, GRAIL_GET_FILE_EX_INFO_STANDARD, &data);
    const DWORD error = GetLastError();
    grail_windows_free_wide(wide, units);
    if (!ok) {
        return grail_windows_fail(error);
    }
    grail_windows_fill_stat(data.dwFileAttributes,
                            grail_windows_size(data.dwFileSizeHigh, data.dwFileSizeLow),
                            data.ftCreationTime, data.ftLastAccessTime, data.ftLastWriteTime, out);
    return GRAIL_OK;
}


static int grail_windows_wide_is_dot(const WCHAR *name) {
    if (name[0] == 0) {
        return 1;
    }
    if (name[0] == '.' && name[1] == 0) {
        return 1;
    }
    return name[0] == '.' && name[1] == '.' && name[2] == 0;
}

static uint64_t grail_windows_wide_length(const WCHAR *text, uint64_t limit) {
    uint64_t length = 0;
    while (length < limit && text[length] != 0) {
        length++;
    }
    return length;
}

static uint64_t grail_windows_kind(DWORD attributes) {
    if ((attributes & GRAIL_FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
        return GRAIL_FILE_KIND_SYMLINK;
    }
    if ((attributes & GRAIL_FILE_ATTRIBUTE_DIRECTORY) != 0) {
        return GRAIL_FILE_KIND_DIRECTORY;
    }
    return GRAIL_FILE_KIND_FILE;
}

static int grail_windows_dir_fetch(HANDLE find, WIN32_FIND_DATAW *data, grail_status *error) {
    for (;;) {
        if (FindNextFileW(find, data)) {
            if (!grail_windows_wide_is_dot(data->cFileName)) {
                return 1;
            }
            continue;
        }
        const DWORD code = GetLastError();
        if (code == GRAIL_ERROR_NO_MORE_FILES) {
            return 0;
        }
        *error = grail_windows_fail(code);
        return -1;
    }
}

static grail_status grail_windows_dir_lookup(grail_dir handle, grail_win32_dir **out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_windows.directories, handle, (void **)out);
    grail_windows_unlock();
    return status;
}

grail_status grail_os_dir_open(const uint8_t *path, uint64_t path_length, grail_dir *out) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    if (units == 0) {
        grail_windows_free_wide(wide, units);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const DWORD attributes = GetFileAttributesW(wide);
    if (attributes == GRAIL_INVALID_FILE_ATTRIBUTES) {
        const DWORD error = GetLastError();
        grail_windows_free_wide(wide, units);
        return grail_windows_fail(error);
    }
    if ((attributes & GRAIL_FILE_ATTRIBUTE_DIRECTORY) == 0) {
        grail_windows_free_wide(wide, units);
        return GRAIL_E_NOT_A_DIRECTORY;
    }
    WCHAR *pattern = (WCHAR *)grail_windows_allocate((units + 4) * sizeof(WCHAR));
    if (pattern == NULL) {
        grail_windows_free_wide(wide, units);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < units; i++) {
        pattern[i] = wide[i];
    }
    uint64_t at = units;
    if (wide[units - 1] == '/' || wide[units - 1] == '\\') {
        pattern[at++] = '*';
    } else {
        pattern[at++] = '\\';
        pattern[at++] = '*';
    }
    pattern[at] = 0;
    grail_windows_free_wide(wide, units);

    grail_win32_dir *dir = (grail_win32_dir *)grail_windows_allocate(sizeof(*dir));
    if (dir == NULL) {
        grail_windows_release(pattern, (units + 4) * sizeof(WCHAR));
        return GRAIL_E_OUT_OF_MEMORY;
    }
    for (uint64_t i = 0; i < sizeof(*dir); i++) {
        ((uint8_t *)dir)[i] = 0;
    }
    dir->handle = GRAIL_INVALID_HANDLE_VALUE;
    dir->handle = FindFirstFileW(pattern, &dir->current);
    const DWORD first_error = GetLastError();
    grail_windows_release(pattern, (units + 4) * sizeof(WCHAR));
    if (dir->handle == GRAIL_INVALID_HANDLE_VALUE) {
        if (first_error == GRAIL_ERROR_FILE_NOT_FOUND || first_error == GRAIL_ERROR_PATH_NOT_FOUND) {
            dir->eof = 1;
            dir->current_valid = 0;
        } else {
            grail_windows_release(dir, sizeof(*dir));
            return grail_windows_fail(first_error);
        }
    } else {
        while (grail_windows_wide_is_dot(dir->current.cFileName)) {
            if (!grail_windows_dir_fetch(dir->handle, &dir->current, &status)) {
                if (status != GRAIL_OK) {
                    (void)FindClose(dir->handle);
                    grail_windows_release(dir, sizeof(*dir));
                    return status;
                }
                dir->eof = 1;
                dir->current_valid = 0;
                break;
            }
        }
        dir->current_valid = dir->eof ? 0 : 1;
    }
    if (dir->current_valid) {
        int fetched = grail_windows_dir_fetch(dir->handle, &dir->next, &status);
        if (fetched < 0) {
            (void)FindClose(dir->handle);
            grail_windows_release(dir, sizeof(*dir));
            return status;
        }
        dir->next_valid = fetched;
        if (fetched == 0) {
            dir->eof = 1;
        }
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_windows_lock();
    status = grail_handle_table_allocate(&grail_windows.directories, dir, &handle);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        if (dir->handle != GRAIL_INVALID_HANDLE_VALUE) {
            (void)FindClose(dir->handle);
        }
        grail_windows_release(dir, sizeof(*dir));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_result grail_os_dir_next(grail_dir handle, uint8_t *name, uint64_t capacity,
                               grail_dir_entry *out) {
    grail_win32_dir *dir = NULL;
    grail_status status = grail_windows_dir_lookup(handle, &dir);
    if (status != GRAIL_OK) {
        return status;
    }
    if (out == NULL || (name == NULL && capacity != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (!dir->current_valid) {
        for (uint64_t i = 0; i < sizeof(*out); i++) {
            ((uint8_t *)out)[i] = 0;
        }
        out->struct_size = sizeof(*out);
        out->abi_version = GRAIL_ABI_VERSION;
        out->is_last = 1;
        return 0;
    }
    if (!dir->next_valid && !dir->eof) {
        int fetched = grail_windows_dir_fetch(dir->handle, &dir->next, &status);
        if (fetched < 0) {
            return status;
        }
        dir->next_valid = fetched;
        if (fetched == 0) {
            dir->eof = 1;
        }
    }
    const uint64_t units =
        grail_windows_wide_length(dir->current.cFileName, 260);
    uint8_t *text = NULL;
    uint64_t text_length = 0;
    status = grail_windows_from_wide(dir->current.cFileName, units, &text, &text_length);
    if (status != GRAIL_OK) {
        return status;
    }
    for (uint64_t i = 0; i < sizeof(*out); i++) {
        ((uint8_t *)out)[i] = 0;
    }
    out->struct_size = sizeof(*out);
    out->abi_version = GRAIL_ABI_VERSION;
    out->name_length = text_length;
    out->kind = grail_windows_kind(dir->current.dwFileAttributes);
    out->is_last = (!dir->next_valid && dir->eof) ? 1 : 0;
    if (text_length > capacity || name == NULL) {
        grail_windows_release(text, text_length);
        return (grail_result)text_length;
    }
    for (uint64_t i = 0; i < text_length; i++) {
        name[i] = text[i];
    }
    grail_windows_release(text, text_length);
    dir->current = dir->next;
    dir->current_valid = dir->next_valid;
    dir->next_valid = 0;
    return (grail_result)text_length;
}

grail_status grail_os_dir_close(grail_dir handle) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_win32_dir *dir = NULL;
    grail_windows_lock();
    const grail_status status =
        grail_handle_table_release(&grail_windows.directories, handle, (void **)&dir);
    grail_windows_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    if (dir->handle != GRAIL_INVALID_HANDLE_VALUE) {
        (void)FindClose(dir->handle);
    }
    grail_windows_release(dir, sizeof(*dir));
    return GRAIL_OK;
}

grail_status grail_os_fs_mkdir(const uint8_t *path, uint64_t path_length, uint64_t mode,
                               uint64_t flags) {
    (void)mode;
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    if (units == 0) {
        grail_windows_free_wide(wide, units);
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((flags & GRAIL_MKDIR_PARENTS) == 0) {
        const BOOL created = CreateDirectoryW(wide, NULL);
        const DWORD error = GetLastError();
        grail_windows_free_wide(wide, units);
        return created ? GRAIL_OK : grail_windows_fail(error);
    }
    for (uint64_t i = 0; i < units; i++) {
        const int separator = wide[i] == '/' || wide[i] == '\\';
        if (!separator && i + 1 != units) {
            continue;
        }
        const WCHAR saved = wide[i];
        wide[i] = 0;
        if (i > 0 && !(i == 2 && wide[1] == ':')) {
            if (!CreateDirectoryW(wide, NULL)) {
                const DWORD error = GetLastError();
                if (error != GRAIL_ERROR_ALREADY_EXISTS) {
                    wide[i] = saved;
                    grail_windows_free_wide(wide, units);
                    return grail_windows_fail(error);
                }
            }
        }
        wide[i] = saved;
    }
    grail_windows_free_wide(wide, units);
    return GRAIL_OK;
}

grail_status grail_os_fs_remove_file(const uint8_t *path, uint64_t path_length) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    const BOOL removed = DeleteFileW(wide);
    const DWORD error = GetLastError();
    grail_windows_free_wide(wide, units);
    return removed ? GRAIL_OK : grail_windows_fail(error);
}

grail_status grail_os_fs_remove_dir(const uint8_t *path, uint64_t path_length) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    const BOOL removed = RemoveDirectoryW(wide);
    const DWORD error = GetLastError();
    grail_windows_free_wide(wide, units);
    return removed ? GRAIL_OK : grail_windows_fail(error);
}

grail_status grail_os_fs_rename(const uint8_t *from, uint64_t from_length, const uint8_t *to,
                                uint64_t to_length, uint64_t flags) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    WCHAR *wide_from = NULL;
    WCHAR *wide_to = NULL;
    uint64_t from_units = 0;
    uint64_t to_units = 0;
    grail_status status = grail_windows_to_wide(from, from_length, &wide_from, &from_units);
    if (status == GRAIL_OK) {
        status = grail_windows_to_wide(to, to_length, &wide_to, &to_units);
    }
    if (status == GRAIL_OK) {
        const DWORD move_flags =
            (flags & GRAIL_RENAME_REPLACE) != 0 ? GRAIL_MOVEFILE_REPLACE_EXISTING : 0;
        if (!MoveFileExW(wide_from, wide_to, move_flags)) {
            status = grail_windows_fail(GetLastError());
        }
    }
    grail_windows_free_wide(wide_from, from_units);
    grail_windows_free_wide(wide_to, to_units);
    return status;
}
