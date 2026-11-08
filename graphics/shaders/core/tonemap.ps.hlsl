// tonemap.ps.hlsl - a fragment stage that reads the frame constants and the bindless table.
//
// This is the smallest shader that exercises the whole binding contract: set 1 binding 0
// (frame constants), set 0 binding 0 (a sampled image) and set 0 binding 2 (a sampler), with
// the texture selected by a slot the host passes in, not by a binding it rewrites.
#include "grail_bindless.hlsli"
#include "grail_frame.hlsli"

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

    // Pre-exposure is applied by the scene pass; exposure.z is 1/(1.2 * 2^EV100).
    float3 mapped = aces_tonemap(g_push.exposure_enabled ? hdr : hdr);
    return float4(mapped, 1.0);
}
