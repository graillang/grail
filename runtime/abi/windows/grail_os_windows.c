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

typedef struct grail_win32_env_iterator {
    grail_env_snapshot snapshot;
    int64_t index;
} grail_win32_env_iterator;

typedef struct grail_win32_state {
    grail_allocator allocator;
    grail_handle_table files;
    grail_handle_table env_iterators;
    grail_env_store env;
    SRWLOCK lock;
    uint64_t capabilities;
    int initialized;
} grail_win32_state;

static grail_win32_state grail_windows = {{0, NULL, NULL, NULL, NULL},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, 0, 0, 0},
                                          {NULL, NULL, NULL, 0, 0},
                                          {NULL},
                                          0,
                                          0};
static _Thread_local grail_os_error grail_windows_error = {GRAIL_OS_DOMAIN_NONE, 0};

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
        status = grail_handle_table_init(&grail_windows.env_iterators, &grail_windows.allocator,
                                         GRAIL_HANDLE_KIND_ENV_ITER);
    }
    if (status == GRAIL_OK) {
        status = grail_env_store_init(&grail_windows.env, &grail_windows.allocator);
    }
    if (status == GRAIL_OK) {
        status = grail_env_store_seed(&grail_windows.env, startup);
    }
    if (status != GRAIL_OK) {
        grail_handle_table_destroy(&grail_windows.files);
        grail_handle_table_destroy(&grail_windows.env_iterators);
        grail_env_store_free(&grail_windows.env);
        return status;
    }
    grail_windows.capabilities = GRAIL_CAP_FILES | GRAIL_CAP_FILE_METADATA | GRAIL_CAP_PATHS |
                                 GRAIL_CAP_UNICODE | GRAIL_CAP_ENVIRONMENT |
                                 GRAIL_CAP_ENV_MUTATION | GRAIL_CAP_TIME | GRAIL_CAP_CPU_TIME;
    grail_windows.initialized = 1;
    return GRAIL_OK;
}

grail_status grail_os_shutdown(void) {
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_handle_table_destroy(&grail_windows.files);
    grail_handle_table_destroy(&grail_windows.env_iterators);
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

grail_status grail_os_env_get(const uint8_t *name, uint64_t name_length, uint8_t *out,
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

grail_status grail_os_fs_mkdir(const uint8_t *path, uint64_t path_length, uint64_t mode,
                               uint64_t flags) {
    (void)mode;
    if (!grail_windows.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if ((flags & GRAIL_MKDIR_PARENTS) != 0) {
        return GRAIL_E_UNSUPPORTED;
    }
    WCHAR *wide = NULL;
    uint64_t units = 0;
    grail_status status = grail_windows_to_wide(path, path_length, &wide, &units);
    if (status != GRAIL_OK) {
        return status;
    }
    const BOOL created = CreateDirectoryW(wide, NULL);
    const DWORD error = GetLastError();
    grail_windows_free_wide(wide, units);
    return created ? GRAIL_OK : grail_windows_fail(error);
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
