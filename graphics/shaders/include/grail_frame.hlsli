// grail_frame.hlsli - the shader mirror of gr_frame_constants (grail_bindless.h).
//
// Set 1, binding 0: one dynamic uniform buffer, one slot per frame in flight.
//
// Layout rules both sides obey: scalar block layout (-fvk-use-scalar-layout), row-major
// matrices acting on column vectors (-Zpr), members in this exact order. The declared
// order matters where C and HLSL would otherwise disagree about padding: exposure is a
// float4 and therefore precedes the scalars, so it lands on a 16-byte boundary under scalar
// layout and under C's natural alignment alike. The whole structure is 416 bytes; a host
// with a different size refuses to run (see grail-layout-check).
#ifndef GRAIL_FRAME_HLSLI
#define GRAIL_FRAME_HLSLI

struct GrailFrameConstants
{
    float4x4 view;                 // camera-relative world -> view (rotation only)
    float4x4 proj;                 // view -> clip, reverse-Z, infinite far plane
    float4x4 view_proj;
    float4x4 inv_view_proj;
    float4   origin;               // xyz: camera world position
    float4   viewport;             // xy: render size in pixels; zw: 1/size
    float4   time;                 // x: seconds; y: delta seconds; z: frame index
    float4   sun_direction;        // xyz: unit vector towards the sun; w: angular radius
    float4   sun_illuminance;      // rgb: illuminance at the ground
    float4   camera_forward;       // xyz: unit forward; w: near plane (m)
    float4   jitter;               // xy: this frame's jitter; zw: previous
    float4   exposure;             // x: display scale; y: EV100; z: pre-exposure
    uint     frame_index;
    uint     frame_seed;
    uint     flags;
    uint     version;
    uint     light_count;
    uint3    _reserved0;
};

ConstantBuffer<GrailFrameConstants> g_frame : register(b0, space1);

#define GRAIL_FRAME_FLAG_HISTORY_RESET (1u << 0)
#define GRAIL_FRAME_FLAG_CAPTURE       (1u << 1)
#define GRAIL_FRAME_FLAG_HEADLESS      (1u << 2)
#define GRAIL_FRAME_CONSTANTS_VERSION  1u

// A shader that depends on this layout must refuse a host it does not match rather than
// read a struct that means something else. Called once per pass that reads g_frame.
bool grail_frame_matches()
{
    return g_frame.version == GRAIL_FRAME_CONSTANTS_VERSION;
}

#endif // GRAIL_FRAME_HLSLI
