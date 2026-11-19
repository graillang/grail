# Next window

The swarm is paused on its weekly quota. This file is the handoff: per lane, where it stopped, what
is already on main, and the one thing to do first. Each lane also has its own resume note in its
worktree (named below), which is the authoritative detail; this page is the index so a fresh session
does not have to rediscover the queue.

Read `docs/PORT_STATUS.md` for the coverage numbers and the named boundaries.

| Lane | Area | Resume note |
|---|---|---|
| `abn_gp_prod` | production: economy domains | `grail-w-abn-gp-prod/NEXT_STEPS.md` |
| `abn_gp_combat` | combat: character + actions | `grail-w-abn-gp-combat/NEXT_STEPS.md` |
| `abn_gp_world` | world/UI presentation | `grail-w-abn-gp-world/NEXT_STEPS.abn-gp-world.md` |
| `abn_gp_runtime` | network + formats | — |
| `abn_ecs` | ECS, collision, movement | `grail-w-abn-ecs/NEXT_STEPS.md` |
| `abn_mesh` | save tables | `grail-w-abn-mesh/NEXT_STEPS.md` |
| `abn_app` | scarab app + save | `grail-w-abn-app/NEXT_STEPS.md` |
| `abn_wg_terrain` | worldgen terrain | `grail-w-abn-wg-terrain/NEXT_STEPS.abn-wg-terrain.md` |
| `abn_wg_hydro` | worldgen coasts/hills/oil/volcanic | `grail-w-abn-wg-hydro/NEXT_STEPS.md` |
| `abn_wg_feat` | procgen + kit geometry | `grail-w-abn-wg-feat/NEXT_STEPS.md` |
| `abn_render_policy` | renderer policies | `grail-w-abn-render-policy/NEXT_STEPS.abn-render-policy.md` |
| `abn_rhi` | RHI + graph execution | `grail-w-abn-rhi/NEXT_STEPS.md` |
| `abn_rgraph` | render graph plan | `grail-w-abn-rgraph/NEXT_STEPS.md` |
| `abn_shaders` | shader inventory | — |
| `abn_abtex` | textures + image IO | `grail-w-abn-abtex/NEXT_STEPS.md` |
| `abn_hashes` | hashing + block codecs | `grail-w-abn-hashes/NEXT_STEPS-abn-hashes.md` |
| `abn_lang2` | compiler gaps | `grail-w-abn-lang2/NEXT_STEPS.md` |
| `abn_f32lib` | glibc-exact maths | `grail-w-abn-langfix/NEXT_STEPS.md` |
| `abn_tools` | content tools | `grail-w-abn-tools/NEXT_STEPS.md` |
| `abn_platform` | platform layer | `grail-w-abn-platform/NEXT_STEPS.md` |
| `abn_monuments` | monuments | `grail-w-abn-monuments/NEXT_STEPS.md` |
| `abn_exchange` | compiler ownership | `grail-w-exchange/NEXT_STEPS.md` |

## First item per lane

Taken from each lane's own resume note at hand-off. Where a lane has no note, the last reported
scope list in its final message is the source.

- **production** — `item_content`'s validation report, then `topological_resources`/`reachable_resources`,
  then `content_hash` and the `append_*` builders; then trade, agriculture, construction
  placement/terrain/wear, manufacturing replay/repair/warehouse, crafting actions, logistics freight.
- **combat** — character 2c (weapon view + held equipment), then 2d (firearm carry maths), then
  actions/combat on the tx layer, skills, survival, explosives, anticheat, security.
- **world** — `input::BindingModel` (1522/1540 lines, 18 signed-zero diffs, parked in
  `.work/scratch/wip`), then `GameShellSettings` in two or three landings, then `settings_screen`;
  `map_markers` is blocked on `host_economy`.
- **runtime** — the chunk codec's canonical-shape section, then server layers, `world_voxel_save`,
  the rest of `protocol.cpp`, then `multiplayer_acceptance`.
- **ecs** — `step_mover`'s movement step (slide/probe_ground, walking/falling); collision queries,
  exact sin/cos and the `MoverState` wire are already in place.
- **mesh** — `drones.fleet`, the last of 65 save tables; its format is written out field by field in
  the lane's note (`DroneFleetRegistry::encode`: magic, catalog hashes, per-drone configuration blobs).
- **app** — the `ABTW` section now that 64 of 65 tables are exact, then `step_mover` in the digest.
- **terrain** — the surface passes (`warp_relief`, `plateau_character`, `relax_talus`,
  `smooth_erosion_delta`, parked at `.work/coherent_surface.grl.wip`), then `erode_stream_power`,
  then regional relief/crags/dissection, then geology and material masks.
- **hydro** — the stepped-hills planner, then `apply_stepped_hills` + marks, then oil, then volcanic.
- **feat** — the `Builder` port from `.work/abn-scratch/builder-wip.patch` (959 lines; three borrow
  fixes left), then `kit_fences`, the tree builder, `horse_tack`/`floor_props`.
- **render_policy** — page book part (b) (hash table, records, `take_upload`), then `node_set`.
- **rhi** — multi-segment submission (`submit_with_waits`), the last item on its list.
- **shaders** — nothing queued; the CMake mirror step landed (211 entries, 25.7 MB of SPIR-V).
- **abtex** — BC7 albedo/ORM in QA now that `lib/bc7_decode.grl` exists, then EXR scanline-zip.
- **hashes** — `manufacturing_content_catalog`, which needs `item_content`'s extraction/geology/nuclear
  pieces first.
- **lang2** — gap 4 ergonomics; the exchange-through-record-field segfault is fixed and gated.
- **f32lib** — signed constant folding (three parts: the literal-led expression parse, negation of a
  parenthesised/named integer, and the folder's signed channel).
- **tools** — content gc/heal on the landed fs primitives, then the `execve` report.
- **platform** — nothing queued; the overlay hook landed and the occlusion query needs stage-6
  collision.
- **monuments** — nothing queued; M1 and M2 are on main.
- **exchange** — the second ownership probe batch (map value, `Some` payload, through `&mut`, `Drop`
  source, loop, match), then any related hole it finds.

