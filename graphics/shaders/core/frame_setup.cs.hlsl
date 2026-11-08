// frame_setup.cs.hlsl - a compute stage over the bindless storage buffers and push constants.
//
// It stands in for the per-frame GPU bookkeeping a renderer needs (here: clearing and
// seeding a visibility counter buffer) and exists to pin down the parts of the contract that
// only a compute pipeline can express: a declared thread group size, a storage buffer read
// through the table, and a 128-byte push constant block whose layout the host mirrors.
#include "grail_bindless.hlsli"
#include "grail_frame.hlsli"

// The host's push constants for this pass. 16 bytes used of the 128 available; the struct is
// part of the contract the host mirrors in C.
struct GrailFrameSetupPush
{
    uint counters_slot;   // bindless storage-buffer slot
    uint count;
    uint seed;
    uint flags;
};

// [[vk::push_constant]]: a real push-constant block on Vulkan, b0 root constants on D3D12.
[[vk::push_constant]] ConstantBuffer<GrailFrameSetupPush> g_push : register(b0);

RWByteAddressBuffer g_counters : register(u3, space0);

[numthreads(64, 1, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= g_push.count)
        return;
    if (!grail_frame_matches())
        return;
    // Each element is a uint32 counter; seed it from the frame so a stochastic pass differs
    // per frame without the host writing the buffer.
    uint value = g_push.seed ^ (id.x * 0x9E3779B9u);
    value ^= value >> 16u;
    value *= 0x7FEB352Du;
    value ^= value >> 15u;
    g_counters.Store(id.x * 4u, value);
}
