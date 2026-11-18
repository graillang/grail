# Next steps: Abundance checkpoint section payload codecs (lane abn_mesh, parked 2026-11-18)

Parked work-in-progress on branch `abn-mesh-payloads-wip` (pushed, NOT landed: nothing here has been
checked against a trustworthy reference yet, and `abundance/src/*.grl` is compiled into every port
test program, so it must not reach main untested).

## Blocker: the prebuilt gameplay-core archive does not match the pinned sources

- `/home/shulgin/abundance/build/libabundance_gameplay_core.a` was built 2026-11-11 01:47 UTC. The
  suite's pin (abundance/README.md) is `83d90ed95e` (2026-11-18 06:06 UTC). The checkout has since
  moved on: its HEAD was `a7eebe8e72` (2026-11-18 18:20 UTC) when this was found, so neither the
  working tree nor the archive is the pin.
- Evidence (reference compiled against the pinned `tx/` headers, linked against that archive): the
  archive's `World::encode_engine` writes an extra empty u32-count field between the entity rows and
  the schedule (bytes 180..184 of the 380-byte payload are `00000000`, followed by the three schedule
  rows), and the header-inlined `ScheduleTable::all().size()` reads 0 effects while the payload holds
  3 - a struct layout skew between headers and archive (an ODR mismatch, so inline header code can
  silently read wrong offsets).
- Consequence: every reference that links the archive (tx, tx_engine, construction_build_job,
  power_generation, power_grid, world_model, ...) is checked against Nov-11 behaviour, not the pin.
- Fix (director owns it centrally): build `abundance_gameplay_core` and its link set
  (`abundance_worldgen abundance_procgen abundance_terrain_runtime ab_render_policy ab_clipper2
  ab_sky_policy`) out of tree from `git archive 83d90ed95e` (the pinned tree configures cleanly with
  `cmake -DCMAKE_BUILD_TYPE=Release -DAB_USE_CCACHE=OFF`), and point every reference's library
  directory at it.

## What is here

- `abundance/tests/parity/tx_sections.cpp` - the reference, complete but not yet run against a
  matching archive. It builds the state through real commits (the engine test's `test.arm` /
  `test.arm_dud` actions via `ab::tx::Engine`, two due effects run, then commits at ticks 5000/5001
  so the ledger prunes into its watermark), dumps the 'ABTX' engine state field by field, writes
  `engine.abtx`, 'ABTW' from `adopt_registered()`, both host sections via `store_host_sections`, the
  ABCP2 checkpoint via `encode_checkpoint`, and ~20 engine-payload and ~10 table-envelope mutations
  with `decode_engine` / `decode_tables` verdicts (refusal text verbatim) and seven
  `load_host_sections` cases. It links the archive `--whole-archive` so all 60 table registrars are
  present, plus `world_season.cpp`, `-lab_sky_policy`, and `tx_sections_blu_stub.cpp` (the Blu mode C
  entry points the archive references; never invoked).
- `abundance/src/tx_sections.grl` - the port: 'ABTX' decode/encode (field codec, paged-row ordering
  with std::pair<double,id> semantics so a NaN due orders by id, unique effect ids,
  next_id >= 2^62, exact consumption, opaque byte vectors uncapped), the 'ABTW' envelope with
  `decode_tables`' registry-level refusals ("malformed table envelope", "unsorted (table N )",
  "unknown to this build (table N )" - note the empty-name trailing space), `host_table_payload`,
  and the host-section store/load rules. Not compiled yet.

## To finish increment A (once the pinned archive exists)

1. Link the reference against the pinned archive; run it into `abundance/tests/parity/tx_sections/`
   and commit its output as `tx_sections.txt`.
2. Write `abundance/tests/tx_sections_test.grl`: decode each fixture with the port and print the same
   lines (registered table ids are `fnv1a64(name)`; carry the build's 60 table names as the port's
   registry and verify the ids against the reference's `table` lines).
3. Add a `tx_sections` entry to `references` in `tools/abundance-test.mjs` (whole-archive link, the
   extra sources above), CHANGELOG, land.

## After that: the domain table codecs

'ABTW' carries one blob per registered table: 60 in this build (empty sizes 1..93 bytes; largest:
power.power_dispatch, mode.match_setup, trade CrossWorldTable, agriculture.watershed_dispatch,
agriculture.wildlife_habitats). Port them in batches, each gated by non-empty states built through
the domain's own actions, so `decode_tables` can also reproduce "payload does not load (table N
name)". Then ping /root/abn_app: the stage-6 exit gate needs these on main.

## Also noticed

`abundance/src/entity_table.grl` caps an entity's opaque data at codec_max_string (65536). At the pin
the field codec puts no cap on `std::vector<std::uint8_t>` (only "length <= remaining";
tests/tx_engine_tests.cpp `opaque_byte_blobs_do_not_use_the_object_count_limit`), so that decoder
refuses payloads the engine accepts. Fix when the entity test is regenerated against the pinned
archive.
