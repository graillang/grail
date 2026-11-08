// tonemap.ps.hlsl - a fragment stage that reads the frame constants and the bindless table.
//
// This is the smallest shader that exercises the whole binding contract: set 1 binding 0
// (frame constants), set 0 binding 0 (a sampled image) and set 0 binding 2 (a sampler), with
// the texture selected by a slot the host passes in, not by a binding it rewrites.
#include "grail_bindless.hlsli"
#include "grail_frame.hlsli"

// Permutation domains. The directive is a comment the compiler ignores; the offline tool reads
// it so a host cannot ask for a define this shader does not declare, and so the cross product is
// enumerable at build time (graphics/docs/shader-flow.md "Permutations").
//   GRAIL_TONEMAP_EXPOSURE   0: the scene pass already applied pre-exposure
//                            1: apply the frame's pre-exposure here
//   GRAIL_TONEMAP_OUTPUT     0: linear (an HDR target follows)
//                            1: sRGB-encoded for a swapchain without an sRGB format
// grail:permutation GRAIL_TONEMAP_EXPOSURE default=1 values=0,1
// grail:permutation GRAIL_TONEMAP_OUTPUT default=0 values=0,1
#ifndef GRAIL_TONEMAP_EXPOSURE
#define GRAIL_TONEMAP_EXPOSURE 1
#endif
#ifndef GRAIL_TONEMAP_OUTPUT
#define GRAIL_TONEMAP_OUTPUT 0
#endif

// A define is applied as the numeric value, so `#if` reads it as one would hope and no
// `#ifdef`/`#if` confusion is possible.
static const bool kApplyExposure = GRAIL_TONEMAP_EXPOSURE != 0;
static const bool kEncodeSrgb = GRAIL_TONEMAP_OUTPUT != 0;

struct GrailFullscreenOut
{
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
};

// ACES filmic approximation, the same curve shape Abundance grades with. Kept in the shader
// rather than described in C because the renderer must not be able to disagree with it.
float3 aces_tonemap(float3 x)
{
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

// Push constants: 128 bytes, all stages. [[vk::push_constant]] makes DXC emit a SPIR-V
// PushConstant block (no descriptor, so it cannot collide with a table binding); the D3D12
// path ignores the attribute and keeps b0, which the root signature declares as 128 bytes
// of root constants. One declaration, both backends.
struct GrailTonemapPush
{
    uint scene_texture_slot;   // slot of the scene colour target in the sampled-image table
    uint exposure_enabled;
    uint2 _pad;
};

[[vk::push_constant]] ConstantBuffer<GrailTonemapPush> g_push : register(b0);

float4 main(GrailFullscreenOut input) : SV_Target
{
    if (!grail_frame_matches())
        return float4(1.0, 0.0, 1.0, 1.0); // magenta: host and shader disagree on the layout

    Texture2D<float4> scene = g_tex2d_f4[NonUniformResourceIndex(g_push.scene_texture_slot)];
    float3 hdr = scene.Sample(grail_sampler(GRAIL_SAMPLER_LINEAR_CLAMP), input.uv).rgb;

    // exposure.z is the pre-exposure, 1/(1.2 * 2^EV100); whether to apply it here or in the
    // scene pass is the GRAIL_TONEMAP_EXPOSURE permutation.
    float3 scene_colour = hdr;
    if (kApplyExposure)
        scene_colour *= max(g_frame.exposure.z, 1.0e-4h);
    float3 mapped = aces_tonemap(scene_colour);
    if (kEncodeSrgb) {
        // The piecewise sRGB transfer function; the swapchain format may be UNORM.
        float3 lo = mapped * 12.92;
        float3 hi = 1.055 * pow(max(mapped, 0.0), 1.0 / 2.4) - 0.055;
        mapped = select(mapped <= 0.0031308, lo, hi);
    }
    return float4(mapped, 1.0);
}
