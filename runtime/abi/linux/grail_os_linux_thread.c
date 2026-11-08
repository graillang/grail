/*
 * Linux reference backend: native threads, mutexes, condition variables and
 * dynamic library loading.  Hosted C oracle for the ABI contract.
 */
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <sched.h>
#include <string.h>
#include <time.h>

#include "grail_os_linux.h"

typedef struct grail_linux_thread {
    pthread_t id;
    grail_thread_entry entry;
    void *user;
    uint64_t result;
    pthread_mutex_t gate;
    int detached;
    int finished;
    int freed;
} grail_linux_thread;

typedef struct grail_linux_mutex {
    pthread_mutex_t value;
} grail_linux_mutex;

typedef struct grail_linux_condvar {
    pthread_cond_t value;
} grail_linux_condvar;

typedef struct grail_linux_library {
    void *handle;
} grail_linux_library;

static grail_status grail_pthread_status(int code) {
    if (code == 0) {
        return GRAIL_OK;
    }
    return grail_linux_errno(code);
}

static void grail_thread_release(grail_linux_thread *thread) {
    pthread_mutex_destroy(&thread->gate);
    grail_linux_release(thread, sizeof(*thread));
}

static void *grail_thread_trampoline(void *argument) {
    grail_linux_thread *thread = (grail_linux_thread *)argument;
    const uint64_t result = thread->entry(thread->user);
    pthread_mutex_lock(&thread->gate);
    thread->result = result;
    thread->finished = 1;
    const int release = thread->detached && !thread->freed;
    if (release) {
        thread->freed = 1;
    }
    pthread_mutex_unlock(&thread->gate);
    if (release) {
        grail_thread_release(thread);
    }
    return NULL;
}

static void grail_thread_name(const uint8_t *source, uint64_t length, char out[16]) {
    uint64_t count = length < 15 ? length : 15;
    while (count > 0 && (source[count] & 0xC0u) == 0x80u) {
        count--;
    }
    if (count != 0) {
        memcpy(out, source, (size_t)count);
    }
    out[count] = '\0';
}

