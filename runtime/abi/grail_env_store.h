/*
 * Shared in-memory environment store for native backends.
 *
 * The store owns UTF-8 copies of names and values and never touches the host
 * environment itself.  Backends seed it from grail_startup and propagate
 * mutations to their native environment separately.  It performs no locking;
 * the backend serialises access.
 */
#ifndef GRAIL_ENV_STORE_H
#define GRAIL_ENV_STORE_H

#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_error.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct grail_env_store {
    const grail_allocator *allocator;
    char **names;
    char **values;
    uint64_t count;
    uint64_t capacity;
} grail_env_store;

typedef struct grail_env_snapshot {
    const grail_allocator *allocator;
    char **names;
    char **values;
    uint64_t count;
    uint64_t capacity;
} grail_env_snapshot;

grail_status grail_env_store_init(grail_env_store *store, const grail_allocator *allocator);
void grail_env_store_free(grail_env_store *store);
grail_status grail_env_store_seed(grail_env_store *store, const grail_startup *startup);
grail_status grail_env_store_get(const grail_env_store *store, const uint8_t *name,
                                 uint64_t name_length, const char **value,
                                 uint64_t *value_length);
grail_status grail_env_store_set(grail_env_store *store, const uint8_t *name,
                                 uint64_t name_length, const uint8_t *value,
                                 uint64_t value_length);
grail_status grail_env_store_unset(grail_env_store *store, const uint8_t *name,
                                   uint64_t name_length);
uint64_t grail_env_store_count(const grail_env_store *store);
grail_status grail_env_store_at(const grail_env_store *store, uint64_t index, const char **name,
                                uint64_t *name_length, const char **value,
                                uint64_t *value_length);
grail_status grail_env_snapshot_take(const grail_env_store *store, grail_env_snapshot *snapshot);
void grail_env_snapshot_free(grail_env_snapshot *snapshot);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_ENV_STORE_H */
