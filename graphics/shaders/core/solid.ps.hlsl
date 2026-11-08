// solid.ps.hlsl - a fragment stage that needs no descriptors, for proving the draw path.
//
// tonemap.ps samples the bindless table, and until the backend allocates a descriptor set any
// sample from it is undefined. This shader reads only its interpolated position and one push
// constant, so a frame that clears and draws with it exercises the whole command path — dynamic
// rendering, pipeline binding, push constants, rasterisation, readback — while producing a value
// that can be predicted exactly. It is the shader the offscreen frame test uses.
//
// Output: r = uv.x*tint.r, g = uv.y*tint.g, b = tint.b, a = tint.a. A 64x64 target therefore holds a gradient whose corner
// values are known, which is what makes the readback digest meaningful rather than merely stable.

struct GrailSolidIn
{
    float4 position : SV_Position;
    float2 uv       : TEXCOORD0;
};

struct GrailSolidPush
{
    float4 tint;
};

// [[vk::push_constant]]: a real push-constant block on Vulkan, root constants on D3D12.
[[vk::push_constant]] ConstantBuffer<GrailSolidPush> g_push : register(b0);

float4 main(GrailSolidIn input) : SV_Target
{
    // Written component by component: a float2 * float3 is not a float4, and the intent is one
    // channel per axis so the readback has a gradient in both directions.
    return float4(input.uv.x * g_push.tint.r, input.uv.y * g_push.tint.g,
                  g_push.tint.b, g_push.tint.a);
}
