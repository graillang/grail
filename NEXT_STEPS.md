# abn_wg_hydro — resume point

Last landed / queued when this was written: `fabc0339` (stepped-hills planner, gated 6/6) — queued
behind the land queue; `b20568a7` (coasts port) and `313787f7` (coasts ria/spit fixture, 58/58) are
the previous two. If the queue shows anything earlier than `fabc0339` on main, re-queue the branch.

## Done (on main or queued)

| Increment | Gate |
|---|---|
| Palette classifier + ecology (`src/terrain_palette.grl`) | generated world, cell-for-cell |
| Mountains (`src/mountain_shape.grl`) | 14/14 digest lines |
| Crags (`src/coherent_crags.grl`) | 60/60 lines, five configurations |
| Mesa planner / builder / hooks (`src/coherent_mesa.grl`) | 48/48 lines, four planner configurations + builder + marks + biomes |
| Feature composition (`src/feature_composition.grl`) | 10/10 lines |
| Coasts (`src/coherent_coasts.grl`) | 38/38 lines + ria/spit fixture 58/58 |
| Stepped-hills planner (`src/coherent_stepped_hills.grl`) | 6/6 lines |

## Next, in order

1. **Stepped hills, second increment** — `apply_stepped_hills` and `compose_stepped_hill_marks` from
   `Private/coherent_stepped_hills.cpp:403-940`: the strata column (`build_column`,
   `build_mesa_column`, `proportion_unit`, `remap`), `apply_site` (risers, benches, talus, the
   water/rigid fades, the closing flood), the trap-riser mask and the mark weights. Reference:
   extend `tests/parity/coherent_stepped_hills.cpp` with an apply pass over the forced sites.
2. **Oil** (`Private/coherent_oil.cpp`, 1532 lines) — plan, salt-dome relief/sinks, `finish_oil_system`.
3. **Volcanic** (`Private/coherent_volcanic.cpp`, 2665 lines) — split into two landings if it is
   naturally two passes.

## Known gaps

- **Coasts fjord profile**: unexercised. Needs a stem confined for more than 1200 m; the valley
  fixture's drowned reach is shorter. Extend `coherent_coasts_valley.bin`'s valley north or raise
  `head_rise_max` tolerance by widening the floor only above the 1200 m mark.
- **Stepped-hills natural sites**: the 12 km fixture selects none, in the engine and the port alike,
  so the trap/dry/plateau scoring runs but ends below `natural_min_score`. A world with a bigger,
  flatter basalt plateau would select one.
- **Mesa multi-region**: covered — `mesa.multi` keeps four regions with separation and rank rejects.

## Discipline

`--only` while iterating; at most one full suite before a landing; scratch in `.work`; rebase on
`origin/main` before each landing; explicit `git add` paths; CHANGELOG in the same commit; report each
SHA to `/root`. Do not edit `worldgen_macro_coast/macro_world/mountains/landform/provinces/noise/
coherent_field/fastnoiselite.grl` — those belong to `abn_wg_terrain`.
