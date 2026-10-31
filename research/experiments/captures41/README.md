# Captured readonly references

Run `python research/experiments/captures41/check.py` with existing stable/pinned-nightly Rust,
clang and the configured TinyCC root. The gate does not download tools or use other models.

Independent Rust executes the cursor/drop control and rejects both a long unique-field borrow and
nested-capture widening. Real source-hidden Grail modules execute the same authority/cleanup
boundary, nested const-pointer/descriptor ABI in C/LLVM, and allocator/optimizing sanitizer checks.
A frozen `b755920` replays the same compile/lower-only corpus; invalid/nonterminating IR is never run.

Costs include old/new plain loops and numeric references, plus 1/8/32/64 distinct source captures
across 16/64/256 getter calls. The native scanner compares the old by-value-view provider with the
new shared-cursor provider over the same 950272 bytes / 131072 tokens. Both own token spellings and
use real generic Result/Option helpers. Provider source is removed; three samples require stable
artifact IDs/executable bytes. The new program has one extra cursor/name and an intentionally changed
provider ABI, so this is representative composition evidence, not an isolated instruction-level
measurement or whole compiler benchmark. Runtime includes fixed host-shim/process overhead.

Mutable capture witnesses/invariance/writeback, general reference-containing containers/cursors and
self-hosting remain required. Do not count still-unsupported mutable types as proof of those gates.
