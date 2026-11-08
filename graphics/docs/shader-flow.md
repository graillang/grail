# The offline shader flow

Shaders are compiled **offline**, at cook time, never at run time. One HLSL source produces
the bytecode and the reflection every backend consumes.

```
graphics/shaders/<area>/<name>.<stage>.hlsl
        |
        |  dxc -spirv                    dxc                        spirv-cross
        +------------> <name>.<stage>.spv ---> Vulkan (Linux, Windows)
        |                     |
        |                     +-----> <name>.<stage>.msl ----> Metal (macOS)
        +------------> <name>.<stage>.dxil -------------------> D3D12 (Windows)
        |
        +------------> <name>.<stage>.refl.bin + .refl.json      every backend
```

`<stage>` is `vs`, `ps`, `cs`, `ms`, `as` (entry `main`) or `lib` (ray tracing, any entries).
A file name states its stage, so the build can glob for it and a shader cannot be compiled
for the wrong stage by accident. This naming is Abundance's
(`<name>.<stage>.hlsl`, `abundance/engine/CMakeLists.txt`).

## The exact DXC flags

Verified working against **DXC 1.9.2609.5**, the version Abundance pins
(`abundance/engine/tools/fetch.sh`, `dxc|1.9.2609`). Flags for SPIR-V:

```
-spirv
-fspv-target-env=vulkan1.3
-HV 2021
-enable-16bit-types
-fvk-use-scalar-layout
-Zpr
-fspv-use-unknown-image-format
-O3
-Wno-conversion -Wno-ignored-attributes
-I graphics/shaders/include
-T <stage>_6_6 -E main
```

and for DXIL the same minus the four `-fspv-*`/`-spirv` flags.

Why each is load-bearing:

| flag | why |
| --- | --- |
| `-spirv -fspv-target-env=vulkan1.3` | Vulkan 1.3 is the device floor, so the SPIR-V must not use a newer target environment |
| `-HV 2021` | HLSL 2021: templates and `enum class`; matches Abundance |
| `-enable-16bit-types` | 16-bit floats for packed vertex data; the capability is required |
| `-fvk-use-scalar-layout` | the frame constants layout; without it std140 applies and `gr_frame_constants` offsets are wrong |
| `-Zpr` | row-major matrices, matching the column-vector convention in `grail_rhi.h` |
| `-fspv-use-unknown-image-format` | bindless storage textures of any format, which is the whole point of the storage-image table |
| `-T <stage>_6_6` | shader model 6.6, the profile the D3D12 backend requires |
| `-Wno-ignored-attributes` | `[[vk::push_constant]]` and `[[vk::binding]]` are unknown to the DXIL path; the warning is expected, not a fault |
| `-O3` | as Abundance. A debug build of a shader is a separate, explicit target |

`-fspv-reflect` is **not** used for shipped bytecode: Abundance does not enable its SPIR-V
extensions on the device (`abundance/engine/core/DESIGN.md` "Shaders"). Reflection is
extracted at build time instead and shipped beside the bytecode, so the runtime needs no
reflection capability at all.

## Bindings: verified, not assumed

DXC's default mapping, confirmed with `spirv-dis` against 1.9.2609:

```
register(xN, spaceM)   ->   DescriptorSet M, Binding N
```

So one spelling serves both Vulkan and D3D12: `space` is D3D12's register space and becomes
the Vulkan descriptor set, and the register index becomes the binding. `[[vk::binding(n,m)]]`
is Vulkan-only and is *ignored* when a `register()` is also present, which is why
Abundance's header (Vulkan-only) uses the attribute while this one uses registers.

The numbers are chosen so that every `(set, binding)` pair is unique across descriptor
classes, because Vulkan requires unique bindings per set while D3D12 keeps `t`, `u`, `s` and
`b` in separate namespaces:

