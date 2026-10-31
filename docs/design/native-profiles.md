# Native development and release profiles

The real `compile` / `build` driver accepts three explicit native profiles:

| CLI profile | native compiler | intended use |
| --- | --- | --- |
| `clang` (unchanged default) | installed clang, `-O0` | development |
| `clang-release` | installed clang, `-O2` | optimizing release |
| `tcc` | configured Goose/TinyCC | fast development / ABI comparison |

```sh
seed/target/release/grail-seed compile seed/std/core.grl OUT OUT clang-release
seed/target/release/grail-seed compile seed/examples/generics/parse.grl OUT OUT clang-release
seed/target/release/grail-seed build seed/examples/generics/client.grl OUT OUT clang-release
OUT/client 42
```

Both C object compilation and executable linking use the chosen profile. There is no LTO, fast-math,
profile-directed checker bypass or native capability/ownership change. CLI usage/errors name all
three profiles. The prior default does not silently become optimized, and TinyCC retains its pinned
support-root/CRT/no-unwind-table configuration.

## Interfaces and artifacts

Checking, canonical interfaces, generic physical layouts, emitted C and dependency validation are
profile independent. Different-profile objects can link through the same checked ABI: development
providers with optimizing callers and TinyCC/optimizing crossings are executed in both directions.
There is no interface-schema bump or duplicate release-only semantics.

A module artifact's content identity already binds the actual C/object/API bytes. Thus optimization
changes its generation when object bytes change; no redundant profile-name tag is needed to claim
that equal material bytes differ. The public interface fingerprint does not include optimization.

Native compilation uses job-owned work directories and stable **relative input filenames**, without
debug information or temporary-path macros. Under the same installed toolchain/system libraries,
identical inputs and selected dependency objects reproduce module IDs, object bytes and executable
bytes—even after relocating output/import stores and removing provider sources. Concurrent release
publication and corruption controls reuse the immutable-generation tests.

This is tested reproducibility, **not a hermetic toolchain bundle or complete executable recipe
manifest**. The module manifest does not yet bind a final executable or inventory all linked
implementation generations/toolchain/system-library bytes. Capturing the complete bootstrap graph,
packaging the compiler and stage-2/stage-3 reproducibility/TCB audit remain required v0 work.
Hostile native objects/filesystems, dishonest FFI producers and authenticated interfaces remain
outside the current guarantee.

## Optimization observations and safety gates

Full tests still run independently of native optimization. The new profile test covers nested
Result/Pair ownership, captured token/error returns, source-hidden providers, reallocating byte
vectors, empty copies/text/slices and wrapping arithmetic. Bounds failure, remainder by zero and
failed unwrap must still abort under every selected profile. Release UTF-8 tests compare valid and
malformed input against Rust; invalid byte sequences must abort, not become accepted after `-O2`.

Allocator calls are not language-level user effects in this slice. Optimizing C can elide unobserved
allocations/frees; precise wrapper-based allocation traces therefore remain separate instrumentation
probes with allocator builtin optimizations disabled when necessary. The production release profile
does **not** disable optimizer features just to satisfy those counters. Custom effectful destructors
remain deferred; default recursive ownership cleanup retains its checked semantics.

`research/experiments/profiles37/check.py` records stable/pinned-nightly full-suite results, profile
crossings, UTF-8/corruption/concurrent-publication controls, deterministic rebuilds and three-run build/
runtime measurements through the **actual driver**. Its scanner classifies word bytes and computes
a wrapping hash over a retained prefix of real seed source, with an independent Python checksum.
It is a precursor source-scanning workload, not the complete Grail lexer or self-hosted compiler.

[Retained commands, source hashes, costs and limitations](../../research/evidence/profiles37-20261031/README.md).
