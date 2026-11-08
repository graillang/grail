#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

/*
 * Linux reference backend: initialization, environment, time and process paths.
 *
 * Hosted C oracle for the ABI contract; see runtime/abi/README.md.
 */
#include <errno.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "grail_os_linux.h"

grail_linux_state grail_linux = {
    {0, NULL, NULL, NULL, NULL},
    0,
    0,
    PTHREAD_MUTEX_INITIALIZER,
    {NULL, NULL, 0, 0, 0},
    {NULL, NULL, 0, 0, 0},
    {NULL, NULL, 0, 0, 0},
    {NULL, NULL, 0, 0, 0},
    {NULL, NULL, 0, 0, 0},
    {NULL, NULL, 0, 0, 0},
    {NULL, NULL, 0, 0, 0},
    NULL,
    NULL,
    0,
    0,
};

static _Thread_local grail_os_error grail_linux_last_error = {GRAIL_OS_DOMAIN_NONE, 0};
_Thread_local char grail_linux_loader_error[512];

void grail_linux_set_error(uint64_t domain, uint64_t code) {
    grail_linux_last_error.domain = domain;
    grail_linux_last_error.code = code;
}

grail_status grail_linux_errno(int error_number) {
    grail_linux_set_error(GRAIL_OS_DOMAIN_ERRNO, (uint64_t)(int64_t)error_number);
    return grail_os_status_from_errno(error_number);
}

void *grail_linux_allocate(uint64_t size) {
    if (size == 0) {
        size = 1;
    }
    return grail_linux.allocator.allocate(grail_linux.allocator.context, size, 8);
}

void grail_linux_release(void *pointer, uint64_t size) {
    if (pointer != NULL) {
        grail_linux.allocator.release(grail_linux.allocator.context, pointer, size, 8);
    }
}

char *grail_linux_copy_text(const uint8_t *bytes, uint64_t length) {
    if (length > (uint64_t)INT64_MAX || (bytes == NULL && length != 0)) {
        return NULL;
    }
    char *text = (char *)grail_linux_allocate(length + 1);
    if (text == NULL) {
        return NULL;
    }
    if (length != 0) {
        memcpy(text, bytes, (size_t)length);
    }
    text[length] = '\0';
    return text;
}

void grail_linux_free_text(char *text) {
    if (text != NULL) {
        grail_linux_release(text, strlen(text) + 1);
    }
}

int grail_linux_native_setenv(const char *name, const char *value) {
    return setenv(name, value, 1);
}

void grail_linux_native_unsetenv(const char *name) {
    (void)unsetenv(name);
}

static int grail_text_has_zero(const uint8_t *bytes, uint64_t length) {
    for (uint64_t i = 0; i < length; i++) {
        if (bytes[i] == 0) {
            return 1;
        }
    }
    return 0;
}

static int grail_env_name_valid(const uint8_t *name, uint64_t length) {
    if (name == NULL || length == 0 || grail_text_has_zero(name, length)) {
        return 0;
    }
    for (uint64_t i = 0; i < length; i++) {
        if (name[i] == '=') {
            return 0;
        }
    }
    return 1;
}

static uint64_t grail_env_find(const char *name) {
    for (uint64_t i = 0; i < grail_linux.env_count; i++) {
        if (strcmp(grail_linux.env_names[i], name) == 0) {
            return i;
        }
    }
    return grail_linux.env_count;
}

static int grail_env_reserve(uint64_t capacity) {
    if (capacity <= grail_linux.env_capacity) {
        return 1;
    }
    uint64_t next = grail_linux.env_capacity == 0 ? 8 : grail_linux.env_capacity * 2;
    while (next < capacity) {
        next *= 2;
    }
    char **names = (char **)grail_linux_allocate(next * sizeof(char *));
    char **values = (char **)grail_linux_allocate(next * sizeof(char *));
    if (names == NULL || values == NULL) {
        grail_linux_release(names, next * sizeof(char *));
        grail_linux_release(values, next * sizeof(char *));
        return 0;
    }
    for (uint64_t i = 0; i < grail_linux.env_count; i++) {
        names[i] = grail_linux.env_names[i];
        values[i] = grail_linux.env_values[i];
    }
    if (grail_linux.env_names != NULL) {
        grail_linux_release(grail_linux.env_names, grail_linux.env_capacity * sizeof(char *));
        grail_linux_release(grail_linux.env_values, grail_linux.env_capacity * sizeof(char *));
    }
    grail_linux.env_names = names;
    grail_linux.env_values = values;
    grail_linux.env_capacity = next;
    return 1;
}

