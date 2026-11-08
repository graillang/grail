/*
 * Internal generation-checked handle table shared by reference backends.
 * Handles are opaque to callers: 24-bit slot index, 8-bit kind tag and 32-bit
 * generation.  A released slot increments its generation, so a stale handle is
 * rejected instead of naming a reused resource.  The table is not internally
 * synchronized; the caller provides a lock.
 */
#ifndef GRAIL_HANDLE_TABLE_H
#define GRAIL_HANDLE_TABLE_H

#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GRAIL_HANDLE_KIND_FILE 1u
#define GRAIL_HANDLE_KIND_DIR 2u
#define GRAIL_HANDLE_KIND_ENV_ITER 3u
#define GRAIL_HANDLE_KIND_THREAD 4u
#define GRAIL_HANDLE_KIND_MUTEX 5u
#define GRAIL_HANDLE_KIND_CONDVAR 6u
#define GRAIL_HANDLE_KIND_LIBRARY 7u
#define GRAIL_HANDLE_KIND_PROCESS 8u
#define GRAIL_HANDLE_KIND_SOCKET 9u

#define GRAIL_HANDLE_MAX_SLOTS 0xFFFFFFu

typedef struct grail_handle_slot {
    void *object;
    uint64_t generation;
} grail_handle_slot;

typedef struct grail_handle_table {
    const grail_allocator *allocator;
    grail_handle_slot *slots;
    uint64_t count;
    uint64_t capacity;
    uint64_t kind;
} grail_handle_table;

grail_status grail_handle_table_init(grail_handle_table *table, const grail_allocator *allocator,
                                     uint64_t kind);
void grail_handle_table_destroy(grail_handle_table *table);
grail_status grail_handle_table_allocate(grail_handle_table *table, void *object,
                                         grail_handle *out);
grail_status grail_handle_table_lookup(grail_handle_table *table, grail_handle handle,
                                       void **object);
grail_status grail_handle_table_release(grail_handle_table *table, grail_handle handle,
                                        void **object);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_HANDLE_TABLE_H */
