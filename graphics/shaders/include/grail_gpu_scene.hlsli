// grail_gpu_scene.hlsli - the GPU-visible structures shared between the renderer and the
// shaders, and the file the layout hash is computed over.
//
// Abundance stamps a hash of its shared GPU structs next to its shaders and has the host
// refuse a mismatch (abundance/engine/tools/layout_hash.cmake): a half-failed build once put
// new shaders beside an old host, which read the structs as garbage and page-faulted the
// GPU. Grail does the same, with the digest carried inside each reflection blob instead of
// in a side file, so a blob can never be separated from the layout it was built against.
//
// Every change to a struct in this file changes the digest and therefore refuses to run
// against a host that was not rebuilt. That is the intent.
#ifndef GRAIL_GPU_SCENE_HLSLI
#define GRAIL_GPU_SCENE_HLSLI

// One draw. Matches the host's scene record; 96 bytes, 16-byte aligned.
struct GrailDrawData
{
    float4x4 model;              // object -> camera-relative world (row-major)
    float4   bounds_center_radius; // xyz centre, w radius (camera-relative)
    uint     mesh_index;
    uint     material_index;
    uint     flags;
    uint     object_id;
};

// One point light, the shape a forward renderer consumes; 64 bytes.
struct GrailLight
{
    float4 position_radius;      // xyz position (camera-relative), w radius
    float4 colour_intensity;     // rgb colour, w intensity
    float4 direction_kind;       // xyz direction, w: 0 point, 1 spot
    float4 spot_angles;          // x cos(outer), y cos(inner)
};

#define GRAIL_MAX_LIGHTS 256

#endif // GRAIL_GPU_SCENE_HLSLI
