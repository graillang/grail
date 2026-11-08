/* grail_shader.h - shader containers, offline reflection, pipelines and permutations.
 *
 * Reflection is a build artifact, not a runtime query.
 *
 * Abundance's engine deliberately compiles without -fspv-reflect, because the SPIR-V
 * extensions it emits are not enabled on its devices (engine/core/DESIGN.md "Shaders").
 * Grail needs reflection for a second reason as well: the D3D12 root signature and the
 * Metal argument-buffer layout both have to be derived before any device exists, at cook
 * time, from the same source that produced the bytecode. So the compiler emits a
 * reflection blob next to each shader, the backend consumes it at pipeline creation, and no
 * backend ever parses a container at runtime.
 *
 * One source, three containers:
 *   HLSL --dxc--> SPIR-V  (+ reflection)   Vulkan; also the input to the Metal path
 *   HLSL --dxc--> DXIL    (+ reflection)   D3D12
 *   SPIR-V --spirv-cross--> MSL            Metal
 * The reflection blob is identical for all three because it is produced from the HLSL
 * front end (DXC's reflection of the same source), so a pipeline's bindings, vertex inputs
 * and constant-block layout cannot drift between backends.
 *
 * Graphics/docs/shader-flow.md defines the flow; this header defines the on-disk format.
 */
#ifndef GRAIL_SHADER_H
#define GRAIL_SHADER_H

#include "grail_abi.h"
#include "grail_bindless.h"
#include "grail_rhi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* =======================================================================================
 * Stages
 * ======================================================================================= */
typedef enum gr_shader_stage {
    GR_SHADER_STAGE_VERTEX = 0,
    GR_SHADER_STAGE_FRAGMENT = 1,
    GR_SHADER_STAGE_COMPUTE = 2,
    GR_SHADER_STAGE_MESH = 3,
    GR_SHADER_STAGE_TASK = 4,      /* amplification, the mesh pipeline's first stage */
    GR_SHADER_STAGE_LIBRARY = 5,   /* ray tracing, any number of entry points */
    GR_SHADER_STAGE_COUNT
} gr_shader_stage;

/* The suffix Abundance uses for its shader filenames (<name>.<stage>.hlsl), kept so a file
 * name states its stage and the build can glob for it. */
const char *gr_shader_stage_suffix(gr_shader_stage stage);   /* "vs", "ps", "cs", "ms", "as", "lib" */
gr_result gr_shader_stage_from_suffix(gr_str suffix, gr_shader_stage *out);

/* The bytecode container inside a blob. */
typedef enum gr_shader_container {
    GR_CONTAINER_SPIRV = 0,   /* VK; DXC -spirv */
    GR_CONTAINER_DXIL = 1,    /* D3D12; DXC, signed */
    GR_CONTAINER_MSL_SOURCE = 2, /* Metal; SPIRV-Cross text, compiled by the backend at load */
    GR_CONTAINER_MSL_LIBRARY = 3 /* Metal; a .metallib built offline by xcrun metal */
} gr_shader_container;

/* =======================================================================================
 * Reflection blob - on-disk format
 *
 * All integers little-endian. All offsets are bytes from the start of the blob. Every
 * table is an array of fixed-size records, so a reader validates ranges once and can then
 * index without re-checking each record. A blob with a bad magic, an unknown version, an
 * out-of-range offset, a string that is not inside the string section, or a trailing byte
 * is refused with GR_ERROR_SHADER_INVALID.
 *
 *   [0]  gr_reflect_blob_header
 *   [1]  bytecode            (container-specific, container_length bytes, 8-byte aligned)
 *   [2]  string section      (NUL-separated; every name is an (offset, length) pair)
 *   [3]  gr_reflect_binding  x binding_count
 *   [4]  gr_reflect_member   x member_count
 *   [5]  gr_reflect_vertex   x vertex_count
 *   [6]  gr_reflect_stage    x stage_count   (compute group size, mesh output limits)
 *   [7]  gr_reflect_define   x define_count  (permutation domains this shader reacts to)
 * ======================================================================================= */
