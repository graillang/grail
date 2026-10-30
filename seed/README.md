# Grail seed slice

A reusable Rust checker, first `.grl` source frontend, and C/LLVM emitters. This is a narrow
implementation slice, not a complete Grail compiler. No external Rust crates or network are required.

```sh
cargo test --manifest-path seed/Cargo.toml --offline
cargo clippy --manifest-path seed/Cargo.toml --offline --all-targets -- -D warnings
cargo build --manifest-path seed/Cargo.toml --offline --release
seed/target/release/grail-seed provider seed/.work/demo 0 1 c
seed/target/release/grail-seed client seed/.work/demo seed/.work/demo/scan.api 1024:2 c
seed/target/release/grail-seed scale 4096
```

`provider OUT BIAS VERSION c|llvm` and `client OUT API LEN:REPEATS c|llvm` construct fixed
workloads through the public typed-IR API. They write native source plus a canonical signature.
They are demonstration commands, not a surface-language parser or general build system.

## Supported semantics

- Owned local byte buffers and growable heap byte vectors; affine read/write views and carriers.
- Explicit region labels in signatures. Labels describe lifetime relationships, **not** target
  identity. Separate mutable input parameters have distinct abstract targets even with one label.
- Reborrows restrict the parent carrier; moves preserve loan identity. Owner release/movement
  requires all views to end. Calls consume view arguments; explicit reborrows retain a parent.
- Returned references may originate only from suitable input regions. No local-buffer escape.
  Imported return bounds conservatively retain every compatible argument origin and parent.
- Counted loops require the same resource state at their back edge. Numeric state may change;
  loop-local resources must end. The lowered IR has explicit `End`; the source frontend infers
  borrowed-value endings and inserts lexical owner cleanup.
- Numbers are wrapping u64; buffers hold bytes. Native indexing and remainder have abort guards.
  `buffer` is stack allocated (individual maximum 1 MiB); `bytes` is heap allocated and grows
  only when unborrowed. Stack exhaustion is not prevented.
- A private validated wrapper gates lowering. Interfaces describe types/regions only, no G1
  post-state inference. Signature decoding validates schema and canonical form, not producer honesty.

No general generics, arbitrary records, Result/error flow, closures, reference-containing heap elements,
async, destructors, capabilities, interface authentication or language soundness theorem yet.
Numeric branches and byte slicing are now supported in both emitters.
The compiler's own safe Rust is not a proof that the new checker is sound. The first scaling
probe exposed repeated whole-state scans. Indexed loan checks now remove those scans; deep
ancestry and origin unions still need measurement.

## Native boundary

C lowers the checked IR, including heap owners. LLVM currently rejects owned heap layouts
explicitly and remains a comparison backend for the earlier subset. The workload scans bytes, counts word starts, computes a
rolling hash and updates a byte bucket table. The client holds its input view in a carrier and
calls the body-hidden provider repeatedly. LLVM uses simple alloca-based locals; these emitters
are not optimized or portable-ABI-certified. Native execution is currently checked on Linux x86-64.

The TinyCC driver in the prior Goose build is usable, but is configured for embedded/JIT use.
Standalone linking needs explicit host CRT objects, libc paths and its staged support archive;
this is recorded by the measurement harness rather than changing third-party sources.

## Measurements

[Results and limitations](../docs/design/seed-measurements.md). Reproduce with:

```sh
python seed/measure.py --pairs 10 --length 262144 --repeats 16
```

Requires Linux wait4/bubblewrap, clang, rustc/cargo, and the existing pinned Goose/TinyCC build
under `research/experiments/memory01/.work/goose-build`. It rebuilds baseline `d6ac951` in owned
scratch, preserves all measured samples and aborts on nonzero exits or checksum mismatches.
The driver is Python orchestration; it is not a replacement for the Rust seed or its future
Grail implementation. It does not download tools, contact models, or modify external sources.

## First source-to-native path

[Bootstrap v0 rules and limits](../docs/design/bootstrap-v0.md). Requires clang for the default
native driver; Cargo itself still has no third-party crates.

```sh
cargo build --manifest-path seed/Cargo.toml --release --offline
seed/target/release/grail-seed compile seed/examples/number.grl seed/.work/source seed/.work/source
seed/target/release/grail-seed build seed/examples/sum.grl seed/.work/source seed/.work/source
seed/.work/source/sum '12+34+5'  # 51
cargo test --manifest-path seed/Cargo.toml --offline
cargo test --manifest-path seed/Cargo.toml --offline --test native -- --ignored
```

For the configured TinyCC driver, set `GRAIL_TCC_ROOT` to the existing Goose build root and append
`tcc` to both compile/build commands. There is no silent fallback or download. Source modules have
one exported function; only direct imports are linked. The parser example borrows slices rather
than allocating token copies. Malformed numeric input aborts, and the executable expects exactly
one text argument. Generic heap containers, Result and type generics are still follow-up work.

## Heap byte owners

[Semantics and limits](../docs/design/heap-ownership.md). `bytes()`, `push`, `copy_bytes` and
owned `bytes` parameters/results are now supported by the C backend. Signatures are schema 2;
rebuild old `.api` files. Heap owners drop at scope exit, not at borrowed-value last use.

```sh
seed/target/release/grail-seed compile seed/examples/make_bytes.grl seed/.work/heap seed/.work/heap
seed/target/release/grail-seed build seed/examples/use_bytes.grl seed/.work/heap seed/.work/heap
seed/.work/heap/use_bytes  # 125717
cargo test --manifest-path seed/Cargo.toml --offline --test heap_native -- --ignored
```
