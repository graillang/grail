# Checked generic function gate — 2026-10-31

Reproduce `python research/experiments/templates39/check.py`. `checks.json` retains commands, full
stdout/stderr, tool versions, source hashes, raw build/runtime samples and cost medians. This is an
implemented **by-value** function milestone, not completion of bootstrap v0 or typed references.

## Executed checks

- **95 tests** pass on stable Rust 1.98 and pinned nightly 1.101 (including 18 native tests).
  Formatting and all-target Clippy with denied warnings pass. Generic native tests also run against
  clang development, actual clang `-O2` release, TinyCC and both mixed-profile directions.
- Public bodies universally check opaque affine parameters. Invalid numeric assumptions, duplicate
  moves, unbound/conflicting arguments, local-view escapes, live-parent mutations and aliased mutable
  inputs reject. Explicit/inferred calls, caller binder substitution, lifetime-only code sharing,
  distinct modes/private-layout keys, ordinary recursion and bounded polymorphic growth are tested.
- Source-hidden `low → api → client → app` retains private helper implementation closure integrity.
  Changing a private helper preserves its public fingerprint but invalidates consumers. Rebuilding
  intermediate api changes its closure hash via the transitive body pin, still invalidating old
  client. Rebuilding the client restores the new result. Malformed immutable IR fails; corrupt
  convenience files are ignored; failed builds preserve prior executable/artifacts.
- Provider checking/publication works with imported body bytes temporarily absent: it uses
  contracts, not caller-root or imported-body borrowing analysis. Native consumers subsequently
  load canonical, content-bound, universally rechecked IR.
- Real core helpers transfer strings and borrowed-span/owned-name tokens through nested sums,
  preserve mutable authority and release captures before owner growth. Eager generic argument
  snapshots return **7**, not the later write's **99**. Numeric recursion runs in native C and LLVM.
- Exact recursive cleanup (including owned-string generic recursion, expression-statement temporary
  destruction and `?`) agrees with independently executed stable/nightly Rust wrappers:
  success **11 / `[3,5,6,7,4,2,1]`**, failure **3 / `[3,2,4,1]`**. Native allocator wrapping balances;
  optimized ASan/UBSan probes preserve allocation builtins for observation only. Production flags
  are unchanged. Rust wrappers check logical destructor order, not allocator implementation identity.

## Frozen replay and specialization costs

A separately rebuilt `a1351ad` executes the same 1200 raw / 400 source **compile/lower-only** corpus.
Acceptance is unchanged (**271 raw + 108 source accepts**), all **379 C outputs** are byte-identical,
and **108 API payloads** match after removing only the changed empty module schema envelope.
Invalid/nonterminating generated IR is never run. The public emitter's now-fallible return type
is adapted only in the replay program, not through a compiler compatibility route.

Three-run medians at 256 sites:

| source style | checking | native specialization/C | IR decode/recheck | native generic instances | C bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| expanded concrete helpers | 5.46 ms | 2.31 ms | — | 0 | 161467 |
| generic, distinct types | 3.61 ms | 3.50 ms | 0.227 ms | 256 | 214021 |
| generic, repeated same type | 3.42 ms | 1.96 ms | 0.224 ms | 1 | 126616 |

All 0/16/64-site samples and metadata sizes are retained. Hashed symbols increase C text size;
specialization is not free. Payload closure currently includes all private helpers/layout context,
including unused declarations, so invalidation/IR costs are deliberately coarse. Memoization is
per compilation only; this is not a persistent generic cache or a scalability theorem.

## Token workload / real native profiles

Separately compiled source-hidden core + lexer + scanner compose borrowed spans, owned spellings,
Result/Option/identity, `?`, nested loops/exits and deterministic per-token cleanup. The host shim
supplies **950272 bytes / 131072 tokens**. Rust and all profiles agree on
**11380358366811062272**. CLI-built programs also accept valid input and abort on malformed tokens.

| profile | sum of 3 module compile medians | fixed clang-shim link median | run median | lexer + scanner objects |
| --- | ---: | ---: | ---: | ---: |
| clang `-O0` | 84.04 ms | 46.87 ms | 23.99 ms | 11520 bytes |
| clang-release `-O2` | 101.25 ms | 45.91 ms | 2.82 ms | 3768 bytes |
| TinyCC | 13.07 ms | 46.25 ms | 33.35 ms | 14016 bytes |

Three module compilation samples include first publication and repeated existing-generation checks;
there is no persistent checking cache. Link/run measurements include process/host-shim overhead.
Identical artifact IDs across three compiles and identical shim executable bytes across three links
are required. CLI build recompiles the same scanner object and must retain its artifact ID too.
The TinyCC shim is deliberately linked by the fixed clang host control; the separately tested CLI
executable uses the selected native driver profile. This is not a whole compiler benchmark.

## Diagnostics, TCB and unfinished gates

Rust workspace source/tests have zero diagnostics; seven severity-4 notes belong to old unlinked
scratch files, not current project errors. Focused Python LSP plus CLI Pyright/Ruff are clean.
The old running harness's Python workspace pull times out: its capability-aware fallback was already
fixed/pushed in Borg Agent **d4566bd5**, confirmed in `~/agent`; the active host was not restarted.
`diagnostics.json` retains the partial report rather than reporting it as a clean workspace pass.

IR/schema/hash checks bind structure/bytes, not honesty of native producers or hostile filesystems.
The compiler, codec/materializer, C compiler/linker/runtime and host remain trusted. No full
soundness theorem, hermetic executable recipe, real seed port, stage-2/stage-3 or retained self-hosted
bootstrap artifact is claimed. Mutable typed-reference invariance/writeback, arbitrary-element
containers/cursors and remaining ownership joins are still required, not silently excluded.