#define GR_REFLECT_MAGIC 0x46455247u  /* 'G','R','E','F' as little-endian bytes */
#define GR_REFLECT_VERSION 1u
#define GR_REFLECT_MAX_DEFINES 16u

typedef struct gr_reflect_blob_header {
    uint32_t magic;              /* GR_REFLECT_MAGIC */
    uint16_t version;            /* GR_REFLECT_VERSION */
    uint16_t header_size;        /* sizeof(gr_reflect_blob_header) when written */
    uint32_t container;          /* gr_shader_container */
    uint32_t stage;              /* gr_shader_stage */
    uint32_t flags;              /* gr_reflect_flags */
    uint64_t blob_length;        /* the whole file; a reader refuses a mismatch */
    uint64_t bytecode_offset;
    uint64_t bytecode_length;
    uint32_t entry_point_name;   /* string offset */
    uint32_t source_name;        /* string offset: the path the blob was built from */
    uint32_t compiler_version;   /* string offset: e.g. "dxc 1.9.2609.5" */
    uint32_t compile_flags;      /* string offset: the exact command line */
    uint32_t string_offset;
    uint32_t string_length;
    uint32_t binding_offset, binding_count;    /* gr_reflect_binding */
    uint32_t member_offset, member_count;      /* gr_reflect_member */
    uint32_t vertex_offset, vertex_count;      /* gr_reflect_vertex */
    uint32_t stage_offset, stage_count;        /* gr_reflect_stage */
    uint32_t define_offset, define_count;      /* gr_reflect_define */
    /* The layout hash: a 128-bit digest of every GPU-visible type the shader declares
     * (constant buffers, storage-buffer structs, vertex inputs), over the concatenation of
     * their canonical descriptions. A host that builds its structs from a different layout
     * computes a different digest and refuses to run, instead of reading another shader's
     * memory as its own. This is Abundance's layout.hash (engine/tools/layout_hash.cmake)
     * generalised to a digest the blob carries with it. */
    uint64_t layout_hash[2];
    uint32_t _reserved[2];
} gr_reflect_blob_header;

typedef enum gr_reflect_flags {
    GR_REFLECT_NONE = 0,
    GR_REFLECT_HAS_PUSH_CONSTANTS = 1u << 0,
    GR_REFLECT_HAS_DEPTH_WRITE = 1u << 1,
    GR_REFLECT_USES_64BIT_INTEGER = 1u << 2,
    GR_REFLECT_USES_16BIT_TYPES = 1u << 3,
    GR_REFLECT_USES_STORAGE_IMAGES = 1u << 4,
    GR_REFLECT_USES_NONUNIFORM_INDEX = 1u << 5
} gr_reflect_flags;

/* A binding as the shader declares it. `set` and `binding` are the portable numbers of
 * grail_bindless.h; the backend maps them (Vulkan directly, D3D12 to a heap offset, Metal to
 * an argument-buffer index). */
typedef enum gr_reflect_binding_kind {
    GR_REFLECT_BIND_SAMPLED_IMAGE = 0,
    GR_REFLECT_BIND_STORAGE_IMAGE = 1,
    GR_REFLECT_BIND_SAMPLER = 2,
    GR_REFLECT_BIND_STORAGE_BUFFER = 3,
    GR_REFLECT_BIND_UNIFORM_BUFFER = 4,
    GR_REFLECT_BIND_ACCELERATION_STRUCTURE = 5,
    GR_REFLECT_BIND_PUSH_CONSTANTS = 6
} gr_reflect_binding_kind;

typedef struct gr_reflect_binding {
    uint16_t set;
    uint16_t binding;
    uint16_t kind;         /* gr_reflect_binding_kind */
    uint16_t array_size;   /* 0: unbounded, the bindless case */
    uint32_t name;         /* string offset */
    uint32_t type_name;    /* string offset */
    uint32_t stage_mask;   /* gr_shader_stage bits that reference it */
    uint32_t member_first; /* index into gr_reflect_member, for a uniform block */
    uint32_t member_count; /* 0 when the block is opaque */
    uint32_t _reserved;
} gr_reflect_binding;