| resource | set | binding | HLSL | D3D12 register | Vulkan type | Metal |
| --- | ---: | ---: | --- | --- | --- | --- |
| sampled images | 0 | 0 | `Texture2D[]` | `t0` | SAMPLED_IMAGE | argument buffer 0 |
| storage images | 0 | 1 | `RWTexture2D[]` | `u1` | STORAGE_IMAGE | argument buffer 1 |
| samplers | 0 | 2 | `SamplerState[]` | `s2` | SAMPLER | argument buffer 2 |
| storage buffers | 0 | 3 | `RWByteAddressBuffer[]` | `u3` | STORAGE_BUFFER | argument buffer 3 |
| acceleration structures | 0 | 4 | `RaytracingAccelerationStructure[]` | `t4` | ACCELERATION_STRUCTURE | argument buffer 4 |
| frame constants | 1 | 0 | `ConstantBuffer<>` | `b0` | UNIFORM_BUFFER_DYNAMIC | buffer 5 |
| push constants | — | — | `[[vk::push_constant]] ConstantBuffer<>` | root constants `b0` | PUSH_CONSTANT | `setBytes`, index 6 |

Two findings that shaped this, both from compiling real shaders:

1. **`RWByteAddressBuffer` is a UAV (`u`), not an SRV (`t`).** Declaring it at `t1` is a
   compile error ("invalid register specification, expected 'u' binding"). D3D12 also puts a
   read-only `ByteAddressBuffer` in the SRV class, so two declarations would need two
   bindings and a buffer would have to know which access a shader would use. Grail therefore
   has **one** storage-buffer table, declared read-write; a read-only buffer is simply never
   stored to.
2. **Push constants must be `[[vk::push_constant]]`.** A plain `cbuffer` at `b0` becomes a
   *descriptor* at set 0 / binding 0 and collides with the sampled-image table — verified:
   DXC emits `DescriptorSet 0 Binding 0` for a non-attributed `b0`. With the attribute, DXC
   emits a SPIR-V `PushConstant` block (no descriptor at all) and the DXIL path ignores the
   attribute while keeping `b0` for the root signature. One declaration, both backends,
   confirmed both ways.

Abundance's numbers differ (`0/1/2/3` by type, via `[[vk::binding]]`) because it ships only
Vulkan. The difference is deliberate and is the cost of the second and third backend.

## Reflection

Reflection is a build artifact in a fixed binary format (`gr_reflect_blob_header`, defined in
`grail_shader.h` and read only by `graphics/src/grail_reflect.c`). It travels *inside* each
shader's container:

```
[header][bytecode][string section][bindings][members][vertices][stages][defines]
```

Contents: the entry point, every binding with its set/binding/kind/array size, every
constant-block member with its byte offset and type, every vertex input with its semantic
and location, per-stage limits (compute group size, mesh output limits, push-constant range),
the permutation domains the shader reacts to, the compiler version and the exact command
line, and the layout hash.

The reader trusts nothing: magic, version, exact length, bytecode alignment, every table
range checked against the header with overflow-safe arithmetic, and every string offset must
address a terminated string inside the string section. A malformed blob is
`GR_ERROR_SHADER_INVALID`, never a read past the end.

Because one reflection blob is produced from the HLSL front end, a pipeline's bindings,
vertex inputs and constant-block layout cannot drift between Vulkan, D3D12 and Metal.

## The layout hash

Abundance stamps a hash of its shared GPU structs beside its shaders and has the host refuse
a mismatch (`abundance/engine/tools/layout_hash.cmake`): a half-failed build once put new
shaders beside an old host, which read the structs as garbage and page-faulted the GPU.

Grail carries a 128-bit digest of every GPU-visible type inside each reflection blob, so a
blob can never be separated from the layout it was built against. A host computes the same
digest from its own structs; `GR_ERROR_LAYOUT_MISMATCH` means refuse to run.

`graphics/shaders/include/grail_gpu_scene.hlsli` holds the shared GPU structs and is the file
the digest is computed over. Every change to it changes the digest, which is the intent.

## Metal

There is no Metal compiler for HLSL. The path is HLSL → DXC → SPIR-V → **SPIRV-Cross** → MSL
3.0 (`--msl --msl-version 30000`), then `xcrun metal` for a `.metallib` if the build wants a
pre-compiled library instead of load-time source compilation.

The binding model survives because SPIRV-Cross lays a descriptor set out as one argument
buffer: set 0 becomes `buffer(0..4)` holding the same unbounded arrays in the order
`grail_bindless.h` declares them, set 1 becomes `buffer(5)`, and push constants become
`setBytes()` at index 6. Metal requires argument-buffer **tier 2** for arrays of textures and
samplers inside an argument buffer, so `grail_backend_metal.h` requires macOS 13 and tier 2.

Two Metal differences the backend absorbs, not the caller: there is no depth clamp and no
"unknown format" for storage images (a storage texture is typed by its view).

