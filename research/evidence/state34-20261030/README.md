# Scalar state reduction

`before.json` pins the full baseline revision and original compiler/output hashes. The gate rebuilds
that revision in a fresh ignored directory rather than trusting the current compiler to emulate it.
`checks.json` retains source/input hashes, commands, tool versions, environments, outputs and expected
acceptance. The full suite runs on stable and pinned modern nightly, including native release-order
and mixed-backend propagation tests. No host default, model or provider changed.

The final enlarged 1,600-case corpus includes reuse of previously defined loop indices. Acceptance
matches exactly: 271 raw and 108 source programs accept; all others reject in both compilers.
`differential.json` records 487 accepted C/API output hashes, plus 16 byte-identical cost outputs.
Generated invalid/nonterminating raw IR is compile/lower-only, never executed.

Raw `costs-before-N.txt` / `costs-after-N.txt` and `medians.json` retain three-run before/after values.
The original first sample and an intermediate scalar-only optimization sample are also retained,
not substituted for final timings. The median 1,000-branch check improved 406 ms → 4.2 ms; 1,000
propagations improved 1.69 s → 12 ms. C and interface output identity is a hard gate; elapsed time
is a local observation, not a universal bound or representative finished-compiler performance.

An extra regression caught an intermediate optimization incorrectly permitting a dead scalar
parameter as a fresh loop index. It was fixed with separate compact definedness tracking before
landing. Ownership/reference state is not pruned, and no general typed scalar references exist yet;
that future feature must extend address-liveness rules. See `docs/design/checker-state.md`.