/* A member of a uniform block or a storage struct, in declaration order. `offset` is the
 * byte offset under the layout the shader was compiled with - scalar layout by contract,
 * so this is the only layout a host may assume. */
typedef enum gr_reflect_member_type {
    GR_MEMBER_FLOAT = 0,
    GR_MEMBER_FLOAT2 = 1,
    GR_MEMBER_FLOAT3 = 2,
    GR_MEMBER_FLOAT4 = 3,
    GR_MEMBER_MATRIX_FLOAT4X4 = 4,  /* row-major, 64 bytes */
    GR_MEMBER_INT = 5,
    GR_MEMBER_UINT = 6,
    GR_MEMBER_INT2 = 7,
    GR_MEMBER_UINT2 = 8,
    GR_MEMBER_UINT3 = 9,
    GR_MEMBER_UINT4 = 10,
    GR_MEMBER_INT4 = 11,
    GR_MEMBER_STRUCT = 12,
    GR_MEMBER_FLOAT2X2 = 13,
    GR_MEMBER_FLOAT3X3 = 14
} gr_reflect_member_type;

typedef struct gr_reflect_member {
    uint32_t name;         /* string offset */
    uint32_t type_name;    /* string offset */
    uint32_t offset;
    uint32_t size;
    uint16_t type;         /* gr_reflect_member_type */
    uint16_t array_size;   /* 1 for a scalar */
    uint16_t matrix_major; /* 0: row-major (the contract), 1: column-major */
    uint16_t _reserved;
} gr_reflect_member;

/* A classic vertex input. A mesh-shader pipeline has none; a vertex pipeline without one is
 * refused at pipeline creation. Semantic names are the HLSL ones, matched case-insensitively
 * against the pipeline's declaration so a typo fails at build time. */
typedef struct gr_reflect_vertex {
    uint32_t semantic;     /* string offset, without the index: "POSITION" */
    uint32_t semantic_index;
    uint32_t location;     /* the HLSL register number, as the compiled shader sees it */
    uint32_t format;       /* gr_format of the whole attribute */
    uint32_t offset;       /* byte offset in the vertex stride, from the input signature */
    uint32_t component_count;
} gr_reflect_vertex;

/* Per-stage limits. A compute shader's group size is needed to size a dispatch; a mesh
 * shader's output limits are needed by the D3D12 PSO and by Vulkan's
 * VkPhysicalDeviceMeshShaderPropertiesEXT check. */
typedef struct gr_reflect_stage {
    uint16_t stage;          /* gr_shader_stage */
    uint16_t subgroup_size;  /* an explicit required size, or 0 */
    uint32_t group_x, group_y, group_z;  /* compute */
    uint32_t output_vertices, output_primitives;  /* mesh */
    uint32_t payload_bytes;  /* task/mesh payload */
    uint32_t push_constant_offset, push_constant_size;
    uint32_t _reserved[2];
} gr_reflect_stage;

/* A permutation domain the shader reacts to: the build passes -D<name>=<value> and the
 * reflection records which names exist so the host cannot invent one. */
typedef struct gr_reflect_define {
    uint32_t name;       /* string offset */
    uint32_t default_value;
    uint32_t value_count;/* 0: open-ended (a numeric range); else the size of the values list */
    uint32_t values;     /* string offset of a comma-separated list, or 0 */
} gr_reflect_define;

/* =======================================================================================
 * Reading a blob. The reader is the only code that interprets the format; every backend
 * goes through it. It never writes to the blob and never allocates.
 * ======================================================================================= */
typedef struct gr_reflection {
    const gr_reflect_blob_header *header;
    const uint8_t *bytecode;
    const char *strings;
    const gr_reflect_binding *bindings;
    const gr_reflect_member *members;
    const gr_reflect_vertex *vertices;
    const gr_reflect_stage *stages;
    const gr_reflect_define *defines;
} gr_reflection;