**SPIRV-Cross is not installed on this host** (`spirv-cross` is missing), so the Metal leg of
the tool refuses with a clear message rather than emitting nothing. That is the one shader
dependency this repository does not already have.

## Permutations

A permutation is a set of `(name, value)` pairs applied as `-D` defines at compile time. Its
key hashes the pairs *sorted by name*, so enumeration order cannot cause a cache miss
(`test_abi` asserts this). The domains come only from the shader's own declared
`gr_reflect_define` list: a host that asks for a define the shader did not declare gets
`GR_ERROR_INVALID_ARGUMENT` instead of a silently ignored `#ifdef`.

D3D12 has no specialization constants, so the offline flow emits one DXIL per permutation
where the bytecode actually reads the define; Vulkan may use `VkSpecializationInfo` for the
same pipeline. `gr_specialization` carries the values either way.

A shader declares its domains in a comment the compiler ignores:

```hlsl
// grail:permutation GRAIL_TONEMAP_EXPOSURE default=1 values=0,1
// grail:permutation GRAIL_TONEMAP_OUTPUT   default=0 values=0,1
```

The tool reads those, writes them into the blob as `gr_reflect_define` records, and enumerates
the cross product with a key per combination (`--permutations` prints them). Four properties
that make this safe:

- **The directive cannot change what the shader compiles to.** It is a comment; the shader also
  carries `#ifndef … #define` defaults, so a plain DXC invocation compiles the default.
- **A host cannot invent a define.** The declared set is in the blob, so a request outside it is
  `GR_ERROR_INVALID_ARGUMENT` rather than a silently ignored `#if`.
- **The cross product is bounded** (256). Exceeding it is an error naming the count, not a build
  that quietly produces a hundred thousand shaders.
- **The name ids have one definition.** `gr_permutation_name_id` is the low 32 bits of the
  name's FNV-1a 64 hash; the C implementation and the tool's implementation are compared by
  `make shader-check`, which fails if they disagree.

Comparing the ids matters because the key is folded from ids, not names: two implementations
deriving different ids for `GRAIL_TONEMAP_OUTPUT` would make every cache key a miss. Observed
agreement on the two defines above: `GRAIL_TONEMAP_EXPOSURE` → `0xabe4a289`,
`GRAIL_TONEMAP_OUTPUT` → `0x199f71d9`, four combinations, keys
`0xf6510c514cdc3fd9` … `0x01b3872a5c56107d`.

### Each combination is compiled

Enumeration alone would prove nothing about the shader. Every combination is therefore built
for real, with its `-D` flags, through exactly the same flag path as the base build:

```
tonemap.ps.spv                     the no-flags build (equals the declared default combination)
tonemap.ps.dxil
tonemap.ps.refl.bin
tonemap.ps.<key>.spv               one per combination, <key> the 16-hex permutation key
tonemap.ps.<key>.dxil
tonemap.ps.<key>.refl.bin
tonemap.ps.refl.json               every variant's digests, keys and defines
```

Two digests measure different things, and the difference is the point:

| digest | must | why |
| --- | --- | --- |
| `spirv_sha256` / `dxil_sha256` | **differ** per combination | otherwise the `-D` never reached the compiler |
| `layout_hash` | **not differ** | bindings and constant-block layout are declarations, not code; if a permutation changed the layout, the host's structs would be wrong for that combination only |

`make -C graphics perm-test` asserts both, and `shader-check` verifies every per-permutation
blob with the C reader, so 7 blobs are validated rather than 3.

The tests were checked against deliberate regressions rather than assumed to work: dropping the
`-D` flags, building a variant's blob from the base bytecode, changing the directive default,
and mismatching the `#ifndef` default each fail the specific assertion meant to catch them. The
last two matter because the shader carries *two* declarations of its defaults — the directive
and the `#ifndef` — and the test asserts that the no-flags build is byte-identical to the
variant whose flags equal the declared defaults. The first version of that test passed while a
directive default was deliberately wrong; it now compares the two builds instead of naming a
combination.

Observed for `tonemap.ps`, 4 combinations, all with layout hash unchanged:

| key | defines | SPIR-V | DXIL |
| --- | --- | ---: | ---: |
| `0xf6510c514cdc3fd9` | exposure 0, output 0 | 3440 B | 5820 B |
| `0xe2b8c0215166c65c` | exposure 0, output 1 | 3768 B | 6124 B |
| `0xd756454841ecf5b8` | exposure 1, output 0 | 3592 B | 6068 B |
| `0x01b3872a5c56107d` | exposure 1, output 1 | 3920 B | 6296 B |

Not yet done: selecting a variant at pipeline creation. `gr_pipeline_cache_key` exists and is
tested, and a pipeline descriptor carries `permutation_key`, but no backend resolves a key to
a bytecode file yet — that arrives with the first backend.

## Backend requirements

**Vulkan (Linux, Windows)** — Vulkan 1.3 floor. Required: descriptor indexing with
update-after-bind, partially bound and non-uniform indexing on sampled and storage
descriptors; buffer device address; dynamic rendering; `synchronization2`; timeline
semaphores; scalar block layout; `shaderInt16`/`shaderInt64`. Optional and reported: mesh and
task shaders (`VK_EXT_mesh_shader`), 64-bit image atomics, float atomics, conservative
rasterisation, calibrated timestamps, memory budget, subgroup size control. The instance
needs the surface extensions SDL3 reports.

**D3D12 (Windows)** — feature level 12_0 floor, 12_1/12_2 used when present. Windows 10
build 19041 or later for the Agility SDK device path. Shader model 6.6 DXIL is not
retargeted at runtime, so a driver without it is refused. The root signature is: 128 bytes of
root constants at `b0`, four unbounded descriptor ranges in space 0 (`t0`, `u1`, `s2`, `u3`),
and one root CBV `b0` in space 1. **DXIL must be signed** — `dxil.dll` from the same DXC
release has to be beside `dxc` or the compiler refuses the DXIL target.

**Metal (macOS)** — macOS 13, Metal 3, argument buffer tier 2, MSL 3.0 via SPIRV-Cross.

## The tool

`graphics/tools/shader.mjs` runs the whole flow:

```
node graphics/tools/shader.mjs --all              # every shaders/**/<name>.<stage>.hlsl
node graphics/tools/shader.mjs <file.hlsl>...     # named files
node graphics/tools/shader.mjs --all --no-dxil    # SPIR-V only
node graphics/tools/shader.mjs --all --metal      # also emit MSL when SPIRV-Cross is present
make -C graphics shader-check                     # compile, then verify with the C reader
```

For each shader it emits `<name>.<stage>.spv`, `<name>.<stage>.dxil` (when DXC can sign it),
`<name>.<stage>.refl.json` and `<name>.<stage>.refl.bin`. It resolves DXC from `$DXC`, then
Abundance's pinned tools cache, then `PATH`, and prints the version it used. Options are held
in one table in the file, so the flag set above has a single definition.

Reflection is extracted by parsing the compiled SPIR-V's decorations — `OpDecorate`
`DescriptorSet`/`Binding`, `OpMemberDecorate` `Offset`, `OpType*`, `OpVariable` and
`OpEntryPoint`. Every read is bounded by the instruction's own word count. Push constants are
excluded from the binding table (they occupy no set and binding, and listing them at an
invented `(0,0)` would collide with the sampled-image table); their size is recorded on the
stage record instead. Vertex inputs are extracted only for the vertex stage, and a built-in
such as `SV_VertexID` is not an attribute even when it arrives as an `Input` variable.

## Verification

`make -C graphics shader-check` compiles the shaders and then opens every blob with
`graphics/src/grail_reflect_tool.c`, which is a *second, independent* implementation of the
format. It fails the build on any of:

- a blob the reader rejects (magic, version, exact length, alignment, table ranges, string
  termination);
- `gr_reflect_frame_constants_size()` disagreeing with `sizeof(gr_frame_constants)`;
- any frame-constant member offset or size differing from `offsetof(gr_frame_constants, …)`;
- the stored layout digest differing from the one the C implementation recomputes.

That last check is what keeps the tool and the host honest: the digest is computed twice, in
different languages, and a divergence fails here rather than in the renderer.

Verified on this host: `frame_setup.cs`, `fullscreen.vs` and `tonemap.ps` all compile, pass
`spirv-val --target-env vulkan1.3`, produce the binding numbers in the table above, report
416-byte frame constants whose 18 members match `offsetof` exactly, and carry a matching
digest. The Metal leg reports that SPIRV-Cross is absent and continues rather than failing.