grail_status grail_os_thread_spawn(grail_thread_entry entry, void *user,
                                   const grail_thread_options *options, grail_thread *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (entry == NULL || out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    uint64_t stack_size = 0;
    char name[16];
    name[0] = '\0';
    if (options != NULL) {
        if (options->struct_size < sizeof(*options) || options->abi_version != GRAIL_ABI_VERSION) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        if (options->flags != 0) {
            return GRAIL_E_UNSUPPORTED;
        }
        stack_size = options->stack_size;
        if ((options->name == NULL && options->name_length != 0) ||
            options->name_length > (uint64_t)INT64_MAX) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
        if (options->name != NULL) {
            grail_thread_name(options->name, options->name_length, name);
        }
        if (stack_size != 0 && stack_size < (uint64_t)PTHREAD_STACK_MIN) {
            return GRAIL_E_INVALID_ARGUMENT;
        }
    }
    grail_linux_thread *thread = (grail_linux_thread *)grail_linux_allocate(sizeof(*thread));
    if (thread == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    memset(thread, 0, sizeof(*thread));
    thread->entry = entry;
    thread->user = user;
    if (pthread_mutex_init(&thread->gate, NULL) != 0) {
        grail_linux_release(thread, sizeof(*thread));
        return GRAIL_E_SYSTEM;
    }
    pthread_attr_t attributes;
    if (pthread_attr_init(&attributes) != 0) {
        pthread_mutex_destroy(&thread->gate);
        grail_linux_release(thread, sizeof(*thread));
        return GRAIL_E_SYSTEM;
    }
    if (stack_size != 0) {
        (void)pthread_attr_setstacksize(&attributes, (size_t)stack_size);
    }
    const int created = pthread_create(&thread->id, &attributes, grail_thread_trampoline, thread);
    pthread_attr_destroy(&attributes);
    if (created != 0) {
        pthread_mutex_destroy(&thread->gate);
        grail_linux_release(thread, sizeof(*thread));
        return grail_pthread_status(created);
    }
    if (name[0] != '\0') {
        (void)pthread_setname_np(thread->id, name);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.threads, thread, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        pthread_mutex_lock(&thread->gate);
        thread->detached = 1;
        pthread_mutex_unlock(&thread->gate);
        (void)pthread_detach(thread->id);
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_thread_join(grail_thread handle, uint64_t *exit_code) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_thread *thread = NULL;
    grail_linux_lock();
    grail_status status =
        grail_handle_table_lookup(&grail_linux.threads, handle, (void **)&thread);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int joined = pthread_join(thread->id, NULL);
    if (joined != 0) {
        return grail_pthread_status(joined);
    }
    pthread_mutex_lock(&thread->gate);
    const uint64_t result = thread->result;
    thread->freed = 1;
    pthread_mutex_unlock(&thread->gate);
    grail_linux_lock();
    status = grail_handle_table_release(&grail_linux.threads, handle, NULL);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_thread_release(thread);
    if (exit_code != NULL) {
        *exit_code = result;
    }
    return GRAIL_OK;
}

grail_status grail_os_thread_detach(grail_thread handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_thread *thread = NULL;
    grail_linux_lock();
    grail_status status =
        grail_handle_table_release(&grail_linux.threads, handle, (void **)&thread);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int detached = pthread_detach(thread->id);
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
        grail_thread_release(thread);
    }
    return detached == 0 ? GRAIL_OK : grail_pthread_status(detached);
}

grail_status grail_os_thread_id(uint64_t *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    *out = (uint64_t)(uintptr_t)pthread_self();
    return GRAIL_OK;
}

grail_status grail_os_thread_yield(void) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (sched_yield() != 0) {
        return grail_linux_errno(errno);
    }
    return GRAIL_OK;
}

static grail_status grail_mutex_lookup(grail_mutex handle, grail_linux_mutex **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.mutexes, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

grail_status grail_os_mutex_create(grail_mutex *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_linux_mutex *mutex = (grail_linux_mutex *)grail_linux_allocate(sizeof(*mutex));
    if (mutex == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    const int initialized = pthread_mutex_init(&mutex->value, NULL);
    if (initialized != 0) {
        grail_linux_release(mutex, sizeof(*mutex));
        return grail_pthread_status(initialized);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.mutexes, mutex, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        pthread_mutex_destroy(&mutex->value);
        grail_linux_release(mutex, sizeof(*mutex));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_mutex_lock(grail_mutex handle) {
    grail_linux_mutex *mutex = NULL;
    const grail_status status = grail_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    return grail_pthread_status(pthread_mutex_lock(&mutex->value));
}

grail_status grail_os_mutex_try_lock(grail_mutex handle, uint64_t *acquired) {
    grail_linux_mutex *mutex = NULL;
    const grail_status status = grail_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    if (acquired == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    const int result = pthread_mutex_trylock(&mutex->value);
    if (result == 0) {
        *acquired = 1;
        return GRAIL_OK;
    }
    if (result == EBUSY) {
        *acquired = 0;
        return GRAIL_OK;
    }
    return grail_pthread_status(result);
}

grail_status grail_os_mutex_unlock(grail_mutex handle) {
    grail_linux_mutex *mutex = NULL;
    const grail_status status = grail_mutex_lookup(handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    return grail_pthread_status(pthread_mutex_unlock(&mutex->value));
}

grail_status grail_os_mutex_destroy(grail_mutex handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_mutex *mutex = NULL;
    grail_linux_lock();
    grail_status status =
        grail_handle_table_lookup(&grail_linux.mutexes, handle, (void **)&mutex);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int destroyed = pthread_mutex_destroy(&mutex->value);
    if (destroyed != 0) {
        return grail_pthread_status(destroyed);
    }
    grail_linux_lock();
    status = grail_handle_table_release(&grail_linux.mutexes, handle, NULL);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_linux_release(mutex, sizeof(*mutex));
    return GRAIL_OK;
}

static grail_status grail_condvar_lookup(grail_condvar handle, grail_linux_condvar **out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.condvars, handle, (void **)out);
    grail_linux_unlock();
    return status;
}

grail_status grail_os_condvar_create(grail_condvar *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_linux_condvar *condvar = (grail_linux_condvar *)grail_linux_allocate(sizeof(*condvar));
    if (condvar == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    pthread_condattr_t attributes;
    if (pthread_condattr_init(&attributes) != 0) {
        grail_linux_release(condvar, sizeof(*condvar));
        return GRAIL_E_SYSTEM;
    }
    (void)pthread_condattr_setclock(&attributes, CLOCK_MONOTONIC);
    const int initialized = pthread_cond_init(&condvar->value, &attributes);
    pthread_condattr_destroy(&attributes);
    if (initialized != 0) {
        grail_linux_release(condvar, sizeof(*condvar));
        return grail_pthread_status(initialized);
    }
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.condvars, condvar, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        pthread_cond_destroy(&condvar->value);
        grail_linux_release(condvar, sizeof(*condvar));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

static int grail_deadline(int64_t timeout_ns, struct timespec *out) {
    if (clock_gettime(CLOCK_MONOTONIC, out) != 0) {
        return 0;
    }
    if (timeout_ns < 0) {
        return 0;
    }
    out->tv_sec += (time_t)(timeout_ns / 1000000000);
    long nanoseconds = out->tv_nsec + (long)(timeout_ns % 1000000000);
    if (nanoseconds >= 1000000000) {
        out->tv_sec++;
        nanoseconds -= 1000000000;
    }
    out->tv_nsec = nanoseconds;
    return 1;
}

grail_status grail_os_condvar_wait(grail_condvar condvar_handle, grail_mutex mutex_handle,
                                   int64_t timeout_ns, uint64_t *signaled) {
    grail_linux_condvar *condvar = NULL;
    grail_status status = grail_condvar_lookup(condvar_handle, &condvar);
    if (status != GRAIL_OK) {
        return status;
    }
    grail_linux_mutex *mutex = NULL;
    status = grail_mutex_lookup(mutex_handle, &mutex);
    if (status != GRAIL_OK) {
        return status;
    }
    if (signaled == NULL) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    int result;
    if (timeout_ns < 0) {
        result = pthread_cond_wait(&condvar->value, &mutex->value);
    } else {
        struct timespec deadline;
        if (!grail_deadline(timeout_ns, &deadline)) {
            return grail_linux_errno(errno);
        }
        result = pthread_cond_timedwait(&condvar->value, &mutex->value, &deadline);
    }
    if (result == 0) {
        *signaled = 1;
        return GRAIL_OK;
    }
    if (result == ETIMEDOUT) {
        *signaled = 0;
        return GRAIL_OK;
    }
    return grail_pthread_status(result);
}

grail_status grail_os_condvar_signal(grail_condvar handle) {
    grail_linux_condvar *condvar = NULL;
    const grail_status status = grail_condvar_lookup(handle, &condvar);
    if (status != GRAIL_OK) {
        return status;
    }
    return grail_pthread_status(pthread_cond_signal(&condvar->value));
}

grail_status grail_os_condvar_broadcast(grail_condvar handle) {
    grail_linux_condvar *condvar = NULL;
    const grail_status status = grail_condvar_lookup(handle, &condvar);
    if (status != GRAIL_OK) {
        return status;
    }
    return grail_pthread_status(pthread_cond_broadcast(&condvar->value));
}

grail_status grail_os_condvar_destroy(grail_condvar handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_condvar *condvar = NULL;
    grail_linux_lock();
    grail_status status =
        grail_handle_table_lookup(&grail_linux.condvars, handle, (void **)&condvar);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int destroyed = pthread_cond_destroy(&condvar->value);
    if (destroyed != 0) {
        return grail_pthread_status(destroyed);
    }
    grail_linux_lock();
    status = grail_handle_table_release(&grail_linux.condvars, handle, NULL);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    grail_linux_release(condvar, sizeof(*condvar));
    return GRAIL_OK;
}

static void grail_loader_error(void) {
    const char *message = dlerror();
    if (message == NULL) {
        grail_linux_loader_error[0] = '\0';
        return;
    }
    uint64_t length = strlen(message);
    if (length >= sizeof(grail_linux_loader_error)) {
        length = sizeof(grail_linux_loader_error) - 1;
    }
    memcpy(grail_linux_loader_error, message, (size_t)length);
    grail_linux_loader_error[length] = '\0';
}

grail_status grail_os_dl_open(const uint8_t *name, uint64_t name_length, uint64_t flags,
                              grail_library *out) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (out == NULL || (name == NULL && name_length != 0)) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    char *text = NULL;
    if (name_length != 0) {
        text = grail_linux_copy_text(name, name_length);
        if (text == NULL) {
            return GRAIL_E_OUT_OF_MEMORY;
        }
    }
    int mode = (flags & GRAIL_DL_LAZY) != 0 ? RTLD_LAZY : RTLD_NOW;
    mode |= (flags & GRAIL_DL_GLOBAL) != 0 ? RTLD_GLOBAL : RTLD_LOCAL;
    (void)dlerror();
    void *library_handle = dlopen(text, mode);
    grail_loader_error();
    grail_linux_free_text(text);
    if (library_handle == NULL) {
        return GRAIL_E_NOT_FOUND;
    }
    grail_linux_library *library = (grail_linux_library *)grail_linux_allocate(sizeof(*library));
    if (library == NULL) {
        (void)dlclose(library_handle);
        return GRAIL_E_OUT_OF_MEMORY;
    }
    library->handle = library_handle;
    grail_handle handle = GRAIL_HANDLE_NONE;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_allocate(&grail_linux.libraries, library, &handle);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        (void)dlclose(library_handle);
        grail_linux_release(library, sizeof(*library));
        return status;
    }
    *out = handle;
    return GRAIL_OK;
}

grail_status grail_os_dl_symbol(grail_library handle, const uint8_t *name, uint64_t name_length,
                                void **symbol) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    if (symbol == NULL || name == NULL || name_length == 0) {
        return GRAIL_E_INVALID_ARGUMENT;
    }
    grail_linux_library *library = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_lookup(&grail_linux.libraries, handle, (void **)&library);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    char *text = grail_linux_copy_text(name, name_length);
    if (text == NULL) {
        return GRAIL_E_OUT_OF_MEMORY;
    }
    (void)dlerror();
    void *address = dlsym(library->handle, text);
    grail_loader_error();
    grail_linux_free_text(text);
    if (address == NULL && grail_linux_loader_error[0] != '\0') {
        return GRAIL_E_NOT_FOUND;
    }
    *symbol = address;
    return GRAIL_OK;
}

grail_status grail_os_dl_close(grail_library handle) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    grail_linux_library *library = NULL;
    grail_linux_lock();
    const grail_status status =
        grail_handle_table_release(&grail_linux.libraries, handle, (void **)&library);
    grail_linux_unlock();
    if (status != GRAIL_OK) {
        return status;
    }
    const int result = dlclose(library->handle);
    grail_loader_error();
    grail_linux_release(library, sizeof(*library));
    return result == 0 ? GRAIL_OK : GRAIL_E_SYSTEM;
}

grail_result grail_os_dl_error(uint8_t *out, uint64_t capacity) {
    if (!grail_linux.initialized) {
        return GRAIL_E_NOT_INITIALIZED;
    }
    return grail_abi_copy_out((const uint8_t *)grail_linux_loader_error,
                              strlen(grail_linux_loader_error), out, capacity);
}