/* Validates magic, version, every offset and count against blob_length, the bytecode
 * alignment, string termination, and that every name offset addresses a terminated string
 * inside the string section. Returns GR_ERROR_SHADER_INVALID with a log line on failure. */
gr_result gr_reflect_open(gr_span_u8 blob, gr_reflection *out);
/* The same, from a shader handle the device already validated. */
gr_result gr_reflection_of(gr_handle shader, gr_reflection *out);

const char *gr_reflect_string(const gr_reflection *refl, uint32_t offset);
const gr_reflect_binding *gr_reflect_find_binding(const gr_reflection *refl, uint32_t set,
                                                  uint32_t binding);
const gr_reflect_member *gr_reflect_find_member(const gr_reflection *refl, gr_str name);
/* The declared size of set 1 binding 0, or 0 when the shader declares none. A host compares
 * this with sizeof(gr_frame_constants). */
uint32_t gr_reflect_frame_constants_size(const gr_reflection *refl);
/* The digest the blob carries. A host that builds its own structs must reproduce this value
 * from its own declarations to run; a mismatch is GR_ERROR_LAYOUT_MISMATCH. */
void gr_reflect_layout_hash(const gr_reflection *refl, uint64_t out_hash[2]);

/* Recomputes the digest from the reflection tables themselves, independent of the value the
 * blob stores. This is the function the offline tool's output is checked against: if the tool
 * and this disagree, the build fails rather than the renderer reading the wrong memory. */
gr_result gr_reflect_compute_layout_hash(const gr_reflection *refl, uint64_t out_hash[2]);

/* =======================================================================================
 * Shader objects
 * ======================================================================================= */
typedef struct gr_shader_desc {
    gr_desc_head head;
    /* The reflection blob (gr_reflect_blob_header and its tables). Required: it is the only
     * description of the shader the device trusts, and it carries the layout digest. It is the
     * `.refl.bin` the offline tool writes. */
    gr_span_u8 reflection_blob;
    /* The container bytes, WITHOUT the reflection blob around them: the `.spv`, `.dxil` or
     * `.msl` file itself. A device uses the one its backend consumes and ignores the others;
     * a shader with none of the containers it understands is GR_ERROR_UNSUPPORTED. */
    gr_span_u8 spirv;
    gr_span_u8 dxil;
    gr_span_u8 msl_source;
    gr_span_u8 msl_library;
    const gr_reflect_blob_header *reflection_header;  /* may be NULL when a blob carries it */
    gr_str name;
    /* The permutation this bytecode was built for. A pipeline that declares a key requires
     * every one of its shaders to carry the same one, so a pipeline cannot silently mix an
     * unpermuted vertex shader with a permuted fragment shader. */
    uint64_t permutation_key;
} gr_shader_desc;

gr_result gr_shader_create(gr_handle device, const gr_shader_desc *desc, gr_handle *out_shader);

/* =======================================================================================
 * Shader library: resolving a permutation key to that permutation's bytecode
 *
 * The offline tool writes one set of artifacts per shader and stage, and one set per
 * permutation, named from the key:
 *
 *     <name>.<stage>.refl.bin              the no-flags build (the declared default)
 *     <name>.<stage>.<16 hex key>.refl.bin one per permutation
 *
 * A host resolves a key to bytecode through this library rather than composing file names
 * itself, so the naming convention lives in one place and a missing artifact is a specific
 * status instead of an open() that failed. Loading is lazy and cached: the first resolve of a
 * key reads and validates its blob, later resolves of the same key return the same bytes
 * without touching the filesystem.
 *
 * The library is backend-agnostic: it knows nothing about Vulkan, D3D12 or Metal, and
 * gr_shader_create_resolved() below chooses the container the device wants.
 * ======================================================================================= */
typedef struct gr_shader_library_desc {
    gr_desc_head head;
    gr_str root;      /* the directory the tool wrote, e.g. build/shaders */
    uint32_t flags;   /* reserved; 0 */
} gr_shader_library_desc;

