# Private module helpers and recursion

`tests.txt`: complete source/checker and explicitly enabled native suite. The new native test runs
self/mutual recursion through C and LLVM, removes provider source before compiling its client,
links two modules with repeated private helper names, executes a heap-using helper behind a numeric
interface and verifies that an invalid unused helper cannot replace an existing valid interface.
The independent malloc wrapper also checks ownership transfer and local string cleanup inside a
private helper. Source cases reject laundering a local reference through a recursive signature.
`checks.json` retains current hashes, format/Clippy and TinyCC execution (146).

`cost_harness.rs` checks generated chains of 250 / 1,000 / 4,000 helpers through the public source API,
five repetitions per size. `costs.txt` records helpers, source bytes, median checking seconds. This
is release-built in-process frontend checking, not native build/runtime or a real-compiler benchmark.
Reproduce from the Grail root after a release seed build:

```sh
rustc --edition=2024 -O research/evidence/functions27-20261030/cost_harness.rs \
  --extern grail_seed=seed/target/release/libgrail_seed.rlib \
  -L dependency=seed/target/release/deps -o /tmp/grail-function-cost
/tmp/grail-function-cost
```

Only used callee signatures are stored per checked body; no per-body copy of the whole module's
header map. Every body is validated, including unused helpers. The first function remains the only
public export; `.api` schema 3 is unchanged. Multiple public exports, public type definitions,
records/enums/generics, early-return cleanup and complete bootstrap/self-hosting remain unfinished.
No whole-language soundness or realistic large-module performance claim follows from these tests.
