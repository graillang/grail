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

/* One backend per process. The object table is global, so two live backends would have to
 * disambiguate each other's handles on every call; instead the first device creation fixes the
 * backend and the ABI entry points route through it. A second device of a different backend is
 * refused with GR_ERROR_UNSUPPORTED. */
void gr_set_active_backend(gr_backend backend);
gr_backend gr_active_backend(void);

/* Implemented by grail_vulkan.c, reached only through the dispatcher in grail_null.c. Every one
 * of these returns GR_ERROR_UNSUPPORTED when the build has no Vulkan headers, which is what makes
 * the dispatch safe to write unconditionally. */
gr_result gr_vk_abi_device_create(const gr_device_desc *desc, gr_handle *out_device);
gr_result gr_vk_abi_device_destroy(gr_handle device);
gr_result gr_vk_abi_device_get_caps(gr_handle device, gr_device_caps *out);
gr_result gr_vk_abi_device_wait_idle(gr_handle device);
gr_result gr_vk_abi_device_queue(gr_handle device, gr_queue_kind kind, gr_handle *out_queue);
gr_result gr_vk_abi_queue_timeline(gr_handle queue, gr_handle *out_semaphore);
uint64_t gr_vk_abi_queue_submitted(gr_handle queue);
uint64_t gr_vk_abi_queue_completed(gr_handle queue);
gr_result gr_vk_abi_queue_wait_idle(gr_handle queue);
gr_handle gr_vk_abi_device_bindless(gr_handle device);
gr_result gr_vk_abi_bindless_get_info(gr_handle bindless, gr_bindless_info *out);
gr_result gr_vk_abi_device_retire(gr_handle device, gr_handle object, uint64_t after_value);
gr_result gr_vk_abi_device_collect(gr_handle device);
gr_result gr_vk_abi_shader_create(gr_handle device, const gr_shader_desc *desc, gr_handle *out_shader);
gr_result gr_vk_abi_pipeline_create(gr_handle device, const gr_pipeline_desc *desc,
                                   gr_handle *out_pipeline);
gr_result gr_vk_abi_pipeline_commit(gr_handle device, double *out_seconds);
gr_result gr_vk_abi_pipeline_stats(gr_handle device, uint32_t *out_declared, uint32_t *out_committed);
gr_result gr_vk_abi_texture_create(gr_handle device, const gr_texture_desc *desc, gr_handle *out_texture);
gr_result gr_vk_abi_texture_view_create(gr_handle device, const gr_texture_view_desc *desc, gr_handle *out_view);
gr_result gr_vk_abi_texture_read(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t width, uint32_t height, gr_mut_span_u8 out);
gr_result gr_vk_abi_cmd_pool_create(gr_handle device, const gr_cmd_pool_desc *desc, gr_handle *out_pool);
gr_result gr_vk_abi_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd);
gr_result gr_vk_abi_cmd_begin(gr_handle cmd);
gr_result gr_vk_abi_cmd_end(gr_handle cmd);
gr_result gr_vk_abi_cmd_reset(gr_handle cmd);
gr_result gr_vk_abi_cmd_barrier(gr_handle cmd, const gr_barrier *barriers, uint32_t count);
gr_result gr_vk_abi_cmd_begin_render(gr_handle cmd, const gr_render_begin *info);
gr_result gr_vk_abi_cmd_end_render(gr_handle cmd);
gr_result gr_vk_abi_cmd_set_viewport(gr_handle cmd, float x, float y, float width, float height, float min_depth, float max_depth);
gr_result gr_vk_abi_cmd_set_scissor(gr_handle cmd, int32_t x, int32_t y, uint32_t width, uint32_t height);
gr_result gr_vk_abi_cmd_bind_pipeline(gr_handle cmd, gr_handle pipeline);
gr_result gr_vk_abi_cmd_push_constants(gr_handle cmd, uint32_t stage_mask, uint32_t offset, gr_span_u8 data);
gr_result gr_vk_abi_cmd_draw(gr_handle cmd, const gr_draw *draw);
gr_result gr_vk_abi_submit(const gr_submit *submit, uint64_t *out_value);
gr_result gr_vk_abi_fence_create(gr_handle device, uint64_t initial_value, gr_handle *out_fence);
gr_result gr_vk_abi_fence_wait(gr_handle fence, uint64_t value, uint64_t timeout_ns, gr_result *out_status);
uint64_t gr_vk_abi_fence_value(gr_handle fence);

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