/* One compiled variant, as discovered from the artifact layout. */
typedef struct gr_shader_entry {
    gr_str name;            /* borrowed from the library, e.g. "core/tonemap" */
    gr_shader_stage stage;
    uint64_t permutation_key; /* 0 for the no-flags build */
} gr_shader_entry;

typedef struct gr_shader_library_stats {
    gr_desc_head head;
    uint32_t shader_count;   /* distinct (name, stage) pairs */
    uint32_t variant_count;  /* distinct artifacts, including the no-flags build */
    uint32_t cache_capacity; /* slots before GR_ERROR_EXHAUSTED */
    uint32_t cache_used;
    uint64_t cache_hits;     /* resolves served from memory */
    uint64_t loads;          /* blobs read from disk and validated */
    uint64_t misses;         /* PERMUTATION_MISSING, and failed loads */
} gr_shader_library_stats;

gr_result gr_shader_library_open(const gr_shader_library_desc *desc, gr_handle *out_library);
void gr_shader_library_close(gr_handle library);
gr_result gr_shader_library_stats_query(gr_handle library, gr_shader_library_stats *out);
/* Enumerates the discovered variants in a stable order (by name, then stage, then key). */
gr_result gr_shader_library_entries(gr_handle library, uint32_t first, uint32_t count,
                                    gr_shader_entry *out, uint32_t *out_written);

/* A resolved variant. The spans and the reflection borrow the library's memory and stay valid
 * until the library is closed; a caller copies whatever it must outlive that. */
typedef struct gr_resolved_shader {
    gr_desc_head head;
    gr_shader_stage stage;
    uint64_t permutation_key;
    /* The reflection blob, which is what gr_shader_desc.reflection_blob wants. */
    gr_span_u8 blob;
    /* The container bytes as siblings, absent when this build did not produce them. */
    gr_span_u8 spirv;
    gr_span_u8 dxil;
    gr_span_u8 msl_source;
    gr_reflection reflection;
    uint32_t frame_constants_size; /* 0 when the shader declares none */
    uint32_t from_cache;           /* 1 when this resolve was a cache hit */
} gr_resolved_shader;

/* Resolves `permutation_key` for a shader.
 *
 *   GR_OK                        the variant was found; from_cache says hit or first load
 *   GR_ERROR_INVALID_ARGUMENT    no shader with that name and stage
 *   GR_ERROR_PERMUTATION_MISSING that key was not compiled (the shader exists, the variant does
 *                                not) — a build defect, not a run-time condition to retry
 *   GR_ERROR_LAYOUT_MISMATCH     the blob's frame-constant block does not match the host's
 *   GR_ERROR_EXHAUSTED           the cache is full; nothing was evicted
 *   GR_ERROR_SHADER_INVALID      the blob failed validation
 */
gr_result gr_shader_library_resolve(gr_handle library, gr_str name, gr_shader_stage stage,
                                    uint64_t permutation_key, gr_resolved_shader *out);

/* Resolves by key and creates the device shader from the container that device prefers
 * (SPIR-V for Vulkan, DXIL for D3D12, MSL for Metal). This is the whole pipeline-side path: a
 * builder names a shader, a stage and a permutation key, and gets a shader handle or a status
 * that says precisely why not. */
gr_result gr_shader_create_resolved(gr_handle device, gr_handle library, gr_str name,
                                    gr_shader_stage stage, uint64_t permutation_key,
                                    gr_handle *out_shader);

/* =======================================================================================
 * Pipelines
 *
 * A pipeline is fully baked and immutable. Every pipeline shares the bindless layout, so a
 * pipeline object carries no descriptor state at all. Pipelines are built before the first
 * frame is submitted (gr_pipeline_commit); creating one afterwards returns
 * GR_ERROR_NOT_READY, which makes a mid-frame pipeline stall impossible by construction.
 * This is Abundance's PipelineRegistry contract (engine/core/pipelines.hpp).
 * ======================================================================================= */
