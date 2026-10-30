# Field-sensitive by-value records checkpoint

`checks.json` retains full stable/nightly native-inclusive tests, format/Clippy/release, explicit
TinyCC native records/artifacts/modules, independent Rust control compilation/execution, and three
Grail programs with equal 16 / 11 / 5 outputs under clang/TinyCC. Compile-only negatives are never
run. Rust workspace and focused Python LSP reports are retained; the runner also passes CLI Ruff
and Pyright. The complete bootstrap goal remains active.

## Composition gates actually executed

- Owned UTF-8 names plus borrowed spans, whole-record calls/returns and nested field moves.
- Both directions of the clang/TinyCC large-record parameter/return ABI with provider source hidden.
- Independent malloc/realloc/free wrapping, live-count assertions, ten record allocations/cleanups
  in a loop, no double frees/leaks and final reverse-binding frees 2 then 1. The audit links the
  selected-backend object, not a substitute clang recompile of its C.
- Carrier destruction while a copied readonly span remains usable; owned fields move independently.
- A pair of disjoint mutable views returned under one lifetime label. Origin may-sets overlap but
  the valid capabilities remain separate. Duplicate unique borrows of one owner still reject.
- Native stale-client rejection after a field-order-only type-layout change, without a function
  signature word change; the previous executable/pointer remains intact.
- Owned parameter storage cannot be returned under a sibling capture's lifetime. Local-source escape,
  field use after move, move of incomplete aggregate and owner release while referenced reject.

These do not test unsupported general `&T`/`&mut T` stores, generic vectors/maps, enum variants,
conditional partial initialization, user destructors or self-hosting. See `docs/design/record-core.md`.
Record liveness is still register-granular and join/back-edge resource changes remain restricted.

## Backend counterexample / correction

`tcc-unwind-before.txt`: GNU ld rejected a TinyCC-produced provider. Multiple `.rela.eh_frame`
function-start relocations all had zero addends despite distinct function offsets. A direct ABI
probe without those tables returned the expected field lengths/offset. The abort-only TinyCC
profile now uses `-fno-asynchronous-unwind-tables`, not disabled ABI checking or ELF postprocessing.
Both mixed-backend directions and selected-object allocator audits then pass. This profile promises
neither exception unwinding nor correct unwind-table-based native backtraces.

## Narrow cost control

`cost_harness.rs` checks 250 / 1,000 / 4,000 public record layouts and consuming accessors, five
repetitions per size, release-built seed. `costs.txt`: definitions/functions, interface bytes, median
source-check seconds, median encode/decode/fingerprint seconds. Context validation is shared, not
repeated wholesale per function. Layout expansion counts empty nodes as well as primitive leaves;
the empty-record fanout rejection is an actual type-declaration test. Codec producer bounds match
consumer bounds before artifact publication; standalone nominal signature payloads permit 64 KiB.
This is synthetic frontend/interface evidence, not a real compiler or native runtime benchmark.

```sh
cargo build --manifest-path seed/Cargo.toml --offline --release
rustc --edition=2024 -O research/evidence/records30-20261030/cost_harness.rs \
  --extern grail_seed=seed/target/release/libgrail_seed.rlib \
  -L dependency=seed/target/release/deps -o /tmp/grail-record-cost
/tmp/grail-record-cost
```

`python research/experiments/records30/check.py` reproduces the full gate with the project-local
pinned nightly and TinyCC prerequisites documented in that experiment. Module schema 2 / function
payload 4 replace older artifacts. Signature words are not sufficient without their nominal layout
context. No global proof, generic-reference soundness claim or stage-2/stage-3 result is implied.
