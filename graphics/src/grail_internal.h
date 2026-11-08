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
gr_result gr_vk_abi_texture_read(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t width, uint32_t height, uint32_t src_state, gr_mut_span_u8 out);
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
gr_result gr_vk_abi_cmd_push_constants(gr_handle cmd, uint32_t offset, gr_span_u8 data);

/* Derives the stage mask a push-constant write must name: the union of the stageFlags of every
 * declared range that overlaps [offset, offset+size). Pure, so it is tested without a GPU. A range
 * with a zero stage mask cannot exist (Vulkan forbids it), and nothing is returned for a write that
 * falls in no range - the caller treats that as a programming error. */
uint32_t gr_push_constant_stage_mask(const uint32_t *range_offsets, const uint32_t *range_sizes,
                                    const uint32_t *range_stages, uint32_t range_count,
                                    uint32_t offset, uint32_t size);
gr_result gr_vk_abi_cmd_draw(gr_handle cmd, const gr_draw *draw);
gr_result gr_vk_abi_cmd_draw_indexed(gr_handle cmd, const gr_draw_indexed *draw);
gr_result gr_vk_abi_cmd_draw_indexed_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t draw_count, uint32_t stride);
gr_result gr_vk_abi_cmd_bind_vertex_buffer(gr_handle cmd, uint32_t slot, gr_handle buffer, uint64_t offset);
gr_result gr_vk_abi_cmd_bind_index_buffer(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t index_type);
gr_result gr_vk_abi_cmd_dispatch(gr_handle cmd, uint32_t x, uint32_t y, uint32_t z);
gr_result gr_vk_abi_cmd_dispatch_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset);
gr_result gr_vk_abi_submit(const gr_submit *submit, uint64_t *out_value);
gr_result gr_vk_abi_swapchain_create(gr_handle device, const gr_swapchain_desc *desc, gr_handle *out_swapchain);
gr_result gr_vk_abi_swapchain_info(gr_handle swapchain, gr_format *out_format, uint32_t *out_width, uint32_t *out_height, uint32_t *out_image_count);
gr_result gr_vk_abi_swapchain_acquire(gr_handle swapchain, uint64_t timeout_ns, uint32_t *out_image_index, gr_handle *out_view, int32_t *out_needs_recreate);
gr_result gr_vk_abi_swapchain_recreate(gr_handle swapchain, uint32_t width, uint32_t height, uint64_t after_value);
gr_result gr_vk_abi_present(gr_handle queue, gr_handle swapchain, uint32_t image_index, uint64_t wait_value, uint64_t *out_value);
gr_result gr_vk_abi_fence_create(gr_handle device, uint64_t initial_value, gr_handle *out_fence);
gr_result gr_vk_abi_fence_wait(gr_handle fence, uint64_t value, uint64_t timeout_ns, gr_result *out_status);
gr_result gr_vk_abi_buffer_create(gr_handle device, const gr_buffer_desc *desc, gr_handle *out_buffer);
gr_result gr_vk_abi_buffer_write(gr_handle buffer, uint64_t offset, gr_span_u8 data);
gr_result gr_vk_abi_buffer_read(gr_handle buffer, uint64_t offset, gr_mut_span_u8 out);
gr_result gr_vk_abi_buffer_map(gr_handle buffer, void **out_ptr);
uint64_t gr_vk_abi_buffer_device_address(gr_handle buffer);
uint32_t gr_vk_abi_buffer_bindless_index(gr_handle buffer);
gr_result gr_vk_abi_sampler_create(gr_handle device, const gr_sampler_desc *desc, gr_handle *out_sampler, uint32_t *out_slot);
gr_result gr_vk_abi_texture_write(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t w, uint32_t h, gr_span_u8 rows);
uint32_t gr_vk_abi_texture_view_bindless_sampled(gr_handle view);
gr_result gr_vk_abi_frame_constants_write(gr_handle device, uint32_t slot, const gr_frame_constants *constants);
gr_result gr_vk_abi_frame_slot_count(gr_handle device, uint32_t *out_count);
gr_result gr_vk_abi_cmd_push_frame_offset(gr_handle cmd, uint32_t frame_slot);
void gr_vk_abi_buffer_unmap(gr_handle buffer);
uint64_t gr_vk_abi_fence_value(gr_handle fence);