static grail_status grail_env_insert(const char *name, const char *value) {
    const uint64_t index = grail_env_find(name);
    char *name_copy = NULL;
    char *value_copy = NULL;
    if (index == grail_linux.env_count) {
        if (!grail_env_reserve(grail_linux.env_count + 1)) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        name_copy = grail_linux_copy_text((const uint8_t *)name, strlen(name));
        if (name_copy == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        grail_linux.env_names[grail_linux.env_count] = name_copy;
        grail_linux.env_values[grail_linux.env_count] = NULL;
        grail_linux.env_count++;
    }
    value_copy = grail_linux_copy_text((const uint8_t *)value, strlen(value));
    if (value_copy == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    const uint64_t slot = grail_env_find(name);
    char *old = grail_linux.env_values[slot];
    grail_linux.env_values[slot] = value_copy;
    if (old != NULL) {
        grail_linux_free_text(old);
    }
    return GRAIL_OK;
}

static grail_status grail_env_seed(const grail_startup *startup) {
    if (startup == NULL) {
        return GRAIL_OK;
    }
    if (startup->struct_size < sizeof(grail_startup) || startup->abi_version != GRAIL_ABI_VERSION) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if ((startup->environment == NULL && startup->environment_length != 0) ||
        (startup->environment_offsets == NULL && startup->environment_count != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    for (uint64_t i = 0; i < startup->environment_count; i++) {
        const uint64_t begin = startup->environment_offsets[i];
        const uint64_t end = i + 1 < startup->environment_count
                                 ? startup->environment_offsets[i + 1]
                                 : startup->environment_length;
        if (end > startup->environment_length || begin >= end) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        const uint8_t *entry = startup->environment + begin;
        const uint64_t size = end - begin;
        if (entry[size - 1] != 0 || grail_text_has_zero(entry, size - 1)) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        uint64_t separator = 0;
        while (separator < size - 1 && entry[separator] != '=') {
            separator++;
        }
        if (separator == 0 || separator == size - 1) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        char *name = grail_linux_copy_text(entry, separator);
        char *value = grail_linux_copy_text(entry + separator + 1, size - separator - 2);
        if (name == NULL || value == NULL) {
            grail_linux_free_text(name);
            grail_linux_free_text(value);
            return GRAIL_E_OUT_OF_MEMORY;
        }
        const grail_status inserted = grail_env_insert(name, value);
        grail_linux_free_text(name);
        grail_linux_free_text(value);
        if (inserted != GRAIL_OK) {
            return inserted;
        }
    }
    return GRAIL_OK;
}

static void grail_env_clear(void) {
    for (uint64_t i = 0; i < grail_linux.env_count; i++) {
        grail_linux_free_text(grail_linux.env_names[i]);
        grail_linux_free_text(grail_linux.env_values[i]);
    }
    if (grail_linux.env_names != NULL) {
        grail_linux_release(grail_linux.env_names, grail_linux.env_capacity * sizeof(char *));
        grail_linux_release(grail_linux.env_values, grail_linux.env_capacity * sizeof(char *));
    }
    grail_linux.env_names = NULL;
    grail_linux.env_values = NULL;
    grail_linux.env_count = 0;
    grail_linux.env_capacity = 0;
}

grail_status grail_os_init(const grail_allocator *allocator, const grail_startup *startup) {
    if (allocator == NULL || allocator->allocate == NULL || allocator->release == NULL ||
        allocator->struct_size < sizeof(grail_allocator)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (grail_linux.initialized) {
        return GRAIL_E_UNSUPPORTED;
    }
    grail_linux.allocator = *allocator;
    grail_linux.capabilities = 0;
    grail_status status = GRAIL_OK;
    const uint64_t kinds[] = {GRAIL_HANDLE_KIND_FILE, GRAIL_HANDLE_KIND_DIR,
                              GRAIL_HANDLE_KIND_ENV_ITER, GRAIL_HANDLE_KIND_THREAD,
                              GRAIL_HANDLE_KIND_MUTEX, GRAIL_HANDLE_KIND_CONDVAR,
                              GRAIL_HANDLE_KIND_LIBRARY};
    grail_handle_table *tables[] = {&grail_linux.files, &grail_linux.directories,
                                    &grail_linux.env_iterators, &grail_linux.threads,
                                    &grail_linux.mutexes, &grail_linux.condvars,
                                    &grail_linux.libraries};
    for (uint64_t i = 0; i < sizeof(tables) / sizeof(tables[0]) && status == GRAIL_OK; i++) {
        status = grail_handle_table_init(tables[i], &grail_linux.allocator, kinds[i]);
    }
    if (status == GRAIL_OK) {
        status = grail_env_seed(startup);
    }
    if (status != GRAIL_OK) {
        for (uint64_t i = 0; i < sizeof(tables) / sizeof(tables[0]); i++) {
            grail_handle_table_destroy(tables[i]);
        }
        grail_env_clear();
        return status;
    }
    grail_linux.capabilities = GRAIL_CAP_FILES | GRAIL_CAP_DIRECTORIES | GRAIL_CAP_PATHS |
                               GRAIL_CAP_UNICODE | GRAIL_CAP_ENVIRONMENT |
                               GRAIL_CAP_ENV_MUTATION | GRAIL_CAP_TIME |
                               GRAIL_CAP_LOCAL_TIME_OFFSET | GRAIL_CAP_CPU_TIME | GRAIL_CAP_THREADS |
                               GRAIL_CAP_SYNC_PRIMITIVES | GRAIL_CAP_DYNAMIC_LIBRARIES |
                               GRAIL_CAP_SYMLINKS;
    grail_linux.initialized = 1;
    return GRAIL_OK;
}

grail_status grail_os_shutdown(void) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_handle_table_destroy(&grail_linux.files);
    grail_handle_table_destroy(&grail_linux.directories);
    grail_handle_table_destroy(&grail_linux.env_iterators);
    grail_handle_table_destroy(&grail_linux.threads);
    grail_handle_table_destroy(&grail_linux.mutexes);
    grail_handle_table_destroy(&grail_linux.condvars);
    grail_handle_table_destroy(&grail_linux.libraries);
    grail_env_clear();
    grail_linux.capabilities = 0;
    grail_linux.initialized = 0;
    return GRAIL_OK;
}

uint64_t grail_os_capabilities(void) {
    return grail_linux.initialized ? grail_linux.capabilities : 0;
}

grail_status grail_os_error_last(grail_os_error *out) {
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *out = grail_linux_last_error;
    return GRAIL_OK;
}

grail_result grail_os_env_get(const uint8_t *name, uint64_t name_length, uint8_t *out,
                              uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (!grail_env_name_valid(name, name_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_linux_copy_text(name, name_length);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    grail_linux_lock();
    const uint64_t index = grail_env_find(text);
    grail_result result;
    if (index == grail_linux.env_count) {
        result = GRAIL_E_NOT_FOUND;
    } else {
        result = grail_abi_copy_out((const uint8_t *)grail_linux.env_values[index],
                                    strlen(grail_linux.env_values[index]), out, capacity);
    }
    grail_linux_unlock();
    grail_linux_free_text(text);
    return result;
}

grail_status grail_os_env_set(const uint8_t *name, uint64_t name_length, const uint8_t *value,
                              uint64_t value_length) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (!grail_env_name_valid(name, name_length) ||
        (value == NULL && value_length != 0) || grail_text_has_zero(value, value_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *name_text = grail_linux_copy_text(name, name_length);
    char *value_text = grail_linux_copy_text(value, value_length);
    if (name_text == NULL || value_text == NULL) {
        grail_linux_free_text(name_text);
        grail_linux_free_text(value_text);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    if (grail_linux_native_setenv(name_text, value_text) != 0) {
        const int error_number = errno;
        grail_linux_free_text(name_text);
        grail_linux_free_text(value_text);
        return grail_linux_errno(error_number);
    }
    grail_linux_lock();
    const grail_status status = grail_env_insert(name_text, value_text);
    grail_linux_unlock();
    grail_linux_free_text(name_text);
    grail_linux_free_text(value_text);
    return status;
}

grail_status grail_os_env_unset(const uint8_t *name, uint64_t name_length) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (!grail_env_name_valid(name, name_length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_linux_copy_text(name, name_length);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    grail_linux_native_unsetenv(text);
    grail_linux_lock();
    const uint64_t index = grail_env_find(text);
    if (index < grail_linux.env_count) {
        grail_linux_free_text(grail_linux.env_names[index]);
        grail_linux_free_text(grail_linux.env_values[index]);
        for (uint64_t i = index + 1; i < grail_linux.env_count; i++) {
            grail_linux.env_names[i - 1] = grail_linux.env_names[i];
            grail_linux.env_values[i - 1] = grail_linux.env_values[i];
        }
        grail_linux.env_count--;
    }
    grail_linux_unlock();
    grail_linux_free_text(text);
    return GRAIL_OK;
}

typedef struct grail_linux_env_iterator {
    char **names;
    char **values;
    uint64_t count;
    uint64_t capacity;
    int64_t index;
} grail_linux_env_iterator;

static void grail_env_iterator_free(grail_linux_env_iterator *iterator) {
    if (iterator == NULL) {
        return;
    }
    for (uint64_t i = 0; i < iterator->count; i++) {
        grail_linux_free_text(iterator->names[i]);
        grail_linux_free_text(iterator->values[i]);
    }
    if (iterator->names != NULL) {
        grail_linux_release(iterator->names, iterator->capacity * sizeof(char *));
        grail_linux_release(iterator->values, iterator->capacity * sizeof(char *));
    }
    grail_linux_release(iterator, sizeof(*iterator));
}

grail_status grail_os_env_iter_open(grail_env_iter *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_linux_env_iterator *iterator =
        (grail_linux_env_iterator *)grail_linux_allocate(sizeof(*iterator));
    if (iterator == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    memset(iterator, 0, sizeof(*iterator));
    iterator->index = -1;
    grail_linux_lock();
    if (grail_linux.env_count != 0) {
        iterator->names = (char **)grail_linux_allocate(grail_linux.env_count * sizeof(char *));
        iterator->values = (char **)grail_linux_allocate(grail_linux.env_count * sizeof(char *));
        if (iterator->names == NULL || iterator->values == NULL) {
            grail_linux_unlock();
            grail_env_iterator_free(iterator);
            return GRAIL_E_OUT_OF_MEMORY;
        }
        iterator->capacity = grail_linux.env_count;
        for (uint64_t i = 0; i < grail_linux.env_count; i++) {
            iterator->names[i] =
                grail_linux_copy_text((const uint8_t *)grail_linux.env_names[i],
                                      strlen(grail_linux.env_names[i]));
            if (iterator->names[i] == NULL) {
                iterator->count = i;
                grail_linux_unlock();
                grail_env_iterator_free(iterator);
                return GRAIL_E_OUT_OF_MEMORY;
            }
            iterator->values[i] =
                grail_linux_copy_text((const uint8_t *)grail_linux.env_values[i],
                                      strlen(grail_linux.env_values[i]));
            iterator->count = i + 1;
            if (iterator->values[i] == NULL) {
                grail_linux_unlock();
                grail_env_iterator_free(iterator);
                return GRAIL_E_OUT_OF_MEMORY;
            }
        }
    }
    grail_linux_unlock();
    grail_handle handle = GRAIL_HANDLE_NONE;
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.env_iterators, iterator, &handle);
    if (status != GRAIL_OK) {
        grail_env_iterator_free(iterator);
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static grail_status grail_env_iterator_lookup(grail_env_iter handle,
                                              grail_linux_env_iterator **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.env_iterators, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

grail_status grail_os_env_iter_next(grail_env_iter handle, uint64_t *is_last) {
    grail_linux_env_iterator *iterator = NULL;
    const grail_status status = grail_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) {
        return status;
    }
    if (is_last == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    if (iterator->index + 1 >= (int64_t)iterator->count) {
        iterator->index = (int64_t)iterator->count;
        *is_last = 1;
        return GRAIL_OK;
    }
    iterator->index++;
    *is_last = 0;
    return GRAIL_OK;
}

grail_result grail_os_env_iter_name(grail_env_iter handle, uint8_t *out, uint64_t capacity) {
    grail_linux_env_iterator *iterator = NULL;
    const grail_status status = grail_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) {
        return status;
    }
    if (iterator->index < 0 || iterator->index >= (int64_t)iterator->count) {
        return GRAIL_E_NOT_FOUND;
    }
    return grail_abi_copy_out((const uint8_t *)iterator->names[iterator->index],
                              strlen(iterator->names[iterator->index]), out, capacity);
}

grail_result grail_os_env_iter_value(grail_env_iter handle, uint8_t *out, uint64_t capacity) {
    grail_linux_env_iterator *iterator = NULL;
    const grail_status status = grail_env_iterator_lookup(handle, &iterator);
    if (status != GRAIL_OK) {
        return status;
    }
    if (iterator->index < 0 || iterator->index >= (int64_t)iterator->count) {
        return GRAIL_E_NOT_FOUND;
    }
    return grail_abi_copy_out((const uint8_t *)iterator->values[iterator->index],
                              strlen(iterator->values[iterator->index]), out, capacity);
}

grail_status grail_os_env_iter_close(grail_env_iter handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_env_iterator *iterator = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_release(&grail_linux.env_iterators, handle, (void **)&iterator);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_env_iterator_free(iterator);
    return GRAIL_OK;
}

static int grail_clock_id(uint64_t clock, clockid_t *out) {
    switch (clock) {
    case GRAIL_CLOCK_MONOTONIC:
        *out = CLOCK_MONOTONIC;
        return 1;
    case GRAIL_CLOCK_REALTIME:
        *out = CLOCK_REALTIME;
        return 1;
    case GRAIL_CLOCK_PROCESS_CPU:
        *out = CLOCK_PROCESS_CPUTIME_ID;
        return 1;
    case GRAIL_CLOCK_THREAD_CPU:
        *out = CLOCK_THREAD_CPUTIME_ID;
        return 1;
    default:
        return 0;
    }
}

grail_status grail_os_time_now(uint64_t clock, int64_t *nanoseconds) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    clockid_t identifier;
    if (nanoseconds == NULL || !grail_clock_id(clock, &identifier)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct timespec value;
    if (clock_gettime(identifier, &value) != 0) {
        return grail_linux_errno(errno);
    }
    if (value.tv_sec > (time_t)(INT64_MAX / 1000000000)) {
        return GRAIL_E_OVERFLOW;
    }
    *nanoseconds = (int64_t)value.tv_sec * 1000000000 + value.tv_nsec;
    return GRAIL_OK;
}

grail_status grail_os_time_resolution(uint64_t clock, int64_t *nanoseconds) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    clockid_t identifier;
    if (nanoseconds == NULL || !grail_clock_id(clock, &identifier)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct timespec value;
    if (clock_getres(identifier, &value) != 0) {
        return grail_linux_errno(errno);
    }
    *nanoseconds = (int64_t)value.tv_sec * 1000000000 + value.tv_nsec;
    return GRAIL_OK;
}

grail_status grail_os_time_sleep(int64_t nanoseconds, int64_t *remaining_nanoseconds) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (nanoseconds < 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    struct timespec request;
    request.tv_sec = (time_t)(nanoseconds / 1000000000);
    request.tv_nsec = (long)(nanoseconds % 1000000000);
    struct timespec remainder;
    while (nanosleep(&request, &remainder) != 0) {
        if (errno == EINTR) {
            if (remaining_nanoseconds != NULL) {
                *remaining_nanoseconds =
                    (int64_t)remainder.tv_sec * 1000000000 + remainder.tv_nsec;
            }
            return grail_linux_errno(EINTR);
        }
        return grail_linux_errno(errno);
    }
    if (remaining_nanoseconds != NULL) {
        *remaining_nanoseconds = 0;
    }
    return GRAIL_OK;
}

grail_status grail_os_time_local_offset(int64_t utc_nanoseconds, int64_t *offset_nanoseconds) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (offset_nanoseconds == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    time_t seconds = (time_t)(utc_nanoseconds / 1000000000);
    struct tm broken_down;
    if (localtime_r(&seconds, &broken_down) == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *offset_nanoseconds = (int64_t)broken_down.tm_gmtoff * 1000000000;
    return GRAIL_OK;
}

grail_result grail_os_path_current_directory(uint8_t *out, uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    uint64_t size = 256;
    while (size <= 1048576) {
        char *buffer = (char *)grail_linux_allocate(size);
        if (buffer == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        if (getcwd(buffer, (size_t)size) != NULL) {
            const grail_result result =
                grail_abi_copy_out((const uint8_t *)buffer, strlen(buffer), out, capacity);
            grail_linux_release(buffer, size);
            return result;
        }
        const int error_number = errno;
        grail_linux_release(buffer, size);
        if (error_number != ERANGE) {
            return grail_linux_errno(error_number);
        }
        size *= 2;
    }
    return GRAIL_E_NAME_TOO_LONG;
}

grail_status grail_os_path_set_current_directory(const uint8_t *path, uint64_t length) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (path == NULL || grail_text_has_zero(path, length)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = grail_linux_copy_text(path, length);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    const int result = chdir(text);
    const int error_number = errno;
    grail_linux_free_text(text);
    return result == 0 ? GRAIL_OK : grail_linux_errno(error_number);
}

grail_result grail_os_path_executable(uint8_t *out, uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    uint64_t size = 256;
    while (size <= 1048576) {
        char *buffer = (char *)grail_linux_allocate(size);
        if (buffer == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
        const ssize_t length = readlink("/proc/self/exe", buffer, (size_t)size - 1);
        if (length >= 0) {
            buffer[length] = '\0';
            const grail_result result =
                grail_abi_copy_out((const uint8_t *)buffer, (uint64_t)length, out, capacity);
            grail_linux_release(buffer, size);
            return result;
        }
        const int error_number = errno;
        grail_linux_release(buffer, size);
        if (error_number != ENAMETOOLONG) {
            return grail_linux_errno(error_number);
        }
        size *= 2;
    }
    return GRAIL_E_NAME_TOO_LONG;
}
