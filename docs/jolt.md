# Jolt, called from Grail

Abundance's physics is Jolt, and Jolt is not going to be rewritten in Grail (docs/design/
abundance-port.md, R8). Grail now calls it in process: `abundance/src/jolt.grl` holds worlds, bodies,
shapes, the fixed step, ray and capsule queries, and the contact events a gameplay loop consumes.
This page states what that covers, how the layout of every record is verified, and what the parity
program proves - and what it does not.

## Why there is a C boundary, and where it is

Jolt is C++: a world is a `PhysicsSystem` made of interfaces, bodies are `BodyID`s into a body
manager, shapes are immutable reference-counted classes, and `RVec3` changes its calling convention
with a compile define. Grail's FFI calls C symbols with C layouts, so *something* has to be the
boundary, and the only question is where. It is `abundance/tools/jolt_shim.h` - plain C functions
with scalar arguments, and a plain C `struct` for every record that crosses:

| File | What it is |
| --- | --- |
| `abundance/tools/jolt_shim.h` | the records and the C entry points. The single definition of what crosses |
| `abundance/tools/jolt_shim.cpp` | one Jolt call per function, and the engine configuration it copies, cited line by line to `engine/physics/world.cpp` |
| `abundance/tools/jolt_layout.c` | prints `sizeof`/`offsetof` of every record, compiled as C (docs/jolt.md quotes it) |
| `abundance/tools/build-jolt.mjs` | fetches the pinned Jolt, builds it with the engine's settings, links the shim, prints the table |
| `abundance/src/jolt.grl` | the Grail module: the same records, the externs, and the small wrappers |
| `abundance/tests/jolt_test.grl` | the parity program: one deterministic scene, asserted bit for bit |
| `abundance/tests/parity/jolt.cpp` | the reference: the same scene against Jolt directly, with the engine's physics header |
| `abundance/tests/jolt_layout_probe.grl` | the record round trip and the world lifecycle, as a probe |

The shim keeps three rules, and they are what make this a binding rather than a second physics:

- **a shim function is one Jolt call.** `gr_jolt_step` is `PhysicsSystem::Update`, `gr_jolt_add_box`
  is one `BoxShape` and one `CreateAndAddBody`, `gr_jolt_cast_ray` is one `CastRay` and one surface
  normal read. No integrator, no broad phase, no solver lives here;
- **the engine's configuration is copied, not invented.** The world is
  `PhysicsSystem::Init(1024, 0, 8192, 2048)` with gravity `(0, 0, -9.81f)`, the two-layer object and
  broad-phase filters, a 16 MiB `TempAllocatorImpl` and one `JobSystemSingleThreaded`, exactly as
  `world.cpp`'s `Impl` builds it. `gr_jolt_add_static_mesh` is its chunk body;
  `gr_jolt_character_step` is its `World::step`, line for line;
- **the query answer is the gameplay core's.** A `Trace` is the refusal word of
  `ab::PhysicalRefusal` plus the receipt fields of `ab::PhysicalHit`
  (`Source/AbundanceGameplayCore/Public/abundance/physical_world.hpp`), including its rule that a
  zero-length or non-finite trace is `invalid_request` rather than an empty answer.

## The records, and how their layout is verified

Grail declares the same structs in the same order with the same widths, and the compiler lays both
out by C rules - nothing is laid out by hand and nothing is cast. `bun abundance/tools/build-jolt.mjs
--table` prints the C side; on this machine (x86-64, Jolt 5.3.0):

| Record | Size | Fields (offset) |
| --- | --- | --- |
| `DVec3` | 24 | x 0, y 8, z 16 - a world position, Jolt `RVec3` under `DOUBLE_PRECISION` |
| `Vec3` | 12 | x 0, y 4, z 8 - local geometry and velocities, the core's `Vec3` |
| `Quat` | 16 | x 0, y 4, z 8, w 12 |
| `BodyState` | 56 | position 0, rotation 24, velocity 40 |
| `Trace` | 72 | refusal 0, hit 4, start_penetrating 5, point 8, normal 32, distance 56, body 64 |
| `Contact` | 28 | body1 0, body2 4, kind 8, normal 12, depth 24 |
| `Constants` | 72 | version 0/4/8, abi_ok 12, broad_phase_layers 16, max_bodies 20, max_body_pairs 24, max_contact_constraints 28, temp_allocator_bytes 32, max_physics_jobs 36, object layers 40/44, fixed_step_seconds 48, gravity_x/y/z 56/60/64 |

