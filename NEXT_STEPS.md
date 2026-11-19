# Lane abn-gp-combat: resume point

State at the 2026-11-19 budget wind-down (OpenCode weekly window ~11%, resets 2026-11-23).

## On main from this lane
- combat_core (1548 values), damage rules (323), combat world queries (374), faraday_cage (49),
  placed_damage (135), character rules group 1 (140), character group 2a look/fall/survival/tool (321),
  character group 2b traversal (407).

## Unfinished, in order
1. **Character group 2c: weapon view + held equipment.** It was written but not green and was
   reverted for the wind-down (the scratch copy was removed when the harness cleared `.work`; rewrite
   it from `character/{weapon_view_rules,held_equipment_rules}.hpp` and the presentation half of
   `firearm_profile.hpp`). State before reverting: the module compiled and the 636-line reference
   generated; the test failed at one type mismatch near the `held.remote_cart` case
   (`HeldFacts`/`select_held_presentation` call sites), then would have needed the usual parity
   pass. Ids already checked against the headers: weapons 90010 / 1802 / 1803 / 1502 / 82701 /
   87001 / 87009 / 87003 / 87005 / 87006 / 86006; attachment modules are the ASCII constants
   (MODSUPPR etc.); tools surveyor 2319, tapping knife 24402, crowbar 87500, paint rollers
   24960-24967, spray cans 24970-24977, wrench set 84126; munitions 86004/86005/86017/86018/86800.
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
