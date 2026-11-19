# Lane abn-gp-combat: resume point

State at the 2026-11-19 budget wind-down (OpenCode weekly window ~11%, resets 2026-11-23).

## On main from this lane
- combat_core (1548 values), damage rules (323), combat world queries (374), faraday_cage (49),
  placed_damage (135), character rules group 1 (140), character group 2a look/fall/survival/tool (321),
  character group 2b traversal (407).

## Unfinished, in order
1. **Character group 2c: weapon view + held equipment.** The port of
   `character/{weapon_view_rules,held_equipment_rules}.hpp` plus the firearm-profile presentation half
   (ids/mounts/body keys) is written but NOT green. Its diff is saved as
   `.work/scratch/character-2c.patch` (untracked; apply with `git apply`). Remaining failure: the
   parity test aborts at one type mismatch around `abundance/tests/character_rules_test.grl:921`
   (the `held.remote_cart` case); everything before it compiles. Reference output already regenerated
   (636 lines) - re-check with `bun tools/abundance-test.mjs --only=character_rules` after applying
   the patch.
2. **Character group 2d:** `firearm_profile.hpp`'s carry maths (`aim_solution`, `hip_pose`,
   `optic_line_height_cm`, `is_profiled_firearm`, `fires_over_session`, `is_automatic`), and
   `held_item_hold.hpp` if that header is also in `cmake/tx/character.cmake`.
3. **actions/combat on the tx layer** (`combat_strike`, `combat_defence`, `combat_weapon_state`,
   `combat_weapon`, `combat_emp*`, `combat_factory_defence`, `factory_defence_frontier`,
   `item_content/emp_warheads`). Reference path: `ABUNDANCE_ROOT=$HOME/abundance-pin/src
   ABUNDANCE_BUILD=$HOME/abundance-pin/build`, a test action driving the engine's own functions
   through `Engine::submit` (pattern: `abundance/tests/parity/placed_damage.cpp`).
4. skills, survival, explosives, anticheat, security (same pattern).

## Not mine / boundaries
- `lib/math.grl`'s double `pow` is still not glibc-exact; `damage.grl` keeps its local corrected
  double-double `pow` until abn_langfix lands one (director's plan).
- `combat_trace.grl`'s chunk-query + capsule sweep now live in `collision_query.grl` (abn_ecs). Rebase
  before touching either.
- The pinned build at `~/abundance-pin` is the only trustworthy reference for tx-layer symbols; the
  in-tree `build/libabundance_gameplay_core.a` is stale (predates the collision tie-break).