typedef enum gr_blend_mode {
    GR_BLEND_OPAQUE = 0,
    GR_BLEND_ALPHA = 1,
    GR_BLEND_PREMULTIPLIED = 2,
    GR_BLEND_ADDITIVE = 3
} gr_blend_mode;

typedef enum gr_cull_mode {
    GR_CULL_NONE = 0,
    GR_CULL_FRONT = 1,
    GR_CULL_BACK = 2
} gr_cull_mode;

typedef enum gr_compare_op {
    GR_COMPARE_NEVER = 0,
    GR_COMPARE_LESS = 1,
    GR_COMPARE_EQUAL = 2,
    GR_COMPARE_LESS_EQUAL = 3,
    GR_COMPARE_GREATER = 4,
    GR_COMPARE_NOT_EQUAL = 5,
    GR_COMPARE_GREATER_EQUAL = 6,  /* the default: reverse-Z */
    GR_COMPARE_ALWAYS = 7
} gr_compare_op;

typedef enum gr_topology {
    GR_TOPOLOGY_TRIANGLE_LIST = 0,
    GR_TOPOLOGY_TRIANGLE_STRIP = 1,
    GR_TOPOLOGY_LINE_LIST = 2,
    GR_TOPOLOGY_POINT_LIST = 3,
    GR_TOPOLOGY_PATCH_LIST = 4
} gr_topology;

typedef struct gr_vertex_binding {
    uint32_t slot;
    uint32_t stride;
    uint32_t step_rate;   /* 0: per vertex, 1: per instance */
} gr_vertex_binding;

typedef struct gr_vertex_attribute {
    uint32_t location;    /* matches gr_reflect_vertex.location */
    uint32_t binding;     /* which gr_vertex_binding */
    gr_format format;
    uint32_t offset;
} gr_vertex_attribute;

/* A specialization/permutation constant: a shader value set at pipeline creation, so one
 * SPIR-V/DXIL serves several pipelines without recompiling. On D3D12 these become
 * D3D12_ROOT_CONSTANTS only through a permutation compile, so the offline flow emits one
 * DXIL already specialised per permutation (shader-flow.md "Permutations"). */
typedef struct gr_specialization {
    uint32_t id;
    uint32_t value;
} gr_specialization;

typedef struct gr_pipeline_desc {
    gr_desc_head head;
    gr_str name;

    /* Shaders by stage. A vertex pipeline needs VERTEX and may have FRAGMENT; a mesh
     * pipeline needs MESH and may have TASK and FRAGMENT; a compute pipeline needs exactly
     * COMPUTE. Anything else is GR_ERROR_INVALID_ARGUMENT. */
    gr_handle shaders[GR_SHADER_STAGE_COUNT];

    /* Vertex input. Ignored for mesh and compute pipelines; required for a vertex
     * pipeline, and validated against the vertex shader's reflection. */
    const gr_vertex_binding *vertex_bindings;
    uint32_t vertex_binding_count;
    const gr_vertex_attribute *vertex_attributes;
    uint32_t vertex_attribute_count;

    /* Output. Colour formats and per-attachment blend; a missing blend entry is OPAQUE. */
    const gr_format *color_formats;
    uint32_t color_count;
    const gr_blend_mode *blend;
    gr_format depth_format;          /* GR_FORMAT_UNDEFINED: no depth attachment */
    int32_t depth_test;
    int32_t depth_write;
    gr_compare_op depth_compare;     /* GR_COMPARE_GREATER_EQUAL by default */
    int32_t depth_clamp;
    int32_t depth_bias;
    float depth_bias_constant, depth_bias_slope;

    gr_topology topology;
    gr_cull_mode cull;
    int32_t front_face_ccw;          /* 1: counter-clockwise is front (the contract default) */
    int32_t wireframe;
    int32_t conservative;
    int32_t alpha_to_coverage;

    /* MSAA: a pipeline's sample count must equal its attachments'. */
    uint32_t samples;

    /* Permutation values. The backend uses them as specialisation constants where the API
     * has them and the offline flow has already specialised the bytecode where it does not. */
    const gr_specialization *spec;
    uint32_t spec_count;
    uint64_t permutation_key;        /* from gr_permutation_key(); part of the cache key */

    gr_handle query_pool;            /* optional occlusion queries for this pipeline */
} gr_pipeline_desc;

