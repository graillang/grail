/* grail_internal.h - shared implementation detail. Not part of the ABI; nothing outside
 * graphics/src/ may include it. */
#ifndef GRAIL_INTERNAL_H
#define GRAIL_INTERNAL_H

#include "../include/grail/grail_abi.h"
#include "../include/grail/grail_rhi.h"
#include "../include/grail/grail_shader.h"

#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------------------------------
 * Object table.
 *
 * One process-wide table maps the index in a handle to a slot. A slot stores the generation
 * it is currently on, so a handle from before a slot was reused fails
 * gr_object_lookup() instead of addressing a different object. This is the mechanism that
 * makes "a stale handle is refused, not dereferenced" true rather than aspirational.
 *
 * A fixed array is deliberate: the count of live GPU objects is bounded by the bindless
 * capacities, and an implementation that allocates the table itself would need an allocator
 * on the hot path (create/destroy) before it needs anything else. 8192 covers the null
 * backend's tests and a real device's object count with room to spare.
 * --------------------------------------------------------------------------------------- */
#define GR_OBJECT_MAX 8192u

typedef struct gr_object_slot {
    void *object;          /* NULL when free */
    uint32_t generation;   /* valid while free and while live */
    uint32_t type;         /* gr_handle_type */
    uint32_t live;
    uint32_t next_free;    /* free list link */
} gr_object_slot;

typedef struct gr_object_table {
    gr_object_slot slots[GR_OBJECT_MAX];
    uint32_t free_head;    /* GR_OBJECT_MAX when the table is full */
    uint32_t live_count;
} gr_object_table;

void gr_object_table_init(gr_object_table *table);
/* Initialises the process table the first time it is called and never again: a second
 * device creation must not invalidate the handles a first device (or a window) issued. */
void gr_objects_init_once(void);
/* Reserves a slot and returns a fresh handle, or GR_NULL_HANDLE when the table is full. */
gr_handle gr_object_insert(gr_object_table *table, uint32_t type, void *object);
/* Returns the object, or NULL when the handle is null, out of range, of the wrong type or
 * stale. *out_status is set to a specific error when the caller wants to distinguish. */
void *gr_object_lookup(gr_object_table *table, gr_handle handle, uint32_t type,
                       gr_result *out_status);
/* Releases a slot and bumps its generation, invalidating every handle that named it.
 * Returns the object that was removed, or NULL if the handle was not valid. */
void *gr_object_remove(gr_object_table *table, gr_handle handle, uint32_t type);
/* The table for this process. */
gr_object_table *gr_objects(void);

/* Duplicates a gr_str into malloc'd, NUL-terminated memory. Returns NULL for an empty or
 * absent string. The caller owns the result. */
char *gr_str_dup(gr_str s);

/* A stable hash of `data` (FNV-1a 64). Used for layout digests and permutation keys, where
 * the requirement is determinism across processes and machines, not cryptography. */
uint64_t gr_hash_bytes(const void *data, size_t len);
/* Folds `len` bytes into an existing hash. gr_hash_bytes() starts a fresh one; a digest over
 * a sequence of fields must chain, or every named field overwrites what came before it. */
uint64_t gr_hash_bytes_into(uint64_t hash, const void *data, size_t len);
uint64_t gr_hash_u64(uint64_t hash, uint64_t value);

#endif /* GRAIL_INTERNAL_H */
