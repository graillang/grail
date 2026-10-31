# Generic layout gates

Run `python research/experiments/generic36/check.py` from the repository. This uses installed stable,
pinned private nightly, clang and the existing Goose/TinyCC build; no downloads or provider changes.
Scratch builds are isolated under ignored `.work`, including a `git archive` baseline at `889bb45`.

- Complete seed suites, clippy/fmt/release seed, both mixed native directions and sanitizer probes.
- Independent Rust token/error API and generic payload/propagation destructor sequences.
- Three-run deterministic emitted C/API/layout-cost comparisons for 8/32/128/256 instances, before
  and after with explicit expanded layouts and after with actual generic layouts.
- Source hashes, exact commands, tool versions, statuses, outputs and medians in retained evidence.

This does not implement/test generic function body specialization, general typed mutable references,
arbitrary-element vectors or self-compilation. The preceding `generic35` requirements still gate them.
