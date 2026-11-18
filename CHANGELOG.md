## Unreleased

- **The crafting screen's classifier is ported.** `abundance/src/crafting_menu.grl` carries
  `ui/crafting_menu.hpp/.cpp` of `cmake/tx/crafting_menu.cmake`: the ten categories and their
  display labels (Machines reads "Facilities"), every sub-type group with its display rank and
  out-of-range fallback, and the 123-rule first-match classification table (prefix at the id's
  start, `contains` searched from the prefix's end), with `craft_class`'s catalogue-label
  overrides (Building Part, Farming unless the item is food, then Tool/Weapon/Machine/Electrical,
  else Materials group 0). `abundance/tests/crafting_menu_test.grl` prints 328 lines that match a
  reference compiling the engine's own `crafting_menu.cpp`, probing every rule and 37 realistic
  products.

- **Abundance's biomes tool is ported: validation and every generated output reach byte parity.**
  `abundance/src/biomes.grl` reproduces `engine/tools/biomes.py`'s `--check` (every error and warning
  in the reference's order) and `--generate` — terrain_palette.json, biome_canopy_mix.ush,
  biome_fold.ush, biome_near_density.ush, near_field.json and the deterministic
  Saved/BiomeCuration/biomes_status.json — on `abundance/src/pyjson.grl`, a shared module carrying
  Python's json semantics (canonical, `dumps(indent=)`, `repr` float layout) that the content tool now
  uses too. The suite drives both implementations on identical staged trees: 24 reference lines and
  six generated files compared byte for byte, with the reference run from a staged copy because its
  status report would otherwise write into the human's checkout (that one CURATION line is the copy's
  only difference). Not ported, recorded: `write_to_download` reads the machine's free disk space.
- **The island generator's gradient noise kernels are ported bit for bit.** `abundance/src/
  worldgen_noise.grl` carries `gradient_noise`, `gradient_fbm` and `ridged_multifractal` from the
  shared `engine/base/worldgen_noise_impl.hpp` (rotated mix64 lattice mixes, the eight-entry
  gradient table, ab::pm's straddle lerp, f64 octave accumulators narrowed once); 144 values
  matched against the header compiled with the worldgen library's `-ffp-contract=off`. These are
  the bands the coherent terrain relief is built from.

- Abundance port: `abundance/src/lake_topology.grl` is the `<cache>.lake-topology` sidecar
  (docs/BOOT_LAKE_TOPOLOGY_CACHE.md) in both directions: the "ABWLTSC1" magic with the writing
  binary's generator version and reserved word, then LandscapeLakeModel's stored topology - the
  geometry, surface and boundary outlets, the depression hierarchy (52-byte nodes with parent/child/
  pit/spill ids and merge/spill/capacity/marginal storage, vertex and triangle owners, four capacity
  ranges, 36-byte pieces) and the facet routing (primary/secondary/order receivers, fractions,
  slopes, spill levels, terminals) - raw little-endian with the writer's block-wise FNV-1a checksum.
  `decode` performs the sidecar wrapper check and every rule LandscapeLakeModel::read_topology
  makes (versions, byte-order probe, lattice admission, packed-record shapes, every index range,
  the capacity ranges, the checksum and exact consumption); doubles stay bit patterns. The reference
  `abundance/tests/parity/lake_topology.cpp` compiles the engine's codec and save path: it
  generates the suite's 64 x 64 landscape world, saves its cache with `save_world_cache` (which
  writes the real sidecar through the engine's own writer), decodes it with the engine's
  `read_topology`, and asserts its layout walk agrees with `read_topology` on every file. It also
  builds a small synthetic model through LandscapeLakeModel's public constructor and mutates it.
  `abundance/tests/lake_topology_test.grl` matches all 72 lines - the 235 KB real sidecar
  round-trips byte for byte, and 24 malformed files reach their intended refusals.

- **The subsurface probe's ore and oil indicators are ported, with `ab::pm`'s exp, log and pow.**
  `worldgen_pm.grl` gains the portable-math exponentials the indicators ride: `exp` over the
  header's 128-entry 2^(j/128) table (embedded as the exact bit patterns it compiles to), `log`
  with its split2 decomposition, and `pow` through `exp(y log x)`. `worldgen_subsurface.grl`
  computes `sample_subsurface`'s four indicators: the vein Gaussians at 440/620/760 m and the oil
  layer at 790 m scaled by its trap's show halo, all in the C++'s f32/double split. The feature
  parity fixture now probes 32 points (four positions at eight depths, every Gaussian centre
  included) and all ten sample fields; `features.txt` carries 4974 bit-exact values.
- **The recorded input's float view is gated against the engine's own deserializer.** The world
  model derives the input floats exactly as `deserialize_mover_input` does (`axis_value` is the
  i16 over 32767 in double narrowed to f32, `yaw_degrees` the u16 times 360/65536,
  `pitch_degrees` the i16 times 90/32767), so the movement kernel's seam starts from the engine's
  values rather than a re-derived approximation. The replay compares the bit pattern of every
  field of all 48 recorded samples against the C++ deserializer's output (1 393 reference lines).

- **ab::CoherentField2D, the standard basis every coherent terrain field samples through, is
  ported.** The u64 world-seed fold into the noise seed, the generator's exact construction
  sequence over the FastNoiseLite port (noise type, frequency, fractal state; the warp object's
  type/amplitude/progressive octaves), warp-then-sample, and the C++ constructor's and sample()'s
  refusals as typed verdicts. 136 values matched against the real facade linked from the worldgen
  library.
- **The manufacturing domain's machine wear model is ported.** `abundance/src/
  manufacturing_maintenance.grl` carries the run half of `machine_maintenance.hpp/.cpp` and the
  manufacturing adapter's content (`manufacturing_maintenance.hpp/.cpp`, cmake/tx/manufacturing):
  the fault and machine definitions with their rules, the condition state and isolation bits, the
  load-basis-point conversion, the checked wear accrual with its numerator remainder carried
  across runs, the availability and status classification, the run path's guards (sequence,
  revision, time, runtime and load bounds, the shutdown fault, the wear limit) and fault
  triggering at each trigger wear, and the industrial/food machine definitions with their
  service, wear and breakdown ladders. `abundance/tests/manufacturing_maintenance_test.grl`
  prints 79 lines that match a reference driving the engine's real MachineMaintenanceAuthority
  through `libabundance_gameplay_core.a`, including a 2375-hour fault ladder. The replay store,
  the inspection/repair commands and the snapshot codec are later increments.

- **Jolt physics is bound to Grail, and a 373-value parity program gates it.** `abundance/src/jolt.grl`
  calls Jolt 5.3.0 (the commit `engine/physics/jolt.cmake` pins) through a C shim
  (`abundance/tools/jolt_shim.h/.cpp`) built the way the engine's physics builds it:
  `DOUBLE_PRECISION`, `CROSS_PLATFORM_DETERMINISTIC`, the JPH defines that are part of Jolt's binary
  interface, and one `libJolt.a` shared by the shim and the reference. It exposes the surface
  `engine/physics/world.cpp` uses - the engine's world configuration, box/sphere/capsule/mesh bodies,
  add/remove, the 1/30 s step, the character mirror of `World::step`, ray and capsule casts carrying
  the core's refusals, and bounded contact events. The parity program
  (`abundance/tests/jolt_test.grl` against `abundance/tests/parity/jolt.cpp`, which drives Jolt
  directly with the engine's physics header) prints a deterministic box-stack scene as exact bit
  patterns - transforms, sleep state, every step's contact counts, six queries and 120 character
  ticks - and matches all 373 values. `abundance/tests/jolt_layout_probe.grl` checks every record's
  layout in both directions and the world lifecycle; docs/jolt.md records the binding and two
  findings: Jolt's `sRotation` capsule quaternion cannot be spelled as a decimal literal (one ulp
  off, caught by the parity at tick 0), and `world.cpp` is the specification rather than a link
  because its collision path's closure is the canonical voxel snapshot.
- **The island's world features are ported: sites, cave entrances, strategic regions and transport
  corridors, with the seeded fields and portable math they are placed by.** `abundance/src/
  worldgen_pm.grl` ports ab::pm exactly (sin/cos over the header's Cody-Waite reduction - not
  lib/math.grl's fdlibm, which differs in the last bit - plus lerp, hypot and std::remainder);
  `worldgen_field.grl` carries mix64/hash01/value-fbm noise and sample_grid from the world
  generator; `worldgen_subsurface.grl` the seeded bedrock and the cave-openness field (tubes,
  chambers, the connected tunnel); `worldgen_world.grl` the raster state; `worldgen_features.grl`
  the pass itself: the defensibility raster, the shared site census (11 kinds, thresholds, caps,
  the farmland reserve, spaced greedy selection, per-site measures), entrance probing on the 220 m
  grid with the 520 m separation, the 4x4 strategic regions and the corridors joining major
  complementary sites. `features_test.grl` re-derives all of it from three generated worlds and
  matches `parity/features.txt` line for line: 4302 bit-exact values, including the two
  intermediate rasters' digests, a cell-for-cell defensibility agreement and the entrance score
  tie count (zero on every seed, which is what makes the C++'s unstable sort order reproducible).
  `abundance/tests/parity/features.cpp` is the reference, built against the worldgen library.
- **The world model's reset drops the clock with the session, and the epoch/iteration rules get
  their own gates.** `abundance/src/world_model.grl`'s `reset` now zeroes the canonical clock:
  `Session::reset` drops the `HostCore` and a fresh `create` starts at time zero, so keeping the
  old frontier was wrong. The replay proves the two staleness rules a frame boundary exists for:
  identical state under a different `game_epoch` produces different frame bytes (so no cache
  survives an epoch), and iteration is the key order — spawns arriving 5, 4, 6 read 1, 4, 5, 6,
  a duplicate is refused and an erase in the middle leaves the rest ascending (1 201 reference
  lines).

- **Abundance's content tool is ported: `inspect`, `cook` and `verify` reach byte parity.**
  `abundance/src/content.grl` reproduces `engine/tools/content.py`'s bounded manifest inventory and
  audio-index closure, the deterministic cook into a SHA256-named package (same directory name, same
  `package.json`, same payloads) and the verify that re-derives the identity — in Python's exact
  canonical form (`sort_keys`, compact separators, `ensure_ascii=False`, `repr` float layout), with
  SHA-256 from `lib/sha256.grl`. The suite drives the ported program and the reference with the same
  argv and diffs stdout, stderr and the exit status over 15 scenarios: the real
  `engine/content/switch_inventory.json`, a payload/audio fixture, cook and its idempotent repeat, a
  package the *Python* tool cooked (the implementations verify each other), corrupted and renamed
  packages, and eight refusals. New `--only=NAME` runs a single tool's program. Recorded boundaries:
  `gc`/`heal`/`cook-cache`'s flock (no advisory locks or link counts in `fs`), `start` (execve), and
  interpreter-worded OSError/TypeError cases.
- **FastNoiseLite, the noise the world generator is built on, is a bit-exact Grail port.** All six
  noise types, fBm/ridged/ping-pong, the cellular distance/return matrix, the 3D rotation types and
  domain warp, in both template instantiations (the generator samples with doubles); the four
  lookup tables are the compiled C++ tables' exact bits and the derived constants are the C++
  compiler's. A new `fastnoise` suite gates 610 values against the vendored header built with
  `-ffp-contract=off`, the flags its worldgen library uses: this is the substrate on which the
  generator's terrain bytes are reproducible at all.

- **The electrical grid's state machine and dispatch are ported, byte for byte against the
  engine.** `abundance/src/power_grid.grl` carries `power_grid.hpp/.cpp` of
  `cmake/tx/power.cmake` (minus the publication binding): the five record types and the EMP
  projection, the acceptance rules, add/replace/set/remove over sorted unique ids with the
  instance-generation bump and projection clearing, and `dispatch` — electrical islands by
  union-find, per-island shortfall bounding battery discharge, Dinic's max flow in doubles with
  the engine's 1e-7 epsilon, merit order (dispatch_order then id), load service in
  PowerPriority rounds, discharge floors, and charging from a bus's unused generation assigned
  to same-bus producers in merit order — plus `force_field_passable`.
  `abundance/tests/power_grid_test.grl` prints 175 lines that match a reference linked from the
  engine's own `power_grid.cpp` through `libabundance_gameplay_core.a`, including the engine's
  own test scenarios and its FRPG1 codec legs: the encoded size and FNV hash, the decode/encode
  round trip, trailing bytes, an over-limit bus count, an unknown-bus snapshot and a corrupted
  producer kind byte all refused with the live state unchanged, the canonical-zero rule that
  refuses every -0.0 snapshot field and setter, and the instance-generation table the encoder
  appends once a record is replaced.
- **The world model grows the generic component set and shares the tx vocabulary.** Components
  are now a `ComponentSet<T>` primitive (`abundance/src/world_model.grl`): ascending keys beside
  values, insertion in key order, duplicate keys refused, erase/index/at/value_mut — the keyed-table
  shape `ab::tx::PagedRows` and HostCore's pawn map have, as the thing gameplay lanes instantiate
  once per component type (the pawn is its first instance, and the 48-tick replay gate came
  through the refactor line for line). The registry is the tx table `engine.entities`: the frame
  now carries its table id in its bytes, and the world uses `abundance_tx`'s `world_actor` /
  `engine_id_base` / `table_entities` instead of restating them. The replay also walks the
  registry's lifecycle now — a duplicate spawn is refused and a remove erases the row and its
  component, with the remaining encoding and FNV gated against the real `ab::tx::EntityRows`
  insert/erase/encode (1 184 reference lines).

- **`lib/earcut.grl`: mapbox earcut triangulation, ported from the vendored C++.** The Abundance
  water-geometry callers (`water_geometry.cpp`) triangulate their bank, island and raster-cell
  polygons with `mapbox::earcut<std::uint32_t>` rather than Clipper2's experimental triangulator, so
  this is that library's ear clipper in pure Grail: the ring winding pass, the hole-elimination
  bridges (Eberly's leftmost-ray bridge), duplicate/collinear filtering, the three repair passes
  (filter, local self-intersection cure, diagonal split), and the z-order hashing walk that starts
  once a polygon passes 80 vertices. The emitted index stream is vertex-for-vertex identical to the
  vendored library, including its `std::sort` tie order for holes that share a leftmost x (the port
  replicates libstdc++'s introsort permutation) and its behaviour on inputs it cannot triangulate
  (a self-crossing bowtie keeps only the triangle it can form; rings under three points and fully
  collinear rings emit nothing). Gated as `lib-earcut` over `tests/lib/earcut`: 30 cases produced by
  `tests/lib/reference/earcut_corpus.cpp`, which compiles the vendored earcut.hpp and the engine's
  own `water_geometry.cpp` unmodified - real buffered river centrelines, hairpin buffers and raster
  cell unions with holes, plus crossing, hole-touching, nested, duplicate and degenerate shapes on
  both sides of the hashing threshold.

- **The power domain's generation assessment is ported, bit for bit against the engine.**
  `abundance/src/power_generation.grl` carries `power_generation.hpp/.cpp` of
  `cmake/tx/power.cmake`: the seven limits, the canonical acceptance rules (finite, signbit-free,
  at most the limit, so -0.0 is a distinct input from +0.0), the three config validators
  (station service strictly below the rated gross output, cut-in strictly below cut-out), the
  wind curve (resource `0.5 rho A v^3` with the world-event multiplier applied to speed before
  the cube, cut-in/cut-out boundaries, rated cap, availability scaling), the solar irradiance
  product, and geothermal station service consumed before the net offer.
  `abundance/tests/power_generation_test.grl` prints 122 lines that match a reference linked
  from the engine's own `power_generation.cpp` through `libabundance_gameplay_core.a`. The grid
  half (PowerGrid, dispatch, the offer_* adapters) is a later increment.

- Abundance port: `abundance/src/frw.grl` is `world.frw`, the world's public runtime payload, in both
  directions - the FRW2 header (schema 5, resolution, seed, map size and sea level as binary64 bit
  patterns), the 32 self-describing fields (u16-length names and units, a type byte for f32/u16/u8/
  u32/f64, a u64 count, then the values; type-5 doubles stay bit patterns because a Grail f64
  canonicalises NaN payloads), and the reader's rules from `world_tests.cpp`: magic, schema, the
  exact field count, every field header and value range, the six drainage fields' shapes and shared
  node count, and the two biome-authority rasters at cell_count. `abundance/tests/frw_test.grl`
  matches `parity/frw.cpp` on the 382 KB `world.frw` the engine's own `ab::export_world` writes for
  the suite's seed-1/resolution-64/1024 m world, a four-cell synthetic world (every value type,
  -0.0, infinity, NaN payloads, u16/u32 extremes) and thirteen malformed files that each reach their
  intended refusal; the writer round-trips byte for byte. 118 reference lines. Recorded: the on-disk
  magic is "FRW2" - the docs call the format ABW2, but the AB rename kept the FR wire bytes
  (Abundance 8071d8c2ca) - and like the engine's assert-based reader, decoding does not require EOF
  after field 32, which the trailing-bytes case pins.
- **The Abundance day/night sky model and season lock are ported, bit for bit against the engine.**
  `abundance/src/sky_model.grl` carries `ab::sky::DayNightSkyModel` of
  `cmake/tx/render_sky.cmake`'s `ab_sky_policy` (`day_night_sky_model.cpp`): canonical input,
  the celestial state (solar declination and equation of time, hour angle, the sidereal frame the
  star field rotates in, the compact lunar orbit, phase and illuminated fraction), phase weights,
  the biome-biased sunset palette and its display refinement, the full 47-field render-parameter
  block, the FNV determinism signature over the fields clients compare, the exposure/leak/occlusion
  policy, `SmoothPresentation` and `ValleyMistFloorMetres`. `abundance/src/world_season.grl` is
  the season lock (`world_season.cpp`), and `abundance/src/sky_float.grl` the exact numeric
  helpers it shares (an exact `fmod`, positive modulo, degree normalisation, finiteness).
  `abundance/tests/parity/sky.cpp` compiles those two engine sources with `-ffp-contract=off` and
  prints 669 values; `abundance/tests/sky_test.grl` reproduces every one — four complete Evaluate
  outputs, the canonicaliser's fallbacks and eleven refusals, bands, solar fraction, sidereal,
  exposure limits, leak/occlusion, smoothing (including the NaN, zero-elapsed and invalid-previous
  paths), gamut mutations, valley mist and the whole season block, with the locked season's effect
  on Evaluate measured against the engine's own `SetActiveSeason`. The engine's process-wide
  active season is host glue, so the port takes the locked solar-year day as an explicit
  parameter (quiet NaN = no lock).
- `math::asin` and `math::fmod` (earlier in this release) are what the sky port needed; `lib/clone.grl`'s
  `Clone` is not used because `@derive(Clone)` loses `f32` fields (reported separately, with a repro).
- Abundance port: `abundance/src/abcmesh.grl` is the `.abcmesh` character-mesh codec - the version-5
  container (render vertices with their topology split at UV seams, rigid joints, twelve influences
  per vertex with unorm16 weights, centres of rotation, rest positions, tangent rings and sparse
  fp16 blendshape deltas as CSR arrays, packed masked/two-sided submesh words, channel names,
  Multi-PIE landmarks, two eyes) with every reader admission bound, exact consumption, and
  `validate`'s exact diagnostic strings. `abundance/tests/abcmesh_test.grl` matches the C++ codec
  byte for byte on fixtures written by the engine's own encoder (a skinned body, a rigid head, a
  morph face, the engine's one-triangle mesh and the empty mesh), sixteen mutated files the decoder
  refuses, the full validate rule matrix (28 cases) and the packed channel-id bound - 206 reference
  lines, floats as 32-bit patterns. Compiling the engine's own `mesh_decode_tests.cpp` shows a
  stale expectation there (a submesh word of 256 now means masked Skin and decodes; the test still
  asserts a refusal from before the version-5 flag bits), so the suite pins the decoder's behaviour.

- **The construction build jobs' pure scheduling half is ported, bit for bit against the engine.**
  `abundance/src/construction_build_job.grl` carries the progressive build jobs of
  `actions/construction/build_job.hpp` and the pure rules of `cmake/tx/construction.cmake`'s
  `construction_build_job.cpp`: the tuning block (including the 3x-faster per-block rate the
  engine static_asserts), `order_build_steps` (bottom layer first for Place/Upgrade, top layer
  first for Remove, nearest to the builder first within a layer, ties by x, then y, then
  instance, stable), one `advance_build_job` tick (the due-block pass with its lookahead window
  and scan cursor, one block per block time for Place with no accumulated time debt and bounded
  catch-up for modifications, the Materials pause and its retry cadence, the OutOfRange pause
  with no burst on return, the Obstructed/Unsupported defers, the 30 s stall that gives up blocks
  still unsupported, and the ten-minute abandon), `BuildJobBook::find` over ascending ids, and
  `actor_overlaps_cells`'s capsule-against-cell-AABB predicate. `abundance/tests/
  construction_build_job_test.grl` prints 105 lines that match a reference linked from
  Abundance's own `construction_build_job.cpp` through `libabundance_gameplay_core.a`; the
  fixtures follow `tests/construction_build_job_tests.cpp` and add the tie-break, capsule
  touching and z-edge boundary cases. The saved table's codec and the three actions over `Tx`
  stay with the tx kernel; the job entry's text is gated as the engine's `fnv1a64`.
- **The parity references follow the reference checkout's moves**: `tools/abundance-test.mjs`
  gives every Abundance-tree reference the `engine/` include (`base/*.hpp` moved there) and builds the
  RHI reference against this repository's `graphics/` (the foundation left the checkout); `job.cpp`
  follows `job_scheduler.hpp` to `base/`. The world/cache fixtures are regenerated against the
  checkout at `83d90ed95e` (generator version 122): the world and synthetic hashes and the cache
  containers change with it, the landscape authority snapshot does not. All 13 programs and 6 probes
  still match.
- `tools/abundance-test.mjs`: the references map had two identical `checkpoint` entries; the first
  was shadowed and dead, and is deleted. No behavior change.

- **The ab::tx engine's observed-character index is ported** (`abundance/src/tx_engine.grl`): the
  host's per-tick population snapshot with its spatial index — a uniform 32 m grid over the
  finite-positioned characters with a 2^30-cell clamp, order-preserving packed cell keys, the
  padded covered span, and the scan-vs-walk heuristic that must answer identically — plus the
  exact `within`/`touching` distance tests (per-actor capsule, unknown-capsule fallback) and the
  id lookup. Gated by `tests/parity/tx_engine.cpp` against the engine's own `ObservedIndex`/
  `ObservedList` with a nine-actor fixture covering every branch: 43 reference lines, all matched
  by `abundance/tests/tx_engine_test.grl`.
- **The Abundance gameplay kernel's shared vocabulary and table codec are ported**
  (`abundance/src/tx.grl`, the stage-6 base every gameplay domain builds on): action-kind and
  table-name identity hashes, the effect-id and engine-id ranges, all 55 refusal codes with the
  engine's own names, the Writer/Reader byte codec (little-endian words, IEEE-754 bit patterns
  with -0.0/NaN/infinity payloads preserved, bounded strings/sequences, opaque payloads beyond
  codec_max_string, exact consumption, nothing produced on failure), the stamp/receipt records,
  and the changeset - ops sorted by (table, key), flows merged by (resource, reason) and summed,
  FNV hash over the encoding - plus the codec's hostile-input refusals and three malformed
  changesets both implementations reject. Gated by `tests/parity/tx.cpp` against the engine's own
  headers and the compiled `libabundance_gameplay_core.a` (`-ffp-contract=off`): 235 reference
  lines, all matched by `abundance/tests/tx_test.grl`.
 (Abundance: .abcmesh codec, identical to the C++ on fixtures the engine's own encoder writes (206 lines))

- **`Mutex::lock_with` passes the hidden result destination its callback needs.** A framed result
  of more than two words — an `Option<record>`, or any enum whose payload is a record — is written
  to a destination the caller passes after the declared arguments (docs/design/unboxed-values.md
  3c). The builtin call site never passed one, so the callback wrote its result through whatever
  `%rdx` already held: returning `Some(Pod{a,b})` from a `lock_with` callback segfaulted while
  `u64`, `u64?` and bare records were unaffected. `mutex_method` now allocates the destination with
  `call_dest` and passes it in the third argument register, as every other call site does. Corpus
  case `mutex-lock-result-enum-with-record-payload`.
(compiler: lock_with passes the hidden result destination its callback needs)
- **`math::asin` and `math::fmod` join the standard library.** asin is fdlibm's
  `__ieee754_asin` - the algorithm glibc's double asin evaluates - so its results are bit-identical
  to the system libm (expected bits in the new corpus case come from the libc itself); fmod is the
  exact IEEE remainder, built only from power-of-two doublings and Sterbenz-exact subtractions, so
  it agrees with C's fmod by construction rather than by measurement. Both are `@no_block`. The
  Abundance sky port needed both (the day/night model uses std::asin for the sun and moon and
  std::fmod for every clock wrap).
- **The Abundance world model's storage, frame boundary and replay harness are ported.** There is
  no ECS in the C++ to translate, so stage 3 is a design: `abundance/src/world_model.grl`
  implements the epoch-stamped frame boundary the engine keeps in `FrameContext`/`Session` (the
  epoch and its `create`/`reset` bumps, the pending player boundary and its exact-target retry,
  publish refusing to mix a new body with old rules), an id-ordered entity registry with pawn
  component columns beside it (the `ab::tx::EntityRows` insert/erase/mutate/encode semantics
  `entity_table.grl` gates), `MoverServerSim`'s recorded-input admission (wrap-safe seq watermark,
  duplicates and not-newer samples refused, queue bounded at 90) and tick rules (consume, repeat
  for three starved ticks, then a zero input keeping the last seq and yaw), and the session
  refusal texts verbatim. `abundance/tests/world_model_test.grl` replays 48 recorded 30 Hz inputs
  in the engine's own 14-byte wire through it, gated line for line (1 176 lines) against a
  reference built from `kinematic_mover.cpp`'s wire functions and the real registry;
  `docs/design/abundance-ecs.md` is the contract gameplay lanes code against, including the
  worker borrow rule (workers lease an owned `Frame`; the owner keeps the mutable `World`, and the
  borrow checker enforces it) and the seams for the mover, frame sections, store and transactions.
- **Abundance's XXH3-128 state digest and its SHA-256 usage are ported and gated.** `lib/xxhash.grl`
  gains streaming XXH3-128 (`xxh3_new`/`reset`/`update`/`digest`, seeded and unseeded, plus
  `canonical128`), byte-exact against the vendored xxHash 0.8.4 over 0..300-byte inputs, the
  0/1/16/64/240/241/1024/64 KiB/1 MiB fixtures, three streaming chains and two seeds
  (abundance/tests/xxhash3_test.grl: 58 lines against the header itself, and a `lib-xxhash3`
  corpus case that pins it without the Abundance checkout). The one picosha2 caller
  (`Private/config_value.cpp`'s `content_digest`) is gated end to end: 35 lines against the
  vendored picosha2 in abundance/tests/sha256_test.grl, over SHA-256's padding boundaries,
  `Digest::hex()` and seven canonical preimages the reference wrote. libsodium's UDP crypto is
  recorded as out of scope in abundance/README.md. Checked arithmetic rewrites the reference's
  `0 - x` complements as `wrapping_sub(0, x)`.

- **Every performance chart is re-measured with the machine idle** (load average under 3; release
  compiler with PGO on main bcf78e5a). Every compile row now beats the fastest rival: the cold
  check of the 104,000-line program is 0.93x Zig's instructions (3.05 against 3.28 billion). Channels
  are level with crossbeam's CPU time; parallel ECS is the fastest of all on one worker and 1.7x C
  at eight; the scheduler's frame loop has the best p99 of the three. The chapter's text follows.

- **A direct call to a closure that captures nothing passes no environment.** It was handed the
  address of a stack copy of the closure value, which nothing reads and which kept the calling
  function from being inlined. bench/iterchain (native): 1320M to 1310M instructions. The plan for
  the rest of the native chain is in docs/design/dyn-and-callable-bounds.md, section 7.
- **bintrees runs 21% fewer instructions in release and 18% fewer in dev.** Freeing a static object
  (a payload-less variant such as a tree's `Leaf`, or a literal's) is answered in the free fast path;
  it went through two slow-path calls, a third of the frees in bintrees. And with release builds the
  allocator's fast paths are inlined where a program allocates and frees: the LLVM lifter keeps the
  threaded paths out of line and hints `rt_alloc`, `rt_alloc_unlocked` and `rt_free` inline.
  bench/bintrees: release 3.653 G -> 2.878 G, dev 12.168 G -> 9.931 G user instructions, output
  unchanged.

- **Development builds drop the register copies around float arithmetic.** The native backend
  computes every float operation in the %xmm0/%xmm1 scratch pair and copies values in and out; a new
  pass (`xmm_copies`) and the f32 constant rewrite now load straight into the destination, store
  straight from it and do two-address arithmetic in place, wherever the scratch is dead after.
  Development builds, outputs identical: ecs_par 18.3G to 15.2G instructions (-17%), dot_f32 -10%,
  xform_f32 -9%, ecs -8%, matmul -7%; f64 code unchanged.
- `bench/results/compile.json` re-measured with the PGO release compiler of main d086c472: a cold
  check of the 104 000-line program is 1.10x Zig's instructions (from 1.29x); every other row is
  below the fastest rival.

- **Release builds lift the `dyn` adapter thunks.** A thunk (`.C<hash>_N`) adjusts the receiver and
  tail-calls the method with `jmp *%r11`; the lifter refused it, so every `dyn` call went through a
  native thunk and a second jump. It is now a call and a return in IR, which LLVM inlines the method
  into: bench/dyncall release 503.8 M -> 443.8 M instructions, output identical.

- **A payload-less variant of a boxed enum allocates nothing.** `Tree::Leaf` is now one static
  `{tag, 0}` object with a static object's header, which every free path already skips, instead of a
  16-byte allocation per value. bench/bintrees release: 3.78 G -> 3.59 G instructions, 0.28 s ->
  0.24 s; output identical.

- **A cold check spends less on per-function store bookkeeping.** Each body's key is hashed once
  (it was hashed three times: lookup, filing and the body record); units are encoded straight into
  the module's pack buffer, with the checksum's input built in one reused buffer; and a body key's
  column comes from the lexer's token instead of rescanning the file. syn4000 cold check: 3.60G to
  3.51G instructions (-2.6%).
- **The performance chapter explains the `fib(32)` scheduler rows.** They mostly measure g++'s
  recursive inlining in oneTBB's twin (46 to 50 million instructions for serial `fib(32)`, against
  67 million for clang's C and 75 million for Grail's release build, which is clang's loop plus one
  register move), not Grail's join, which costs about the same as oneTBB's per join. The chapter's
  earlier explanation (hidden registers in Grail's calling convention) was wrong and is removed.
- **Release builds lift the drop glue too.** The content-addressed helpers (`.D…` drop glue, `.P…`)
  are frameless, so the lifter's function split ran each one on into the next helper's `.weak`
  directive and refused it; they stayed native calls LLVM could not inline. A symbol directive that
  introduces the next function now ends the open one. bench/bintrees in release: 3.85 G -> 3.78 G
  instructions and 0.29 s -> 0.25 s; dyncall -3%, strings -1%; outputs identical.

- The FFI test shim builds for Windows without a C library's headers again: `immintrin.h` pulled in
  `<stdlib.h>` through `mm_malloc.h`, which a Linux host has no MSVC copy of, so the Windows check
  (and with it every post-landing run) failed before any case ran.

- **The performance charts are measured again** on main bd532104 (kernels, engine programs, parallel
  ECS; compile on 66e3b3b6 with PGO). `tools/bench-rivals.mjs` now takes the best of 7 runs by default
  (it was 3) and `just bench-results` the best of 9 for the parallel chart (it was 5), so the next
  refresh on a shared machine is less at the mercy of one quiet round.
- **A task's finish no longer makes a system call nobody waits for.** Every finished task woke its
  "finished" word with a futex call, waited on or not: a burst of 100k spawns made 100k futex wakes
  (and about 40% of the burst's system time). A thread that waits on that word now registers in the
  task's joiner word, and only then is the wake made: 100,049 -> about 300-500 futex wakes per 100k
  spawns, system CPU 0.057 -> 0.035 s for the burst.

- `bench/results/compile.json` re-measured with the release compiler of main 66e3b3b6 (with its
  profile): a cold check of the 104 000-line program is now 1.29x Zig's instructions (from 1.51x),
  and every other row is at or below the fastest rival.

- **Default `extern "C"` calls on Windows x64 lost their locked instruction.** The foreign-call
  marker counts out with a plain increment and one load; the scheduler's monitor orders it with
  `FlushProcessWriteBuffers` before it hands a stuck call's worker on (docs/design/concurrency-model.md,
  2.4.1). With this every target has the asymmetric-fence marker.
- **Fix: a per-module build where two modules coerce a function links.** Each module's object carried
  its own global `grail_fn_thunk` (the adapter that lets a named function act as an `Fn` value), so
  the link failed with `duplicate symbol: grail_fn_thunk`. It is now a weak definition like the
  other shared adapters, and the linker keeps one.
- **f32 element loads and stores and f32 constants in development builds take no detours.** An f32
  element now loads and stores with one `movss` (it went through `%eax`), and an f32 constant hoisted
  into an SSE register is rounded to binary32 once, so `v * damping - gravity * dt` is `mulss` and
  `subss` with no widening to f64. AArch64 and RV64 lower the new forms to `ldr`/`str s` and
  `flw`/`fsw`, and `grail asm` encodes `movss` and AArch64 `movi d,#0`. Development builds, callgrind,
  outputs unchanged: ecs 20.8G to 16.7G instructions (1.09 s to 0.80 s), matmul 11.9G to 9.9G,
  xform_f32 7.0G to 6.4G, ecs_par 19.8G to 18.4G, dot_f32 5.1G to 3.9G.
- **Fixed: a zeroed f32 local in an AArch64 development build failed to assemble** (`movi` was
  missing from `grail asm`), and RV64/AArch64 had no register for `%xmm15`.

- **The per-function store files one pack per module run.** A cold compile used to file one store
  entry per function (16,126 files for a 4,000-function module, each a create, write and rename); a
  module run now writes all its units into one pack, once, with one rename, and reads its module's
  pack once before any body. Units are still keyed per function, so an edit refiles only its own
  module's pack and replays every other body; entries filed one per file by an older compiler are
  still read; `grail cache gc` stamps and evicts packs like any entry; a check and a build (and a
  debug build) of a module keep separate packs. Cold check of a 104k-line module: system time 0.82 s
  to 0.16 s; cold build: 1.62 s to 1.12 s.
- **`grail check` is about 9% faster on a large program: the root module writes no interface.** A
  check wrote every module's interface, including the program's root, which no other module reads.
  The root's run now skips it, and with it the effect recording that only fed that interface. A
  cached check of a module that other modules read still requires a record carrying its interface
  (or the runtime's effect summary). A cold `grail check` of the 104k-line syn4000 runs 16.59 G ->
  15.16 G instructions (-8.6%), with identical output.
- **Channels no longer take a lock.** `chan::bounded` is now crossbeam-channel's array design: a
  ring of slots with a stamp each, and `head` and `tail` counters on cache lines of their own. A send
  or a receive is one compare-exchange and a release store. A side that has to wait spins, then
  yields, and parks only after that; nothing touches the parking gate unless someone is parked. On
  `bench/chan` the release build goes from 14.7x the fastest rival's CPU time to the fastest of
  all (best of 9, on a loaded machine: 0.060 s against Go's 0.087 and crossbeam's 0.119); the
  development build goes from 17x to 2.4x. The API is unchanged, and values left in a channel are
  dropped with it.
- **`host::yield_now()`** gives up the processor for a moment: `sched_yield` on a thread, a switch
  to another task on a pool worker.
- **Fixed: a yield on AArch64 and RV64 Linux did nothing.** The runtime's `sched_yield` had no
  entry in their system-call table, so the scheduler's own yields there returned "not
  implemented"; it is system call 124 on both.
- **f32 locals in development builds stay in SSE registers, in binary32.** The native optimiser
  kept no float local in a register in any function that multiplied two f32 values (that sequence
  names %xmm8/%xmm9, and the allocator gave up on a function naming either), and a local set to
  `0.0` (a `movq $0` store) never qualified. Now the registers a body names are skipped rather than
  disqualifying it, a zero store becomes `xorps`, and `xmm_narrow` keeps such a local in binary32
  when it is returned or added to a product: `s = s + x[i] * y[i]` is one `addss` on the register.
  bench/dot_f32 (dev): 0.690 s to 0.330 s, 5.14 G to 4.14 G instructions; matmul 11.88 G to 10.54 G;
  outputs unchanged.

- **Default `extern "C"` calls on AArch64 and RV64 Linux lost their atomic instruction too.** The
  foreign-call marker counts out with a plain load, add and store (the `ldaxr`/`stlxr` loop and
  `amoadd.d.aqrl` are gone) and reaches its counter in one load from the thread record; the
  scheduler's monitor orders it with `membarrier` (system call 283), as on x86-64. A new FFI fixture,
  `foreign_handoff`, checks on all three targets that a C call stuck for 120 ms still has its worker
  handed on.

- **The summary chart reads in words.** Its axis runs "32x, 8x, 2x, same, 2x, 8x, 32x" under
  "◀ Grail faster / Grail slower ▶", and every note and table cell says "3.3x faster" or "1.96x
  slower" instead of a bare ratio such as 0.31x.
- **The performance chapter opens with every benchmark on one page.** A summary chart has one bar
  per category (compile check and build, cold and after an edit; release and development run time;
  release instructions; the scheduler): Grail's ratio to the fastest rival, the geometric mean of the
  category's rows, with its best and worst rows marked. A table under it names them. It reads the
  same committed results as the other charts (`{{perf:summary}}`).
- **The release compiler is built with profile-guided optimisation.** `tools/native.mjs release`
  compiles the compiler's LLVM code with `-fprofile-use` and the profile in
  `tools/pgo/grail.profdata.xz`: a training run of the instrumented compiler (a cold check and build
  of a 26 000-line program and the compiler's own check), regenerated with `bun tools/native.mjs
  pgo-train`. The compiler's output is unchanged (byte-identical text and objects); it runs 7-9% fewer
  instructions per compile: check of a 104 000-line program 5.06 G -> 4.60 G, its build 26.5 G ->
  24.7 G. `GRAIL_PGO=0` builds without the profile.

- **Generic code over a type that owns nothing has no drop bookkeeping.** In a specialisation, a
  type parameter bound to a plain type (`A = u64`) answered "needs drop" like an unknown type, so
  every value of it carried a drop flag, a drop-helper call guarded by it, and a callee-saved register
  saved and restored to hold the flag. It now answers for the type it is bound to. bench/iterchain's
  native build: 1.92G to 1.14G instructions.
- **The compiler checks about 5% faster: the allocator's and copy's hot paths lost their checks.**
  `rt_alloc_unlocked` finds the class and clears the block in one compare chain (no variable shift,
  no checked add, the two smallest classes cleared with fixed stores); `rt_free` answers a null
  pointer before loading anything and finds the class with two constant shifts; `rt_copy_bytes` and
  `rt_drop_seq` use wrapping arithmetic. A cold `grail check` of the 26k-line syn1000 runs 4.247 G
  -> 4.040 G instructions (-4.9%), with identical output.

- **A release build's runtime error says where it failed.** A failing check in a release (LLVM)
  build printed its message without the ` --> file:line:col` line a development build prints, because
  that line came from the native backend's site table. The front end now records statement positions
  for the lifter too (`.gsite` lines), and the failure path of lifted code - only the failure path -
  points the runtime at a record of its statement before it calls the failure entry, which the report
  prints as the ` --> ` line. Measured: no instruction changes on bench/ecs, sort, sieve, xform_f32 or
  nbody. Failures inside a runtime helper that is not lifted in place still report no location, and a
  contained task failure keeps the location it had.
- Interfaces record the source they describe by the build store's fast hash (`source-hash`) rather
  than SHA-256 (interface format 14): digesting every source byte with SHA-256 was a twelfth of
  checking a large module. Interfaces written by an older compiler are refused as a different format
  and rebuilt.
- **Fix: `dyn Iterator` works again.** `Iterator::fold` (a generic method taking `self` by value)
  made the interface "cannot be used as dyn". As in Rust, such a method is now left out of the dyn
  object - it is called on concrete types and through bounds - and the interface stays usable as
  `dyn` for its other methods.
- **A failed check inside a parallel job no longer aborts silently now and then.** The joiner that
  re-raises a job's failure took one from the contained-failure count with a checked subtraction,
  which trapped - inside the failure path, so without a report - when it ran before the failing stack
  had counted the failure (exit 134 about 1 run in 10 under aarch64/riscv64 emulation). The counts
  are atomic and wrapping now. The failure-site walk also stops where the frame chain stops being one
  (a task stack's bottom on AArch64/RV64 left garbage there: SIGSEGV in `rt_site_above`).

- The foreign-call marker reaches its worker's counter in one load (x86-64 Linux): thread-record
  word 48 caches the running block's pair, set wherever a thread gains or loses a block. One to two
  instructions less per default `extern "C"` call (LLVM `f64` row 15 -> 13).

- **Capture-free and named-function callbacks to generic functions cost no allocation, and named
  functions are accepted.** A closure given for a lent `Fn(..)` parameter of a generic function was
  boxed whenever the call's type arguments were not all fixed yet - `Condition::wait_with`'s two
  callbacks were two heap records per channel send/receive; it is now a frame environment
  (bench/chan ping: 810M to 502M instructions). A named function given for such a parameter
  (`with(&mut m, x, grow<T>)`) was "generic argument shape mismatch"; it is accepted.
- **Fixed: `grail build --release` failed for a whole-program build** (a single file with
  `--no-cache`, `--whole-program`, a claimed effect): the run assembled its in-process object as the
  unit object while the LLVM step looked for the native part beside it (`llvm-ar: X.o.s.o: No such
  file or directory`). The run now writes the native part, as the per-module units do;
  tools/test-cli.mjs builds every release shape and runs the program.

- **`exchange` and `v[i] = x` are inline in release builds.** The LLVM lowering emits the runtime's
  `rt_xchg` in place (tagged as element storage when the address is an element's), so a store loop
  over a vector is a plain loop the optimiser sees: filling 10M words goes from 100M to 67M
  instructions. bench/iterchain builds its vector at its final length, as its C and Rust twins do.
- The orphan rule's diagnostic names the modules: an `impl I for T` written outside the modules that
  declare `I` and `T` now says where it was written, where the interface and the type are declared
  (or that no module declares the type, leaving only the interface's), and the fix - move the impl
  there, or wrap the type in a struct the module declares. The rule itself is unchanged; the book's
  generics chapter now states it ("Where an implementation may live"). A scan of the corpus, lib/,
  the Abundance port and the borg sources found no impl it refuses besides the reject cases.
- Overflow checks on loop-carried arithmetic: a bound may reach a literal through other terms
  (`j <= limit`, `limit <= 50000000`), a compound assignment `x op= e` gets the overflow proof
  `x op e` gets, and `A - (t & L)` with `L <= A` cannot wrap. The sieve's `j += i`, `i * i`, `i += 1`
  and `n - (count & 1)` carry no check (6 -> 2 in `main`; the two left are its unbounded counters).

- **`lib/chan.grl`: a bounded multi-producer multi-consumer channel.** `chan::bounded<T>(n)` with
  `send` (waits while full; false once closed), `recv` (waits while empty; `None` once closed and
  empty) and `close`; waits park, as every `sync` wait does. `bench/chan.grl` measures it against
  crossbeam-channel and Go's chan in `tools/bench-rivals.mjs`.

- A per-function unit's key, and a module run's declaration record key, carry a digest of the run's
  declaration surface instead of its bytes (key formats `grail-fnkey 5`, `grail-declrec 3`; units
  filed before miss once). compile-perf build_syn1000_edited 6.379G -> 6.266G (-1.8%).
- Inflate calls its bit refill only when the buffer is short of the bits a symbol or extra field
  needs (a word refill holds 56 or more), instead of on every symbol: the 4K png Grail-LLVM 4.94G ->
  4.66G instructions (0.59 -> 0.53 s; stb_image 0.37 s), Grail-native 16.1G -> 15.1G.
- Fixed (soundness): the interval proof removed the overflow check of `a * b` when each operand was
  at most 2^40, but their product can reach 2^80; the product of the bounds must now stay below 2^62
  (`bce-product-bound-kept`). The interval reading of an index (`i * n + k`) also formed its
  products before testing them, which can wrap in a compiler built with wrapping arithmetic; it now
  tests by division first.

- xxhash reads its eight-byte lanes with one load (`bytes::load_u64`) now that the call inlines,
  instead of assembling each from eight indexed bytes: the 20 MB zstd archive (whose frames carry
  an XXH64 checksum) Grail-LLVM 5.88G -> 5.09G instructions, 0.65 -> 0.55 s (libzstd 0.26 s).
- Small allocations clear their block with two fixed stores instead of the general loop: every
  request up to 16 bytes (a tree node, a box) is served from the smallest bin, whose blocks hold at
  least 16. bench/bintrees.grl: Grail-LLVM 4.89G -> 4.15G instructions, Grail-native 14.2G -> 13.7G.
- **`v.iter()` returns a typed `iter::SliceIter`.** Its `fold` is a counted index loop, so
  `v.iter().map(..).filter(..).fold(..)` runs as one loop over the vector: bench/iterchain goes from
  1130M to 250M instructions (C 106M), 109 ms to 42 ms. **What changes:** code that named the result
  type as `iter::Iter<(&T)>` must name `iter::SliceIter<a, T>` (or call `iter::refs(&v)` for the erased
  form); `for`, `next`, `map`, `filter` and `fold` work as before.
- **`Iterator::fold`, with internal iteration.** The `Iterator` interface has a default `fold`, and
  the typed adapters `Map` and `Filter` override it to hand a composed callback to the iterator they
  wrap, so a chain runs as its source's single loop rather than a `next` call per item that loops
  inside each filter. The adapters' inherent `fold` methods are gone (they are the interface's
  now); `iter::fold_all(it, init, f)` calls it.
- `grail build --release --report checks` reports the checks that survived LLVM's optimisation and
  the thin-LTO link: it reads the linked image (llvm-objdump; `GRAIL_OBJDUMP` overrides it) and
  counts each branch from a program function to rt_fail, rt_trap, rt_abort (with its `.cold` parts)
  or rt_refine, per function, grouped by kind where the failure code is a constant (x86-64). A release
  build has no line tables, so a function is the grain. Only the native report forces an uncached
  build.

- **An interface method generic over a callable can be called through a bound.**
  `fn total<I: Seq>(it: I) -> u64 { return it.fold(0, |a, x| a + x); }`, where `fold` is a generic
  interface method (`fn fold<A, G: FnMut(A, Self::Item) -> A>`), was "generic argument shape
  mismatch"; it now reaches the implementation's method, default or overriding. This is what lets
  iterator adapters fold internally.
- LLVM backend: pushing a 4-byte element (f32, u32, i32) inlines at the call site - `rt_push4`'s
  growth moved to `rt_push4_slow`, which the lifter keeps out of line, as `rt_push` already did.
  bench/ecs on LLVM: 941M -> 823M instructions (C -O2: 710M), same checksum.

- **A no-op build right after an edit is a no-op.** The build store records a source by its stamp
  only when it was read at least 10ms after its last write (one kernel time tick). It used to require
  the file to be 100ms old when the record was written, so an edited `main.grl`, read the moment the
  build started, was never recorded: the next build read and scanned all of it again and started a
  compiler to resolve its modules. A source read too soon is now read once more at the end of the
  build and recorded if its stamp and bytes are unchanged, and the resolved module set waits for it.
  Dev compiler, the 104,000-line syn4000: a build right after an edited build 0.340G -> 0.005G
  instructions, a check after an edited check 0.343G -> 0.008G.
- Compiling is a little cheaper: the optimiser's liveness tables are allocated at full size once per
  body instead of grown a push at a time (cold build of a 104k-line program: 93.9G -> 92.1G
  instructions, output unchanged).
- **The optimiser skips dead-code runs that cannot change anything.** It counts its edits to a
  function, and a `dead_defs` run on a function unedited since a run that removed nothing is
  skipped; the output is byte-identical. A cold build of the 4,000-function scaling program executes
  3.0% fewer instructions (100.9G -> 97.8G).
- The macOS arm64 assembler covers the rest of Mach-O: GOT and thread-local-variable loads
  (`@GOTPAGE`/`@GOTPAGEOFF`, `@TLVPPAGE`/`@TLVPPAGEOFF`), `__thread_bss`/`__thread_vars`,
  `__cstring`, `.data`, and compact unwind (`__LD,__compact_unwind` from `.cfi_*` frames); objects
  are held to clang's structurally (`GRAIL_ASM_ORACLE=1` now covers macOS builds). Fixed: `.data` in
  a macOS build crashed the assembler, and C-string sections had the wrong Mach-O type.

- SIMD vectors cross `extern "C"` by value, as `__m128`/`__m128d`/`__m128i` on x86-64 Linux and macOS,
  `__m256` at `--cpu=x86-64-v3`, and `float32x4_t`/`float64x2_t`/`int32x4_t` on AArch64, in arguments and
  results. A 4-lane dot product in C costs half the instructions per call of the scalar-argument
  version. Windows x64, RV64 and a 256-bit vector without AVX are refused with a diagnostic.
- **`byval` records after the argument registers run out now reach C intact on AArch64 and
  RISC-V.** On AArch64 a record that no longer fits the registers left goes on the stack and, per
  AAPCS64, every later argument of that kind follows it there; Grail kept putting the next double in
  `d7` or the next integer in `x7`, where C does not look. On RISC-V such a record was put on the
  stack instead of falling back to integer registers, and a 16-byte record with only `a7` left was
  not split between `a7` and the stack. New fixture `tests/ffi/abi_edges.grl` (all three ELF
  targets, both backends, and Windows x86-64 under Wine).
- **A default `extern "C"` call no longer executes a locked instruction (x86-64 Linux).** The
  foreign-call marker counts out with a plain increment and one load of a "retaken" word; the
  scheduler's monitor, which takes a worker back from a call stuck for 10 ms, pays for the ordering
  with `membarrier` instead. User cycles per call on LLVM: `f64` 14.5 -> 8.8, `f32` 8.2 -> 6.8
  (C: 6.4-6.6). Windows x64 keeps a locked increment and AArch64/RV64 a sequentially consistent one,
  each its own barrier. Without `membarrier` (a kernel before 4.14) undeclared calls are not handed
  off. The protocol and its race argument: docs/design/concurrency-model.md, 2.4.1.
- **Fixed: a release-build miscompile of float arithmetic in closures (bench/ecs_par).** A closure
  body's float-operation facts were numbered on from the body emitted before it, while the LLVM
  lifter counts each function's calls from zero, so a fact named another call: the gravity
  closure's `p + v * DT` was lowered as a multiply and the y positions were lost (ecs_par printed
  500666023.38 in release, 751091934.76 everywhere else). The counters now restart in every
  closure body. The lifter also stops relying on the numbering: it reads the opcode the stream
  passes to `rt_f64_op` (tracked through registers and frame slots), refuses a fact naming another
  operation, and lowers a call without a fact to the one IEEE double operation the runtime
  performs, with one result word in %rax and nothing written to %rdx.
- The build store no longer grows without bound. Every unit, body record and optimiser memo entry
  has a last use (each compiler run writes one use list), `grail cache gc [--max BYTES]` evicts the
  least recently used entries until the store is under the cap, and a build checks the cap itself
  every 8th build (`GRAIL_CACHE_MAX`, 2 GiB by default; `GRAIL_CACHE_GC_EVERY`). An evicted entry is
  only ever a miss. 25 one-body edits of a 40-function module grew the store from 7.1 to 22.9 MB;
  with a cap of 1.3 times the cold build it ends at 6.9 MB.
- **Constant promotion of literal vectors.** `table := u64[1, 0, 1, ...];` whose elements are integer
  literals, bound to an immutable name the rest of its block only indexes or measures, is now one
  read-only object emitted once instead of a vector built on the heap at every execution (meshopt's
  `can_collapse`/`has_opposite` rebuilt a 36-entry table per call). A literal that is mutated,
  moved, returned, borrowed out or captured by a closure still allocates fresh.

- **`bench-rivals` no longer charts a build that printed the wrong answer.** It already failed the
  run when a build's output differed from C's, but still wrote that build's figures into the
  results, so a miscompiled program could chart as the fastest. Such a figure is now left out and
  shown as not measured.
- **`grail build --release` no longer hangs on large programs.** The LLVM lifter's name table was
  sized once from a guess and never grew; a program with more names than the guess (the Abundance
  port's `abgeo` and `cache`) filled it, and the next lookup of a missing name probed for ever. The
  table now doubles before it is half full.
- **SIMD `.bits()` gives the same NaN bits on every target too.** A NaN lane of an `f32x*` or
  `f64x*` vector now reads as `0x7FC00000` or `0x7FF8000000000000`, as scalar `bits(x)` does;
  before, x86-64 gave negative NaNs (and a release build could mix the two), ARM and RISC-V
  positive ones. Three vector instructions (compare with itself, select), no per-lane work.
- **`bits(x)` of a NaN is the same on every target.** Hardware disagrees on the NaN an operation
  makes (x86 sets the sign bit; ARM and RISC-V do not), so `bits(0.0 / 0.0)` used to be
  `0xFFF8000000000000` on x86-64 and `0x7FF8000000000000` elsewhere. Every NaN now reads as the one
  quiet NaN `0x7FF8000000000000`, on every target and both backends; arithmetic and printing are
  unchanged, and other values' bits are untouched.
- **Maps hash one-word keys with a keyed multiply mix instead of SipHash-1-3.** Integer, float and
  other one-word keys hash in about eight instructions instead of sixty, keyed by the map's two seed
  words (one mixed into the value, one as a secret odd multiplier), the same construction as the
  seeded word hashes of Go's and Zig's tables. `bench/hashmap` falls from 0.71 to 0.46 billion
  instructions and from 99 to 75 ms against C's 67 ms. It is not a cryptographic hash: `hash::hash`
  still returns SipHash-1-3 and `hash::hasher` is still SipHash-2-4, and multi-word keys (strings,
  records) still stream through SipHash-1-3.
- **The scheduler's "a worker is searching" count could go below zero, and then no fork woke
  anyone.** A worker that found work while searching, and lost its worker block to a blocking call
  inside that work, cleared the searching flag that the block's new thread had set. The count went
  to -1, which reads as "someone is searching" for ever, so a task put on the injection ring
  waited with every worker asleep (`bench/frame.grl` hung about one run in 20). The thread now
  touches the flag only while it still owns the block. 0 hangs in 300 runs.

- **A lost wakeup in nested joins is fixed.** A waiter that took a stale queue entry for a recycled
  job record gave it back with a plain store of "pending", which could erase the forker's
  registration as the job's waiter in the moment between: the job was then published to nobody
  and the forker slept for ever. It now gives the job back with a compare-and-swap, and runs the job
  itself when its forker is already waiting. `sched-wake-not-lost-under-constant-parking` hung
  about one run in four under aarch64 emulation; 0 of 50 now.

- A program whose `main` takes the argument view and is run without one now prints `usage: PROGRAM NAME`
  on stderr, with the parameter's declared name, before exiting 2. It used to exit 2 silently.
- The SIMD benchmarks (`bench/simd_dot`, `simd_mat4`, `simd_aos`) take `check` for a three-round run that
  prints only the result, and the corpus pins those results on every target and backend. A
  benchmark run with no argument exits 2, as every `main(arg: &[u8])` program does.
- macOS arm64 builds assemble in the compiler too: `compiler/macho.grl` writes Mach-O objects
  identical to clang's (`grail asm --target macos-aarch64`). Intel macOS still assembles with clang.

- **A closure copies a captured shared reference.** `r := &x` captured by two closures used to fail
  with "`r` was moved" at the second; a `&T` is now copied into each closure, which holds the shared
  loan, as in Rust (an exclusive `&mut`, and a shared slice value, which owns its header, still move).
  A closure given for a generic `F: Fn<Send>` now reports a capture that cannot cross a thread as
  soon as it is read.
- **`dyn` calls devirtualise in release builds.** Vtables are constants in the LLVM module,
  reference parameters cross calls as `ptr` (so a `&dyn` pair in the caller's frame no longer
  escapes as an integer), frame-slot spills keep their pointer provenance, and slot offsets are
  pointer arithmetic: when the vtable is known, LLVM calls the method directly and inlines it. A
  loop calling `area()` through a `&dyn` of one type: 140 M -> 7.6 K instructions (folded). dyncall
  (mixed types): 633 M -> 603 M (Rust -O: 648 M).

- **Release builds inline small functions across modules.** A call to a function of another module
  was declared with a generic six-argument type that never matched the callee's real definition,
  so LLVM never inlined it: small std helpers (`bytes::load_u64`, hash and string methods) stayed
  calls in every release program. Each module's interface now records the signature its body was
  defined with, and importers declare their calls with it (interface format 13).
  `bench/hashmap.grl` -7.6% instructions; a loop over `bytes::load_u64` -27%.
  `tools/release-signature-test.mjs` fails on any cross-module declaration that disagrees with
  its definition.
- **Release builds keep vector headers in registers across element stores (TBAA).** The LLVM lifter
  writes the word and 4-byte element accessors (`rt_slot`, `rt_slot4`, `rt_at4` and their unchecked
  forms) in place: the header's `data`/`len` loads carry a `header` type tag, and every load or store
  through the element address - followed through registers and frame slots within a block - carries
  an `element` tag. Safe Grail cannot point one into the other, so LLVM hoists the header loads out of
  loops and vectorises them: bench/ecs goes from 3.45 G to 0.94 G instructions, sort from 7.53 G to
  7.24 G.
- `pool::join` takes its first branch as a generic `F: Fn<Send>() -> A`, so a closure given for it is
  held in the frame and called directly (no heap environment). An explicit type-argument list may
  leave out trailing parameters that only a callable bound names (`pool::join<u64, u64>(a, b)` still
  compiles), and a closure given for a callable-bound parameter has its capture bounds checked as
  the argument is taken, as an erased `Fn<Send>()` parameter's are.

- **A standard generic is checked once per surface, not once per run.** The check
  `emit_specializations` owes every template a run instantiates (a replay of its body with its own
  parameters opaque, its text thrown away) is now a unit of the per-function store: what it asked of
  the run - specialisations, drop helpers, effect records - is recorded and asked again on a hit,
  under the unit key the store already uses. Dev compiler, an edited check: bench/iterchain.grl
  0.234G -> 0.154G, hashmap 0.203G -> 0.158G, json 0.188G -> 0.133G. `GRAIL_TEMPLATE_MEMO=0` turns it
  off; the fn-cache report counts template checks apart from bodies. Fixed on the way: a body that
  asked for a `parallel_for_zip` adapter could be a unit whose replay did not ask again (the adapter
  went missing from a warm build); it is no longer a unit.
- **Faster release rebuilds, within a machine's memory.** After an edit to one function, a release
  build re-optimises only the ~128 KB LLVM part that holds it and re-runs the ThinLTO backend for
  that part alone; the unit archive is written in one step and the native part is assembled by the
  compiler itself. `bench/hashmap.grl`, one function edited: 0.82 s -> 0.56 s median (cargo
  --release on the Rust twin, measured alongside: 0.74 s). Part compiles are admitted against the
  memory available, so a release build of the compiler fits a 16 GB machine instead of being
  killed for memory.
- Native backend: an f32 `+ - * /` with an f32 constant is one binary32 instruction (`mulss` with the
  constant's bits) instead of widen, operate in f64 and round - the same result, since both operands
  are binary32. bench/ecs_par.grl writes its updates as zip closure literals (no bounds checks).

- After each landing the build host also runs the closure-passing fuzzer (`tools/fuzz-closures.mjs`, 400
  cases, compile and run) next to the front-end fuzzer. `tools/land.sh --remote-status` reports both.
- Fixed: when two or more sequences proved stable across one loop had their data pointers hoisted
  before its head (optimize.grl item 6), only the last one's load was emitted, and the others'
  accesses used an unset register (`damp(v, p)` with both slices proved crashed with SIGSEGV). Every
  sequence of a loop head is now loaded. `loop-hoist-two-slices-one-head` and
  `loop-hoist-three-slices-one-head` pin it on all three targets.

- **UTF-8 validation skips ASCII eight bytes at a time** (`.text()`, string literals that need a
  run-time check, `append_format` onto a string), as Rust's `from_utf8` does: aligned words with no
  high bit set are passed whole, and the multi-byte checks are unchanged. No load is misaligned on
  any target. A case covers every alignment and four rejections just past word boundaries.
- The standard library claims `@no_block` where its bodies prove it: every `math` function, the
  `hash` writers and `finish`, `u64[].sum`, `[u8].is_char_boundary` and `strings::utf8_width`.

- New: `@no_block`, a checked effect: a function and everything it calls makes no blocking call - no
  park (locks, channels, conditions, joins), sleep, file or socket I/O, or C function not declared
  `extern "C" nonblocking`. Refusals name the chain (`nap -> sleep_ms -> f_host_sleep_ms ->
  rt_sleep_for`). A check that can fail does not block (the failure ends the frame). Interface
  format 12: the `effects` row and the `facts` record carry it.
- `grail build --cpu=x86-64-v2|v3|v4|native` builds for an x86-64 CPU level. `@if target.features.NAME`
  (avx2, fma, sse4_2, avx512f, ...) tests the level at compile time. At v3 and above, `mul_add` is one
  `vfmadd231ps`/`pd` on both backends; the release build's IR carries `"target-cpu"`, which ThinLTO
  needs. Other targets refuse `--cpu`.
- png unfilters the common layout through addresses (`bytes::data_addr`, new) into an image sized
  once, under the length guard that already bounds every row, instead of a push and a checked index
  per byte. The 4K png: Grail-LLVM 6.44G -> 5.50G instructions (0.71 -> 0.61 s; stb_image 0.41 s),
  Grail-native 17.7G -> 16.8G.
- zstd's backward bit reader keeps a 64-bit window and reloads it about once per sequence instead
  of assembling a word on every read: the 20 MB archive 11.9G -> 11.75G instructions on Grail-LLVM.
- Closure bodies are proved like function bodies: a loop bound or a condition in a closure now
  removes the bounds checks it covers. A closure literal written as `parallel_for_zip`'s argument
  also starts knowing that every piece is as long as the first, so `v[i]` under `for i in p.len()`
  has no check (a closure passed through a variable keeps it).
- `mul_add` on f32 and f64 vectors: `a * b + c` per lane with one rounding, identical to C's `fma`
  on every target and backend. AArch64 uses `fmla`, RISC-V `fmadd`, and baseline x86-64 an exact
  software routine in the runtime, which is slow there.
- Native Linux builds give every compiled function a symbol type and size (`.type @function`,
  `.size`), so readelf, perf and debuggers name addresses inside them; the compiler's assembler
  writes them as STT_FUNC with st_size.
- **Inflate refills its bit buffer a word at a time** (`bytes::load_u64`, a new unaligned
  little-endian word read), instead of a byte per loop step, while eight input bytes remain. The 4K
  png: Grail-LLVM 7.47G -> 6.44G instructions (0.85 -> 0.71 s; libpng 0.41 s, stb_image 0.41 s),
  Grail-native 19.8G -> 17.7G.
- Bounds checks on decoder state: facts about the fields of a `&mut` record or a `mut` record
  binding (`z.at < z.data.len()`) are kept until something can change that field - a write of the
  path (`z.at += 1`), a mutable loan of it (`z.data.pop()`), or a call or method that receives `z`
  itself. A loan of one field (`z.out.push(..)`) ends that field's facts only, so
  `while z.at < z.data.len() { z.out.push(z.data[z.at]); z.at += 1; }` reads unchecked.

- Bounds checks: an index `t & L` is at most `L`, so a table lookup through a mask that matches the
  table (`next[s & 511]` on a 512-entry table) needs no check. The loop-invariant pass runs only in
  a body `func()` compiles, where a failed kept fact can recompile the function; a closure body
  compiled elsewhere uses the plain kill.

- **A killed `grail build`/`grail check` leaves no compiler running.** The driver starts each module's
  compiler run with `GRAIL_PARENT=<its pid>`; on Linux the run's runtime asks for
  `PR_SET_PDEATHSIG`/SIGKILL at startup and exits if the driver is already gone (getppid), and on
  Windows the driver puts such a child in a job object that kills it when the driver's handle closes.
  The variable is consumed, so the run's own children are not affected. A driver SIGKILLed by a
  timeout, an editor or the OOM killer used to leave its module runs going as orphans (one ran 1h45m).
- **Closures given for a generic `F` live in the frame (S6(A)).** A closure whose type is its own
  literal's - a local closure, or one passed for a callable-bound parameter - is now held as its
  environment's words in the caller's frame, copied on a move and dropped in place, and called
  directly: no heap object, as in Rust. It is boxed once, where it meets an erased `Fn(..)` type, a job
  or thread payload, or a `&Fn(..)` parameter. A closure written inside a generic function sees that
  specialisation's types, so it may call a captured callable-bound `f` (`|i| f()` inside `pool::run`'s
  adapters). Bound violations through a generic `F` now give the same messages as through `Fn(..)`.
- **Fix: every closure expression is a type of its own.** Two closure literals with the same
  signature and environment shape compared equal inside a generic type, so `k = keep(|| ..)` could
  replace a `Keep<F>` built from another literal; calls through it then ran the first literal's body
  (callable-bound calls are direct), and a borrowing closure could outlive what it borrowed. It is now
  a type mismatch, as in Rust.
- **`split` and `lines` scan eight bytes per step** with `bytes::find_byte`, so `strings` now uses
  the `bytes` module (a program that lists its modules adds `lib/bytes.grl`). bench/strings.grl:
  Grail-LLVM 4.53G -> 3.63G instructions, 0.37 s (Rust 3.23G); Grail-native 13.7G -> 12.1G.
- **`bytes::copy_back(v, distance, length)`**: the LZ77 match copy, appending `length` bytes copied
  from `distance` back (overlap allowed, as DEFLATE and zstd require), a word at a time when the
  distance is at least eight. Inflate and zstd use it instead of a push per byte: the 20 MB zstd
  archive Grail-LLVM 14.4G -> 11.9G instructions (1.43 -> 1.24 s), the 4K png 8.07G -> 7.47G
  (0.91 -> 0.85 s).
- A push onto a vector or a text that has room is a store and a length again, in a release build too:
  growing moved out of `rt_push` into a cold `rt_push_slow`, so the call a release program makes
  into the runtime no longer saves five registers on every push. Abundance's slowest program
  (abgeo) runs 6% fewer instructions; `rt_push` went from 17% to 6-8% of its time.
- **Native backend: a scaled array index is computed once per straight line.** nbody's `p[i*3+k]`
  computed `3*i` again for every `k`; it is now computed once into a free scratch register and the
  later accesses read `8k(%rdi,%r8,8)`. nbody executes 5% fewer instructions.
- **C calling a Grail callback is cheaper (x86-64).** A callback whose arguments all arrive in
  registers is entered through a frameless thunk that pins the thread's record, calls the body and
  unpins; only a thread C created takes the framed path that adopts a record. A full-word body is
  an ordinary register function, so release builds optimise it. A C loop calling a callback (10 M
  calls): 42 -> 26 instructions per call native, 47 -> 22 LLVM (C calling C: 11).

- Fixed: an interface whose methods carry default bodies could not be read back and written again
  unchanged ("does not round-trip"): the reader kept a default body only as the source it compiles,
  not as the method's text.
- On AArch64 the native backend computes SIMD operations with NEON: arithmetic, compares, select,
  splat, sums, `any`/`all`, `to_f32`, and integer min/max. Results are identical to the scalar lanes
  and to the LLVM backend. The internal AArch64 assembler encodes the NEON forms identically to
  clang.
- **png and inflate decode faster.** Inflate's length and distance tables were vector literals
  built on every match; they are static text indexed in place. png unfilters the common layout
  (whole-byte samples, no channel added) straight into the image with one loop per filter type,
  instead of five filter tests per byte, a fresh vector per row and a byte-by-byte copy. A 4096x4096
  RGBA texture: Grail-LLVM 41.1G -> 8.1G instructions (3.65 -> 0.91 s; libpng 0.40 s, the runtime's
  division fix included), Grail-native 107G -> 21.4G.
- `pool::chunks_mut_at` (exclusive pieces with their first index) and `pool::reduce_chunks` (a
  read-only reduction folded in index order, the same bits on any number of workers).
- A Grail callback called from C settles on its thread record once at entry and pins and unpins
  through it, instead of choosing between `rt_tls_record` and the thread pointer at each end
  (x86-64). A C loop calling a Grail callback 10 M times: LLVM 52 -> 47 instructions per call.

- The native backend computes SIMD operations with packed SSE2 on x86-64 (lane arithmetic, compares,
  select, splat, sums, 4-lane shuffles, `any`/`all`, `to_f32`), with exactly the same results as
  before. A dot product, a 4x4 matrix product and an AoS-to-SoA transpose run 2-5x faster natively.
  The internal assembler encodes the new instructions identically to clang.
- **`bytes::find_byte(text, from, b)`**: where byte `b` next occurs, eight bytes per step (a word
  read and the has-zero-byte test), in plain Grail. The compiler's line scanners use it - the
  optimiser's body reader, the frame-probe and inlining scans, the site table: 6.4% fewer
  instructions compiling a 4000-function file, 7.2% for the compiler itself.
- **zstd decodes with fewer allocations and a word-at-a-time bit reader.** The sequence-code tables
  were vector literals built on every lookup (four per sequence) and the backward bit reader took
  one bit per step; the tables are static text indexed in place and the reader assembles whole
  bytes. A 20 MB archive (126 MB out): Grail-LLVM 44.8G -> 14.4G instructions (4.38 -> 1.43 s;
  libzstd 0.29 s), Grail-native 124G -> 35.2G.
- **jpeg decodes without an allocation per block or per pixel.** The zigzag table was a vector
  literal built on every lookup, each 8x8 IDCT allocated its 64-entry work area and each 1-D pass
  returned a fresh vector, and every pixel was assembled in a vector of its own before being copied
  out. The table is now static text, the IDCT works in scratch kept between blocks, and pixels go
  straight to the image. A 2048x2048 photo: Grail-LLVM 6.9G -> 1.6G instructions (0.60 -> 0.14 s;
  it was 25.8G before the runtime's division fix), Grail-native 38.6G -> 24.3G.
- **Release builds optimise across modules (ThinLTO).** A `--release` build of more than one module
  compiles each module to ThinLTO bitcode and links with ThinLTO, so a small function of one module
  is inlined into another (LLVM's choice, with the real definition kept where it was). The ThinLTO
  cache lives in the build store. `bench/hashmap.grl`: 1,235M -> 823M instructions; a one-function
  edit rebuilds in 0.82 s (cargo --release: 0.65 s). The release compiler is built the same way.
  Needs `llvm-ar` (or `GRAIL_AR`) beside clang and ld.lld.
- Release builds optimise functions that pass C records by value: a `byval` record crosses in
  registers by its SysV eightbyte classes (INTEGER in general registers, SSE in vector registers)
  or, over 16 bytes, as `ptr byval` on the stack - matching the native placement. tools/test-ffi.mjs
  now runs every FFI fixture on the LLVM backend too (x86-64, with --verify-facts).
- `bench/ecs_par.c` and `bench/rivals/ecs_par.*`: the parallel ECS benchmark's C/OpenMP, Rust/rayon, Go
  and Zig twins; `bun tools/bench-rivals.mjs --workers 1,4,8 --metric wall` runs a program at each
  worker count with every runtime told its threads. `bash tools/quiet-window.sh` takes the wall-time
  measurements (sched-rivals, the parallel benchmark, the kernels) in one command, pinned with
  taskset, when the machine has been quietened.
- **Native backend: unchecked multiplies by a constant are cheap.** A multiply the prover bounded
  (an array index `i * 3`) no longer loads the constant and uses `mulq`: it is
  `leaq (%r12,%r12,2),%rax` for 3, 5 and 9, a shift for a power of two, else `imulq $c`. nbody
  executes 13% fewer instructions.

- An effect refusal over a callee the run cannot see (compiling a program to assembly without the
  runtime's sources) names it - "the target is `rt_len`, whose body and effect summary this run does
  not have" - instead of calling it an indirect call.
- Fixed (windows-x86_64): the failure path reached the socket arms of the Windows syscall emulation,
  so every `@no_alloc` function that indexes was refused there. The failure path and the scheduler
  use `rt_syscall_low` (write to a handle, exit, park, wake, yield, sleep, clock, unmap), and the
  profile dump creates and closes its file with `rt_create_file`/`rt_close_file`.
- **Native backend: a vector the loop cannot change is read once before the loop.** With the
  front end's loop-stability fact, the optimiser loads the vector's data pointer (and its length,
  when a check or `len()` in the loop needs it) into registers on the way into the loop, and the
  accesses inside read those. An unchecked access needs only the data register. fnv executes 11%
  fewer instructions.
- Bounds checks across loops that rebuild their vectors: a fact a `while` body's writes would end
  (`v.len == n` when the body swaps `v` with another vector) is kept while the body is compiled and
  checked where the body ends; if it holds again it holds at every evaluation of the guard and
  after the loop, and if not the function is compiled again without it. Assignments now state what
  they store (`v = tmp` gives `v.len == tmp.len`), a write keeps what its name tied together
  (`v.len == n` and `tmp.len == v.len` leave `tmp.len == n`), `x := y.copy()` has `y`'s length,
  `if hi > n { hi = n; }` leaves `hi <= n`, and an index `t - c` with `c <= t` and `n / 2` are
  read. Sort's checks in `main` go from 12 to 7.
  `for x in v` reads its element unchecked when the body mentions `v` only as `v[...]` and
  `v.len()` (no closure): the length the loop counted to cannot change.

- **Interface format 11:** an interface's trailer ends with `fast_hash` of the bytes before it (XXH64
  under four seeds, the build store's digest) instead of SHA-256. It guards against corruption, which
  is all a digest in the file itself can do; the source digest stays SHA-256. Interfaces written by
  an older compiler are refused by version and regenerated.
- Windows x86-64 builds (non-debug) assemble in the compiler too: `compiler/coff.grl` writes COFF
  objects byte-identical to clang's, `.pdata`/`.xdata` unwind for every function included
  (`grail asm --target windows-x86_64`), debug builds included (CodeView line tables). Fixed:
  `movsd` encoded as `movdqu` (the two shared an internal id).
- **Sized and signed arithmetic no longer divides in software.** The runtime's `rt_div` was a
  shift-and-subtract loop, and every overflow check of a sized or signed multiply and every sized or
  signed division and remainder went through it; it is now the hardware divide. jpeg decoding of a
  2048x2048 image: Grail-LLVM 25.8G -> 6.9G instructions, Grail-native 128G -> 38.6G. A case pins
  division, remainder and multiplication at the edges of every width (checked and wrapping), and
  `MIN / -1`, `MIN * -1`, division and remainder by zero and products one past the maximum abort.
- **The linux-x86_64 release package ships the release-built compiler.** `tools/ci.mjs` builds the
  compiler with the native backend as before (the bootstrap and fixed point) and then the release
  compiler from it (`tools/native.mjs release`: LLVM backend and clang -O2, accepted on identical
  text, objects and a corpus slice), and packages the release one - several times faster at
  compiling (`check` of a 104 000-line program: 11.2 G against 25.8 G instructions).
  `GRAIL_SHIP_NATIVE=1` ships the native build. `tools/compile-perf.mjs` measures
  `GRAIL_RELEASE_COMPILER` beside the dev compiler when it is set.

- Fixed: the per-loop stability fact and the LLVM backend's indirect-call fact both used fact kind
  7, so a stable vector whose slot number matched an indirect call's ordinal (with a loop head
  label of 6 or less) could make the lifter pass that call too few arguments. The stability fact
  is now kind 8.
- docs: `docs/design/ctfe.md` - an in-compiler evaluator over checked IR for compile-time values (design only).
- **R4: a compile-time probe compiles only what its values reach.** Before the bodies, a probe walks
  the bodies its value functions reach, name by name (a call, a method, a generic's template), and
  compiles only those; one that makes a closure or names `dyn` compiles the whole program, and a link
  that finds a function left out recompiles with everything. A recomputed value in a 1600-function
  program now costs +0.0-0.2 s instead of +1.1 s. The probes' base objects live in the build store
  (`<store>/probe-base`), which `grail cache clear` and `prune` cover.
- **Fixed: `grail build --release` for aarch64 and riscv64 failed to link any program with more than
  one module** (`duplicate symbol: rt_abort.c`). The thunk through which lifted code calls a native
  function is now weak, so every unit can carry it.

  Fact kinds are now named constants in one table (`llvm::FACT_*`), every writer and reader uses
  the names, and `ci.mjs lint` fails on a literal kind or on two names with one number.
- Fixed (release builds): a C call passing a record `byval` from an optimised function passed only
  its first word (the record was counted as one argument word); such calls are placed by the
  native C classification again. A typed C call whose loaded argument registers exceed its fact is
  now refused (an error under `--verify-facts`).
- Fixed (release builds): a function calling a blocking `extern "C"` function was left unoptimised
  since the foreign-call marker landed - the marker's locked counter, thread-pointer read and
  register save around `rt_foreign_lost` were text the LLVM lifter refused. It now lifts them
  (`lock incq`/`decq` as `atomicrmw` with the flags of the new value, the save area as words),
  and calls to Grail's own functions no longer trip the vector-register guard meant for C calls.
  tools/test-facts.mjs checks that a blocking-extern caller is lifted.
- `grail check` no longer builds the list of SIMD type names for every identifier it reads: names
  that cannot be one (wrong length, first letter or `x` position) are rejected first. This was 7% of
  checking a large program since the SIMD types arrived.
- The optimiser parses each distinct instruction line once per compile and replays the record for
  its repeats (a label operand is numbered again, the frame-slot bookkeeping redone): byte-identical
  output, 2.6% fewer instructions for a 4000-function file. The plan for taking the remaining text
  hops out of the dev backend is docs/design/in-memory-ir.md.
- **The inliner reaches further: copies inside copies, promoted registers, a 32-line cap.** A copy
  of a small wrapper keeps the call it makes last (`rt_new` calling `rt_alloc`); that call is now
  expanded too, three levels deep, since nothing of the copy is live across it. A small leaf whose
  values the optimiser put in callee-saved registers (`rt_block_bin`, `rt_job_deque`) is no longer
  refused: its copy keeps them in free scratch registers. The size cap is 32 lines, up from 24.
  Measured (callgrind, one worker, minimum of five), against main: a join 2742 -> 2652 instructions,
  a spawn 1631 -> 1583, fib(20) by nested join -1.7%. The compiler's own text is 4.0% larger and
  it compiles 0.85% faster.
- **The optimiser's liveness is linear in a function's length.** The register and frame-slot
  liveness behind dead-store removal, prologue zeroing and register colouring looked at every
  candidate slot on every line of every round; each line's effect is now worked out once per pass
  and read through a slot-to-candidate table. The output is byte-identical; compiling the compiler
  takes 20% fewer instructions, and a cold `grail build` of a 1000-function file 5.7% fewer.
- **Release builds compile a module's LLVM code in parallel.** `grail llvm-compile` cuts a lifted
  module into parts - shared declarations, each function in one part, internal functions renamed
  per unit - and runs `clang -O2` on all of them at once under the jobserver, then joins them. A
  release unit, and the release compiler itself (`tools/native.mjs release`), is no longer bound by
  one serial `clang -O2` over a gigabyte of IR.
  A function's part is a hash of its name and a part carries only the declarations it uses, so
  its text changes only when its own functions do; each part's object is kept in the build store
  (`llvm-parts/`) under the digest of its text and command, and a rebuild after an edit compiles
  only the parts holding changed functions.
- **A compile-time probe no longer compiles the runtime and the standard library.** They are
  compiled once into a cached base object with their interfaces (`.work/comptime/base/<key>`, keyed
  by the compiler, the options and their sources), and each probe compiles only itself and the
  program's own sources against them, then links with the base. The fixed cost of recomputing a
  value fell from +1.1 s to +0.07-0.11 s of CPU (the probe's function cache was invalidated by any
  change to the program's declarations, so the runtime was recompiled after every edit).
- `grail build --report checks` prints every runtime check left in the program's own functions,
  one line each: the function, `file:line:col`, and the kind (index, overflow, divide, conversion,
  refinement, ...). A check the prover removed is not listed, so what stays in a hot loop is
  visible. The report run is uncached, so a module from the build store cannot hide its checks.
  The compiler's own flag is `--report-checks`.
- **`grail cache warm [--target T]`** checks and builds every standard module into the build store,
  as rustup ships libstd: a project's first check then compiles only its own modules. The installers
  run it (not under DESTDIR), and compile-perf's template store is now a warmed one. Dev compiler,
  GRAIL_JOBS=1, a project's first check: bench/iterchain.grl 0.84G -> 0.24G, hashmap 0.72G -> 0.21G,
  json 1.33G -> 0.20G.
- A module run of a store build no longer re-hashes every interface it loads to check its trailer:
  the driver passes `--use-vouched`, because each one was written by a run of that build or restored
  from a blob whose bytes matched its content digest. Interfaces from a user's `--use DIR` or
  `--interface DIR` keep the check. An edited bench/iterchain.grl check: 0.267G -> 0.234G.
- **SIMD S2.**
  - New types: `u8x16`, `u8x32`, `u32x4`, `u32x8`, `i64x2`, `i64x4` and the masks `m8x16`, `m8x32`.
    Unsigned lanes compare, order and widen as unsigned.
  - `shuffle` and `shuffle2` take literal lane indices.
  - `to_f32`, and `to_i32`, which truncates, saturates and turns NaN into 0.
  - `bits` and `T::from_bits` reinterpret lanes.
  - `load_aligned` and `store_aligned` check the address and stop with it if it is misaligned.
  - With the LLVM backend, a 4x4 matrix product and an array-of-structs to struct-of-arrays
    transpose run as the same loops as C with SSE2 intrinsics: 1.04x and 1.17x C's instructions,
    the same time within the machine's noise.
- Fixed: the release compiler could be built by an older release compiler's LLVM backend and
  accepted although it miscompiled its own assembler (programs printed stray zero bytes). The
  release build now always lowers with the current native compiler, and accepts the result only
  when it compiles the compiler to the same text and the same objects as the native build and its
  programs pass a corpus slice (hello, strings, alloc, thread, sched).
- **`host::chmod(path, mode)`**: sets a file's permission bits, 0 or a positive errno (fchmodat on
  Linux, chmod on macOS, and 0 on Windows, which has no bits to set). The build store will use it to
  give a restored executable image its mode without a shell, once the bootstrap seed knows it.
- **`grail build` and `grail check` start no helper process to hash or file the build store**, and an
  unchanged program is decided from file stamps. Every `sha256sum`, `sh -c`, `mv` and `cp` the store
  ran (about 70 per small build) is now in-process: the store's digest is `store_hash` (XXH64 under
  four seeds, still 64 hex digits; store keys change once), and writes go to a staging file renamed
  into place. A new `fp/` record per file holds its digest plus the module, `use` lines and `@embed`
  flag the driver reads sources for, keyed by size, nanosecond mtime, inode and device. So a no-op
  build reads no source, the compiler's `--print-inputs` answer is remembered under the stamps of
  what it read (`inputs/`), and a tool's `--version` is asked once per binary (`tool-id/`). A module
  run with in-process assembly is one process, not a `grail unit-build` wrapper and the compiler.
  `host::read_file` reads straight into its result instead of pushing byte by byte, sized from the
  file's own size. With the dev
  compiler and GRAIL_JOBS=1, in user-space instructions: hello no-op build 0.235G -> 0.008G, hello
  check 0.310G -> 0.058G, hello build 0.453G -> 0.140G. `grail cache prune` drops `fp/`, `inputs/`
  and `tool-id/` whole.
- **Short floats print without big integers.** A double whose shortest form has at most 15 digits
  and lies in [1e-7, 1e22) (`0.25`, `1.037`, `123.5`) is printed from a candidate checked exactly
  with one correctly rounded operation (Clinger), with the same text as before; longer ones still
  go through Burger & Dybvig. Decimal-shaped values print about twice as fast (LLVM 729M -> 384M
  instructions for 6,000 of them).
- Parallel loops over several columns: `parallel_for_zip(grain, f, s1, .., s4)` and
  `pool::zip2/zip3/zip4` with generic callable bounds (simd-layout-parallel-loops.md 4.2). One split,
  the same index range of every slice per piece, equal lengths checked once, a piece per worker;
  same-vector-twice, captured arguments and `FnMut` callbacks are the ordinary refusals.

- **More small functions are inlined, and dispatch wrappers too.** The inliner filed a candidate
  under the first label of its body, which in a build with error locations is a statement's site
  label, not the function's symbol, so most small leaves were never matched to their calls. They are
  now filed under their symbol. A body whose only call is the last thing it does (`rt_alloc` picking
  `rt_alloc_unlocked` or `rt_alloc_shared`) is inlined as its test and the call it makes. Measured
  (callgrind, one worker, minimum of five): a join 2911 -> 2888 instructions, a spawn 1757 -> 1741,
  fib(20) by nested join -0.24%. An inlined wrapper is not a frame of its own in a backtrace.
- Fixed: `grail fmt` could break a long expression inside `<<` or `>>` (each is two `<`/`>` tokens),
  or start a continuation line with `<`, and the output then read as a generic argument list and no
  longer parsed. A wrapped line now never starts with `<` or `>`.
- **Faster rebuilds after an edit: unchanged functions' optimised code comes from the store.** A
  body replayed from the function store carried its parameters' type facts twice, so its key in the
  optimiser's memo differed from the one it was filed under and every body of an edited module was
  optimised again. The facts are now the fresh emission's, and the memo hits for every unchanged
  body: `grail build` of a 4000-function file after a one-function edit went from 95.7G to 34.0G
  instructions (GRAIL_JOBS=1). The stack-probe check reads the assembly once with no per-line
  copies, and the inlining pass's call lines travel with each remembered body instead of being found
  by a scan of the whole output.
- Fixed: `grail check` refused every program using a module that claims an effect (`use strings;`
  alone: "`is_char_boundary` ... makes an indirect call the compiler cannot follow"). Check runs go
  per module, and a check-only run recorded no effect facts, so the runtime's run wrote no
  `runtime.facts` and every claim that reaches the runtime met an unknown callee. A check run that
  writes interfaces records its bodies now; `tools/test-cli.mjs` checks a program using each lib/
  module.
- The internal assembler takes `.previous`.
- **Integer map keys hash in registers.** `hash::Hash` has a defaulted `table_hash`, the SipHash-1-3
  value a map uses (the default streams through `hash`, as before); the integer types give it as
  `hash::word_hash`, the same value computed straight-line with no hasher state in memory. User
  `Hash` impls need no change. bench/hashmap.grl: Grail-LLVM 0.88G -> 0.77G instructions and 0.30
  -> 0.27 s user (Rust 0.64G, 0.21 s), Grail-native 3.21G -> 2.69G.
- **Fix: every closure expression is a type of its own.** Two closure literals with the same
  signature and environment shape compared equal inside a generic type, so `k = keep(|| ..)` could
  replace a `Keep<F>` built from another literal; calls through it then ran the first literal's body
  (callable-bound calls are direct), and a borrowing closure could outlive what it borrowed. It is now
  a type mismatch, as in Rust.
- `left, right := split_at_mut(s, mid)`: two exclusive halves of one slice, usable at once
  (simd-layout-parallel-loops.md 4.3). The borrow checker gains sibling loan groups - halves of one
  split never conflict with each other or with what is reborrowed from them - and nothing about
  indices; `mid <= len` is checked as it runs.
- Fix: a bare `return;` in a function that takes a borrow no longer reports "returned borrow escapes
  its declared input lifetime" (its unit value was read from the first parameter's slot).
- **A closure passed straight to a `Fn(..)` parameter no longer allocates (call ABI S6 B).** A
  closure literal that is the whole argument for a plain `Fn(..)`/`FnMut(..)` parameter without
  `Owned` or a lifetime - which the checker keeps inside the call - builds its environment in the
  caller's frame, with an in-place drop, instead of `rt_rec`/`rt_free`. A 10 M-call loop through
  such a parameter: native 1,400 M -> 930 M instructions, LLVM 1,400 M -> 450 M.
- Release builds lift the foreign-call marker's register save around `rt_foreign_lost`;
  `GRAIL_LLVM_WHY=FUNCTION` prints the instruction that keeps FUNCTION unoptimised.

- **Text costs less to build and parse.** A string literal is checked to be UTF-8 while compiling,
  so making a `string` of it is a copy with no run-time check; appending a `string` onto a `string`
  no longer re-checks it; `format` hands its buffer over as the string instead of copying it, and
  checks it only when an argument may carry non-UTF-8 bytes. `json` copies a plain string in one
  step, writes one with no escapes in one append, and skips the whitespace call when the next byte
  is not whitespace. bench/json.grl: Grail-LLVM 4.48G -> 3.15G instructions (Rust 1.64G),
  Grail-native 14.3G -> 9.8G.
- **Native backend: float elements go straight to and from SSE registers.** A float loaded through
  a general register (`movq (%rax),%rax; movq %rax,%xmm8`) is `movsd (%rax),%xmm8`, and a store the
  same way back; the internal assembler encodes `movsd`, and AArch64 and RISC-V translate it to
  `ldr`/`str` and `fld`/`fsd`. nbody executes 7% fewer instructions.
- **Native backend: fixed-size array elements are addressed directly.** An element access reads its
  base and index from the registers that hold them instead of copies in `%rdi`/`%rsi`, and a load
  of the element takes the scaled address as its operand (`movsd (%r12,%rbx,8),%xmm9`) instead of
  computing it with `leaq` first. nbody executes another 10% fewer instructions.
- **Native backend: SSE register liveness by register number.** Whether a float register is still
  needed is now decided by its number, for promoted registers as for scratch ones, and through a
  chain of overflow checks; so more float operations work on their registers directly, and a float
  element loaded only to be an operand is read by the arithmetic itself (`subsd (%rdi,%rsi,8),%xmm8`).
  nbody executes 3% fewer instructions.

- **Raw address offsets.** In an `unsafe module`, the address operand of `raw_load`/`raw_store`
  and their narrow forms written as `p + k` with a literal `k` has no overflow check and is folded
  into the load's addressing (`movq 16(%rax),%rax`); other integer arithmetic there still follows
  the build's overflow mode. The runtime loses about 950 of its 2,664 overflow checks
  (docs/ffi.md; decision record "Raw address offsets").
- SIMD loads and stores take fixed-size array fields in place (`f32x4::load(&mat.m, 4)` on a
  `[f32; 16]` field, a row of `[[f32; 4]; 4]`); test-simd checks the loop over a vector of such
  structs stays in registers on LLVM.

- **Soundness: a callable bound's reference parameters are fresh on every call.** In
  `F: FnMut((&mut T), C) -> R` the `&mut T` has a lifetime the bound names nowhere else, so - as in
  Rust's `for<'a>` elision - the closure or function given for `F` must accept any lifetime there. One
  whose signature ties it to another parameter, its result or a capture (`fn leak<a, b>(v: &a mut T,
  out: &b mut Out<a>)`) could keep the reference past the call and is now refused: "its parameter N
  is a reference the bound gives it fresh on every call". It was accepted since callable bounds
  landed (through `vecs` callbacks and the typed iterator adapters too).
- **Fix: default interface methods work across modules.** An interface's default method bodies were
  not carried in its `.iface`, so an implementation in another module failed with
  "missing interface method (it has no default body)" under separate compilation (a single run was
  fine). The default's text now travels with the method record, as a generic template's does.
- **Changed: `split`, `trim`, `lines` and `split_whitespace` return views, and live in `strings`.**
  They were the compiler's own methods (and `strings` methods) returning owned copies; now they are
  `strings` methods (`use strings;`) returning views of the text (`(&[u8])[]`, `&[u8]`), like
  Rust's `&str` pieces, and `trim_start`/`trim_end` join them. A view keeps the text borrowed, so a
  piece that must outlive it is `split_owned(sep)` or `piece.copy()`. `for x in v` over a vector of
  views borrows each one in place, as `for x in &v` does. Views print and format as text.
- **`parse_f64`** (`strings`): decimal text to the nearest double, ties to even, as Rust's and Go's
  parsers: Clinger's exact path, then Eisel-Lemire over a 128-bit power-of-five table, then an exact
  big-integer fallback; `inf`/`infinity`/`nan`, overflow to infinity (`"1e400"`) and underflow to
  zero. It lives in the new module `float`, which `json` now uses too (its own bignum-only path is
  gone).
- **`out.append_format("{}:{};", a, b)`** writes `format`'s text onto the end of a `string` or byte
  vector with no string of its own (Rust's `write!`); onto a string only the new tail is checked to
  be UTF-8, and not at all when every argument is a number, bool, char or string.
- Integers print without a buffer per number or a software division per digit (`rt_fmt_num` wrote
  each number into a fresh allocation through a shift-and-subtract divide): two digits per division,
  straight into the output. bench/strings.grl (now `split` views, `parse_f64`, `append_format`, as
  its Rust twin): Grail-LLVM 11.65G -> 4.53G instructions (Rust 3.23G), Grail-native 35.7G -> 13.7G.
- The LLVM backend no longer mistakes a static's storage between two functions for a function (a
  module with a `static` and functions after it failed to assemble).
- `grail check` is about a fifth cheaper again: a check files *check units* - what a function asks
  of the build, without its assembly - and writes no assembly at all; a build does not take a check
  unit for its own and compiles that function. The compiler is no longer hashed on every command
  (its digest is kept in the store by path, size and time).

- **The standard map is one open-addressed table** (`lib/hashmap.grl`). Keys, values and their
  hashes are stored densely in insertion order (iteration order and `key_at`/`value_at` are
  unchanged), indexed by one table of slot words (a 32-bit hash tag and the entry index) with
  Robin Hood linear probing and backward-shift deletion, at most half full; the per-bucket vectors
  are gone. `hash::hash` (what the maps use) is now SipHash-1-3, as Rust's and CPython's tables
  are; `hash::hasher` stays SipHash-2-4. The hasher compresses a word at a time (`write_num`,
  `write_bytes`) instead of byte by byte, and `hash::table_hasher`/`hash::hash_from` hash from a
  prepared state. bench/hashmap.grl: Grail-LLVM 4.49G -> 1.10G instructions (Rust 0.64G),
  Grail-native 28.3G -> 4.6G (best development rival 8.1G). The LLVM backend emits generic
  specialisations `weak_odr` instead of `weak`, so LLVM may inline them, and pushing a record of
  whole words copies words rather than calling the byte copier.
- Fixed: a failed index check could be reported as `division by zero`. A `%` or `/` states its
  failure kind before its own check; when the optimiser removed that check (a divisor it proved
  non-zero), the kind stayed pending and named the next check in the function. A pending kind now
  ends with its statement, and an inlined bounds check is recognised by its shape first.
- **`extern "C" nonblocking fn`**: a foreign function promised never to block is called bare, with
  no foreign-call marker - the cost of a C-to-C call. The monitor cannot hand such a call off, so a
  wrong promise costs latency (a held worker), never safety. `blocking` and `nonblocking` now travel
  in interface files, so a call from another module behaves as declared. `docs/ffi.md`, "Blocking
  foreign calls", has the three forms and their costs.

- **A foreign call that holds a worker for more than 10 ms is handed off.** Every `extern "C"`
  call on x86-64 Linux counts itself in and out on its worker (about 1.2 ns a call, measured on
  10M calls of `labs`), and a scheduler monitor thread looks every 5 ms: a worker inside one foreign
  call for two looks while work is queued is given to a spare, as a `blocking` call would have
  been at once. The runtime says so once, naming the function, so it can be declared `blocking`.
  At most 10,000 threads may be blocked in foreign calls; the next one ends the program with a
  message instead of exhausting the machine.

- **SIMD vector types (S1).** `f32x4`, `f32x8`, `f64x2`, `f64x4`, `i32x4` and `i32x8`, with masks
  `m32x4`, `m32x8`, `m64x2` and `m64x4`.
  - They are plain values. Lane-wise `+ - * /` work on floats; wrapping `+ - *` and `& | ^` on
    integers; `& | ^` on masks.
  - Constructors are `splat`, `new` and `load` (from a slice or an array, one bounds check per
    vector). Methods are `store`, `sum` (a fixed halving tree, bit-identical everywhere), `lane`,
    `min`/`max` (the scalar NaN and tie rule) and the compares `eq ne lt le gt ge`, which give masks.
    A mask has `select`, `any`, `all` and `not`.
  - The LLVM backend lowers them to vector IR. A dot product runs within 5% of the same loop in C
    with SSE2 intrinsics, its loop entirely in registers. The native backend computes the same
    results lane by lane; packed SSE2 and NEON come later.
  - Interfaces are format 10.
- Fixed: an `Atomic<T>`'s element was not part of its type, so an `Atomic<u8>` could be passed where
  an `Atomic<u64>` was expected.
- Stack probes have a backstop: after the probe pass, any frame line (`subq $.F<n>[+K],%rsp`,
  `framesub`, or a literal `subq`) whose frame is larger than a page without its probe is an
  internal compiler error naming the function, so a new spelling of the frame line cannot drop the
  probe silently again. Frames within 128 bytes of a page are probed when the saved-register area
  carries them over it.

- Fixed: `grail fmt` could break a long expression inside `<<` or `>>` (each is two `<`/`>` tokens),
  or start a continuation line with `<`, and the output then read as a generic argument list and no
  longer parsed. A wrapped line now never starts with `<` or `>`.
- **Small runtime functions are inlined into every module.** A small runtime body (the scheduler's
  `rt_current`, `rt_list_set`, `rt_list_head`, ...) is now inlined where another module calls it,
  in every build shape: a per-module build carries the bodies in `runtime.facts`. A failure inside
  such a copy reports the calling statement. Measured with callgrind on one worker, against main:
  a join 3102 -> 3059 instructions, a spawn 1845 -> 1810.
- **Fixed: a release build of a program that calls C's `memcpy` failed to compile.** The LLVM
  module defines `memcpy`/`memset`/`memmove` itself, and an `extern "C"` declaration of the same
  name added a second, conflicting one ("invalid redefinition of function 'memcpy'"); the stdmap DNS
  and IPv6 cases failed under `GRAIL_BACKEND=llvm`. Those names are no longer declared again.
- `host::stack_left()`: the bytes left on the current green task's stack above its guard page (0 off
  a task), for recursive code that wants to stop or fork before it overflows.
- The scheduler's "enough stack left to help" check read the address of a helper's dead local,
  which the LLVM build may fold to anything; it compares a live one now
  (`sched-help-stops-when-the-stack-is-low` passes under both backends; its depth is now measured
  with `host::stack_left()` instead of being tuned to native frame sizes).

- **Typed iterator adapters: `iter::over(v).map(..).filter(..).fold(..)`.** `iter::VecIter<T>`,
  `iter::Map<I, U, F>` and `iter::Filter<I, F>` implement `Iterator` with each callback held by its
  own closure type, so a chain is one nested type, specialised and called directly, with no
  allocation per element; a `for` loop runs over any of them. `iter::fold_all(it, init, f)` folds any
  `I: Iterator`. `iter::Iter<T>` is unchanged (the erased form for `from_fn`, `dyn Iterator` or a
  field). Callable bounds now work on an impl's own parameters (`impl<U, F: FnMut(u64) -> U> W<U, F>`)
  and through interface files.
- Release builds pass only the words a call through a closure, function value or `dyn` slot uses:
  the other argument registers are `poison` rather than whatever they held, so LLVM no longer
  keeps stale values alive to fill them. dyncall: 719 M -> 679 M instructions (Rust -O: 648 M). A
  wrong word count is refused (an error under `--verify-facts`; `--forge-indirect=SYMBOL` shows it).

- Release builds optimise the runtime's job, task and thread runners again: they make calls
  through code pointers and were kept unoptimised after lifting them raced on the thread pointer.
  That race is fixed (every thread-pointer read is now an opaque one), and
  alloc-threads-pool-results-freed-by-waiter passes 50 runs of 50.
- The front-end fuzzer's baseline check skips a fixture marked `fuzz: refused` on its first line:
  the 21 inputs only rejection cases compile (`tests/interfaces/strictgen*.grl`, the visibility and
  inherent-method refusals, ...) carry the marker, so a refusal they are written to produce is no
  longer reported as a regression.

- **The optimiser inlines small functions in ordinary builds again.** A small leaf (at most 24
  instructions, no call but a failure exit) was only inlined when it carried no statement-position
  marker, and every statement of a build with error locations carries one, so outside
  `--no-error-sites` almost nothing was inlined (3 bodies on the scheduler's join probe, 57 with the
  flag). The markers now travel with the copy. A failure inside an inlined function still reports
  the line it was written on, but the inlined function is no longer a frame of its own: its caller's
  `= called from` line is the next one shown. Measured (callgrind, one worker): a join 3406 -> 3355
  instructions, a spawn 2089 -> 1858; the compiler's own text +0.4%.

- Fixed: a module exporting a `u64` constant at or above 2^63, or a negative signed constant, could
  not be read back from its interface ("carries a number wider than 64 bits"), so `grail build` of a
  program using such a module failed. The reader now accepts the tenth LEB128 byte that holds bit 63.
- Fixed: builds sharing one store at once (the per-module runs of one `grail check`, or several
  builds) wrote their `sha256sum` output to one file in the store, and one run could take another's
  digest and file a module under another module's interface ("core.iface describes module `io`").
  Each such command now writes to a directory it claims for itself.
- Removed: `--assembler=clang`. The internal assembler has been byte-identical to clang through a
  landing on every target it covers, so Linux x86-64, AArch64 and RISC-V builds always use it and
  `GRAIL_ASSEMBLER` no longer overrides it there (it still names the C compiler and the assembler
  for release builds, macOS and Windows).
- Arrays whose elements own data (`[string; 3]`, `[u64[]; 4]`) can be struct fields and vector
  elements: held inline and flat like every array, dropped in place with their holder.
- Fix: stack probes were skipped for every frame since frames also save callee-saved registers
  (`subq $.F<n>+K,%rsp`); a frame over a page could step over the guard page again. The probe
  matches that form, covers the K bytes, and the pinned case checks it on every target.
- `bun tools/compile-rivals.mjs` measures a no-op rebuild beside the cold build, the edited build and
  both checks, runs the rival twins as well as the generated programs, and reports instructions in one
  process (the primary figure) and wall time at four jobs; the results are `bench/results/compile.json`
  and the Performance chapter names the cause of every row where Grail is behind.

- **C calls with floats are optimised in release builds (call ABI S8a).** A function that called a
  C function with `f64`/`f32` arguments or a float result had to stay unoptimised on the LLVM
  backend (its floats travel in vector registers a lifted call did not carry). The front end now
  records each C function's argument and result types, and the lifter emits the call as C types it
  (`call double @scale(i64, double, float)`), on x86-64 for calls whose arguments are all in
  registers. Variadic calls, records and stack arguments keep the native body.
- **Records that own data are no longer boxed** (unboxed-values.md, stage 4). Every struct and
  tuple - strings, vectors and `impl Drop` included - is held as its words in the frame, inline in
  the record that contains it and flat in vectors; each type gets an in-place drop, and the boxes
  that remain (enum payloads, closures, `Mutex`, `dyn`, task results) drop in place and free.
  `check syn1000`: record boxes 404 k -> 71 k, peak memory 53 -> 41 MB.
- A `dyn` call on a record now costs one call: the vtable adapter that loads the record out of
  its cell was a function with its own frame calling the method; it is a load and a tail jump.
  dyncall (20 M dispatches): native 1,645 M -> 1,565 M instructions, LLVM 779 M -> 719 M (Rust -O:
  648 M).
- **Field predicates may relate fields of the same record:** `struct Span { lo: u64, hi: u64 where
  lo <= hi }`. A literal owes the predicate once every field has its value, every write of a field it
  reads owes it over the new value and the other fields, a mutable borrow of any such field is
  refused, and a reader through a shared reference or a non-`mut` binding gets it as a fact. A name
  that is not a field of the record is still refused at the struct. Strict mode proves literals; a
  single-field write it cannot prove, and says to rebuild the record.
- **Raw code follows the build's overflow mode, and the release compiler wraps.** Arithmetic in an
  `unsafe module` used to be checked whatever the build asked for; it now traps in a checked build
  and wraps in a wrapping one (`--release`, `--overflow=wrap`) like all other code. Code that must
  wrap says so with `wrapping_*`, as the runtime's address arithmetic does. `tools/native.mjs
  release` lowers the compiler with `--overflow=wrap`, as every release build does, so the release
  compiler no longer checks after nearly every address addition. `GRAIL_COMMAND_TIMEOUT` raises
  tools/native.mjs's per-step time limit on a loaded host.
- Fixed a silent release miscompile: a two- or three-word value whose address is taken (an `Option`
  from `pop()`, a small record passed by address) could be lowered by the LLVM backend as separate
  one-word stack objects when its width fact was missing, so writing its second word overwrote a
  neighbour - `pool::split` crashed under `--release` on 18e6943. The lifter now checks every access
  through an address-taken slot against the slot's declared width and keeps a body that reaches
  past it in native code (`--verify-facts` makes it an error). With that, the thread-pointer reads
  are lifted again (now with a memory clobber), so `rt_current`, the mutex fast path and the
  allocator's threaded path are optimised in release builds.

- AArch64 and RV64 native code drops moves that move nothing (call ABI S7): the word machine's
  result register is x9 (t0) and its first argument x0 (a0), and moves go through the scratch x10
  (t1), so calls and returns were full of `mov x0,x9` after `mov x9,x10; mov x10,x0`. A value number
  per register drops a move between two registers known equal; 1.5 % fewer lines in a small
  program's output on both targets.

- **Cheaper prologues on the native backend (call ABI S4-S5).** The callee-saved save area is
  part of the one frame adjustment (`subq $.Fn+16,%rsp`, where there were two), a promoted register
  or a cleared frame slot is zeroed only when the body may read it before writing it, and a first
  statement that returns without a call (`if n < 2 { return n; }`) is tested on the argument
  registers before the prologue, which moves behind it (shrink-wrapping). fib(32) on a dev build:
  155.1 M -> 112.8 M instructions (Go: 102.9 M); its base case is now four instructions.
- Fixed (LLVM backend): a function that called a C function with a float argument or read a float
  result kept that value in a vector register the lifted call never passed or returned, so
  `cbstk-callback-stack-arguments` printed NaN (0 on older builds). Such a body now stays native.

- **A call with more than six arguments no longer allocates (call ABI S3).** Words past the sixth
  went in a heap record behind the sixth register, which the callee copied and freed: an
  `rt_rec` and an `rt_free` per call. They now travel on the stack in the platform's layout (word
  6 + k at 8k(%rsp) at the call, 16 + 8k(%rbp) in the callee) on x86-64, AArch64 and RV64, and the
  LLVM backend lifts both sides. A 7-argument call loop (10 M calls): native 3,670 M -> 430 M
  instructions, LLVM 1,990 M -> 17.5 M. The interface ABI line gains `args = 6 registers then
  stack`, so an interface written for the old convention is refused.

- **Release builds call like C (LLVM backend, call ABI S1-S2).** A lifted function used to take and
  pass all six argument registers and return two words, and was almost never internal, so LLVM
  kept unused words alive across every call: fib(32) ran 112.8 M instructions against clang's 67.1 M.
  The front end now records each function's argument words; the lifter defines and calls it with
  exactly those and one result word (two for a `&dyn` result), and functions native code does not
  call are internal. fib(32) is 74.9 M, the shape clang emits. A wrong signature fact is refused, and
  an error under `--verify-facts`. Calls through closures, vtables and function values are lifted on
  x86-64 too, so the functions that make them are optimised instead of shipping as unoptimised
  text (`&Fn` call loop: 430 M -> 120 M instructions).

- `tools/land.sh BRANCH` (`just land`) lands a branch on main through one queue: the branch must already contain main, the fast gate runs on exactly its tree, and green fast-forwards main. Emulated targets run after the landing on the build host.
- **Fixed: a release-build segfault in `pool::split` and the other pool shapes.** Lifting the
  thread-pointer read and write into LLVM inline assembly (so that `rt_current`, the mutex fast path
  and the allocator's threaded path were optimised) put the allocator's thread-cache path in the
  lifted code, and a closure's capture was found zeroed after `pool::split` built it: five pool and
  scheduler cases crashed under `GRAIL_BACKEND=llvm`. Functions that read or set the thread pointer
  stay in the native stream again until the lifted form is shown correct. The landing gate now runs
  an LLVM leg over the pool, scheduler, unboxed and vector cases (`llvm-pool` in
  tools/landsvc/suites.txt).
- Fixed: a single-run build of a program whose module's text comes in two parts (its generic
  specialisations are emitted after the rest) could give two inlined copies of one body the same
  return label, and the output did not assemble. Each unit now numbers its inline sites across all
  its parts; `split-test` checks that no assembly it builds defines a label twice.
- **`extern "C" blocking fn`**: a foreign function declared `blocking` (a read, a wait, a present)
  does not take a worker with it. On a worker running a green task, the call hands the worker's
  queues to a spare thread for its duration and the calling thread keeps the task - C's frames and
  thread-locals stay where they are - then becomes a spare itself. Spares are reused - a
  thread is made only when none is idle - and an idle one exits after a second once more than the
  worker count are waiting. `host::read_file`, `write_file` and `command` from a task work the same
  way now, instead of starting a thread for every call. Off a worker the
  declaration changes nothing. x86-64 Linux for now; elsewhere `blocking` is a plain call. The old
  `rt_blocking_enter` warning ("a blocking foreign call is running on a green task's scheduler
  thread") is gone with the unsafe hook that produced it.
- **Release builds convert integers to `f32` with one instruction.** The LLVM lifter turns
  `rt_f32_from_int` - which halves the value in a loop and then calls `rt_f32_round` - into
  `sitofp`/`uitofp` to `float`, chosen by the source's signedness. Both round once to nearest even,
  as the runtime does, so results are bit-identical (the float matrix pins the edge values). A loop of
  three million conversions goes from 50 to 32 ms.
- **The internal assembler covers AArch64 and RISC-V.** `grail build --target aarch64` and
  `--target riscv64` (Linux) assemble in the compiler run too (`compiler/asm_a64.grl`,
  `compiler/asm_rv64.grl`; `grail asm --target T`), debug builds included. Their objects are
  byte-identical to clang's: the syn4000 program on both targets, and all 540 single-source corpus
  programs on AArch64 (`bun tools/asm-oracle.mjs --target aarch64 --corpus`).

- Fixed: the internal assembler refused `.hidden` (the runtime's `rt_sites_fill`), so every LLVM
  release build failed at `grail asm`. It now takes `.hidden`, `.protected`, `.internal` and
  `.comm`, and `.word` is 32 bits on AArch64. `tests/asm/` holds every ELF directive the
  compiler, runtime and LLVM backend write, checked byte-for-byte against clang by the landing
  suite `asm-oracle` (`bun tools/asm-oracle.mjs --suite`).
- Fixed: `grail check` of a library file (no `main`) failed with "executable entry requires readonly
  argv view", located in an imported module's interface (`result.iface`). A module with no `main`
  makes its first public function the entry, and that rule picked a function no entry can be (one
  taking a `u64` or a `&dyn Shape`). It now picks only a public function taking nothing or the
  argument view; a module with neither is told `no `main` in FILE`, located in the file.

- Fixed two compiler aborts on malformed input found by the front-end fuzzer: an unmatched `)` or
  `>` in an `extern` signature (an arithmetic overflow), and a file ending in a `//` comment or a `/`
  with no newline (an out-of-bounds read). Both are ordinary diagnostics now.
- `tools/fuzz-frontend.mjs` checks the unmutated source of any refused case whose first error points
  outside the mutated file, and reports a source that fails as it is as a `baseline` bug: a library
  that stops checking can no longer pass as a stream of fine refusals.
- **Fixed: a small record returned from a function with a refined parameter came back wrong.** Since
  the body became `<name>.proved` beside a checking wrapper, the typed-IR facts were still keyed by
  `<name>`: the optimiser did not see that a two-word result is returned in `rax:rdx` and dropped the
  second word (`mk(2, 5).hi` read 0), and the wrapper did not pass on the destination address a
  result of more than two words is written to. The body's facts now carry its own symbol, the wrapper
  states its two-word result too, and it forwards the hidden destination argument (also past six
  arguments). `refinement-wrapper-two-word-result`, `refinement-wrapper-dest-result`.
- `bun tools/abundance-perf.mjs`: every Abundance port program built through the build store (cold and
  after a one-statement edit), run (dev and release, checked against the parity reference) and the
  slowest profiled, on the current compiler and `--branch REF`; `bench/results/abundance.json` and a
  section of the Performance chapter. It found that a module exporting a `u64` constant above 2^63
  cannot be read back from its interface file, so eight of the ten programs do not build through
  the store.

- **Writing interfaces no longer costs the square of the declarations.** The interface writer put
  each list of names in order with a selection sort, and looked up every type's inherent methods
  by scanning every function of the program. A stable merge sort and a by-module index of the
  functions give the same interface bytes: an edited build of the 104k-line syn4000 program (one
  body changed, warm store) takes 36% fewer instructions.
- **Arrays by value and arrays of owners** (fixed-arrays.md, A3). Functions take and return
  `[T; N]` by value (a result travels in a short-lived box until results are in registers);
  `extern "C"` signatures refuse an array by value with a message naming the pointer form.
  Arrays may hold strings, vectors, options and records that own data: they move, drop their
  elements at the end of their scope, and replace an element by dropping the old one.
- **Generic array lengths** (A4): `fn sum<@n: u64>(a: &[f32; n])`, inferred from the argument's
  array type or given (`zeros<4>()`), and record value parameters as lengths
  (`struct Mat<@R: u64, @C: u64> { m: [[f32; C]; R] }`).

- **Arrays in records, vectors and C structs; arrays as slices** (fixed-arrays.md, A2). `[T; N]`
  is a field of structs, tuples and generic records (inline) and the element of a flat vector
  (`[f32; 4][]` is a C `float[n][4]`). Elements may be plain or extern records and C handles. `&a`
  is a `&[T]` / `&mut [T]` / `&[u8]` where one is expected, `a[lo: hi]` a sub-slice, every slice
  method works on an array, and `a.copy_from(&v)` copies a vector of exactly N in.
- **Changed: an `extern "C" record` field `[T; N]` is now an array, not a vector.** `ids := d.ids`
  is a `[u32; 4]`; `d.ids[3]` reads and writes in place and `&d.name` is a `&[u8]`. Initialise and
  assign it with an array literal (`name: [0; 16]` where `u8[0; 16]` was written); a vector is
  copied in with `d.ids.copy_from(&v)`, which checks the length. The copy-as-vector surface
  (`rt_carray_store`, the field-assignment special case) is gone.
- **A callback from C keeps its task on its thread.** A Grail function that C called from a green
  task could wait (sleep, lock, join) and the task then resumed on another worker, so it returned
  into C's frames on a different OS thread - with C's thread-locals and locks belonging to the old
  one. A thread now counts the callbacks it is inside, and a task that waits there blocks its
  thread instead of moving (`callback_pins_task`: 181 of 200 calls came back on another thread
  before, none now). While it waits, that worker runs nothing else; handing the worker's queue to a
  spare thread is the next step of stage 6.
- Fixed: **`grail check` (and a default build) of a program with a compile-time value needed a C
  compiler, or failed.** A probe is now assembled in process and linked with the build's linker, and
  a module of a separate build - which reads the runtime as an interface - gives its probe the
  runtime's sources. A value the batch probe cannot compute is computed by its own probe before the
  interfaces are written, so `check` and `build` report the same error for it (it was an internal
  "no type" error in a separate build). Module-binding guards in a probe are defined once (the
  internal assembler has no `.comm`).

- A table static can be a vector literal of constant expressions - `static K: u64[] = u64[0x428a2f98,
  0x71374491];` - baked with no compile-time probe. The compiler's own sources hold only such
  constant-tier values (`ci.mjs lint` refuses a run-tier one there, which would compile the whole
  compiler in a probe on every cold build). The runtime gains `raw_sites`, the site-table helper
  called by name, ahead of its first use at the next reseed.

- The landing queue's build host runs the aarch64 legs under the patched qemu-aarch64:
  `tools/land-remote.sh` builds it there with `tools/qemu/build.sh` before starting the legs, and
  `tools/land.sh --remote-status` (`just land-status-remote`) prints each emulated leg's verdict for
  the newest landing. `build.sh` names any missing build dependency and the packages that provide it.
  Beside the emulated legs the build host runs the front-end fuzzer at 2000 cases, seeded from the
  landing, and `--remote-status` reports it with the shrunk input of anything it found.
- **Grail assembles its own x86-64 code.** `grail build` and `grail run` on Linux x86-64 no longer
  run clang to assemble. The compiler's own assembler (`grail asm IN.s -o OUT.o`,
  `compiler/asm_x86.grl` and `compiler/elf.grl`) writes the ELF objects. It covers exactly the
  subset the compiler emits and runs inside the compiler run, so the build no longer writes and
  re-reads the module's assembly (`--object`), and its objects are byte-identical to clang's from the same text
  (`tools/asm-oracle.mjs`; the gate's `asm-oracle` leg checks every corpus program). In the release
  compiler it assembles the syn4000 program's 35 MB of assembly in 0.41 s against clang's 1.37 s,
  and the self-compile's 119 MB in 1.1 s against 5.2 s. Debug
  builds go through it too (it writes `.debug_line` from `.file`/`.loc` as LLVM does); the other
  targets still use clang. It lowers the portable atomic operations as it reads them, so an x86
  build no longer rewrites the whole stream for them first. It keeps each object's function units
  beside it (`OBJ.units`): a function whose text did not change is replayed, not assembled again
  (`GRAIL_ASM_UNITS_VERIFY=1` checks the replayed object against a plain assembly).

- **Callable bounds: `fn map<U, F: FnMut(T) -> U>(self, f: F)`.** A type parameter may be bound by a
  closure type; a value of that type is callable in the generic body, the closure's own type is what
  the specialisation is made for, and its parameters and result are inferred from it. A closure whose
  type is known - a local closure, or one given for such a parameter - is now called directly, by its
  body's symbol, instead of through its code word, so the optimiser can inline it. The `vecs`
  callback methods (`map`, `filter`, `fold`, `any`, `all`, `find`, `position`, `sort_by`, ...) take
  callable bounds. A closure given for a callable-bound parameter without `Owned` is lent for the call,
  as an `Fn(..)` parameter is. Fixed with it: two capture-free closures with the same signature given
  to one generic function were one specialisation; they are two.
- Engine-shaped benchmarks against C, Rust, Go and Zig (`bench/hashmap`, `bintrees`, `strings`, `json`,
  `dyncall`, `iterchain`, `ecs`, each with matched outputs in all five languages), with a section of
  their own in the book's Performance chapter naming why Grail is behind on each
  (`bench/results/engine.json`, refreshed by `just bench-results` and the gate).

- **`grail check` is incremental.** It goes through the build store as `grail build` does: one
  compiler run per module, a module whose inputs did not change is not checked again, and in a
  module that is, the unchanged function bodies replay. A check after an edit to one module checks
  that module. A module with errors reports them; the modules that read it print one line each
  (`not checked: `c` depends on `a`, which has errors`) and the independent modules are still
  checked. A check and a build share their records, so a build after a check reuses its units.
- Added: TLS over the operating system's own implementation. `lib/tls.grl` gives `TlsConfig`, `TlsClient`, `TlsStream` and a `tls::Error` that keeps four classes apart - `Verify` (the chain or name was rejected, never retried), `Protocol`, `Io` and `Closed` (already closed, or the peer's connection ended without a `close_notify`; `read` returns 0 only for a clean one). Peer verification has no switch: a client refuses to exist while its trust store is empty (`NoTrustStore`) instead of verifying nothing, the store is checked for content on Linux rather than assumed, `SSL_CERT_FILE`/`SSL_CERT_DIR` are honoured, and the name or address handed to `connect` is always checked against the certificate (`SSL_set1_host`, `X509_VERIFY_PARAM_set1_ip_asc`). The socket is never given to the C library: memory BIOs plus `WANT_READ`/`WANT_WRITE` mapped onto `host::read_fd`/`host::write_fd`, so a TLS stream suspends its task on the reactor exactly like `net::TcpStream`. One `TlsClient` is one context (and therefore one session cache), `connect_over` consumes a `net::TcpStream` so the descriptor cannot be closed twice, `shutdown` sends `close_notify` and keeps reading, `close` sends it and releases both. The Linux binding is executed: the local `openssl s_server` pair in the corpus proves the handshake is REFUSED for an untrusted self-signed certificate and ACCEPTED once it is the anchor, then 3000 bytes are echoed byte for byte; a real handshake against `example.com:443` pins the version, ALPN and subject; a missing CA and an empty system store are both refusals. The link-note rule is pinned both ways: `tls-link-notes-absent-without-import` fails if a program that never imports `tls` emits `// grail-link: ssl`/`crypto`, and `tls-trust-store-empty-refuses` pins that one which does import it emits both. macOS and Windows are refused: a build of a `tls` program for either stops with a compile-time message naming what is missing (a SecureTransport layer was written but never run, and SChannel is not implemented) - docs/design/tls.md records the plans. Book: *TLS over the system stack* in *The standard library*, and *Link inputs, and per-target bindings* in *Calling C*.

- **`dyn<Send> I`, `dyn<Share> I` and `dyn<s> I`.** An interface object can now say what the value
  behind it may do: `dyn<Send> I` may cross to another thread (a `parallel_map` item, a task item,
  `T: Send`), `&dyn<Share> I` may be shared by workers, and `dyn<s> I` may hold borrowed data from
  `s` (its loans are kept). The bound is checked where a value is boxed, against its concrete type;
  bounds may be dropped (`dyn<Send> I` to `dyn I`) but not added. A bare `dyn I` is unchanged - it
  holds no borrow and is neither Send nor Share - and its refusal now says to write `dyn<Send> I`.
  `Owned` is never written on `dyn`. Interface format 9.
- **Faster iteration over owned vectors.** `iter::of(v)` and the consuming `vecs` methods (`map`,
  `fold`, `filter`, `filter_map`, `flat_map`, `for_each`, `reduce`, ...) no longer copy the vector
  into a reversed one by popping and pushing every element (an option allocated per element, twice):
  they reverse it in place and take elements with `pop()!`. `v.reverse()` itself is a two-pointer
  loop instead of a bounds-checked swap call per pair (about 10x).
- Fixed: a debugger read records wrongly after the unboxed-values layout (stages 1a and 1b). A
  reference to a record is the record's own address, but DWARF and CodeView still described it as a
  pointer to a pointer, so `print *o` showed garbage. A plain record held in a record or a vector is
  stored inline, but it was described as a pointer at an 8-byte slot. Both now follow the layout:
  `&Outer` is `Outer *`, a plain field is the record itself at its real offset, and a flat vector's
  element is the record (`tests/debug_members.grl`, `tools/test-debug-lines.mjs`).

- **`grail check` grows linearly with function length.** The borrow checker answered "is any
  bond held under this place?", "which bonds does this reference rest on?" and "is this bond new?"
  by scanning every bond the function had made, after every statement and every use, so one long
  function cost the square of its length. The bonds are now indexed by holder, with a mark on each
  place that holds one inside it. A binding's last use is found by reading the scope's tokens in
  place, and a name is told from a keyword without building a keyword list per binding. `grail
  check` no longer spells the assembly it throws away: the text emitters write nothing in a
  check-only run. Checking the 104k-line syn4000 program takes 47% fewer instructions, and the
  verdicts are the same: `tools/check-diff.mjs` compiles every corpus
  source and example with two compilers and compares their output byte for byte (with `--build`,
  the assembly too).
- Fixed: **a failed check inside the compiler itself faulted instead of reporting.** The failure
  report was written in process-state bytes 4096..8192, but `rt_state` is sized by the entry stub
  of the compiler that built the binary, and the compiler is built by its seed, which gives 4096.
  The report block is now mapped on first use (its address in state word 3432), so it is the same
  in every binary, and `rt_state` is 4096 bytes again.

- **Compile-time values cost one probe per build, and none when nothing they read changed**
  (comptime-speed R2, R3). Every run-tier value a build needs is computed by one probe; each is then
  cached with what it read - the program's function bodies its computation reached, the
  non-function declarations, the other values, the runtime and standard library files, the compiler
  and the options - so an edit anywhere else runs no probe. 100 values: one probe (+2.3 s CPU on a
  first build, +0.9 s once the probes' function cache is warm), and no probe on a warm rebuild or
  after an unrelated edit. A value that fails names itself, its call and its declaration (a failed
  check, a refused effect, an exit).
- **The LLVM lifter lowers a module's functions in parallel.** The functions are cut into pieces of
  about equal size, one forked copy each as the build's jobserver allows (`GRAIL_JOBS=1` for one
  process), and the pieces are put back in order; a function's temporaries and fresh blocks are
  now numbered within it, so the module text is the same whatever the count. Together with the
  table lookups that replaced the lifter's per-call and per-slot scans, lifting the compiler goes
  from 904 s to well under the old figure on one core (136 s measured before this change).
- **Native backend: a store into a `u8[]` is inline.** `v[i] = b` was a call to `rt_write`, which
  checked the bound and the byte range again; it is now the bounds check and one `movb`, and a
  slice's store uses the hoisted data and length. The byte range is the front end's: a `u8` value,
  or the check it emits before the store. The sieve benchmark executes 58% fewer instructions.
- **Native backend: fixed-size array elements and float arithmetic take fewer instructions.** An
  array element whose length and element width are constants is checked against an immediate and
  addressed with a scaled index (`cmpq $15,%rsi; leaq (%rdi,%rsi,8),%rax`) instead of loading both
  and multiplying. And a float operation on values held in SSE registers works on them directly
  (`subsd %xmm9,%xmm8`) instead of copying both into the scratch pair and the result back. nbody
  executes 27% fewer instructions.
- **Native backend: three small rewrites.** A local whose address is taken only to load it at once
  (`leaq -N(%rbp),%R` ... `movq (%R),%R`) is loaded directly, so it can be kept in a register; a
  shift by a constant uses the immediate, and the run-time check of a constant shift count (or any
  comparison of two constants) is decided at compile time; an accumulator worked on in %rax
  (`movq %r12,%rax; xorq ...,%rax; imulq ...,%rax; movq %rax,%r12`) is worked on in its own
  register. fnv executes 15% fewer instructions, sieve 3%.
- **Native backend: callee-saved registers are shared by variables whose lives do not overlap.** The
  optimiser kept one register per promoted local for the whole function, so the variables of a
  function's first loop held the registers its later loops needed. Locals are now coloured by
  interference, as float locals already were. fnv executes 4% fewer instructions, nbody 3%.
- **Native backend: a call to a Grail function keeps alive only the registers it takes.** The
  signature fact (the argument words LLVM's `define` uses) is now recorded for native builds too,
  and a direct call to a body with one reads only that many argument registers instead of all six,
  so a value left in, say, `%rcx` before a one-argument call is no longer kept for it. fib(32):
  112.8M -> 105.8M instructions (Go 102.9M).

- **Native backend: a slice's `data` and `len` live in registers.** The type facts are recorded on
  the native path too, and the optimiser reads F1's slice-descriptor fact: a slice written once at
  the top of a function keeps its data pointer and length in two callee-saved registers, so a
  checked access is `cmpq %rL,%rsi; jb` and an indexed load (`movq (%rD,%rsi,8),%rax`), and
  `n := x.len()` is the length's register. A failed check still names the index and the length
  (`rt_trap` kind 64; `slice-hoisted-len-index-message`). With it: `movl`/`movb` are known
  instructions (they were barriers across which every register was live); a float slot is found
  through the temporaries the front end copies results through; a float held in a register across a
  drop helper call is saved around it; and the type facts of a frame slot are looked up under the
  table's own numbering (`-8(k+1)(%rbp)` is slot k), which the typed IR had off by one.
  Instructions per element against scalar C: xform_f32 8.7x -> 6.9x, xform_f64 7.1x -> 5.6x,
  dot_f32 10.8x -> 8.9x, dot_f64 8.6x -> 6.7x, matmul 12.4x -> 11.4x.
- **Allocation costs half what it did.** The size class of a small request is a compare chain
  instead of a doubling loop, and the allocator's address arithmetic no longer checks for overflow:
  about 38 instructions per allocation instead of 96, 30 per free instead of 44. `grail check` of a
  104k-line program does 21% fewer instructions and uses 10% less CPU. And in a release build the
  runtime functions that read the thread pointer - the allocator's threaded path, the current task,
  the mutex - are now optimised by LLVM like the rest; they were left in unoptimised code.
- Landing on main goes through a service (`tools/landsvc/landd.py`, client `tools/land.sh`): it merges each queued branch onto current main itself, gates up to four together, retries a red train one branch at a time, and cannot be stopped by killing the process that queued a branch.
- `tools/pkg-test.mjs` passes again and runs in the gate and the landing queue. Its offline-build
  check called `grail run --offline`, a flag only `add`, `update` and `fetch` have (a build never
  networks); the stricter option parser refuses it, and nothing ran the suite to notice. Running
  it found a real bug: `grail test` in a project no longer saw the root's dependencies or its
  dev-dependencies (`use kit;` in a test failed to resolve) since the test runner was rewritten;
  each test program now gets the plan's module list, dev-dependencies included.

- **A fork wakes a worker only when none is searching.** Idle workers look for work a little longer
  before they sleep, and a fork wakes a sleeping worker only when no worker is still looking. In a
  join the forker usually takes its own fork back, so the old rule (a futex wake per fork whenever
  any worker slept) cost two system calls per join. 100,000 joins on a worker now make 15 wakes.
- **A task's sleep no longer hangs when woken early.** A sleep woken before its deadline waited
  again on a one-shot timer that might already have fired; it now re-arms for the time left. The
  I/O task of `bench/frame.grl` hung on this about one run in four.
- A Background job's cap slot is taken with the job's claim, so a slot cannot leak to a job
  another stack runs.
- Fixed: on windows-x86_64 every `@no_alloc` function that indexes, casts or unwraps was refused
  (`lib/strings.grl`'s `is_char_boundary` among them, so `bun tools/windows.mjs check` failed): the
  runtime's calls through the import table were unknown edges, and the syscall dispatcher the
  failure path calls reached `rt_alloc` through the pipe arm's heap-allocated SECURITY_ATTRIBUTES. An
  import-table OS call in the runtime is now modelled as a syscall (no Grail heap, no failure), and
  CreatePipe's attributes live in process state.
- Added: sockets on Windows. `lib/net.grl`'s TCP layer now works on `windows-x86_64` instead of reporting `ENOSYS`: Winsock is started once per process (`WSAStartup` 2.2) and cleaned up on exit, a socket is an overlapped `WSASocketW` descriptor in the platform's own record list, and a receive or send is an overlapped `WSARecv`/`WSASend` whose completion the waiter takes from the request's own event - on an offload thread, so a task blocked on a socket parks and never holds a worker. `connect` is ConnectEx, resolved through `WSAIoctl(SIO_GET_EXTENSION_FUNCTION_POINTER)` because no DLL exports it on every stack, with `SO_UPDATE_CONNECT_CONTEXT` and a forced bind (and a blocking fallback), and `raw_win_call` now passes up to eight word arguments with the Win64 caller frame so the extension pointer can be called. `accept` is a blocking `accept` on an offload thread: `AcceptEx` was implemented first and withdrawn, because under Wine - the only host that runs these tests - it and a cooperative accept both complete only for an already-queued connection. Winsock errors map onto the errno space the portable layer reports (`WSAEWOULDBLOCK` never reaches a task, and `WSAECONNRESET`/`WSAECONNABORTED` on a receive are end of stream, not an error). `win-sockets-echo` runs the whole path under Wine, non-ASCII text included. Not implemented: driving sockets from the I/O completion port (it cannot be verified on this host, and the design says what it would need), UDP (`WSARecvFrom`/`WSASendTo` have no portable operation or library API to reach them), and cancellation of a task blocked in a socket call. Design and evidence: *Sockets* and *Sockets: what is verified* in docs/design/windows-backend.md.
- Added: wide-character paths on Windows. Every file and process entry point is now the `-W` one - `CreateFileW`, `CreateDirectoryW`, `DeleteFileW`, `RemoveDirectoryW`, `GetFileAttributesW`, `GetCurrentDirectoryW`, `GetModuleFileNameW`, `CreateProcessW`, `GetCommandLineW`, `GetEnvironmentStringsW`/`FreeEnvironmentStringsW` - so a file name outside the system code page is no longer mangled into the ANSI code page. One convention holds it together: every entry point in `compiler/os-windows.grl` takes and returns UTF-8, and `rt_win_wide`/`rt_win_utf8_of` convert at the FFI boundary in a fixed 128 KiB arena (five 16 KiB slots, no user allocation), so no call site converts by hand. The encoder refuses invalid UTF-8 with `EINVAL` instead of replacing bytes - overlong forms, bare continuation bytes, truncated sequences, encoded surrogates and code points above U+10FFFF - and encodes a code point past U+FFFF as the surrogate pair UTF-16 requires; text the OS hands back with an unpaired surrogate becomes U+FFFD in the one inbound helper, because refusing `argv[0]` would leave a process with no arguments. `CreateProcessW` gets the MSVC quoting rules applied to UTF-16 units (`rt_win_quote_w`/`rt_win_split_w`), so an argument survives the trip in both directions, and its environment block is UTF-16 with `CREATE_UNICODE_ENVIRONMENT` - without that flag Windows reads a non-NULL block as ANSI and the child sees an empty environment. `host::list_dir` works on Windows for the first time: a read-only open of a directory returns an enumeration backed by `FindFirstFileW`, and `rt_syscall(217)` rewrites the find results into the `dirent64` stream the portable decoder already parses, as the Darwin module does for `getdirentries64`. `GetModuleFileNameW` also wires `host::exe_path` (it answered nothing before). Six dead Win32 import declarations are gone with their entries: `ExitThread`, `GetEnvironmentVariableA`, `SetFilePointerEx`, `FlushFileBuffers`, `MoveFileA` (no portable rename operation calls it) and `GetSystemTimeAsFileTime`. `tools/test-windows.mjs` now fails the suite if any case's object imports an ANSI entry point, and runs `win-unicode-paths` under Wine: Latin-1, CJK and emoji file names, a non-ASCII directory, a non-ASCII working directory and argument, and the `EINVAL` refusal. Design: *Text at the Win32 boundary* in docs/design/windows-backend.md.
- Bounds checks: an index that is a sum of `term * constant` products and constants - `p[i * 3 +
  k]` - is proved in bounds when every term has a literal upper bound in the facts and the largest
  value the sum can take is below the length (a fixed array's constant, or a vector's `len()` the
  facts know). The sum is bounded far below 2^64, so a release build computes the value that was
  proved. nbody's own array checks go from 24 to 0. A name the facts equate with a literal (`n := 256`) reads as that literal, and a loop count they make
  constant (`for i in n * n`) bounds the loop variable and the vectors a push loop fills: matmul's
  checks go from 6 to 0.
  The same interval facts prove the index arithmetic itself cannot overflow (`i * 3 + k` with `i < 5`,
  `k < 3`): `*` and `+` on such operands carry no overflow check in any build (nbody: 44 traps in its
  own functions -> 2). A proved byte store (`composite[j] = 1`) is one instruction (sieve: 1 -> 0).
  Under `--verify-facts` a check a proof removed is kept and still not counted as a failure, so
  `@no_panic` accepts the same functions in both builds (a kept index check and a proved call
  through the checking wrapper both name the proof).

- Bounds checks: a vector filled from empty by a counted loop - `for i in n { v.push(x); }`, one
  push per iteration, no `break` or `continue` - has `v.len == n` after the loop, so a later
  `for i in n { v[i] }` indexes without a check. The ECS benchmark's update loop loses all 18 of its
  checks. A push inside a branch, an early exit, or a vector that was not empty states nothing.
- Added: wide-character paths on Windows. Every file and process entry point is now the `-W` one - `CreateFileW`, `CreateDirectoryW`, `DeleteFileW`, `RemoveDirectoryW`, `GetFileAttributesW`, `GetCurrentDirectoryW`, `GetModuleFileNameW`, `CreateProcessW`, `GetCommandLineW`, `GetEnvironmentStringsW`/`FreeEnvironmentStringsW` - so a file name outside the system code page is no longer mangled into the ANSI code page. One convention holds it together: every entry point in `compiler/os-windows.grl` takes and returns UTF-8, and `rt_win_wide`/`rt_win_utf8_of` convert at the FFI boundary in a fixed 128 KiB arena (five 16 KiB slots, no user allocation), so no call site converts by hand. The encoder refuses invalid UTF-8 with `EINVAL` instead of replacing bytes - overlong forms, bare continuation bytes, truncated sequences, encoded surrogates and code points above U+10FFFF - and encodes a code point past U+FFFF as the surrogate pair UTF-16 requires; text the OS hands back with an unpaired surrogate becomes U+FFFD in the one inbound helper, because refusing `argv[0]` would leave a process with no arguments. `CreateProcessW` gets the MSVC quoting rules applied to UTF-16 units (`rt_win_quote_w`/`rt_win_split_w`), so an argument survives the trip in both directions, and its environment block is UTF-16 with `CREATE_UNICODE_ENVIRONMENT` - without that flag Windows reads a non-NULL block as ANSI and the child sees an empty environment. `host::list_dir` works on Windows for the first time: a read-only open of a directory returns an enumeration backed by `FindFirstFileW`, and `rt_syscall(217)` rewrites the find results into the `dirent64` stream the portable decoder already parses, as the Darwin module does for `getdirentries64`. `GetModuleFileNameW` also wires `host::exe_path` (it answered nothing before). Six dead Win32 import declarations are gone with their entries: `ExitThread`, `GetEnvironmentVariableA`, `SetFilePointerEx`, `FlushFileBuffers`, `MoveFileA` (no portable rename operation calls it) and `GetSystemTimeAsFileTime`. `tools/test-windows.mjs` now fails the suite if any case's object imports an ANSI entry point, and runs `win-unicode-paths` under Wine: Latin-1, CJK and emoji file names, a non-ASCII directory, a non-ASCII working directory and argument, and the `EINVAL` refusal. Design: *Text at the Win32 boundary* in docs/design/windows-backend.md. Redone on current main (2026-11-17): the metadata, rename, symbolic-link and redirected-spawn layer that landed after the first version moved to `GetFileAttributesExW`, `MoveFileExW`, `CreateSymbolicLinkW` and `CreateProcessW` too, pinned by `win-unicode-stat-rename` under Wine.

- **Fixed: an LLVM-backend miscompile of a vector grown through its address.** A call handed `&mut v`
  receives the slot's address, not the header word, so the lifter did not count it as a call that
  can grow `v`, and the `len`/`data` it had read before the call were used after it: `pad(&mut out,
  4); out.len()` read the old length (65 / 73 / 0 instead of 72 / 73 / 7). Now any call that is not
  known to leave headers alone makes the cached fields of every vector whose address the function
  takes stale, and they are read again. `vector-grown-through-its-address-is-reread` covers the
  direct call, a loop, a method on a record holding the vector and a record passed by `&mut`.

- Fixed: an error inside a closure made the compiler re-run itself up to 20 times. To report the
  next error it re-runs with the failing body skipped, and for a closure it skipped the wrong body,
  met the same error again and chained to the cap: an eight-line program took 14 s to reject
  (30 s with a second error), now under 2 s with the same diagnostics. Found as two "hangs" of the
  front-end fuzzer.
- A `use` naming a module no root holds is an ordinary diagnostic: `error: cannot resolve module
  ...` with the `use` line's location and the name underlined, instead of a bare `grail:` line.
- `tools/fuzz-frontend.mjs` names its five slowest cases in the summary and in `report.json`.
- **The atomics family.** `Atomic<T>` now holds `u8`, `u16`, `u32`, `u64`, `i8`, `i16`, `i32`,
  `i64` or `bool`. Each width wraps at its own size, and `fetch_min`/`fetch_max` are signed for
  `i*` types.
  - Every operation names its ordering:
    - `load` with `_relaxed` or `_acquire`; `store` with `_relaxed` or `_release`.
    - `swap` and `fetch_add`, `fetch_sub`, `fetch_and`, `fetch_or`, `fetch_xor`, `fetch_min`,
      `fetch_max`, each with `_relaxed`, `_acquire`, `_release` or `_acqrel`.
    - `compare_exchange` (returns the value it saw) and the new `compare_exchange_weak` (returns
      whether it stored), each with the same suffixes.
    - The bare name is sequentially consistent, and a pair that makes no sense (`load_release`) is
      an error that lists the valid names.
    - `fence()`, `fence_acquire()`, `fence_release()` and `spin_hint()` are new.
  - The methods compile to instructions at the call site, not runtime calls, so they are allowed in
    `@no_alloc @no_panic` code. Each ordering is lowered as itself: x86-64 SC loads lose their
    `mfence`, `fetch_add` is one `lock xadd`, AArch64 uses `ldar`/`stlr` and exclusive pairs, RISC-V
    uses AMOs, and the LLVM backend emits `load atomic ... acquire` and so on instead of
    `fence seq_cst`.
  - Measured on x86-64: an uncontended `load` went from 15.4 ns to 1.4 ns, `fetch_add` from 18.5
    ns to 1.8 ns, and a Mutex round trip from 42.7 ns to 11.4 ns. The runtime's own atomics
    (scheduler, jobs, mutex) use the same instructions.
  - `Atomic<u64>` programs are unchanged.
  - Interfaces are format 8: an `Atomic<T>` records its element (format 7, from the effects
    work, added the summary rows of every listed function).
  - `bun tools/test-atomics-litmus.mjs` runs the litmus suite on every target and both backends.
    `bun tools/test-optimiser-atomics.mjs` checks that the optimiser moves nothing across an
    atomic.
- **`concurrent_map` lookups run side by side.** Its shards are `sync::RwLock`s now, so `contains`
  and `len` on one shard no longer queue behind each other (about 1.6x faster under a read-mostly
  load, `bench/shard_read.grl`). Keys and values must therefore be `Share` as well as `Send` -
  DashMap's rule - and a value also `Owned`, since `insert` and `remove` hand the old one back. A
  map of a type that is transferable but not shareable is refused with
  `type does not satisfy Share`, naming the type.
- Fixed (statics, after the merge with unboxed records and the prover rework): a static's
  initialiser is evaluated in its own module's scope whoever asks for it first, so `PAGE - 1` finds
  `PAGE` when the interface writer asks at the end of the compile; a baked record is laid out as the
  record layout now has it (a plain record held in a field inline, a vector of plain records flat)
  and read through the record's address, which is what a record reference now is.

- **A compile-time probe never starts another probe** (comptime-speed R1). Inside a probe a read of
  a run-tier value calls a value function the probe defines - a static is computed once on first
  read behind a guard, a module binding at each read - so N values cost N flat compiles instead of
  a chain N deep (12 values: 7.6 s; before, never finished). A cycle is a compile error naming every
  value on it and the path (`main::A -> main::B -> main::A`).
- **Proved calls cost nothing again, on every target and on the LLVM backend.** A function with
  refined parameters is two ordinary functions: the body, `<symbol>.proved`, with no checks, and
  `<symbol>`, a wrapper that checks the parameters and calls it. A proved call calls the body
  directly - the same instructions as a call to a function with no predicate (measured on
  x86_64, aarch64 and riscv64: identical bodies, identical call sites). An unproved call pays one
  call/return on top of its checks. The LLVM backend now uses proofs too (it skipped the prover
  while the second entry was a prologue copy it could not lift).

- A call whose constant arguments break the callee's predicate (`split(v, 0, f)` with
  `grain: u64 where grain > 0`) is a compile error in every mode; it used to compile and fail at
  run time. Only constants, and names the facts equate with one, are judged false.

    atomic. Both are gate legs.
  - The aarch64 tests run under the repository's own qemu-aarch64: `tools/qemu/build.sh` builds
    QEMU 11.1.3 with `tools/qemu/stlr-rcsc.patch` into `.work/architectures/toolchain`. Stock
    11.1.3 on an x86 host lets a store-release pass a later load-acquire, which ARMv8 forbids;
    the store-buffering test saw up to 7,458 forbidden outcomes in 200,000 rounds there, and none
    under the patched build. The gate builds it and prints its version (`docs/testing.md`, "The
    aarch64 emulator").
- **`thread::scope`: threads that borrow.** `thread::scope(|t| { a := t.spawn(|| ..); ..; a.join() })`
  starts OS threads whose closures may borrow from the caller - shared or exclusive - because the
  scope waits for every one of them before it returns. The compiler refuses two threads taking one
  `&mut`, the body touching what a thread borrowed, and a handle leaving the scope. A failure in
  one thread lets its siblings finish and is re-raised when the scope ends.
- **A function may return a reference to an element of a slice it was given.**
  `fn first<a, K>(v: (&a [K])) -> (&a K) { return &v[0]; }` (and `&mut v[i]` from `(&a mut [K])`)
  was "returned borrow escapes its declared input lifetime": the element reference was a borrow of
  the slice variable. It is now a re-borrow through the slice's own loan, with the slice's region;
  the slice is suspended while an exclusive element reference lives.
- **`&v` of a vector is accepted where a typed slice `&[T]` is expected**, generic or not, and
  `&mut v` for `&mut [T]`: the slice over the whole vector, as `&v[:]` is. A generic `&[K]`
  parameter infers `K` from the vector's elements (it was `generic argument shape mismatch`; the
  non-generic call was a type mismatch).
- **A closure may take a reference where a type argument stands for one, and pass a captured
  reference on.** `lock.read_with(key, |v: (&u64[]), k: (&a u64)| -> bool ..)` was a type mismatch
  when the context parameter `C` was bound to a reference (a type argument carries no lifetime; a
  closure parameter has a fresh one); it is accepted, and a parameter type left to inference there
  asks for the annotation. A captured shared reference read as a value (`find(v, key)` inside a
  closure) is re-borrowed instead of moved out of the closure, which was "move of unavailable or
  borrowed value"; the borrow is kept as before.
 Unreleased- Fixed: a small leaf that takes the address of its own local (runtime.grl's `rt_frame`) was
- **An effect claim no longer makes a program one compiler run.** `@no_alloc` and `@no_panic` are
  proved per module against per-function *summaries*: every run that emits code records every body,
  and the facts it solves - whether a function can allocate, can fail, runs an entry check, and the
  call each fact came through - travel in a `facts` record of every interface (format 7; interfaces
  of format 6 are refused: re-emit them), in `runtime.facts` beside the interfaces for the runtime,
  and in function units, which are filed and replayed in claiming programs again. A claiming program
  builds through the module store like any other, and a refusal names the same chain across modules
  that the whole-program build names (`loud -> push_one -> grow -> rt_push -> rt_grow`).
  (`docs/design/effects.md`, *Summaries*.)
  - **What changes:** dropping a `dyn I` value of a **public** interface is refused under `@no_alloc`
    and `@no_panic` in every build shape ("the drop of a `dyn I` value, whose implementations this
    module cannot see"): an implementation in another module may be the one dropped. Claim the
    implementing types' `Drop` instead, or do the drop where `I` is private.
  - Methods in `impl` blocks take `@no_alloc` and `@no_panic`.
  - The standard library claims `@no_alloc` on `hash::write_byte`, `write_num` and `finish`,
    `u64[].sum` and `[u8].is_char_boundary`, and `@no_alloc @no_panic` on `strings::utf8_width`.
    Functions that return an option, a tuple or a record allocate it, so `find` and the parsers do
    not claim.
  - Fixed: a closure whose result type was inferred by a trial emission left that emission's calls
    in the effect record.  inlined with that local turned into a scratch register, so split and cached builds of programs
- `tools/land.sh BRANCH` (`just land`) lands a branch on main through one queue: the branch must already contain main, the fast gate runs on exactly its tree, and green fast-forwards main. Emulated targets run after the landing on the build host.
- Fixed: the native optimiser took an `f32` constant whose 64-bit immediate it cannot read (2.0 is
  `$4611686018427387904`, more than 18 digits) for zero, held the variable as binary32 and read 2.0
  back as 0.0. It changed Abundance's abgeo mesh digests (meshopt's `quadric_error_attr`);
  `f32-constant-wide-immediate-not-narrowed` pins it.

- Fixed: a small leaf that takes the address of its own local (runtime.grl's `rt_frame`) was
  inlined with that local turned into a scratch register, so split and cached builds of programs
  that reach it emitted `leaq %r8,%rax` and did not assemble. Such a leaf is no longer an inline
  candidate.

- **A failure allocates nothing, on every route.** A failed check inside a parallel job used to build
  its failure record and texts on the heap where it failed, so every `@no_alloc` function that
  could index, cast or unwrap was refused once the job-failure path existed. The failing stack now
  writes numbers only (kind, operands, the statement's site) into a record that is not heap
  memory. The joiner builds the message and the site text, on a healthy stack. A wake on that path
  no longer reaches scheduler creation.
- The book has a chapter, "Performance against other languages": charts of run time (release and
  development builds), compile speed and the scheduler against C, Rust, Go, Zig, rayon and oneTBB,
  with the numbers, the machine, the load, the commit and the commands under each, and the named
  reason wherever Grail is behind. It renders `bench/results/*.json` (inline SVG, offline; no
  benchmark runs when the book is built); the rivals tools write those files with `--json`, and
  `just bench-results` refreshes them, as the gate's last legs do.

- The rivals tools (`bench-rivals`, `sched-rivals`, `compile-rivals`) take `--compiler PATH` or
  `--branch REF` (REF's compiler built from a read-only `git archive` copy) and name the Grail commit
  they measured in every table. A toolchain that is not installed is skipped with a note. Each fails
  only when a program's output differs: compile-rivals now runs what it built and compares.

- `bun tools/compile-rivals.mjs`: compile speed against Go, Zig and rustc on the same programs
  (hello world and the scaling trio at N = 1000 and 4000): check and build, cold and after a
  one-function edit, CPU seconds by `getrusage`. The table and the reason for every miss are in
  `docs/design/compile-speed.md`, "Against Go, Zig and rustc".

- `bun tools/sched-rivals.mjs`: the scheduler (`bench/sched.grl`, `bench/frame.grl` from a
  scheduler tree) against Rust's rayon and C++'s oneTBB twins (`bench/rivals/sched-rayon`,
  `sched_tbb.cpp`): join, spawn, a burst of spawns, fib(32) by nested join and the frame loop's
  tail. The table and the reason for each miss are in `docs/design/runtime-parity.md`.

- Fixed: the native optimiser took an `f32` constant whose 64-bit immediate it cannot read (2.0 is
  `$4611686018427387904`, more than 18 digits) for zero, held the variable as binary32 and read 2.0
  back as 0.0. It changed Abundance's abgeo mesh digests (meshopt's `quadric_error_attr`);
  `f32-constant-wide-immediate-not-narrowed` pins it.

- Fixed: `bun tools/native.mjs build` rebuilt the compiler on every call. It assembled the bootstrap
  seed each time and keyed the compiler by the bootstrap's mtime, so the key never matched. The
  assembled seed is now kept under its digest and the key names the bootstrap's content; a second
  build with nothing changed takes milliseconds (`tools/test-cli.mjs` checks it).

- **A release build says what failed.** On the LLVM backend an inline check (overflow, a negative
  value to an unsigned type, division by zero, an unwrap, an assertion) used to end the program
  with status 134 and no message, because only the native backend's site table turned its `call
  rt_abort` into a report. The front end now writes `rt_trap` with the check's kind itself when
  there is no site table, and a failed index into a 4-byte vector reports its index and length
  like an 8-byte one. Locations (`--> file:line`) are still native-only.

- **One integer-overflow mode per build, decided by the root.** `--overflow=checked|wrap` on the
  command line wins; otherwise the root package's new `[package] overflow = "checked" | "wrap"`
  key; otherwise the build mode's default - checked, or wrap for `--release`. A dependency's own
  `overflow` key is not used, and the build prints one note naming it (Cargo's model for profiles):
  a library that needs modular arithmetic says so with `wrapping_add` and friends. An interface file
  still records the mode it was written under, but a build of the other mode no longer refuses it:
  the prover and the effect analysis do not depend on the mode, so the mode only chooses the code.

- **`grail build --release`** (and `grail run --release`, a project's `grail test --release`):
  every module is compiled by the LLVM backend and its LLVM module optimised by `clang -O2`, per
  module through the build store as before, and integer overflow wraps unless `--overflow=` says
  otherwise. A release unit is still one object: the assembled stream and the optimised module are
  folded together with `ld.lld -r`. Release builds are refused on macOS and Windows and with
  `--debug` or `--split`, rather than quietly built native. Runtime failures print their message
  without the `--> file:line` location in a release build (the location table is a native-backend
  artefact for now). The LLVM backend's `memcpy`/`memset`/`memmove` are weak, so several modules can
  each carry them, and so are the lifted bodies of `.weak` functions (generic specialisations,
  drop helpers), which every module that instantiates them defines.

- **LLVM backend: loops over slices vectorise.** A slice's descriptor (`&[T]`, `&mut [T]`) cannot
  change while the slice lives, so the front end says so (F1 kind 5) and the lifter reads its
  `data` (as a pointer) and `len` once per function; element addresses are `getelementptr`s on that
  pointer, which keeps their provenance. `x[i] = x[i] * a + y[i]` over one million elements goes
  from 7x to 1.2x (`f32`) and from 4x to 1.1x (`f64`) of vectorised `clang -O2`. Under
  `--verify-facts` every such access re-reads the header and aborts if it moved.

- Fixed: the native optimiser took an `f32` constant whose 64-bit immediate it cannot read (2.0 is
  `$4611686018427387904`, more than 18 digits) for zero, held the variable as binary32 and read 2.0
  back as 0.0. It changed Abundance's abgeo mesh digests (meshopt's `quadric_error_attr`);
  `f32-constant-wide-immediate-not-narrowed` pins it.

- Fixed: a small leaf that takes the address of its own local (runtime.grl's `rt_frame`) was
  inlined with that local turned into a scratch register, so split and cached builds of programs
  that reach it emitted `leaq %r8,%rax` and did not assemble. Such a leaf is no longer an inline
  candidate.

- **Fixed-size arrays, `[T; N]`** (docs/design/fixed-arrays.md, stage A1). N values back to back in
  C layout, held in the frame: no heap allocation, no header, the length a constant of the type.
  Literals `[a, b, c]` and `[x; N]` where an array is expected (count checked while compiling),
  indexing and element assignment, `&[T; N]` / `&mut [T; N]` parameters, `len()`, `for x in &a`,
  `==`, printing, `.copy()`. An index proved below N has no check; any other is one compare against
  the constant, with no length load - on LLVM that compare is folded wherever the loop bounds imply
  it, and element addresses keep the array's provenance, so elements stay in registers. Arrays of
  plain data up to four words copy; larger ones move. `bench/nbody.grl` is now the fixed-array twin
  of `bench/nbody.c`: LLVM backend at parity with clang -O2 (was 4.5x with vectors), native backend
  0.59 s against Zig Debug's 0.90 s and Go's 0.11 s.
- **Stack probes.** A function whose frame is larger than a page touches it a page at a time from
  the top before allocating it (x86-64, AArch64 and RISC-V; `probe-stack` on LLVM), so a large frame
  can no longer step over a stack's guard page: running out of stack is reported. A frame larger
  than the 1 MiB task stack is a compile error. On Windows the probe follows the frame line the
  unwinder describes and touches the frame from the top down, as `__chkstk` does.

- **A failure allocates nothing, on every route.** A failed check inside a parallel job used to build
  its failure record and texts on the heap where it failed, so every `@no_alloc` function that
  could index, cast or unwrap was refused once the job-failure path existed. The failing stack now
  writes numbers only (kind, operands, the statement's site) into a record that is not heap
  memory. The joiner builds the message and the site text, on a healthy stack. A wake on that path
  no longer reaches scheduler creation.

- Fixed: `bun tools/native.mjs build` rebuilt the compiler on every call. It assembled the bootstrap
  seed each time and keyed the compiler by the bootstrap's mtime, so the key never matched. The
  assembled seed is now kept under its digest and the key names the bootstrap's content; a second
  build with nothing changed takes milliseconds (`tools/test-cli.mjs` checks it).

- `bun tools/bench-rivals.mjs`: every `bench/` program against its C, Rust, Go and Zig twins
  (`bench/rivals/`), release and debug builds of each, CPU time from `getrusage`, one table with
  Grail's two builds as ratios to the best competitor of their bar. The numbers and the named
  reason for every miss are in `docs/design/runtime-parity.md`, "Against other languages".
  Every column targets baseline x86-64 (Zig gets `-mcpu=baseline`); a second table builds the
  rivals for the host CPU, and a third counts instructions. `bench/sieve`, `matmul` and `xform`
  (all twins) now make every round depend on the one before, so no compiler can drop a round:
  their printed results changed.

- **A foreign call costs what it costs in C (x86-64).** In a program that loaded libc, every
  `extern "C"` call switched the thread pointer to libc's TCB and back, and on x86-64 a write to the
  FS base is a system call (`arch_prctl`): two per call, about 660 ns for a call to `labs`. The
  thread pointer now stays libc's TCB for the life of the thread, and the runtime finds its own
  thread record through an initial-exec TLS word (`rt_tls_record`) - one fs-relative load, as
  before. Measured on 10M `labs` calls, best of five: about 3 ns a call against C's 2-3 ns
  (`bench/ffi_call.grl` and its C twin). AArch64 and RISC-V, whose thread-pointer write is a
  register move, and programs that never load libc keep the record as the thread pointer.

- **`sched::start(config)`** (`lib/sched.grl`) sets the scheduler up before anything starts it:
  `workers`, `background_cap`, `idle_spin_us`, `pin_workers` (Linux), `warm_stacks` (task stacks
  mapped up front, so a frame never maps one) and `seed` (a reproducible steal order). It returns
  false - it never aborts - when the scheduler already started or settings were already applied.
  `GRAIL_WORKERS` still wins over `workers`.

- **Priority classes for parallel work.** `pool::with_class(pool::Class::Frame | Normal | Background,
  f)` runs `f` with every job it forks - and every job those fork - in that class. Workers take
  Frame work before Normal work, Normal before tasks, and tasks before Background work. At most a
  quarter of the workers (at least one) take Background jobs at once, so an asset import cannot
  occupy the machine when a frame's jobs arrive. Nothing is preempted. `host::background_wait_us()`
  (and the `GRAIL_SCHED_STATS=1` line) reports how long the oldest queued Background job has
  waited, so starvation is visible. Every 61st scheduling step looks at the injected tasks first.

- **Parallel splits are by grain, and never depend on the machine.** `pool::split_mut(data, grain, f)`
  replaces `pool::chunks_mut(data, count, f)`, and `pool::split(data, grain, f)` replaces
  `pool::for_chunks(data, count, f)`: each job gets a piece of at most `grain` elements. The builtin
  is `parallel_split(data, grain, f)` (it was `parallel_for_chunks` with a count). The old names are
  gone, with no alias; every caller in the repository moved. `grain` is `u64 where grain > 0`.
  `parallel_map` (and so `pool::map` and `pool::run`) splits into at most 256 leaves fixed by the
  length, where it used to make four per worker. New: `pool::range(n, grain, f)` calls `f(lo, hi)`
  per piece of `0..n`, and `pool::reduce(n, grain, zero, leaf, merge)` folds the pieces' results
  in index order. A floating-point reduction therefore prints the same bits with 1, 4 or 24
  workers (`pool-reduce-bit-identical-workers-*`).

  Every column targets baseline x86-64 (Zig gets `-mcpu=baseline`); a second table builds the
  rivals for the host CPU, and a third counts instructions. `bench/sieve`, `matmul` and `xform`
  (all twins) now make every round depend on the one before, so no compiler can drop a round:
  their printed results changed.

- A method of a generic written-type impl whose bound the receiver does not meet says so: `v.sort()`
  on a `Point[]` is "`sort` needs `T: order::Ord`, and `Point` does not implement it", with a help
  line naming the impl (`impl<T: order::Ord> T[]`, module `vecs`), where it was "`Point[]` has no
  method `sort`".

- Fixed: a `&mut self` method of a written-type impl (`v[i].deps.insert_sorted(x)`, from
  `impl<T: order::Ord> T[]`) called on a field of a vector element was refused as "mutation through
  readonly frame": the check that borrows an indexed element mutably looked only at methods of the
  element's own struct, never at the type the field path reaches or at written-type impls.

- Removed: `iter::from_step`, an exact copy of `iter::from_fn`. Write `iter::from_fn(step)`.

- Removed: **the free-function forms of the `strings`, `vecs` and `iter` methods.** Each was one line
  calling the method; call the method instead. `lib/strings.grl`: `strings::starts_with`,
  `ends_with`, `split`, `trim`, `to_upper`, `to_lower`, `replace`, `repeat`, `contains`, `find`,
  `parse_u64`, `parse_i64`, `is_utf8`, `utf8_error`, `char_count`, `is_char_boundary`,
  `slice_chars`, `char_indices`, `to_text_lossy` (`strings::find(t, x)` is `t.find(x)`),
  `join_with(&parts, sep)` (`parts.join_with(sep)`), `push_char(&mut out, c)` (`out.push_char(c)`)
  and `parse_num(t)` (`t.parse_u64()`). `lib/vecs.grl`: `vecs::map`, `fold`, `sum`
  (`vecs::map(v, f)` is `v.map(f)`), `filter_nums(v, f)` (`v.filter(f)`), `reverse`, `sort`,
  `is_sorted`, `sort_by`, `sort_by_key`, `binary_search`, `insert_sorted` (`vecs::sort_by(&mut v, f)`
  is `v.sort_by(f)`), `sort_nums(&mut v)` (`v.sort()`), and `min_index(&v)`/`max_index(&v)`, which
  stopped the program on an empty vector (`v.min_index()!`; the method returns `u64?`).
  `lib/iter.grl`: `iter::map`, `filter`, `take`, `enumerate`, `zip` and `collect`
  (`iter::collect(iter::map(it, f))` is `it.map(f).collect()`). Two free functions stay because
  they are not the method of the same name: `strings::chars(t)` is a lazy `iter::Iter<char>`
  (`t.chars()` is every code point at once, a `char[]`), and `vecs::contains(&v, &x)` takes any
  `hash::Equal` element (the built-in `v.contains(x)` takes integer and bool elements only).
- Fixed: **a chain of more than eight compile-time values hung the build.** The compile that hit
  the nesting limit re-ran itself to report its next error, up to 20 times, and inside a probe each
  re-run repeated every probe beneath it, so the failure multiplied through the chain (12 values
  had not finished after four minutes). A probe now stops at its first error; the same program
  fails in half a second.

- **The refinement prover knows statics and constants** (module-values stage 5): an integer static
  or constant is its value (`small(LIMIT)` with `x < 10` and `LIMIT = 8` calls the proved entry),
  and a baked string's or table's `.len()` is its length (`get(SQ, 3)` on an 8-element static is
  proved), at the caller and at the callee's renamed obligation alike. A local that shadows the
  name hides it; a value that breaks the bound proves nothing and the check stays.

- **Baked statics hold records** (module-values stage 4): `static FLAGS: Flag[] = @flags();` and
  `static BOX: Box = @make_box();` for plain records whose fields are integers, bools, strings,
  vectors or such records again, at any depth. The run tier prints the value field by field and
  the compiler lays it out as read-only objects (one word per field), so a read borrows it. A record
  holding a thread-affine handle is refused as not shareable; a `NAME := f();` binding that computes
  a record says to make it a static; enums and generic records are refused as not built yet.

- Fixed (test harness): **`test-native --jobs N` made every stripe build a second compiler** - the
  parent passed its compiler as `GRAIL_COMPILER`, which `buildCompiler()` reads as the base to build
  from - all into one directory at once, and each finished build was renamed over the binary the
  other stripes were running, so a compile-time probe found its compiler "(deleted)". Stripes now run
  the parent's compiler (`GRAIL_TEST_COMPILER`), and a finished build is put in place by a hard link
  that never replaces an existing one.

- Fixed: **a compile-time call with a signed result came back wrong.** A vector of signed integers
  with a negative element stopped the probe (it printed each element through a checked `u64(..)`),
  a negative scalar was read back as digits only, and every integer result was typed `u64`. Signed
  elements are now printed as `i64`, a leading `-` is read, and the result keeps its own integer
  type - in a `const`, a `NAME := f();` binding, a baked `static` and an `@f()` expression.

- Fixed: **`@no_alloc` refused every function with a check that can fail** - an index, an overflow,
  a division, a narrowing, an unwrap, a refined parameter - because the failure report allocated:
  its texts were heap strings (`rt_new`, `rt_reserveb`, `rt_alloc`, and the runtime's literals are
  heap values), and it reached the compiler's site-table helper through an unnamed indirect call.
  The dying report is now written in a report block mapped on first use,
  its literals are static views, and the helper call is a named edge. The checks still fail, so
  `@no_panic` still refuses them.

- **Module statics, baked tier** (docs/design/module-values.md, stage 1): `static NAME: T = init;`
  where `init` is a constant expression or `@f(...)` computed while compiling. A static is one
  read-only object in the declaring module's object: a number or `bool` read is a load, any other
  read is a borrow (`TABLE[i]`, `TABLE.len()`, a `&u64[]` argument) that never copies or allocates,
  so `@no_alloc` code may read it - unlike a `const` table or string, which is rebuilt at every read.
  Types: integers, `bool`, `string`, vectors of integers and bytes. Refused with a reason: `static
  mut`, a missing type, assignment or mutation, a borrow or a non-shareable type, a generic or
  function-local static, a plain call (the lazy tier, not built yet), and an `@` initialiser that
  cannot run at compile time. `pub static` crosses modules through the interface file.

- Fixed: a module binding whose compile-time call was refused (`LOCK := make();` returning a
  `Mutex`) was reported at the end of whichever file the compiler had parsed last - often
  `lib/result.grl:129` - when nothing read it. The diagnostic now points at the binding.

- **`lib/sync.grl`: `RwLock`, `Condition`, `Once`, `Latch`, `Barrier`, `Semaphore`.** All park
  instead of spinning, and every wait has an `_until(deadline)` form answering
  `time::WaitError::{Cancelled, TimedOut}`. A task waiting in a long wait - a condition, a latch, a
  barrier, a semaphore, another caller's `Once` initialiser, `time::sleep_ms` - now wakes when its
  scope is cancelled and ends as a `Cancelled` failure (`try_join` reports kind 16; `join`
  re-raises; the cancelled scope itself does not); `time::try_sleep_ms` answers instead. Lock
  waits are not cancellable; `sync::lock_until`, `read_until` and `write_until` are. A writer that
  fails poisons an `RwLock`, permits come back from a failed holder, and a failed `Once`
  initialiser lets the next caller try. `docs/design/parking.md`.
- `thread::spawn` states what it needs: `f: FnMut<Send, Owned>((&Ctx)) -> R` with `R: Send + Owned`,
  so a closure that captures a borrow or a thread-affine value is refused at the call.

- **A `Mutex` wait costs nothing, and a failed holder poisons it instead of hanging everyone.**
  A task or thread waiting for a lock now parks - eight tasks waiting through a 300 ms hold used a
  processor each, and now use under 100 ms of CPU together. When a task or a spawned thread fails
  inside `lock_with`, the lock is released and the mutex is poisoned: the next `lock_with` fails with
  `mutex poisoned: its holder failed at FILE:LINE:COL` (the next locker used to wait for ever).
  `sync::recover_with(&m, ctx, f)` gets in anyway and clears the poison; `sync::try_lock_with` and
  `sync::is_poisoned` are new. `thread::join` from a task parks instead of starting a helper thread.
  `docs/design/parking.md`, `bench/mutex.grl`.

- **One set of worker threads: jobs run on the scheduler.** `parallel_map`,
  `parallel_for_chunks`, `pool::join` and job handles used to run on a pool of threads separate
  from the scheduler that runs tasks, so a program that used both had two threads per CPU (50 on a
  24-CPU machine, now 26), and a task that waited for a job put its scheduler thread to sleep: with
  every worker's task waiting on a 300 ms job, a 10 ms timer task stalled for 300 ms (now 11 ms).
  Jobs are now records the scheduler's own workers claim; a waiting thread runs its own forks and
  helps with others; a job that sleeps or reads parks like a task instead of holding a thread; and
  a job that overflows its stack reports `error: stack overflow` and exits 134 instead of dying by
  SIGSEGV.
  - **`pool::join` was not parallel.** It ran `first` through a blocking one-element
    `parallel_map` and only then called `second`, paying several allocations each time, so a
    recursive join was a slow sequential program: `fib(32)` by nested joins took 288 ms against
    9 ms serial. It now forks `first`, runs `second`, and takes `first` back if no worker did: in
    one loaded run on 24 CPUs the same recursion took 9.8 ms where the serial form took 18 ms and
    the old join 370 ms. One join costs about 3 us instead of 9-11.
  - `GRAIL_WORKERS=n` (1 to 64) sets the worker count. `GRAIL_POOL_WORKERS` is gone with the pool
    it sized, and there is no floor of four any more: the default is one worker per CPU with the
    scheduler's floor of two.
  - `pool::wait(pool::spawn(f))` from a thread that waits at once may now run `f` on that thread.
  - `GRAIL_SCHED_STATS=1` prints the worker count and the deepest nesting of helped jobs at exit.
  - **A failure inside a parallel call is contained.** A failed check in a job no longer ends the
    process: the jobs it forked finish, the failure is raised again at the join, and a task that
    made the call fails as tasks already do - `try_join` returns the check's message, the
    statement that failed and a line naming the join. From `main` the program ends as before, now
    with that same report. A stack overflow is still fatal. Until locks are tracked per task, a
    job that fails inside `lock_with` while a sibling waits for that lock waits forever. A thread waiting in a join helps only with work forked by the job
    it waits for, and not at all with less than an eighth of its stack left, so helping never
    stacks more on a stack than the sequential program would.
  `docs/design/scheduler.md` ("Jobs") is the mechanism; `lib/pool.grl`'s signatures are unchanged.
- `host::now_us()`: the monotonic clock in microseconds, beside `host::now_ms()`. A frame time or
  the cost of a join is not measurable in whole milliseconds; `bench/frame.grl` and
  `bench/sched.grl` (run by `bun tools/bench-sched.mjs`) are the scheduler benchmarks that use it.
- **Threads of your own: `thread::spawn`.** `lib/thread.grl` starts an OS thread that runs one
  closure: `spawn(config, f)`, `join`, `try_join`, `detach`, `with_current`, `sleep_until`, and
  `thread::Local<T>` read through a `thread::Ctx` that cannot leave its thread. A handle that is
  dropped joins. `Config` asks for a name, a stack size, a processor set and a priority; a refusal
  by the OS is an error value from `spawn` and the closure does not run. A failed check on a
  spawned thread is contained like a task's - a `TaskFailure` at `try_join`, re-raised by `join` -
  and running off its stack is the named `stack overflow`. **What a thread is not:** it is not a
  scheduler worker; nothing is stolen onto it; a wait blocks it in the kernel. Linux and Windows;
  on macOS `spawn` returns `Unsupported`. Not checked yet: a `spawn` closure that captures a borrow
  or a thread-affine value is accepted until bounds on closure types land.
  `docs/design/threads.md`, the book's concurrency chapter.
- Fixed: an `extern "C"` call with no arguments that was the first thing in its function left the
  thread pointer on libc's side in a libc-linked program, so later runtime calls on that thread
  (starting a thread, for one) read the wrong record.

- **A buffer of 512 bytes or more starts on a 64-byte boundary.** Every allocation of that size -
  a vector's storage, a byte buffer, a record that large - is cache-line aligned, on every path and
  every thread; smaller ones stay 16-byte aligned. It costs 32 bytes per megabyte arena and nothing
  per allocation, and it is a promise from now on (`docs/design/allocator.md`).

- **Threads no longer queue for the allocator.** Once a program has a second thread, every OS
  thread allocates from and frees into a cache of its own for blocks up to 256 KiB, with no lock
  and no atomic operation; the lock is taken only to move a batch of blocks between a cache and
  the shared lists. Pool workers that allocate and free small vectors and records went from 10.5
  million pairs a second with one worker and 0.5 with 24 (slower with every worker added) to 12.7
  and 126 on a 12-core machine. A block may be freed on any thread, a thread that ends gives its
  cache back, and the end-of-main leak check still counts exactly. A one-thread program runs the
  code it always ran. macOS, which has no threads in this runtime, is unchanged.
  `docs/design/allocator.md`; `bench/alloc_threads.grl`, `bench/alloc_handoff.grl`.
- Fixed: an effect attribute's name anywhere in a source file - a comment, a string - made the build
  one compiler run over the whole program, because the driver searched the bytes. It now looks for
  the attribute itself (`@no_alloc`, `@no_panic` outside comments and strings).
- **Native backend: float temporaries live in SSE registers.** The optimiser keeps a frame slot
  that only ever holds a float in one of xmm8..xmm14, slots whose lives do not overlap sharing a
  register, as long as the slot is not live across a call that returns (every SSE register is
  caller-saved). It also knows the SSE instructions the front end writes (`addsd`, `cvtss2sd`,
  `ucomisd`, ...) touch no general register; before, each was an unknown instruction across which
  nothing could be removed. And a compare-and-branch now fuses even when the loop's exit runs
  through several drop-flag tests. On x86-64, CPU time: nbody 1.42 s -> 1.16 s, xform_f32 1.08 ->
  0.80, dot_f64 0.72 -> 0.62. A loop's slots now outweigh straight-line ones 16 to 1 (was 4), so a
  loop bound gets a register before a drop flag does.
- **Native backend: `f32` arithmetic in single precision.** A promoted `f32` local whose every
  value comes from a widening (or is zero) is held as binary32, and an operation on two such values
  that is rounded to `f32` at once (`addsd; cvtsd2ss; cvtss2sd`) is the single-precision one
  (`addss`): exact for + - * / and sqrt, since 53 >= 2*24 + 2. Loads that feed anything else are
  widened in place of the copy. `f32-held-as-binary32-in-registers` pins the results.
- The float arithmetic is SSE text on AArch64 and RISC-V too, translated by machine.grl (xmm0/1 to
  d0/d1 and ft0/ft1, xmm8..xmm14 to v17..v23 and ft2..ft8, all caller-saved), so floats are kept in
  registers there as on x86-64; compares and integer conversions stay `fop`. And a call to a
  runtime exit or a drop helper reads only the argument registers it takes, so a value left in
  %rcx before one is no longer kept alive for it.

- **Records of plain data are stored inline.** A struct or tuple with no `Drop` whose fields are
  numbers, bools, chars, references or other such records is now stored in place where it is a
  field of another record or an element of a vector, and so is every `extern "C"` record in a
  vector: `Vertex[]` is one buffer of vertices, laid out as a C array, not a vector of pointers.
  One million three-word records take 24 MB instead of 69 MB, and iterating them in a shuffled
  order costs what iterating them in order does. What a program may write and what it means do not
  change - a plain record still moves, and `q := v[i]` still borrows. Interface files say
  `record plain = inline`. Second stage of docs/design/unboxed-values.md.

- **A reference to a record is the record's address.** `&T` and `&mut T` for a struct, a tuple or
  an `extern "C"` record used to be the address of a word holding the record's address; a field
  read through a reference now costs one load, not two, and a local record whose reference is
  passed no longer has to live in memory. Nothing a safe program can observe changes: assignment
  and `exchange` through such a reference replace the record's contents, and a reference to an
  enum, a vector, a string or a number is what it was. Interface files state it (`ref record =
  address` on the `abi` line), so an object built by an earlier compiler is refused instead of
  linked. First stage of docs/design/unboxed-values.md.
- **`--debug` builds write vector element access in line.** The leaf accessors (`rt_slot`, `rt_at`,
  `rt_slot4`, `rt_at4`, `rt_len`, `rt_push`, ...) were expanded only by the optimiser, so a debug
  build called them for every element; the expansion is lowering and now runs without the
  optimiser too (`optimize::lower_leaf_calls`). A failed index check in a debug build reports
  through `rt_trap`, so a task still contains it. The `f32` transform benchmark in a debug build
  goes from 57 ms to 6.3 ms a pass. 16-bit loads and stores are in line on aarch64 and riscv64 too.

- **Native backend: float operations are not calls.** `+ - * /`, comparisons, negation, `abs`,
  `sqrt` and conversions from integers of up to 32 bits (and signed 64-bit to `f64`) are emitted in
  line, and so is access to `f32[]`/`u32[]`/`i32[]` elements and to narrow fields of `extern "C"`
  records (one emitter, `sized_load`/`sized_store`). The LLVM backend keeps the called forms its
  lifter rewrites. One million `x[i] = x[i] * a + y[i]` over `f32[]` goes from 7.6 ms to about 4 ms
  a pass. `float-operations-agree-across-backends` pins every operation over edge values. The LLVM
  lifter also treats `rt_refine`, `rt_task_fail` and the other runtime exits as non-returning.
- `bench/` has `xform_f32`, `xform_f64`, `dot_f32` and `dot_f64`, with a README.

- **LLVM backend: a failed check no longer costs the loop it guards.** `rt_fail` and `rt_trap` never
  return, and the lifter now says so (`unreachable` after the call), as it already did for
  `rt_abort`. A checked access to an 8-byte element (`f64[]`, `u64[]`) used to leave a returning call
  in the loop body, which clobbered every register the loop held. A one-million-element `x[i] =
  x[i] * a + y[i]` pass over `f64[]` goes from about 1.3 ms to 0.64 ms, and the `f64` dot product
  from 2.0 ms to 0.62 ms (scalar C: 0.65 ms).

- **`f32` arithmetic on the native backend rounds in hardware.** Every `f32` result used to be
  rounded by a runtime routine written with integer shifts and a division; it is now one narrowing
  and one widening conversion on x86-64, aarch64 and riscv64. A one-million-element `x[i] = x[i] * a
  + y[i]` pass over `f32[]` goes from 259 ms to 7.6 ms. Non-NaN results are bit-identical to before
  (`f32-round-hardware-matches-reference` checks four million words on every target); a result that
  is a NaN is a quiet NaN and its payload bits are not promised.

- The LLVM backend builds programs for AArch64 and RISC-V again. A lifted function the stream
  declares `.weak` (a generic instance, a drop helper) got a `.globl` entry thunk, which the
  assembler rejects (`changed binding to STB_GLOBAL`); the thunk now keeps the weak binding. And
  an AArch64 module is compiled with atomics inline (`-mno-outline-atomics`): clang's default
  calls `__aarch64_cas8_acq_rel` in libgcc, which a Grail program does not link.
- `grail profile --callers` samples each tick's return addresses too (the runtime walks the frame
  pointers) and adds two views to the report: inclusive samples per function, and for the ten
  hottest functions who called them and the first caller outside the runtime - so a profile topped
  by `rt_alloc_unlocked` says which code allocates. Without the flag nothing changes: the request,
  the sample format and the signal handler's path are the ones before.

- A function taking an `extern "C"` record `byval` no longer breaks an interface or the build store:
  the interface writer took the record's type for its declaration (an index out of bounds while
  spelling it), and the reader rebuilt the marker over a declaration where the parser puts the
  record's type.

- **A module's function bodies are compiled in parallel.** After the declarations, forked copies of
  the compiler compile slices of the bodies into units and the compile applies them in source
  order, so the output is byte-identical at any worker count (`GRAIL_JOBS=1` keeps one process). The
  compiler compiling itself goes from 38.7 s in one process to 18.3 s; a 1000-function program from
  4.2 s to 2.1 s. A body with an error is reported exactly as before: any worker that does not
  finish sends the module back to one process. The first body of each module is now a cache unit
  too. `grail check` is parallel the same way (the compiler's own sources: 13.6 s to 6.0 s).

- **One jobserver per build.** `grail build` runs at most `GRAIL_JOBS` (default: the processor count)
  compiler processes at once across everything it starts - module runs and their optimiser workers
  share one GNU-make-style token fifo - where each module run used to fork up to the processor count
  on its own. Under `make -j`, a build takes its tokens from make's jobserver
  (`MAKEFLAGS=--jobserver-auth=fifo:PATH`). On the 24-module benchmark with `GRAIL_JOBS=4` the build
  peaks at 9 processes instead of 49.

- Integer conversions (`u8(x)`, `i32(y)`, `wrapping_u16(z)`, ...) are emitted in line by the native
  backend: a widening costs nothing, a wrapping conversion is a shift pair, and a checked narrowing
  is a compare and a branch that calls the runtime only to report a value that does not fit (the
  report is unchanged). They were a runtime call each, 8 % of the compiler's own run time.

- **An edit to one function recompiles that function.** The per-function layer of the build store
  now replays every other body of the module: a body's assembly no longer depends on the bodies
  before it (labels are numbered per function, `.L<unit>_<function>_<n>`, and its positions count
  from its own first line), and a stored body records the drop helpers it names and the
  specialisations it asks for, so a replayed body asks the build for them again. Before, a body
  that named a drop helper or instantiated a generic was never stored, and one that used a
  specialisation an earlier body had asked for could be replayed into a build that no longer
  emitted it (an undefined symbol at link time). On a 1000-record module an edit to one function
  replays the other 1999 bodies where it replayed none. Bodies that create a closure, use a vtable
  or the fn thunk, add a link input or a constant, synthesise a declaration (the first tuple of a
  size, the first result union) or spell a source position as text are compiled every time, as is
  the first body of each module; the build's `fn-cache:` line says how many bodies each rule kept
  out. A program with a compile-time constant no longer stops a build through the store with
  `internal: no type where one is required`.

- A build emits a drop helper for each type whose helper something names, in the order they are
  first named, instead of one for every type the compiler interned: the helpers nothing called are
  gone from the assembly, and the set no longer depends on which bodies the compiler had to check.
- Fixed: **a module's compiler run read every interface that happened to be in the build
  directory.** With modules compiling at the same time that was a race - a run could list and open
  an interface another run was still writing - and it made what a run read depend on timing and on
  the file system's listing order. The build now names the modules a run reads (the ones it uses,
  and theirs: `--use-named`, `--use-module NAME`) and the run reads those, in that order, and
  nothing else; without the flags a directory is read in name order.

- **A closure inside a closure may capture what the outer one captured.** A captured shared
  reference is re-borrowed, and a captured `&mut` vector or slice is re-borrowed as an exclusive
  slice, keeping the original borrow - the shape every scoped spawn has
  (`scope(|t| t.spawn(|| use(rx)))`). It was an `undefined name` error. An expression-bodied closure
  without a result type may now capture a local borrow (it was "parameter requires a declared
  lifetime").
- **`Fn<s>(..)`: a closure type may name the lifetime its borrows come from**, so a record labelled
  `s` can keep closures that borrow (`struct Holder<s> { items: (Fn<s>() -> u64)[] }`) and keeps
  their loans alive while it lives. A record whose closure field states no bound (`iter::Iter<T>`)
  is no longer accepted for `T: Owned`; its hidden borrows stay local.
- **Soundness: a closure parameter borrows for the call.** A parameter typed `Fn(..)`/`FnMut(..)`
  (without `Owned`) may be called and passed on during the call, and nothing more: returning it,
  storing it (a push through `&mut`, a field), or capturing it in a closure that is returned is
  refused. Before, a callee could keep a closure that borrowed the caller's frame and call it after
  the frame was gone (a use after free in safe code). A record holding a borrowing closure can no
  longer be boxed as `dyn`, and a job spawned from a call-scoped closure keeps its loans, so a
  wrapper must wait on it before returning. **What stops compiling, and the fix:** a function that
  keeps a closure it was given must say so - `f: Fn<Owned>(..)` (it then borrows only what its type
  names); its callers move values in instead of borrowing them, or name the borrow in the closure's
  result type. The lazy `iter` adapters (`map`, `filter`, `flat_map`, `filter_map`, `from_fn`,
  `from_step`) now take `FnMut<Owned>(..)`; no program in the corpus, Abundance or Borg needed a
  change. (`docs/design/closure-bounds.md`, stage 3.)
- **Closure types state what the closure may capture: `Fn<Send>`, `Fn<Share>`, `Fn<Owned>`.**
  A closure parameter, field or element can now say its captures may move to another thread
  (`Send`), be used from several at once (`Share`, `Fn` only), or hold no borrow (`Owned`), and
  `Owned` is a new bound on type parameters (`R: Send + Owned`). `lib/pool.grl` states them:
  `pool::map`/`run`/`for_chunks`/`chunks_mut` take `Fn<Share>(..)`, `pool::spawn` takes
  `FnMut<Send, Owned>() -> R`, `pool::join`'s first branch is `Fn<Send>() -> A`. This closes three
  soundness holes in safe code: a wrapper over the parallel builtins let a thread-affine handle, or a
  shared `&mut`, reach a worker, and a record with an `Fn` field carried a handle capture into
  `parallel_map`. (`docs/design/closure-bounds.md`; interface format 6.)
  **What stops compiling, and the fix:**
  - A bare `Fn(..)` is no longer `Send` or `Share`. A record with an `Fn(..)` field sent to a worker,
    a `Fn(..)` passed to a `T: Send` generic, or a `Fn(..)` parameter forwarded to `parallel_spawn`,
    `parallel_map` or a `pool` function is refused with "does not say what it captured". Write the
    bound where the type is written: `Fn<Send>(..)` (one worker) or `Fn<Share>(..)` (several).
  - `pool::spawn` refuses a closure that captured a borrow where the closure is written, and every
    `pool` callback refuses an `FnMut` one: move the value in, or return an owned result.
  - Interfaces written by an older compiler are refused: re-emit them with
    `grail check --interface DIR`.
- **Soundness: a job handle keeps what its closure borrowed.** A closure that borrowed a value,
  passed through a wrapper such as `pool::spawn`, left a `Job<R>` that the checker believed held
  no borrow, so the borrowed value could be moved or dropped while the job was still reading it
  (a use after free in safe code). The handle now holds the loan until it is waited on or dropped.
  A program that moved the borrowed value while the job was live is refused with
  `move of unavailable or borrowed value`: wait on the job first, or move the value into the
  closure instead of borrowing it. (`docs/design/closure-bounds.md`, Q3.)
- **Fixed: memory corruption after a proved call to a refined function.** The `.proved` entry
  that let a proved call skip the parameter checks was a byte copy of the prologue taken before the
  optimiser rewrote it: it did not save the callee-saved registers the epilogue restores, so the
  caller's registers came back as garbage (seen as a double free of a vector the caller had moved
  into the call, exit 134 at the next allocation). The entry is gone: a proved call is a plain call
  and the entry checks run, true by the proof; `@no_panic` still counts it as unable to fail. Every
  refined function whose body used a callee-saved register was exposed, since the second entry was
  introduced.

- **Field predicates are sound.** A field predicate may name only its own field, on an integer,
  a float or an owned vector's `len()`; anything else is refused at the struct. It used to be read
  in the scope of whoever built the record, so a predicate naming another field was an undefined
  name or - with a local of that name - a proof about the wrong value, and `@strict` accepted
  records that broke their own predicates. Every store into a refined field now owes the
  predicate: `r.f op= v` (it skipped the check), a nested path `o.inner.n = v` (it looked in the
  wrong record) and a closure's write. A mutable borrow of a refined field is refused - `&mut r.f`,
  `exchange(&mut r.f, ..)`, `r.items.push(..)` and the other mutating methods, a `for` over
  `&mut r.items`, a record pattern through `&mut` - because a write through it would skip the
  check. In return a record read through a shared reference or a non-`mut` binding gives its field
  predicates as facts: `need(r.n)` is proved from `n: u64 where n > 5`. No existing code in the
  repository uses a cross-field predicate; the book's `Ray` example is unchanged.

- **A refinement proof no longer depends on the overflow mode.** `--overflow=checked` and
  `--overflow=wrap` now accept exactly the same programs under `@strict` and under `@no_panic`
  (`bun tools/overflow-parity-test.mjs` checks it over the corpus, in the gate). A constant in a
  condition, a predicate or an argument (`i + 1`, `v.len() - 1`) is integer arithmetic where the
  facts show it cannot wrap - `i - 1` under `i > 0`, `i + 1` under `i < n` - and otherwise one
  opaque value that proves an obligation naming the same expression and nothing else. What changes
  for existing code:
  - a wrap build now proves what a checked build did where the proof never needed the trap
    (`while i + 1 < v.len() { get(&v, i + 1); }`);
  - a checked build no longer proves from "the overflow would have trapped": `get(&v, i - 1)` under
    `i < v.len()` alone, `i < n` from `i + 1 < n + 1`, and any offset on a sized integer keep their
    checks (and are refused under `@strict`) in both modes;
  - `@no_panic` treats `+`, `-`, `*`, `**`, a shift and sized arithmetic as possible failures in a
    wrap build too, unless the facts prove the operation cannot overflow; `i + 1` with `i < n` is
    now such a proof, beside `hi - lo` with `lo <= hi`, and a proved addition has no overflow
    check in a checked build;
  - `@bounded` no longer reads a bound from a predicate whose bounded side has a constant
    (`where n + 1 < 100`): that bounds the wrapped sum, not `n`.
  Every sum of offsets in the prover is exact or abandoned (limit 2^60), so a chain of large
  constants cannot overflow into a wrong proof.
  Fixed on the way: a call in a `while` guard was proved from facts that the loop's body ends, so
  `@strict` accepted a guard that indexed out of bounds on its second evaluation.

- **Builds are 25x to 180x faster than they were a day ago.** With the release compiler: the
  compiler compiles itself in 2.9 s (was 73.8 s), a 104k-line program checks in 0.9 s (was 166 s),
  hello world checks in 0.04 s (was 1.1 s), and 90k lines in 24 modules build cold in 1.4 s.
  Time is linear in program size. What changed:
  - `bun tools/native.mjs release` builds the compiler through the LLVM backend (`clang -O2`) and
    accepts it only if it emits, for the compiler's own sources, exactly what the natively built
    compiler emits. `compile-bench --release` measures it.
  - `grail check` stops when its last diagnostic can have been given: no optimiser, nothing written.
  - A view of a whole vector is the vector's header, not a record (7 in 10 allocations).
  - The borrow checker walks storage trees, live loans and a loan's bonds instead of every place,
    loan and bond the function has made; types are interned by hash; the lifetimes a type carries
    are remembered per type.
  - The optimiser runs in forked workers, one piece of the stream per processor, with output that
    does not depend on the number of workers (`GRAIL_JOBS=1` for one process).
  - Modules compile at the same time, each started when the modules it reads are finished.
  - With a build store, an optimised function body is remembered and not optimised again.
  - Tokens carry their line and column: a `--debug` build no longer rescans the source per
    statement (11.3 s to 2.2 s on 26k lines).
  New in the language and library on the way: `u8[].append(bytes)`; `host::fork()` and
  `host::cpus()` (Linux). `docs/design/compile-speed.md` has every measurement.

- **The native backend's optimiser follows jumps again.** Since 2026-11-13 it read no label a real
  build mints: `label_number` compared the whole label with the unit prefix instead of its opening,
  so every `.L<prefix>_<n>` was unnumbered, and a jump's operand was still read in the old
  `.L<digits>` spelling. Nothing failed - every pass that follows a jump (liveness across a branch,
  dead code after a jump, the peephole, register promotion's loop weights) took its most
  conservative answer. Labels and jump operands now go through one reader (`ir::numbered`), which
  reads `.L<prefix>_<n>` and the per-function `.L<prefix>_<f>_<n>`. `GRAIL_OPT_STATS=1` writes
  `# grail-jumps <known> <unknown>` before each optimised body, and
  `tools/test-optimiser-jumps.mjs` holds the compiler's own sources to 99% known (674285 of
  674319 today; the rest are a hand-written body the optimiser leaves alone and two indirect jumps).
  The compiler's self-compile assembly is 0.5% smaller (111.9 MB from 112.5 MB) and the compiler
  compiles itself 2% faster (16.5 s from 16.9 s); `bench/` programs use 9-14% less CPU time.

- `hash::write_byte` states its precondition in its signature (`value: u64 where value < 256`)
  instead of asserting it in its body: a caller that can show the value is a byte pays no check,
  and one that cannot gets the check at its own call, named. It was the standard library's only
  asserted precondition - the rest of `lib/` answers an out-of-range request with an option or a
  defined result rather than requiring one.

- **`grail build` reuses what it built before, by default.** A build goes through the build store
  without `--cache`: one compiler run and one object per module, reused when nothing they depend
  on moved. Hello world rebuilds in 0.15 s after an edit instead of 0.72 s, and in 0.07 s when
  nothing changed. The store is now per user (`GRAIL_CACHE_DIR`, else `$XDG_CACHE_HOME/grail/build`,
  else `~/.cache/grail/build`) rather than per project, so the runtime and standard-library objects
  are built once per machine and a new project's first build links them (0.15 s). `--no-cache` is
  the whole-program build; `--debug`, `--split`, `--whole-program`, `--interface`, `--emit-ir` and
  `--watch` builds are unchanged. A program built through the store runs as fast as one built
  whole (measured on `bench/`). `grail cache clear` and `grail cache prune` act on the per-user
  store.

- **Methods on written types, and the standard library as methods** (the postfix work): `impl<T> T[]
  { .. }` and `impl u8[] { .. }` declare methods on a type no module declares, `&self` / `&mut
  self` are the receiver shorthand, and `vecs`, the text helpers and the iterator adapters are
  methods (`v.map(..)`, `it.filter(..).collect()`). A written type's methods travel in its
  module's interface file (format 5, record `inherent_type`), so they work across separately
  compiled modules.

- **`pop()` returns an option.** `v.pop()` on a vector or a byte vector is `T?`: `Some(element)`, or
  `None` when there is nothing to take, so `while let Some(x) = v.pop() { .. }` and `if let Some(x)
  = v.pop()` replace a length test followed by a pop. `v.pop()!` is the old behaviour - the element,
  or the program stops with `pop from an empty vector` - and compiles to exactly the code it always
  did (no option is built). A discarded `v.pop();` on an empty vector now does nothing instead of
  aborting. **This changes existing code:** a `pop()` whose result is used as the element needs a
  `!` or a pattern. In this repository 125 sites were read: 17 became a pattern (`while let` over
  the stdlib's move loops in `vecs`, `btree`, `pool`, `iter`; `collections::pop` is now the builtin
  itself), and the rest take `!` because the surrounding code had already established the
  collection is not empty. A type mismatch against an option now spells it `u64?` rather than
  `result::Option<u64>`. Cases `pop-returns-option`, `pop-insisting-on-empty-aborts`,
  `pop-option-is-not-the-element`.

- **A record prints.** `println(p)` and `format("{}", p)` on a record with no `show` method write its
  name and fields in declaration order - `Point { x: 1, name: "a" }` - a tuple prints as it is
  written (`(1, "x")`), and nested records and vectors print inside. A type with no form (an enum
  without `show`, an extern record) is refused by name (`` `E` has no text form ``) instead of with
  a list of the types that do print.

- **`{n}` in a format string is refused by name.** Grail's placeholder is `{}`; `println("n is
  {n}", n)` used to say "unmatched brace" and `println("{n}")` printed the braces. Both now say
  `` `{n}` is not a placeholder: write `{}` and pass `n` as an argument ``. Braces around a word that
  is no binding in scope are still text in a lone literal.

- **A closure's result is its body's type.** `g := |x: u64| x * 2` returned `unit` and dropped the
  product unless a `->` or an expected type said otherwise; an expression body now gives the
  closure its result type everywhere. A block body that returns a value with nothing to fix the
  type (`|a: u64| { return a + 1; }`) is refused with the spelling that works, instead of dropping
  the value.

- **The prover reads five more everyday shapes.** An argument may be a term plus or minus a
  constant (`get(&v, i + 1)`, `get(&v, i - 1)`, `get(&v, v.len() - 1)`); a comparison may carry its
  constant on the left (`while i + 1 < v.len()`); a field reached through a binding nothing can
  write is a term (`c.at < c.items.len()` proves `get(&c.items, c.at)` when `c` is a shared
  reference or a record that is not `mut`); `.len()` in an argument no longer counts as a call; and
  a subtraction the facts order (`hi - lo` with `lo <= hi`) keeps no underflow check, so it can sit
  in a `@no_panic` function. Offsets are read only in a checked build - the arithmetic is the
  program's, and a wrap build can wrap it - and a field behind `&mut` or a `mut` binding states
  nothing. Tightened on the way: in a wrap build a condition with an offset (`i < n - 1`) is no
  longer taken as a fact. Cases `refinement-argument-*`, `refinement-field-path-*`,
  `refinement-subtraction-*`.

- **`grail build`, `check`, `run` and `fmt` refuse a flag they do not have.** A `--word` that is
  none of the driver's used to fall into the input list, where a build ignored it: `grail build
  --strict-refinments main.grl` compiled without the flag and said nothing. It is now refused by
  name before anything is built, with the nearest real flag when one is close (`did you mean
  `--strict-refinements`?`), and a flag of the compiler proper (`--backend=llvm`, `--range-facts`,
  `--export`, `--typed-refs`) says that is what it is. Words for the program a `run` starts go
  after `--` and are never read. The driver gains two flags it forwards: `--strict-refinements` and
  `--emit-ir` (the typed IR, written to `target/NAME.s.tir`). The driver's flags are one table
  (`flag_table` in `compiler/cli.grl`), so a new flag is a row.

- **`[1, 2, 3]` is a vector literal.** The element type is the first element's, and each later
  element is checked against it; where the context names a vector type (a typed binding, a
  parameter, a field, a return type, an assignment, an enclosing literal's element type) the literal
  takes that type, so `b: u8[] = [104, 105]`, `rows: u64[][] = [[1], []]` and `return [];` need no
  type written twice. `[v; n]` repeats. The colon decides between the two bracket literals -
  `["a": 1]` is a map, `[:]` the empty map - and the two empty forms need an expected type (`[]`
  alone is refused naming both spellings that work). `u64[1, 2, 3]` stays as the explicit form,
  braces are unchanged, and a `[` after an expression is still indexing. Cases
  `literal-untyped-vector`, `literal-untyped-vector-expected`, `literal-untyped-empty-needs-type`,
  `literal-untyped-mixed-elements`, `literal-untyped-element-against-expected`.

- **The compiler is 2x to 9x faster, and its time is linear in program size.** Checking a
  104k-line program of 4,000 small declarations took 166 s and takes 18 s; the compiler compiles
  itself in 42 s instead of 74 s; hello world checks in 0.59 s instead of 1.19 s. Nothing it emits
  changed (the self-compile is byte-identical). What was fixed, from a profile of the compiler
  itself: function, type, specialisation and emitted-helper lookups were scans that allocated per
  candidate and are now hashed; every generic specialisation re-read and re-tokenised its source
  file; the allocator took its lock in a single-threaded process; a keyword test copied the token
  it compared; the optimiser built a record per comparison. A program may now have 65,536 generic
  specialisations (the limit was 1,024). `bun tools/compile-bench.mjs` measures all of it (scaling
  at three sizes with the fitted exponent, hello world, a generic-heavy program, the self-compile),
  the gate records the numbers, and `docs/design/compile-speed.md` has the table, the findings and
  the order of the remaining work.

- Fixed, **soundness**: **a refinement fact survived a write in a loop.** `mut i = 0; while i < 3 {
  take0(i); i += 1; }` with `take0(i: u64 where i == 0)` compiled under `@strict` and printed
  `0 1 2`: the fact `i == 0` from before the loop was still believed at the body's first statement
  on the second iteration, so the check was removed. Every name a loop body assigns, lends out with
  `&mut` or calls a non-pure method on now loses its facts before the body is compiled (`while`,
  `loop`, counted and pattern `for`, map loops, nested loops), a loop owns a fact scope of its own
  so a shadowed fact comes back when the loop ends and not at an unrelated block's close, and a
  call of a closure forgets the names that closure writes. Strict mode refuses the program, plain
  code keeps the check and aborts on the second iteration. `grail build --verify-facts` now reaches
  the compiler (the driver accepted the word and dropped it). Cases `refinement-loop-write-*`,
  `refinement-assignment-kills-fact`, `refinement-loop-mut-borrow-kills-fact`,
  `refinement-loop-field-write-kills-fact`, `refinement-nested-loop-outer-write-kills-fact`,
  `refinement-loop-branch-write-kills-fact`, `refinement-shadow-fact-ends-with-scope`,
  `refinement-loop-invariant-name-still-proved`; the book's refinements chapter states the loop
  rule and no longer says no check has ever fired.

- Fixed: **a runtime error could name the statement after the one that failed.** The location walk
  took the statement whose label is not past the return address, and a return address is the byte
  *after* the call: when the failing call was its statement's last instruction (`take0(i);` as a
  statement), the report and the backtrace named the next line. The walk now compares strictly, and
  the backtrace looks up `return address - 1`.

- Fixed: **a refusal could name the wrong type.** `type_name` - the speller about half the
  diagnostics used - answers in the interface format for anything it does not name itself, so an
  element or argument of type `u8` read back as `(int 8u)` and an `f32` as `f64` (f32 and f64 are one
  store kind told apart by width, and its plain-word arm answered by kind alone). The user-facing
  messages now go through `source_type_name`, the speller the type-mismatch diagnostics already used:
  a `Send`/`Share` bound refusal, an associated-type mismatch, the `[]`-on-a-non-sequence refusal and
  the specialisation name in a diagnostic (`fill<Arg>`) all name `u8`, `f32` and a record as the
  author wrote them, and a same-module record loses its qualifier (`Plain`, not `main::Plain`).
  `type_name` keeps the interface spelling, which is what the interface round-trip refusal has to
  report (it says what the *file* wrote and read back), and it now spells an f32 as `f32` wherever it
  is still reached. Cases `index-invalid-type-spells-f32`,
  `assoc-equality-bound-spells-narrow-int`; the expectation in
  `reject-unsafe-struct-type-argument-unclassified` moves with the dropped module prefix.

- **A `for` header destructures a tuple element.** `for (at, c) in pairs { .. }` binds each field of
  the element to its own name, the way `(at, c) := pairs[0]` already did, so `char_indices`,
  `iter::zip` and `iter::enumerate` chains no longer end in `pair.0` / `pair.1`. The pattern must
  name exactly as many fields as the element has (`the element is a 3-tuple and the pattern names
  2`), `_` skips a position and drops what it held, an owned field such as a `u8[]` moves out of the
  element (the element's own record is freed and nothing else is), and a non-tuple element is
  refused naming the element type as the source spells it (`u8` for an element of a `u8[]` or a
  `string`-shaped byte sequence, `f32`, a record's own name), and a borrowed element (`for (a, b) in
  &pairs`) is refused with the alternative rather than the reference's internal spelling. The comma
  form `for k, v in &m` and the counted forms are unchanged. Cases `for-tuple-pattern-halves`,
  `for-tuple-skip-position`, `for-tuple-moves-owned-element`, `for-tuple-iterator-chain`,
  `for-tuple-arity-mismatch`, `for-tuple-non-tuple-element`, `for-tuple-bytes-element`,
  `for-tuple-float-element`, `for-tuple-record-element`, `for-tuple-rejects-borrowed-element`.

- **A map can be iterated.** `Map::keys()`, `values()` and `iter()` (both at once) yield references
  into the map, in its storage order, borrowing it the way `iter::refs(&v)` borrows a vector - so
  `for k in m.keys() { m.insert(..) }` is refused as a borrow conflict rather than corrupting the
  walk. `iter::from_step(closure)` is now the public seam a module outside `iter` uses to build its
  own iterable, so every iterator in the language is still one record with a `next`. Before this,
  iterating a map meant `for i in m.len() { *m.value_at(i) }`, which is the shape people coming from
  Rust reach for once and then work around.

- Fixed: a narrowing integer conversion that does not fit **aborted the program with an empty
  stderr**. `x: u64 = 300; y := u8(x);` exited 134 with nothing said, while every other failed
  runtime check reports its message and line. `rt_int_cast` called `rt_abort()` directly; it now goes
  through the reporting path with two new kinds, so `u8(x)` says `error: value 300 does not fit in
  u8` with the caret on the conversion, `u16(x)`/`i32(x)` name their own target, a negative value
  into an unsigned target keeps `negative value converted to an unsigned type`, and a negative value
  into a smaller signed target prints the sign the program wrote (`value -300 does not fit in i8`).
  A constant the target cannot hold is refused at compile time instead - `error[E0015]: integer 300
  is out of range for u8 (0..=255)` - and `wrapping_u8` stays the silent, intended-truncation
  spelling. Cases `runtime-narrowing-conversion-report`, `runtime-narrowing-conversion-u16`,
  `runtime-narrowing-negative-to-unsigned`, `runtime-narrowing-negative-to-signed`,
  `narrowing-conversion-of-a-constant`, `narrowing-conversion-wrapping-is-a-choice`. The help line
  that accompanied an out-of-range literal named the wrong conversion - "convert explicitly
  (`u8(x)`), which truncates" - while `u8(x)` checks the value at run time and `wrapping_u8(x)` is
  the truncating spelling; it reads "write a value that fits, or truncate on purpose:
  `wrapping_u8(x)` says the narrowing is intended, where `u8(x)` checks the value at run time".
  docs/design/frontend-robustness.md, class 2.
- Fixed: a declaration the file ends in (`fn f(a: u64`, nothing after it) **aborted the compiler**
  with `error: index 24 out of bounds for length 24 --> compiler/native.grl:5874:5` and a backtrace.
  Three passes scan forward to a body's `{`; the stream ends with an end-of-file token, the scan
  stepped over it, and `kind()` indexed the token vector unchecked. `kind`, `tok_text` and `fail`
  now answer "end of file" past the last token, and the scan stops there and refuses as any missing
  token is (`expected `{`, found the end of the file`, with `this `fn` has no body` on the `fn`).
  The same fix closed a second crash one layer under it: `fail` marked the secondary labels it had
  drawn by setting their token index to 0, and 0 is a real token - the first `fn` of a file - so the
  renderer asked for the label after the last one and indexed past it (`index 1 out of bounds for
  length 1`). Labels carry their own drawn flag now. Cases `frontend-fn-without-body`,
  `frontend-fn-without-body-generic`; docs/design/frontend-robustness.md.
- Fixed: `return;` in a function whose result is unit was refused with "expected a name here, found
  `;`", and there was no spelling for an early return from a unit function at all (`return ();` and
  `return unit;` failed differently). `return` followed by `;` is a return from a unit function now;
  a function with a result still has to name one, and the refusal says so: "`return` needs a value:
  this function returns `u64`". Cases
  `early-return-unit-function` (which runs), `early-return-needs-value`.
- Fixed: `struct N { v: u64, next: N }` was accepted in silence, and no value of the type can ever
  be built - the field that names the record needs a value of the record first. A record that
  contains itself by value is refused, with the caret on the field that closes the cycle, and the
  fix named: an optional field (`N?`, whose value can be `None`), a reference, or a vector. Only the
  edges a value cannot avoid are followed, so `next: N?`, reference fields and vector fields stay
  accepted, and a mutual cycle is refused at the record that is completed second. Cases
  `record-contains-itself`, `record-contains-itself-indirectly`, `recursive-record-through-optional`.
- Changed: a refusal about the program's entry names the entry and the file instead of pointing into
  the standard library. `grail check` of a module with no `main` used to say `error: executable entry
  must return u64 --> lib/result.grl:128:1`: the diagnosis was about a function borrowed from
  entry selection, at a line in a file the user never wrote. The refusal now names it - "the entry
  `main::helper` was picked because this module has no `main`, and an entry must return `u64`; it
  returns `u8[]`. Give the program a `pub fn main()`" - or says there is none, at the file the
  caller named. Entry *selection* is unchanged. Cases `entry-picked-function-named`,
  `entry-missing-names-the-file`, `main-result-type-named`.
- Added: `tools/fuzz-frontend.mjs`, a front-end fuzzer that mutates real sources (the test corpus,
  the book's examples and the compiler's own modules) and runs one compiler per case, and classifies
  each outcome - `fine` (a diagnostic), `bug` (a signal, a runtime check inside the compiler, a hang),
  or `other` with the reason. Deterministic from a seed, one case per crash site, with a shrinker.
  `ci.mjs lint` runs 200 mutations from seed 1, so the class cannot come back unnoticed.
  docs/design/frontend-robustness.md has the mutation set, the classification, and the bug list with
  repros: 0 bugs and 0 hangs on the 200-case seed, from 2 bugs before the fixes above.
- `grail build --module-root DIR` now reaches the compiler. The flag was taken for a path by the
  option parser, so the resolution run never saw it and the build refused the module with a message
  telling the caller to pass the very flag it had passed. A command-line root comes before the
  stdlib's, so a project can shadow a std module by name.
- `grail build --emit-interface DIR`, `grail build --no-entry` and `grail build --print-inputs FILE`
  work on the driver, as they already did on the compiler. `--print-inputs` writes the module set the
  build resolved and still builds.
- A call that passes too many arguments has a case pinning its message; it had none.

- Added: **the per-function codegen cache** (`compiler/fncache.grl`, `--fn-cache DIR`). A module run
  that misses can now replay the functions whose inputs did not move: a function's whole emitted
  region, the label numbers it mints and its typed-IR facts are filed under a key naming its source
  text, its structurally spelled signature, the run's declaration surface, the option vector, the
  compiler's own digest and its starting label numbers. `grail build --cache` passes the store, so the two caches compose - a
  module-level hit runs nothing, a module-level miss replays every body it can. A body is a unit only
  when its emission added nothing outside its own bytes (no specialisation, closure, drop helper,
  vtable, link input, constant, debug record or effect record), and everything else is emitted as
  before: `docs/design/incremental-compilation.md` writes the rule down, including the excluded
  classes and why. On the compiler's own 2,569 bodies, 879 are units and a full replay is byte
  identical to a clean build; `tools/cache-test.mjs` section (i) measures it.
- Changed: `grail build --cache` prints one `grail: fn-cache: MODULE: N hit, M filed, K not units`
  line per per-module run, the layer's own account of what a run replayed and what it re-emitted.
- Changed: module interface files are a **typed record stream, format 4**, not line-oriented
  text. The compiler wrote the text and then re-read it with a hand-written line lexer and parser -
  two implementations of one format, and one of them three hundred lines of spelling rules that had
  already lost a qualified enum in a signature (`&a tls::Error`) and needed a version bump to thread
  the effects row. Now one writer encodes the declarations and one reader consumes them:
  `GRIF`, a version byte, then `tag, length, payload` records (module, type, alias, const, fn,
  inherent, interface, impl, env, link) whose types are records too, then a trailer carrying the
  source digest and the SHA-256 of every byte before it. Every record and every string is
  length-counted, and the reader refuses a record with bytes left over rather than skipping them, so
  a field this compiler does not know is a refusal by name and never a misread. Refusals name the
  file, the record and the byte: not an interface, the old text format, another version, truncated,
  unknown record, unread field, edited (trailer digest), not in the manifest, stale, disagreeing.
  `grail iface dump FILE` renders the typed record tree the reader read - the inspector, with no
  second parser behind it - and `grail iface roundtrip FILE` reads a file, writes it again and
  requires byte identity. The surface (which private items travel because a public item names them)
  is computed from the types and text the writer itself produces, not by scanning emitted lines. A
  build cache keys on the interface's *surface* bytes (everything before the trailer), so an edit
  that changes no declaration still leaves downstream keys alone. Two behaviour changes: a generic
  interface implementation (`impl<T> Show for Pair<T>`) now carries its parameters - the text format
  wrote `params=0` because writer and reader looked the record up under different keys - and the
  compiler's own interfaces drop from 14,427 to 8,733 bytes, with emission from 4m12s to 2m14s.
  The header record also carries the borrowed-`dyn` ABI (`abi dyn pair size = 16 align = 8 word0 =
  data word1 = vtable drop = 0`, one string, `iface_dyn_abi()` its only spelling), so two modules
  built for different pair layouts refuse to link rather than dereferencing each other's pairs
  wrongly. docs/design/separate-compilation.md, "Format 4 as built"; cases `ifc-*`, and
  `tools/interface-test.mjs` proves round-trip equality and every refusal.
- Fixed: the windows suite's Windows ARM64 frame-size check never ran. It matched `.set .F<n>,<size>`,
  but a frame constant is named in its unit's namespace (`.set .F<unit>_<n>,<size>`), so the pattern
  matched nothing and a tolerance added for the apparent absence (`672e1da`) turned the comparison
  into `if (haveFrameTable)`. That is the one check guarding against a wrong frame size in an unwind
  record, which corrupts stack walks on real hardware. The table was there all along: every ARM64
  function emits its constant, its prologue subtracts that constant (`movz/movk x10,#.F<n>; sub
  sp,sp,x10`) and the unwind pass writes it as `.seh_stackalloc`. The suite now requires one table
  entry per function and compares each record's `sub sp, #n` against it, so a table that disappears
  or goes stale fails instead of skipping.
- Changed: an `impl` may name a type no module declares - `impl u8[] { ... }`, `impl [u64] { ... }`,
  `impl<T> T[] { ... }`, `impl string { ... }` - and its methods are that type's own, so a method can
  exist on a slice or on text at all. `impl [T]` accepts the bare slice spelling and serves a `&[T]`
  and a `&mut [T]` receiver alike: the mode belongs to the value, so the method's own `self` type
  decides, and a `&mut self` method is refused on a shared slice (and a `&self` method on a
  `&mut [T]`). Method lookup is inherent first, then interface implementations, then the builtin
  collection methods - Rust's order. The collection protocol names (`len`, `push`, `pop`, `insert`,
  `remove`, `swap`, `contains`, `reverse`, `append`, `truncate`, `clear`) are refused where an impl
  declares them: `for i in v.len()` and every bounds check depend on what `len` means.
- Changed: `&self`, `&mut self` and `self` are the method receiver shorthand -
  `self: (&__self Self)`, `(&mut __self Self)` and `Self`, with a fresh region per method - and
  `&Self`/`&mut Self` spell the same reference in a signature, so `fn same(&self, other: &Self) -> bool`
  reads the way it does in Rust. Interfaces and implementations match whichever spelling each side
  used, and the written `fn f<a>(x: (&a Self))` still means exactly what it did. `&self` outside a
  method now says a receiver belongs to a method instead of `expected a name here`.
- Changed: the vector and text libraries are postfix. `lib/vecs.grl`'s operations are methods on
  `T[]` (`v.map(f)`, `v.filter(p)`, `v.fold(a, f)`, `v.reduce(f)`, `v.sort()`, `v.sort_by_key(k)`,
  `v.min()`, `v.max()`, `v.get(i)`, `v.first()`, `v.last()`, `v.any(p)`, `v.all(p)`, `v.count(p)`,
  `v.find(p)`, `v.position(p)`, `v.dedup()`, `v.iter()`, `v.into_iter()`, `v.binary_search(x)`,
  `v.insert_sorted(x)`, `v.sum()`), and `lib/strings.grl`'s are methods on `[u8]` (`text.find(n)`,
  `text.parse_u64()`, `text.parse_i64()`, `text.is_utf8()`, `text.utf8_error()`, `text.char_count()`,
  `text.is_char_boundary(i)`, `text.slice_chars(lo, hi)`, `text.char_indices()`, `text.lines()`,
  `text.split_whitespace()`, `text.to_text_lossy()`) with `chunks`/`windows` on `u8[]` and
  `join_with` on `u8[][]`. A byte vector or a string is viewed for a `[u8]` receiver, so
  `bytes.trim()` and `view(bytes).trim()` are both the old `strings::trim(view(bytes))`, and a view
  receiver is reborrowed so one binding serves several calls. Every old free name still works
  (they are one-line forwarders), except `vecs::any_num`, `all_num`, `count_num`, `position_num` and
  `max_num`, which are gone: the generic `any`/`all`/`count`/`position`/`max` methods replace them.

- Fixed: the windows suite no longer requires the `.set .F<n>` frame-constant table on Windows ARM64, where prologues size their frame with `sub sp, #n` instead. ARM64 unwind records are still checked one per function, with length, frame-pointer pair and `mov fp, sp`.
- Fixed: `tools/interface-test.mjs` wiped `.work/interface-test/<target>` at the start of every run,
  so two runs in one checkout deleted each other's interfaces mid-run and the survivor failed with
  `has no interface for module X (expected this file)` - a directory collision, not a compiler bug.
  Each run now works in `<target>-<pid>`, which is what made this look like a module-set bug in the
  interface emitter.
- Changed: the interface set is one rule, stated once and checked at the boundary. An emitting run
  writes one interface per source module of the program except the runtime and the platform modules -
  `core` included when `use` resolution makes it a source module, since the prelude is not exempt as a
  category - and `interfaces.manifest` is that set, not just a list of checksums: `--interface DIR` (a
  verification build, which `--verify-interface` names explicitly) now refuses a source module the
  manifest does not describe, naming the module and the file it should be in, where before only a
  module whose file the manifest listed could be caught. The synthetic units `.impl_N`, `.inherent_N`,
  `.interface_N`, `.union`, `.result`, `.closure`, `__start` and the entry's process furniture are
  excluded by name in docs/design/separate-compilation.md ("What an interface deliberately does not
  contain"), "What a run compiles, and what it writes" states the set for both shapes (a
  `use`-resolved program and an explicit source list), and `tools/interface-test.mjs` pins the
  manifest check by deleting one row and requiring a refusal that names the missing module.
- Corpus: the cases that assert a failure's location are scoped to the backend that emits the
  tables. A contained failure's `site`, and `host::backtrace()`, are read from the statement and
  function tables and the `rt_sites` helper the entry publishes, and `native.grl site_table_on`
  emits them only without `--backend=llvm` (as it already did without `--debug`, with `--split`,
  with `--no-error-sites`, and on macOS), so `GRAIL_BACKEND=llvm bun tools/test-native.mjs x86_64`
  reported `no site` for the four `rth-` cases that expect `site`
  (`rth-contained-then-joined`, `-thrice`, `rth-offer-five-names-the-frame`,
  `rth-offer-three-still-names-the-statement`). Those four now carry `"backends": ["native"]` and a
  `note` naming the mechanism, joining `tfail-trap-contained-at-join`, which already documented the
  same limit; the containment, the message and the kind stay asserted on both backends, and
  `rth-offer-two-refuses-the-descriptor` stays unscoped because its expected answer is the refusal
  that loses the location on purpose. docs/testing.md also records that `--backend=llvm` is a
  compiler flag with no `grail build` path - the driver assembles and links `OUT.s` only, never the
  `OUT.s.ll`, so `grail build x.grl --backend=llvm` silently builds the native one - and
  docs/design/task-failure-containment.md lists which builds carry a site table.
- Fixed: `grail build` of a multi-module project failed with an unknown-function diagnostic for
  `some` in `core` and left no `core.iface` behind whenever the program's standard closure reached
  `core` and `result` (reproduced without `--cache`). The per-module driver ordered its runs by the
  `use` graph alone, but `Some(value)` and `None` lower to `core`'s constructors, so a module may need
  `core` with no `use` line to say so - and the modules that write one ran before `core` did, so the
  failing unit read a `core` nothing had declared and `core`'s own run never happened. `core` is now
  an implicit dependency of every module outside the prelude, and the prelude - `core` plus the
  modules `core` itself `use`s, which is `result` - is built before it; `lib/result.grl` constructs
  its option values as `Option::Some(v)` instead of through the `Some(v)` shorthand, because the
  shorthand lowers to `core::some` and put `core` and `result` in a dependency cycle one compiler run
  per module cannot order (it needs `core` for its bodies and `core` needs its `Option` for `T?`).
  `tools/cache-test.mjs` (g) and `tools/split-test.mjs` build such a project per module again, and the
  corpus case `drv-per-module-three-modules` pins that every module a run compiles from source has its
  interface written (docs/design/separate-compilation.md, "What a run compiles, and what it writes").
- Fixed: `tools/split-test.mjs` wrote a project `grail.toml` whose package name spanned two lines
  (the fixture put a `\n` inside the quoted string), so every driver build in that tool stopped at the
  manifest with `grail.toml: line 2: unterminated string` before testing anything - the per-module
  section never reached the build it exists to compare.
- Fixed: a cached build passed the `--module-root` directory to `sha256sum` (one `Is a directory`
  line per build) and keyed the program on it, and the image shortcut did not see an edit to a module
  `use` resolution had added, so `grail build --cache` could hand back a stale image for a project
  whose standard closure changed. A module root is now an option with a value rather than an input,
  and the program record lists and re-checks the digest of every module source the build compiles.
- Changed: the effects prover no longer reads the emitted bytes for a fact. `fx_end` used to count the
  `call` lines in each body's text and refuse a body whose count disagreed with the calls it recorded;
  it now records what the body emitted and lets the typed IR answer, once, after the whole program is
  parsed (`ir::count_calls` + `fx_check_calls`). The check is unchanged in strength - a call site that
  bypasses `call_out`/`call_slot_out`/`call_dispatch_out`/`call_entry_out` still refuses the build -
  and it is the last text scan in the prover. Two things it had to respect: a `.proved` entry replays
  a copy of the checked entry's prologue (the recorded range is excluded), and the nine leaf accessors
  `parse` re-tags into pseudo-instructions 40..48 are calls too.
- Changed: an `@no_alloc`/`@no_panic` refusal for an indirect call now names what the call is. The
  effects record keeps the reason the target has no symbol (`fx_edge_why`, filled by
  `call_slot_out`), and a `dyn` receiver's site fills it from the interface the vtable belongs to, so
  the diagnostic reads "it makes an indirect call the compiler cannot follow (the target is interface
  `Shape` of module `m`)" instead of a blanket "an indirect call". A closure call, a function value
  and an imported function say which they are. Case `ssair-fx-indirect-names-interface`.
- Added: a typed IR with SSA values for the word stream, and its serializer
  (`compiler/ir.grl`, docs/design/typed-ir.md "A typed IR with SSA values, and its serializer").
  The optimizer's record moved out of `optimize.grl` into the IR module as `ir::Body`, and with it
  the stream parser (`parse`, `classify`, the opcode and register keys) and the operand algebra
  (`reads`, `writes`, `slot_read`, `slot_written`, `dst_writes`, `dst_address`, `result_live`):
  the two modules are now "what a body is" and "the passes that rewrite it". On top of the
  instruction record the IR carries what the text could not say: each instruction's defined value
  and the values it reads (minted per definition, bound inside a block, kept as the frame slot at a
  label), each value's type and width (from the front end's fact table, keyed by body symbol and
  slot, through the new reader `llvm::fact_slot_kind`), and the body's calls with the callee symbol
  in emission order. `ir::build` fills that layer once per body, before the passes. Nothing in it
  changes a decision yet: **the emitted assembly is byte-identical**, verified per function by the
  new `tools/ssair-bytes.mjs` over the x86-64 corpus and the compiler's own sources.
  `--emit-ir` writes the units beside the assembly (`OUT.s.tir`), versioned text, one unit per
  function; `tools/ssair-ir.mjs` holds the format to its own counts. Cases `ssair-emit-ir`,
  `ssair-emit-ir-split`.
- Fixed: the tree did not compile. Two merge sites arrived half-applied on `gaps-int5`:
  `none_tag` lost its closing brace, so `compiler/native.grl` reported "unclosed {" at end of file,
  and the field-shorthand path of a record literal still called `primary(&mut c)` after `primary`
  gained its `expected` type, so a typechecked build reported "function argument count". Both are
  one-line repairs (`primary(&mut c, field)`, which is the type the shorthand's field has); the
  emitted assembly is unchanged.
- Named and default arguments. A call may name the parameter each argument fills - `f(x: 1, y: 2)`,
  positional arguments first, and every argument after the first named one named too - and a
  parameter may carry a default (`fn f(x: u64, y: u64 = 0)`) that a call leaving it out gets. A
  default is a value the declaration supplies, compiled where the call is written: it adopts the
  parameter's type, is owned and borrowed exactly as an argument is, and can build an owned value in
  the caller's frame. The argument list is resolved into one slot per parameter before any argument
  compiles, so the refusals are all at the argument: a name the declaration does not have (naming
  its parameters), a parameter given twice, a positional argument after a named one, a parameter
  left without an argument and without a default, and a default on a parameter followed by one
  without. A short call's diagnostic now names the parameter it leaves empty, not only the count.
  Parameter names and each default's *text* travel in interface files (`param`, `default`), so an
  importing module still names its slots and still compiles what the declaration wrote;
  `--verify-interface` agrees. The compiler's own `compile`, `compile_mode` and `build_argv` - nine
  positional arguments each, three of them empty at most call sites - now name their arguments and
  let `iface`/`verify`/`diag` default, and `flag_bits` takes the check-only bit as a named argument
  instead of every caller adding `1`. docs/design/named-arguments.md; cases `nargs-*`; the book's
  "Functions and recursion" gains the section and its example.
- Changed: a borrowed interface object's shape is now stated by the language instead of declared by
  the emitter. A `&dyn I` is one 8-byte pointer to a 16-byte, 8-byte-aligned `{data@0, vtable@8}`
  pair, whose vtable is `{drop, method0, method1, ...}` with the destructor's slot first
  (`docs/design/fat-dyn.md`). One word is what keeps a borrow a borrow: the handle is the same size,
  alignment, copy and drop as any `&T`, so it sits in a record field, a vector element, a generic
  argument or a result unchanged - a two-register fat pointer would double each of those and put
  Win64's 16-byte-aggregate-by-reference rule, and 32-bit targets' hidden `sret` pointer, on every
  signature that mentions one. A returned `&dyn I` still travels as the pair's two words
  (`%rax:%rdx`, `x0:x1`, `a0:a1`), which is those platforms' own rule for a 16-byte `{ptr, ptr}`
  aggregate, and the caller stores both into its own frame. The `.gpair` directive is gone from the
  emitted stream and `pair_new` with it: the front end records the pair as a typed-IR fact about the
  body that builds one (`llvm::fact_dyn_pair`, and `llvm::fact_dyn_result` for a body that returns
  one, beside the instruction stream and keyed by body symbol), and `optimize.grl` and `llvm.grl`
  read it there, so the optimizer's two-word frame value is a fact about a language type rather than
  a marker it parses out of assembly text. A pair-building function compiles to exactly the
  instructions it did (the assembly of `opt2-dyn-pair-loop` is byte-identical), building one still
  allocates nothing, and it is still optimized rather than copied unchanged. The interface format
  goes to `// grail-interface 4` with one header line - `abi dyn pair size = 16 align = 8 word0 =
  data word1 = vtable drop = 0` - which the reader compares with its own ABI and refuses when it
  differs, so separately compiled modules cannot be built for different `dyn` layouts; a v3 file
  meeting this compiler is refused with the version it was written in. Cases: `dynf-pair-layout`
  (the offsets, by assembly), `dynf-borrowed-mut-method`, `dynf-owned-dyn-field`,
  `dynf-pair-fields-and-vectors`, `dynf-pair-optimized`, and `dynf-pair-c-boundary`, which pins the
  layout by a *call*: a shared `&dyn I` parameter of an `extern "C"` function is now the C
  `const DynPair *` - one pointer argument, the pair's address - so a callee reads the object at word
  0 and its table at word 1, and one callee serves two concrete types. That is the only reference
  parameter that is a reader rather than an out-parameter; `&mut dyn I` stays refused (C writing a
  16-byte pair is not part of the ABI), which `dynf-reject-c-boundary` pins.

- Ranges: a range value is now a `Span` (`lib/span.grl`) that carries the slice it was made from - a
  byte view plus its two ends - so a range its slice does not have is refused where the span is made
  (`span_of` yields `1..0`, which names no bytes) and a range taken from one sequence cannot reach
  another: `s[r]` is a compile error that names both spellings that mean something, `r.bytes()` and
  `s[a: b]` / `s[a..b]`. `..` is accepted in brackets exactly where `:` is (`s[a..e]`, `s[a..]`,
  `s[..e]`, `s[..]`, on sequences, byte views and strings) and lowers to the same
  `rt_slice`/`rt_vslice` call: the assembly of a representative loop-and-slice program is byte
  identical before and after. The compiler's own four-argument `same(s, a, e, w)` is gone - its 30
  call sites build a span from the slice they scan (`same(span_of(s, a, e), w)`, or `at(s, a, w)`
  when the window's extent comes from the needle) - which deleted the defensive `e > s.len()` guard
  and halved the emitted `optimize.same` (270 -> 135 lines of assembly) while leaving the two-argument
  `native.same` byte-for-byte untouched. The count-only range in a loop header (`for i in 0..n`) is
  unchanged and still drives the bounds-check elimination. docs/design/range-values.md; cases
  `rng2-*` and `tests/lib/span.grl`.
- Added: `lib/result.grl` - `pub enum Result<T, E> { Ok(T), Err(E) }` and
  `pub enum Option<T> { Some(T), None }` with the combinators that do not panic (`is_ok`/`is_err`,
  `ok`, `err`, `unwrap_or`, `map`, `map_err`; `is_some`/`is_none`, `unwrap_or`, `map`, `ok_or`,
  `to_result`). `T?` is now the concise spelling of `result::Option<T>`: the internal
  `core::OptionStorage` enum it used to name moved here, was renamed and made public, so `Some(5)`,
  `Option::Some(5)` and a `u64?` are one type rather than two lookalikes; `lib/core.grl` imports
  `result`, which keeps `T?` reachable everywhere it was. A payload may itself be another instance
  (`Result<u64?, string>`), a reference, or a record.
- Changed: `?` (and `!`) read a shape, not a variant-name convention. Any type with exactly one
  success member and one failure member propagates: a two-member enum (`Ok`/`Some` by name, otherwise
  the first declared variant is the success), a two-member ordinary union (the first member), and a
  result union `S |? F` (its declared success members, any arity). A shape that cannot say which
  member fails - an enum with three or more variants, an ordinary union with three or more members -
  is refused with a diagnostic that names the type, its members and the count, replacing
  "unwrap requires two-variant Option/Result" and "unwrap requires Ok/Err or Some/None variants",
  which named neither. No implicit conversion was added: the failure type must still match exactly.
  docs/design/generic-results.md records the rule, the specialisation keys and why the concrete
  error shapes (`io::Error`, `fs::Error`, `errs::Report`, `dns::Error`, `net`'s `io::Error`) stay
  concrete.
- Fixed: a type-mismatch diagnostic named a `string` value `u8[]` and a `u8[]` value `string`:
  `source_type_name` had the two store kinds swapped. Passing a string literal to `fn half(x: u64)`
  now reports the found type as `string`, which is what the source wrote.
- Fixed: a bare `None` stored tag `0` whatever the option declaration's variant order, so it was read
  back as its sibling; the tag now comes from the declaration (`none_tag`), which is what let `Option`
  be declared `{ Some(T), None }` at all.
- Ergonomics: `if` produces a value where one is required - an initializer, an argument, a `return`, a
  record field, a match arm expression: `x := if c { 1 } else { 2 };`, `else if` chains included. The
  statement form is untouched (`statement_body` sees an `if` that begins a statement first), and the
  lowering is the statement `if`'s - same condition check, same per-arm ownership snapshots, same merge
  at the join - plus one frame word every arm stores its expression into, owned once *after* the merge
  so exactly one value exists however many arms wrote it (per-arm slots would leave two places where
  the program has one value, which the place model is not path-sensitive enough to join). `primary`
  now takes the type its context expects, so a literal, a `None` or a narrower integer adopts it
  before the arms are compared: `n: u8 := if c { 1 } else { 2 };` is two `u8`s. Refused by name: an
  `if` with no `else` ("an `if` in expression position needs an `else`... add `else { ... }`, or write
  the `if` as a statement"), two arms of different types (the primary line names both: "the other arm
  is `u64`, this one is `u8[]`", labelled at the other arm), an arm that is a block of statements or
  holds statements before a value, an arm that writes (`{ x = 1; }`), and an arm whose value borrows
  ("the result is one word, so it cannot name both arms' loans: use the reference inside each arm" -
  documented limitation, not a semantic rule). A diverging arm (`return`, `break`) needs no value and
  the other arm decides the type; both arms diverging is refused ("neither arm of this `if` produces a
  value"). Also fixed: a statement word where a value was required used to report
  `error[E0001]: undefined name` under the keyword - it now says *`for` is a statement, not an
  expression: it has no value*. Reasoning and the lowering in docs/design/if-expression.md; book:
  *Branches and loops* with the `if-values` example; corpus: the sixteen `exprif-` cases.
- Ergonomics: `match` is an expression too - `x := match n { 0 => 1, _ => 2 };`,
  `return match k { Rate(n) => n * 2, Empty => 0 };`, `show(match e { A(v) => v, B => 0 })`. The
  statement `match` is unchanged: `match_statement` is that same code (scrutinee, patterns, per-arm
  ownership snapshots, the failed-match abort, the exhausted-match check) with one flag set, so an
  arm body writes its value into one frame word instead of discarding it, and that word is owned once
  after the arms join - the lowering `if` in expression position uses. An `if` with `else` is an
  ordinary arm body (`0 => if c { 1 } else { 2 },`), and so is a nested `match`. Refused by name: an
  arm that is a block of statements but falls through, arms of different types (the primary line
  names both and the arm that fixed the type is labelled), an arm whose value borrows (`match n { 0
  => &a, _ => &b }` - one result word cannot name both loans), and a match no arm gives a value to.
  A diverging block arm (`_ => { return 9; }`) needs no value. The declared type of the binding is
  adopted by a literal or `None` arm, as for `if`. Two claims in earlier notes are corrected: a block
  arm is a statement list and needs its semicolons (`_ => { P { x: 1 } }` was documented as working
  and does not), and `_ => if ...` is refused for a statement `match` but is an expression arm in an
  expression `match`. Reasoning in docs/design/match-expression-arms.md; book: *Enums, match and
  early exits* with the `match-values` example and its Rust comparison; corpus: the ten
  `exprif-match-` cases.
- Changed: `exchange` is two-phase, like a call. Its value argument is now evaluated before the
  `&mut` is borrowed, so `x := exchange(&mut p, p + 1)` stores the value `p` already holds plus
  one and returns the old `p`, and `exchange(&mut c.pos, c.pos + 1)` or `exchange(&mut c.f, c.g)`
  read where they are written instead of through a hoisted temporary. Taking the value from the
  place being written stays refused: `exchange(&mut a, a)` and `exchange(&mut a, &mut a)` are
  errors. compiler/README.md, compiler/NATIVE.md and the borrowing and references chapters state
  the rule, and `exch-inline-field-read`, `exch-reads-old-value`, `exch-record-field-swap` pin the
  accepted shapes with `exch-rejects-same-place`/`exch-rejects-same-ref` the refusals. The
  compiler's own sources drop the 19 `tmp := c.field; exchange(&mut c.field, tmp);` hoists the old
  order forced; the 5 that remain read the vector that the written place indexes (`&mut o.op[last]`
  with `o.op.len()` above it), which is part of taking the place, not an argument.
- Fixed: a C callback definition (`extern "C" fn ... { }`) could declare a byte view parameter, and
  the caller then crashed with no diagnostic: C passes a view as two argument words (pointer then
  length), the exported function's prologue reads one argument word per parameter, so the view
  arrived as its pointer and the next parameter took the length - a segfault when the body read
  through the misread value. Refused at the definition now, by name and with the working spelling:
  `parameter `v` is a byte view, which C passes in two argument words (pointer then length); a C
  callback entry reads one argument word per parameter - take `v: CPtr` and a `u64` length, and copy
  the bytes with `cslice(u8, p, n)` inside an unsafe block`. A `cfn` type still accepts a view,
  because it describes a callee Grail calls and a call emits the pair; a buffer-shaped callback
  *result* was already refused (a callback answers in one register). `tests/native-cases.json` pins
  the refusal for the first parameter, for a `&mut [u8]` in the middle of the list, and for the
  result position, and `ffin-c-definition-pointer-length` executes the accepted `CPtr` + `u64` shape
  on x86-64, AArch64 and RISC-V 64.
- Narrow integers across the C ABI: what a caller must put in the argument register is now stated
  per target in `docs/ffi.md` ("Narrow integers") and pinned by tests on x86-64, AArch64 and RISC-V 64.
  A narrow argument crosses as the type's canonical word - unsigned zero-extended, signed
  sign-extended - which is what System V x86-64, Win64 and AAPCS64 require (they extend to 32 bits
  and leave bits 63:32 unspecified); RISC-V 64 LP64D wants the value zero- or sign-extended to 32
  bits and then sign-extended to XLEN, so a `u32` is sign-extended at the boundary there and
  `0xffffffff` arrives as `0x00000000ffffffff` on the other targets, both correct for a C callee that
  reads 32 bits. A narrow result is re-extended from the declaration because C leaves the upper bits
  of the result register unspecified. New: `tests/ffi/narrow_upper.grl`, whose C twins are declared
  `unsigned long long` so the C side sees the whole register - the six widths in argument and result
  position, one `connect`-shaped symbol declared twice (narrow and wide, each twin answering whether
  the register held the word its own ABI requires), and the narrow fields of a 16-byte record passed
  by value; plus the corpus cases `ffin-narrow-arguments` (the doubled declaration and every width at
  the first, seventh and ninth integer word), `ffin-narrow-arguments-riscv64` (the RISC-V sign
  extension), `ffin-narrow-results` and `ffin-narrow-record-fields`, which need no C toolchain: their
  C-ABI callee is a Grail `extern "C" fn` returning the whole 64-bit word.
- Added: the compiler resolves `use` itself. `--module-root DIR` (repeatable) names a directory a
  `use NAME;` is looked up in as `DIR/NAME.grl`, and the closure is transitive and cycle-safe, so a
  program that says `use fs;` builds without listing `lib/fs.grl` - or anything fs uses - on the
  command line. Roots are tried in order: `--module-root` as given, then the stdlib directory of every
  input file that sits beside `core.grl` (the layout the compiler already recognises as a standard
  module), then a project's `src/` when the working directory holds a `grail.toml`. A module the
  command line names explicitly still wins, so naming a file is never wrong, only unnecessary; and an
  unresolvable `use` is a hard error naming the module, the file that asked and every root searched,
  instead of the unknown type deep inside an imported module it used to be. `core` (which `Some`/`None`
  lower to) and `use host;` are handled as before: core is compiled when a root holds it, and `host`
  is the ambient interface, not a file. `grail build`/`check`/`run`/`test` pass the stdlib root
  automatically, and the project root needs nothing. The three copies of "scan `use` lines and guess
  the module set" - `stdClosure` in `tools/test-native.mjs`, `stdNames` in `tools/book.mjs` and
  `used_std` in `compiler/cli.grl` - are gone, with 547 `lib/...` entries in
  `tests/native-cases.json` and 13 `std` lists in `book/book.json`; `grail build --watch` watches
  every standard module instead of a copy of the answer. `lib/json.grl` now says `use hashmap;`, the
  module its concise map type needs. docs/design/module-resolution.md; cases `useres-*` pin the
  std-by-name build, a transitive chain, a cycle, the searched-roots diagnostic and explicit-name
  precedence. The corpus's `asm`/`asmAbsent` pins may now be scoped to one function
  (`{"in": "f_main_get", "text": "call rt_trap"}`), because the standard library is part of every
  program and its own checked arithmetic traps.

- Tooling: `grail test` gained the ergonomics a regression run needs. Selection: `--filter TEXT`, `--list`, `--shard i/n`, `--jobs N`; reporting: a `FAIL NAME` block per failure (the case, its source path, what the exit status and the output pins expected, the actual status/signal and stdout/stderr), a stable `passed X failed Y skipped Z` line, and `--fail-fast`. `--update` rewrites a corpus case's `stdout`/`status` from the observed run, only when it is asked for - a `stderr` pin or a `signal` pin is never rewritten. Inside the Grail tree `grail test` forwards every argument to `tools/test-native.mjs`, which is now the same engine behind those flags; a project runs its `tests/` programs through one child per test with a per-test log. docs/testing.md says which command owns what.
- Added: `grail doc` generates the reference documentation of a Grail source tree - one HTML page per module, a searchable index and an `index.json` model - from the comments and declarations the sources already carry. Grail has no doc-comment syntax, so a `//` comment block directly above a declaration or a field is its documentation, read from the source text (compiler/docgen.grl). Each function carries its signature with its `where`/`ensures` clauses and its `@no_alloc`/`@no_panic` claims, each record/enum/interface its members, variant payloads and method signatures, and `impl`s and aliases are listed. A doc body links an identifier when exactly one declaration in the tree has that name. The tree is deterministic (sorted, `<kind>-<name>` anchors, no clock), so it reviews as a diff; `grail doc` documents `lib/` (29 modules, 582 declarations) and the compiler (124 modules, 2532 declarations) without building either. docs/tooling/doc.md; pinned by tools/test-cli.mjs.
- Debug info: the DWARF a `--debug` build emits now names an enum's variants, not just its layout. An enum gains a `DW_TAG_enumeration_type` (the tag word's type, one enumerator per variant valued by the tag the constructor stores), a `DW_TAG_structure_type` for the value `{tag, payload}` and a `DW_TAG_typedef` for the enum itself, so `gdb` prints `{tag = Square, payload = 7}` by name. A sequence's `data` stays a pointer to the first element - an array type would have to state a length the header does not carry - which is what gives `print *values->data@values->len`. The variable's unused base-type fields are gone. Verified with `llvm-dwarfdump --verify`, `readelf --debug-dump=info` and a real `gdb --batch` session on a record, a nested record, a string, a vector, a C record and an enum tag, for x86-64 and the AArch64/RISC-V 64 units; Windows CodeView keeps its records, symbols and PDB (an enum's word maps to the integer it is). `tools/test-debug-lines.mjs` pins all of it; docs/tooling/debugging.md is the tested gdb/lldb recipe and says plainly that macOS Mach-O DWARF is not emitted and that the DAP adapter is a WIP that is not shippable this round.
- Fixed: a `byval` record whose last eightbyte is narrower than eight bytes — a 12-byte record, or
  a three-float aggregate — loaded that eightbyte with `movl ...,%rax`, which is not an instruction,
  so the generated assembly did not assemble. The load now matches the width. `tests/ffi/byval_records.grl`
  covers 12- and 40-byte records, a record returned by value while another arrives by value, and a
  callee that writes its own copy, on x86-64, AArch64, RISC-V 64 and (through `tests/windows-cases.json`)
  Windows x86-64 under Wine.
- Added: `grail bindgen HEADER.h -o OUT.grl`, a C header importer. It is a compiler module
  (`compiler/bindgen.grl`) with its own preprocessor - `#include` resolution through `-I`/`-isystem`,
  object-like and function-like macros with `##` pasting, `#if`/`#ifdef`/`#elif` with a C constant
  expression evaluator (`defined`, arithmetic, shifts, casts, `sizeof`/`_Alignof`, `?:`) - and a
  declaration parser for typedefs, structs, unions, enums, function declarations and `static inline`
  definitions. Output: `pub extern "C"` functions, C-layout records with `SIZE`/`ALIGN`/`OFFSET_<field>`
  constants, enum constants, and object-like macros that are integer constants. Constructs Grail
  cannot express (bit-fields, `packed`, `#pragma pack`, `long double`, `_Complex`, `__int128`,
  `_Atomic`, anonymous union members, multi-dimensional array members, `#error`) are refused with
  `file:line` and no output file; file-scope variables and function-like macros are reported and
  omitted, or refused under `--strict`. `-D`, `-l`, `-M lp64|llp64` and `--module` are supported.
  No libclang: nothing new links into the compiler or the seed. Verified by `bun tools/bindgen-test.mjs`
  (the committed binding for `tests/bindgen/fixture.h` regenerates byte for byte, its layout constants
  are compared with the C compiler's `sizeof`/`offsetof`, the real `<zlib.h>` binding calls a C `crc32`
  and returns `0xCBF43926`, and every refusal is asserted) and by the `cimp-fixture-layout` corpus case
  on every target.

- `grail fmt` no longer reads `i < (n >> 1)` as a generic argument list (it wrote `i<(n> > 1)`, which does not parse): a `>` met inside an open parenthesis or bracket closes no type arguments.

- Fixed: **a program that ran the main thread's stack out died with an empty stderr**. `f(100000000)`
  in a recursive function exited 139 (SIGSEGV) with nothing said, because the guard page and the
  `rt_stack_overflow` report belonged to task stacks and the main thread's stack is the kernel's -
  there is no page the runtime can make `PROT_NONE` there. The main thread now installs the same
  `SIGSEGV` handler on an alternate stack at startup (a 64 KiB mapping, its base in a process-state
  word of its own) and reports a fault as an overflow when the fault address is within 64 KiB below,
  or one page above, the interrupted stack pointer read out of `ucontext` - `error: stack overflow`,
  the statement the overflowing frame was entering as ` --> file:line:col`, and status 134 through
  the same one-reporter claim a task's overflow uses. Anything farther away restores `SIG_DFL` and
  returns, so a genuine wild pointer still dies by SIGSEGV with no report; recursion that ends
  normally is untouched, and a task's overflow still prints the same message. Nothing is allocated
  in the handler. `ucontext` offsets per target (`os-linux.grl`): x86-64 `sp` 160 / `pc` 168,
  aarch64 432 / 440, riscv64 192 / 176 - `offsetof()` against each target's own headers. A fault in
  a function's prologue, which the statement table marks positionless, is attributed to that
  function's first statement, verified through the function table. Cases
  `main-stack-overflow-reports-and-exits-134` (x86-64, aarch64, riscv64),
  `wild-pointer-dies-by-sigsegv-without-an-overflow-report` (x86-64) and
  `deep-recursion-that-ends-is-unaffected` (all three). docs/design/main-stack-overflow.md.

- Changed: the call-site table helper the compiler emits (`compiler/native.grl` `rt_sites`) and the
  runtime that calls it (`compiler/runtime.grl`) now carry their length instead of agreeing on fixed
  offsets. The signature is `words_written = rt_sites(out, capacity_words)`, and the descriptor is
  append-only - statement table start/end, the caller's frame, then the function table start/end - so
  the helper writes the longest prefix the capacity admits and returns how many words it wrote. The
  runtime asks once (`rt_sites_fill`), reads only that many, and **refuses** the descriptor when the
  count is smaller than a statement entry needs or larger than the capacity it offered, so a caller
  that reads first and believes afterwards is gone from this contract. A capacity of `0` means "this
  caller predates the argument" and is answered with the three words every runtime since the
  statement table existed has room for - the direction that must never break, because a checked-in
  seed's runtime calls `helper(scratch, 0)` on a 24-byte scratch and a five-word answer there *is*
  the 16-byte overrun into the following block's allocator header that the task-failure example
  tripped; an offer below three words writes nothing at all. `rt_backtrace` needs the last two words
  and answers no text when it was offered three, instead of walking a function table that is not
  there; `rt_site_here` (the containment path, which may not allocate), `rt_fail_where` and
  `rt_backtrace` all go through the one fill, so `words read <= words written` is checked in one
  place rather than assumed in three. The audit of the other `rt_*` handshakes found no second
  word-list: `host::*` `&[u8]` pairs carry a pointer *and* a length, `host::backtrace` returns an
  owned text it bounds itself, and everything else that crosses is a single process-state word or a
  NUL-terminated static the runtime only reads. Corpus: `rth-contained-then-joined` (the book's
  example with the join's site made observable), `rth-contained-then-joined-thrice` (the repeat run
  that caught the original overrun), `rth-offer-five-names-the-frame`, `rth-offer-three-still-names-
  the-statement` and `rth-offer-two-refuses-the-descriptor` - the last two drive the capacity through
  `GRAIL_RT_SITES_OFFER`, a test-only fault injection read once into process-state word 3408, which
  is how a buffer smaller than the helper writes is shown to be refused rather than corrupted.
  docs/design/runtime-abi.md, "What the compiler hands the runtime: a handshake that carries its
  length".
- Fixed: a repeated parameter name and a repeated method name are refused. `fn f(a: u64, a: u64)`
  bound `a` twice, so the first argument could never be read: `` `f` has two parameters named `a`:
  rename the second, the first can never be read``, caret on the second and a label on the first. A
  method declared twice on one type was reported as "declared twice in this module" with the caret
  past the signature; it now says ``this type already has a method named `get`: rename one, or
  remove it`` with the caret on the method name. One method name on two different types is still
  fine (`diagx-same-method-two-types`). Pinned by `diagx-dup-parameter`, `diagx-dup-method-on-type`.
- Fixed: an `extern "C"` callback cannot be generic. A lifetime parameter (`extern "C" fn cb<a>`) and
  a type parameter (`extern "C" fn cb<T>`) were both accepted and quietly ignored, emitting a
  function exported under a fixed symbol that C could not call: ``an `extern "C"` callback cannot
  take a type parameter: `T` has no C representation``, naming the parameter, with a help line
  offering the two ways out. Pinned by `diagx-extern-callback-type-parameter`,
  `diagx-extern-callback-lifetime-parameter`, and `diagx-extern-callback-plain-ok` as the guard that
  a concrete callback still compiles.
- Fixed: a Rust-style tick before a name is diagnosed instead of being read as a character literal.
  `extern "C" fn cb<'a>() -> &'a [u8]` used to abort the compiler on an assert; after the asserts
  were removed it became ``a character literal holds exactly one character: `'a>() -> &'` has more``,
  which is true of the token stream and useless to the reader. Grail lifetimes take no tick (`<a>`,
  `&a`), so a quote followed by a name now gets its own token and one message that names it and both
  readings: `` `'a` is not a character literal, and it does not close as one`` with ``for a character,
  close it (`'a'`); a lifetime takes no tick in Grail (`<'a>` is `<a>`, `&'a u64` is `&a u64`)``. A
  character literal that really is unfinished (`'ab'`, or a `'` at the end of the file) keeps its
  own message.
  Pinned by `diagx-tick-lifetime`, `diagx-char-literal-unclosed`, and
  `diagx-lifetime-parameters-ok` as the guard that `<a>` / `&a` still parse.
- Fixed: a duplicate declaration no longer compiles. Two `struct`/`enum` declarations under one
  name in a module, a repeated field in a record, a repeated variant in an enum, a second
  module-level `const`, and a `type` alias colliding with another alias or with a struct were all
  accepted, and the second one silently won: a duplicate field was laid out behind the first and
  could never be read through a `.name`. All of them are refused now, by a diagnostic that names
  where the first declaration is - `a struct named `P` is already declared at input.grl:1:8: rename
  one, or remove it` - and, for a repeated member, `` `P` has two fields named `x`: rename or remove
  the second, it can never be read`` with the caret on the second and a label on the first. `union`
  members are not declarations in Grail (`A | B` is a type) and were already refused; a `handle` and
  an `extern "C" record` share the type check. The first declaration's position is carried as
  `file:line:column` text because it can be in another file of the same module, where a token index
  means nothing. Pinned by `diagx-dup-struct-field`, `diagx-dup-enum-variant`,
  `diagx-dup-type-name`, `diagx-dup-type-across-files`, `diagx-dup-const`, `diagx-dup-alias`,
  `diagx-dup-alias-for-struct`, and `diagx-decl-distinct-members` as the guard that distinct names
  still compile.
- Fixed: the lexer no longer aborts on source it cannot scan. Six `assert`s on user input -
  `'ab'`, a character literal that never closes, an unterminated string, a raw control byte in a
  string - ended the compiler with `error: assertion failed` and a compiler source line
  (`compiler/lexer.grl:169`), which is a compiler bug by definition, not a refusal. The scanner now
  emits a token for what it could not finish (998 an ill-formed character literal, 996 an unclosed
  string, 995 a string holding a raw control byte) and the front end renders it where every other
  diagnostic is rendered: ``a character literal holds exactly one character: `'ab'` has more`` with a
  help line naming `'a'` and `"ab"`, `unclosed character literal: add the closing `'``, `unclosed
  string literal: add the closing `"``, and `a string literal cannot hold a raw tab: write the escape
  `\t` instead`. A literal newline inside a string is reported as the unclosed literal it means. The
  lexer module now has no `assert` at all. Pinned by `diagx-char-literal-too-long`,
  `diagx-char-literal-unclosed`, `diagx-string-literal-unclosed`,
  `diagx-string-raw-control-byte`, and `diagx-literal-escapes-ok` (escapes, an escaped backslash and
  a non-ASCII character still lex).
- Docs: docs/testing.md records what `--jobs N` changes about a case's working directory - it runs in
  `.work/native-tests/<target>/stripe-<i>-<n>/<case>`, one level deeper - and therefore why the five
  `lib-*` corpus cases that pass a relative `../../../../tests/lib/<name>` argument report `cannot
  read a corpus file` under `--jobs` and pass without it. A full run in jobs mode is green at
  `failed 5` with exactly those names.
- Diagnostics: the loop-backedge refusal names the value it refuses. `while i < 2 { consume(s) }`
  with an owned `s` printed `error: loop backedge consumes entry storage` under the closing brace of
  the *enclosing function* and said nothing about what was consumed or what to do. It now reads
  ``loop backedge consumes entry storage: `s` is moved out of it, so a second iteration would use a
  moved value``, with `` = help: copy it (`s.copy()`), borrow it (`view(s)`), or move it before the
  loop``, and the caret on the loop's own `}` (`compiler/ownership.grl` gained `consumed_entry` so the
  check can name the place it refuses). The `continue` edge names the value too. Pinned by
  `diagx-backedge-names-the-value`, `diagx-backedge-names-the-field`,
  `diagx-backedge-continue-names-the-value`.
- Fixed: `b.push(300)` on a `u8[]` was accepted and then aborted at run time with no message at all -
  the `push` path of a byte buffer was the one place with no literal range check, while `u8[300]` and
  `b[0] = 300` were already compile errors. A literal that does not fit is now refused, and the
  refusal names the value, the type, the range and the conversion: `error[E0015]: integer 300 is out
  of range for u8 (0..=255)` with `` = help: write a value that fits, or convert explicitly
  (`u8(x)`), which truncates and so says the narrowing is intended``. Silent truncation is the wrong
  default for a memory-safe language, and an unmessaged abort is not much better. A *value* wider
  than a byte (`b.push(n)`, `n: u64`) is still accepted and range-checked at run time, exactly as a
  byte store is, so a conversion is demanded only where the compiler can see the number. Pinned by
  `diagx-byte-push-literal-out-of-range` (refused) and `diagx-byte-push-wider-value` (accepted).
- Diagnostics: sixteen messages that named no entity now name one, and each has a reject case so it
  cannot regress. `integer literal out of range for its type` became E0015 ``integer 300 is out of
  range for u8 (0..=255)`` with the `u8(x)` fix - it named neither the value nor the type, and the
  reader had to count bytes. E0006 `use of moved, borrowed or partially initialized value` gained a
  clause that names the binding and which state it is in (moved, maybe moved, never assigned, not yet
  written) plus the fix. E0009 `mutation through readonly frame` names the binding that holds the
  shared borrow and how to ask for a writable one. `unknown function` / `unknown type` /
  `undefined name` / `duplicate function` name what they are about (`unknown function `lenght` in
  `main``, `unknown type `Widget``, `undefined name `totl``, ``` `f` is declared twice in this
  module: rename one, or remove it```), `unknown field or variant` says `` `P` has no field `y` ``
  (or `no variant`, for an enum), `unknown collection method` says `` `u64[]` has no method `lenght` ``,
  E0018 says ``wrong number of arguments: `f` takes 2, this call passes 1``, and
  `index/slice requires byte sequence/view` says `` `u64` cannot be indexed ``. Every parse error now
  names the token it found as well as the one it wanted (``expected `;`, found `}` ``,
  ``expected a name here, found `=` ``), and `unclosed {` labels the brace that was never closed
  instead of only the end of the file. `explain::code_of` learned the new spellings, so the codes
  (E0002, E0003, E0015, E0018) survive the rewording. Pinned by the `diagx-*` reject cases.
- docs/design/grail-container-ergonomics.md rewritten to what this tree actually does. The Abundance
  port note it replaced claimed nine container shapes; re-measured here, six are fixed (a function
  with seven or more parameters, `a[i].f = x` and `&v[i]` on nested vectors, rebinding a reference,
  `module::Type[]`, `f64(f32)` outside the entry module, `1..n` ranges) and are recorded with the
  corpus case that pins each, and three still hold (an owned aggregate consumed at a loop backedge -
  refused, Rust-compatible, and the message is now the finding; `if` as an expression, being fixed
  elsewhere; `u8[]` push of a word, refused by this round).
- Tooling: `tools/test-cli.mjs` stops leaking `grail check --watch` processes. The watch section
  started four watchers inside a bare block, so an assertion that threw before the section's own
  `stop()` calls left a watcher running against a tree with nothing left to read it - one ran for 100
  minutes, reparented to systemd once the runner exited. Every watcher the file starts is now
  registered, a `finally` kills whatever the case did not, `stop()` escalates to SIGKILL after ten
  seconds instead of hanging the suite on an ignored SIGINT, and a watcher that was still alive in
  that `finally` fails the case by name.
- Fixed: a contained task failure corrupted the allocator header of the block that followed the
  task record, so the scope exit aborted (`book/examples/task-failure.grl` printed `bad input` and
  exited 134 instead of printing its sibling's `7`). `rt_site_here` handed the compiler's `rt_sites`
  helper the record's 24-byte walk scratch, but the helper writes five words - both tables' bounds
  and the caller's frame - so its last two stores landed on the record's word 232 and word 240. The
  record is 240 bytes, and with the allocator's 16-byte block header that is exactly one 256-byte
  size class, so word 240 is the *next* block's size word, not padding. That block was free at the
  time and `rt_alloc_unlocked` writes a size only on the bump path, so the next 240-byte allocation
  was handed a record whose header read `__stop_grail_funcs`; `rt_free_unlocked` read that as a
  >= 512 KiB arena, did not find it in the arena list and aborted. The walk's scratch is now the
  record's words 200..240 - the five words the helper writes, inside the record - and the "these
  are already texts" flag moved to bit 0 of the site word (a table entry is 8-byte aligned in a
  24-byte stride, an allocation is more so), which keeps the record at 240 bytes and in its size
  class. `rt_site_here`'s contract now says its area is sized by what the helper writes, not by
  what the walk reads. Corpus: `tmem-contained-then-joined` (the book example's shape) and
  `tmem-contained-then-joined-thrice` (the same scope three times, so the overlapped block comes
  back from the free list); both abort 5 times out of 5 before this fix.
- Added: `grail check --watch` and `grail build --watch` - one driver process that re-runs the cycle
  when an input changes. The input set is the source named on the command line, or, for a project,
  the plan the package manager resolves from `grail.toml` and the lock - the entry plus every module
  `grail.lock` names, the root's and its dependencies' - with the manifest, the lock and a listing of
  `src/` polled so a new dependency, module or re-lock re-plans the next cycle. The standard modules
  the sources reach through `use` and every file in an `--interface DIR` are in the set too, and it
  is recomputed on every poll, so a new file or a new `use` is a change like any other. Change detection is a 128-bit content stamp (XXH64 with two
  seeds, `lib/xxhash.grl`), never a timestamp: a file written back unchanged is not a change, and a
  source restored with an old mtime still is. A burst of writes collapses into one cycle through a
  quiet period (120 ms, `--debounce MS`) over a 100 ms poll (`--interval MS`); the first cycle runs
  immediately, an error keeps the process alive, and each cycle prints its diagnostics followed by
  exactly one summary line - `check ok 24 ms`, `error 3 diagnostics 31 ms`, `built target/app 210
  ms`. No lock is held between cycles, so a concurrent `grail build` in the same directory runs
  while the process waits. `--json` makes a cycle one JSON object per line (`cycle`, `status`, `ms`,
  `output` for a build, and a `diagnostics` array of `{file, line, col, code, message}`), which is
  the seam an editor or the language server reads (the LSP now does, instead of parsing the caret
  block); the fields come from a new structured-diagnostics
  channel - `--diagnostics-json FILE`, written at the one place a diagnostic is built, carrying
  `file`, `line`, `col`, `col_end` (the width of the token it points at), `code`, `message` and the
  caret form as `rendered`, and exposed to any driver as `grail check --diagnostics-json FILE`, which
  prints nothing and reports only through the exit status - so nothing parses printed text. `--watch` is refused on
  `run`/`test` and `--cache` is refused with it, since a cache hit is a cycle that does not run the
  compiler. Limit, stated with its reason: the runtime installs no SIGINT/SIGTERM handler and a new
  `host::` builtin cannot land from this branch (the published bootstrap compiler would not know
  it), so a watch process ends on the signal with the shell status 130/143 rather than the last
  cycle's; the last cycle's status is in the summary line and in `--json`. Design and the
  rejected alternatives: `docs/design/incremental-compilation.md`, watch mode. Book: *Building
  modules: the work a build can skip* in *Modules*. Tests: a watch section in
  `tools/test-cli.mjs`, since the behaviour is a process loop.
- Fixed: the debug tables named local labels by number alone (`.L<n>`), but a label is minted in
  its unit's namespace (`.L<unit>_<n>`, the separate-compilation change), so a `--debug` build whose
  program spans more than one unit asked the assembler to subtract a label no unit had emitted
  (`symbol '.L5021' can not be undefined in a subtraction expression`). DWARF's compile-unit range
  and subprogram ranges and CodeView's function ranges and `.cv_linetable` directives now spell the
  label through the function's own unit; `DebugFunc` records the unit it was emitted in. Found by
  merging the backtrace tables (`grail_funcs`) with per-module label namespaces; no single branch had
  it.
- Fixed: the compiler's "no type" is a real sentinel instead of type id 0, which is u64. A type is an index into the interned type table and id 0 is u64 (1 unit, 2 bytes, 3 string, 4 view), so every "no type" answer used to collide with a real type and needed a second `found`/`any`/`set` flag beside the id; any site that forgot the flag read "no type" as an integer. The no-type answer is now `NO_TYPE` (`compiler/native.grl`), one value above any id a table can hold, so the id itself says whether there is a type: the `found`/`any` pair in `assoc_type`, `impl_params.self_ty`'s "0 means not built yet" and `c.self_type`'s `+1` offset are gone, and `type_args`/`ty_kind`/`ty_arg`/`ty_mode`/`ty_env`/`type_regions`/`ct_seq_elem` refuse a sentinel with a diagnostic instead of indexing the table with it. Two user-visible bugs the collision caused, both fixed: `type Word = u64;` could not be named as `module::Word` (the u64 id read as "unresolved alias", `recursive or unresolved type alias`), and a recursive alias used qualified (`type A = probe::A;`) crashed the compiler with `index 18446744073709551615 out of bounds` instead of naming the alias. Corpus: `sentinel-qualified-u64-alias`, `sentinel-qualified-recursive-alias`, `sentinel-u64-self-impl` (an `impl` for u64, whose `Self` is type id 0) and `sentinel-untyped-closure-reject`.
- Changed: the refinement prover keeps its facts as the body is compiled instead of re-reading the
  tokens from the body's `{` to each check (`docs/design/refinements.md`). Every fact now belongs to
  the structure that stated it, which is what makes a `match` arm's pattern (`16 =>` states
  `n == 16`, `0..16` states both bounds), a `match` guard, a shadowing binding and a `for` guard
  exact: an arm's facts reach that arm's body and no sibling arm or code after the match, a
  shadowing binding kills the facts about the name it shadows for its own block and the outer ones
  come back when it closes, and `for i in a..b` / `for i in v.len()` state their bound inside the
  body and stop at its `}`. Writes are never restored (a path may have taken them), bindings are
  (the outer value was never written), and a statement that calls forgets the names it mentions. The
  old token walk is removed; the switch was measured on the corpus first - 41 check sites with it,
  41 with the walk over the IR, and seven new `pv-` cases prove calls the token walk could not.
- Added: a standard error interface, owned context chains and captured stacks for returned errors. `lib/errs.grl` gives the stdlib an error layer that fits `?`: `errs::Report` is one owned value holding the root message, the context frames each layer added, a typed `io::Error` origin and - when the caller asks - the stack where it was created. `errs::report(text)` allocates one value and captures nothing, `errs::traced(text)` captures the stack at that point, `errs::from_os(error, what)` is the explicit conversion from a stdlib failure (there is no implicit `From`), and `r.context(text)` consumes the report and returns it with one more frame, so the chain is built by reassignment and every frame is owned. `show()` is the deterministic one-line chain, outermost context first and the cause last (`while loading app: while parsing config: while opening /x: not found`), `to_stderr()` prints it followed by the captured stack, and `depth()`, `frame(i)`, `cause()` and `origin()` walk it. `errs::Error` is the interface - one `message` method - implemented by `errs::Report`, `errs::Message` and `io::Error`; `errs::Message` is the message-carrying record a program's own error type takes. The capture itself is the native runtime's: `host::backtrace()` walks the frame-pointer chain exactly as a failed check's report does, and `site_table` now also emits a per-function range table (`grail_funcs`, name 0 for the runtime's own functions) whose bounds the `rt_sites` helper fills beside the statement table's, so every frame line names its function and its call site. Frames in the runtime, in libc, or in a prologue the table cannot name are left out, and a build that carries no tables (macOS, the LLVM backend, `--debug`, `--split`) captures nothing and prints the message alone instead of a stack it would have had to guess. Two fixes fell out: the runtime's message writers no longer take an owned literal that a caller which survives its own report would leak (`rt_backtrace` writes its punctuation a byte at a time), and `module::Type::method(...)` resolves to the type's own function, as the unqualified spelling already did, instead of a variant constructor of the same name. Corpus: `err-message-and-context-chain`, `err-backtrace-on-returned-error`, `err-backtrace-absent-without-tables`, `err-question-mark-two-layers`, `err-chain-drop-releases-every-frame` (two thousand chains built, returned and dropped - the runtime aborts a double free and its entry shim aborts a leak), and `err-qualified-type-method`. Book: *A standard error value* in *Enums, match and early exits*, with the `errs` example and its Rust comparison, and an *Errors* section in *The standard library*; design: `docs/design/standard-errors.md`.

- Changed: `@no_alloc` and `@no_panic` are proved from the call graph the front end records, not by reading the emitted assembly back. Every direct call is recorded where it is emitted, with the callee's linker symbol (runtime entries and drop helpers included); an indirect call in user code is recorded as unknown and counts as both; a refined parameter's check in the checked entry is an entry fact, not an edge. The compiler's own dispatch (`call_dispatch_out`) is not an unknown, and a `dyn` value's drop through a vtable's first word is resolved to the drop helper of every concrete type whose vtable this build recorded, so a `Drop` reached through dispatch is followed. A prover-removed check is never in the graph, because it is never emitted.
- Fixed: a generic's effect claim was never checked. The claim sat on the template's symbol, which has no body, so `@no_alloc` on a generic with an allocating instantiation was silently accepted. One record per emitted body now means each instantiation is judged separately - an allocating instance does not mark a quiet one - and the refusal names the instance (`store_one<Loud>`).
- Corpus: `fx-effects-specialization-per-instance`, `fx-effects-generic-claim-refused`, `fx-effects-drop-glue-dyn-refused`, `fx-effects-drop-glue-accepted`, `fx-effects-indirect-call-refused`, `fx-effects-prover-removed-check`. See docs/design/effects.md.
- Optimizer: a frame slot is no longer always one word. The emitter declares a borrowed interface object's `{data, vtable}` pair with a `.gpair -N(%rbp)` line, and the word optimizer carries a slot of width 2 the way it carried width 1: both words are one value for promotion, forwarding and dead-store elimination (neither is promoted, neither is forwarded, neither store is deleted), the frame compaction reserves both and keeps them adjacent and in order so the handle still names word 0 with the vtable eight bytes above it, and `.gpair ret` keeps the second result word (`%rdx`) live at the return. The opt-out that sent every function building a `&dyn` pair down the copy-unchanged path - an unaligned frame operand the optimizer treated as unrecognized, added with borrowed interface objects - is gone, and the pair is now emitted as two direct frame stores plus the pair's address instead of two stores through a computed pointer. A function that builds, copies, passes or returns a `&dyn` pair is optimized again, which is where dynamic dispatch lives: `main` of the borrowed-object case drops from 588 to 392 instructions, the loop case from 408 to 313, and 20M iterations of building a pair and dispatching through it go from 308 ms to 131 ms (2.4x). The LLVM backend lowers a declared pair as one `[2 x i64]` alloca, so neither word is a separate object whose store it could drop; pair-free functions are untouched - all five `bench/` programs still emit byte-identical assembly. Docs: `compiler/NATIVE.md` *Optimization* and `docs/design/llvm-backend.md`; corpus: `opt2-dyn-pair-loop`, `opt2-dyn-pair-optimized` (a promotion pin and the absence of the old opt-out).
- Fixed: a function's frame constant could name another function's frame. `.F<label>` was one `.set` symbol per assembly file, so when two functions were minted the same frame number the last `.set` in the file decided both functions' displacements - a silent miscompile in the single-file shape, and in `--split` a `.text` difference between the split and single builds for a generic-heavy program (which is how `tools/split-test.mjs` caught it). Frame constants are now named per emission unit (`.F<unit>_<n>`) like every other label.
- Changed: a module's emitted assembly no longer depends on what was emitted before it. Local labels are minted per module (`.L<module>_<hash>_<n>`), the optimizer's own expansion labels and the refinement strings are namespaced with them, and inlining stays inside one module - a body is only copied into a caller that emits it. The build cache now measures an edit in the entry module of a five-module program as 5 hit / 1 miss with the other parts' assembly byte-identical, where it used to miss all six; `tools/cache-test.mjs` requires that. See `docs/design/separate-compilation.md` (stage 5).
- Tooling: `tools/cache-test.mjs` prints edit cost - wall clock and the exact module runs each edit redid for four edits (a leaf module's body, a body-only edit whose interface surface is unchanged, an interface edit, and one function of a 400-function module), each ending in a byte comparison against the same build made without the cache; `--big` swaps in a 2000-function module. `tools/split-test.mjs` runs its cross-target leg before the example that replaces the entry source, which is the program that leg asserts.
- Verified and pinned: an interface object behind a shared pointer - `Rc<dyn I>` and `Arc<dyn I>` - works end to end on this branch (construction through the typed-binding cast form, `rc::new<dyn I>(x)`, method dispatch through the vtable, `clone` keeping the value alive, and the concrete destructor running once when the last handle goes), with corpus cases for a record with `impl Drop` behind `Rc<dyn I>`, two clones keeping it alive until the last drop, a `Weak`, an `Rc<dyn I>` record field and `Arc<dyn I>`. The cross-thread rule is checked and now stated: a `dyn` object is neither transferable nor shareable (its concrete type is unknown there), so `Rc<dyn I>` and `Arc<dyn I>` are local handles and passing either to a worker is refused by name (`ergo-rc-dyn-reject-cross-thread`, `ergo-arc-dyn-reject-not-shared`). Not supported, and documented rather than changed: `r: Rc<dyn I> = rc::new(Rect { .. })` (generic inference does not seed `T` from the expected result type - write the object through a typed binding or the type argument), and storing a borrowed `&dyn I` in `Rc` (the pre-existing owned-container borrow-escape hole, which admits `Rc<&a u64>` too). Reasoning in docs/design/dyn-shared-pointers.md; book: *Shared ownership* in *Cleanup and boundaries*; corpus: `ergo-rc-dyn-*`, `ergo-arc-dyn-*`.
- Ergonomics: an immediately invoked closure takes its parameter types from the call (`(|x| x + 1)(41)`, `(|p| p.x)(Point { x: 2 })`, `(|x| x + 1)(n)` with a `u32` `n`), joining the argument-position and typed-binding inference that already existed. The arguments are typed ahead of the closure by compiling each in isolation with the enclosing locals bound, and only the parameter types are kept; the result still comes from the body. An argument that is itself a closure, or one whose parameter type would hold a borrow, is not inferred (a reference parameter needs the closure's own input lifetime): the diagnostic now names the parameter and repeats it in the suggestion, "closure parameter `x` needs a type here (nothing fixes it): write |x: T|". Fixed on the way: a record literal compiled in isolation for inference (`constructor_hint` reading `c.result`) aborted the compiler when nothing was being returned. Reasoning in docs/design/closures.md; book: *Closures*; corpus: `ergo-closure-infer-*`.
- Ergonomics: a `match` arm body may be a single expression (`0 => println("zero"),`) as well as a block. Both spellings compile to the same code - the expression's temporaries are released at the arm's end and an owned value it produces is dropped there - and the trailing-comma rule is the same for every arm (the last arm may omit it). The shapes that used to be ambiguous are refused by name: `Pat => if ...` reports that a statement body needs braces, and `Pat => x = 1` / `Pat => println(x);` report that an arm body is one expression, not a statement. A record literal needs no parentheses in an arm (`_ => P { x: 1 }`), unlike Rust's rule for control-flow headers, because the arm body begins where no block can. Formatter round-trips unchanged. Reasoning in docs/design/match-expression-arms.md; book: *Enums, match and early exits* and the cheatsheet; corpus: `ergo-match-expr-arm-*`.
- Ergonomics: a string literal bound with `mut` is Rust's `let mut s = "x"` rule, and the diagnostics now say so. `mut s = "x"; s = "y";` reassigns the binding; writing `s[0] = 65` or taking `&mut s[0]` is refused because a string literal is read-only text, and the refusal names that reason and points at `s.copy()` for a mutable byte vector (previously the statement form said only "index assignment needs a vector, bytes or a mutable byte view"). Reasoning in docs/design/owned-text.md, *Mutability of a binding that holds text*; book: *Bindings* and *Bytes and text*; corpus: `ergo-mut-string-literal-*`.
- Added: task-level failure containment. A green task that fails a runtime check - an out-of-bounds index, a checked overflow, a division by zero, `!` on a failed `Option`/`Result`, a failed refinement, `assert` - or that calls the new `task_fail(text)` no longer ends the process. The failure is contained at the task's own top frame: the check kind, its operands and the failing statement's site-table entry are written into the task record (**nothing is allocated there**, so a trap cannot deadlock on the allocator lock), the task is marked finished and control returns to the scheduler, which takes its ordinary completion path. The task's stack is discarded whole - no frame is unwound, no destructor runs and nothing crosses a C frame, which is B5's rule applied to one task instead of the process. `try_join(handle)` is the containing join: it returns `R |? TaskFailure` (the language's result union, so `?` and match arms work unchanged) and never aborts, where `join(handle)` keeps its "must have succeeded" meaning and reports the recorded failure at the join - still status 134 with one reporter at the top of a program. `TaskFailure` carries the check's `kind`, its `message` and the `site` of the failing statement. The compiler refuses to drop an outcome that was never looked at - `try_join(t);` and an unused binding are compile errors - and `ignore_failure(...)` is the explicit opt-out. Decided semantics: a failed task produces no placeholder result; its children are not cancelled (they finish and keep their own outcomes, and cancellation stays what `scope.cancel()` asks for); an abandoned handle whose task failed re-raises at the scope exit, contained by the enclosing task or fatal at the top; `rt_abort` sites (allocator invariants, stack overflow, the end-of-main leak check) and the opt-in `GRAIL_TASKS=thread` scheduler are never contained. Accepted cost, stated rather than hidden: the discarded stack's owned heap values leak (the stack mapping itself is recycled), and because no exact count of them can exist the end-of-main leak check prints `note: N allocation(s) still live after M contained task failure(s)` on fd 2 and exits normally once a failure was contained, while a program that contained nothing still aborts on a leak. Design and the full semantics catalogue: `docs/design/task-failure-containment.md`, decision B5a in `docs/design/decisions-b2-b6.md`. Book: *A failed task is a value* in *Threads, atomics and mutexes*; corpus: the six `tfail-` cases.
- Added: `socket`, TCP and UDP over IPv4 and IPv6 (`lib/socket.grl`) - the AF_INET6 half the runtime's `net` does not have. `bind(addr, port, v6_only)` is the dual-stack switch (`IPV6_V6ONLY` over an `AF_INET6` socket): a listener on `::` without it accepts an IPv4 peer, which `peer()` then reports as `::ffff:127.0.0.1` (and `ip::Ipv6::ipv4_mapped` unwraps). `connect`, `accept`, `read`, `read_all`, `write_all`, `peer`, `local`, `close` are the stream side; `datagram`/`bound_datagram`/`send_to`/`recv_packet` the UDP side, where a packet carries its sender. Addresses go on and off the wire through `sockaddr_in`/`sockaddr_in6` (28 bytes, `AF_INET6`, the address and the zone as the scope id), encoded and decoded in this module rather than through a C struct. Every socket is non-blocking (SOCK_NONBLOCK|SOCK_CLOEXEC) and every wait is `poll` in one-millisecond slices with a deadline, so a waiting task suspends through `host::sleep_ms` and the other tasks keep running; reads and writes go through `host::read_fd`/`host::write_fd`, which suspend on a foreign descriptor just as on one the runtime made. Because the layer is libc's (`extern "C" lib "c"`, `__errno_location` for the error code), a program using it is linked against `-lc`: it builds where the host's libc is available and not in a static cross build, so the corpus cases carry `"targets": ["x86_64"]`. Corpus: `stdmap-ipv6-sockets` (an echo over `::1` with both ends' addresses, an IPv4 client of a dual-stack listener seen as a mapped address, the same listener with `v6_only` refusing it, and the refused-connection and bad-port errors).
- Added: `dns`, a stub resolver over the wire format (`lib/dns.grl`). `encode_query` writes a header and a question; `parse_response` reads the header, the questions and the answer records, following name-compression pointers only when they point strictly backwards and only MAX_POINTERS times, so a loop is `Error::Malformed` instead of a hang. `Resolver`/`configured()` read the `nameserver` lines of `/etc/resolv.conf` (port 53, one second) and `with_servers` takes explicit ones; `resolve_all` asks for A then AAAA, which is the order a default `getaddrinfo` returns, and `resolve4`/`resolve6` ask one family. A second nameserver is tried when the first times out or answers with a mangled message, a truncated (TC) answer is repeated over TCP with RFC 1035's two-byte framing, a numeric name answers itself without a query, and the errors are `NoNameServer`, `NxDomain`, `Timeout`, `Malformed`, `ServerFailure(code)`, `NoAddress` and `Transport`, each with `show()`. Corpus: `stdmap-dns-wire` (the encoder's bytes against a query a real client sent, and a real 61-byte answer with a compression pointer parsed back to its two addresses) and `stdmap-dns-stub-resolver` (a stub nameserver started as a task on a loopback port: A-then-AAAA resolution, per-family lookups, NXDOMAIN, a silent server timing out, a TC answer answered over TCP, and the literal/empty-config paths). Book: *Addresses, IPv6 and DNS* in *The standard library*.
- Added: `ip`, the address module (`lib/ip.grl`). `Ipv4` is the 32 bits as one word and `Ipv6` the 128 bits as two plus the numeric zone of `%N`; parsing accepts what `inet_pton` accepts (`::` compression, an embedded dotted-quad tail, zones), and formatting is RFC 5952's canonical text - lowercase hex, no leading zeros in a group, the longest run of two or more zero groups compressed to `::` (the first such run on a tie, and never a single group), an IPv4-mapped address written `::ffff:a.b.c.d`, and the zone appended. `Ipv6::scope()`/`Scope::name()` classify unspecified, loopback, link-local (`fe80::/10`), unique-local (`fc00::/7`), multicast (`ff00::/8`) and global, and `is_ipv4_mapped`/`ipv4_mapped`/`ipv6_from_ipv4` are the IPv4 bridge. `Ip` is one address of either family - what resolution answers and a socket connects to - with `family()`, `is_loopback()` and `format`. `Ipv4` and `Ipv6` implement `order::Ord`, `hash::Equal` and `hash::Hash`, so an address sorts and can key a map. Corpus: `stdmap-ipv6-forms` (40 texts whose canonical form or rejection was cross-checked against Python's `ipaddress`) and `stdmap-ipv6-scope-and-v4` (scope names, the IPv4-mapped round trip, zones, `Ip` of both families and the refused texts).
- Added: `btree::BTreeMap<K, V>`, the ordered map (`lib/btree.grl`). A B-tree of order 8 keyed by the `order::Ord` interface, so any key with an implementation - the numbers, `string`, `u8[]` - orders by comparison and nothing needs a hash. `insert` is the upsert (a stored key is never replaced, the value is; it answers the old value), `get_or_insert` places a value only when the key is absent, and `len`, `is_empty`, `contains_key`, `get`, `get_mut`, `remove`, `clear`, `first` and `last` are the rest of the API. `iter()` walks every pair smallest key first and `range(lo, hi)` walks the pairs with `lo <= key < hi`; both hand out `(&K, &V)` and borrow the map for the walk, and both are O(1) a pair after an O(log n) start (a `Cursor`/`Range` record with the iterator protocol, so `for pair in map.iter()` works). Every operation is O(log n) node visits, each a binary search over at most seven keys, and a lookup allocates nothing: nodes live in one vector and refer to their children by index. Deletion keeps the tree balanced by lending a key from a sibling or merging two nodes; a merged node - and the root a collapse empties - goes on a free list the next split reuses, so repeated growth and shrinkage recycles storage, and `nodes_used()`/`shrink()` report and rebuild the arena when a burst of removals leaves it larger than the pairs need. Corpus: `stdmap-btree-model-1000` (1000 shuffled keys against a sorted reference model, then 500 removals, a range window, and removal to empty), `stdmap-btree-keys-and-edges` (`string` keys, byte order, range on text, empty map and single-key edges) and `stdmap-btree-stress-and-shrink` (3000 interleaved inserts and removals checked against the model after every step, then `shrink`). Book: *Ordered maps* in *Collections*.
- Added: hover, completion and rename in the Grail language server, answered from the open buffers (`tools/lsp/analysis.grl`) over LSP 3.17. Hover: the type of an identifier, field, call result or literal; a call's signature plus the `///` documentation above its declaration; a field's declared type and the record it belongs to; an enum variant. Completion: keywords and built-in types, the bindings in scope with correct shadowing, a record's fields and `impl` methods after `.`, an enum's variants after `Type.`, a call's parameters after `name(`, each with a `kind`, a `detail` and a `sortText` that ranks parameters, locals, fields, functions and keywords in that order. Rename and `prepareRename`: a local, a `for` binding, a parameter, a module-level function, record, enum, type alias, constant and record field, across every open document, honouring per-file scopes and shadowing - a shadowing binding's uses are never touched, nor a same-named field of another record, nor text inside a string or comment. Refused with `-32001` and a reason: keywords, `self`, builtins, `extern "C"` declarations, enum variants, methods, and modules whose source is not open; a name that is not an identifier as `newName` is `-32602`. Every position is converted between UTF-16 code units (LSP) and byte offsets (Grail) exactly, so a line with non-ASCII text - an emoji, an accented letter - maps correctly, and a malformed position is an LSP error instead of a crash. The server's own tolerant scanner replaces the strict lexer for these requests, so a buffer halfway through a string literal no longer aborts the session; and the diagnostics parser now reads the format the compiler prints today (`error[CODE]:`, ` --> file:line:column`, carets for the token's width), so a compiler error is published again and its range covers the token it underlined. Editor support: the VS Code extension registers hover, completion and rename providers. Docs: docs/tooling/lsp.md, editors/README.md.
- Added: a package manager. `grail.toml` (`[package]` name/version/`grl-version`/`entry`, `[dependencies]` with registry requirements and `path`/`git` sources, optional `[dev-dependencies]`, `[registry] index`) replaces the three-line `grail.pkg` manifest, which is deleted with its loader, `grail add NAME URL` and the `.grail/deps` checkout directory. Semver resolution assigns one version per package name (module identity is the module name), picks the highest version that satisfies every requirement, prefers what `grail.lock` already chose, and reports a conflict by naming both requirements and both requirers instead of backtracking. `grail.lock` is deterministic JSON: exact versions, sources, git commits, tarball and tree checksums, and the resolved edges. Packages live in a content-addressed store (`$GRAIL_PKG_STORE`, `$GRAIL_HOME/cache/pkg`, `$XDG_CACHE_HOME/grail/pkg`, `~/.cache/grail/pkg`) that every build re-hashes against the lock, so a tampered tree is refused rather than compiled. `grail add NAME[@REQ]`, `--path DIR`, `--git URL --rev/--tag/--branch`, `grail remove`, `grail update`, `grail fetch [--force]`, `grail tree`, and `--offline` for add/update/fetch; `grail build`, `check`, `run` and `test` read the lock and never resolve or network. The registry is a static git index (one file per package, one JSON line per version, `config.json` `dl` template, sha256 of the tarball). `grail new` writes `grail.toml`, `grail version` reads the version from one place, and `grail install` (a stub alias for `fetch`) is gone. Documented in the book (*Packages and dependencies*) and `docs/packages.md`; design in `docs/design/package-manager.md`; end-to-end suite `tools/pkg-test.mjs`; corpus: `pkg-*` cases (TOML subset, semver, requirements, resolver, manifest, lockfile JSON, SHA-256).
- Added: `lib/fs` grew the file-system surface a program actually needs, on seven new runtime
  operations (`stat`, `rename`, `symlink`, `spawn` with redirected stdio, `wait`, `ready` and `cwd` -
  newfstatat/renameat/symlinkat/ppoll, `MoveFileExA`/`CreateSymbolicLinkA`/`WaitForSingleObject`,
  and the Darwin equivalents). `fs::Error` now names the path and the reason (`tree/one.txt: not
  found`) and every operation answers one instead of stopping: `Path` with join/normalize/canonicalize
  (lexical, no file needs to exist), parent/file_name/extension/file_stem and Windows-aware
  `is_absolute`; `Metadata` with size, kind, mode, `time::Timestamp` mtime/atime, owner and
  inode/device; `read_text` refuses bytes that are not UTF-8 with the offset (`io::Error::InvalidUtf8`);
  `write_atomic` (temporary file beside the destination, then rename); `create_dir`/`create_dir_all`;
  `remove_dir_all`; sorted `list_dir`/`read_dir`; `walk` with a symbolic-link policy that is explicit
  (`walk_options()`, `follow_links`, `max_depth`) and cycle-safe by device and inode; `rename` and
  `copy` with their overwrite rules documented; `symlink`; and a `File` handle whose `close` is
  explicit, whose double close is `EBADF` and whose short write is `ShortWrite`. `lib/process` adds
  `spawn`/`spawn_with` from an argv vector (never a shell), `Child::wait` (consuming the child), a
  `Status` of `Exited(code)`/`Signaled(signal)` with signal names, `run`/`run_with`/`run_in` which
  capture stdout and stderr separately up to a size cap, an `Environment` with get/set/remove/all
  whose names are case-insensitive on Windows, and `current_dir`/`executable`. Both were exercised on
  a real temporary tree, on children that exit non-zero and on one killed by `SIGKILL`, and on a path
  holding spaces and non-ASCII text (`fsx-*` cases). Book: *The standard library* gains *Files*,
  *Processes*; mechanism: `docs/design/stdlib-utilities.md`.
- Added: `lib/tz`, time zones from the system's tzdata. `TimeZone` parses TZif v1, v2 and v3 (the
  64-bit table when a file has one, the POSIX `TZ` footer for every time after the last recorded
  transition, leap-second records read past on purpose because `time::Timestamp` counts POSIX
  seconds) and answers `offset_at`, `abbreviation_at`, `is_dst_at`, `to_local` and `from_local`.
  `load(name)` reads `$TZDIR` or `/usr/share/zoneinfo` and refuses a name that is not a relative path
  of ordinary components. A wall-clock reading is not always a unique instant, and the ambiguity is
  data: `Unique(instant)`, `Ambiguous(earlier, later)` or `Skipped(gap start, gap seconds)`, the last
  one also for a gap the footer rule creates. `parse` takes bytes, so a zone can come from anywhere;
  `parse_posix` reads a rule string on its own. `time` gained `Timestamp`, `DateTime` and their UTC
  calendar conversion. Cases: `tz-*`, including a TZif file built in the test itself and the
  machine's Europe/Berlin and Australia/Lord_Howe (its thirty-minute saving) skipped cleanly where
  the machine has no tzdata.
- Added: `lib/utf8`, validated text. `Utf8String`'s invariant is "valid UTF-8"; `from_bytes` is the
  checked constructor and answers the offset of the first ill-formed sequence, `from_text` takes the
  language's owned text, and `unsafe fn from_unchecked` is the escape hatch a caller must open an
  `unsafe` block for. `concat`, `slice_chars` (checked character boundaries), `replace` and
  `to_ascii_upper`/`to_ascii_lower` cannot produce invalid UTF-8; `to_upper`/`to_lower` refuse text
  with a code point above U+007F rather than half-mapping it; `chars`/`char_indices` decode without
  substituting U+FFFD, and `as_bytes` hands the bytes out as a view without copying. The invariant is
  pinned by a seeded 10,000-mutation fuzz case that re-validates every accepted value
  (`utf8-fuzz-construction-invariant`). Book: *Bytes and text* says why this type exists beside the
  byte-slice string.
- Fixed: the runtime's host operations take ownership of a byte-view argument, and the new file and
  process operations were not releasing it: every `fs::metadata` call leaked a block, which the
  entry-time allocation check reports as exit status 134 after a program has finished its work.
  `stat`, `rename` and `symlink` now free the view they are handed, as `open` and `list_dir` already
  did. `host::pipe` also exists on Windows now (CreatePipe), so a captured child works there.
- Fixed: seven corpus cases listed `lib/strings.grl` without `lib/iter.grl`, which its `chars`
  signature needs, and `lib/fs.grl` gained `lib/time.grl`/`lib/strings.grl`/`lib/iter.grl` as
  dependencies; the case lists follow.
- Added: `@derive(Eq, Ord, Hash, Clone, Debug)` on a `struct` or an `enum`, generated with the comptime `@for` over the type's fields and variants (docs/design/derives.md, book *Methods*). There is no macro system: the compiler renders fixed Grail source for the derives asked for, appends it to the file's own text and parses it as ordinary items, so a derived method is checked, borrowed and dropped like a hand-written one - and `--show-derives` prints what each `@derive` generated. The derives are the standard library's own interfaces: `ops::Eq` (`==`), `order::Ord` (lexicographic over the fields and, for an enum, over the variants in declaration order), `hash::Hash` (the fields written into one `hash::Hasher` in order, a variant index first, which agrees with `Eq`), a new `clone::Clone` (`lib/clone.grl`, field-wise and refused for a borrowed view) and a new `debug::Debug` (`lib/debug.grl`, `Point { x: 1, y: 2 }` / `Circle(2)`), which also installs the inherent `show` that `println` and `format` already call. Partial derives work (`@derive(Clone, Debug)`), a generic type derives per specialisation (the header repeats the declaration's parameters and adds the interface as a bound on the parameters a field mentions), and a field it cannot handle is named with its type rather than skipped (`field `right` of type `&u64`: a borrowed view cannot be deep-cloned`). Refused: an unknown derive name, a derive listed twice, `@derive` before anything but a struct or an enum, a type with no fields or variants, `Ord` on a field with no total order, `Hash` on `f64`, and a field or variant payload without the implementation the derive needs. Corpus: `derives-eq-record`, `-ord-record`, `-hash-record`, `-clone-record`, `-debug-record`, the same five on enums, `derives-generic-record`, `derives-nested`, `derives-partial`, `derives-show-derives` and the `derives-reject-*` set.
- Fixed: an interface method declared `-> Self` lost the specialisation's identity for its receiver. When a generic body specialised its type parameter (`T` = `u64`) and called such a method, the result was typed as the concrete type instead of the parameter, so `v.rebuild().rebuild()` or a cloned field refused to fit back into the parameter's own field, and a value produced that way carried no ownership record. The concrete type is still what finds the implementation, but a `Self` result now types as the parameter again (one layout, one word) and its drop record is added when the implementation's type has none. Corpus: `interface-self-result-in-generic`.
- Fixed: `--backend=llvm` no longer emits the refinement prover's `<sym>.proved` entry, whose copied prologue is written in frame-symbol arithmetic (`subq $.F7,%rsp`) the lifter does not model - the assembly did not assemble (`expected relocatable expression`), and no effect could be discharged from a call whose entry did not exist. An LLVM build now proves nothing at a call site and refuses an effect that the proof alone would have satisfied (`@no_panic` function `pick` can fail`), instead of discharging it and then leaving the check in; the native backend is unchanged, and `effects-accepted` is a native-backend case.
- Fixed: `bun tools/bootstrap.mjs stage ARCH` no longer requires the published manifest to describe the current sources. Splitting a reseed into `stage` and `publish` left the old `verify`-only manifest comparison on a bare `else`, so every `stage` run ended in `bootstrap source manifest is stale` - exactly the case a reseed exists for, and `tools/gate.sh --reseed` stopped at its first target after the self-hosting check had already passed. The comparison now runs only for `verify`; `bun tools/ci.mjs lint` pins the guard.
- Tooling: `bootstrap.mjs stage ARCH` and `bootstrap.mjs publish` split a reseed into one step per target plus a publish that requires every seed to come from the current sources, and `tools/gate.sh --reseed` uses them, so an interrupted gate resumes at the target it stopped on rather than redoing an up-to-90-minute reseed.
- Added: borrowed interface objects - `&dyn I` and `&mut dyn I` of a value that stays where it is, with no allocation (Rust's `&dyn Trait`). `&x` and `&mut x` become one at a typed binding, an argument and a return when `T` implements `I`, and a reference to an owned `dyn I` converts too. The value is a pair {data, vtable} written into the frame that borrows it, so the object never moves and nothing is allocated; a method call dispatches through that pair exactly as an owned `dyn I` dispatches through its cell, and a `&mut dyn` method mutates the original. The lifetime rules are `&T`'s: the value cannot be moved or dropped while the borrow lives, and a `&dyn` borrowed from a local cannot be returned (`returned borrow escapes its declared input lifetime`) while one borrowed from an input can. Records, vectors of borrowed objects (`(&dyn I)[]`) and generic code hold them; interface files carry the form as `(bobj (dyn ...))`. A function that builds one is optimized like any other: the pair is a two-word value the word optimizer models (see *Optimizer* below). Book: *Borrowing an object* in *Generics*; corpus: `dyn-borrowed-objects`, `dyn-borrowed-no-alloc` (an `@no_alloc` builder and a static-vtable pin), `dyn-borrowed-interface-form`, and `dyn-borrowed-reject-move`/`-escape`/`-not-implemented`.
- Added: an M:N green-task scheduler. One worker per CPU (Windows included), per-worker Chase-Lev deques with work stealing, a shared injection ring for spawns and wakeups from threads without a deque, and parking on the platform's address wait (futex, `WaitOnAddress`, `__ulock_wait`). A spawn goes to the spawning worker's deque, a wake returns the task to a deque, and a joined task is pushed onto its joiner's waker's deque. `host::worker_id()` and `host::workers()` expose the scheduler. Task stacks are created on first entry, so a 100k-task spawn burst costs records and queue slots rather than 100k stack mappings. Book: *Threads, atomics and mutexes*; mechanism: `docs/design/scheduler.md`.
- Added: lazily committed task stacks with a guard page and a named overflow. Linux and macOS reserve 1 MiB, `mprotect` the low page `PROT_NONE`, let the kernel commit touched pages, and recycle finished stacks through a per-worker free list; Windows uses a fiber stack (64 KiB committed in 1 MiB reserved) grown by the OS. Running past the bottom reports `error: stack overflow` and exits 134 from an alternate-stack `SIGSEGV`/`SIGBUS` handler on POSIX and a vectored exception handler on Windows, instead of scribbling into the neighbouring mapping.
- Added: a Windows reactor. The scheduler creates an I/O completion port; offload completions are posted to it, `host::sleep_ms` parks on a timer heap that sets the `GetQueuedCompletionStatus` timeout, and tasks are Win32 fibers multiplexed over one worker per core. A reactor that cannot be created is no longer fatal: the runtime falls back to the offload path, which fixes the Windows abort with status 134 and no output for any task program. macOS gains kqueue readiness/timers and `__ulock_wait`/`__ulock_wake` parking.
- Fixed: two tasks failing at once printed two messages and sometimes killed the process with `SIGABRT` instead of exiting 134. An atomic claim in `rt_fail`/`rt_abort` now decides the single reporter, the others park until its exit ends the process, and a scheduler or pool worker exits 134 directly instead of raising a process-wide signal that can be delivered to a parked sibling. `pool-chunk-write-outside-aborts` and the new eight-chunk case report once and exit 134 deterministically.

- Added: the compiler runs natively on Windows and macOS, and `grail build` links on both. `bun tools/windows.mjs compiler` cross-builds `grail.exe`; `bun tools/native.mjs compiler --target macos-aarch64|x86_64` cross-builds the Mach-O `grail`. On Windows `grail build --target windows-x86_64` assembles with `clang`, writes its import objects from the compiler's own `// grail-link: import DLL SYMBOL` notes (the Win32 import table now states the DLL, `win32_dll`, so no table is duplicated in the driver), packs them with `llvm-ar` and links with `lld-link` - LLVM is the whole toolchain, no Visual Studio and no Microsoft `.lib`. The platform module is now chosen by *target* (os-windows.grl, darwin.grl or os-linux.grl) instead of always being os-linux, so one host builds all three. `bun tools/windows.mjs selfhost` runs the Windows compiler under Wine: it compiles hello end to end, and its stage 2 is byte-identical to the Linux compiler's. Four bugs that only a real program finds were fixed on the way: the allocator's `mremap` grow of blocks of 512 KiB or more (now copies to a fresh mapping, as Darwin does), a self-deadlock when a large block was freed (the thread-stack reap took the allocator lock the allocator already held), `host::exe_path` reading `/proc/self/exe` (now `GetModuleFileNameA` on Windows, `_NSGetExecutablePath` on macOS, `/proc/self/exe` on Linux - `grail build` cannot re-invoke itself without it), and the 1 MiB PE stack reserve that overflowed the compiler (`/stack:8388608`). Paths: `grail build` treats `\` as a separator and `C:` as absolute, in source paths, module search and link inputs. Console: the Win32 console is set to UTF-8 (`SetConsoleOutputCP`), so printed strings are UTF-8 and not the ANSI code page. New CI lanes run the cross-built compilers natively on `windows-latest` and `macos-14` (book examples, corpus cases, and a self-compile), fed by one Linux job that builds both binaries. Documented in README ("Installing on Windows and macOS") and docs/platform-status.md.
- Fixed: `grail build --target macos-aarch64` / `--target macos-x86_64` now assembles and links end to end on a Linux host. The emitter wrote two things Darwin's assembler refuses: `.weak` before a drop helper's or vtable's definition (Mach-O spells a weak definition `.weak_definition` - there is no `.weak` for a definition) and an ELF-only `.pushsection .rodata` pad between modules, which an empty pad must not bring into being when only ELF builds are split. Read-only strings now name `__TEXT,__cstring` on Mach-O instead of `.rodata`. Without a macOS SDK the driver writes the same libSystem `.tbd` stub `tools/macos.mjs` builds - exported from the object's own `nm -u` list - and links against that, so a cross build is a real Mach-O executable with the `/usr/lib/libSystem.B.dylib` dependency and an ad-hoc signature, not just an object. `GRAIL_SDK` still selects a real SDK; `GRAIL_NM` the nm used for the stub. `tools/test-macos.mjs` pins the driver path for both targets.
- Docs: a "Why Grail" chapter (invariants checked, not just memory; honest tradeoffs against Rust, Go and Zig; what Grail refuses) and "Grail for Rust programmers", a cheatsheet table backed by one checked program in both languages (`cheatsheet` example, verified by `tools/book.mjs check`).
- Fixed: `grail build` (per module, the default) failed on any program using `iter`: a generic interface implementation read back from an interface file was keyed like an inherent impl, so its parameters were not found (`method type parameters do not match the interface`). Closures emitted inside specialisations no longer change binding from `.globl` to `.weak`. `split-test` now builds the iterator-adapters example per module.
- Added: checked effects. `@no_alloc` and `@no_panic` on a function are proved over the whole call graph, the runtime included, and a refusal names the chain that reaches the allocator or a runtime check (`grow -> rt_push -> rt_grow`). A refined parameter's check counts against callers that did not prove it. `@bounded(n)` on a `while` or `for` is proved from an unsigned counter and a constant or refined bound. Programs that claim an effect build whole-program; interface files carry the claims. See docs/design/effects.md.
- Added: UTF-8 helpers on byte strings (`lib/strings.grl`), following Rust's `str` API. `strings::is_utf8` validates strictly - every overlong form, surrogate, value above U+10FFFF and truncated sequence is rejected - and `strings::utf8_error` answers `u64?`, the offset of the first ill-formed sequence. `strings::chars` and `strings::char_indices` are lazy `iter::Iter` values (`char` and `(u64, char)` items) that chain with `map`/`filter`/`collect`; `strings::is_char_boundary`, `strings::slice_chars(bytes, lo, hi)` (a runtime error names the call site when either offset is not a boundary), `strings::char_count`, and `strings::encode_utf8`/`strings::push_char` (both take a `char` now) complete the set. Invalid input decodes to one U+FFFD per maximal invalid subpart, the policy Unicode recommends and Rust's `from_utf8_lossy` implements. The iterators own a copy of their input: an `iter::Iter<T>` carries no lifetime, so it cannot hold a borrow of the argument. Book: *UTF-8* in *Bytes and text*, with a Rust comparison.
- Fixed: the LLVM backend no longer re-declares a weak vtable `.globl` when it exports it (the assembler refused `changed binding to STB_GLOBAL` for `dyn` with fixed associated types).
- Fixed: a drop helper named from a body emitted during the helper sweep was never defined (`undefined symbol: .D...`), which broke any generic record holding a vector of a parameter type - `lib/arena.grl` was the first. `emit_drops` now absorbs both the types its own walk interns and the helpers its own output names, instead of walking a snapshot, and `drop_call`/`release` no longer name a helper for a type that still has a parameter in it (a body emitted without its bindings cannot name one). `lib/arena.grl` gains its corpus case: `arena-generational-keys`.

- Added: shared ownership in the standard library. `lib/rc.grl` gives `Rc<T>` (`rc::new`, `r.clone()`, `r.get() -> &T`, `strong_count`, `weak_count`), `Weak<T>` (`rc::downgrade(&r)`, `w.upgrade() -> Rc<T>?`) and `Arc<T>` with atomic counts, declared `unsafe struct Arc<T>: transferable, shareable` so its type argument must be shareable as well. One heap block holds `[strong, weak, value]` as words, because every Grail value is one word, so a handle is one word and the last handle out drops the value and frees the block; a handle's field points at the value, which is what lets a record literal infer `T`. There is no interior mutability: `Rc`/`Arc` are read-only and shared mutation is `Arc<Mutex<T>>`. `lib/arena.grl` is a generational slot map in safe Grail - `insert -> Key`, `get`/`get_mut` (borrowed), `remove -> T?`, `len`, `is_empty` - whose freed slots are reused with their generation bumped, so a stale key answers `None` instead of naming a later value. To make the pointer-backed handle expressible, `p.read()` now hands the value out as an *owner* (`ptr::read` duplicates ownership: the result has a drop flag, so it can be dropped or moved on) and `p.write(v)` consumes its operand (`ptr::write` hands `v` in: an owned local written into a block is not also dropped where it came from); both directions of the contract the book already stated are now checked. Book: *Shared ownership: `rc` and `arena`*, and the raw-pointer section states the read/write contract.
- Fixed: `Arc<T>`'s teardown freed one of its two count cells twice. Each cell now has exactly one owner at a time: the block's word or the handle that read it out, handed back with `write` (which consumes it) or kept with `drop` (which frees it); the last handle of any kind drops both cells and then frees the block. An `Arc` program now satisfies the exit-time allocation check, and `rc-arc-counts-and-drop` pins the counts, the value's drop at zero and the clean exit.

- Added: the rest of the unsafe hatch. `unsafe fn` states a contract the checker cannot see: its body is checked one level down (so raw pointers and foreign calls in it need no inner `unsafe` block) and every call from safe code must be inside one. `unsafe struct C<T>: transferable, shareable` states an audited capability contract where the type is declared - the classification takes `unsafe` on purpose, only a struct can take it, `shareable` implies `transferable`, and `transfer_capability` honours it without walking the fields while still requiring every type argument to classify, as Rust's `unsafe impl<T: Send + Sync>` does. `p.as_ref()` and `p.as_mut()` hand a borrow back out; they may only be the returned value of a function whose result is `&T` / `&mut T` of the same pointee, because the declared result is what names the lifetime, and the reference's frame source is registered the way a returned capture is. `unsafe` before an item other than a function or a struct is refused, and a leading `unsafe` is read as `unsafe module` only when `module` follows, so an entry file may start with `unsafe fn`. Fixed: a raw pointer in a generic signature (`fn f<T>(p: *mut T)`, `unsafe struct C<T> { p: *mut T }`) now infers and substitutes its type argument - `bind_types`, `canonical_type`, `infer_type` and `concrete_type` walked every payload kind but the pointer's. Book: *Unsafe code: raw pointers* gains *Handing a borrow back out*, *unsafe fn* and *Audited records*.

- Added: `impl Drop for T { fn drop(self: &mut T) { ... } }`, Rust's rule for cleanup a type has to write itself. `Drop` is a built-in interface - the name is reserved, nothing imports it, and `fn drop(self: &mut Self)` is its only method - so an implementation with another shape, or for a type declared in another module, is refused at the `impl`. The method runs at the head of the cleanup the compiler already generated for `T`, before the fields are released; the rest of the order is unchanged (fields in declaration order, a scope's locals in reverse, vector elements front to back, a `dyn` object through its vtable), and a generic implementation runs for every instantiation, since each instantiation's glue calls its own `drop`. The helper's content-addressed name now covers the user `drop`, so two objects that both know the implementation still emit one weak body, while an object that never saw it cannot be handed a helper that silently skips it. `x.drop()` is refused by name (the call is the glue's; `drop(x)` ends the storage early), and a value that implements `Drop` is opaque to partial moves: a field cannot be taken out of an owned value of that type, and `(a, b) := t` or `match p { T { .. } => ... }` cannot take it apart (`match &p` binds references and is fine). Book: *Cleanup you can write: impl Drop* in *Cleanup and boundaries*.

- Added: raw pointers behind `unsafe` (Rust's `*T`/`*mut T`). A `*T` is one word, `Copy` and drops nothing; `**T` is a pointer to a pointer. `ptr_of(&x)`/`ptr_of(&mut x)` give the address a reference already carries, `alloc(T, n)`/`free(p)` a zeroed block, `ptr_from_addr(T, a)`/`p.addr()` convert to and from `u64`, and `p.add`/`p.sub`/`p.read`/`p.write`/`p.is_null`/`p.cast` are the operations, with the step and the load width being the natural width of a sized integer, f32 and f64 and one word for everything else. Every operation is refused by name outside an `unsafe` block, `write` needs a `*mut T`, and a pointer keeps the loan of the reference it came from, so the storage it names cannot move underneath it. A record holding one is thread-affine. The type round-trips through an interface as `(ptr mode T)`. Not in this increment: `p.as_ref`/`p.as_mut` (refused by name), `unsafe fn` and `unsafe struct ... : transferable, shareable`.
- Added: refinement types - a predicate a value must satisfy, written where the value enters: `fn sample(v: &f32[], i: u64 where i < v.len())`, `struct Ray { t_max: f32 where t_max.is_finite() && t_max > 0.0 }` and `fn normalize(x: f32) -> f32 ensures result.is_finite()`. Every obligation is checked: a parameter's predicate at its entry (so the values are the arguments', and a failure names the call site), a field's at a record literal and at `r.f = v`, and `ensures` at each `return` with `result` naming the value. A failure stops the program through the runtime-error path - `error: refinement violated: i < v.len()`, the ` --> ` call site, then ` = required by sample at src/lib.grl:3:1`. A predicate may not call a user function or have a side effect: only `len()`, `is_finite()` and `is_nan()` are pure enough, and anything else is refused by name. Predicates travel in interface files, so a module's invariants cross a separately compiled boundary.
- Added: the refinement prover. An obligation the compiler can discharge from what it can read at the
  site - an `if`/`while` condition (and its negation in `else`), an `assert`, a `for` loop's bounds, a
  binding of a constant, a refined parameter of the function being compiled - compiles to nothing: the
  call jumps to a second entry, `<sym>.proved`, that runs the frame and the parameter stores and skips
  the checks. `take(16)` against `align % 16 == 0`, a ray built under `t.is_finite() && t > 0.0`, and
  `return x` for `ensures result.is_finite()` are all discharged. Anything the prover cannot read - a
  `||`, an unreadable term, an argument that is not a name or a constant, an indirect call - keeps its
  check, so a program is never weaker than the checked one. A refined parameter (`i < v.len()` on
  `v: &u64[]`) also feeds the existing bounds-check elimination for the whole body, so
  `fn get(v: &u64[], i: u64 where i < v.len()) -> u64 { return v[i]; }` compiles with no check on the
  index path; a body that binds either name again, or a base that is not a shared reference, keeps it.
  `--strict-refinements`, `@strict;` for a module and `@strict` before a declaration turn an
  unproved obligation into a compile error at the call, the literal or the `return`, naming the
  predicate, the declaration that requires it, and the facts the prover had. `--verify-facts` (now
  accepted on the native backend) re-emits the check of every obligation the prover discharged and
  enters the checked entry, so a wrong proof aborts instead of passing unnoticed.

- Added: tuples. `(u64, string)` types and `(1, "a")` values (each tuple size is a generic record with fields `0`, `1`, ...), `t.0` / `t.0.1`, `(q, r) := divmod(17, 5);` destructuring, and `(A, B)[...]` literals. `iter::enumerate` and `iter::zip` yield tuples; `iter::Indexed` and `iter::Pair` are gone (`p.index`/`p.value` and `z.left`/`z.right` become `.0`/`.1`). The book no longer calls tuples deliberately absent.
- Added: generic interface methods. `fn wrap<U>(self: &Self, u: U) -> U[];` in an interface, implemented with the same parameters, is specialised per call through bounds, `Interface::method` calls and default methods; an implementation with different type parameters is refused, and (Rust's rule) an interface with one cannot be `dyn`.
- Added: interface inheritance. `interface Shape: Named + Sized` requires every implementation of `Shape` to have implementations of `Named` and `Sized` for the same type, and lets a bound `T: Shape`, a default method or a `dyn Shape` call their methods (a dyn vtable carries them too). Interface files record the supers.
- Added: closure parameter and result inference. `iter::of(v).filter(|x| *x > 1).map(|x| x * 2)` and `f: Fn(u64, u64) -> u64 = |a, b| a * b` need no annotations: a closure takes its parameter types from the function type it is passed or bound as, and its result from that type or, for an expression body whose type nothing fixes yet (`map`'s `U`), from the body. A parameter nothing fixes is still an error that says to write `|x: T|`.
- Added: `map` from reference items to owned ones (`iter::refs(&v).map(|x: &u64| -> u64 *x * 2)`). A generic function's result may carry the lifetimes of its type arguments, as Rust's returned `impl Trait` does: the result keeps the loans of the arguments that carry them, so `v` stays borrowed while the mapped iterator lives. A moved value now carries every live loan it holds, whatever its type shows.
- Added: a shared reference can be copied out through a shared reference, as in Rust (`&T` is `Copy`): `r := *x` for `x: &&u64` (what `filter` hands its predicate) gives an `&u64` with the inner lifetime. An exclusive reference still needs an explicit reborrow.
- Added: associated-type bounds and constraints. `type Item: order::Ord;` in an interface lets generic code use the bound on `T::Item` (an implementation giving a type without it is refused); `I: iter::Iterator<Item = u64>` pins it for a function; `dyn iter::Iterator<Item = u64>` is an interface object of an interface with associated types.
- Added: operator interfaces. `lib/ops.grl` has `Add`, `Sub`, `Mul`, `Div`, `Rem` and `Eq`; implementing one makes `+ - * / %` or `==`/`!=` work on a record or enum type, and `order::Ord` gives `<`, `<=`, `>`, `>=`. The built-in numbers implement them too, so `T: ops::Add` code takes records and numbers alike.
- Added: generic interface implementations. `impl<T: Show> Show for Box<T>` implements an interface for every instantiation whose parameters meet the bounds; its methods are specialised per type and dispatch through calls, method syntax, generic bounds, default methods, associated types and `dyn` vtables. `iter::Iterator` (`type Item; fn next(...)`) is the standard iterator interface, implemented for `iter::Iter<T>`. Interface methods also work with method syntax on non-record types (`impl Show for u64` makes `x.show()` work).
- Added: iterator adapters as methods. `iter::Iter<T>` has `map`, `filter`, `take`, `enumerate`, `zip`, `collect`, `count` and `fold` methods, so chains read left to right: `iter::of(v).filter(...).map(...).collect()`.
- Changed: the compiler's own sources no longer hoist a field read out of a call's argument list. Two-phase borrows make `f(&mut c, c.field)` mean what the temporary said, so 153 `tmp := c.field; f(&mut c, tmp);` sites are inlined at the argument position they read in, and the 38 that stay carry a one-line reason: 24 because the callee is the `exchange` builtin, which takes its `&mut` before its other argument, and 14 because the read goes through a borrowed vector element, which is a loan rather than a copy. compiler/README.md, compiler/NATIVE.md and the borrowing chapter now state the rule instead of presenting the temporary as the way to write it; `hoist-inlined-field-read` and `hoist-inlined-nested-call` pin the accepted forms and `hoist-rejects-simultaneous-mut-alias`/`hoist-rejects-element-borrow` the two that still need one.
- Added: two-phase borrows, as in Rust. A call's `&mut x` argument (or a `&mut self` receiver `x.m(...)`) is borrowed after the other arguments are evaluated, so they may still read `x`: `bump(&mut c, c.pos)`, `ty_kind(&mut c, ty_arg(&mut c, t))` and `c.bump(c.pos)` compile. A borrow that stays alive through the call, such as `take(&mut c, &c.pos)`, is still refused.
- Added: runtime-error locations and backtraces on Windows. A failed check on Windows x86-64 (and on Windows ARM64, where the path is verified by static PE/COFF checks rather than execution) now prints `error: ...`, then ` --> file:line:col`, then one ` = called from file:line:col` per frame above it, exactly as on Linux. A PE linker has no `__start_`/`__stop_` symbols, so the table goes into grouped sections `grail_sites$a`/`$b`/`$z`: lld-link sorts and merges them, which puts a local label that opens `$a` at the first entry and one that opens `$z` past the last, with the entries in `$b` as read-only data. The Win64 prologue already keeps the `rbp` chain the walk follows (and ARM64 the `x29` one), the runtime writes the message through `WriteFile` on stderr as before, and `--debug` builds, `--split`, `--no-error-sites` and the LLVM backend are unchanged (the Windows case `runtime-error-backtrace` executes under Wine; `bun tools/windows.mjs check` gained `stderr` assertions for it). Also fixed in the same place: a failure report never names a runtime frame, and the column never carries the table's legacy internal bit. A table written before the statement-range format (the checked-in seed is one) keeps the file name and marks the runtime with bit 63, which the reader now skips and masks, so a compiler built by the seed reports the program's own frames with clean columns; a table written now marks the runtime by leaving the file zero. Pinned by `runtime-error-skips-runtime-frames`, which asserts the frames of a check that fails inside `rt_pop` and that stderr never contains `runtime.grl`.

- Changed: typed references and the `u64` default integer type are the language's only modes, so a compile needs no switches. An unsuffixed integer literal is a `u64` unless its context types it otherwise, and `&`/`*` are typed references everywhere. The removed dialect is now rejected unconditionally by name - `borrow(x)`, `borrow_mut(x)`, `read<a>`, `mut<a>`, `&mut a T`, an unsuffixed literal defaulting to `i64`, and an implicit address-of for a `&T` parameter - and the code paths that implemented it, the per-module mode restoration and the harness options that selected a mode (`defaultU64`, `typedRefs`, `legacyRefs`) are gone. `--default-u64` and `--typed-refs` are accepted as no-ops for one release so existing build scripts keep working; the compiler's own sources need neither, and only the checked-in bootstrap seed still takes both until it is reseeded from a compiler that has no such switches. An interface still records `mode typed_refs=1 default_u64=1`, which refuses an artifact written under the removed modes instead of misreading it.

- Fixed: one diagnostic per error. A generic template's body is replayed for its validation and again for each specialisation, so an error in one was printed at the same location up to 20 times and counted 20 times in `error: aborting due to N previous errors`. Diagnostics are now deduplicated by (file, line, column, message) and the summary counts distinct errors; a body an earlier run reported an error in is skipped when it is replayed too, so the run goes on to the next real error instead of the 20-error cap (`diag-dedupe-*` in `tests/native-cases.json`; a rejection case can pin an exact count with `diagnosticCount`, the rejection-side counterpart of `stderrCount`).
- Added: `x: T = v` declares an immutable typed binding, the form the mutable one already used (`mut x: T = v`) and the one Rust spells `let x: T = v`. `x: T := v` still works, as do `x := v` and `mut x = v`, and the initializer is checked against the declared type in either spelling. The bindings chapter and its checked example show the `=` form.
- Changed: a runtime error's location names its file relative to the working directory - ` --> src/main.grl:3:5` - when the compiler was given a path under it, instead of repeating the absolute path (`compiler/native.grl` in the seed built from the compiler's own sources). A path outside the working directory keeps the form it was given. `host::arg` is unchanged; the call-site table that `rt_fail_where` reads is what names the file, and `tools/native.mjs` pins `PWD` to the tree for the runs whose output is a seed, so the checked-in seed carries no checkout path and `bootstrap.mjs verify` matches in any clone. The x86-64 seed is republished (2.81 MB).
- Changed: the bootstrap seeds are checked in zstd-compressed - `compiler/bootstrap/native.s.zst`, `aarch64.s.zst` and `riscv64.s.zst`, level 19 - instead of 56.6 MB of plain assembly plus two gzip files. The seed set is 12.8 MB instead of 78.2 MB (x86-64 56.6 MB → 2.9 MB, AArch64 164.5 MB of assembly and 10.9 MB of gzip → 5.1 MB, RISC-V 64 155.0 MB and 10.6 MB → 4.9 MB), so a reseed no longer writes a file over GitHub's 50 MB warning (GH001). `bun tools/bootstrap.mjs update` compresses what it publishes, and every reader - `tools/native.mjs buildCompiler`, `bun tools/ci.mjs preflight` and `bun tools/bootstrap.mjs verify` - decompresses the seed once into `.work/bootstrap-seeds/<compressed-digest>.s` through `seedAssemblyPath`, which refuses a seed that does not match the manifest. `manifest.json` (schema 2) now records the compressed file's digest next to the uncompressed assembly's digest and size, so the staleness and identity checks are the same as before; an old-format manifest is reported by name instead of read as the wrong format. Bun's built-in zstd (`node:zlib`) does the work, so there is no new tool or package to install, and the `zstd` CLI reads the files too. `.gitattributes` marks the seeds binary.
- Changed: a program of more than one module is built one compiler run per module, which was `--per-module` and is now what `grail build` does. Each run parses only its own module's sources, reads the interfaces the runs before it wrote, and writes one assembly file for one object (`--separate`), so an edit recompiles the module it is in. The runtime, the platform module and the standard library's `core` prelude are in every program and are not counted: a program of one module of its own is still a single compiler run and a single file. `--whole-program` asks for the old one-run build and `--split` for the old parts shape; `--per-module` is still accepted and means the default. It now works on AArch64 and RISC-V as well as x86-64 - the per-module object is assembled and linked with the target's usual toolchain - while Windows and macOS keep building the whole program. The default build keeps every runtime-error location: a check that fails in a module the entry never mentions reports that module's `file:line` and the frames above it. `grail build --cache` now caches the default path - each module's run keyed by its own sources and the surfaces of the interfaces it can read, plus the image, so an unchanged rebuild prints `program up to date`; `--whole-program --cache` keeps the older object cache. `--interface` builds still check every module in one run. Measured on a five-module project: cold 780ms per module against 732ms whole-program, 54ms on an unchanged rebuild.
- Added: runtime-error backtraces, on every Linux target. After the location line a failed check names the frames above it, innermost first, the way Rust's panics do - `= called from src/main.grl:9:5` - up to 32 of them; the `error: ...` and ` --> ` lines are unchanged. The table is built for AArch64 and RISC-V as well as x86-64 now, which also gives those targets the `error: ...` message and its ` --> ` line in the first place. It records a position per statement, and the code between two positions is the statement a frame's return address falls in, so every frame is named by the statement that called it rather than only the calls into the runtime; the runtime's own code and a function's prologue are ranges that name no place and are skipped. Windows and macOS still carry no table. `--debug`, `--split`, `--no-error-sites`, the LLVM backend and `--per-module` builds are unchanged.
- Added: `tools/gate.sh` (`just gate [--reseed]`), the full merge gate in one script: every target, both backends and every tool suite, overlapping independent legs three at a time, with no duplicate `verify` after a reseed and a `summary.txt` that lists failures first. Native and LLVM corpus runs of one target now use separate work directories, so they can run at once.
- Fixed: a closure held by reference (`f: &Fn(...)`, or `r := &g`) can be called more than once, in loops and branches. The scan that finds a binding's last use skipped `name(...)`, so the reference's loan ended after its first call.
- Improved: range facts summarise counted fill loops (`for i in N { v.push(x) }` leaves `len(v) >= N`), so matmul's kernel needs no bounds checks with `--range-facts` (about 1.4x to 1.0x of C).
- Improved: range facts survive calls that take a vector by shared reference (`energy(&p, &v, &m)`): the front end records shared-reference parameters and the analysis keeps a slot's facts when its address reaches only those. nbody's `main` now proves 12 of 17 bounds checks (none before), about 1.8x to 1.5x of C with `--range-facts`.
- Added: interface objects. `dyn Shape` holds a value of any type implementing `Shape`, chosen at run time; a value converts to one where a `dyn Shape` is expected (binding, argument, pushed element), methods run through a per-type vtable, `&dyn`/`&mut dyn` borrow one, and dropping one drops the value. Rust's object-safety rules apply (receiver `&self`/`&mut self`, no other `Self`, no associated types), and a `dyn` value may not hold borrowed data. Works on every target and the LLVM backend.
- Added: associated types. An interface declares `type Item;` and names it `Self::Item`; an implementation gives it with `type Item = u64;`; a generic function names it `T::Item` (also as a literal, `T::Item[]`), and it resolves to the implementation's type when `T` is bound. Interface files carry both. A missing or foreign associated type is reported by name. Also fixed: a `pub interface` in a module other than the entry may elide method lifetimes (`fn value(self: &Self) -> &[u8];`) by the same rules as functions.
- Added: `filter` over reference items. `iter::filter(iter::refs(&v), |x: &&u64| -> bool **x > 1)` works: `&&T` is a type (a shared reference to `&T`) and `**x` reads a plain value through two shared references. A closure that loops over a captured iterator of references no longer fails the loop check ("loop backedge consumes entry storage"): a fresh shared borrow of storage outside the function on each turn is now recognised as harmless.
- Added: default methods on interfaces. A method written with a body is a default that an implementation may leave out or override; it is compiled per implementing type, can call the interface's other methods and its module's private helpers, and reports errors at the interface. Methods of a bounded type parameter can be called with method syntax (`s.name()` for `T: Shape`). An implementation's missing or foreign method is now reported by name, at the `impl` or the method.
- Added: runtime errors say what failed and where. A failed bounds check, division by zero, overflow under `--overflow=checked`, `unwrap` of None/Err, a slice out of range, a C-array length mismatch and other checks now print `error: index 7 out of bounds for length 3` and ` --> src/main.grl:2:5` before aborting (native x86-64 Linux builds at the time; the backtrace entry above extends the table to AArch64 and RISC-V).
- Added: editor support for `.grl` files. `editors/vscode/` is a VS Code extension (language id `grail`, `.grl`) carrying a TextMate grammar for the language - declaration heads and their names, the control keywords and built-in types, `@if`/`@for`/`@assert`/`@embed`/`@name(...)`, value generics (`<@k: u64>`, `x.@f`), lifetimes (`<a>`, `&a T`), `extern "C" lib "x" fn`, closure heads, `match` arms, the operators (`::`, `|?`, `..`, `**`, ...), string/char literals with their escapes, every numeric literal form (including `65533u32` and `3.0e38`) and `//` comments - a language configuration for comments, brackets and indentation, and a dependency-free client that starts the existing language server (`grail.server.path`/`args`/`cwd`, defaulting to the documented `bun tools/lsp.mjs`) to publish its diagnostics and serve go-to-definition. `editors/README.md` covers installing it by symlink or packaged `.vsix`, pointing it at a server and using the grammar in other editors. The same grammar is usable by any TextMate-based editor (scope `source.grail`). `bun tools/grammar-test.mjs` verifies it: valid JSON, every regex compiles in JavaScript, and 19 fixture lines - nearly all verbatim lines from this tree - tokenize to the expected scopes under a self-contained matcher and, when the packages are installed, the real `vscode-textmate` engine; `bun tools/ci.mjs lint` runs the grammar test.
- Added: the first user-facing standard-library modules. `lib/time.grl` wraps the runtime clocks: `time::now()` gives a monotonic `Instant` with `elapsed_ns`/`elapsed_ms`, `time::unix_seconds()` reads the wall clock, `time::sleep_ms(n)` suspends the task, and `nanos_from_ms`/`millis_from_nanos` convert durations. `lib/net.grl` wraps the runtime TCP sockets: `net::connect(ip, port)` returns a `TcpStream` with `read`, `read_all`, `write_all` and `close`, and `net::bind(ip, port)` returns a `TcpListener` with `port`, `accept` and `close`; failures are `io::Error` values a caller can propagate with `?`. The runtime exposes the wall clock to Grail as `host::wall_ms`. `lib/strings.grl` gains `parse_u64` (the explicit spelling of `parse_num`), `parse_i64`, `from_u64` and `from_i64`, which answer `None` for bad input instead of stopping the program. The book has a new *standard library* chapter with an example for each module.
- Added: compile-time stage C3, the run tier. `TABLE := build();` and `@fib(30)` call ordinary functions while compiling: the compiler builds and runs a probe of the program's own code, with files, the clock, the network and processes refused, and bakes the integer, bool or string result into the program. Constants are computed on first use, a dependency cycle is reported as one, and results are cached in `.work/comptime`.
- Added: compile-time stage C4 and value parameters on records. `@for f in fields(T) { ... }` (and `variants(E)`) compiles its block once per field with `f.name`, `f.index` and `x.@f`, so a generic `show<T>` prints any record; `@embed("file")` places a file's bytes in the program as `u8[]` (such a build skips `--cache`). `struct Ring<T, @N: u64>` takes a value parameter, `Ring<u64, 8>` is its own type, and a function infers `N` from an argument of that type.
- Fixed: `grail fmt` no longer aborts on a source whose line ranges close a bracket before opening one (the formatter's unsigned bracket depth underflowed under checked arithmetic).
- Fixed: an iterator that holds a reference can be lent to a second loop after a first one (`for x in &mut it` twice): the loop no longer keeps its last item's loan in the state it exits with. Added `iter::refs(&v)`, an adapter yielding references into a vector; closures whose type returns a reference (`Fn() -> &a T`) may now carry, return and be called for borrows of `a`, which stay checked (the vector cannot change while one is live). A reference passed by name to a closure is reborrowed rather than moved, as at a direct call; a closure may capture a record holding a borrow.
- Changed: `pub` is a checked visibility boundary. Every item - function, extern declaration, record, enum, handle, constant, alias, interface and method - is private to its module unless it is `pub`, and naming a private item from another module is an error (`` `helper` is private to module `vis_lib` ``, with a help line). Interfaces carry only the public surface plus the private items a public generic's body needs (marked `private`). A whole-program build with `--interface` now compiles every module from source and checks its interface against it; the transitional path that compiled a module's bodies against its interface's declarations is gone. Abundance, the standard library and the tests mark what they export.
- Added: several errors per compile. An error in a function body no longer ends the compile: the compiler reports it and goes on checking the rest of the program with that body skipped, up to 20 errors, then `error: aborting due to N previous errors`. The common diagnostics carry an error code (`error[E0004]: type mismatch`), and `grail explain CODE` prints what it means and how it is usually fixed (docs/diagnostics.md).
- Added: `extern "C" lib "name";` requests a library with no declaration from it (the ImGui binding states the C runtime its C++ shim needs). Indexing a vector of handles, `CStr` or `CPtr` now reads the element, as for numbers.
- Added: C arrays and C strings read back. A field `f: [T; N]` in an `extern "C" record` is a C array laid out inline; Grail reads it whole as a vector (`[u8; N]` as bytes) and assigns it whole from exactly N elements. `unsafe cslice(T, p, n)` copies an array C hands out by pointer and length into a vector, and `unsafe cstr_bytes(s)` copies a C string into bytes. Abundance uses them for `VkPhysicalDeviceProperties`, the physical-device list and SDL's extension names, replacing byte-offset decoding, an eight-field slot record and strlen/memcpy copies.
- Added: `grail cache prune [--keep N]` drops build-cache records no build used in the last N builds (10 by default) and every blob nothing then names; `grail cache clear` empties the store.
- Added: compile-time stage C2 - value parameters on functions. `fn rotl<@k: u64>(x: u64)` is called as `rotl<13>(x)`; every distinct value is its own specialisation, the parameter is a constant inside the body, and `@assert`/`@if` see it, so a bad value is a compile error at the call. Interfaces spell the binding `(const N)`.
- Added: `grail build --per-module --cache` keys each module's compiler run by its own sources and the surfaces of the interfaces it can read, so editing one module's body recompiles that module alone; a warm rebuild compiles nothing.
- Range facts: stores through an element pointer, drop flags a block itself clears, loads through a frame slot's address, and drop-glue calls no longer erase what the analysis knows about a vector (each verified across the corpus with `--verify-facts`).
- Changed: compile errors are rendered the way rustc does - `error: message`, an `-->` location, a numbered source excerpt with the offending code underlined, secondary labels on the other lines that explain the error, and `help:` lines. A borrow conflict now shows where the borrow was taken and where it is still used and names the owner of the storage (`v`, not `*r`); assigning to an immutable binding points at its declaration and suggests `mut`; an undefined name or unknown function points at the name and suggests the closest one in scope (`help: a name with a similar spelling is in scope: \`total\``); a type mismatch names both types in source syntax (`expected \`u64\`, found \`u8[]\``). The internal byte offset is no longer printed.
- Added: `grail build --per-module` compiles each module of a program in its own compiler run, in dependency order, against the interfaces of the modules before it, and links once. Fixed on the way: an interface implementation for a built-in type (`impl Ord for u64`) was written with the generic parameters of whatever declaration shared its index, so a module compiled alone against such an interface failed with `generic constraint arity`; and a specialisation is now emitted `.weak` directly instead of `.globl` then `.weak`.
- Changed: the interface format is version 3 and can express every type in the corpus - pool job handles (`Job<T>`, spelled `(job T)`) were the last kind it refused, so the 11 pool programs now build from interfaces too.
- Added: debug info describes what values contain - DWARF on Linux and CodeView (a `.debug$T` type stream) on Windows. A Grail record is a pointer to a structure of its fields, a string/byte sequence/vector a pointer to its {data, len, cap} header with typed elements, a view {data, len}, a reference a pointer to its referent, and an extern "C" record its C layout - so `print **o` in gdb shows `{count = 7, ratio = 2.5, inner = ...}` and `print (*s)->data` the text.
- Fixed (separate compilation): methods, interface implementations and interfaces were emitted under symbols that spelled a position in the compiling run's declaration tables, so a module compiled alone could not call another module's method; the symbols now spell the declaration (module, type or interface name, and a digest of an implementation's type). A specialisation instantiated inside another specialisation is emitted by the module that asked for the outer one.
- Changed (separate compilation): every module emits the specialisations its code uses, weak and content-addressed, replaying the template from its interface when the source is not in the build; the linker keeps one copy. The `--serve` option and `.sreq` request files are gone, so a module's object depends only on its own source and the interfaces it reads.
- Added: compile-time evaluation, stage C1 (`docs/design/comptime.md`, book chapter *Compile time*). Module constants take constant expressions (`const MASK: u64 = PAGE - 1;`, or `MASK := PAGE - 1;` with the type inferred); `@if target.os == .windows { } else { }` compiles only the branch that holds, at module level or in a function, without type-checking the other; `@assert(cond, "message")` is a compile error with the message; `@expr` folds an operand; `size_of`/`align_of` give the target layout of scalars, handles and C records. Checked arithmetic: an overflow is a compile error.
- Fixed: a character the language does not use (such as `#`) made the compiler abort without a message; it is now an error at its position, and `#` says that comments start with `//`.
- Range facts (`--range-facts`) widen at loop heads with thresholds, so a loop of any trip count, and a loop that pushes, converges and can be proved; previously the fixpoint hit its 24-round cap and decided nothing.
- Added: an iterator protocol. A record with an inherent `fn next(self: &mut Self) -> T?` is iterable: `for x in it` takes the iterator, `for x in &mut it` lends it so the loop can stop early and a later loop carry on; `for x in &it` is refused by name. A plain `for` over a vector compiles exactly as before.
- Added: `lib/iter.grl`, lazy adapters over a closure-backed `Iter<T>` - `upto`, `of`, `map`, `filter`, `take`, `enumerate`, `zip` and `collect` - with a new book chapter, *Iteration*, and Rust comparisons.
- Fixed: a closure body that instantiates a generic (`Some(i)` inside `|| ...`) no longer leaves an undefined symbol at link time; closures and specialisations are emitted to a fixpoint.
- Added: `byval` records on Windows. Win64 passes a record of 1, 2, 4 or 8 bytes as one integer word in its positional slot and any other size by reference to a 16-byte-aligned caller copy; Windows ARM64 uses the AAPCS64 rules. Executed under Wine with the callback stack-argument, record-write and nested-float fixtures (`tests/windows-cases.json`).
- Added: a C function may return a record whose embedded records contain floats. Result classification (SysV eightbytes, AAPCS64 homogeneous aggregates, RV64 float+int pairs) now runs over the flattened field list instead of refusing the shape (`tests/ffi/nested_float_results.grl`, executed on x86-64, AArch64 and RISC-V).
- Added: a C callback may write into the struct C passes it: declare the parameter `p: &mut R` for an extern record `R`. The body works on a Grail-owned copy that every exit writes back into C's storage, so field writes, passing `p` on and whole-value replacement are all sound. A `cfn` type may declare `&mut R`, and a call through it passes the record's own address.
- Added: a C callback may take any number of parameters. Arguments past the registers are read from the caller's stack on SysV x86-64, AAPCS64, RV64 (which first spills extra floats into free integer registers) and Win64, instead of the parameter list being refused (`tests/ffi/callback_stack.grl`, executed on x86-64, AArch64 and RISC-V).
- Added: a C callback that arrives on a thread C created now runs instead of aborting. The outermost callback on such a thread adopts a record (its own TCB, no task state) for the duration of the call and releases it on return, so it can allocate, make foreign calls with its own errno, and be re-entered through C.
- Fixed: `cstr("literal\0")` no longer dangles after its statement - it points into static read-only storage, so a `CStr` kept in a binding or record field stays valid; a literal without a trailing NUL is a compile error rather than a runtime abort. `cstr(bytes)` now holds a loan on `bytes` for as long as the `CStr` is live, under the same rule as `cptr`.
- Foreign calls work on every runtime thread, not only the main one. The host TLS base is per
  thread now (record word 56, replacing the process-wide `rt_host_tls`/`rt_grail_tls`), and in a
  process that loaded libc the runtime creates its pool workers, green scheduler threads, reactor and
  offload threads through `pthread_create`, so each has a glibc TCB of its own: errno, `pthread_self`
  and the malloc tcache belong to the thread that uses them, and glibc knows the process is
  multithreaded. A callback finds its thread's record through `rt_tls_record`, an initial-exec TLS
  word; on a thread C created it aborts by name instead of sharing the main thread's record (adoption
  is next). Static programs are unchanged except that a foreign call on a thread without a TCB no
  longer switches the thread pointer. A dynamic link now always adds `-lc`. On x86-64 a foreign call
  costs one `arch_prctl` fewer (two instead of three). `tests/ffi/threads.grl` (`bun tools/test-ffi.mjs`)
  executes libc calls and errno from a pool worker and a green task and errno isolation between two
  threads on x86-64, and under qemu on AArch64 and RISC-V 64 with a glibc sysroot; the previous
  runtime fails it (shared errno 42/42).
- Fixed (soundness): a C pointer made by `cptr(&r)`, `cptr_mut(&mut r)` or `cptr(bytes)` is now a
  borrow of what it points at for as long as the pointer is live. Before, the borrow ended with the
  statement, so `p := cptr(&sub); sub = other;` compiled and left `p` dangling. The pointer holds the
  same loan a reference would, through bindings, copies, record fields (assigned or in a literal),
  values read back out of them, moves of the record holding it and closures that capture it. While
  it is live the storage cannot be assigned, modified, moved, dropped or re-borrowed, and a
  `cptr_mut` pointer is exclusive, so the storage cannot be read either. The pointer also cannot
  outlive the storage, so keeping it in an outer-scope record, writing it through a `&mut`
  parameter, returning it or returning a closure that holds it are all refused. A Grail call whose
  arguments carry a pointer is assumed to pass it to its result and its `&mut` arguments, so a
  helper cannot launder it. `cptr(&mut v)` is a read-only pointer and holds a shared borrow.
  Each refusal names the storage, the binding holding the pointer and the `cptr` that made it:
  `cannot assign to `sub` while a C pointer to it is live in `p` (made by cptr at line 5)`,
  `` `app` goes out of scope while a C pointer to it is live in `info` ``, `cannot return a C
  pointer to `app`: the pointer would outlive it`. A C call still borrows the pointer only for the
  call, and C must not keep it. Abundance's renderer (`abundance/src/rhi_*.grl`) and every FFI
  fixture compile unchanged. `CStr` from `cstr(...)` is not covered yet. See
  [docs/ffi.md](docs/ffi.md), "Pointer lifetimes", and the book's "Calling C" chapter.
- Fixed: a generic instantiated on both `f32` and `f64` no longer shares one specialisation - the structural type key now records float width, so the f64 call ran the f32 body before (found by the per-module work).
- Fixed: `&mut` of an `extern "C"` record held in a field of a plain record (`set_y(&mut bag.pair,
  7)`, or the same reference passed to C as an `R *`) silently lost the write: the place was wrapped
  in the proxy slot only an embedded C-layout field needs, so the callee wrote into the container's
  next word instead of the record. The proxy is now made only for a C-layout container;
  `tests/ffi/record_field_refs.grl` executes the shape with a Grail and a C callee on x86-64,
  AArch64 and RISC-V 64 (reproducer from [docs/rhi.md](docs/rhi.md)).
- The sequential stdlib callbacks take `FnMut` (readiness A12, first step): `vecs::map`, `fold`,
  `filter_nums`, `any_num`, `all_num`, `count_num`, `position_num`, `sort_by`, `sort_by_key`,
  `Option::map` and the second callback of `pool::join`, so a predicate or comparator that writes
  its captures - a counter behind a captured `&mut`, a toggle in its own environment - is accepted
  instead of refused with `FnMut, not Fn`. `Fn` closures and named `fn` values still widen to them.
  The `pool` callbacks that run on workers (`pool::map`, `run`, `for_chunks`, `chunks_mut`, `spawn`,
  `join`'s first) stay `Fn`, because every worker shares one closure. Native cases
  `vecs-fnmut-predicates-mutate-captures`, `closure-fnmut-sort-by-counts` (replaces
  `closure-fnmut-sort-by-rejected`), `vecs-fnmut-predicate-needs-exclusive-capture`,
  `pool-join-second-fnmut`, `pool-join-first-fnmut-rejected`.
- Fixed: an `Fn` closure passed for a generic `FnMut(T) -> U` parameter was a `type mismatch` when
  the call learned a type variable from that closure (`vecs::map(v, |x: u64| -> u64 x * 2)` learns
  `U` from it): the widening only ran once every variable was already bound. The closure's own
  signature is now widened to `FnMut` before inference (`widen_to_fnmut_formal` in
  `compiler/native.grl`); native case `closure-fn-widens-to-generic-fnmut`.
- Fixed: `--range-facts` (off by default) could remove a bounds check that a loop does exceed. The
  pass stopped its fixpoint after 24 rounds and recorded verdicts from whatever state it had, and
  without widening a loop counter's interval grows one step per round, so `while i < 100` over a
  30-element vector read past the end instead of aborting. A function whose fixpoint has not
  converged at the cap now gets no verdicts, and every access keeps its check; a loop that pushes,
  which never converged either, keeps its check too. `compiler/tests/range_long_trip.grl` and
  `range_push_loop.grl` pin both in `tools/test-facts.mjs`.
- Typed-IR range facts for the LLVM backend (F3), behind `--range-facts`: the lifter derives, from
  the word stream alone, that a slot holds an integer in `[lo, hi]` at a point, and uses it where
  the front end's bounds check lives. A *state* is one flat vector per block over the 14 registers, the frame slots
  and one length per sequence identity; the facts are established from literals, masks, truncations
  to a narrow type, arithmetic over facts already held, and comparisons already checked on the path
  -- including the 0/1 word the front end materialises every `while` guard into, whose operands the
  analysis follows back through the copies that carried them -- and they are dropped by a write to
  the location, by an address that escapes, by any call that may take an argument by reference, and
  by a narrowing that is not provably in range. Where a fact puts an accessor's index below the
  sequence's length, the accessor's body is emitted in place of the call with the bounds compare and
  its cold `rt_abort` removed, `align 8`/`align 4`/`align 1` by element width; `--verify-facts`
  re-inserts exactly that check (a cold abort if any index is out of range), and writes the verdicts
  into the module as `; range` comments. Nothing else changes: the word stream is byte-identical to
  the F1 branch's on all five benchmarks, and `optimize.grl`, `machine.grl` and the native backend
  are untouched. Measured with `tools/bench.mjs --rounds 9` against `typed-ir-f1`: **no benchmark
  moves** (0.519/0.571/1.076/0.169/0.224 s, the same as before within the spread) because **no check
  is removed on any of the five** -- their sequences are filled by counted push loops, whose trip
  count this pass does not summarise, and `nbody` hands its vectors to `energy(&p, ...)`, an escape
  the rules drop the fact on. What it does prove is a fixture's `v[i]` under a literal-length
  sequence and a `while i < 5` guard, identically through the native backend, LLVM, and LLVM with
  `--verify-facts`. It costs compile time (3.2 s -> 6.0 s end to end on `sieve`). See
  `docs/design/typed-ir.md`, "Implemented: the range fact (F3)", including the one rule that would
  make the benchmarks prove. Off by default: with the pass on, compile time is 3.2 s -> 5.5 s on
  `sieve` for no runtime gain yet, so default builds are unchanged (3.2 s / 3.3 s, F1's numbers) and
  `tools/test-facts.mjs` exercises the pass on a fixture instead.
- Fixed: LLVM builds no longer fail with `changed binding to STB_GLOBAL` - a kept-native function the emitter declared `.weak` (content-addressed drop helpers) keeps that binding instead of being re-declared `.globl`. The weak-name table is sized for every name, so programs with many drop helpers no longer hang the lowering.
- Fixed: `GRAIL_TEST_RESUME` keys pass markers by the compiler's content-hash directory rather than its file name, which is `grail` for every build, so a rebuilt compiler never inherits another build's passes.
- Measured what the validation in a Grail program costs, split by kind; the compiler is untouched.
  [tools/checks-budget.mjs](tools/checks-budget.mjs) classifies the abort arms in the emitted `.ll`
  by the predicate that guards them (bounds: the arms inside the sequence accessors; overflow: the
  arms `--overflow=wrap` does not emit; other: allocation, formatting and conversions), then times
  variants of that same `.ll` with one kind of arm deleted, paired with C `-O2` over nine rounds.
  On the five `tools/bench.mjs` programs, x86-64 `--backend=llvm`: the index/length check is 61% of
  `nbody`'s gap to C and 37% of `sort`'s, 72% of `matmul`'s and 41% of `sieve`'s, and worth nothing
  on `fnv`, which has no gap; the arithmetic checks are worth ~5% on `sieve` and 0 ms on the other
  four, so `nbody`'s "both operands are bounded by the integration step" proof would move nothing.
  `--overflow=wrap` is *not* a clean isolate -- it also drops the flag materialization the same
  machine's comparisons read, so `nbody` and `sieve` come out 3-4% slower with fewer checks -- and
  the report uses the branch-only variant for that share. Inlining the accessors in the check-free
  build is worth at most ~2%, so the residual 1.01-1.26x floor is not call overhead.
  [docs/design/typed-ir.md](docs/design/typed-ir.md) carries the tables, the explanation of what
  could not be attributed (the floor's split between the 24-byte header and the word-shaped scalars,
  `sieve`, `fnv`, and the 9-34% interaction term), and ranks the proofs a range fact would buy:
  the loop-guard/literal-length bounds proof first, `nbody` as its first instance.
- Documents: the claims this week's compiler work made false are gone, each checked against the
  compiler in this tree first. [docs/rhi.md](docs/rhi.md) said "there is no expression whose value is
  the address of an owned `extern \"C\"` record" and listed `cptr(&app)`, a record out-parameter and a
  `cnull()`-seeded handle field as refused - all three work now (the first two compile, the third is
  still `generic argument shape mismatch`), so the probe's own two `unavailable` lines are a port that
  has not been made rather than a language limit, and the refusal table now lists what is *still*
  refused: the address of a temporary, the same record twice in one expression, an out-parameter with
  no binding, and an out-parameter that is not a handle/`CPtr`/`CMutPtr`/extern record.
  [docs/platform-status.md](docs/platform-status.md) listed the same refusal and 18 executable FFI
  fixtures with 54 instances - [docs/ffi.md](docs/ffi.md) already said 19, and
  `bun tools/test-ffi.mjs x86_64` reports "19 linked and executed", so the counts are 19 fixtures and
  57 instances, and the FFI row now includes record addresses, `&mut R` out-parameters and arrays of
  handles. [book/chapters/cleanup-and-boundaries.md](book/chapters/cleanup-and-boundaries.md) listed
  taking a record's address as still refused and said the book cannot show C ABI tests because its
  examples link no C library - two of them now link a freestanding fixture in `book/ffi/`.
  [docs/testing.md](docs/testing.md) described `test-facts.mjs` and `--verify-facts` as the `f32` fact
  alone (F1 landed this week and the same suite covers its header facts) and omitted `split-test.mjs`
  from the gate and from the suite list.
  [docs/design/implementation-status.md](docs/design/implementation-status.md) still said `Send`/`Share`
  for closures was deferred, which a neighbouring row of the same file contradicted and the
  parallelism work replaced, and [docs/design/decisions-b2-b6.md](docs/design/decisions-b2-b6.md)
  recorded the same scope limit; both now point at the structural classification that reaches a
  closure's environment. [docs/design/parallelism.md](docs/design/parallelism.md) described in-place
  chunks in the future tense ("stage 2's `&mut [T]` chunks will produce") after measuring them, and
  now states the copy it removed with the numbers.
  [docs/design/llvm-backend.md](docs/design/llvm-backend.md)'s 660-case requirement names the corpus
  and its current count. Historical records of past runs (`755 cases`, `796 native cases`, `49
  examples` for a branch) are left as the records they are.
- Book: four new example pairs for the week's compiler work, each run by `bun tools/book.mjs check`
  against an equivalent Rust program. **`pool-chunks-mut`**: `parallel_for_chunks` over a ten-element
  vector in three chunks (4, 4, 2, the `ceil(n/chunks)` split) and then `pool::chunks_mut` at 5 and 5,
  against `chunks_mut(4)`/`chunks_mut(5)` under `thread::scope` - the same arithmetic split, the same
  ten numbers, and no element copied in either language. **`pool-job-handle`**: spawn, do other work,
  join; then two live handles joined in the reverse of their start order, against
  `std::thread::spawn`/`JoinHandle::join`. **`ffi-handle-array`**: a record of `handle` fields as the
  array C writes - `c_alloc_buffers(&mut buffers)` fills four slots, the record goes back to C as a
  parameter, a second array is seeded from handles already held, and the handle Grail reads out of the
  array compares equal to the one C hands back - against a Rust twin using `MaybeUninit`/`assume_init`
  on the same C file. **`ffi-uninitialised-record`** is the uninitialised-handle rule as an intentional
  rejection in both languages: reading a field of an `extern "C"` record before anything wrote it is
  `use of moved, borrowed or partially initialized value` in Grail and E0381 in Rust. The book is now
  59 Grail examples with 59 Rust twins. The concurrency and FFI chapters gain a *What this month added*
  section (in-place chunks and the measured difference against `pool::for_chunks`, the job handle and
  what its drop does, the capture classification; record pointers, records C fills, arrays of handles,
  and the borrowed callback record parameter that used to abort at exit). The modules chapter states
  the build cache flag (`grail build --cache`, `b1-cache`) and checked module interfaces
  (`b1-interfaces`) with **no** Rust comparison, and says why: they are build-driver flags, and Rust
  splits the same work between `rustc`'s incremental mode and Cargo, so a pair of programs would
  compare nothing. That section also says plainly that neither flag is in this tree yet, so the book
  does not claim to verify it.
- Dear ImGui, called from Grail: the immediate-mode UI layer the editor needs, over the FFI the
  previous increment landed. `abundance/src/imgui.grl` (new) is the context, the frame, `ImGuiIO` and
  the draw data; `abundance/src/imgui_widgets.grl` (new) the widgets and ImGui's ID stack. The C++
  boundary is `abundance/tools/imgui_shim.h`/`.cpp` - one ImGui entry point per function, and a plain
  C `struct` for every record that crosses - built with the pinned Dear ImGui 1.93.0 checkout into two
  shared libraries (`libgrail_imgui.so`, `libgrail_imgui_platform.so`) by
  `abundance/tools/build-imgui.mjs`, which also prints and diffs the record table. No struct is laid
  out by hand: `GrIo` is ImGuiIO's 240-byte prefix through `MousePos`, asserted field by field with
  `offsetof` at compile time, printed by a C program against a C++ program's own table, and checked
  again at run time by `imgui_layout_probe.grl` in both directions. `imgui_test.grl` (new) runs
  widgets, IDs, a table, a child, an `InputU64` (ImGui's `InputScalar` over `ImGuiDataType_U64`), a
  real click on a button's own rectangle, and then prints every vertex, every triangle and every draw
  command of a settled frame: 2 draw lists, 310 vertices, 501 indices, 167 triangles, byte-identical
  to the same frames through ImGui's own C++ API in `abundance/tests/parity/imgui.cpp`. That is 11
  reference programs now, and the ten ports are unchanged.
- Dear ImGui, the io fields as numbers: `imgui_layout_probe.grl` printed ImGuiIO's `DisplaySize`,
  `DeltaTime` and `Framerate` as the *bit pattern* of their binary64 widening (1280.0 came out as
  `4653344314980564992`), which was a correct read presented as an unreadable number. The probe now
  prints `imgui.io.display_size 1280 720`, `imgui.io.delta_time 0.015625` and `imgui.io.framerate 64`
  and asserts them by value - `display_size_is_1280x720`, `delta_time_is_1_over_64`,
  `delta_time_in_range`, `framerate_in_range` - and `imgui_frame_probe.grl` pins the same fields to the
  window SDL reports (`io.display_size_is_window_pixels`), so a float field arriving as a raw word
  fails on the first comparison instead of looking plausible. The parity reference keeps the encoding
  only where it is an exactness mechanism (vertex positions, uvs, clip rectangles) and now says so in
  the labels (`pos_bits`, `uv_bits`, `clip_bits`, `target.min_x_bits`); its io lines are 1280, 720, 1.
- Dear ImGui reaches the GPU: `abundance/src/imgui_platform.grl` (new) binds `ImGui_ImplSDL3_InitForVulkan`,
  `ImGui_ImplVulkan_Init`, both backends' `NewFrame`, `ImGui_ImplVulkan_RenderDrawData` and both
  shutdowns, in a second shared library (`libgrail_imgui_platform.so`) whose own dependencies are
  `libSDL3` and `libvulkan`, so no headless program loads either. `ImGui_ImplVulkan_InitInfo` crosses as
  `VulkanInitInfo` - the fields a host has - and the shim translates it into the real struct and zeroes
  the rest; the record's 104-byte layout is round-tripped through the C offsets before the backend is
  initialised. `imgui_frame_probe.grl` (new) runs the frame the editor needs end to end: SDL3 window,
  device, swapchain, the RHI's clear render pass, ImGui recording into the command buffer inside it,
  submit, present, and a readback of the presented image - 5 frames, 208 vertices and 348 indices per
  settled frame, 22908 of 230400 pixels not the clear colour, and the last two frames' images
  byte-identical. `imgui.status`/`imgui.frame.status` verdicts; a machine with no display server or
  driver skips with the platform's own words.
- RHI increment 4b, in four steps that each run before the next. The gate was the FFI's record
  pointer (`cptr(&record)`, record out-parameters, arrays of handles), so the whole Vulkan create-info
  graph is now records and pointers into them rather than byte layout:
  **1. device, queue, swapchain, images and views.** `abundance/src/rhi_device.grl` (new) creates the
  logical device with `pQueueCreateInfos` pointing at a `VkDeviceQueueCreateInfo` record whose
  `pQueuePriorities` points at a one-field record holding the `float`, and `ppEnabledExtensionNames`
  pointing at a record of `CStr` fields - the array itself - to enable `VK_KHR_swapchain`;
  `abundance/src/rhi_swapchain.grl` (new) creates the swapchain from the four decisions
  `abundance_rhi_surface` already makes (B8G8R8A8_SRGB, currentExtent, minImageCount+1, MAILBOX with
  FIFO fallback), takes its images through a record of handle fields (`vkGetSwapchainImagesKHR`
  writing them in place, four on this machine) and makes one 2D colour view per image. The surface's
  `supportedUsageFlags` decides whether a transfer source can be asked for; the report says
  `rhi.swapchain.readback supported` or names the missing bit. The probe's
  handle ledger is now per class - window, instance, surface, device, queue, swapchain, image, image
  view, and a total - with the queue closed by `vkDestroyDevice` and the images by
  `vkDestroySwapchainKHR`, so `rhi.handles.total created 14 destroyed 14 live 0` is a fact about this
  machine rather than an assumption.
  **2. a clear, a fence and a present loop.** `abundance/src/rhi_render.grl` (new) has the render pass
  (`pAttachments`/`pSubpasses`/`pDependencies`, each a record passed with `cptr(&record)`), one
  framebuffer per image view (`pAttachments` as a record of one `ImageView` field), a command pool and
  one command buffer, a clear colour as a `VkClearValue` record, `VkSubmitInfo`/`VkPresentInfoKHR` with
  their arrays of handles as one-field records, and the barriers that move the image from
  COLOR_ATTACHMENT_OPTIMAL to TRANSFER_SRC_OPTIMAL and PRESENT_SRC_KHR. The probe runs the
  acquire/submit/present loop for `GRAIL_RHI_FRAMES` frames (default 3), waiting on a
  fence each frame, and prints one `rhi.frame` line per frame plus
  `rhi.swapchain.result frames 3 of 3`. The pool carries
  VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT: one command buffer is re-recorded every frame, and
  beginning it again without that bit is undefined behaviour (it segfaults on RADV).
  **3. one triangle, drawn from the committed SPIR-V.** `abundance/src/rhi_pipeline.grl` (new) creates
  both shader modules from `abundance_rhi_shader_blob`'s bytes, and builds
  `VkGraphicsPipelineCreateInfo`'s nine pointers out of records: the two stages as a record of two
  `VkPipelineShaderStageCreateInfo`s (`pName` a `CStr` field), the vertex input from the layout the
  shader build extracted (locations 0/1/2, offsets 0/12/20, formats R32G32B32/R32G32/R32G32B32A32,
  stride 36 - checked to be contiguous and to sum to the stride), triangle list, a static viewport and
  scissor, fill, no culling, one sample, blending off, no depth and no dynamic state. The vertex data
  is a 108-byte record of three 36-byte vertices and is copied in with `vkCmdUpdateBuffer` from
  `cptr(&triangle)` - no staging buffer and no mapped memory - followed by a memory barrier to the
  vertex stage. The probe reads the entry point out of the SPIR-V's own `OpEntryPoint` and passes the
  bytes it found, so a renamed shader cannot leave a stale name behind.
  **4. the readback.** Every presented frame is copied out of the swapchain image
  (`vkCmdCopyImageToBuffer`, one `VkBufferImageCopy` region record, into a host-visible coherent
  buffer) after a COLOR_ATTACHMENT_OPTIMAL -> TRANSFER_SRC_OPTIMAL barrier, then barriered on to
  PRESENT_SRC_KHR, and after the fence the buffer is mapped, memcpy'd into Grail bytes and checked:
  626688 cleared pixels and 294912 covered ones out of 921600, none of any other colour, the covered
  count equal to the triangle's own area (0.32 x width x height), the corner (4,4) reading 0,0,0,255
  and the centre (640,270) reading 0,0,255,255 in B8G8R8A8 order, and the same FNV-1a digest for all
  three frames. "It presented" is not the evidence; the bytes are.
- FFI, found by increment 4b and recorded in `docs/rhi.md` ("What the FFI does not do safely"),
  both reproducible without Vulkan and neither worked around by laying bytes out by hand:
  **`&mut` of an extern record field of a plain record does not reach the field's storage.** A write
  through such a reference lands in the proxy slot, not in the container - `set_y(&mut bag.pair, 7)`
  leaves `bag.pair.y` at 0 and puts the 7 in the next field. A slot array written through such a
  reference is a record of null handles, which is how it was found: a null `VkFramebuffer` handle, and
  a segfault inside the driver. Direct field writes and passing the interior record by value are both
  correct; only the reference is wrong. **A `CStr` taken from a string literal must not outlive the
  statement that made it**: `cstr` is zero-copy and a literal's bytes are a temporary, so keeping the
  `CStr` in a binding and using it later reads freed memory - it read correctly often enough to be
  missed here, and the pipeline's entry-point names now come out of the SPIR-V into byte-sequence
  bindings instead. Both are `compiler/` bugs and `compiler/` is off limits in this increment, so they
  are reported rather than patched.
- FFI: a C callback's extern-record parameter is borrowed, not owned. The parameter prologue marked
  every parameter as an owning binding, so the epilogue ran the record's drop glue on the address C
  handed over — freeing the caller's struct (or its stack) — and the process then aborted inside the
  runtime's free path at exit, after `main` had printed everything and returned 0. That is the abort
  the RHI work recorded in `docs/rhi.md`: the shape is "a record crosses an `extern "C"` call", and
  the two-declarations-of-one-symbol case that pinned it is now a case of its own. A callback's
  record parameter is the `const R *` the C caller owns, so `func`'s prologue registers it through
  `borrow_parameter` (a real place, no drop glue) instead of `own`, and the fields stay readable
  under the ordinary borrow rules. Verified by `ffi-record-callback-parameter` in
  `tests/native-cases.json` (20, and the process reaches its exit status) and by the same shape in
  `tests/ffi/record_pointers.grl` against a real C shim.

- FFI: the address of a Grail-owned `extern "C"` record is now a value, and C can fill a record in
  place. `unsafe cptr(&r)` is a `CPtr` and `cptr_mut(&mut r)` a `CMutPtr` holding the address of the
  record's own fields — the same pointer a record *parameter* already was — so a struct that points
  at another struct (`VkInstanceCreateInfo::pApplicationInfo`, `VkRenderPassCreateInfo::pAttachments`)
  is expressible without laying bytes out by hand; a field, a binding and a declaration parameter
  typed `const void *`/`void *` all take it. `p: &mut R` in a declaration is the C `R *` the callee
  writes, and the caller reads the typed fields afterwards
  (`vkGetPhysicalDeviceSurfaceCapabilitiesKHR`). An `extern "C"` record binding declared without an
  initializer gets `sizeof(struct)` zeroed bytes instead of nothing, so `&mut r` is a valid pointer
  and a callee that reads a field it does not overwrite reads 0 - but the binding still holds no
  *value*: reading a field (or moving the record) before a foreign call or an assignment wrote it is
  refused with `use of moved, borrowed or partially initialized value`, which is what keeps a zeroed
  handle from being read as one. With handle-typed fields filled by C through `&mut`, or seeded from
  handles the program already holds, `vkQueueSubmit`'s `pCommandBuffers` and `VkPresentInfoKHR`'s
  `pSwapchains` are expressible as arrays of handles. The borrow rules are the call-scoped ones
  `cptr` already had, with named failures for each hazard: `cptr needs a named record: the address of
  a temporary would not outlive the pointer`, `cptr takes the address of an extern "C" record; a
  Grail record has no C layout`, `the value handed to C as a writable pointer is already borrowed in
  this expression`, `the value handed to C as a read-only pointer is already mutably borrowed in this
  expression`, and `an extern C out-parameter needs a binding to write into; a temporary record would
  be discarded`. Also fixed, on the way: an embedded record's place (`o.inner`) is a proxy slot
  holding its interior address, so `&mut o.inner` no longer reads the first field as an address
  (it faulted on x86-64 and wrote through a stack slot on assignment); and a C callback's record
  parameter is now borrowed rather than owned, because the epilogue used to free C's struct, which
  aborted in the runtime's free path at exit after `main` had already printed everything. Verified
  by `tests/ffi/record_pointers.grl` against a real C shim on all three targets (including a handle
  Grail reads out of an array C filled comparing equal to the one C hands back), fourteen new cases
  in `tests/native-cases.json`, and a new book chapter (`Calling C`) whose Grail and Rust twins link
  one C file.

- `parallel_for_chunks` and a job handle: the two things the pool surface was missing, and the
  measured entry cost the owned-chunk shape paid is gone. `parallel_for_chunks(&mut data[a: b],
  chunks, f)` splits an exclusive slice into disjoint exclusive chunks and hands each job `&mut [T]`
  over its own elements, so no element is moved or copied: the same 3M-u64 CPU-bound pass measures
  94 ms through `pool::for_chunks` (which moves every element into its chunk) against 38 ms in place
  as one job, 63 ms against 11 ms as eight. The split is `size = ceil(n/chunks)`, chunk `k` being
  `[k*size, min(n, k*size+size))`, so disjointness and coverage are arithmetic rather than a checked
  property, and the runtime still asserts the chunk lengths sum to the element count. The element
  type goes through the same structural walk `parallel_map` uses, asking `transferable`: `&mut
  [File]` is refused exactly as `&[File]` is. A chunk callback cannot reach outside its chunk:
  the argument is an exclusive loan of the whole vector, so a capture that could alias that data - a
  move, a shared slice, a sub-range's slice - is a borrow error at the call site; a captured `&mut
  [T]` is refused by name (every worker calls one closure); and the slice a callback holds has its
  own length, so an index past it is a bounds abort. `parallel_spawn(f) -> Job<R>` with
  `parallel_join(h) -> R` is spawn-then-wait as two statements, on the runtime's existing submit and
  wait. `Job<R>` is a move-only type kind like `Task<R>`: the closure's environment moves into the
  job through a heap box the job drops on the worker that ran it, the result is owned and
  transferable, a callback that captured a borrow is refused (the handle's type records no such
  lifetime), a job may not return another handle, sharing a handle is denied, and the handle's drop
  *waits* - so dropping it instead of joining is a wait-and-discard, never a leak or a double free.
  Nothing reachable from a handle is frame memory and it has exactly one owner, which is why it may
  outlive the frame and cannot dangle. `lib/pool.grl` wraps all three as `chunks_mut`, `spawn` and
  `wait`. Native cases: `pool-chunks-mut-split` (uneven, one, zero, more chunks than elements, more
  chunks than workers, a sub-range, empty, nested chunking, f32/u32/bytes, all by content),
  `pool-chunks-mut-timing`, `pool-job-handle`, six chunk rejections, four job rejections, the
  out-of-chunk bounds abort, and the borrowed-closure refusal. No reseed is needed: the compiler's
  own sources do not call the new builtins.
- Separate compilation, stage 4 (first half): **a build cache**. `grail build --cache` reuses what a
  previous build produced, from a content-addressed store under `.work/cache/<target>/`. An unchanged
  program is not rebuilt at all, and an unchanged module is not reassembled: the store is keyed by what
  actually determines each output - a module's source digest, the digests of the interfaces it reads,
  the compiler's own digest, the target, the assembler's and the linker's identity, and the compiler's
  whole flag vector - and each entry is filed under the digest of its bytes, published by rename, and
  re-hashed before it is ever reused, so a corrupted or unreadable entry is a miss and never a wrong
  binary. `grail build --cache` reports one line - what hit, what missed by name, and what ran. The
  flag implies `--split`, so it is available where that is: the Linux x86-64 assembler path, without
  `--debug`. `grail build` also accepts `--overflow=wrap|checked`, which until now only the compiler
  driver itself could pass. Without `--cache` nothing about a build changes. `tools/cache-test.mjs`
  proves the six claims (a cached build is the uncached build byte for byte, a second build is a full
  hit and 12x faster, one module's edit misses that module and its importers and nothing else, a flag
  change misses everything, a tampered interface misses the importer, corruption rebuilds and repairs)
  and pins the one thing the module level cannot do yet: the emitter numbers its local labels over one
  stream, so an edit re-spells every module emitted after it and those modules reassemble.
- Separate compilation, stage 3: **generic bodies in interfaces**. A type-generic template's body
  now travels in its module's interface (`// grail-interface 2`): one quoted `line` row per source
  line under the template's `fn` line, so a changed statement is a changed line in a review diff.
  `grail ... --use DIR` builds a module against a directory of interfaces whose sources are not on
  the command line at all, and `--serve DIR` makes the module that *defines* a template emit the
  instantiations its importers asked for. A specialisation's symbol is now content-addressed -
  `f_<module>_<name>$<16 hex of the SHA-256 of module::name plus the canonical argument types>` -
  so the definition and the reference agree in every compilation order, and the body is emitted
  once, in the defining module's part, while importers reference it; each importer writes
  `DIR/<module>.sreq` naming what it references, and the defining module's build serves that list.
  The key is a *total structural* description of the type (`type_key`), not the interface's spelling
  and not an index: naming a type happens on every scope exit and every call, so it must never be
  able to fail a build, and it embeds no number this run chose - a proof carries its interface's
  name, an unknown store kind has its payload walked as a type, and one definition is emitted per
  key rather than per interned index. Drop helpers are content-addressed the same way and `.weak`
  for the same reason, closure bodies are named after the module that owns them rather than by an
  index in this run's closure table, and a request file carries the environment records its keys
  mention, so a generic instantiated on a capturing closure can be served by the module that defines
  it and two importers still share one body. Capability metadata keeps its force across an
  instantiation: a `T: Share` bound and a handle's audited `transfer`/`share` are read from the
  interface, so instantiating a template on a handle that is transferable but not shareable is
  refused by name (`type does not satisfy Share: handles::Lock is thread-affine (declared
  transferable, not shareable)`) whether the module came from source or from its interface. Also
  fixed: the interface manifest was never actually enforced (`iface_words` returned the whole file
  as one word), and `--verify` now covers carried bodies. `tools/interface-test.mjs` proves one
  emitted body across two importers, identical behaviour against the source build, the refusal by
  name, and that a template without a body is refused. What stage 3 does not do: a body is still replayed (re-parsed and re-checked) once per
  instantiation at the *caller*, because the checker is per-instantiation and there is no typed IR
  yet; only emission moved. A request line must be written in the interface format, so an
  instantiation on a type with no spelling is refused by name at that boundary (a type that cannot
  be spelled cannot appear in an exported signature either). A generic instantiation
  discovered while a defining module replays one of its own templates is filed in *its* request
  file, so a driver has to iterate to a fixpoint (stage 4).

- Separate compilation, stage 2: **checked module interfaces**. `grail check --interface DIR` writes
  one `DIR/<module>.iface` per module plus `DIR/interfaces.manifest`; `grail build --interface DIR`
  reads them instead of the modules' sources, and refuses by name when an interface is missing, when
  the source it was built from no longer hashes to the digest it records, or (with `--verify`) when
  it disagrees with the module. An interface carries what an importer needs to check a call -
  exported declarations with their parameter and return types, types with their full structure, and
  the audit results that must not be re-derived (`handle ... transfer= share=`, and a closure type's
  environment record) - and nothing a body would carry. Text, versioned, one declaration per line,
  sorted by name, with a digest over the file. `tools/interface-test.mjs` proves that a program built
  against interfaces behaves like the program built from source (corpus, and the compiler compiling
  itself), that stale and tampered interfaces are refused - an edited `transfer`/`share`/environment
  entry, a re-digested file, and a file whose manifest entry was rewritten - and that an interface
  leaks no body, no local name and no synthetic declaration. Bodies and generic templates still come from source: that
  is stage 3 (bodies in interfaces) and stage 4 (one object per module, and the cache).

- RHI increment 4a, the shader side: HLSL compiles offline to SPIR-V, the bytes are committed, and
  the one create info that carries them is expressible today. `abundance/tests/shaders/
  rhi_triangle.hlsl` is the source of truth (one vertex and one pixel stage);
  `bun abundance/tools/build-shaders.mjs` compiles it with `glslangValidator -D -V --target-env
  vulkan1.2 -S vert -e vs_main` (and `-S frag -e ps_main`), runs `spirv-val` on each module, extracts
  the `VertexIn` layout, cross-checks that extraction against the compiled stage's own `OpName` /
  `OpDecorate Location` / `OpTypeVector` decorations, and writes the `.spv` files, a manifest
  (`abundance/tests/shaders/shaders.json`: compiler version, exact flags, entry points, sizes,
  fnv1a64 hashes, layout, cross-check status) and `abundance/src/rhi_shader_blob.grl` (the bytes as
  constants plus the layout). All four artifacts are committed, so a clean checkout builds, tests and
  renders with no shader compiler installed; the generator is a maintenance tool, not a build step.
  `abundance/src/rhi_shader.grl` (new) holds the loader shape - `VkShaderModuleCreateInfo` as an
  `extern "C" record` (40 bytes; sType 0, pNext 8, flags 16, codeSize 24, pCode 32) whose `pCode` is
  the one pointer inside a Vulkan create info the FFI can already fill, `unsafe cptr(&bytes)` - plus
  a small SPIR-V decode (magic, version, generator, bound, schema, first `OpEntryPoint`) that checks
  a module the way a loader can without a driver. `abundance/tests/rhi_shader_probe.grl` (new) is
  the fourth probe and the only graphics check that links nothing at all: it runs under `env -i`,
  with no display, no ICD and no shader compiler, reconstructs the bytes from the generated
  constants, hashes them with Abundance's own `fnv1a64` and matches the recorded hash, decodes the
  header and entry points, builds the create info and checks `codeSize`, and validates the layout
  (declaration-order locations, contiguous offsets, stride equal to the sum). The suite runs it in
  the default set and also ties its printed hash to the manifest; the generator's own `--check` is
  two-tiered - everything that needs no toolchain always runs, and the recompile demands identical
  bytes only when this machine's glslang matches the version the manifest records, otherwise it
  prints `shader hash differs (glslang 11:16.6.0 recorded, <detected> present): not compared` and
  passes. Verified with `DISPLAY`/`WAYLAND_DISPLAY` unset, `VK_ICD_FILENAMES=/nonexistent` and
  `glslangValidator`/`spirv-val`/`spirv-dis` off `PATH`: `rhi_shader: ok`, the other three probes
  skip, `10 test program(s) passed, 4 RHI probe(s) run`. Handle accounting in the swapchain probe is
  now per class (`rhi.handles.window`, `.instance`, `.surface`, then `.total`), and a disagreement in
  any class or in the total fails the run, so increment 4b's device, swapchain, images, views,
  semaphores and fences arrive as classes rather than as one count they could hide in.
- RHI increment 3: `abundance/src/rhi_surface.grl` (new) creates a real `VkSurfaceKHR` from the
  SDL3 window and reads back what that surface accepts. The instance is now created with the
  platform's own extension set: `abundance_rhi_vulkan::instance_create_info_with(extensions, count)`
  fills `ppEnabledExtensionNames` from a `CPtr`, and `SDL_Vulkan_GetInstanceExtensions` returns
  exactly that shape — C's `const char *const *` — so the array is C's memory and Grail never has to
  build an array of strings (this host: 2 extensions for the `x11` driver, and the loader offers
  `VK_KHR_surface`, `VK_KHR_xlib_surface` and `VK_KHR_wayland_surface`, each named in the report).
  `SDL_Vulkan_CreateSurface` reaches the platform `vkCreate*SurfaceKHR` for whichever video driver
  served the window, so no platform extension is named in Grail. `VkSurfaceCapabilitiesKHR` is an
  `extern "C" record` (52 bytes of scalars, offsets checked with a C program against
  `offsetof`/`sizeof`) rather than a byte buffer, and the format and present-mode lists are
  fixed-capacity records of scalars — the record *is* the array, the count query and the seeded fill
  call are the idiom the physical device list already used. On top of that the module makes the four
  decisions a swapchain needs, each a stated rule instead of a constant: format (sRGB first, ties
  keeping the surface's order, `format_by application` when the surface reports no preference),
  present mode (MAILBOX, then FIFO, then FIFO_RELAXED, then IMMEDIATE), extent (`currentExtent`
  unless it is `UINT32_MAX`, otherwise the window's pixel size clamped into the surface's range) and
  image count (`minImageCount + 1`, clamped to a non-zero `maxImageCount`). The device is now chosen
  as the highest-ranked one that has a queue family which both runs graphics and presents to this
  surface (`vkGetPhysicalDeviceSurfaceSupportKHR`), not merely the fastest device on the machine.
  `abundance/tests/rhi_swapchain_probe.grl` (new, wired into `tools/abundance-test.mjs` as the third
  probe) prints the whole chain, takes the frame count as `argv[1]` (`GRAIL_RHI_FRAMES`, default 3),
  skips with `rhi.status skipped no-display` where there is no display server, and asserts its own
  handle balance (`rhi.handles created 3 destroyed 3 live 0`, a leak fails the run) because the
  validation layer is not installed on this host; where it is installed the suite forces it on
  through the loader (`VK_LOADER_LAYERS_ENABLE`/`VK_INSTANCE_LAYERS`) for a second run and fails on
  any validation message, after requiring the layer's manifest to name a real ELF shared object,
  since the loader skips a broken layer silently. What did *not* land is the swapchain itself and
  everything downstream of it — device, `VkSwapchainKHR`, image views, the render pass, the clear and
  the present — because all of them need an expression whose value is the address of an `extern "C"`
  record Grail owns, and the submit/present arrays are arrays of *handles*, which cannot even be
  seeded. The probe reports `rhi.swapchain.result frames 0 of 3` plus one `unavailable` line per
  blocked call rather than pretending; docs/rhi.md lists the calls and what each one needs.
- Borg's goal, plan and work list fold out of a journal, and `borg` serves them (`borg/src/aggregates.grl`,
  `borg/src/cli.grl`). Four new journal kinds join the five transcript ones, each with the journal's
  encoding — a tag, a little-endian length and a body of length-prefixed texts — and each refusing by
  name what it cannot represent: `goal_created` (6) carries a goal id, an objective and an optional
  token budget; `goal_updated` (7) a goal id and a status of `active`, `complete` or `blocked`
  (`ModelGoalStatus`, contract.rs:2337); `plan_projected` (8) a participant, a workspace revision and
  its items (`id`, `content`, a `pending`/`in_progress`/`blocked`/`awaiting_review`/`completed`
  status, and the port's own optional `work_id`); `work_projected` (9) a revision and its shared work
  items with their assignees and states. A status outside its enum is `unknown-goal-status` or
  `unknown-item-status` from the reader rather than a variant coerced to a neighbour. The fold is its
  own module with its own refusals: `goal-exists` (a second `goal_created`), `no-goal`, `goal-mismatch`
  (an update naming another goal), `goal-finished` (any update of a completed goal — the terminal
  rule), `unknown-work` (a plan item pointing at work the journal never carried), `duplicate-item` and
  `duplicate-work`; replay carries them with the event index and its own reason, so a diagnostic names
  the rule that stopped it. The one rule that does not refuse is the model's: a plan projection that is
  not newer than the one applied is dropped and counted (`plans_stale`), exactly as
  `session_store.rs:1178-1191` compares revisions, and the drop is decided before the items are
  examined. `borg_replay::State` now holds the goal, the plan and the work list, with the session
  fingerprint unchanged (a journal without aggregates keeps its checksum) and a second fingerprint over
  the aggregates only. `borg daemon` serves the transport while keeping the folded session between
  connections (`borg_daemon::serve_stateful`, `serve_one` untouched), stamps the sequence, event id and
  timestamp onto what a client sends — the daemon appends, so a command cannot write the cursor in two
  places — and answers with the reply frame *and* a new state frame (opcode 6) carrying the aggregates,
  whose statuses are re-read through the same functions on arrival. The client has `create-goal`,
  `update-goal`, `set-plan` (a work projection, then a plan that may name it), `list-work` and `attach`,
  each printing what came back off the socket rather than what it meant to send, and each refusing with
  the model's own names; `bad-argument` is the command line's own for a command it cannot read. The
  transport's unknown-tag fixture moved from tag 6 to tag 10 because 6 is now a real kind, and what it
  prints is unchanged. `borg/tests/aggregates_test.grl` covers every refusal, the stale plan drop, a
  plan taken over by another participant, a sequence gap, a cut stream, and for every fixture three
  properties — the same journal through the byte stream, twice-replay identity, and prefix-plus-apply —
  then runs a whole command session on 127.0.0.1 where each answer is compared with the daemon's own
  account of what it sent. The committed reference (`borg/tests/parity/ref/src/bin/aggregates.rs`)
  implements the kinds, the fold, the fingerprint and the command session independently, over its own
  socket.
- The Borg transport layer carries the typed event stream over TCP with the refusals the journal
  already has (`borg/src/frames.grl`, `borg/src/daemon.grl`, `borg/src/client.grl`). A frame is one
  encoded event — the journal's `u8 tag | u32 LE length | body` — so the wire and the journal are the
  same bytes by construction (`frame_of` is `encode_stream` over a one-event journal, `frames` is
  `encode_stream`), and a frame captured off the socket replays through the file reader. Tag `0`
  marks a control frame: `hello` (version, session), `hello_ok`, `hello_refused` (both versions as
  numbers), `reply` (the folded sequence/status/events plus any refusal) and `end` (the batch is
  complete). Refusals are named and numbered, and the reader's codes 20-24 pass through unchanged:
  `version-mismatch` 10, `session-mismatch` 11, `not-handshaken` 12, `frame-too-large` 13,
  `short-read` 14, `bad-control` 15, `bad-reply` 16, `replay-refused` 17, then `unknown-tag` 20,
  `truncated-event` 21, `length-overflow` 22, `bad-field` 23 and `trailing-bytes` 24. A cut stream
  fails the way the file reader fails, as a function rather than a claim: `journal_code(14)` is 21
  and `journal_code(13)` is 22, and the test prints both columns for the same bytes. A declared
  length is refused at the header before its body is waited for, and the ceiling is the journal's
  own `MAX_EVENT_BODY`, so an accepted frame is an event a journal file could hold. The daemon folds
  each event as it arrives with `borg_replay::apply` and answers a refusal with the index and the
  fold's own reason; the client returns that refusal instead of reporting success, and a peer that
  closes without answering is `short-read` rather than silence. Opening the listener is an explicit
  grant — `borg_daemon::listen` takes `authority::Authority` and calls `authority::listen`, and
  `borg_client::connect` calls `authority::connect` — so the grant decides who may listen and who may
  connect, while `accept`/`read_fd`/`write_fd` stay ambient: what the peer does after connecting is
  not covered. No authentication, encryption, reconnection or multiplexing, and the docs say so.
  `borg/tests/frames_test.grl` prints every frame in hex, decodes the capture whole and one byte at a
  time, hands it to the file path, builds all thirteen refusals from the bytes a peer would send, and
  runs a real loopback round trip per fixture (a clean fold, a frame that decodes and replays to a
  refusal, a foreign session, a version mismatch) plus a peer that stops inside a reply frame, and a process grant that opens neither a listener nor a
  connection; the
  daemon's account of its answer is compared with the line the client decoded from the socket. The
  committed reference (`borg/tests/parity/ref/src/bin/frames.rs`) implements the frame layout, the
  refusal classification and the fold independently, including its own socket, and the module is
  called `frames` because `borg/src/transport.grl` already holds the local-control channel's rules.
- Borg journals replay into the in-memory session state (`borg/src/replay.grl`). The module folds a
  decoded event stream with the rules of `SessionState::reduce`/`apply` (session_store.rs:906-959,
  1036-1041, 1320-1336) over the five transcript kinds `borg/src/events.grl` carries, and
  reconstructs exactly what those kinds write: the sequence cursor, when the session started, the
  activity clock, status and detail, the title with the rule that a generated title is final
  (session_store.rs:952), the first and latest prompt and the latest reply. It folds typed events
  rather than bytes, so it cannot disagree with the reader about what an event says, and
  `replay_stream` propagates the reader's refusal — a cut tail, an unknown tag — instead of folding
  the rows that arrived before the cut; a refused stream yields no state at all. An event that cannot
  apply is refused by name with the index that stopped the fold and never skipped or forced:
  `sequence` (not the expected `last + 1`), `session` (another session's `session_id`),
  `unknown-actor` and `unknown-message-status` (outside `EventActor`'s and `MessageStatus`'
  four variants), and `stream` (the reader's own code). The one rule that drops rather than refuses —
  a title event while the current title was generated — is the model's own rule, so replay counts
  the drop (`titles_frozen`) instead of rejecting a journal Borg writes. `borg_events` gains typed
  accessors (`title_value`, `status_value`, `actor_value`, `tokens_value`, ...) so a fold can tell an
  absent optional from a text that happens to be `-`, and `no_event()`. `borg/tests/replay_test.grl`
  covers a clean journal, the empty one (which replays to the default state, not an error),
  out-of-order, unknown actor, unknown message status, a foreign session, the sticky title, and a
  journal read back from the typed byte stream intact and cut short, then generates journals: a
  seeded xorshift makes six events per seed and each seed must replay to the same checksum twice and
  to the same checksum as `prefix + [last]` versus `replay(prefix)` plus a direct `apply` — refusals
  compared by index and reason, so both sides must fail identically. The committed reference
  (`borg/tests/parity/ref/src/bin/replay.rs`) is an independent implementation of the same rules and
  of the byte stream, and the suite compares fingerprints and FNV-1a checksums field by field.
  `docs/design/borg-agent-port.md` records what replay reconstructs, the refusal table, and what it
  cannot cover yet: a real journal also carries `PlanProjected`, `SubagentRegistered` and provider
  events, whose unknown tags the reader refuses, so replaying one fails by name rather than
  returning the subset it understood.
- Windows task scheduling is now the same as Linux: a task is green on Windows, not an OS thread.
  One scheduler thread runs the tasks cooperatively, a task runs until it yields or blocks, and
  suspension parks the task rather than the thread. The switch is a Win32 fiber
  (`CreateFiberEx`/`SwitchToFiber`/`DeleteFiber`/`ConvertThreadToFiber`, declared in
  `compiler/os-windows.grl`, since `raw_switch` is not lowered for the PE targets) and the run queue
  parks on the same address wait (`WaitOnAddress`/`WakeByAddressAll`) the Linux build uses for its
  idle word. Windows has no epoll/eventfd/timerfd, so the platform reports no reactor
  (`rt_os_reactor()` = 0) and the runtime parks tasks *inside* blocking host operations instead:
  `host::read_file`, `host::write_file`, `host::command`, `host::read_fd`, `host::write_fd` and
  `host::sleep_ms` run the blocking call on a helper thread (`rt_offload`) and suspend the task, so
  another task keeps running, exactly as the reactor does on Linux. What is now identical:
  `spawn`/`join`/`task_scope`/`parallel_map`, cancellation, scope-exit joining, the run-until-it-
  yields-or-blocks rule, and the blocking-operation handoff. What still differs: Linux works the
  queue with one scheduler thread per CPU (4-64) so two ready tasks can run at once, while Windows
  has one thread and therefore a FIFO, deterministic interleaving; task stack cost is 256 KiB of
  mapping on Linux and a 64 KiB-in-256 KiB fiber on Windows. The previous thread-per-task scheduler
  is kept as an explicit opt-in, `GRAIL_TASKS=thread`, on every platform: each task then owns an OS
  thread, a task that never yields still progresses, suspension blocks that thread, `rt_wait_fd`
  returns immediately and `rt_reactor_fence` is a no-op. It is the better shape for CPU-bound
  fan-out once a `Send`/`Sync` check exists; there is none yet, so it is not the default. A program
  ported from Linux keeps its task semantics and must only stop relying on global interleaving
  order. Verified by execution under Wine (`bun tools/windows.mjs check`):
  `tasks-scope-and-parallel-map`, `tasks-sleep-overlap`, and the new `tasks-interleave-at-yield`
  (deterministic FIFO interleaving at yields), `tasks-sleep-progress` (a parked sleeper does not
  stop another task), `tasks-read-file-offload` (`host::read_file` from a task offloads and another
  task runs) and `tasks-thread-mode` (the opt-in mode still runs). The same four programs are also
  executed as Linux ELF where their result is platform-independent.
- Transferable and shareable, derived and default-denied, and a real soundness hole closed. The
  parallel surface asked one question of a type and answered it with a structural walk; the walk is
  now the design note's two properties and it reaches a closure's captures. `transfer_capability(c,
  ty, shared, trail, depth)` keeps its role as the single derivation engine and `shared` selects
  which property is asked, so `transferable(T)` and `shareable(T)` come from one recursion and stay
  genuinely distinct (a movable-but-not-shareable decoder context is one and not the other). Rules by
  kind: scalars (now including `char`) are both; a record, enum or union is both when every field is;
  a vector is its element; a typed slice is its element and is shareable only read-only; `&T` is
  shareable when `T` is (so a `&File` is refused even though nothing can be written through it);
  `&mut T` transfers but is never shareable; `Mutex<T>` and `Task<R>` and `byval(R)` behave as the
  table in `docs/design/parallelism.md` says; `Scope<C>` is neither. **A foreign handle is neither
  unless its own declaration says otherwise** - `handle File: transferable;`, `handle
  PhysicalDevice: transferable, shareable;`, `handle Window;` - and `shareable` alone is an error
  because sharing implies moving. `sys_grail` audits `File`, `Socket` and `Process` transferable-only
  (owned OS resources with no wrapper-side state, but nothing serializes two users of one) and
  `Thread` as neither (disposal is the creating thread's bookkeeping, and the shim hands every handle
  out through a `_Thread_local` slot); `abundance/src/rhi_vulkan.grl` audits `Instance` as neither
  (created and destroyed on the display's thread, every child dead before it) and `PhysicalDevice` as
  both (it owns nothing and every operation is a query). The hole: a closure type carried only its
  signature, so `parallel_map` checked the item, the result and the context but never the callback,
  and `g := |x: u64, u: u64| -> u64 touch(&h, x)` compiled - a plain-data signature with a
  thread-affine capture that every worker could reach. The environment is now part of the closure's
  type (`Ty.env`, interned into the type key, so two closures with one signature and different
  captures are the different types they already were as layouts), the walk classifies every capture,
  and `parallel_map` also refuses an `FnMut` callback because every worker shares one closure object.
  Rejections name the field instead of the type: `cannot share closure capture `a`: a.file is
  thread-affine (a foreign handle with no audited classification)`, `cannot share parallel_map
  context: file is thread-affine`, `cannot transfer spawned result: thread-affine (a foreign handle
  with no audited classification)`. The parallel surface speaks `transferable`/`shareable`; the
  opt-in generic bounds keep their old `Send`/`Share` names, since renaming a user-visible bound is a
  separate language change. `CStr`, `CPtr`/`CMutPtr` and `CFn` stay denied. Pinned by 12 cases in
  `tests/native-cases.json` - two accepted (a closure capturing a record of plain data and a shared
  slice of numbers, and a transferable handle crossing as a spawned result) and ten rejected, each
  with the field in its diagnostic. A scoped job primitive calls `require_capability_named` for the
  values it moves and `require_parallel_closure` for the closure it accepts, `shared` = 1 when the
  environment is called by several workers. Classification must reach B1's interface files before
  separate compilation can check it; `docs/design/parallelism.md` records the table, the audit and
  that contract.
- Parallelism stage 1: a real bounded work-stealing job pool in the runtime, and `lib/pool.grl` as
  the safe surface over it. The pool is one process-wide singleton created by the first parallel
  call: N workers (default max(4, available CPUs) capped at 64, `GRAIL_POOL_WORKERS` overrides it),
  one bounded ring per worker plus a bounded injection ring for threads that are not workers, owner
  push/pop at the tail (LIFO) and thieves taking from the head (FIFO) with a rotating victim cursor,
  and idle workers parked in the kernel on one futex wake sequence read *before* each scan, so no
  wakeup is lost and nothing spins for work. A job owns its callback, one environment word, one
  argument word and the single word it returns; the worker publishes the result with a release store
  and the thread that waits for the job frees the record, so every allocation has one releasing
  thread. A waiting worker runs queued work itself, so nested parallelism cannot deadlock even on a
  one-worker pool. `parallel_map` is now a client of the pool - it submits a few contiguous owned
  ranges per worker and waits for every job - instead of creating and joining threads per call, and
  it asserts that the per-job item counts sum to the item count, so an item written twice or not at
  all aborts rather than returning a plausible wrong answer. `rt_offload` stays the blocking path;
  a blocking foreign call never runs on a pool worker. Safe surface: `pool::map(items, f)`,
  `pool::run(count, f)`, `pool::for_chunks(data, chunks, f)` (consume a vector, one contiguous owned
  chunk per job, results concatenated in chunk order) and `pool::join(a, b)`; results are always in
  input order, and the ownership rule "everything a job's closure touches it owns" is stated in the
  module. Once the structural classification landed, item, result, context and the closure's
  captured environment are all classified: a handle - bare, inside a record, or captured - is refused
  by name (`cannot share closure capture `h`: h.file is thread-affine ...`), as are an `FnMut`
  closure shared with workers, a `Task` handle, an exclusive borrow, a mutable slice and an
  unproven type parameter. `CStr`, `CPtr`, `CMutPtr` and `cfn` stay deliberately unclassified, so
  they are refused as unclassified foreign authority rather than silently allowed; a classification
  states that a value may move, never that the library behind it tolerates that, and `unsafe module`
  code can still build anything - the safe surface is as strong as the classification under it, not
  more.
  Measured on 24 reported cores, 3M CPU-bound elements, one job vs four: 27 ms → 8 ms (3.4x) at the
  default size, 28 → 12 ms (2.3x) at four workers, 27 → 28 ms (0.96x) at one. Six native cases:
  owned-chunk split equals the sequential answer, `map` order independent of completion order,
  uneven work without deadlock, nested parallelism on a one-worker pool, an aborting job that
  ends the process instead of hanging, and the speedup assertion (which skips honestly below four cores).
  The test harness gained an `env` field for the one-worker case.
- Fixed an interaction between the pool and the Windows green scheduler, found only when the two
  branches met: the pool cached its pointer in `raw_state()+88`, and the green scheduler's new
  task-mode cache then stored the resolved mode (1) there, so a program that ran a `task_scope`
  before its first `parallel_map` read 1 as the pool pointer and faulted at address 0x9 - correct
  output first, then SIGSEGV inside `rt_parallel_map` (`program-parallel-primes`), and the same page
  fault under Wine. The pool's words are now 3200/3208, taken from named accessors that appear in a
  single process-state table in `compiler/runtime.grl` (word, owner, accessor, claimant) instead of
  a comment nobody owns. The same review found a second borrowing of the same kind: the pool read
  "which worker am I" from thread-record word 48, which is free on Linux but is the Windows address
  wait's per-thread expected-value slot, so every Windows wait and the pool marker fought over it;
  a worker now publishes its thread record into its own worker block and `rt_pool_self` scans the
  worker array, touching no thread-record word on any platform. Pinned by `pool-from-green-task`
  (parallel work entered from a task scope and from spawned tasks), which fails with 139 against the
  merged-but-unfixed runtime.
- Book and status documents match the 2026-11-10 increments. The book (54 examples, each with its
  Rust comparison) adds strict bool conditions (`strict-condition`: an integer condition is refused
  in both languages), consuming loops over owned elements (`consume-owned`) and range loops in
  *Branches and loops*, and a *Calling C* section in *Cleanup and current boundaries* with the
  `byval` record marker (`byval-record`), the handle and out-parameter surface, and what the FFI
  still refuses. Claims that map iteration, owned-element consumption, `FnMut`, borrowed captures,
  `char`, the sampling profiler, `.debug_info` locals or the language server were missing or
  rejected are gone, and so are the comparison notes that said Grail comparisons produce a number
  rather than `bool`. [docs/design/language-readiness.md](docs/design/language-readiness.md) now
  reports B1 stage 1, B2, B6 and B7 as implemented, with the Windows `byval` refusal;
  [docs/platform-status.md](docs/platform-status.md) replaces the stale FFI, tooling and COM rows;
  [docs/ffi.md](docs/ffi.md) documents the `byval` marker instead of listing it as decided-but-absent;
  and [docs/design/decisions-b2-b6.md](docs/design/decisions-b2-b6.md) records what landed for B1,
  B2 and B7.
- Fixed: the `FnMut` entry below had a duplicated half-paragraph spliced into it.
- Explicit environments for spawned processes: `host::command_with(argv, env)` runs `argv` with
  `env` as the child's *whole* environment and returns the same status encoding `host::command`
  returns (0–255 exit code, 128+N for a signal, 256+errno when the child could not be started, and
  278 = 256+EINVAL for a vector or entry that cannot be used). Nothing is inherited: an empty vector
  means the child starts with no environment from us, and a malformed entry (no `=`, or an empty
  name) is refused before anything is spawned, because `execve` would otherwise start the child with
  no environment at all and `CreateProcess` rejects the block. Both vectors are consumed, like
  `host::command`. `host::environment()` reports this process's own environment as `NAME=VALUE`
  entries, which is the additive spelling made explicit — `env := host::environment();
  env.push("APP_MODE=batch".copy()); host::command_with(argv, env)`. The executable search stays in
  the parent against the parent's `PATH`, so an explicit environment does not stop `"sh"` from being
  found. The spawn moved out of the portable runtime into the platform modules: `rt_spawn_wait` is
  `fork`/`execve`/`wait4` in `compiler/os-linux.grl` and `compiler/darwin.grl`, and `CreateProcessA`
  with an explicit (sorted, double-NUL-terminated) environment block in `compiler/os-windows.grl`,
  which also makes `host::command` work on windows-x86_64 for the first time: a NULL block inherits,
  a non-NULL one replaces. The Windows argument vector is quoted back into the command line with the
  `CommandLineToArgvW` rules; the ARM64 PE target reports the call as unimplemented because the
  ARM64 Win32 call path passes seven register arguments and `CreateProcessA` needs ten. Tests: six
  native cases (`command-with-env-carries-its-entries`, `-empty-env-clears-everything`,
  `-built-from-the-inherited-one`, `command-without-env-still-inherits`, `-refuses-malformed-entry`,
  `-reports-a-signalled-child`) and four Windows cases executed under Wine (`command-with-env`,
  `-inherit-env`, `-empty-env`, `-argv-round-trip`) plus one static ARM64 build. A host builtin that
  `compiler/*.grl` itself calls needs a **two-step bootstrap**, because the checked-in seed *is* the
  compiler and carries the `host::` table of the commit it was recorded from: stage a compiler that
  knows the builtin and point `GRAIL_COMPILER` at it, then reseed with that same variable
  (`bun tools/bootstrap.mjs update all` — `bootstrap.mjs` uses `buildCompiler()`, which honours
  `GRAIL_COMPILER`), then confirm on a clean tree (`rm -rf .work && bun tools/native.mjs build` with
  no `GRAIL_COMPILER`). `bun tools/bootstrap.mjs verify x86_64` is the 20-second version of that
  check: it still reports "checked-in bootstrap is stale" when `GRAIL_COMPILER` is set, which is the
  case the suites cannot catch. Until the reseed lands, a plain build of this branch fails at the seed with
  `unknown function` for `host::environment`; `docs/testing.md` records the cycle next to the other
  reseed notes.
- `authority::spawn_with(&a, argv, env)` gates an explicit environment with the same `may_spawn`
  grant as `authority::spawn`: spawning with an environment of your choosing is still a spawn, so
  neither route becomes a way around the other, and a file grant is refused exactly as it is for a
  plain spawn. `authority::environment()` returns this process's own entries so a program compiled
  with `--deny-ambient-host` can build an additive environment without opting into `use host;`;
  reading your own environment stays ungated, because every grant already implies the process can
  see its own configuration. What the grant covers is unchanged and still narrow: it decides
  *whether* a child starts, not what program it runs, and the child's own environment reads are
  outside the model.
- `grail profile` no longer uses a rendezvous file: the arming request
  (`GRAIL_PROFILE="1 RATE CAPACITY SAMPLES"`) travels in the target's environment through
  `host::command_with`, the samples go to a private `mkdir`-claimed scratch directory under
  `TMPDIR`, and nothing is written to the target's working directory. A killed run can no longer
  leave a stale request behind, the target no longer needs a writable working directory, and
  concurrent profiles no longer collide on `.grail-profile/`. The runtime reads the variable at
  startup instead of a config file. A profiled program that spawns Grail children with the
  inherited environment now arms them too (they share one sample file); a child started with an
  explicit environment is not armed unless the request is copied into it. `tools/test-profile.mjs`
  now also asserts that the target still sees a variable the runner set, and that no
  `grail-profile-` scratch directory is left behind.
- Typed-IR F1, a sequence-header fact for the LLVM backend: the front end now records, beside the
  word stream, that a frame slot or a call's argument 0 holds a pointer to a 24-byte sequence header
  -- `{data, len, cap}` for a vector, `what` 2/3/4 with element width 8/4/1 -- and the LLVM lifter
  can consume it, so nothing in `.s`, `optimize.grl`, `machine.grl` or the native backend changes. A
  fact-carrying `call rt_slot` is lowered into an internal sibling of the accessor emitted from the
  same word-machine body with argument 0 typed `ptr nocapture nofree dereferenceable(24) align 8` and
  with `data`/`len` passed in, so the two header loads leave the body; the call site emits them once
  where the fact is established, at `align 8`, and passes them. `len` dies on
  push/pop/remove/insert/truncate/fill/clear and `data` on any growth or untyped write to the slot,
  enforced by invalidating the hoisted pair on any call that is given the header and is not a
  read-only accessor, and on any `leaq` of the slot; `cap` is never read, so a descriptor's
  uninitialised `+16` is unreachable from an F1 fact.
  `--verify-facts` now checks F1 too: non-null and eight-byte aligned, `cap >= len` through `+16`
  for a vector fact (the tripwire for a vector fact on a descriptor), and the element pointer inside
  `data .. data + len*width` for the wide accessors. `tools/test-facts.mjs` compiles a fixture with a
  deliberately wrong fact (`--f1-what=N`, a test aid) and shows the flag aborting in that check
  instead of printing a plausible number. Measured with `tools/bench.mjs --rounds 9`, F1 is
  **neutral, not a win**: `dereferenceable(24)` on the accessor's parameter is not re-derived for the
  inlined argument, so LLVM still will not speculate the header load out of a loop, and the lifter's
  own hoist is only sound where the establishing block dominates the call -- which the word machine's
  frame-spilled temporaries never make true on this corpus. Letting the call site re-read the fields
  when they are not established instead is measured at `nbody` 1.72x -> 1.89x, so that form is not in
  the tree. The fact and its verifier stay because a pointer type with an element width is the half
  that outlives this attempt. See `docs/design/typed-ir.md`, "Implemented: F1".
- B1 stage 1, per-module emission: `grail build --split` writes one assembly file per module
  (`OUT.NNN.module.s`) plus `OUT.parts`, assembles the parts concurrently and links them once,
  instead of one `.s` for the whole program. Emission is still a single pass — the optimizer inlines
  across modules and generic specialisations are emitted at the module that defines the generic — so
  the compiler records a `.grail_part <module>` marker where the module changes, the optimizer
  reports the offset each marker landed at (also after its inlining pass rewrites the stream), and
  the writer cuts the finished stream at those offsets. Splitting therefore copies nothing and the
  compile time is unchanged; what the parts cannot own goes to one synthetic `__start` part: the
  entry stub, `rt_state`, the TLS bases and `.note.GNU-stack`. String literals travel with the
  function that emits them (`.pushsection .rodata`/`.popsection` inside a module's own code), so
  there is no program-wide literal pool to duplicate or pool. Two things differ from the single-file
  build, both inherent to linking several objects: with `--split` a function another part calls is
  `.globl` (names, sizes and order unchanged; in the compiler's own build the symbol table is the
  same size and `sh_info` moves 2366 → 1139), and the linker inserts alignment padding between input
  sections (15 bytes across nine boundaries for the compiler, a few bytes for small programs). Code
  and data bytes do not change. A whole-program build is untouched: no `--split`, the same compiler,
  the same `.s`, byte for byte. Scope is the Linux x86-64 assembler path, without `--debug` and
  `--backend=llvm`; other targets keep the whole-program build because `machine::lower` rewrites the
  stream after the optimizer. `bun tools/split-test.mjs` (also `just test-split`, and a CI job)
  proves it on the book's `modules` example, a generic-heavy native corpus case and the compiler
  itself: the parts minus their `.text` prologue and the added `.globl` lines concatenate to the
  single assembly file byte for byte, the concatenated objects have the single object's `.text`
  length and match outside relocation fields, the linked programs have the same `.rodata`/`.data`/
  `.bss`, the same symbols and the same output, and `grail build --split` agrees with `grail build`.
  Measured on the compiler compiling itself (10 modules, 33 MB of assembly): compile 15.6–15.8 s →
  15.7–15.9 s, assemble 1.62–1.65 s → 0.99–1.02 s (−38 %), link 18–19 ms → 21–22 ms, total ~17.3 s →
  ~16.8 s. See `docs/design/separate-compilation.md`, "Stage 1 as built".
- RHI increment 2: `abundance/src/rhi_vulkan.grl` creates a real `VkInstance` and picks a real
  physical device. `vkCreateInstance` is called through the FFI's out-parameter form — `slot: &mut
  Instance` in the declaration, `&mut instance` at the call site — with `VkInstanceCreateInfo` as an
  `extern "C" record` holding the C layout (64 bytes; `sType` 0, `pNext` 8, `flags` 16,
  `pApplicationInfo` 24, the two counts and name arrays at 32/40/48/56), and `vkDestroyInstance` on
  every path that created one, the paths where a later call failed included. Physical devices are
  enumerated three ways through one symbol: a count query, a single handle slot (`&mut
  PhysicalDevice`, which is also the seed the array form needs) and a fixed-capacity record of
  handle fields, because a record *parameter* is the address of the record's fields and a handle
  cannot be read out of a byte buffer. `VkPhysicalDeviceProperties` (824 bytes) and
  `VkQueueFamilyProperties` (24 bytes each) are decoded at their C offsets, selection ranks device
  types (discrete, integrated, virtual, CPU) with an optional name filter, and the first
  graphics-capable queue family is chosen and printed. Two calls are deliberately not made:
  `VkApplicationInfo` cannot be passed and `vkCreateDevice` is not declared, because Grail has no
  expression whose value is the address of an owned `extern "C"` record, so a create-info cannot
  point at another struct (`pApplicationInfo`, `pQueueCreateInfos`, `ppEnabledExtensionNames`,
  `pNext`); `cptr` takes only byte sequences and views, and a `&mut` record is not an
  out-parameter slot. Both refusals are pinned as `ffi-reject-record-address` and
  `ffi-reject-record-out-param` in `tests/native-cases.json`, the probe says
  `unavailable extern-C-cannot-take-the-address-of-a-record` on its own output line, and
  `docs/rhi.md` states what that costs and what unblocks it. New program
  `abundance/tests/rhi_vulkan_probe.grl` replaces the Vulkan half of `rhi_device_probe.grl`, which
  now covers the SDL3 window alone; `tools/abundance-test.mjs` links one system library per probe,
  so the Vulkan probe runs on a machine with no display server while the window probe skips there.
- `FnMut`: a closure that mutates a captured value now works, with the rules B6 fixed in advance.
  The body is scanned for a store to a capture or to a place rooted at it (`n = ..`, `n += ..`,
  `s.field = ..`, `v[i] = ..`, `*r = ..`), a mutable borrow of it (`&mut n`) and method calls that
  may mutate their receiver; a closure with any such capture is `FnMut(...)` instead of `Fn(...)`.
  Only the written captures are mutable in the body, and the body's hidden environment parameter is
  `&mut Env`, so a store goes through an exclusive reference to the environment field and the
  existing loan checks apply. Calling an `FnMut` value needs a mutable binding (`mut f = |...|`),
  borrows the closure exclusively for the whole call and ends that borrow when the call returns: a
  second simultaneous call (`f(f(1))`) or a live shared borrow of the closure is rejected, and a
  `FnMut` closure used where `Fn` is required (the `Fn(...)` parameter type, a function value
  coerced to it, `vecs::sort_by` and the other stdlib callbacks) is rejected with a diagnostic that
  says why instead of being silently made exclusive. A closure that writes nothing stays `Fn` and is
  accepted where `FnMut` is expected, by value and as `&mut Fn(...)` for `&mut FnMut(...)`; `FnMut`
  is written in type position like `Fn`. A by-value `FnMut` parameter cannot be called, because
  parameters are not mutable storage — adapters take `&mut FnMut(...)`, and even then a callable
  reached through a reference parameter can be called once in straight-line code (the pre-existing
  `access has no live reference authority` limitation, which reproduces on `main` with `&Fn`).
  `compiler/native.grl`, fourteen cases in `tests/native-cases.json` (`closure-fnmut-counter`,
  `-disjoint-captures`, `-sequential-calls`, `-second-call-rejected`, `-shared-borrow-rejected`,
  `-not-fn-rejected`, `-sort-by-rejected`, `-vector-element`, `-captured-field`,
  `-needs-mut-binding`, `-through-exclusive-reference`, `-mixed-captures`,
  `closure-shared-capture-still-fn`, `closure-shared-borrow-of-fn-closure`) plus the two former
  read-only rejections now accepted as `closure-capture-mutation-fnmut` and
  `closure-capture-borrow-mut-fnmut`, the book example `fnmut`, and the B6 decision record.
- LLVM backend: typed-IR fact **F2**, "this word holds an `f32`". The front end now records, beside
  the word stream rather than in it, that a local's frame slot holds an `f32` and that a given
  `rt_f64_op` call computes on two `f32` operands with a given opcode; `compiler/llvm.grl` lowers an
  accepted slot to `alloca float` with `load float`/`store float` and one `fpext` to the binary64
  word the rest of the program expects, and an accepted call to `fadd`/`fsub`/`fmul`/`fdiv float`
  plus the single `fpext` that produces the result word. `matmul`'s inner loop becomes
  `movss`/`mulss`/`addss` with no `cvtss2sd`/`cvtsd2ss`, so the `f32` kernel stops being penalised
  for being unrolled; output is bit-identical (the standard `p2 >= 2*p1 + 2` argument, pinned by new
  cases that print each `f32` result as `f64`, i.e. its shortest round-trip decimal). The fact table
  never enters the stream: `optimize.grl`, `machine.grl` and the native backend are untouched, the
  native assembly is byte-identical, and a slot whose address is taken or that the body touches in
  any way other than one eight-byte word is dropped and keeps the word lowering. `--verify-facts`
  (off by default) emits `fpext(fptrunc(d)) == d` at every word a fact treats as an `f32` and writes
  the table into the module as `; fact` comments; `tools/test-facts.mjs` runs it.
  Measured on x86-64 with `tools/bench.mjs --rounds 9` (paired medians): `fnv`/`sieve`/`sort`/`nbody`
  unchanged, and `nbody` correctly gets no fact at all (its 38 float operations are `f64`). `matmul`
  does **not** get faster at default `-O2` on the measuring host: 0.220 s -> 0.214 s in the 9-round
  paired run, and 1.000 / 1.014 (after/before) over two 41-round paired A/B runs, i.e. within noise
  -- this LLVM already unrolls the kernel, and the second element of the unrolled pair hides the
  widened dependency chain. What F2 is worth is the design's own experiment: with every check branch
  deleted from the `.ll` (measurement only), `matmul` is 0.360 s / **1.95x** C before and 0.191 s /
  **1.05x** C after, so F2 is what turns "remove the bounds checks" from a 1.9x regression into C
  parity, which is F1's lever. Design and the full measured table: `docs/design/typed-ir.md`,
  *Implemented: F2*.
- FFI out-parameters: a C function can write a handle or bare pointer through a slot the caller owns,
  spelled as a mutable borrow in the declaration (`slot: &mut Instance`) and `&mut binding` at the
  call site. That is the Vulkan/D3D12/Metal create shape (`vkCreateInstance(..., VkInstance
  *pInstance)`), which no result register can express. The parameter is the C `H *`; the callee
  writes one word into the binding's own slot and Grail reads the binding afterwards. A handle or
  bare pointer binding declared without an initializer is now null instead of uninitialized, so the
  callee always reads a defined word and a binding that already holds a value seeds the next call.
  Only `handle`, `CPtr` and `CMutPtr` slots are out-parameters; a shared `&H`, any other `&mut T`, a
  C callback parameter and a `cfn` type's parameter are refused with their own diagnostic, and the
  slot is an ordinary mutable borrow, so one call cannot take it twice
  (`compiler/native.grl`, `docs/ffi.md`, `tests/ffi/out_params.grl`, and the `ffi-out-params` case
  that executes under Wine on Windows x86-64).
- FFI calls of more than six word arguments execute with the target's own limit: six integer argument
  registers on x86-64 and the outgoing stack after them, eight on AArch64 and RISC-V 64. Argument
  words past the register file are stack slots (up to 64 words, 2 KiB of outgoing area), so Vulkan
  entry points of seven to ten words are expressible. `tests/ffi/call_words.grl` executes seven,
  eight and nine word arguments with literal and computed values on x86-64, AArch64 and RISC-V 64, so
  a dropped or misplaced word changes the printed sum; with the old peephole argument-register model
  the same fixture returns 91 and 603 instead of 140 and 204 on AArch64 and RISC-V 64. The
  `ffi-call-words` case runs the same calls on Windows x86-64 under Wine.
- Fixed: an exported C callback with a seventh or eighth parameter read the sixth again. The callback
  prologue clamped at `%r9` instead of reading the seventh and eighth integer argument registers, so
  on AArch64 and RISC-V 64 the extra parameters arrived as copies of the sixth. It now reads the
  target's own argument registers, which `tests/ffi/callback_words.grl` executes on those two
  targets (1 + 2*2 + ... + 8*8 = 204, previously 181). x86-64 and Windows, whose callback prologue
  reads registers only, refuse a parameter list beyond six integer words by name instead of reading
  a register that holds something else.
- Opaque handles across modules, and identity comparison. A `handle` declared in one module is
  nameable in any module that imports it (`use sys_grail;` then `sys_grail::File`, or
  `use sys_grail::File;` then `File`), so another module can name it in a parameter, a result and a
  record field - `tests/handles/stream_def.grl` + `stream_user.grl` execute an `fopen`/`fileno`/
  `fclose` round trip through a field and back to C, which pins it. `==`/`!=` between two handles of
  the same type now compile to a word compare, the "compared by identity" rule `docs/ffi.md` already
  stated but which failed with `type mismatch`; a record field of handle type compares the same way.
  A handle used where it has no value names the rule instead of `type mismatch`: arithmetic and
  ordering say "a handle is a foreign token: pass it, store it in a field, or compare it with == / !=
  against a handle of the same type; it has no arithmetic, ordering or size", a value of another type
  where a handle is expected says it cannot be constructed or converted (only a foreign call produces
  one), and two different handle types say they do not mix. Handles stay one-word values the compiler
  never frees (`docs/ffi.md`), so binding one copies the word rather than moving it; that documented
  non-linearity is unchanged. `tests/native-cases.json` gains `cross-module-handle-signatures` and
  `handle-reject-arithmetic`.
- Fixed: `!` on a `None` inside an `extern "C"` callback died of SIGSEGV instead of reaching the
  checked abort (SIGABRT / exit 134, the B5 policy). The unwrap was right; the value never existed.
  A declaration (`absent: u64? := None`), an assignment and a `return` in an `unsafe module` all
  skipped `adopt_value`, which is the context *lowering* - `None`/`Some` construction, union
  injection, a function used as a closure - and not a check, so a raw module left `None` as an
  untyped `0` and `absent!` dereferenced a null payload. The three sites now run `adopt_value`
  regardless of raw mode; only `require_type` and the literal-typing tail (a raw module's literals
  stay untyped words) remain safe-mode. The `None` token span is also cleared when the token stream
  or `locals` is replaced, like the call-flex hint record, so a span from another file can never
  fabricate an option object. `tests/ffi/unwrap_none_callback.grl` (an `extern "C"` callback that C
  calls through the shim) asserts SIGABRT and the output printed before it; without the fix the same
  program dies of SIGSEGV.
- Fixed: a sized integer in an `unsafe module` (the runtime's raw mode) computed its arithmetic as
  an untyped unsigned word, so `x: i32 = 0; x = x - 1` aborted in checked mode instead of producing
  `-1`, and an `i64` comparison such as `status < 0` was an unsigned compare. Raw mode skips the
  *checks* for a stated integer type, not the type itself: the binary operator path, compound
  assignment and `compound_value` now pick `int_binary` whenever an operand's type is a sized
  integer (taking it from either operand), so subtraction, comparison, shifts, division and
  multiplication keep the stated signedness and width inside `unsafe module runtime`/`darwin` code.
  `tests/native-cases.json` `raw-module-sized-integer-arithmetic` pins `0 - 1` as `-1`, a signed
  comparison, `i8` 120 + 7 and an `i64` comparison, with an `extern "C"` declaration that carries a
  `cfn` parameter in the same module - the shape the report named, though the `cfn` itself was not
  the trigger: any `unsafe module` showed it.
- `grail profile [--rate N] [--out FILE] -- PROGRAM [ARGS]` samples a compiled Grail program and
  prints a per-function table (`samples`, `share`, `function`, `module`) plus `[unknown]` and
  `total` rows. The sampler is part of the program's runtime, not a wrapper around `perf`: on Linux
  x86-64 `compiler/runtime.grl` looks for a `.grail-profile/config` rendezvous file at startup,
  maps a 65536-entry address buffer and a 64 KiB alternate signal stack, installs a `SIGPROF`
  handler and starts `ITIMER_PROF` at `1/rate` of CPU time. The handler reads the interrupted `RIP`
  from the kernel `ucontext_t`, claims a slot with a CAS loop and stores one word - it never
  allocates, never takes the allocator lock and never enters the kernel, so it cannot deadlock
  against the runtime. Samples are written as `GRPROF2` plus the rate, capacity, count, dropped
  count, the `CLOCK_PROCESS_CPUTIME_ID` nanoseconds the samples cover and the raw addresses on
  normal exit, `host::exit` or a runtime abort. The report prints the measured CPU time and the
  effective rate (`samples / CPU seconds`) and says so when the request was not honoured, because
  the kernel accounts CPU time per tick and caps the effective rate near one kilohertz regardless of
  `--rate`. The command then
  parses the program's ELF `.symtab` (`SHT_SYMTAB` + linked `.strtab`, `STT_FUNC` ranges since the
  compiler emits no `st_size`) and binary-searches each address. Addresses outside every symbol are
  reported in an always-present `[unknown]` row rather than dropped, and the report states that a
  default build is `ET_EXEC` and needs no PIE adjustment (a relocated `ET_DYN` binary is reported as
  unmatched instead of guessed). No `perf`, `nm`, `addr2line` or debug section is used at any
  point; `.grail-profile/` is created and removed in the working directory because safe Grail code
  cannot set a child's environment. `tools/test-profile.mjs` (`just profile-test`, the CI `profiler`
  job, and a `bun tools/ci.mjs lint` check) profiles a known hot loop at a fixed rate and asserts
  the hot function is the first row with over half of the attributed samples, that the rows sum to
  the total, that a stripped copy lands entirely in `[unknown]`, and that `--out` matches stdout.
  `docs/tooling/profiler.md` documents the command, the columns and the limits: the sampled code
  cost (about 3.4 KiB of `x86-64` text in every program and one failing `openat` at startup when no
  profile was requested), leaf-only
  attribution, optimiser inlining, no line granularity, CPU-time rather than wall-clock sampling,
  no report when the program is killed, and Linux x86-64 only (other targets compile the hook but
  never arm it, and `grail profile` refuses to run there).

- Records can be passed to C **by value**: `v: byval R` in an `extern "C"` declaration (or a
  `cfn(...)` parameter list) passes the whole record the way C does, while a bare `R` keeps meaning
  the C `R *`. The classification reuses the record's C layout and is per target ABI: SysV x86-64
  classifies each eightbyte INTEGER or SSE (a mixed eightbyte is INTEGER, over 16 bytes is MEMORY on
  the caller's stack, and an exhausted register class sends the whole record to the stack); AAPCS64
  passes homogeneous float aggregates in `v0`-`v7`, other composites of 16 bytes or less in
  consecutive `x0`-`x7`, and larger records by reference to a caller copy; RISC-V 64 passes records
  over 2xXLEN by reference, and at or below it either one register per field (one or two fields with
  at least one float) or one integer register per eightbyte. `byval` is refused with a diagnostic on
  the Windows ABIs (MSVC struct rules, no Windows FFI execution path here), on anything that is not
  an `extern "C"` record, and in an `extern "C" fn` definition (C calling Grail with a by-value
  record), rather than approximated. `tests/ffi/byval_records.grl` with `tests/ffi/byval_shim.c`
  executes 4-, 8-, 16- and 24-byte records, mixed int/float fields, an ImVec2-shaped float pair, an
  embedded array, a byval argument after six integer arguments, a byval record sharing the stack area
  with a following scalar and a `cfn` call on x86-64, AArch64 and RISC-V 64 (the latter two under
  qemu); `docs/ffi.md` gains the syntax, the per-ABI rule table and the refusal cases.
- A C-layout record argument to a `cfn` call is now borrowed, not moved, exactly as a direct extern
  call treats it: the callee receives a pointer to (or a copy of) the record's fields and Grail keeps
  ownership, so the value is still usable after the call.

- Fixed: `tools/test-ffi.mjs` listed the `pointers` fixture by repeating keys inside the
  `nested_records` entry, so `nested_records` never ran. Both fixtures are entries of their own and
  both pass.
- Borg session state persists a typed event stream instead of an opaque payload
  (`borg/src/ffi/store.grl`, `borg/src/events.grl`). The frame still opens with the `BGS` magic and
  now carries the version digit `2`, a little-endian payload length and a sequence of tagged events;
  a `1` file is refused as `unsupported-version` rather than decoded as events. Each event is a
  one-byte tag, a 32-bit body length and explicitly typed fields: little-endian numbers,
  length-prefixed text, 0/1 booleans, presence-tagged optional values and length-counted text lists.
  An unknown tag, an event cut short, a body length past the 256 KiB per-event ceiling, a boolean or
  presence byte that is neither 0 nor 1, and bytes past an event's last field are each refused by
  name, and a refused stream yields no events. Every declared length is checked against the bytes
  actually present, and the payload is capped at 1 MiB before the file is read, so no
  attacker-controlled length becomes an allocation. The same-directory temp file and rename are
  unchanged, and the write is still not fsynced. `just borg-store-test` covers the empty stream, one
  event of every variant, ordering, and every refusal (`borg/tests/ffi/store_test.grl`).
- `lib/sys/grail_ffi.grl` re-binds the `&mut [u8]` argument of `read`, `env_get` and `recv` to a
  mutable local before the C call. The ownership checker requires a mutable binding for storage a
  call writes through, and a parameter binding cannot be `mut`, so forwarding the reference straight
  through no longer compiled: the FFI wrapper, and every test that links it, failed to build.
- The seven owner decisions left open in `docs/design/language-readiness.md` section B are settled
  and recorded in `docs/design/decisions-b2-b6.md`: B1 (separate compilation with checked module
  interfaces) and B7 (records passed by value, spelling `v: byval R`) are accepted and in progress;
  B2 keeps ambient `host::` for v1 as a recorded deviation with the conditions that force a change;
  B3 makes a foreign call block the executing thread with no green-task integration; B4 keeps
  thread-per-blocking-call on Windows and names IOCP as future work with a sketch; B5 fixes abort as
  "never unwinds, nothing unwinds across the C boundary"; B6 records that closures capture
  references and views under region checking and defers `FnMut` with six fixed rules. Section B of
  the readiness audit now marks every row decided with a one-line summary and a link, so the work
  can proceed without re-arguing the choices.
- Documentation corrections found while writing those decisions: `implementation-status.md` reported
  the user FFI boundary as missing (it is implemented and executed on six targets) and borrowing
  closure captures as missing (they exist; only `FnMut` is deferred); `concurrency-v1.md` claimed
  blocking foreign calls are isolated (only `host::read_file`, `host::write_file` and
  `host::command` are offloaded, from a green task); `windows-backend.md` and B4 now state that a
  green-task spawn aborts on Windows because the scheduler treats a missing `epoll` as fatal, which
  a task-scope program reproducing it confirms (exit 134 under Wine, no output, against `42` and
  exit 0 on Linux); `borg-agent-port.md` blockers 1 and 3 are annotated as resolved before that
  record; README lost a duplicated Windows paragraph and no longer reports Windows threads as
  missing; `runtime-api.md` keeps its OS-wrapper plan but records that its premise - the compiler
  not yet accepting `extern "C"` declarations - has changed. No compiler or runtime code changed.
- Strict-bool is now the language's rule, not an opt-in survey: a `bool` and an integer no longer mix,
  and every `if`/`while` condition must be a `bool`. `if n` is written `if n != 0`, `(a < b) + (c < d)`
  is `a < b || c < d`, `flag & (x == 0)` is `flag != 0 && x == 0`, and `f(x) == 0` on a predicate is
  `!f(x)`. The compiler's own sources were migrated first (`docs/design/strict-bool-migration.md`):
  `--strict-bool-report` over them went 1595 -> 1409 (predicates that return `bool` instead of a 0/1
  `u64`) -> 405 (operators) -> 0 (conditions).
  - `--strict-bool` is gone: the rule is enforced whenever the compiler type-checks a program (it stays
    off in `unsafe module` sources, as before), and a violation is a compile error.
  - `--strict-bool-report` remains as the survey mode: it prints `file:line:column: message` for every
    violation, keeps compiling and exits 0.
  - `--strict-bool-fix` and its `FIX ...` records are deleted; the `tools/strict-bool-fix.py` they were
    meant for never existed.
  - Migrated with it: the test corpus and the examples (`tests/native-cases.json`, `compiler/tests`,
    `compiler/examples`, `book/examples`, `examples/loops/cleanup.grl`), where `if flag` became
    `if flag != 0` and the fixture that asserted bool arithmetic now spells the conversion with
    `u64(1 == 1) + u64(2 == 2)`.
- The RHI starts in Grail. `abundance/src/rhi_sdl3.grl` and `abundance/src/rhi_vulkan.grl` bind the
  system SDL3 and Vulkan loaders through `extern \"C\"` declarations, and
  `abundance/tests/rhi_device_probe.grl` exercises them against this machine: `SDL_GetVersion`,
  `SDL_Init(SDL_INIT_VIDEO)`, `SDL_GetCurrentVideoDriver`, a hidden `SDL_WINDOW_VULKAN` window with
  `SDL_GetWindowSize`/`SDL_GetWindowSizeInPixels` and `SDL_DestroyWindow`, then
  `vkEnumerateInstanceVersion` and the loader's instance extensions and layers, decoded at their C
  offsets out of `VkExtensionProperties`/`VkLayerProperties` byte buffers. `tools/abundance-test.mjs`
  runs the probe after the parity suite under the same exclusive GPU lock `graphics/Makefile` takes,
  and skips it when no `libSDL3.so`/`libvulkan.so` can be linked; the ten parity programs are
  unchanged and still byte-identical, because the two FFI modules are linked only by the probe.
  `VkInstance` creation is blocked by an FFI limit, not by a driver: `handle` and `CPtr` values enter
  Grail only as a foreign call's *result*, so `vkCreateInstance`'s `VkInstance *` out-parameter has no
  spelling. The new `ffi-reject-handle-out-slot` and `ffi-reject-handle-null-seed` native cases pin
  the two refusals, and `docs/rhi.md` states what the increment covers, what it does not, and the
  next three.
- **Authority/capability model for OS access (decision B2).** `lib/authority.grl` makes OS access
  an explicit value: `authority::open_read(root)`, `open_write(root)`, `open(root)`, `process()`
  and `sockets()` create an owned `Authority`, and `authority::read_file`, `write_file`, `spawn`,
  `connect`, `listen`, `port` and `close` enforce it. Path containment is lexical and
  component-wise after normalising `.`, `..` and duplicate separators (both `/` and `\`), so
  `/database` is not under `/data` and `/data/../etc/passwd` is `Denied`; the operation opens the
  same resolved path the check approved. `authority::Error` keeps an OS error (`not found`)
  distinct from a denial. The new compiler switch `--deny-ambient-host` rejects any `host::`
  reference in a module whose `use` lines do not name `host`, covering calls, function values and
  constants; `use host;` is the module-level opt-in (Grail has no attribute syntax), and ambient
  `host::` remains the default without the switch. `grail build`, `grail check` and `grail test`
  forward the flag. The switch does not cover `extern "C"` declarations, compiler builtins or
  descriptor values, and containment does not resolve symlinks (see `docs/authority.md`). New
  `bun tools/test-authority.mjs` (74 checks: 57 containment cases, a gated read/write/spawn/socket
  round trip, and the switch), wired into `just test-authority` and the full linux-x86_64 CI lane.
  Book: a "Capabilities instead of ambient access" section and the `authority` example with its
  Rust comparison.
- The compiler no longer dies of SIGABRT on a stale call-flex hint record. `hint_use` remembers the
  token span and `locals` index of a committed literal binding whose type a later use may fix, but the
  record outlived the file that made it: token spans are indices into one file's token stream, so a
  record from one file could match an unrelated argument in the next, and the `locals` index it
  carried could reach past that function's locals. On the Borg module set that aborted the compiler
  with no diagnostic and no output. The record is now cleared wherever the token stream or `locals` is
  replaced (file load, function, closure body), and a stale index is reported as a
  `file:line:column` internal-error diagnostic instead of faulting the process.
  `compiler/tests/hint_scope_record.grl` + `hint_scope_stale.grl` (case `literal-hint-scope`)
  reproduce the abort in two eight-line files; the triggering program is valid, so the `.copy()` and
  `.text()` call sites that exposed it are unchanged.
- Two cross-lane defects found while wiring the release pipeline: `bun tools/ci.mjs build
  --platform windows-x86_64` no longer passes `compiler/os-linux.grl` alongside the
  `compiler/os-windows.grl` that `tools/windows.mjs` appends, which made the PE/COFF build fail with
  a duplicate `rt_syscall`; and the Mach-O object check reads `llvm-nm --extern-only` so the
  compiler object's local symbols no longer overflow the command buffer. Windows x86-64 and both
  macOS object lanes build again.
- Release pipeline for `v*` tags (`.github/workflows/release.yml`, `tools/release.mjs`,
  `docs/releases.md`). Every supported target builds from the checked-in bootstrap seed with no
  development compiler (`GRAIL_COMPILER` is refused) and no network beyond the runner toolchain;
  the workflow publishes one GitHub release per tag with the per-target artifacts, a `SHA256SUMS`
  file, `release.json` provenance and a generated `RELEASE-README.md`. Linux x86-64, AArch64 and
  RISC-V 64 ship real ELF compiler executables; windows-x86_64 ships a cross-built PE32+ compiler
  image and COFF object bundle that are static-checked but not runnable on Windows yet; macOS
  ships static-checked Mach-O object bundles only; windows-aarch64 remains planned and is not
  published. `tools/ci.mjs build`/`package` gained `--stage0 PATH` for a seed-built stage0, and
  `bun tools/ci.mjs lint` now checks the release workflow against the platform matrix.
- A language server for Grail, **written in Grail** (`tools/lsp/main.grl`, launched by
  `bun tools/lsp.mjs`, also `just lsp`), replacing the JavaScript MVP that lived in
  `tools/lsp.mjs`/`tools/lsp.test.mjs` (both removed). It speaks JSON-RPC 2.0 over stdio with
  `Content-Length` framing and implements `initialize`/`initialized`, `shutdown`/`exit`,
  full-text `didOpen`/`didChange`/`didClose`, and `textDocument/publishDiagnostics` from the
  existing compiler: the buffer is written to a scratch file, `grail check` runs on it in its
  own directory, and the compiler's `file:line:column: message` diagnostics are published as
  UTF-16 ranges (severity Error, `source: grail`, `code: compiler`) and cleared with `[]` when
  the buffer checks clean or is closed. `textDocument/definition` answers from the same file
  for a function declaration, a local `NAME :=`/`mut NAME` binding, a `for` binding and a
  function parameter, using `compiler/lexer.grl` in process. Malformed input is answered with
  the JSON-RPC error that describes it — `-32700` for framing and JSON, `-32601` for unknown
  methods, `-32002` before `initialize`, `-32600` after `shutdown`, `-32602` for definition
  params — and never terminates the server; a frame that carried no usable `Content-Length`
  is discarded and the reader resynchronises on the next header line. `initialize` advertises
  only `textDocumentSync` and `definitionProvider`: no hover, completion, rename, formatting,
  references, symbols or pull diagnostics. `bun tools/lsp-test.mjs` (55 checks, hermetic: it
  builds the compiler and the server from the tree) drives a real stdio session, is wired
  into `just lsp-test`, `bun tools/ci.mjs lint` and the CI `lsp` lane, and the server is
  documented in `docs/tooling/lsp.md`.

- Decision B4 (Windows I/O readiness): the green-task reactor is epoll-only, so on Windows
  (`rt_threaded()`) a task is now an OS thread instead of aborting on a failed `epoll_create`:
  `spawn` creates the thread, `join`/scope exit wait on the task's finished word and reap it,
  suspension parks the task's own thread on its park word with `WaitOnAddress`, `host::sleep_ms`
  sleeps that thread and `rt_wait_fd` returns immediately (thread-per-blocking-call). `rt_sched`
  never creates a reactor there, so `spawn`, `task_scope` and `parallel_map` work; a blocking foreign
  call blocks only its own task. `WaitOnAddress`'s expected value moved from one shared scratch word
  to the calling thread's record, because two task threads can now wait on different values at once.
  Windows cases `tasks-scope-and-parallel-map` and `tasks-sleep-overlap` execute under Wine and on
  Linux. Not implemented: IOCP, overlapped I/O, and an ARM64 thread bridge.
- Decision B3 (suspension and blocking contract): a foreign call blocks the executing task thread.
  The runtime's own blocking operations hand the call to a dedicated OS thread and suspend the task
  (`rt_blocking_call`, now the single entry point for `host::read_file`, `host::write_file` and
  `host::command`), so no worker is lost; `host::pipe` and `host::sleep_ms` suspend on the reactor.
  An `extern "C"`/`cfn` call is not wrapped by the compiler, so it runs on the worker and blocks it,
  and a wrapper that knows it blocks declares that with `rt_blocking_enter`, which makes the runtime
  warn once per process on stderr. Native cases `blocking-foreign-call-occupies-worker` (two tasks,
  one blocking in libc `usleep`: the other keeps running and the warning appears exactly once) and
  `blocking-foreign-call-handoff-is-silent` (the same call through the handoff: silent) pin the
  contract; `docs/ffi.md` states it for users.
- Decision B5 (abort/unwind policy): abort never unwinds, and nothing may unwind across the C
  boundary. `rt_abort` is the only abort entry point and now ends in a platform `rt_hard_exit`:
  `exit_group` on Linux, `TerminateProcess` on Windows, `_exit` on macOS. Two defects are fixed.
  A Windows abort used `ExitProcess`, which runs DLL detach handlers and C++ static destructors; and
  on x86-64 Linux the fallback was `exit(2)`, which ends only the calling thread, so an abort inside
  a green task whose SIGABRT was caught by a foreign handler left the process waiting forever. Both
  now end the whole process with no foreign cleanup. Tested from inside a Grail callback that C
  called (glibc `qsort`) and from a green task: `tests/abort/` plus native cases
  `abort-in-c-callback-*`, `abort-in-green-task-ends-process`, `abort-unwrap-none`, with a control
  case proving C does return into Grail normally. The rule and its one-line rationale are stated in
  `docs/ffi.md` ("Abort and unwinding across the boundary").
- `docs/design/llvm-backend.md` stage 2c: the five benchmarks re-measured with paired medians, seven
  further lowering and driver levers recorded as measured-and-rejected (three-region alias metadata,
  loop pragmas on the latch, `-funroll-loops`, inline thresholds, an unroll threshold with its
  compile-time cost), the cause of `matmul`'s "removing the checks is slower" anomaly corrected to
  the `f32` accumulator widening to a `binary64` phi when the loop unrolls, and the two pieces of
  type information that block the remaining gap named precisely (`F1` a typed pointer to a sequence
  header; `F2` a word that holds an `f32`), each with the lever it unblocks and what that lever is
  worth. No lowering change: nothing tested paid for itself.
- `tools/bench.mjs --rounds N` interleaves the C and Grail binaries round by round and reports the
  median of N runs each with the observed spread, because a shared machine drifts within a single
  run: the default best-of-three favours whichever side happens to run first when the host is busy.
  The default (best-of-three) is unchanged.
- Merge the three design reviews from branch `claude/brave-heisenberg-0h3ska` as documents only
  (`docs/design/first-principles-architecture.md`, `architecture-reassessment.md`,
  `complexity-reassessment.md`, 2,746 lines). Their edits to README and to the research-phase
  decision log were not taken: those files describe the compiler as it is today, and the reviews
  were written against the earlier research-phase text.
- The runtime's narrow-vector routines (`f32[]`, `u32[]` and `i32[]` push, fill, indexing, copy,
  insert, remove, swap, reverse, truncate, contains and compare) read and write their 4-byte elements
  with the `raw_load32`/`raw_store32` intrinsics, one access each, instead of composing each from four
  byte loads and stores; behaviour and output are unchanged. The bootstrap seeds are refreshed so a
  fresh clone builds this runtime without a development compiler, and the seed manifest carries the
  new source and artifact digests.
- Strict-bool phase 1 (`docs/design/strict-bool-migration.md`): the compiler's own predicate helpers
  return `bool` instead of a 0/1 `u64`, so a caller's `if f(x)` stops reading as an integer test and
  `f(x) == 0` reads as `!f(x)`. Internal only; no language change. The six helpers that carry a real
  status code (`compile_mode`, the `*_command` handlers, `frame_split`) keep `u64`.
  - `lexer`: `whitespace`, `punctuation`.
  - `ownership`: `ancestor`, `loan_ancestor`, `can_cleanup`, and `overlaps`, whose body was the sum of
    two `ancestor` calls and is now `||`.
  - `optimize`: `same`, `movelike`, `arith`, `slot_read`, `slot_written`, `reg_fact_valid`,
    `dead_after`, `promotable_use`. Sums of predicates used as a truth value became `||`.
  - `fmt`: `is`, `keyword`, `binary`, `prefix_position`, `unary`, `space`, `opener`, `closer`,
    `opens`, `shuts`, `breakable`, `trailing_ok`, `arm_break`, `chain_dot`, `chain_break`,
    `list_break`, `op_break`. The space flag still lands in the numeric `f.lspace`, so that one
    assignment converts explicitly.
  - `cli`: `eq`, `starts`, `ends`, `contains_name`, `is_macho`, `is_command`. The command handlers
    that carry the process exit status are untouched.
  - `llvm`: `eq`, `starts`, `ends`, `occurs_at`, `has`, `member`, `is_local_label`, `legacy_base`,
    `is_xmm`, `set_has`, `callee_saved`. `frame_split` stays u64: it is stored in the lowering
    state's `split` field.
  - `machine`: `eq`, `starts`, `small_reg`, `atomic_instruction`, `c_abi`. The register-width codes
    `rw`/`sw` stay numeric (0, 1 or 2), so the two `eq` results that initialize them are read through
    an `if`.
  - `native`: `same` (the hottest helper, 437 call sites) first, because most other predicates are
    written in terms of it. Its `same(a) + same(b)` sums become `||`; `mode`, `permitted` and the
    `imm()` argument stay numeric and convert explicitly.
  - `native`, type and span predicates: `span_is`, `span_has`, `needs_drop`, `intersects`,
    `is_local_slot`, `concrete_type`, `ffi_record_has_nested`, `is_text`, `is_float`, `is_char`,
    `literal_target`, `is_bool`, `scalar`, `integer`, `adopt_literal`, `capture_borrow`,
    `contains_text`, `has_bonds`, `numbers_equal`, `satisfies_interface`, `callable_contract`,
    `token_starts_type`, `starts_with`, `flex_read`, `element_index_ahead`, `simple_index_ahead`,
    `slice_ahead`, `typed_binding_ahead_at`.
  - `native`, unions, maps and FFI: `is_ordinary_union`, `is_result_union`, `is_at`, `is_keyword`,
    `ffi_direct_type`, `impl_has_for`, `stdlib_module`, `ffi_record_has_float`,
    `ffi_record_has_float_deep`, `typed_binding_ahead`, `format_arg`, `ref_to_text`,
    `is_option_storage`, `closure_free_name`, `char_method`, `subword`, `is_map_type`,
    `proven_index`. `format_arg`'s `numeric` flag becomes bool; the mask it feeds converts
    explicitly.
  - `native`: `is` (the current-token check, 88 call sites, 70 of them `while`/`if`
    `is(...) == 0`). `is_enum` and a constant's `value` are stored in u64 fields, and `imm()`
    takes the bool constant's value, so those three convert explicitly.
  - `native`: `eat`, `is_union`, `lifetime_candidate`, `borrow_place_ahead`,
    `type_literal_ahead`, `map_assignment_ahead`, `statement_builtin`, plus `type_keyword` and
    `simple_type_head`. 35 `eat(...) == 0` guards become `!eat(...)`; the values that feed u64
    parameters or fields (`public`, `negative`, `hneg`, `raw`, `write`, `mutable`) convert
    explicitly. `is_f32` and `is_comparison` stay u64 — see below.
- Maps iterate with `for key, value in &map`, in insertion order, and `for key, value in &mut map` binds the
  same shared key with an exclusive value (`value := map.value_at_mut(i)`), so values update in place. The loop
  holds one reference to the map throughout: inserting into it inside the body is rejected, a shared loop cannot
  write to a value, and `for key, value in map` is refused with a pointer to `&map`. The compiler cannot see a
  map's private layout, so the sugar lowers to `len`/`key_at`/`value_at`/`entry_at` over positions.
- `Map::key_at`, `Map::value_at`, `Map::value_at_mut` and `Map::entry_at`, and `hashmap::entry_at`, which returns
  the `Entry` view of a position: the positional accessors had free functions only, so the written-out loop had
  no method form.
- Book: the collections chapter documents map iteration, with a side-by-side Rust comparison (a `BTreeMap`,
  because insert order is Grail's order and std's `HashMap` has none).
- `&mut r` on a `mut` binding holding a shared reference borrows the binding's own slot
  (`&mut &T`), so a callee can replace which referent the binding names:
  `previous := replace(&mut current, &second)` with `current = &first` compiles (it was rejected with
  "mutable reborrow of shared reference"). The new reference grants no write access to the old
  referent, the old referent stays frozen for as long as a value still names it, and `&mut r.f` /
  `&mut r[i]` still borrow through the referent and stay rejected. A mutable-reference binding keeps
  reborrowing its referent. Book example `writeback` and its Rust comparison use the natural form
  again.
- Record patterns in `match`: `match p { Point { x, y: other, .. } => { ... } }` takes a record apart
  by field. A record arm matches every value, so it is the only pattern (an explicit `_` may follow
  and is never taken); `..` ignores the rest. Fields bind by copy for plain scalars, by move when the
  whole record is moved, and as shared or exclusive references through `match &p` and `match &mut p`.
  An unknown field and a field left out without `..` are reported by name, and a record arm may not
  be followed by any pattern but `_`. The book's records chapter documents the form with a
  `record-patterns` example.
- Abundance port: the cluster builder builds canonical voxel meshes (`Source::canonical_voxel`). Cluster attributes
  carry the raw RGBA8 grade/excavated grade channel, the quantization grid refines itself (AUTO) until every canonical
  position and every open or non-manifold boundary survives the position codec and the decode remap, and the encoded
  positions of a shared metadata class are locked. Previously refused.
- Abundance port: the cluster builder trims alpha contours (`Options::alpha_trim_levels`, `alpha_trim_budget`). A masked
  material carries its full-resolution alpha as an image (`AlphaSource::Bytes`) or a pixel provider
  (`AlphaSource::Sample`); four-state per-triangle opacity classes produce the per-cluster alpha-test bits and remove
  fully transparent triangles; unclassifiable cutout triangles are split 1:4 at shared edge midpoints, fully
  transparent children dropped and T-junctions repaired, so the kept leaf cards follow their alpha shape. The C++
  source validation for those paths is ported too (finite attributes, measured position encoding error, masked alpha
  rules, one alpha source per material). Previously refused.
- Abundance port parity: `abundance/tests/parity/abgeo.cpp` now also builds a canonical voxel chunk and a leaf card
  with image alpha and pixel-provider alpha; the Grail builder matches all 681 reference lines byte for byte (was 489).
- `bun tools/abundance-test.mjs --regenerate`: a reference may name the source program it shares (`cache` is
  `world.cpp` run with different argv), so the `abgeo` and other references that need a source of their own no longer
  fail on a missing `<name>.cpp`. References that link Abundance's world build tree still need that tree's headers.

- A closure may capture a reference or view (`&T`, `&[T]`, `&[u8]`, `&mut T`): the pointer moves into
  the closure and its loan moves with it, so a comparator can read a key that lives outside the value
  it is given (`groups := &b.groups; vecs::sort_by(&mut order, |x, y| ... groups[*x] ...)`). The closure
  type records the captured lifetime, so a closure that borrows cannot be returned out of the
  function or stored where the borrow does not reach; a struct or enum that merely holds a borrow is
  still rejected. Returning a value that carries a live loan is now rejected whatever its type says.
  The Abundance cluster builder sorts pages with such a comparator again instead of precomputing keys
  into a vector (`vecs::sort_by_key`); output unchanged.
- Sequence element access is cheaper: the runtime's accessors (`rt_slot`, `rt_at`, the byte and
  4-byte variants, `rt_push`, `rt_len`, the slice/view helpers) compose addresses with
  `wrapping_add`/`wrapping_mul`, so the compiler stops emitting overflow guards for the length field
  and the element address on every access. Bounds checks are unchanged and still abort on any
  out-of-range index, including indexes whose byte offset would wrap. Against C `-O2` on x86-64,
  `--backend=llvm`: nbody 2.3x -> 1.7x, sort 1.4x -> 1.3x. The native backend reads the same stream,
  so the guards disappear there too. Design notes: `docs/design/llvm-backend.md`, stage 2b.
- LLVM backend, stage 2b measurement (`docs/design/llvm-backend.md`): after stage 2a the benchmarks
  are within 1.0-1.2x of C except `nbody` (2.4x) and `sort` (1.5x), and in those two the remaining
  cost is the per-element validity/bounds/address checks the front end emits (44% and 21% of run
  time, measured by rebuilding the lowered IR with the check branches deleted). LLVM cannot hoist
  them out of the loops: the word stream carries no type or alias information, so the descriptor's
  length and data loads cannot be merged across an element store, and LLVM will not speculate a
  load through `inttoptr`. Alias scopes, TBAA, alignment metadata, `nounwind`, branch weights, loop
  unroll pragmas and `-O3` were measured and rejected; the only lever that moves them is aggressive
  unrolling (a compile-policy decision: `nbody` 21% faster, `sort` 6%, at five times the code).
  Closing the gap needs the typed front-end IR of stage 3. `fnv`, `sieve` and `matmul` are at their
  floor.
- A program's own `Task`, `Mutex`, `Atomic`, `Scope` or `CancelToken` type shadows the built-in generic of that name
  (`Task[...]` was a parse error). A slice compares with `==` against a vector of the same element type.
- Book: duplicate chapters merged (numbers, bytes and text, records and vectors, views and slices); every example uses
  current syntax (`data[:]`/`&data` instead of `view(data)`, direct writes through references, `bool` instead of
  `u64` flags); new side-by-side examples for typed slices and stable sorting with a closure; stale "preview" notes
  replaced by an accurate list of what is not implemented yet.
- A block that does not start with `{` (such as a brace-less `match` arm) is reported as
  "expected { to start a block"; the compiler used to crash on an arithmetic underflow.
- `for item in items` consumes vectors of owned elements in default-u64 mode too, including
  temporary vectors. Each iteration owns its element; early exits clean up the remainder.
  Borrow with `&items` to preserve the vector. Previously this worked only outside default-u64 mode.

- A rejected program makes the compiler exit with status 1 instead of aborting (which dumped core).
- An `impl` whose method signature does not match its interface is reported at that method; the
  error used to point at the end of the last input file (often `os-linux.grl`).
- Abundance port cleanup: the cluster builder and `.abgeo` reader use the float methods, `wrapping_u32`/`wrapping_u8`,
  `vecs::insert_sorted` and `vecs::sort_by_key` instead of hand-written helpers, and `!x` instead of `x == false`; the
  `.abgeo` test builds its lines with `format` and parses with `strings::split`/`parse_num`. Output unchanged.
- `hash::Equal::equal` and `hash::equal` return `bool` (they returned `u64`). The standard library no longer
  mixes bools and integers (`||`/`&&` instead of `+`/`&` on comparisons, `>=` instead of `(a < b) == 0`).
- `tools/test-selfhost.mjs` (`just test-selfhost`, a CI job): the compiler compiles itself twice and the outputs must
  be identical.
- Closures can take reference parameters (`|a: &T, b: &T| -> bool ...`), each borrowed afresh per call;
  they were rejected ("closure parameters cannot hold borrows yet").
- Functions are values of closure type: any function whose signature matches (up to lifetime names)
  can be passed where an `Fn(...)` is expected, including ones taking references
  (`fn less<a, b>(x: (&a T), y: (&b T)) -> bool` as `Fn(&T, &T) -> bool`). Before, only closures could.
- `vecs::sort_by` (stable, comparator), `vecs::sort_by_key`, `vecs::insert_sorted` and
  `vecs::binary_search`; `order::Ord` for `f32`.
- Float methods `ceil`, `trunc`, `round`, `min`, `max`, `is_finite`, `is_infinite`, `next_up` and
  `next_down` on `f64` and `f32`, bit-identical to libm; `floor(-0.0)` now keeps the sign.
- Borrows made to pass arguments end once the value is computed (when it holds no borrow itself):
  `b.words[i] = f(&b)` and `M { flags: word(&bytes, 0), bytes: bytes }` compile, as in Rust. A value
  that does hold the borrow still keeps it alive.
- `==`/`!=` compare vectors and slices of numbers, bool and char by length and elements (floats by value:
  `-0.0 == 0.0`, NaN unequal); before, only record fields of vector type could be compared.
- Typed slices: `&[T]` and `&mut [T]` for every element type (`v[a: b]`, `&mut v[a: b]`, open bounds,
  sub-slicing, indexing, element borrows, loops by value or reference, `len`, `copy`, `contains`,
  formatting), with the vector's ownership rules: a slice cannot outlive its vector, the vector
  cannot grow or be written elsewhere while a slice of it lives, and an exclusive slice excludes
  every other access. `&s`/`&mut s` on a slice binding reborrows it. Design:
  `docs/design/typed-slices.md`.

- `f32[]`, `u32[]` and `i32[]` store their elements in 4 bytes (they were 8-byte words), halving
  their memory and letting the LLVM backend use 32-bit loads, single-precision arithmetic and
  vector lanes (matmul: 3.2x -> 1.3x of C). Programs print the same output, and every element can
  still be borrowed (`&mut v[i]`, `for x in &mut v`, generic `&mut T`).
- Bytes can be borrowed: `&mut buf[i]` on a `u8[]` or a mutable byte view is a `&mut u8` (it was
  rejected). Borrowing a narrow field of an `extern "C" record` (`&mut rec.x` with `x: f32`) used to
  compile and silently lose writes made through the reference; it now reads and writes the field.
- New compiler intrinsics `raw_load32`/`raw_store32` (32-bit `movl` on every target, an `i32`
  load/store in LLVM); the LLVM lifter now handles `movd`, `cvtss2sd` and `cvtsd2ss`.
- Abundance port: `abundance/src/abgeo.grl` reads `.abgeo` cluster-geometry files with every check
  the C++ `MeshView::open` makes, decodes zstd-compressed pages (`zstd::frame_content_size` is new),
  and decodes clusters (bit-packed positions and uv0, octahedral normal + tangent frames, indices,
  alpha bits, colour), and selects LOD cuts (`select_cut` for a view with partial residency,
  `select_cut_error` at an object-space error). `abundance/tests/abgeo_test.grl` matches the C++
  reader on fixtures built by Abundance's own cluster builder, plain and zstd-paged: 486 lines,
  floats as bits, including 180 cuts.
- Abundance port: `abundance/src/cluster_builder.grl` builds `.abgeo` files from a source mesh
  (clusters, the per-material cluster-LOD DAG via grail-meshopt's clod, per-level BVHs, page packing
  and dependencies, attribute codec). Its output is byte-identical to Abundance's C++ builder on the
  three procedural test meshes (single material, three materials, two-sided foliage with wind).
  Canonical voxel meshes, alpha-contour trimming and voxel LOD levels are not ported yet and are
  refused. `tools/abundance-test.mjs` fetches grail-meshopt at a pinned commit into `.work/deps`
  (`GRAIL_MESHOPT` selects a local checkout).

- `lib/zstd.grl`: Zstandard decompression (RFC 8878), `zstd::decompress(bytes) -> u8[]?`: raw,
  RLE and compressed blocks, Huffman literals (one or four streams, FSE or direct weights,
  treeless), FSE sequence tables (predefined, RLE, compressed, repeat) with repeat offsets, the
  XXH64 content checksum and skippable frames; dictionaries are not supported. Checked against 101
  streams from the reference library (`tests/lib/reference/zstd_corpus.py`).

- `lib/xxhash.grl`: XXH64 (`xxhash::hash64(bytes, seed)`), identical to the reference `xxhash.h`; zstd
  frame checksums and Abundance fixture identities use it.
- Ownership: after a `while` or `for` whose body always returns or continues, locals are usable again.
  The dead end state of such a body (where `return` had dropped every local) was merged into the
  loop exit, so any use after the loop was rejected as a use of a moved value.

- LLVM backend: when every frame access in a function is a constant offset below rbp, each 8-byte
  slot becomes its own alloca, so borrowing one local no longer makes the whole frame escape and
  LLVM keeps the rest in registers. With `--backend=llvm` the benchmarks are now 1.2x (fnv, sieve),
  1.5x (sort), 2.3x (nbody) and 3.2x (matmul) of C `-O2`.

- Repeat literals: `u8[0; n]`, `u64[7; n]`, `f32[0.0; n]` make `n` copies of a plain value in a
  single allocation (Go's `make([]byte, n)`, Rust's `vec![0; n]`). A byte value above 255 stops the
  program; an owned element type is rejected. The sieve benchmark uses it in place of a push loop.
- Green-task stack switches on AArch64 and RISC-V save every register the C ABI preserves
  (x19-x28 and d8-d15; s0-s11 and fs0-fs11), not only those the native backend uses, so
  LLVM-compiled code survives a task switch. A new task's initial frame grows to match.

- `bytes[i]` reads the element straight from the sequence when the index is simple (names, integer
  literals, arithmetic, grouping): no temporary view is allocated, borrow-tracked and freed per
  access. Other index expressions keep the borrowed-view path, so moving or mutating the sequence
  inside them is still rejected. The fnv benchmark goes from 36.1 s to 3.0 s on the native backend
  and from 5.1 s to 0.63 s (1.1x C `-O2`) on `--backend=llvm`.

- `view("literal")` builds nothing at run time: the bytes, a `u8[]` object for them and the view
  descriptor are read-only data behind block headers marked static, which `rt_free` leaves alone.
  The literal used to be copied into a fresh string, UTF-8 checked and wrapped in a heap view on
  every evaluation; compiling the compiler is about 10% faster.

- LLVM backend (`--backend=llvm`, Linux x86-64): `compiler/llvm.grl` lowers the raw word stream to
  LLVM IR for every function it fully understands and keeps the rest (data, the entry, stack
  switching, indirect calls) as native assembly; the compiler writes `PATH.ll` beside `PATH`, and
  `clang -O2` compiles it. Registers, flags and frames become allocas that LLVM promotes, checked
  arithmetic becomes overflow intrinsics, check failures a cold noreturn path, atomics LLVM
  atomics, `syscall` inline asm, and `rt_f32_round` hardware rounding. Every executable native
  case gives identical output; the benchmarks in `bench/` run 1.3x to 39x faster than the native
  backend (`GRAIL_BACKEND=llvm bun tools/bench.mjs`). `compileProgram` and the test runners honour
  `GRAIL_BACKEND=llvm`.
- `tools/bench.mjs` and `bench/`: Grail against C `-O2` on five kernels, with matching output
  required.
- CodeView symbols on Windows x86-64: `--debug` now emits an S_GPROC32 per function (named
  `module::name`) with an S_FRAMEPROC and an S_REGREL32 for every parameter and local at its rbp
  slot, typed with CodeView's predefined base types (`__int64`, `double`, `bool`, `unsigned char`,
  ...). lld-link links the scopes into the PDB; `tools/test-debug-lines.mjs` checks the records
  with `llvm-pdbutil`.

- `&mut z.comps[i].data` and `&grid[y][x]` borrow the whole accessor chain; the borrow used to
  stop after the first index, so the following field was read as a value (a type mismatch).

- Dereference is `*r` and store-through is `*r = v` / `*r += v`, as in C, Rust, Go and Zig. Reading
  copies plain values and refuses owners ("use exchange"); `*r = v` drops the old value, and
  `exchange(r, v)` remains the way to move an owned value out. The `load(r)` builtin is replaced
  by `*r`; `lib/`, Borg, Abundance, the examples, the book and the tests were rewritten.

- The statement builtins `write`, `drop` and `assert` apply only before `(` and when no local
  shadows them, so a binding named `write` can be assigned (`write += 3`).
- Statement and expression keywords (`loop`, `while`, `for`, `if`, `match`, `return`, `mut`, ...) are
  reserved: naming a binding or parameter after one is rejected with "a keyword cannot name a binding". A binding named `loop` used to be
  accepted, and `loop[i] = x` then sent the compiler into an infinite loop.

- Byte reads (`bytes[i]`) are 0..255 words that adopt any integer type holding that range, so
  `hexval(text[i])` with `hexval(c: u8)` works without a conversion, while `bytes[i] << 24` still
  computes in a full word. Byte buffers and byte literals accept `u8` values.
- Storing or pushing a value above 255 into a byte buffer now stops the program, as documented;
  `buf[i] = v` and `buf.push(v)` used to keep only the low byte silently.

- `match m.get(&k) { Some(v) => ..., None => m.insert(k, x) }` works: a borrow whose holders are
  all dead (here the moved scrutinee's) ends before a conflicting borrow is refused, so the `None`
  arm may modify the map; modifying it while the `Some` payload is still used is still rejected.
- A `for` count bound is read once (Go semantics): `for y in z.comps[n].v { f(&mut z) }` no longer
  holds a borrow of `z` for the whole loop.
- An unknown method on text or a vector reports "unknown collection method" instead of the
  misleading "owned storage mutation requires mut".

- Functions, closures, interface methods and function types take any number of parameters; the
  six-parameter (five for closures) limit is gone. Grail's own convention keeps five words in
  registers and passes the rest in a record addressed by the sixth, which the callee copies into
  its frame; C calls and callbacks keep following the platform C ABI.

- A reference or view binding passed to a function by name is reborrowed instead of moved, so
  `total(v) + total(v)` and two `bump(v)` calls through a `&mut` parameter work, as in Rust. The
  borrow checker still rejects real conflicts (a `&mut` reborrow while a shared borrow is live).
- A module's own function, or a callable local, named like a builtin (`load`, `join`, `view`, ...)
  now shadows the builtin instead of failing with an unrelated error; non-callable locals do not.
- `.copy()` works on vectors of plain values (numbers, floats, bools, handles), not only byte
  collections; copying a vector of owners is rejected.
- Arithmetic between untyped integer literals is an untyped constant (Go-style): `65536 + 16777216`
  or `(1 << 20) - 1` adopts its context's type like a single literal, with the same range check.

- Assignment to nested places: `v[i][j] = x`, `world.items[i].hp -= 1`, `rows[i].cells[j] += 1`
  and any mix of indexes and fields, each step borrowed mutably for the statement. Mutating
  method calls through an index (`rows[i].push(x)`, `m[k].push(x)`, user methods taking
  `self: &mut`) borrow the element mutably instead of failing as a read-only access, which
  removes the old need to `exchange` an inner vector out to push to it.

- String literals decode escapes strictly: `\u{...}` (a Unicode scalar value, encoded as UTF-8)
  now works in strings as it already did in character literals, `\xHH` is limited to `\x7F` so
  a literal can never be invalid UTF-8, and an unknown escape such as `\q` is a compile error
  instead of being kept as literal text.
- `u8[]` has `.clear()` and `.truncate(n)` like other vectors (`clear` used to be a parse error).
- `module::Type[]` and `module::Type[...]` collection literals work for another module's types.
- In i64 mode an unsuffixed literal that does not fit `i64` (e.g. `9223372036854775808`) is a
  compile error; it used to wrap silently to a negative value.
- Standard-library modules are recognised by location (a file in the directory holding
  `core.grl`) rather than a hard-coded name list, so every `lib/` module, including new ones,
  compiles in the stdlib's own literal mode regardless of the program's mode.

- `f32_bits(x)` returns the IEEE binary32 bit pattern of an `f32`, and `f32_from_bits(u)` builds an
  `f32` from one (subnormals, infinities and NaN included). `bits(x)` on an `f32` still returns
  the 64-bit pattern of the internally widened value, so these are the way to read and write
  32-bit floats in binary formats.

- FFI bare data pointers: `CPtr` (`const void *`) and `CMutPtr` (`void *`) parameters, results and
  extern-record fields, made with `unsafe cptr(bytes)`, `unsafe cptr_mut(&mut bytes)` and
  `cnull()`. C APIs that take lone buffer pointers (libsodium keys and outputs, Vulkan `pData`)
  are now callable without a C shim. `tests/ffi/pointers.grl` runs on all three Linux targets.
- `grail build` / `grail test` honour the compiler's `// grail-link:` requests: bare library
  names become `-lNAME`, relative objects resolve against the entry file, and an executable that
  links a shared library gets the platform dynamic loader and system library directories
  (Linux), or the library inputs on the Mach-O link line. Previously the CLI linked every program
  statically and ignored foreign libraries, so only the test harness could link C code.
- `docs/ffi.md`: the supported-types table now lists narrow integers, floats, record results
  and the bare pointer types, which were already supported but documented as rejected.
- Borrow checker: a reference obtained from an unwrapped optional reference (`items := get(&v)!`)
  and used only inside one branch of an `if` no longer reports "cleanup conflicts with live loan"
  when its owner is cleaned up. The anonymous origin behind the returned reference was left
  "maybe live" by the branch join and never ended; it now ends once no live loan reaches it, so
  a reference still in use after the join keeps the owner borrowed exactly as before.
- Nested C records: an `extern "C" record` field may itself be an extern record, embedded by
  value at its C offset with C alignment and size. Reads and writes project through it in place
  (`o.inner.x = v`), whole-record assignment copies the bytes in, a value read copies them out,
  and nested records come back from C by value. Results with floats inside an embedded record
  are refused for now. `tests/ffi/nested_records.grl` checks `sizeof`/`offsetof` against clang
  and runs on x86-64, AArch64 and RISC-V 64 Linux and on Windows x86-64 (Wine).
- Standard library: `zlib` (DEFLATE/zlib inflate, Adler-32, and a lenient variant for image
  decoders), `png` and `jpeg`. The image decoders reproduce `stb_image` exactly (the library
  Abundance uses): PNG in every colour type and bit depth with Adam7, palettes, colour-key tRNS
  and stb's 16-to-8-bit and channel conversions; JPEG baseline and progressive with stb's integer
  IDCT, upsampling filters, fixed-point YCbCr and Adobe CMYK/YCCK handling. Tests compare against
  CPython's zlib and against stb itself for every requested channel count (53 streams, 570 PNG
  and 290 JPEG checks); all 95 PNG assets in the Abundance tree also decode bit-identically.
  `png::encode` and `zlib::compress` reproduce `stbi_write_png` byte for byte (its hash-chain
  compressor, adaptive filter choice and CRC; 444 encodings checked). Decoding is currently about
  160x slower than stb.

- DWARF debug info on Linux AArch64 and RISC-V 64: `--debug` emits the same line table and
  typed variables as on x86-64 (frame base `x29` / `s0`). Under qemu with gdb's remote stub,
  `info locals` shows `count = -3`, `ratio = 2.5`, `flag = true` on both; `test-debug-lines`
  checks the line rows, variable types and `llvm-dwarfdump --verify` for both targets.

- Variadic C calls on macOS arm64: each variadic argument (promoted to 64 bits or `double`) goes
  on the stack in its own 8-byte slot while named arguments keep their registers, per Apple's
  arm64 ABI. Checked statically in `test-macos` (no macOS runner); the call was refused before.

- C records with float fields returned by value: SysV classifies each eightbyte (all-float ->
  `xmm0`/`xmm1`, otherwise `rax`/`rdx`), AAPCS64 returns homogeneous float aggregates of 1-4
  fields in `s0`-`s3`/`d0`-`d3` at any size, RV64 returns one or two flattened fields with a float
  in `fa0`/`fa1` (and an integer in `a0`); everything else keeps the integer-register or hidden
  pointer rules (Win64 by size). `tests/ffi/float_record_results.grl` covers five shapes on three
  Linux targets and Windows x64.
- `Some(value)` and `None` are the only option spellings: `core::some` / `core::none` are now
  rejected in every build mode (the legacy `--default-u64` mode used by the test suites still
  accepted them), and the remaining uses in `lib/`, `borg/`, the examples, the compiler tests and
  the book were rewritten. `grail build` now compiles only the standard-library modules a program
  reaches through `use` (plus `core`, which `Some`/`None` lower to) instead of every `lib/*.grl`.
  A bare `None` needs a type from context; `x == None` and `x != None` now take it from `x`.

- Fixed: the `i64` -> `u64` widening check emitted `jns`, which the AArch64 and RISC-V lowering
  does not implement (it emulates the zero and carry flags only), so programs relying on default
  `i64` semantics failed to compile for those targets. The sign is now tested with a shift and a
  zero test.

- Fixed: on macOS an exported `extern "C" fn` was defined without the Mach-O leading
  underscore while references to it had one, so taking a callback's address failed to link.
  `test-macos` now links the `dlopen` fixture (libSystem loader imports, a Grail callback) for
  both macOS targets.

- DWARF variable types: `--debug` on Linux x86-64 now gives every parameter and local a
  `DW_AT_type` base type (signed/unsigned integers of their width, `f64`/`f32`, `bool`, `char`;
  strings, records and other owned values as named 8-byte handles), so gdb prints
  `count = -3`, `ratio = 2.5`, `flag = true`; `llvm-dwarfdump --verify` reports no errors.

- Dynamic loading on AArch64 and RISC-V 64 Linux: the host-TLS bridge (switching the thread
  pointer between Grail's worker record and glibc's TCB around foreign calls and callbacks) now
  covers `tpidr_el0` and `tp`, written directly instead of through `arch_prctl`. With a glibc
  sysroot (`GRAIL_SYSROOT_AARCH64`, `GRAIL_SYSROOT_RISCV64`) dynamically linked cross programs
  link against the target loader and run under qemu `-L`; `tests/ffi/dlopen.grl` executes on
  all three Linux targets. Foreign calls on AArch64/RISC-V previously ran with Grail's worker
  record installed where glibc expects its TCB.
- `lib/sha256.grl`: FIPS 180-4 SHA-256 over byte views, incremental (`sha256::new()`,
  `update`, `finish` -> 32 bytes) with one-shot `digest` and lowercase `hex`/`hex_digest`; the
  PicoSHA2 replacement for Abundance content identities. Checked against the NIST vectors
  (including one million `a`), `sha256sum` on generated inputs around the 55/56/63/64/65-byte
  padding boundaries, and every split of the input between two `update` calls.
- `lib/json.grl`: strict RFC 8259 JSON for the bounded config adapter (replacing nlohmann/json).
  `json::parse`/`parse_with` return `json::Value |? json::Error` with an error kind and byte
  offset, never aborting on malformed input; integers that fit are exact `Int(i64)`, other
  numbers are correctly rounded `Float(f64)`; `\u` surrogate pairs decode to UTF-8 while lone
  surrogates, invalid UTF-8 and raw control characters are rejected; objects keep key order and
  reject duplicate keys unless `allow_duplicate_keys`; nesting is bounded by `max_depth`
  (default 128). `to_text`/`to_pretty` round-trip exactly (shortest float digits). Tested with
  311 inline JSONTestSuite-style accept/reject cases and 612 CPython-verified float conversions
  (`docs/design/language-readiness.md` section C1).

- Callbacks with float and narrow-integer parameters and float results: an exported
  `extern "C" fn` reads each parameter from where the platform C convention put it (SysV,
  AAPCS64 and RV64 pack integers and floats into separate register files; Win64 is positional,
  with the fifth and sixth words from the stack), widens f32, extends narrow integers itself,
  and returns floats in `xmm0`/`d0`/`fa0`. `tests/ffi/callback_floats.grl` runs on three Linux
  targets and Windows x64.

- Variadic C functions: `extern "C" fn f(fixed: T, ...)`. Extra arguments use the C default
  promotions; SysV sets `%al` to the vector-register count, Win64 passes variadic doubles in
  both the xmm and the integer register of their slot, RV64 passes them in integer registers.
  macOS arm64 (variadics on the stack) is refused for now. `tests/ffi/call_variadic.grl` runs on
  three Linux targets and Windows x64.
- COM methods with more than four arguments or floats: read the vtable slot as a typed `cfn`
  and call it with the full platform convention (`tests/ffi/call_com_slot.grl`, seven arguments
  with three on the stack, Linux and Windows).
- C records with `f32`/`f64` fields (by pointer), at C offsets and sizes (`D3D12_VIEWPORT`,
  `VkViewport` shapes). Records with float fields as by-value *results* are refused until the
  SSE/HFA classification exists.
- Fixed: assigning a narrow C-layout field (`p.a = 5` on an `i32`) stored eight bytes and
  clobbered the neighbouring fields; assignment and compound assignment now write only the
  field's width. Fixed: the optimizer could fold a constant into `movq $imm,%xmm0`, which does
  not assemble.

- Child process output capture: `sys_grail::pipe()`, `spawn_with(program, args, stdin, stdout,
  stderr)` (with `inherit()` for shared streams) and `read_to_end(file)`, over a new
  `grail_ffi_process_spawn_stdio`. Executed on Linux (`/bin/sh`) and Windows under Wine
  (`cmd.exe`). The Windows OS ABI returned an error at the end of an anonymous pipe
  (`ERROR_BROKEN_PIPE`); it now reports a zero-length read, the portable EOF contract.
- Windows ARM64 threads: the `CreateThread` start bridge `rt_win_thread_start` now exists on
  ARM64 too and is published by the entry point; thread creation previously failed there. Static
  checks only (no ARM64 Windows runner).

- C records returned by value from direct and `cfn` calls: up to 16 bytes in `rax:rdx`, `x0:x1`
  or `a0:a1` (Win64: 1/2/4/8 bytes in `rax`), larger ones through a hidden result pointer in
  `rdi`/`rcx`/`a0` (shifting the arguments) or `x8` on AAPCS64. `tests/ffi/call_records.grl`
  returns 8-, 16- and 24-byte records on x86-64, AArch64 and RISC-V Linux and Windows x86-64.
- Windows debug info: `--debug` on windows-x86_64 emits CodeView line tables (`.cv_file`,
  `.cv_func_id`, `.cv_loc`, `.cv_linetable`), and the Windows link adds `/DEBUG /PDB:`.
  `test-debug-lines` checks the PDB maps the source lines and that every function keeps its
  unwind entry (the SEH prologue matcher now skips debug labels and `.cv_` directives).

- Win64 callbacks: an exported `extern "C" fn` on Windows x86-64 is now a thunk under the C
  symbol that saves `rdi`, `rsi` and `xmm6`-`xmm15`, moves `rcx`/`rdx`/`r8`/`r9` (and stack
  arguments five and six) into the body's registers and calls the body. Callbacks previously read
  SysV registers, so a C caller's arguments were lost and its callee-saved registers clobbered.
  The f32 narrowing in extern calls no longer uses `xmm15` as scratch, which Win64 preserves.
- Stdlib wrappers on Windows: `lib/sys/grail_ffi.grl` binds `lib "grail_ffi"` (the Linux object or
  `grail_ffi.dll`); `tools/test-ffi-runtime-windows.mjs` builds the C OS ABI and shim into
  `grail_ffi.dll` with Zig's MinGW toolchain and runs the file, socket and process/thread tests
  under Wine (the process test spawns `cmd.exe`).
- Windows `io::Error` codes: the Windows host layer maps `GetLastError` to the errno values
  `io::Error` understands (ENOENT, EACCES, EEXIST, ENOTDIR, ENOTEMPTY, EINVAL, ENOMEM); unmapped
  codes surface as `Other(0x10000 + code)`. Opening any missing or unreadable file used to report
  ENOENT, and removing a non-empty directory or a file as a directory reported EISDIR.
- `vecs::fold` (consuming, any element type) and `any_num`/`all_num`/`count_num`/`position_num`.
  Generic predicates over borrowed elements wait for closure parameters that hold borrows.

- Windows dynamic loading: an `extern "C" lib "X"` declaration on a PE target now records
  `X SYMBOL`, and the Windows link step imports each symbol from `X.dll`, so `LoadLibraryA`,
  `GetProcAddress` and `FreeLibrary` link like any import. Calls through `cfn` values (on every
  target) now use the platform C convention, including floats, narrow integers, stack arguments
  and Win64; they previously used Grail's internal register order. A Wine-executed case resolves
  `lstrlenA` and `MulDiv` from kernel32 and checks `ERROR_MOD_NOT_FOUND` (126) for a missing DLL.

- D3D12 bindless and compute: the contract's root signature now carries the four unbounded
  tables (sampled images, storage images, samplers, storage buffers) over one shader-visible
  resource heap and one sampler heap; the thirteen fixed samplers fill slots 0..12. Added
  `gr_sampler_create`, sampled texture views, `gr_texture_write`, storage buffers (host-visible
  ones in a custom write-back heap the GPU can write), compute pipelines and dispatch, buffer
  barriers with tracked states, `gr_device_retire`/`gr_device_collect` and real bindless
  high-water marks. `grail_bindless.hlsli` declared both UAV tables in space 0, where an
  unbounded `u1` range overlaps `u3`; on D3D12 storage writes landed in the storage-image table.
  The tables now use `u0 space2` and `u0 space3`, with `[[vk::binding]]` keeping Vulkan's set 0,
  bindings 1 and 3 unchanged. Flip-model DXGI swapchains on an SDL3 window (acquire, present,
  resize) and Windows SDL3 loading through `LoadLibrary`, with the window's HWND/HINSTANCE from
  SDL properties, are added.

- Vulkan's thirteen fixed samplers did not match Abundance's definitions: the `*_WRAP` slots
  clamped, the `*_CLAMP_U_WRAP_V` slots never wrapped V, W was always clamped, and the MIN/MAX
  reduction slots filtered as ordinary samplers; `gr_sampler_create` also ignored MIN/MAX
  reduction. Both now use one table, `gr_fixed_sampler` (taken from `engine/core/bindless.cpp`),
  which D3D12 shares, and `samplerFilterMinmax` is enabled for the reduction slots.

- Vulkan pipelines now honour `gr_pipeline_desc.depth_compare`; it was ignored and every
  pipeline used GREATER_EQUAL. Zero still means the reverse-Z default, as on D3D12.

- D3D12 buffers, vertex input and depth: upload, readback and device buffers (host access to
  device memory is refused, as on Vulkan), vertex and index buffer binding, input layouts built
  from the vertex shader's reflected semantics and checked against the pipeline's attributes,
  depth textures, depth-stencil views, reverse-Z depth state and depth clears, and indexed draws.
  The smoke test now has 162 checks, including a depth-tested indexed triangle whose depth reads
  back exactly. The shader tool stored DXC's SPIR-V variable name (`in.var.COLOR0`) as the vertex
  semantic; it now stores the HLSL semantic and index (`COLOR`, 0), as the reflection contract
  says, which D3D12 input layouts need.

- D3D12 draws: DXIL shaders, graphics pipelines on the contract root signature (32 root
  constants at b0, frame constants as a root CBV at b0 space1), blend modes, topology, cull,
  wireframe, pipeline commit/stats, push constants, frame-constant slots and non-indexed draws.
  `make -C graphics d3d12-smoke` now runs on vkd3d-proton (the offline DXIL is shader model 6.6;
  Wine's built-in vkd3d supports 6.2) and checks a 64x64 draw of the offline `core/fullscreen` and
  `core/solid` shaders pixel by pixel against the shader's formula: 83 checks. Vertex input,
  depth, MSAA, compute/mesh pipelines and bindless tables still return `GR_ERROR_UNSUPPORTED`.

- Direct `extern "C"` calls are lowered per calling convention: SysV x86-64, Win64, AAPCS64
  (Linux, macOS and Windows ARM64) and RV64 LP64D. They now take and return `f32`/`f64` (an `f32`
  crosses as real binary32) and `i8`..`i32`/`u8`..`u32` (results re-extended; RV64 receives
  `u32` sign-extended), and pass arguments beyond the registers on the stack (up to 64 words;
  Win64 gets its 32-byte home area). Windows `extern "C"` calls previously used SysV registers;
  they now follow Win64 and run under Wine. RISC-V objects now use the `lp64d` hard-float ABI
  instead of `lp64`, which is what Linux C libraries use. `tests/ffi/call_abi.grl` runs on
  x86-64, AArch64 and RISC-V Linux and Windows x86-64. Callbacks and `cfn` calls keep the
  integer-only slice for now.

- Fixed a double `vkDestroySemaphore` at Vulkan device teardown: the compute queue borrows the
  device's graphics timeline but its teardown destroyed it too. The validation layer had reported
  `VUID-vkDestroySemaphore-semaphore-parameter` and two threading messages after the tests'
  error counters closed, so `vk-smoke`, `vk-surface` and `vk-cache` reported zero while teardown
  did not. All three are now silent through teardown.

- D3D12 backend, first slice (`graphics/src/grail_d3d12.c`): headless device with its reported
  feature level, one direct queue whose fence is the timeline gr fences observe, 2D render-target
  textures and views, command pools and lists (one allocator per list), barriers that refuse a
  source state disagreeing with the tracked one, clears, viewport/scissor, submit and texture
  readback. The device owns and releases all its objects. Every other entry point routes to an
  explicit `GR_ERROR_UNSUPPORTED`. `make -C graphics d3d12-smoke` builds the library for
  x86_64-windows with `zig cc` and runs 47 checks under Wine (vkd3d on the host GPU), including
  exact clear readbacks. Building without SDKs also exposed and fixed two latent gaps: Vulkan
  declarations in `grail_vk_common.h` outside `GRAIL_HAVE_VULKAN`, and eleven dispatcher entry
  points missing from the no-headers Vulkan stubs. The shader library can now index on Windows
  (`FindFirstFileA`) instead of reporting `GR_ERROR_UNSUPPORTED`.

- Added process and thread wrappers over the C ABI: `handle Process`/`handle Thread`,
  `spawn(program, arguments)` with a NUL-separated argv[1..] blob, blocking `wait` returning a
  40-byte `ProcessStatus` (kind/exit code/signal), `process_id`, `process_close`, and
  `thread_spawn(cfn(u64)->u64, user)`, consuming `thread_join`/`thread_detach`. Process stdio
  and environment are inherited; handles are affine by convention. The x86-64 test spawns
  `/bin/sh -c 'exit 7'`, checks the exit status and closes the process, then spawns a Grail
  C-ABI callback thread with user word 41 and joins the result 42; AArch64/RISC-V 64 assembly
  and unmangled calls are checked without execution.
  The FFI runtime runner no longer patches `raw_tp_set` out of a runtime copy: all wrapper tests
  now run on the real runtime through the compiler's host-TLS bridge.

- Dynamic loading on Linux x86-64: `dlopen`/`dlsym`/`dlclose` work through ordinary extern
  declarations, with `dlsym` declared once per signature and returning a callable `cfn`.
  Because the runtime's worker record and glibc's TCB share the FS base, the compiler records
  the loader's TLS base in `_start` before `rt_thread_init`, switches to it around every
  foreign call, and switches to Grail's base for the body of every exported callback. The new
  `tests/ffi/dlopen.grl` resolves two functions from a shared library and runs a callback that
  calls libc. Limits: main thread only, x86-64 Linux only, one `arch_prctl` per switch.

- Added Linux x86-64 DWARF `.debug_info` compile units and DIEs on top of the
  line table. `--debug` now emits a DWARF v4 compile unit naming the entry
  source and one subprogram DIE per function with name, linkage name,
  low/high pc, declaration file/line and an rbp frame base. Parameters and
  locals get formal-parameter/variable DIEs with declaration lines and
  `DW_OP_fbreg` stack locations; optimisation is skipped in debug builds so
  slots stay live, and validation replays do not leak discarded DIEs.
  `grail debug info BINARY` prints the unit through `llvm-dwarfdump` (readelf
  fallback). Type DIEs, location lists, breakpoints/attach/DAP and non-Linux
  debug sections remain follow-ups. The debug integration test now also checks
  subprogram ranges, parameter/local names and locations.
- Port Borg Agent's permission gates (`borg/`). `src/permission.grl` carries the three permission modes, the three approval decisions, and the rules a gate applies: the requested workspace root must sit under a canonical enrolled root, a path must be relative and free of traversal components, a symlink on the way is refused outright, and containment is component-wise so a `/w` root does not cover `/work`. The denial reasons are Borg's own strings, and an `allow_session` grant covers later calls of the same tool and scope while `allow_once` does not. The port now checks 921 reference lines over 200 documents, with `--anchors` verifying 74 copied snippets across thirteen source files.

- Windows COM interop: two new unsafe-runtime intrinsics, `raw_win_local(Symbol, args...)` for a
  direct Windows-ABI call to a symbol linked into the image (x86-64 `%rcx/%rdx/%r8/%r9`; ARM64
  `x0..x3`) and `raw_win_call(slot, args...)` for an indirect call through a loaded function
  pointer such as a COM vtable slot (x86-64 `call *%r11`, ARM64 `wininvoke` ->
  `ldr x16,[x9]; blr x16`). `CoInitializeEx`/`CoUninitialize` join the import table from
  `combase.dll`. Minimal C-ABI shims (`tests/com-shim-x64.s`, `tests/com-shim-arm64.s`) provide
  an `IUnknown` object; the executed x86-64 case proves AddRef/Release counts 2, 3, 2, 1 and 1, 0
  and the exact `E_POINTER` (2147500035) and `E_NOINTERFACE` (2147500034) HRESULTs, plus a
  successful `QueryInterface` returning the object pointer. The same program is checked
  statically for windows-aarch64. Single static object and one IID; no `CoCreateInstance`,
  marshalling or apartment tests.

- Added typed loopback TCP socket wrappers over the C ABI: `handle Socket`, a 56-byte `Address`
  record constructed only by `loopback(port)`, `tcp`, `bind`, `listen`, `accept`, `connect`,
  `send`, `recv`, `recv_bytes`, `socket_shutdown`, `socket_close`, `local_address`,
  `peer_address`, `local_port` and `peer_port`. `bind`/`connect` reject non-127.0.0.1
  addresses before the C call. The x86-64 test runs a listener/client/server ping-pong on an
  ephemeral loopback port and checks the non-loopback rejection; AArch64/RISC-V 64 assembly
  and unmangled socket calls are checked without execution.

- Added `lib/sys/grail_ffi.grl`, the first Grail-facing wrappers over the Linux OS ABI:
  explicit init/shutdown, file open/read/write/close/stat/size, monotonic and wall clocks,
  and environment get/set. The module uses FFI byte views, an opaque `File` handle and
  Grail-owned out-records, returns `T |? Error` with negative ABI statuses, and keeps file
  handles affine by convention (explicit single close, no auto-free). Added a hosted C
  adapter for the allocator and handle-return out-parameter, a repeatable
  `tools/test-ffi-runtime.mjs` runner, and `docs/design/grail-ffi-runtime.md` with the exact
  pointer/length/ownership rules. The x86-64 test links the Linux reference backend with
  libc and executes file/time/environment checks; AArch64 and RISC-V 64 are assembly/static
  checked only. It uses the merged v3 FFI compiler and `runtime.grl`/`os-linux.grl`, is not
  auto-loaded by the current stdlib, and changes no compiler sources (the runner generates a
  test-only runtime copy to preserve libc TLS).

- Persist and reload session state through the C OS ABI (`borg/`). `src/ffi/store.grl` is the first increment that performs real I/O: it frames a payload ("BGS1", little-endian length, payload), writes it to a same-directory temporary file, closes it, and renames over the destination so a crash mid-write cannot leave a partial file — the rule Borg documents for credentials. A short file, a foreign magic and a length that disagrees with the payload are refused by name rather than partially accepted. The rename is declared in the port against the same FFI object file because the wrapper does not expose it yet; nothing under `lib/` or `compiler/` changed. `just borg-store-test` builds the Linux backend, links the FFI test and runs it: three round-trips and five refusals, in a separate suite because it needs a C toolchain. `--anchors` now verifies 75 copied snippets across thirteen source files.

- Abundance RHI host: `abundance/tools/rhi_host.c` handles wire packets using the Vulkan
  backend. Its standalone GPU self-test clears an R8G8B8A8_UNORM target and reads back
  exactly 64, 128, 191, 255. The request/response file transport differs from the documented
  AF_UNIX topology; the Grail client exchange is not yet verified end to end.

- Abundance CPU port, RHI bridge framing: `abundance/src/rhi_bridge.grl` packs and unpacks the
  graphics foundation's `gr_wire_packet` exactly as `graphics/src/grail_wire.c` does — 40-byte
  header, magic/version/op/request/status/sequence/aux, payload, with the 1 MiB packet bound — so a
  host driving `grail_null.c` reads what a Grail program writes. Three packets and three refusals
  are gated byte-for-byte against the C framing: 30 exact values, suite total 313 across nine
  programs. Bounded and stated: the host half (null backend init, render target, one pass,
  readback) is the next increment; no device is created here.

- Abundance CPU port, asset-package increment: `abundance/src/asset_package.grl` carries the ABPKG1
  package header (id, payload hash, payload bytes, ascending dependency ids), package ids and
  payload hashes from the engine's `fnv1a64`, and the dependency DAG with duplicate, missing,
  self-dependency and cycle refusals plus a deterministic topological order that does not depend on
  input order. The reference gates ids and hashes against the engine and the DAG rules against a
  model, because Abundance has no C++ asset DAG (its dependency work is Python staging). 29 exact
  values; suite total 283 across eight programs. No payload bodies, GPU upload or renderer work.
- Added Linux x86-64 DWARF line tables. `grail build --debug` and the raw
  `grail --debug ...` compiler form emit `.file`/`.loc` directives that clang
  assembles into `.debug_line`; statement rows are line/column accurate, with a
  post-pass that re-asserts the location after literal `.popsection` switches.
  `grail debug lines BINARY` prints the table through `llvm-dwarfdump` (with a
  `readelf` fallback). `--debug` is rejected for non-Linux-x86-64 targets, and
  `.debug_info` variable DIEs / debugger attach remain follow-ups.
  `tools/test-debug-lines.mjs` verifies rows against source lines and the plain
  build's lack of a line table; CI adds a preflight-gated `debug-lines` job.
- Added non-executable target object release bundles for the implemented cross
  backends: `windows-x86_64` (COFF), `macos-aarch64` and `macos-x86_64`
  (Mach-O). `bun tools/ci.mjs objects --platform ...` compiles the compiler and
  a conformance program to relocatable objects, verifies COFF/Mach-O headers
  and symbols, and packages `objects/`, gzipped assembly,
  `share/grail/objects.json` provenance and `OBJECTS-BUILD-ONLY.txt` with a
  top-level `SHA256SUMS`. Manifests record `executable: false` and
  `runnable: false`, and verification rejects any bundle containing an
  executable. macOS gained required `cross-macos-aarch64`/`cross-macos-x86_64`
  static lanes; CI adds an object-bundle matrix and a macOS static-check job.
  Nothing is executed on macOS, and Windows release artifacts remain
  non-executable objects even though Windows test programs run under Wine.
- Reserve `VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER_DYNAMIC` in the Vulkan descriptor pool, matching
  set 1; the new SDL3 surface test’s validation layer had exposed the missing pool size.

- Windows x86-64 threads and waits: `raw_thread_clone` now calls a new
  `rt_win_thread_clone`/`rt_win_thread_main` pair in `compiler/os-windows.grl` that creates the
  thread with `CreateThread` through a compiler-emitted Win64 bridge (`rt_win_thread_start` keeps
  the private Grail convention by saving `%rdi/%rsi`, moving the thread parameter from `%rcx` and
  restoring them). A 15-slot registry maps the portable running word to the Win32 thread handle,
  so joins wait with `WaitForSingleObject` and only then release the stack; the unmap path reaps
  still-registered threads. Futex operations map to `WaitOnAddress` and
  `WakeByAddressSingle`/`WakeByAddressAll`, imported from `kernelbase.dll` (Wine exports them
  there, not from `kernel32.dll`). Two new cases run under Wine and as Linux ELF: a thread join
  and a producer/consumer wake. ARM64 thread creation remains unimplemented.

- Windows ARM64 frames now carry unwind data: the compiler describes each canonical prologue
  with armasm-style `.seh_proc`/`.seh_save_regp x29, 0`/`.seh_nop`/`.seh_set_fp`/`.seh_stackalloc`/
  `.seh_endprologue`/`.seh_endproc` directives, so the object has `.pdata` and `.xdata` and the
  image has an exception directory (240 records, 0x780 bytes for the hello image). Frame
  allocation uses a `framesub` pseudo-op (plain `sub sp,sp,x10` instead of checked arithmetic) so
  the recorded frame size is exactly the `.set` value. The records are the unpacked `.xdata` form
  on purpose: the packed encoding counts consecutive `x19..`/`d8..` saves and cannot express the
  lone `x29/x30` frame-pointer save Grail emits. Leaf functions need no record; drop thunks keep
  their conditional prologue and stay undescribed. The suite now checks records per function,
  frame sizes against the compiler's frame values, function lengths and the unpacked flag.

- macOS platform linkage beyond libSystem: `compileProgram` accepts `frameworks` and, with
  `$GRAIL_SDK`, links the SDK's real `-framework` stubs, otherwise writes `<Name>.framework` `.tbd`
  stubs from a caller-supplied export list (a framework name without either is rejected instead of
  being invented). `tools/macos.mjs` parses the linked image and verifies its `LC_LOAD_DYLIB`
  entries. `sign: true` requests an ad-hoc signature — `codesign --force --sign -` on macOS,
  `ld64.lld -adhoc_codesign` elsewhere — and `bun tools/macos.mjs inspect|verify BINARY` validates
  the SuperBlob, CodeDirectory, page hashes and cdhash statically; a tampered page fails
  verification. Tests add Foundation framework loading, unknown-framework rejection (driver and
  linker), and signature validation/tamper detection. Shared Mach-O libraries are also emitted:
  `assembleDylib` links `-dylib -install_name <name>` with an explicit `-exported_symbols_list`
  (a dylib without an install name or without exports is refused), and `tools/macos.mjs` reports
  `LC_ID_DYLIB` plus the export/import sets by parsing `LC_SYMTAB` directly. Tests link an
  executable against the dylib and require its install name in `LC_LOAD_DYLIB`, and reject a
  symbol outside the export list. `--export NAME` is a compiler flag: it marks exactly the
  definition with that declared name `.globl` at its own label and refuses a name that no function
  defines, so the driver no longer rewrites `.globl` into the assembly. Dylibs can advertise
  `@rpath/...` install names and consumers carry `LC_RPATH` (`rpaths` in `tools/macos.mjs`), with
  tests for both. Nothing here is execution evidence on Apple hardware.

- v3 C FFI increment 1: `extern "C"` foreign declarations and calls.
  `extern "C" [lib "INPUT"] [as "SYMBOL"] fn name(i64, u64) -> i64|u64|unit;` declares a
  linker-resolved C symbol; calls emit the C argument/result registers of the selected
  target (x86-64 SysV, AArch64 AAPCS64, RISC-V 64 LP64) and call the unmangled symbol.
  Foreign calls are rejected outside an explicit `unsafe { ... }` block, which remains a
  fully checked lexical region. Declarations carry their link inputs, deduplicated and
  emitted as `// grail-link: INPUT` lines that `tools/native.mjs` obeys. Narrower
  integers, floats, views, handles, records and callbacks are rejected with diagnostics
  rather than truncated or approximated. New `bun tools/test-ffi.mjs` (or `just
  test-ffi`) links a freestanding C shim and checks calls, the rename and `u64` results;
  rejection fixtures joined `tests/native-cases.json`. See `docs/ffi.md`.

- v3 C FFI increment 2: C byte/string views and opaque handles at `extern "C"` boundaries.
  A `&[u8]`/`&mut [u8]` parameter crosses as the C pair `(pointer, length)` with no copy and
  no allocation; `CStr` is a one-word NUL-terminated `const char *` produced by the checked,
  zero-copy `unsafe cstr(value)` cast; `handle Name;` declares a one-word opaque C token that
  safe code cannot construct, inspect, size or drop. Results may be `i64`/`u64`/`unit`/`CStr`/
  handle; a view is never a result. Arities are counted in C argument words (a view counts
  twice), and everything outside this slice is still rejected with a diagnostic. `tests/ffi/`
  gained a views/handles fixture and the shim gained string, byte, mutable-fill and handle
  functions; three more rejection fixtures joined `tests/native-cases.json`. See `docs/ffi.md`.

- v3 C FFI increment 3: `extern "C" record` with C layout and alignment. Fields use C's
  natural alignment, inter-field padding and tail padding, so `offsetof`/`sizeof` agree
  with the C compiler; field reads and writes use the exact field width (`i8`/`i16`/`i32`
  truncate on store and sign- or zero-extend on load, via portable byte-wise runtime
  helpers shared by all targets). A record parameter crosses as the address of its fields
  (`R *`); Grail keeps ownership of the allocation and frees it at scope end, while C must
  not free or retain it. Nested records, record results, pointer/float fields and by-value
  struct passing are rejected with diagnostics rather than approximated. Adds
  `tests/ffi/extern_records.grl` (C reads and writes Grail fields; `offsetof`/`sizeof`
  verified from C) and three rejection fixtures. See `docs/ffi.md`.

- v3 C FFI increment 4: C callbacks and function pointers. `extern "C" fn name(...) { ... }`
  defines a Grail function that C can call: it is emitted with the stated (unmangled) C
  symbol, `as "name"` renames it, and its signature must sit inside the C ABI slice.
  `cfn(P...) -> R` is the type of a C function pointer (one word, no environment, C
  calling convention); only `extern "C"` definitions produce such a value, so a closure or
  an ordinary Grail function is a type mismatch where C expects a callback, and a foreign
  declaration still cannot be used as a value. The generated code preserves the
  callee-saved registers it allocates, verified by a shim that clobbers `rbx`/`r12`-`r15`
  around the callback. `tests/ffi/callbacks.grl` covers a direct callback, a renamed one
  and the register-preservation case; two rejection fixtures cover a mismatched callback
  and `cfn` arity. Variadic callbacks and callback results are still rejected. See
  `docs/ffi.md`.

- Added executed Windows evidence for the C ABI without a Windows SDK:
  `tests/abi/wine_harness.c` is cross-built with Zig's MinGW-w64 target and run under Wine,
  covering file metadata follow/no-follow, hidden attributes, non-reparse readlink rejection,
  symlink readlink/realpath, regular-file non-blocking rejection and `localhost` DNS (47
  checks). Fixed Windows `fs_stat` to follow symlinks unless `GRAIL_STAT_NO_FOLLOW` is set by
  opening the path with `CreateFileW` and using `GetFileInformationByHandle`.
  `tests/abi/macos_metadata_dns_check.c` compiles the same metadata/reparse/DNS call sites for
  Apple ARM64 without execution. Added `tools/test-abi-wine.mjs` and `just abi-wine-test`.

- Abundance CPU port, executor increment: `abundance/src/job_executor.grl` runs the policy order
  through Grail's structured parallelism (`task_scope`/`spawn`/`join` over clone-created OS
  threads) in batches as wide as the worker count, with cancellation filtered before batching, a
  refusal for worker counts outside 1..4, and completion/checksum accounting. The job test now
  covers 47 exact values: 100 repetitions at 1, 2 and 4 workers each reproduce the same dispatch
  digest, completion count and checksum, and the dispatched order equals the policy oracle's.
  Suite total 254 exact values. Two port bugs fixed on the way: a four-id batch packed by
  multiplication overflowed u64 (bit packing now) and cancelled ids were only checked at the batch
  head (filtered up front now).

- Abundance CPU port, job-priority increment plus a container-ergonomics note: `abundance/src/job_policy.grl`
  carries `JobPriority::key()`/`from_key()` (class << 32 | f32 rank bits, with the engine's
  non-finite and negative clamps), `terrain_rank()` and the documented admission policy model; the
  reference links the engine's own symbols. Two arithmetic bugs found on the way are fixed and
  recorded: an unsigned exponent subtraction underflowed for every f32 value below 1.0 (the SIGABRT
  in the first cut) and the rank's level term is max(0, 32 - level). The committed job test now
  covers 30 exact values, including the model's execution order and counters.
  `docs/design/grail-container-ergonomics.md` records what the entity and checkpoint work cost:
  affine loops over owned aggregates, no reference to nested-vector elements, no in-place field
  writes through an index, reference rebinding at every call, and the syntax facts that each cost a
  compile iteration. Suite total 237 exact values.

- Abundance CPU port, entity-registry increment: `abundance/src/entity_table.grl` carries the
  entity registry's persisted state — dense id-ordered rows of id, type, owner, position, spawned
  clock and opaque payload, encoded as `ab::tx::PagedRows` writes it (u32 count then every row) —
  with the decode refusals for non-ascending keys, the codec's sequence and string caps and exact
  consumption. The reference builds a 290-row table through the real registry operations (out-of-
  order inserts, a rejected duplicate, ten erases, a mutate) and both sides reproduce 20 599 bytes
  with FNV 15354762378023838882 plus seven malformed-encoding verdicts. The suite now compares 207
  exact values (math 63, hashing 16, world 25, cache 46, checkpoint 39, entity 18). The in-memory
  page machine (256-row pages, split at 129, merge under 64, bulk fill 192) is documented rather
  than ported because it decides only page_count.
- Port Borg Agent's local-session ownership state (`borg/`). `src/session_state.grl` carries the
  owner record (`schema_version`, `pid`, `executable_identity`, optional `package_version` and
  `process_start_time`) through the JSON codec, the `dev:ino:len:mtime:mtime_nsec` executable
  identity, the `/proc/<pid>/stat` start-time parse, and the two decisions built on them: whether a
  recorded owner is still the same live process, and whether a stale owner may be retired. The
  rules are cited from `crates/borg-agent-runtime/src/local_control.rs:405-671` and reproduced
  exactly, including that a record which does not parse or carries an unknown schema counts as
  absent. Because `borg-agent-runtime` cannot be linked as a reference, `tests/parity/session.rs`
  carries those functions verbatim with citations, and `bun tools/borg-test.mjs --anchors` fails if
  the cited snippets disappear from the Borg checkout. The port now checks 603 reference lines over
  73 documents. Sockets, presence counting and process termination remain out of scope.

- Port Borg Agent's configuration loading (`borg/`). `src/toml.grl` parses and assembles the TOML
  subset Borg's configuration corpus actually uses — strings with escapes, integers in four bases,
  booleans, arrays, inline tables, `[table]` / `[a.b]` headers and comments — canonicalising keys
  into map order, materialising empty headers as empty tables, and rejecting a redefined header.
  Floats, dates, multi-line strings, arrays of tables and dotted inline keys are refused by name
  rather than approximated. `src/config.grl` loads `agent.toml` into effective settings with the
  defaults `crates/borg-cli` compiles in (`impl Default for CapabilityConfig`, `UsageCountConfig`,
  `PromptConfig`, `UpdateConfig`), and reports a wrong-typed key or negative count as an error at
  its path instead of falling back, and capability values are the effective ones: the dependent
  features are intersected the way `apply_dependency_intersection` does (`contract.rs:1403`). Two
  new reference suites compare against the `toml` 1.1.4 crate — the version Borg builds with —
  walking the same value model in the same order; the port now checks 483 reference lines over 50
  documents across JSON, protocol headers, TOML and configuration. Network, IPC and UI remain out of
  scope.

- Port Borg Agent's JSON substrate and runtime-protocol v1 envelope headers (`borg/`). `src/json.grl`
  parses and writes JSON with the exact semantics `crates/borg-*` rely on, measured against
  `serde_json` 1.0.151 with `arbitrary_precision`: numbers keep their decimal text (`1e+5`,
  `-0` -> `0`, 30-digit integers unrounded), objects canonicalise into `BTreeMap` key order with
  last-wins duplicates, strings use the minimal escape set, encoding is strict, and nesting stops at
  serde_json's 127-container limit. `src/wire.grl` validates the v1 header rule and reports the
  failing path and layer. `tools/borg-test.mjs` diffs both suites against committed references that
  `--regenerate` rebuilds from serde_json itself, so the port is checked against Borg's JSON rather
  than a restatement of it (187 reference lines over 31 documents). Command, event and snapshot
  bodies, and every network, IPC and UI concern, remain out of scope.

- Add `docs/platform-status.md`, an explicit matrix of executed, cross-built and scaffolded targets, so Windows PE output and macOS ABI headers are not mistaken for runtime support.
- Added an LSP MVP (`tools/lsp.mjs`): JSON-RPC over stdio with
  initialize/shutdown, didOpen/didChange/didClose and
  `textDocument/publishDiagnostics`. Diagnostics come from the compiler's
  existing `grail check FILE` output (`file:line:column: message`), mapped to
  UTF-16 LSP ranges with version and generation guards; the server never
  fabricates a language diagnostic and reports a missing compiler with
  `window/showMessage`. A real stdio test covers initialize/shutdown, an
  unknown request, a valid document, an invalid document and a didChange
  repair. CI runs the protocol tests in `tooling` and the compiler-backed
  session in a preflight-gated `lsp` job. Workspace checks, hover, definition,
  formatting, completion and pull diagnostics remain future work.
- Cross-platform tooling now treats `windows-x86_64` as a real **build-only**
  lane: `tools/ci.mjs build/test/package` cross-compiles the compiler to a
  PE32+ console image, verifies COFF objects, imports and image headers, and
  packages a zip whose manifest and `WINDOWS-BUILD-ONLY.txt` state that the
  Windows runtime is not implemented and the image must not be executed. The
  support matrix now distinguishes `supported`, `build-only` and `planned`,
  and every platform/lane reports `runnable` explicitly. CI also runs the
  runtime ABI contract suite (`tools/abi-test.mjs`) and the graphics C/shader
  suites, and the Windows x86-64 cross job is a required release gate for
  build/static checks. Windows AArch64 and macOS remain planned.
- Abundance CPU port, landscape-digest increment: `abundance/src/landscape_digest.grl` carries
  `terrain::landscape_world_content_digest` — FNV-1a from the standard offset basis over every byte
  the engine's landscape writer emits, plus the byte count — and the world envelope's `ABWLA001`
  branch is now exercised end to end. The reference builds a real landscape authority the way
  Abundance's own `tests/world_landscape_tests.cpp` does, writes its 721 840-byte serialisation and
  prints both the digest and `World::content_hash()`; the Grail side recomputes the digest from
  those bytes and reproduces the world hash that binds it. The suite now compares 104 exact values
  (math 63, hashing 16, world envelope and landscape digest 25).
- Abundance CPU port, world-hash increment: `abundance/src/world_hash.grl` carries the
  `World::content_hash` envelope — generator identity, configuration, twenty raster layers, drainage
  DAG, geology/province/biomes, material masks, provinces, caves, sites, regions, corridors and
  landform records — with the C++'s uneven count prefixes and eight-byte float widening preserved.
  `abundance/tests/parity/world.cpp` generates a real world with Abundance's own generator, dumps
  its inputs and prints `world.content_hash()`, so the Grail side reproduces a value `ABWCACH5`
  caches and `ABCP2` checkpoints bind, not a transcription of it. The suite now compares 99 exact
  values (math 63, hashing 16, world envelope 20); the terrain landscape-digest branch is recorded
  as the one unported branch.
- Abundance CPU port, hashing increment: `abundance/src/hash.grl` carries `fnv1a64` (with the
  seeded continuation form), the frozen world/checkpoint starting constant from
  `World::content_hash`, and its little-endian `absorb_byte`/`absorb_u64` accumulator. The reference
  is Abundance's own `tx/codec.hpp` plus a verbatim replay of `world.cpp`'s absorb loop, and all 16
  values match; the suite now compares 79 values across math and hashing. Standard-library SipHash
  is asserted to disagree so it cannot be substituted for an id or checkpoint hash.
- Abundance CPU port, first increment: `abundance/src/math.grl` carries the engine's CPU math
  contract (Vec3/Vec4/DVec3/Mat4, row-major multiply and transform, cofactor inverse, `look_dir`,
  reverse-Z infinite projection, camera-relative origin split). `just abundance-test` compiles the
  Grail module and diffs 63 bit patterns against a reference generated by compiling Abundance's own
  `engine/core/math.hpp`/`math.cpp`; every value matches. Documentation is in `abundance/README.md`.
- New design document `docs/design/abundance-port.md`: inventory of the Abundance portable core, own engine, Unreal host and shaders, their CPU/RHI boundary, the FFI/ABI requirements a Grail host would have to meet, and a staged port plan. Documentation only; no compiler or library behaviour changed.
- Graphics foundation (`graphics/`): a versioned C ABI for the render hardware interface and
  the shader pipeline, aligned with the Vulkan engine in Abundance. `grail_abi.h` defines
  64-bit tagged handles whose stale use is detected rather than dereferenced, status codes,
  capability bits and `{size, next}` descriptors. `grail_window.h` covers the SDL3 window,
  event drain and input; `grail_rhi.h` the device, queue timelines, resources, dynamic-rendering
  command buffers, deferred destruction and swapchain; `grail_bindless.h` the single set-0
  table and set-1 frame constants together with the Vulkan/D3D12/Metal mapping; `grail_shader.h`
  an offline reflection blob format, pipeline descriptors and permutation keys; per-backend
  headers state the Vulkan 1.3 feature floor, the D3D12 root signature and the Metal argument
  buffer requirements. `grail_wire.h` carries the same POD structures over a socket for a
  process that cannot link the RHI.

  The null backend implements every entry point and validates arguments, recording order and
  handle liveness without a GPU; `make -C graphics test` runs 219 checks with only a C
  compiler. Three HLSL stages compile offline with DXC 1.9.2609 and pass
  `spirv-val --target-env vulkan1.3`. Two binding facts are pinned by compilation rather than
  assumed: `register(xN, spaceM)` maps to Vulkan `DescriptorSet M`/`Binding N`, and push
  constants must use `[[vk::push_constant]]` because a plain `cbuffer` at `b0` would become a
  descriptor colliding with the sampled-image table. The offline shader tool and the real
  backends are not yet written; a Grail program cannot call any of this until the language has
  an FFI and non-`libc`-free linkage (`graphics/docs/first-renderer-port.md`).
- Cross-platform build/test/distribution foundation: a seven-platform CI matrix
  (Linux x86-64/AArch64/RISC-V64, Windows x86-64/AArch64, macOS AArch64/x86-64),
  host/SDK/QEMU detection, deterministic `tar.gz`/`zip` packaging with
  `SHA256SUMS` and provenance, POSIX/PowerShell installers, and secret-safe
  signing/notarization hooks. Linux lanes build and test; Windows/macOS lanes are
  explicit distribution scaffolding because the compiler still emits Linux ELF
  only. Tooling is documented in `docs/tooling/cross-platform-ci.md`.
- Added statically verified first-layer Windows and macOS backends for the OS ABI, using
  pinned Win32 and Darwin declarations so both compile for their targets without platform SDK
  headers. Implemented init/capabilities/error detail, clocks and sleep, environment
  get/set/unset/snapshot iteration, current directory and executable path, and file basics
  (open/read/write/seek/truncate/sync/close, pipes, mkdir/remove/rename; Windows also stat,
  macOS also non-blocking mode, readlink and realpath). Every unimplemented function is still
  an explicit `GRAIL_E_UNSUPPORTED` stub and the capability word advertises only the first
  layer. Added a shared environment store with host tests and separate `GRAIL_CAP_FILE_METADATA`,
  `GRAIL_CAP_FILE_NONBLOCKING` and `GRAIL_CAP_SYMLINKS` signals.
  `bun tools/abi-test.mjs` compiles each backend for `x86_64`/`aarch64` Windows and
  `arm64`/`x86_64` macOS and verifies all 95 public symbols with `llvm-nm`. These backends have
  not been executed on Windows or macOS; metadata, directory iteration, local time offsets,
  processes, sockets, threads and dynamic libraries remain fail-closed there.
- The Linux reference backend now implements the child-process contract with
  fork/execve/wait4: explicit argv/environment blocks, working directory, stdin/stdout/stderr
  wiring, PATH search, exec-error reporting through an error pipe, blocking and timed waits,
  SIGTERM/SIGKILL termination, process id and single-close handles. It also implements the
  first TCP/UDP socket subset: IPv4/IPv6 create/bind/listen/accept4/connect/send/recv,
  send_to/recv_from, shutdown, address queries, non-blocking mode, the documented socket
  options and blocking `getaddrinfo`, with negative-errno mapping and capability bits. Tests
  cover argv/environment/cwd/stdio, exit status, PATH search, timeout/terminate/kill, loopback
  TCP and UDP, options and DNS; the full Linux behaviour test is now 344 checks with zero
  tracked allocation bytes. Windows/macOS remain fail-closed. C-to-Graal callbacks remain a
  later FFI increment and allocator/thread callbacks stay backend-side.
- Added the child-process and socket/DNS contracts with explicit ownership, error and
  platform-search rules, plus fail-closed Windows and macOS backend skeletons. The Linux
  reference backend reports both domains as unsupported and clears their capability bits;
  a skeleton conformance test verifies that init fails closed, capabilities stay zero and
  representative entry points return `GRAIL_E_UNSUPPORTED`. Documented the full Win32/Winsock
  and libSystem/Mach mapping in `runtime/abi/README.md` and the safe Grail surface in
  `docs/design/runtime-api.md`.
- Added a hosted Linux reference backend for the OS ABI (an ABI oracle, not a Grail build
  path): startup/environment seeding and iteration, monotonic/realtime/CPU clocks and sleep,
  file open/read/write/seek/stat/sync/close, directory iteration, pipes, mkdir/remove/rename,
  current directory and executable paths, pthread threads (spawn/join/detach), mutexes,
  condition variables and `dlopen`/`dlsym`. Processes and sockets remain explicitly
  unsupported with clear capability bits. The end-to-end test verifies 165 checks and zero
  tracked allocation bytes at shutdown.
- Added the resource-domain headers for files/directories/pipes, environment iterators,
  native threads/mutexes/condition variables and dynamic libraries, plus a generation-checked
  handle table that rejects stale, double-closed and cross-domain handles. Contract tests
  cover 1000 handle allocations, reuse, foreign-table rejection and destruction; all headers
  parse for the five ABI targets.
- Added the lexical path contract (`include/grail/grail_path.h`) with one implementation
  for POSIX and Windows rules: absolute/relative detection, join, parent, file name,
  extension and normalization. Both rule sets are exercised on Linux, including drive-relative
  `C:` paths, UNC anchors and canonical `/` output.
- Added the cross-platform OS ABI contract under `include/grail/`: 64-bit scalar and pointer
  calling rules, opaque linear handles, version negotiation, allocator/startup records,
  portable error codes with raw OS detail, and strict UTF-8/UTF-16 helpers. Portable
  implementation and C tests cover version checks, every error mapping (errno, Win32, Mach),
  and Unicode rejection/round-trip cases. Linux, AArch64, RISC-V 64, Win64 and Apple ARM64
  header parsing is checked. Nothing is linked into Grail builds; `compiler/native.grl` and
  `runtime.grl` are unchanged.
  only. Tooling is documented in `docs/tooling/cross-platform-ci.md`; the
  LSP/debugger/profiler integration plan is in
  `docs/tooling/lsp-debugger-profiler.md`.
- Windows x86-64 programs now run: the runtime gained an OS layer
  (`compiler/os-windows.grl`) behind the existing operation IDs, and a new `raw_win32(Symbol, ...)`
  intrinsic emits Win64 calls with shadow space, register arguments and stack arguments. Console
  output, integer/float formatting, file write/read, exit codes and command-line arguments
  (via `GetCommandLineA`) work under Wine; allocation uses `VirtualAlloc` and the thread pointer
  reads TEB+0x28. The Linux syscall boundary moved to `compiler/os-linux.grl` so exactly one OS
  layer is compiled per target; `bun tools/windows.mjs check` executes eight PE cases under Wine
  when available, and the CLI resolves the OS layer next to the runtime (it still refuses to link
  PE images itself, pointing at the Windows tool). Threads, sockets, directory listing,
  `mremap` and `.pdata` unwinding remain unimplemented.
- New `windows-x86_64` target emits COFF-compatible x86-64 assembly for PE32+ console images:
  MSVC `.def` function records replace ELF symbol types, a `grail_entry` PE entry point replaces
  `_start`, process exit is an `ExitProcess` import and the allocation intrinsic maps to
  `VirtualAlloc` with TEB-based thread storage. `tools/windows.mjs` writes COFF short-import
  objects into `kernel32.lib` and links with `lld-link`; `bun tools/windows.mjs check` inspects
  the assembly, the COFF object and the PE image. The Windows runtime, `GetCommandLineA` argv
  recovery, worker threads and `.pdata`/unwind data are not implemented, so PE programs compile
  and link but must not be executed yet. Command-line option errors now print a diagnostic and
  exit 1 instead of aborting without output.
- macOS targets `macos-x86_64` and `macos-aarch64` emit Mach-O objects and executables: underscored
  C symbols, `.build_version`, `__TEXT,__const` literals, `__DATA,__bss` state, AArch64
  `@PAGE`/`@PAGEOFF` addressing and a `_main` entry that takes `argc`/`argv`/`envp` in the Apple C
  argument registers and exits through libSystem `_exit`. `compiler/darwin.grl` is the Mach-O
  platform module (`unsafe module runtime`, selected instead of `os-linux.grl`) and owns the
  libSystem boundary: file/console I/O, mmap and a `mremap` emulation, poll, pipe, mkdir/unlink,
  directory records, clock, sleep, yield, process control, plus Darwin flag-bit, `struct dirent`
  and `errno` translation. The runtime calls its `rt_call` bridge directly, so the compiler emits
  no Darwin-only symbols. Link with
  `ld64.lld -platform_version macos 11.0 11.0 -lSystem -e _main`; `bun tools/test-macos.mjs` checks
  the objects and executables statically. Threads, the async reactor and sockets report `ENOSYS` on
  Darwin, and no macOS runtime behaviour is verified without Apple hardware. Invalid `--target`
  values are now reported instead of aborting silently before any source is loaded.

- Native fixtures, inline regression programs and book examples now use typed references and
  explicit byte views under `--default-u64 --typed-refs`; user-mode cases retain `i64` defaults.
  Ownership/lifetime rejection fixtures use the modern dialect so they still test their intended
  safety checks; intentionally removed-syntax tests retain their invalid inputs. Closure capture
  discovery recognizes `&mut` expressions correctly, and typed borrows of captures retain their
  checked read-only storage frame.

- Compiler and standard-library source now uses typed `&value` / `&mut value` references,
  explicit `view` / `view_mut` byte views, and `&a [u8]` / `&a mut [u8]` signatures.
  `--typed-refs` separates the internal reference dialect from numeric defaults, which remain
  `u64` internally and `i64` for user modules. The normal regression corpus uses typed-reference
  mode; removed syntax is retained only as intentional rejection input. All checked-in bootstraps were refreshed
  and self-host byte-identically. Deferred
  generic and closure bodies restore their defining module's numeric and reference modes.

- Concise type syntax: `T[]` vectors, `u8[]` byte buffers, `T?` optional values and
  `[K: V]` maps. The `num` spelling is removed; user modules default to `i64`, while lengths,
  indices and byte counts are explicit `u64`. `Option`, `Result`, `Pair`, tuple syntax,
  `ref`, `ref_mut`, and the public map/option storage names are not exposed.
- Structural results use `S |? F`: success and failure alternatives are normalized
  separately, bare values convert implicitly, matching is exhaustive by type, and generic
  instantiation rejects overlapping or duplicate members. Ordinary `A | B` unions are
  unordered and carry no success/failure meaning. `?` and result-`!` apply only to `|?`.
- Prelude `Some(value)` and context-inferred `None` construct `T?`; typed patterns use
  `data: T` or a bare `T`, and nominal enum variant patterns remain available. Type aliases
  such as `type LoadError = IoError | ParseError` are supported.
- Function and method references use fresh input lifetimes. An elided output uses the borrowed
  receiver or the sole distinct input lifetime; distinct groups use free names such as `&a` and
  `&b` without a lifetime parameter list. Ambiguous outputs are rejected.
- `use module::Name;` imports a type or interface member. `use order::Ord;` resolves bounds
  and impls through the canonical `order::Ord` path instead of creating a local phantom.
- Read-only shared-reference parameters auto-borrow owned arguments at resolved call sites,
  including literals and owned views. `&mut` arguments remain explicit.
- The old `&mut a T` lifetime order is rejected in user modules; write `&a mut T`.
- The public `borrow`/`borrow_mut` builtins and `read<a>`/`mut<a>` view types are removed in user
  modules. Use `&value`/`&mut value` and `&[u8]`/`&mut [u8]`; compiler and standard-library
  source now use the same reference syntax.
- User-mode loops consume their iterable. Owned vectors move elements into the loop, enabling
  `for part in name.split(' ')` and named non-scalar consumption; loop-owned elements and the
  hidden container are cleaned on normal exit, break and return.
- Maps expose method-first operations: `len`, `contains`, `insert`, `get`, `get_mut`, `remove`
  and `entry`. Lookup methods borrow the key; `insert` consumes it and returns the previous value.
  `entry` returns a named `Entry<a, K, V>` view with a shared key and exclusive value. The free
  `hashmap::map_*` helpers are internal implementation details.
- Map expressions are concise: `[K: V]()`, `[K: V]::with_seed(s0, s1)`, `[k: v]`, and
  context-only `[:]`. `map[key]` is a required place that aborts on a missing key; assignment
  upserts; compound assignment updates an existing key; `get`/`entry` remain optional. Indexed
  assignment currently accepts named or field receivers, not call-result receivers.
- User modules reject `usize`, `core::some` and `core::none`; use `u64`, `Some(value)` and `None`.
- Checked-in x86-64, AArch64 and RISC-V64 bootstraps were refreshed from the v2 compiler and
  independently self-host byte-identically; the published-bootstrap suites pass on x86-64.
- Nominal concurrency types are capitalized: `Atomic<T>`, `Mutex<T>`, `Scope<C>`, `Task<R>`
  and `CancelToken`, with `Atomic::new` / `Mutex::new` constructors.
- Type syntax is now postfix and concise: `T[]` is a vector (`vec<T>` is gone), `u8[]` is the
  byte buffer (`bytes` is gone), and `T[...]` / `T[]` are the element and empty literals. A type
  may be parenthesized when its literal needs one, e.g. `(fn(num)->num)[f]`. The byte-buffer
  literal rejects elements above 255. Compiler, standard library, book, examples, tests, docs and
  the checked-in bootstrap have all been migrated; `grail fmt` understands the new spelling.
- `grail fmt` breaks long lines the way rustfmt does: a match arm moves its body after `=>`,
  binary operator chains break before each operator, postfix chains put one `.method()` per
  line, and bracket lists put one item per line. Record literals expanded this way also take a
  trailing comma, which the language accepts there (call arguments, parameter lists and generic
  arguments reject one, so they stay comma-free). The formatter is still token-level and
  idempotent; formatted sources compile to byte-identical assembly.
- Faster generated code: inline `push` fast path (growth only calls the runtime, large buffers grow in
  place with `mremap`, fresh memory is not re-zeroed), inline sized-integer arithmetic, comparisons
  and division, bounds checks dropped in `for i in v.len()` loops that cannot change `v`, and
  inlining of small leaf functions. A 5M-element sieve runs in 83 ms (was 207 ms), an `i32` loop in
  0.17 s (was 4.7 s).
- `bytes` and `string` store one byte per element instead of one word; the compiler's own peak memory
  for self-compilation drops from 1.5 GB to 0.18 GB.
- `mut` literal bindings take the type of their first sized use anywhere in the function
  (`mut count = 0; count += 1; show(count)` with `show(level: u8)`); the function is recompiled with
  that type. Conflicting uses are rejected.
- Equality on structs, enums and vectors containing `char` works.
- Indexed assignment: `v[i] = x`, `v[i] += x` and `s.items[i] = x` on vectors (the old element is
  dropped) and `buf[i] = b` on bytes; the right-hand side is evaluated first.
- `f32` closures and function values accept float literal arguments; exponent-only float literals
  (`1e9`, `2E-3`) are accepted.
- Optimized code generation: a per-function optimizer (`compiler/optimize.grl`) forwards stack
  slots through registers, removes dead stores and moves, keeps hot variables in callee-saved
  registers, fuses compare-and-branch sequences, turns division by powers of two into shifts and
  inlines bounds-checked element access. On x86-64 a Collatz loop runs in 213 ms instead of 620 ms
  (Rust -O: 85 ms), a 5M-element sieve in 207 ms instead of 689 ms (Rust -O: 33 ms), and the
  compiler builds itself in 15 s instead of 27 s. All three targets share it; output stays byte-identical on self-compilation.
- `borrow(...)`/`borrow_mut(...)` accept temporaries (`borrow(make())`, `borrow(v.len())`,
  `borrow(Point { x: 1, y: 2 })`); the value lives until the end of the enclosing block.
- In `match borrow(x)`, the borrow ends at the last use of the payload references, so an arm may
  then modify `x`.
- Unsuffixed literal bindings infer their type from later use: `n := 5; takes_u8(n)` works, and
  `mut sum = 0; sum += x_i32;` makes `sum` an `i32`. Float literal bindings adopt `f32` the same way.
- New `f32` type (`1.5f32`, contextual literals, `f32(x)`, arithmetic rounded to binary32, shortest
  round-trip printing identical to Rust) and `char` type (Unicode scalar values, `'é'`, `'\u{1F600}'`,
  `chars()`, `push_char`, `char(n)`, `u32(c)`, comparisons, `match`, classification and case
  methods). ASCII literals like `'a'` stay byte values unless a `char` context adopts them.

- References to `bytes`/`string` coerce to views (`read<a>`) in calls, like `&String` to `&str`.
- `parallel_map` accepts closures; realistic sample programs (CSV report, inventory CLI, parallel primes) join the test suite.
- Text operators read through references (`words[0] == "GET"`); clearer error for borrowing a temporary.
- Recursive data types (`enum Tree { Leaf, Node(Branch) }` with `Branch` holding `Tree`) are supported.
- `borrow(v[i])`/`borrow_mut(s.items[i])` borrow vector elements; calculator and binary-tree sample programs.
- `to_upper`/`to_lower` map Latin-1, Latin Extended-A, Greek and Cyrillic letters; word-frequency sample program.
- JSON parser/printer and HTTP server/client sample programs join the test suite.

- Add tuples (`(num, bytes)` types, `(a, b)` values, `t.0` access, `(q, r) := f();` destructuring,
  Debug-style printing), `match` on integers/bytes/bools with literal, range (`0..10`), binding and
  guard (`n if n > 3`) patterns, `_` default arms for enum matches, typed bindings
  (`mut total: i32 = 0;`), `for p in borrow(v)` over non-scalar elements, closures inside generic
  functions, dot-call syntax for implemented interface methods, hex/binary/octal literals with `_`
  separators, `f64` constants, and contextual literal typing for returns, assignments and vector
  literals.
- Formatting: width/fill/alignment specs (`{:>8}`, `{:*^9}`, `{:05}`, `{:8.2}`), Rust-Debug-style
  printing of vectors and tuples. Diagnostics show the source line with a caret; missing input
  files are reported. `grail check` type-checks without building.
- Libraries: `math` (exp, ln, log2, log10, sin, cos, tan, atan, atan2, pow, round, ... within 1 ulp
  of Rust's std except pow), insertion-ordered `hashmap` with `key_at`/`value_at` iteration,
  `order::Ord` with a stable generic `vecs::sort`, Unicode `strings::chars`/`push_char`,
  `replace`/`repeat`, `env::args`/`env::var`, `process::exit`, and typed `io::Error` results from
  `fs` (`read_text`, `create_dir`, `remove_file`, `remove_dir`, `list_dir`).
- Text: `==`/`<` comparisons and `+` concatenation for strings, bytes and views; built-in
  `trim`, `split`, `contains`, `starts_with`, `ends_with`, `replace`, `repeat`, `to_upper`,
  `to_lower`, `is_empty`. Vectors: `insert`, `remove`, `swap`, `reverse`, `truncate`, `clear`,
  `contains`. Borrowing a method result now gives a clear error. Book: Working with text,
  Collections, Tuples and patterns chapters.
- Structural `==`/`!=` for structs, tuples and enums (including `Option`/`Result`).

- Add `f64`: correctly rounded literals, IEEE arithmetic and comparisons in hardware on x86-64,
  ARM64 and RV64 (RISC-V now assembles for `rv64imafd`), checked conversions, `sqrt`/`abs`/`floor`/
  `is_nan`, and shortest round-trip printing identical to Rust's `{}` (checked on 408 values), and `{:.N}` fixed
  precision with exact half-to-even rounding. Compound assignment works on all integer types and f64.
  Add `Option`/`Result` methods (`is_some`, `unwrap_or`, `map`, `ok_or`, `is_ok`, `ok`, ...).

- Add inherent methods (`impl Type { ... }`, including generic `impl<T> Stack<T>`), method calls on
  variables, fields, references and temporaries, `Type::function` associated functions, enum
  methods with `match` through references (payloads bound as references), `show()` for printing
  user types, formatted `print`/`println("{} {}", a, b)` and `format(...)`, `if let`, `while let`,
  `else if`, `loop`, `for i in a..b`, module `const` values, byte character literals (`'a'`),
  struct field shorthand, and the `vecs`/`strings` libraries. Book: Methods and Printing chapters.

- Add sized integers (`u8`..`u32`, `i8`..`i64`) with literal suffixes, contextual literals,
  checked/wrapping/bit conversions and signed arithmetic; `bool` with `&&`/`||` (short-circuit) and
  `!`; the operators `>`, `<=`, `>=`, `|`, `<<`, `>>`; and capturing closures `|x: T| -> R body` of
  type `Fn(T) -> R` that copy or move their captures. Diagnostics now report `file:line:column`.
- Add `for x in v` over scalar vectors and byte sequences, TCP sockets on the colourless reactor
  (`host::tcp_listen/accept/connect`), recoverable file errors (`lib/fs.grl`: `fs::read`/`fs::write`
  return `Result`), `?` across Result types with the same error type, and lex `x!==y` as unwrap
  then `==`.

- Add the `grail` command-line tool in the compiler binary: `build`, `run`, `test`, `fmt
  [--check]`, `new`, `add` (git dependencies pinned in `grail.lock`) and `fetch`, plus
  `just install`. Add a comment-preserving, idempotent rustfmt-style formatter whose output
  compiles to byte-identical assembly. Existing compiler invocation is unchanged.

- Add structured task scopes (`task_scope`, `spawn`, `join`, `cancel_token`) and colourless
  suspension: tasks are stackful green threads on a worker pool with an epoll reactor; pipe I/O
  and sleeps suspend only the calling task, blocking file/process calls move to offload threads,
  and cancellation wakes waiting tasks. Handles cannot outlive their scope; dropping one never
  blocks. Processes now exit with exit_group. Verified on x86-64, ARM64 and RV64.

- Add real multi-threaded structured parallelism: `parallel_map(items, context, f)` runs on
  clone-based worker threads with dynamic work claiming and joins all workers before returning;
  Send/Share/borrow rules are checked. Add futex-based `mutex<T>` with lock-scoped `lock_with`
  access whose loans cannot escape, keyed SipHash-2-4 `hash` interfaces, a checked
  `hashmap::Map` and a sharded `concurrent_map::Map`. Verified on x86-64, ARM64 and RV64,
  including a barrier proving simultaneous execution and contention tests. Closures, cancellation
  and colourless suspension remain unimplemented.

- Add explicit user-defined interfaces, concrete implementations, checked generic bounds and
  static method dispatch, including module-qualified calls and method values. Check ownership
  and lifetime contracts; reject overlapping/orphan implementations and unsafe-runtime exposure.
  Generic interfaces, associated types, blanket implementations and dynamic dispatch remain absent.

- Add typed capture-free function values (`fn(T)->U`), generic callbacks, returned function
  values, indirect calls and explicit generic function items (`identity<num>`). Preserve
  callable lifetime/return-origin contracts; capturing closures remain in progress.
- Add checked structural `T:Send+Share` bounds and opaque `atomic<num>` with sequentially
  consistent operations, explicit valid load/store orderings and modular fetch arithmetic.
  Atomic receiver loans prevent argument evaluation from moving or replacing their owner.
  ARM64 uses exclusive operations/barriers; RISC-V now explicitly requires RV64IMA / LP64.
- Serialize runtime allocation and prepare executable paths before fork, keeping allocations
  and locks out of the child. Runtime file descriptors are close-on-exec. These are concurrency
  prerequisites, not a claim that worker tasks or colourless I/O are implemented.

- Audit all 32 Rust/Grail book pairs: remove unnecessary entry-module headers, use current
  collection literals, pair separate module files in both languages, align fail-fast I/O behavior,
  exercise Unicode argv byte lengths, and clarify ownership, truth-value and arithmetic differences.
  Rust verification now explicitly enables overflow checks and abort-on-panic; supporting modules
  require a checked counterpart instead of displaying an unpaired Grail-only snippet.

- Make the Grail-written compiler the sole language implementation: remove the Rust seed and
  unchecked C compiler/runtime/bootstrap, migrate maintained examples/library sources and 149
  language regression cases, and replace duplicate compiler tests/builds with seed-free tooling.
- Add direct ARM64 and RISC-V 64 Linux assembly lowering alongside x86-64, native syscall/ABI
  handling, target-default self-hosting, executable cross tests and verified compressed bootstraps.
  Add explicit `--target` selection and `--overflow=checked|wrap`; wrapping opts out of user
  arithmetic checks only, retaining runtime allocation/arithmetic, bounds and ownership guards.
- Extend the book runner to native/cross Linux targets without a Rust seed or C backend. CPU
  support does not imply macOS or Windows support; those operating systems are not implemented.

- Unify collection expressions: add `bytes[...]` / `vec<T>[...]` literals and postfix `.push`,
  `.pop`, `.len`, `.copy`, `.text` and string `.append`; use `[i]`, `&v[i]` and `&mut v[i]`
  for vector access as well as byte indexing. Remove old free collection helpers. Add reserved
  `true` / `false` truth literals and bare uppercase generic parameters (`identity<T>`, `replace<a,T>`),
  retaining checked ownership and universal generic-body validation. Method-statement argument
  temporaries end at the full statement. Migrate the book and compilers.

- Unify mutable declarations and borrowing around `mut`: replace `var` with `mut`, and byte-view
  `read(x)` / `mut(x)` with `&x` / `&mut x`. Replace `at` and `slice` calls with byte indexing
  `x[i]` and half-open `x[start:end]`, including omitted bounds. Indexing automatically borrows
  byte storage readonly and preserves borrow, evaluation-order and bounds checks. Migrate the
  maintained compilers, examples, tests and book; remove old builtin routes and regenerate bootstraps.

- Complete Rust comparisons for all 32 book examples, including control flow, modules, arguments,
  files and commands. Require comparison coverage and verify independent Rust arguments, fixtures
  and file outputs in isolated scratch directories.

- Make ordinary `num` addition, subtraction, multiplication and powers (including compound
  assignments) abort on overflow/underflow in every build profile across native, C and LLVM.
  Add explicit `wrapping_add`, `wrapping_sub`, `wrapping_mul` and `wrapping_pow` operations;
  migrate modular hashes and syscall error handling, update the book and regenerate both bootstraps.

- Replace `let` with immutable `:=` declarations and require `mut` for owned-storage mutation
  and mutable borrowing. Fixed explicit mutable capabilities may still write their referents.
  Migrate the maintained Grail compilers, source fixtures and book; regenerate both bootstraps.
- Add unsigned division, wrapping right-associative `**`, and numeric compound assignments
  `+=`, `-=`, `*=`, `/=`, `%=` and `**=` across native, C and LLVM lowering. Keep `^` as XOR;
  guard zero divisors and retain target capabilities through right-hand-side evaluation.
- Update the book to 32 checked Grail examples and 26 Rust comparisons. Default to light mode
  and globally visible Rust, remember explicit reader choices, remove decorative labels, and
  fix the comparison control wrapping across the header corner. Use plain truthy assertions.

- Add a quiet named `main`, optional unit result/final return and optional entry-file module,
  plus `print`/`println` with checked call-local borrowing and numeric output. Numeric main results
  set process status rather than being printed. Preserve the live numeric bootstrap test protocol;
  verify seed/native parity, owner reuse after printing and implicit-return cleanup.
- Add Grail by Example: 20 chapters, 32 verified Grail examples and 26 collapsible Rust comparisons,
  with aligned code/output workspaces, offline search, copy buttons, themes and mobile navigation.
  `just book` builds and opens the static book; companion recipes verify examples and tooling.

- Add invariant captured-storage assignment/replacement, captured vector updates and caller-side
  guard propagation, including generic `replace<T>`. Retain opaque local frame witnesses and
  attach new captures to their real storage owners. Ignore retired access-capability history
  after reassignment while preserving live-loan checks and branch restoration. Opaque external
  writes lacking a recoverable invariant contract remain conservatively rejected.

- Add native generic functions with inferred/explicit type arguments, cross-module specialization,
  regular recursion, and lifted capture lifetimes. Validate unused templates and keep opaque `T`
  affine even in numeric specializations; reject unsupported operations rather than exploiting
  the concrete instantiation.

- Add native generic records/enums with explicit and inferred constructor arguments, nested and
  borrowed type substitution, nominal argument checking, and specialized recursive destruction.
  Keep constructor and call-argument captures live during later argument/field evaluation,
  including nested calls.

- Connect native source-level loan/lifetime enforcement: reject live-borrow moves/growth/writes,
  escaping locals and captures, lifetime laundering, suspended unique carriers and malformed
  aggregate/reference operations. Retain concrete lifetime guards across opaque calls and copies;
  end loans at lexical last uses without confusing shadows, field names or loop iterations.
- Add positive seed/native borrow conformance and adversarial rejection cases, including opaque
  interior-reference returns and descriptor-copy provenance. Native stages reproduce exactly and
  normal exits require zero live allocations.
- Return large allocation arenas to the OS immediately; verify unmapping with `mincore` in the
  Grail runtime audit. Validate UTF-8 text construction/appending in the Grail runtime.

- Preserve native lifetime arguments and reference mutability; add type-shape checks and a
  Grail ownership graph with field-sensitive moves, loan authority and conservative joins.
  Wire move/initialization checks into source compilation, rejecting moved/uninitialized values,
  conditional moves and repeated consumption on backedges/continue, without replacing a prior
  artifact on rejection.
- Generate guarded recursive cleanup for native owned values, including partial fields, vectors,
  enum matches, returns, propagation and loop exits. Transfer ownership explicitly on moves and
  close consumed host-call descriptors. Require zero live allocations at normal program exit;
  native self-compilation and cleanup fixtures pass that check and reproduce their output.

- Replace native runtime support with `compiler/runtime.grl`: allocator/free lists, byte and
  sequence operations, file I/O, PATH search, process execution and numeric printing are Grail.
  Generated `_start` and narrow raw-memory/syscall intrinsics produce a static `as`/`ld` build,
  without C support objects, libc or a handwritten assembly runtime. Restrict raw intrinsics to
  an explicit unsafe runtime module. Verify native self-reproduction, binary I/O/command status,
  allocator reuse and balanced runtime allocations. Preserve the older C bootstrap only as an
  independent cross-check.

- Add a Grail-written Linux x86-64 backend (`compiler/native.grl`) emitting assembly directly,
  with System V calls, stack-slot locals, unsigned arithmetic, control flow, aggregates, typed
  references and the existing runtime ABI. Deliver reproducible `compiler/bootstrap/native.s`;
  native stages 2/3 are byte-identical. Verify both bootstrap routes, existing C artifact replay,
  differential programs and native abort paths. Runtime support is compiled separately from C;
  ownership checking, freeing and optimization remain unfinished. See `compiler/NATIVE.md`.

- Reach bootstrap v0: `compiler/grailc.grl`, a Grail-written compiler to C, is built by the seed
  and reproduces itself byte for byte (stage 2 = stage 3). Commit the stage-2 output as
  `compiler/bootstrap/grailc.c` with its runtime `compiler/grail_rt.c`, and check both plus
  seed-equivalent behaviour on examples in `bootstrap_native`. `grailc` does not check ownership.
- Fix seed liveness across `break`/`continue`: values read after a loop are no longer pruned when
  later body statements reassign them. Checker errors now include the function and register.

- Add generic owned `vec<T>` with push/pop/get and `std/collections.grl`; a trusted `host` module
  (argc/arg, read_file, write_file, print, command) for compiler drivers; and the first Grail-written
  compiler module, `compiler/lexer.grl`, returning borrowed tokens.

- Join conditional owned bindings/fields with definite-use checking and guarded native cleanup.
  Keep untouched fields usable, support consume-then-break exits, and reject repeated consumption.
  Checked IR/template bundles advance to schema 3; native O0/O2 ASan/UBSan paths are covered.
- Preserve all possible old captures when an opaque mutable reference can select multiple cells;
  precise single-target replacement still releases old captures. Add alias regression and native checks.

- Join retained local/external capture sources across branches and loop fixed points instead of
  requiring identical metadata. Recheck later iterations, separate break exits from backedges,
  preserve while-condition effects on zero-body paths, and normalize only dead temporary ancestry.
  Keep stored lifetime/capability bounds and reuse unchanged indexes. Validate hidden Option-pop /
  mixed-exit modules, C/LLVM execution, destruction, independent Rust, frozen replay and costs.
  Conditional moves/partial initialization, general heap collections and self-hosting remain unfinished.

- Admit captured mutable referents with invariant lifetime witnesses, universally checked generic
  storage operations and signature-derived opaque capture writeback. Preserve old/incoming sources,
  distinguish unique transfer from short reborrow, filter nested typed targets, and retire internal
  captures without losing external loans. Remove the temporary plain-kind machinery; use canonical
  IR/template bundle schema 2 with checked ascriptions. Close a reproduced stale external-cell proof
  across loop edges; general changing-state joins remain required. Validate hidden-source mutable
  cursors, generic Option pop/Result cleanup, mixed backends, independent Rust, allocator/sanitizer
  traces, frozen replay and measured costs. General heap collections and self-hosting remain unfinished.

- Support readonly typed references to captured values: distinguish dereferenced stored-source roots
  from outer frames, derive outlives constraints from written inputs and copy shared descriptors
  without extending unique-field reborrows. Check nested return bounds, preserve captures under
  live frame loans, emit proper nested const pointers and execute descriptor loads in C/LLVM.
  Retain hidden-source cleanup, independent Rust, frozen replay and cursor-token costs. Mutable
  capture witnesses/invariance/writeback, real general containers and self-hosting remain required.

- Add typed storage references for lifetime-free referents: explicit place borrows, indirect scalar
  loads, generic/core replacement, owned descriptor/record mutation and C/numeric LLVM lowering.
  Keep addressed scalar storage alive, enforce indexed field/storage exclusion and preserve owned
  relocation/recursive drop flags. Expose reference kind requirements in universal signature/body
  checking, uniformly refresh opaque mutable cell metadata and test source-hidden mixed-profile
  execution/free traces. Keep borrowed loop-entry values live across nested expression blocks,
  fixing a backedge rejection exposed by the mutable-state scanner. Captured-reference
  invariance/witnesses/writeback, general containers,
  remaining joins and full bootstrap/self-hosting are explicitly unfinished, not passed gates.

- Implement universally checked affine generic function bodies and static native specialization,
  inferred/explicit calls, eager snapshots and statement-end expression cleanup. Ship real Grail
  core Option/Result/Pair helpers, recursive calls, canonical rechecked IR/private helper closures,
  lifetime-erased layout-sensitive instance keys and bounded memoization. Bind IR in artifact schema
  2 / module schema 5, separately pin transitive generic implementations and reject stale/malformed
  consumers while preserving prior executables. Retain mixed-backend/independent Rust/cleanup and
  frozen-compiler checks plus token-workload costs. Typed-reference invariance/writeback, arbitrary-T
  heap collections, ownership joins, the real seed port and self-compilation remain unfinished.

- Implement checked `break`/`continue` for counted/while loops, including blocks, nested loops and
  matches. Close local loans and recursively drop local owners before jumping; preserve entry
  resources/scalar definedness and emit explicit C/LLVM targets/latches. Test source-hidden calls,
  unique-parent reactivation, complete release traces, condition-evaluation counts, mixed native
  profiles and a frozen 1,600-case replay. The existing conservative entry ownership invariant
  remains; general conditional ownership joins and full v0/self-hosting are not claimed complete.

- Add the actual `clang-release` native driver profile (`-O2`) while preserving default `clang`
  (`-O0`) and TinyCC. Check source-hidden generic/owned programs, relocation and byte-reproducible
  objects/executables, mixed-profile ABIs, runtime aborts, malformed UTF-8 and concurrent artifact
  publication. Retain real-driver scanner build/runtime costs and independent checksums; full
  executable recipe manifests, hermetic toolchain packaging and stage-2/stage-3 remain unfinished.

- Implement public generic record/enum value layouts and real type-only modules, including a
  `core` library with `Result<T,E>`, `Option<T>` and `Pair<T,U>`. Substitute nested type/lifetime
  arguments without rebinding inserted lifetimes; preserve ownership, origins and error propagation.
  Replace the name-only layout walk with concrete instance ordering; erase lifetime values from
  native instance keys, not modes/shapes. Bound producer/consumer codecs (module 4 / function 6),
  reject old artifacts without compatibility branches, and validate source-hidden native composition,
  recursive cleanup, mixed clang/TinyCC ABIs, invalidation, independent Rust results and costs.
  Generic functions, general typed references/containers and self-hosting remain unfinished.

- Retain a generic-lowering comparison across native development/release profiles with real
  source-token/owned-node workloads, instance counts, independent checksums and lifetime controls.
  Select an initial static-specialization implementation while preserving evidence for shared code;
  document eager snapshots, invariance, outer-loan limits and opaque mutable writeback requirements.
  This is preimplementation evidence, not delivered Grail generics or general typed references.

- Remove cumulative scalar/type-map cloning from the checker: share a monotonic function-local
  type ledger, retain scalar definedness in a compact bitmap and prune only dead scalar values.
  Correct match/if live-in definitions without changing loan/owner cleanup. Frozen-compiler
  differential checks retain identical acceptance/C/interfaces; three-run 1,000-site medians improve
  from 406 ms to 4.2 ms (branches) and 1.69 s to 12 ms (`?`), without an ABI/schema change.

- Implement postfix `?` for Result/Option-shaped enum propagation by lowering to independently
  checked match/return operations. Preserve success payloads, transfer matching errors/None and
  clean remaining owners on failure, including earlier call arguments and loop conditions. Test
  hidden-module composition, mixed native backends, complete release traces, side-effect retention
  and Rust controls; no rollback, implicit error conversion, or additional exception runtime.

- Implement tagged enums, exhaustive consuming match, unit values/interfaces and postfix `!`
  unwrap-or-abort for Ok/Err and Some/None shapes. Transfer only the selected payload; recursively
  destroy active owned leaves without reading inactive union data. Validate borrowed token/owned
  error APIs, recoverable u64 parsing, modern Rust controls, allocation/free behavior, variant-layout
  invalidation and clang/TinyCC ABIs in both directions. Use module schema 3 / function schema 5;
  previous artifacts rebuild. Generic payload parameters, richer patterns and `?` remain unfinished.

- Check early returns through branches/blocks/loops, emit path-local recursive cleanup before each
  return, and preserve only continuing ownership states at joins. Equal partial-move states can join;
  unmatched continuing states still diagnose. Validate C/TinyCC objects with hidden-source record
  calls, allocator balance/free order, and primitive LLVM terminators; retain modern Rust controls
  and seed checking-cost measurements. Record destruction does not access captured descriptors.
- Choose postfix `!` for Result/Option unwrap-or-abort and reserve `?` for propagation; syntax is
  documented but awaits the actual enum/Result implementation, not an error-only parser stub.

- Establish the Grail research workspace and living architectural design record.
- Record `.grl` as the agreed source-file extension.
- Add an initial source-backed comparison, provisional semantic core, syntax sketches,
  and falsifiable experiments. No compiler implementation or verified Grail programs yet.

- Add a source-backed memory-model competition; keep persistent external borrowing and access syntax
  open, assess lexical capability contexts, and make zero-copy APIs/diagnostics explicit design gates.

- Record targeted V lessons and caveats for ownership, ergonomics and fast-build architecture.

- Add isolated executable ownership probes, zero-copy representation measurements, and a synthetic
  generic-compilation experiment with raw data and source/toolchain provenance.
- Correct Hylo research to distinguish the former compiler from `hylo-new`, and qualify Goose
  specialization claims using observed root-class reuse. No Grail compiler implemented.

- Add a bounded typed-IR origin/capture inference experiment, imported contract composition, isolated
  client checking and adversarial tests. Contracts are not independently proof-certified.

- Stress-test origin/capture contracts against separate finite dependency and allocation-epoch models.
- Measure generic forwarding, source-set growth and root-indexed client lookup; document unsupported
  ownership/effect features and the trust limit of schema-valid but dishonest contracts.

- Record assessment of the external Opus design review, checked prior-art updates, and unresolved
  public-contract and scoped-exclusivity choices without treating peer recommendations as decisions.

- Add isolated Quint effect/cancellation experiments and distinguish sampled counterexamples from
  verification; record version-matched source provenance and design lessons.

- Record evidence-backed Haskell successes/costs, retention and inference lessons; distinguish
  community pain reports from causal adoption/performance claims.
- Add Swift/OxCaml/Mojo ownership findings and inspected Quint Connect adapter boundaries.

- Assess the external rooted-value proposal without merging it; add six isolated Rust probes for
  cache-reset and callable/thread-sharing distinctions, and identify mutation/cleanup contract gaps.

- Add a bounded pre/post dependency-state experiment for generic append, clear, replacement, old-value
  returns and disjoint-place updates, with independent concrete comparisons and body-hidden clients.
- State the restricted preservation obligation and expose the remaining forged-artifact trust gap;
  no full memory-model, allocation-reuse or runtime-performance claim follows.

- Exhaustively explore finite error-cleanup models with separate user handles and scope-owned work;
  expose premature buffer release and incorrect all-on-one-acknowledgment policies.
- Record status-specific liburing cancellation guarantees and distinguish storage safety, resource
  discipline, cleanup effects and bounded progress. No actual device/runtime verification claimed.

- Add eighteen isolated Rust/Yoke/self_cell probes for Bundle projection, variance, owned ASTs,
  inline-owner stabilization, external dependencies and dependent-before-owner destruction.
- Distinguish scoped covariant field projection from whole invariant-container escape; document
  candidate Bundle rules and explicit allocation choices without adopting a language primitive.

- Distinguish owner lifetimes, carrier loans, authority transfer and temporary reborrows with fifteen
  isolated Rust probes and bounded interval/cell permission comparisons.
- Record minimal construction/permission proof obligations and Aeneas/Hylo precedent; do not infer
  that extra public lifetime syntax, a runtime loan graph or a full checker is required or implemented.

- Test delayed call activation against nested argument effects, early dependency snapshots,
  materialized storage views and copied-view aliasing, with five Rust reference probes.
- Document stable-place premises and unresolved selector/address/bounds-check timing; no frontend
  implementation, general safety proof or bug in the older restricted IR is claimed.

- Add a pinned, isolated Lean preservation core for pure shared-data dependency state, public-bound
  composition and conditional tracked-root validity, with checked counterexamples and axiom reports.
- Consolidate distinct shape/support/authority/activation/cleanup obligations; explicitly exclude
  earlier artifact certification, physical ownership/alias safety and full-language verification.

- Prove symbolic pre-source substitution commutes with the restricted core analysis and preserves
  public bounds under arbitrary overlapping/empty source images; check the one-entry-snapshot boundary.
- Record separate-module proof provenance and standard quotient-soundness dependencies; do not claim
  physical alias safety, structured generic-route correctness or a certified artifact pipeline.

- Add eight checked structured-route targets for suffix-preserving opaque payload forwarding,
  root substitution and dependency-subtree replacement; extend the existing runner to three modules.
- Keep shape-substitution validation, Python implementation correspondence and physical disjointness
  explicit open premises rather than inferring them from dependency-path separation.

- Prove successful dependency-shape projections survive substitution and same-T prefixes have
  compatible descendants; connect that premise to structured forwarding in a restricted model.
- Check counterexamples for newly revealed opaque paths and different-variable incompatibility;
  keep full source typing, parser/unifier correctness and mutable referent state outside the claim.

- Add eleven isolated Rust referent-state probes and complete finite exploration of five single-cell
  policies, including retained-old-value and temporary-source controls.
- Distinguish storage lifetime, current contents and writeback; record two precise ghost-state styles
  and Aeneas precedent without claiming a general mutable-reference checker or runtime graph requirement.

- Add seven pinned Rust generic/resource controls for ownership forwarding, skipped/destructor
  effects and scoped work; retain an expected bounded stall separately from completed executions.
- Record public-source-matched scope accounting and distinguish root captures, logical loans,
  destructor effects and ambient work obligations without adopting safe forget or Rust's runtime ABI.

- Test target coverage beyond lifetime validity with five Rust cases and 2,140 finite transfer/write
  combinations; distinguish conservative weak updates from unsupported strong may-target updates.
- Add six conditional coverage/post-bound Lean targets with explicit logical dependencies; retain
  target-provenance, producer checking and full ownership/erasure composition as separate obligations.

- Prove may/must interval refinement polarity and test 7,380 interval pairs plus a toy stale-cache
  acceptance when coverage guarantees are omitted from dependencies; no production compiler cache claimed.
- Keep body-contract truthfulness, memory-interface invalidation and value/code proof dependencies
  separate; make the transfer smoke check report the actual shared proof-corpus target count.

- Start a dependency-free Rust typed-IR seed with explicit signature regions, affine views,
  carrier reborrows, guarded C/LLVM lowering and body-hidden interface tests. The first scan-based
  checker is a measured baseline, not the final algorithm or a complete language implementation.

- Replace repeated live-value scans with indexed origin/parent-loan checks in the Rust seed;
  preserve owner/authority checks across carrier moves and shared-view ending.
- Add reproducible paired checker, native backend and module-edit measurements with an independent
  checksum oracle, raw CPU/RSS/commands and explicit limits. Retain TinyCC as a measured development
  candidate, without claiming full-language performance, soundness or self-hosting.

- Freeze bootstrap-v0 decisions and add the first `.grl` source-to-native path: borrowed-token
  parsing, explicit signature regions, inferred local loan endings, counted loops, numeric branches,
  guarded byte slices/writes, imported interfaces and clang/TinyCC source builds.
- Add a two-module zero-copy decimal-token parser and source/native safety checks, including
  hidden producer source, wrong-region/local escapes, live-child write conflicts and abort guards.
  Heap containers, general generics, Result and self-hosting remain unimplemented.

- Add owned heap byte vectors, explicit deep copying, geometric growth and owned parameter/return
  transfer in the C backend. Reject growth/movement while borrowed and insert reverse lexical owner
  cleanup separately from last-use loan ending. Bump seed interfaces to schema 2.
- Validate heap cleanup and reverse drop order with independent allocator wrappers, including loops,
  clones and returned owners. LLVM comparison explicitly rejects unsupported heap layouts.

- Audit stable and pinned modern Rust (2026-10-29 nightly) with Polonius/next-solver flag isolation:
  conditional reborrows and get-or-insert now pass; stored-referent replacement/restoration still
  reject in the tested forms. Correct the comparison baseline without claiming a soundness proof.

- Add owned UTF-8 strings, validated literals/escapes, checked text copying and append, while
  rejecting raw byte mutation and growth under live views. Bump seed interfaces to schema 3.
- Differentially validate text construction on 26 byte sequences through clang/TinyCC, including
  malformed encodings, and exercise owned string calls/returns across a hidden-source boundary.

- Allow readonly byte-view descriptors to be read, moved or ended while derived readonly views
  live, without releasing their data owners or exclusive ancestors. Add paired positive/negative
  source checks for lexer-style retained slices.

- Add while loops to source, checked IR and C/LLVM lowering. Re-evaluate conditions, close their
  temporary owner/loan scope on both outgoing edges, and preserve loop-carried resource obligations.
- Validate zero-iteration execution, mutable counters, condition allocations and retained-view
  growth rejection with native and allocator-audited cases.

- Add lexical shadowing and standalone source blocks with reverse lexical cleanup. Keep old storage
  identities and outer-owner lifetimes distinct from names, restore names on scope exit, preserve
  explicit unconditional moves/drops, and reject duplicate parameters and use after scope/consumption.
  Validate C/LLVM behavior, live-loan rejection and allocator-audited shadowed-owner cleanup.

- Fix source call evaluation to copy/move each user-function argument left-to-right before evaluating
  the next. Reject later use of an already moved owner/view, retain builtin borrowing rules, and
  preserve explicit precomputed values/reborrows. No interface-schema or runtime-borrow-check change.

- Review pinned Blu/Lust frontend and ownership implementations; retain 15 modern-Rust/Lust
  acceptance pairs and seven equal native executions for aggregate/region gates. Record the useful
  field/variance/drop-liveness distinctions, remaining Grail work and Lust's older NLL restrictions
  without treating external subset/performance claims as Grail guarantees.

- Add private source-module helpers, forward calls and self/mutual recursion. Collect signatures
  before independent body checks, keep only used callee headers per body, and emit private native
  linkage in C/LLVM. Validate hidden-source clients, repeated helper names across modules, invalid
  unused helpers and allocator-audited owner transfer. The first function is still the sole export.

- Add explicit module identities, multiple `pub fn` exports, qualified calls and flat checked modules.
  Replace the source artifact protocol with canonical module schema 1 (signature-3 payloads); retire
  nested helper-module storage and rebuild old source artifacts. Validate transitive dependency
  surface hashes before linking, reject cycles/stale callers, and keep body-only rebuilds compatible.
  Verify C/LLVM/TinyCC execution and borrowed export contracts. Artifact-byte authentication,
  concurrent publication safety, public type definitions and full bootstrap remain unfinished.

- Publish immutable, manifest-verified native module generations behind atomic pointers; link captured
  generation objects instead of replaceable convenience files and atomically install successful binaries.
  Preserve prior outputs on native failure, retain metadata-only checking, and require old flat native
  providers to rebuild. Test concurrent publication, byte corruption and retained-version linking.
- Fix TinyCC reproducibility by compiling stable relative source names inside isolated work directories;
  repeated and relocated object generations/executables now match without ELF postprocessing.

- Add field-sensitive by-value nominal records with owned and captured-reference fields, nested
  partial moves, explicit byte-field borrows and recursive remaining-field cleanup. Share validated
  layouts; count empty nodes in expansion bounds; expire captures independently of default drop.
  Export reachable layout definitions in module schema 2/signature payload 4 and invalidate stale
  layout-only clients. General typed references, generic containers, enums/Result/joins remain open.
- Distinguish lifetime may-roots from valid-reference authority during reborrow. Validate disjoint
  returned mutable fields sharing a lifetime, duplicate-borrow rejection, and storage/capture returns.
- Omit the pinned TinyCC's invalid asynchronous frame tables for Grail's abort-only profile; retain
  relocation evidence and verify both mixed-backend large-record ABI directions and allocator balance.
