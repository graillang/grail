# Port status

Generated from the repository: every number below is read off the tree, not estimated.

**177** port modules, **51** library modules, **131** gated test programs,
**105,529** parity lines — each line a value the port prints and the reference prints, compared
byte for byte.

The reference is pinned at `28a31e5089` (`~/abundance-pin`, rebuilt by `abundance/tools/build-pin.sh`);
the Abundance checkout itself is at `91afdbd809` and moves as its owner works, so the pin is what
`docs` and every gate mean by "the reference".

| Area | gated programs | parity lines |
|---|---:|---:|
| Gameplay core (`ab::` tx domains) | 39 | 50,057 |
| Worldgen | 23 | 15,141 |
| Engine (scarab RHI, graph, platform, app) | 32 | 33,417 |
| Asset formats & content tools | 15 | 2,658 |
| Libraries (FOSS port) | 12 | 1,396 |
| Other gated increments | 10 | 2,662 |
| **Total** | **131** | **105,529** |

## What "gated" means

Each test compiles the port together with a reference built from the pinned C++ and compares stdout
byte for byte (`tools/abundance-test.mjs`, `--only=NAME`). A module without a gated test is not
counted above, however complete it looks. The area grouping is by module name, hand-mapped, so it is
for orientation: the totals are exact, the per-area split is approximate.

## Named boundaries

These are real gaps, recorded where they live rather than papered over:

- **GPU-side renderer areas** (lighting, water, geometry, materials, characters, vfx, ui): the CPU
  policies are ported and gated; the draw side is not.
- **Editor**: deliberately last.
- **BC7/BC6H encode**: reached through an ISPC shim behind a C ABI, not ported.
- **glibc-exact `atan2`**: `pow`, `sin` and `cos` are exact; `atan2` is still 1 ulp off.
- **`drones.fleet`**: the last of the 65 checkpoint save tables; a catalog-driven codec with its own
  magic header, not a record table.
- **terrain_server demand order**: not observable from the public API without an engine test hook.
- **EXR/JPEG/TIFF import**: PNG loads; the others still need the C++ importer.
- **Unreal-host code**: out of scope by the port's direction; it stays unported.

