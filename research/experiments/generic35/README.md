# Generic lowering preimplementation comparison

Run `python research/experiments/generic35/check.py` with clang, the existing TinyCC build, stable
Rust and pinned private nightly. Host defaults are unchanged; no models/providers are consulted.
Generated inputs, objects and executables stay under ignored `.work`.

`api.h`, `erased.c`, `specialized.c`, `bench.c` and generated extra instances compare C object
production/runtime, **not an implemented Grail generic checker**. Providers/consumers compile in
separate invocations, no LTO; clang links every configuration intentionally. Real seed Rust/source
files form a frozen lexical-span corpus, checked independently in Python. Every configuration
checks checksum, token count and allocation balance. Positive sanitizer and mixed-compiler runs
supplement the timings. `dynamic.c` checks runtime-sized stack temporaries / owned value transfer;
`snapshot.c` demonstrates why address forwarding must not replace by-value argument snapshots.

`cases.py` contains 12 independent Rust acceptance/rejection requirements for cursor source
lifetimes, unique outer loans, invariant mutable storage, swaps, take/pop and vector captures.
Rejected controls only compile and never execute. Grail general typed references remain future
work; unsupported syntax in the current parser is not counted as a rejection proof.

The results select a small initial static-specialization implementation, not a permanent ban on
shared code. See `docs/design/generic-lowering-gates.md` for limits and required soundness gates.
