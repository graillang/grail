// grail_bindless.hlsli - the shader side of grail_bindless.h.
//
// One declaration per table. On Vulkan every table is set 0, binding N (0 sampled images,
// 1 storage images, 2 samplers, 3 storage buffers); on D3D12 each unbounded table needs a
// register range nothing else overlaps. The sampled images (t0) and samplers (s2) are alone in
// their register classes in space 0, so register() alone gives both APIs the right binding. The
// two UAV tables would overlap in space 0 (an unbounded u1 range covers u3), so they take their
// own D3D12 spaces - storage images u0 space2, storage buffers u0 space3 - and [[vk::binding]]
// keeps them at set 0, bindings 1 and 3, for SPIR-V (DXC ignores the attribute for DXIL).
//
// Verified against DXC 1.9.2609: register(t0, space0) -> DescriptorSet 0, Binding 0;
// register(b0, space1) -> DescriptorSet 1, Binding 0; [[vk::binding(3, 0)]] with
// register(u0, space3) -> DescriptorSet 0, Binding 3 in SPIR-V and u0 space3 in DXIL.
//
// Indices that vary within a wave must be wrapped in NonUniformResourceIndex().
#ifndef GRAIL_BINDLESS_HLSLI
#define GRAIL_BINDLESS_HLSLI

// Set 0, binding 0: sampled images. Every texture view a material samples.
Texture2D            g_tex2d[]        : register(t0, space0);
Texture2D<float4>    g_tex2d_f4[]     : register(t0, space0);
Texture2D<uint>      g_tex2d_uint[]   : register(t0, space0);
Texture2D<uint2>     g_tex2d_uint2[]  : register(t0, space0);
Texture2DArray       g_tex2d_array[]  : register(t0, space0);
Texture3D            g_tex3d[]        : register(t0, space0);
TextureCube          g_texcube[]      : register(t0, space0);
TextureCubeArray     g_texcube_array[]: register(t0, space0);

// Set 0, binding 1: storage images.
[[vk::binding(1, 0)]] RWTexture2D<float4>  g_rw2d[]        : register(u0, space2);
[[vk::binding(1, 0)]] RWTexture2D<float>   g_rw2d_float[]  : register(u0, space2);
[[vk::binding(1, 0)]] RWTexture2D<uint>    g_rw2d_uint[]   : register(u0, space2);
[[vk::binding(1, 0)]] RWTexture2D<uint2>   g_rw2d_uint2[]  : register(u0, space2);
[[vk::binding(1, 0)]] RWTexture2DArray<float4> g_rw2d_array[] : register(u0, space2);
[[vk::binding(1, 0)]] RWTexture3D<float4>  g_rw3d[]        : register(u0, space2);
[[vk::binding(1, 0)]] RWTexture3D<float>   g_rw3d_float[]  : register(u0, space2);

// Set 0, binding 2: samplers. The fixed slots below are the only ones a shader should name
// by constant; a material sampler index comes from gr_sampler_create().
SamplerState            g_samplers[]         : register(s2, space0);
SamplerComparisonState  g_compare_samplers[] : register(s2, space0);

// Set 0, binding 3: storage buffers, by slot. Declared read-write only: D3D12 puts a
// read-only ByteAddressBuffer in the SRV register class and an RWByteAddressBuffer in the
// UAV class, so two declarations would need two bindings and a buffer would have to know
// which access a shader would use. One read-write table, with a read-only buffer simply
// never stored to, keeps one slot per buffer on every backend. Most buffers a pass touches
// arrive as a buffer device address in push constants instead.
[[vk::binding(3, 0)]] RWByteAddressBuffer g_buffers[] : register(u0, space3);

// Set 0, binding 4: acceleration structures (ray tracing backends only).
// RaytracingAccelerationStructure g_tlas[] : register(t4, space0);

// Fixed sampler slots, mirroring gr_sampler_slot in grail_rhi.h.
#define GRAIL_SAMPLER_LINEAR_CLAMP           0
#define GRAIL_SAMPLER_LINEAR_WRAP            1
#define GRAIL_SAMPLER_POINT_CLAMP            2
#define GRAIL_SAMPLER_POINT_WRAP             3
#define GRAIL_SAMPLER_ANISO_WRAP             4
#define GRAIL_SAMPLER_ANISO_CLAMP            5
#define GRAIL_SAMPLER_SHADOW_COMPARE         6
#define GRAIL_SAMPLER_MIN_REDUCE             7
#define GRAIL_SAMPLER_MAX_REDUCE             8
#define GRAIL_SAMPLER_LINEAR_CLAMP_U_WRAP_V  9
#define GRAIL_SAMPLER_LINEAR_WRAP_U_CLAMP_V 10
#define GRAIL_SAMPLER_ANISO_CLAMP_U_WRAP_V  11
#define GRAIL_SAMPLER_ANISO_WRAP_U_CLAMP_V  12

SamplerState grail_sampler(uint slot) { return g_samplers[NonUniformResourceIndex(slot)]; }

// Push constants: 128 bytes, every stage, declared per shader as
//
//     struct MyPassPush { ... };
//     [[vk::push_constant]] ConstantBuffer<MyPassPush> g_push : register(b0);
//
// The attribute makes DXC emit a SPIR-V PushConstant block, which occupies no descriptor
// set and therefore cannot collide with a table binding; the D3D12 path ignores the
// attribute and keeps b0 for the root signature's 128 bytes of root constants. A plain
// cbuffer would become a *descriptor* at set 0 binding 0 and collide with the sampled-image
// table (verified: DXC 1.9.2609 emits DescriptorSet 0 Binding 0 for a non-attributed b0).
#define GRAIL_PUSH_CONSTANT_BYTES 128

#endif // GRAIL_BINDLESS_HLSLI
