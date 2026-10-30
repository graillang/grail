# Lexical scopes checkpoint

`checks.json` retains full tests (including native integration tests), Clippy, release build,
and TinyCC execution of `scopes.grl` (7). C and LLVM both execute nested blocks/shadowing in the
borrowed-input sum workload. The allocator audit checks nested and same-scope shadowed owners:
three allocations stay live after same-scope shadowing, then final cleanup releases each once.
These are primitive owner/view tests, not aggregate-ownership or self-hosting evidence.

`cost_harness.rs` calls the public source compiler in-process, five repetitions per size,
release-built seed/stable Rust on this host. `costs.txt`: blocks, source bytes, median seconds.
250 / 1,000 / 4,000 blocks took 1.30 / 5.94 / 28.36 ms. Numeric temporary metadata remains linear
in function size; unconditional blocks do not clone all preceding state. This is a narrow synthetic
scoping test, not a real-compiler benchmark or a general complexity claim. Reproduce from repo root:

```sh
cargo build --manifest-path seed/Cargo.toml --release --offline
rustc --edition=2024 -O research/evidence/scopes24-20261030/cost_harness.rs \
  --extern grail_seed=seed/target/release/libgrail_seed.rlib \
  -L dependency=seed/target/release/deps -o /tmp/grail-scope-cost
/tmp/grail-scope-cost
```

No new runtime borrow checks or signature-schema changes are needed. The existing restriction on
conditional ownership joins/back edges remains; unconditional blocks preserve consumption instead.
