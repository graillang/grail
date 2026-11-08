/* grail_backend_metal.h - what the Metal backend requires and provides (macOS).
 *
 * Metal is reached from the same HLSL. There is no Metal compiler for HLSL, so the offline
 * flow goes HLSL -> DXC -> SPIR-V -> SPIRV-Cross -> MSL (graphics/docs/shader-flow.md
 * "Metal"). The binding model survives that crossing through argument buffers: each set
 * becomes one argument buffer whose entries are the same unbounded arrays, in the order
 * grail_bindless.h declares them.
 */
#ifndef GRAIL_BACKEND_METAL_H
#define GRAIL_BACKEND_METAL_H

#include "grail_abi.h"
#include "grail_window.h"

#ifdef __cplusplus
extern "C" {
#endif

/* macOS 13 (Ventura) is the floor: Metal 3, argument buffer tier 2, and the family of GPUs
 * the renderer targets. iOS is not a target of this RHI. */
#define GR_METAL_MIN_OS_MAJOR 13
#define GR_METAL_MIN_OS_MINOR 0
/* MSL version the offline flow emits (`spirv-cross --msl --msl-version 30000`). */
#define GR_METAL_MSL_VERSION 30000

/* Argument buffer tier 2 is required: it allows arrays of textures and samplers inside an
 * argument buffer, which is what the bindless table becomes. Tier 1 cannot index them, so a
 * device reporting less is refused.
 *
 * Differences the backend absorbs, not the caller:
 *   - Metal has no descriptor set for frame constants; set 1 becomes buffer(5)
 *   - push constants become setBytes() at index 6, up to 4 KB (still capped at 128 here)
 *   - there are no timeline semaphores; gr_queue_timeline is an MTLEvent with a counter
 *   - there is no depth clamp; GR_STATE_* is honoured, gr_pipeline_desc.depth_clamp is
 *     reported unsupported through GR_ERROR_UNSUPPORTED rather than ignored
 *   - storage image formats must be declared: the "unknown format" bindless trick of
 *     Vulkan does not exist, so a storage texture is typed by its view
 */
gr_result gr_metal_argument_buffer_layout(gr_mut_span_u8 out_json, size_t *out_used);

/* Borrowed handles for a capture tool (Metal System Trace, Xcode GPU capture). */
gr_result gr_metal_device(gr_handle device, void **out_device);
gr_result gr_metal_command_queue(gr_handle queue, void **out_queue);
gr_result gr_metal_layer(gr_handle swapchain, void **out_layer);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_BACKEND_METAL_H */
