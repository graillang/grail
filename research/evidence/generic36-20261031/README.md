# Generic value-layout implementation

`checks.json` is the successful final run: 88 commands with source hashes, tool versions, stdout,
stderr, environments and statuses. Every recorded source hash was checked again before landing.
Stable and pinned nightly each pass **59 checker/source/hash + 12 native tests** (71 total).
Explicit native runs additionally cross clang/TinyCC providers/callers in both directions for the
new layouts and existing records, returns, sums and propagation. Positive Rust controls execute;
no invalid/undefined Rust program is run. No model/provider/host toolchain defaults change.

## Concrete semantics

`seed/std/core.grl` exports `Result<T,E>`, `Option<T>` and `Pair<T,U>` from a type-only module with
no executable entry. Tests remove source providers before consumers compile. Generic nested
string/span/token results, exhaustive extraction and `?` preserve roots and default recursive cleanup.
A type-only variant-order edit invalidates transitive clients without overwriting prior artifacts or
executables. Other tests check actual type arguments, mode/origin rejects, mixed lifetime scopes,
finite phantom arguments versus growing physical recursion, maximum empty chains and canonical
producer/consumer byte/depth/arity bounds.

Independent Rust uses its real generic Result/Option/Pair and source slices. Numeric/error controls
match the source-hidden Grail parser; release traces for partial moves and propagation both equal
`[3,4,2,1]`. Instrumented selected-backend native objects and optimized ASan/UBSan C agree.

## Costs (three-run medians, frozen compiler `889bb45`)

`costs.tsv` covers 8/32/128/256 concrete instances of source-span/owned-name/numeric tokens.
The frozen and current compilers check the same explicitly expanded programs; the current compiler
also checks an actual generic Result template. Repeated C/API output is deterministic. The expanded
before/after C is identical **apart from independent typedef ordering**, checked by extracting and
comparing every declaration and the remaining text—not by accepting arbitrary differences.

At 256 instances:

| program/compiler | check | C emission | API encode + fingerprint | C bytes | API bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| frozen expanded | 4.96 ms | 1.75 ms | 1.82 ms | 201558 | 41227 |
| current expanded | 6.05 ms | 2.71 ms | 2.04 ms | 201558 | 42251 |
| current generic | 5.75 ms | 4.58 ms | 1.48 ms | 259708 | 33805 |

These are small absolute costs, **not zero-overhead claims**: recursive argument checks and
canonical hashed names add compiler/emission work; longer C aliases inflate text, while templates
reduce source and interface duplication. C type-name hashing/caching and large live-owner graphs
remain further measurement targets, not proven complexity bounds.

`native-costs.json` retains three deterministic object builds per input/profile at 8 and 256 instances.
At 256, clang development compilation is 187–189 ms and optimizing compilation 305–308 ms across
all three programs. Clang objects are **byte-identical** across them (173176 / 67552 bytes respectively).
TinyCC takes 4.45–5.08 ms, all objects 204048 bytes; its hashes are deterministic for a given input
but differ across styles/paths, so equal size is not claimed as machine-code equivalence. Mixed ABI
execution is independent evidence. Optimizing C probes are not a delivered release-driver profile.

## Retained failed controls / limits

- `allocator-control.json`: without preservation flags clang `-O2` elides unobserved allocations,
  yielding `live=0 count=0`; the exact trace auditor then aborts. Disabling allocator builtins for the
  **instrumented probe only** yields four frees, previous 2, last 1, and passes. No unsafe failing
  program or Grail cleanup defect is inferred from allocator elision.
- `recorder-before.txt`: all substantive checks finished but an incorrect new recorder header path
  prevented writing results. Corrected to the actual `seed/src/bytes_runtime.h`, rerun completely.
- `layout-order-before.json`: the native-cost extension first demanded raw before/after C equality.
  The only difference was independent typedef ordering; the final gate checks that exact distinction.
- Rust/Python LSP results are retained and clean. Diagnostics and tests are evidence, not soundness
  proofs, authenticated interfaces, a generic mutable-container solution or self-compilation.

General typed-reference invariance/writeback, generic functions, arbitrary-element heap collections,
native release-profile tooling and the real Grail compiler/stage-2/stage-3 port remain required work.