/* Implemented by grail_d3d12.c with the same signatures as the Vulkan entry points. A build
 * without the Windows SDK (every non-Windows host) compiles them as GR_ERROR_UNSUPPORTED stubs,
 * so the dispatcher can route to them unconditionally. */
gr_result gr_d3d12_abi_device_create(const gr_device_desc *desc, gr_handle *out_device);
gr_result gr_d3d12_abi_device_destroy(gr_handle device);
gr_result gr_d3d12_abi_device_get_caps(gr_handle device, gr_device_caps *out);
gr_result gr_d3d12_abi_device_wait_idle(gr_handle device);
gr_result gr_d3d12_abi_device_queue(gr_handle device, gr_queue_kind kind, gr_handle *out_queue);
gr_result gr_d3d12_abi_queue_timeline(gr_handle queue, gr_handle *out_semaphore);
uint64_t gr_d3d12_abi_queue_submitted(gr_handle queue);
uint64_t gr_d3d12_abi_queue_completed(gr_handle queue);
gr_result gr_d3d12_abi_queue_wait_idle(gr_handle queue);
gr_handle gr_d3d12_abi_device_bindless(gr_handle device);
gr_result gr_d3d12_abi_bindless_get_info(gr_handle bindless, gr_bindless_info *out);
gr_result gr_d3d12_abi_device_retire(gr_handle device, gr_handle object, uint64_t after_value);
gr_result gr_d3d12_abi_device_collect(gr_handle device);
gr_result gr_d3d12_abi_shader_create(gr_handle device, const gr_shader_desc *desc, gr_handle *out_shader);
gr_result gr_d3d12_abi_pipeline_create(gr_handle device, const gr_pipeline_desc *desc,
                                   gr_handle *out_pipeline);