gr_result gr_pipeline_create(gr_handle device, const gr_pipeline_desc *desc,
                             gr_handle *out_pipeline);
/* Builds every pipeline declared so far, in parallel, and persists the driver's pipeline
 * cache. After this, gr_pipeline_create returns GR_ERROR_NOT_READY. Returns the build time
 * in *out_seconds so a regression is visible. */
gr_result gr_pipeline_commit(gr_handle device, double *out_seconds);
/* What the device's pipeline cache is doing, for a startup log or a test. */
typedef struct gr_pipeline_cache_report {
    gr_desc_head head;
    uint32_t loaded;      /* 1 when an existing file was accepted at creation */
    uint32_t saved;       /* 1 when the file was written by the last commit, or by save */
    uint32_t size_bytes;  /* the cache's current size */
    uint32_t path_set;    /* 1 when a path was configured */
} gr_pipeline_cache_report;

gr_result gr_pipeline_cache_report_query(gr_handle device, gr_pipeline_cache_report *out);
/* Writes the cache now rather than waiting for a commit. GR_ERROR_NOT_READY when no path is set. */
gr_result gr_pipeline_cache_save(gr_handle device);

/* Number of pipelines declared and committed, for a startup log. */
gr_result gr_pipeline_stats(gr_handle device, uint32_t *out_declared, uint32_t *out_committed);

/* =======================================================================================
 * Permutations
 *
 * A permutation is a set of (name, value) pairs applied as -D defines at compile time. Its
 * key is a hash over the sorted pairs, so the same set in a different order yields the same
 * key and the cache cannot miss. The offline flow enumerates the cross product of the
 * domains a shader declares (gr_reflect_define), which is the only place a permutation can
 * come from; a host that asks for a define the shader did not declare gets
 * GR_ERROR_INVALID_ARGUMENT instead of a silently ignored #ifdef.
 * ======================================================================================= */
typedef struct gr_permutation_entry {
    uint32_t name;    /* gr_permutation_name_id() of the define's name */
    uint32_t value;
} gr_permutation_entry;

/* The stable id of a permutation define name: the low 32 bits of its FNV-1a 64 hash. Fixed
 * here so the offline tool and the host cannot derive different ids for the same define, which
 * would make every cache key a miss. graphics/tools/shader.mjs implements the same function
 * and graphics/src/grail_reflect_tool.c checks the two agree for every declared define. */
uint32_t gr_permutation_name_id(gr_str name);

#define GR_PERMUTATION_MAX_ENTRIES 32u

typedef struct gr_permutation {
    uint32_t count;
    uint32_t _reserved;
    gr_permutation_entry entries[GR_PERMUTATION_MAX_ENTRIES];
} gr_permutation;

/* Entries are sorted by name before hashing, so order does not affect the key. */
uint64_t gr_permutation_key(const gr_permutation *perm);
/* The key with the shader identity mixed in, which is what a pipeline cache is keyed by. */
uint64_t gr_pipeline_cache_key(uint64_t permutation_key, uint64_t shader_identity);

#ifdef __cplusplus
} /* extern "C" */
#endif

#if defined(__cplusplus) && (__cplusplus >= 201703L)
static_assert(sizeof(gr_reflect_blob_header) % 8 == 0, "blob header must keep its offsets 8-aligned");
#elif defined(__STDC_VERSION__) && (__STDC_VERSION__ >= 201112L)
_Static_assert(sizeof(gr_reflect_blob_header) % 8 == 0, "blob header must keep its offsets 8-aligned");
#endif

#endif /* GRAIL_SHADER_H */
