/* grail_backend_d3d12.h - what the D3D12 backend requires and provides (Windows).
 *
 * D3D12 has no descriptor set for the bindless tables in the Vulkan sense; it has
 * descriptor heaps and a root signature, and an unbounded descriptor range can index into a
 * heap at an offset the shader computes. The backend owns one shader-visible heap holding
 * the five tables of grail_bindless.h and declares the matching unbounded root ranges, so
 * the shader source is identical to the Vulkan one.
 */
#ifndef GRAIL_BACKEND_D3D12_H
#define GRAIL_BACKEND_D3D12_H

#include "grail_abi.h"
#include "grail_window.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Feature level 12_0 is the floor for unbounded descriptor ranges and 64-bit atomics;
 * 12_1 (conservative raster, tiled resources) and 12_2 (ray tracing, mesh shaders, sampler
 * feedback) are used when the device reports them. Windows 10 2004 (build 19041) or later
 * is required for the Agility SDK's device creation path. */
#define GR_D3D12_MIN_FEATURE_LEVEL 0xC000 /* D3D_FEATURE_LEVEL_12_0 */
#define GR_D3D12_TARGET_FEATURE_LEVEL 0xC200 /* D3D_FEATURE_LEVEL_12_2 */

/* Shader model 6.6 is what the offline compiler emits (dxil). A device whose driver
 * supports less is refused with GR_ERROR_UNSUPPORTED; the DXIL container is not retargeted
 * at runtime. */
#define GR_D3D12_SHADER_MODEL_MAJOR 6
#define GR_D3D12_SHADER_MODEL_MINOR 6

/* The backend's root signature, which the offline shader flow must agree with:
 *   [0] root constants        b0, 128 bytes (GR_PUSH_CONSTANT_BYTES), all stages
 *   [1] descriptor table      space 0: range t0 unbounded  sampled images
 *   [2] descriptor table      space 0: range u0 unbounded  storage images
 *   [3] descriptor table      space 0: range s0 unbounded  samplers
 *   [4] descriptor table      space 0: range t1 unbounded  storage buffers
 *   [5] descriptor table      space 1: range b0 1         frame constants (root CBV
 *                                                          preferred: no heap traffic)
 * Root parameter 1 is a root constant view, so a shader may also declare b0 for constants
 * directly; grail_bindless.h fixes that a caller uses push constants only.
 */
gr_result gr_d3d12_root_signature_layout(gr_mut_span_u8 out_json, size_t *out_used);

/* Device and command queue interop for a capture or debugging tool. Borrowed pointers. */
gr_result gr_d3d12_device(gr_handle device, void **out_device);
gr_result gr_d3d12_queue(gr_handle queue, void **out_queue);

/* DirectX 12 has no timeline semaphore; the backend emulates gr_queue_timeline with a
 * fence plus a waitable object. This reports the underlying ID3D12Fence for interop. */
gr_result gr_d3d12_fence(gr_handle fence, void **out_fence, uint64_t *out_value);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* GRAIL_BACKEND_D3D12_H */
