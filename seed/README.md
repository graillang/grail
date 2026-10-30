# Grail seed slice

A reusable Rust typed-IR checker and C/LLVM emitters. This is the first implementation slice,
not a `.grl` parser or a complete Grail compiler. No external Rust crates or network are required.

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

- Owned local byte buffers; affine read/write views; one-field carriers containing a view.
- Explicit region labels in signatures. Labels describe lifetime relationships, **not** target
  identity. Separate mutable input parameters have distinct abstract targets even with one label.
- Reborrows restrict the parent carrier; moves preserve loan identity. Owner release/movement
  requires all views to end. Calls consume view arguments; explicit reborrows retain a parent.
- Returned references may originate only from suitable input regions. No local-buffer escape.
  Imported return bounds conservatively retain every compatible argument origin and parent.
- Counted loops require the same resource state at their back edge. Numeric state may change;
  loop-local resources must explicitly end. The lowered IR has explicit `End`, not source-level NLL.
- Numbers are wrapping u64; buffers hold bytes. Native indexing and remainder have abort guards.
  Local buffers are stack allocated (individual maximum 1 MiB); stack exhaustion is not prevented.
- A private validated wrapper gates lowering. Interfaces describe types/regions only, no G1
  post-state inference. Signature decoding validates schema and canonical form, not producer honesty.

No general generics, arbitrary records, branches, Result/error flow, closures, heap ownership,
async, destructors, capabilities, interface authentication or language soundness theorem yet.
The compiler's own safe Rust is not a proof that the new checker is sound. The first scaling
probe exposes repeated whole-state scans; optimizing those is the immediate next step.

## Native boundary

C and LLVM lower the same checked IR. The workload scans bytes, counts word starts, computes a
rolling hash and updates a byte bucket table. The client holds its input view in a carrier and
calls the body-hidden provider repeatedly. LLVM uses simple alloca-based locals; these emitters
are not optimized or portable-ABI-certified. Native execution is currently checked on Linux x86-64.

The TinyCC driver in the prior Goose build is usable, but is configured for embedded/JIT use.
Standalone linking needs explicit host CRT objects, libc paths and its staged support archive;
this is recorded by the measurement harness rather than changing third-party sources.
