# Checked propagation

Run `python research/experiments/propagate33/check.py` with the existing stable Rust, private pinned
nightly, clang and configured memory01 TinyCC tree. It leaves host Rust selection unchanged. Outputs
and build targets stay under ignored `.work`.

The independent Rust reference prints 49 / 5 / 7 / 8, release order 3 2 4 1, retained mutation 9,
and None. Its two negative error-type/lifetime controls compile only and never execute. Native
Grail validates the same pipeline and additionally checks complete allocator release sequences
through hidden modules, pending arguments, loop conditions and Option propagation.

Cost columns: '?' sites, source bytes, emitted C bytes, release-seed checking seconds, C lowering
seconds. This is an adversarial flat-expression stress case, not a representative finished compiler.
