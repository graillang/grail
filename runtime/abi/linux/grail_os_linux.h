/*
 * Linux reference backend shared state.
 *
 * This is a hosted C implementation used as a behavioural oracle for the
 * contract.  It is NOT linked into Grail programs and is not the shipping
 * runtime; the shipping Linux runtime stays in compiler/runtime.grl.
 */
#ifndef GRAIL_OS_LINUX_H
#define GRAIL_OS_LINUX_H

#include <pthread.h>
#include <stdint.h>

#include "../../../include/grail/grail_abi.h"
#include "../../../include/grail/grail_dl.h"
#include "../../../include/grail/grail_env.h"
#include "../../../include/grail/grail_error.h"
#include "../../../include/grail/grail_fs.h"
#include "../../../include/grail/grail_path.h"
#include "../../../include/grail/grail_thread.h"
#include "../../../include/grail/grail_time.h"
#include "../grail_handle_table.h"
#include "../grail_internal.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct grail_linux_state {
    grail_allocator allocator;
    uint64_t capabilities;
    int initialized;
    pthread_mutex_t lock;
    grail_handle_table files;
    grail_handle_table directories;
    grail_handle_table env_iterators;
    grail_handle_table threads;
    grail_handle_table mutexes;
    grail_handle_table condvars;
    grail_handle_table libraries;
    char **env_names;
    char **env_values;
    uint64_t env_count;
    uint64_t env_capacity;
} grail_linux_state;

extern grail_linux_state grail_linux;
extern _Thread_local char grail_linux_loader_error[512];

void *grail_linux_allocate(uint64_t size);
void grail_linux_release(void *pointer, uint64_t size);
char *grail_linux_copy_text(const uint8_t *bytes, uint64_t length);
void grail_linux_free_text(char *text);
void grail_linux_set_error(uint64_t domain, uint64_t code);
grail_status grail_linux_errno(int error_number);

/* Registers the native environment propagation hook for one entry. */
int grail_linux_native_setenv(const char *name, const char *value);
void grail_linux_native_unsetenv(const char *name);

static inline void grail_linux_lock(void) {
    pthread_mutex_lock(&grail_linux.lock);
}

static inline void grail_linux_unlock(void) {
    pthread_mutex_unlock(&grail_linux.lock);
}

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_OS_LINUX_H */