The C table is documentation; the check is `abundance/tests/jolt_layout_probe.grl`, and it runs in
both directions. `gr_jolt_layout_seed` writes known values through the *C* offsets of all seven
records; Grail reads every field back by *name* and counts the ones that disagree; then Grail writes
the other half by name and `gr_jolt_layout_check` reads it back at its offsets.
`jolt.layout.round_trip` must be 0, and it is the count - so a moved field is a number in the probe's
output, not a wrong body position later.

## The binary interface

Jolt's compile definitions are not build detail, they are its ABI: `RVec3Arg` is pass-by-value under
`JPH_USE_AVX` and by-reference without it, so a consumer compiled with a different set calls a
different symbol than the library exports. The defines are also bits of Jolt's version ID, and
`RegisterTypes` *aborts* on a mismatch.

`abundance/tools/build-jolt.mjs` therefore:

- fetches the archive `engine/physics/jolt.cmake` pins (Jolt 5.3.0, commit `0373ec0d`, SHA256
  `834644d7...`), and refuses an archive whose hash is not that one;
- configures Jolt with the settings `jolt.cmake` forces - `DOUBLE_PRECISION=ON`,
  `CROSS_PLATFORM_DETERMINISTIC=ON`, no IPO, no debug symbols, no profiler or debug renderer, no
  install - plus `CMAKE_POSITION_INDEPENDENT_CODE=ON`, because the archive goes into a shared object
  (PIC changes addressing, not arithmetic; the reference links the same archive);
- compiles the shim with exactly the PUBLIC defines and `-m` flags the engine's own Jolt-using
  translation units carry (its `compile_commands.json`: the JPH feature defines, `-mavx2 -mbmi
  -mpopcnt -mlzcnt -mf16c -mfpmath=sse -pthread`), plus `-ffp-contract=off`;
- and `gr_jolt_abi_check()` is Jolt's own `VerifyJoltVersionID()`, so a shim built with a different
  set reports `jolt.abi.ok 0` instead of registering into a library it does not match.

World creation also refuses when that check fails, before `RegisterTypes` can abort.

## The world surface