gr_result gr_d3d12_abi_pipeline_commit(gr_handle device, double *out_seconds);
gr_result gr_d3d12_abi_pipeline_stats(gr_handle device, uint32_t *out_declared, uint32_t *out_committed);
gr_result gr_d3d12_abi_texture_create(gr_handle device, const gr_texture_desc *desc, gr_handle *out_texture);
gr_result gr_d3d12_abi_texture_view_create(gr_handle device, const gr_texture_view_desc *desc, gr_handle *out_view);
gr_result gr_d3d12_abi_texture_read(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t width, uint32_t height, uint32_t src_state, gr_mut_span_u8 out);
gr_result gr_d3d12_abi_cmd_pool_create(gr_handle device, const gr_cmd_pool_desc *desc, gr_handle *out_pool);
gr_result gr_d3d12_abi_cmd_alloc(const gr_cmd_alloc_info *info, gr_handle *out_cmd);
gr_result gr_d3d12_abi_cmd_begin(gr_handle cmd);
gr_result gr_d3d12_abi_cmd_end(gr_handle cmd);
gr_result gr_d3d12_abi_cmd_reset(gr_handle cmd);
gr_result gr_d3d12_abi_cmd_barrier(gr_handle cmd, const gr_barrier *barriers, uint32_t count);
gr_result gr_d3d12_abi_cmd_begin_render(gr_handle cmd, const gr_render_begin *info);
gr_result gr_d3d12_abi_cmd_end_render(gr_handle cmd);
gr_result gr_d3d12_abi_cmd_set_viewport(gr_handle cmd, float x, float y, float width, float height, float min_depth, float max_depth);
gr_result gr_d3d12_abi_cmd_set_scissor(gr_handle cmd, int32_t x, int32_t y, uint32_t width, uint32_t height);
gr_result gr_d3d12_abi_cmd_bind_pipeline(gr_handle cmd, gr_handle pipeline);
gr_result gr_d3d12_abi_cmd_push_constants(gr_handle cmd, uint32_t offset, gr_span_u8 data);
gr_result gr_d3d12_abi_cmd_draw(gr_handle cmd, const gr_draw *draw);
gr_result gr_d3d12_abi_cmd_draw_indexed(gr_handle cmd, const gr_draw_indexed *draw);
gr_result gr_d3d12_abi_cmd_draw_indexed_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t draw_count, uint32_t stride);
gr_result gr_d3d12_abi_cmd_bind_vertex_buffer(gr_handle cmd, uint32_t slot, gr_handle buffer, uint64_t offset);
gr_result gr_d3d12_abi_cmd_bind_index_buffer(gr_handle cmd, gr_handle buffer, uint64_t offset, uint32_t index_type);
gr_result gr_d3d12_abi_cmd_dispatch(gr_handle cmd, uint32_t x, uint32_t y, uint32_t z);
gr_result gr_d3d12_abi_cmd_dispatch_indirect(gr_handle cmd, gr_handle buffer, uint64_t offset);
gr_result gr_d3d12_abi_submit(const gr_submit *submit, uint64_t *out_value);
gr_result gr_d3d12_abi_swapchain_create(gr_handle device, const gr_swapchain_desc *desc, gr_handle *out_swapchain);
gr_result gr_d3d12_abi_swapchain_info(gr_handle swapchain, gr_format *out_format, uint32_t *out_width, uint32_t *out_height, uint32_t *out_image_count);
gr_result gr_d3d12_abi_swapchain_acquire(gr_handle swapchain, uint64_t timeout_ns, uint32_t *out_image_index, gr_handle *out_view, int32_t *out_needs_recreate);
gr_result gr_d3d12_abi_swapchain_recreate(gr_handle swapchain, uint32_t width, uint32_t height, uint64_t after_value);
gr_result gr_d3d12_abi_present(gr_handle queue, gr_handle swapchain, uint32_t image_index, uint64_t wait_value, uint64_t *out_value);
gr_result gr_d3d12_abi_fence_create(gr_handle device, uint64_t initial_value, gr_handle *out_fence);
gr_result gr_d3d12_abi_fence_wait(gr_handle fence, uint64_t value, uint64_t timeout_ns, gr_result *out_status);
gr_result gr_d3d12_abi_buffer_create(gr_handle device, const gr_buffer_desc *desc, gr_handle *out_buffer);
gr_result gr_d3d12_abi_buffer_write(gr_handle buffer, uint64_t offset, gr_span_u8 data);
gr_result gr_d3d12_abi_buffer_read(gr_handle buffer, uint64_t offset, gr_mut_span_u8 out);
gr_result gr_d3d12_abi_buffer_map(gr_handle buffer, void **out_ptr);
uint64_t gr_d3d12_abi_buffer_device_address(gr_handle buffer);
uint32_t gr_d3d12_abi_buffer_bindless_index(gr_handle buffer);
gr_result gr_d3d12_abi_sampler_create(gr_handle device, const gr_sampler_desc *desc, gr_handle *out_sampler, uint32_t *out_slot);
gr_result gr_d3d12_abi_texture_write(gr_handle texture, uint32_t mip, uint32_t layer, uint32_t x, uint32_t y, uint32_t w, uint32_t h, gr_span_u8 rows);
uint32_t gr_d3d12_abi_texture_view_bindless_sampled(gr_handle view);
gr_result gr_d3d12_abi_frame_constants_write(gr_handle device, uint32_t slot, const gr_frame_constants *constants);
gr_result gr_d3d12_abi_frame_slot_count(gr_handle device, uint32_t *out_count);
gr_result gr_d3d12_abi_cmd_push_frame_offset(gr_handle cmd, uint32_t frame_slot);
void gr_d3d12_abi_buffer_unmap(gr_handle buffer);
uint64_t gr_d3d12_abi_fence_value(gr_handle fence);

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
