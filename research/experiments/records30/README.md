# By-value record controls

`reference.rs` independently executes mixed-owned/captured fields, disjoint returned mutable fields
and drop-only capture liveness. Stable and the pinned modern nightly must return `16 / 11 / 5`;
clang/TinyCC Grail builds of `seed/examples/records` must agree. The two negative Rust programs are
compile-only and never run. Matching Grail negatives are actual supported record source in
`seed/tests/records.rs`, including a captured lifetime not licensing a reference to owned storage.

Run `python research/experiments/records30/check.py` from any directory. Prerequisites: pinned
project-local nightly from `rust_next20/README.md` and configured TinyCC from the native experiments.
The runner also checks the entire seed under stable/nightly and explicit TinyCC record/artifact/module
tests. Records in C are implemented; LLVM explicitly refuses record layouts. These tests are neither
full v0 delivery nor a general soundness proof. See `docs/design/record-core.md` for remaining gates.
