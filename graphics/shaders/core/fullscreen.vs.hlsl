// fullscreen.vs.hlsl - the minimal vertex stage of the pipeline contract.
//
// No vertex buffer and no vertex attributes: a triangle covering the viewport is generated
// from SV_VertexID. It exists so the first renderer port has a pipeline that compiles,
// validates and draws with nothing but the frame constants, which makes it the natural
// smoke test for a new backend.
#include "grail_frame.hlsli"

struct GrailFullscreenOut
{
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
};

GrailFullscreenOut main(uint vertex_id : SV_VertexID)
{
    GrailFullscreenOut output;
    // The oversize triangle: (0,0) (-1,3) (3,-1) in clip space, clipped to the viewport.
    float2 p = float2((vertex_id << 1) & 2u, vertex_id & 2u) * 2.0 - 1.0;
    output.position = float4(p, 1.0, 1.0);
    // UVs in the same order, so uv 0..1 covers the visible viewport.
    output.uv = p * float2(0.5, -0.5) + 0.5;
    (void)g_frame; // the contract requires the block to be declared, not necessarily read
    return output;
}