| Call | What it is |
| --- | --- |
| `gr_jolt_world_create` / `_destroy` | the engine's `World::Impl`, and the engine's registration refcount (the first world registers Jolt's types, the last destroy unregisters them) |
| `gr_jolt_add_box` / `_sphere` / `_capsule` | one shape and one `CreateAndAddBody`, with the motion type (static, kinematic, dynamic), the object layer and the activation word |
| `gr_jolt_add_static_mesh` | the engine's chunk body: `MeshShapeSettings(triangles).Create()`, the triangles little-endian f32 relative to the origin, the body at the origin, static, terrain layer, `DontActivate` |
| `gr_jolt_remove_body` | `RemoveBody` then `DestroyBody`, the engine's retirement order |
| `gr_jolt_step` | `Update(float(dt), 1, temp, jobs)` - the engine's one collision step |
| `gr_jolt_character_step` | the engine's `World::step`: centre = feet + half, sphere when half <= radius else capsule, `Quat::sRotation(X, 0.5 * PI)`, `MoveKinematic` on later ticks, `Update(1/30, 1)`, feet = position - half |
| `gr_jolt_rotation_x_up` | the one basis conversion, exposed so a Grail capsule never recomputes the quaternion (see below) |

The character function is a deliberate mirror, not a second controller: the portable mover decides
where the feet go (`ab::step_mover`), and this only reproduces the Jolt half of `World::step`.

## Queries and contacts

A trace is `gr_jolt_cast_ray` (one `RRayCast`, the hit point on the ray, the body's world-space
surface normal at the hit sub-shape) or `gr_jolt_cast_capsule` (one `CastShape` of a capsule whose
axis is world +Z and whose half height is centre-to-top including the cap - the core's
`PhysicalCapsule` semantics). Both apply the core's refusal: a non-finite or zero-length segment is
`invalid_request`, and an invalid capsule (radius not positive, half height below the radius) is
`invalid_request` too.

`gr_jolt_overlap_capsule` is the core's `overlap`: one `CollideShape` of the same capsule, stopped at
the first hit, answering the boolean the contract asks for - so the ground counts, an empty column of
air does not, and a capsule shorter than its own caps is `invalid_request`. Nothing about the hit's
identity crosses, because `ab::PhysicalWorld::overlap` returns a boolean, not a receipt.

The contact listener records, per step, the body pair, whether the contact was added, persisted or
removed, the world-space normal and the penetration depth - the fields a contact consumer reads. The
buffer is bounded at 1024 events per drain and counts what it dropped, because an unbounded event
queue is exactly what the engine's physics design forbids.

## The surface is closed

`engine/physics` is two translation units: `world.cpp` (the Jolt host) and `physics_module.cpp` (the
module that drives it). Between them they contain a kinematic-capsule character over streamed terrain
chunks - which the binding covers as `gr_jolt_character_step` and `gr_jolt_add_static_mesh` - rigid
bodies, ray and capsule casts, contacts and the overlap query bound here. **The engine has no ragdoll,
no articulation and no vehicle physics**: there is no joint, articulation or wheel code in the engine
tree to bind, so none is invented behind the shim. With the overlap query every call the engine makes,
and every query `ab::PhysicalWorld` states, has a shim entry; a future engine feature that needs one
more Jolt call adds one entry point the same way.

## The headless proof

`abundance/tests/jolt_test.grl` and `abundance/tests/parity/jolt.cpp` are the same program twice:
the Grail one through the shim and the FFI, the C++ one against Jolt directly with the engine's
physics header for the constants. The scene is a 40 x 40 m triangle-mesh ground, a stack of five
1 m cubes, a sphere and a capsule; 120 fixed steps of 1/30 s; body ids, and every body's
position/rotation/velocity and sleep state at ticks 0, 1, 30, 60 and 120; the contact counts of every
step and the first six added events in full; six casts (hit, miss, zero-length, capsule hit,
capsule miss, invalid capsule); four overlap cases (the ground, an empty column of air, a prop, an
invalid capsule); and the character tick over 120 ticks in a second world.

Every number is an exact bit pattern (f64 as its u64 word, f32 widened to binary64 first), so the
diff has no tolerance. All **381** values match.

Two findings that shaped the binding:

- **the capsule orientation cannot be a literal.** `Quat::sRotation(Vec3::sAxisX(), 0.5f *
  JPH_PI)` computes `sin`/`cos` of the half angle, and `std::sin(0.7853982f)` lands one ulp from the
  nearest f32 to the mathematical value. A Grail program that spelled
  `(0.70710677, 0, 0, 0.70710677)` tilted every capsule by one ulp, and the parity diff found it at
  the first tick. `gr_jolt_rotation_x_up` exposes the engine's own call instead;
- **the engine's TU is the specification, not a link.** `engine/physics/world.cpp` compiles
  headless in seconds, but linking it needs `ab::CollisionChunk`, and that drags the canonical voxel
  snapshot, the collision builder and the ground columns - the world model, not the physics surface.
  The reference therefore links Jolt and the engine's *header* (`mover_step_seconds`,
  `MoverParams`'s radius and stance heights, so a change to either fails the diff) and spells the
  world configuration with a citation per line.

## Limits, stated

- **Determinism is same-compiler, same-architecture, same Jolt build** - what the engine's own
  physics design claims. `CROSS_PLATFORM_DETERMINISTIC` plus one `JobSystemSingleThreaded` and one
  fixed step is what makes it repeatable here; the parity program would catch a drift on the machine
  that regenerates it, not promise cross-platform rigid-body lockstep.
- **No dynamic props in the engine yet.** `gr_jolt_add_box`/`_sphere`/`_capsule` are the surface Jolt
  offers and the engine's roadmap needs; the engine's own `World` class today has terrain chunks and
  the kinematic character only, and the reference's box stack is direct Jolt.
- **`World::collision` is not reachable from Grail.** A chunk body crosses as a triangle list and an
  origin, not as `ab::CollisionChunk`; the chunk lease, replacement and readiness policy stay in the
  core (`ChunkCollisionWorld`), which the physics module drives.
- **No heightfields, no water source, no vehicles, no ragdoll, no debug wireframe.** They are later
  slices in `engine/physics/DESIGN.md`, and none of them exists in the engine yet; nothing here
  claims them.
- **The layout check covers the records, not Jolt's internal structs.** None of Jolt's structs
  cross (Jolt's `Vec3` is 16 bytes with SIMD padding; ours carry the values), so there is nothing to
  compare them against - what is checked is the C header against the Grail records, in both
  directions.
