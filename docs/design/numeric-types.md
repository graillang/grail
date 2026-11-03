# Numeric types: recommended next step

This is a proposal, not an implemented feature list. Today the only primitive number is checked
unsigned 64-bit `num`; `true` / `false` are numeric truth literals, not a separate boolean type.

Use a small Rust-like family rather than unrelated special-purpose number types:

- `u8`, `u16`, `u32`, `u64` and `i8`, `i16`, `i32`, `i64` for explicit width and signedness.
- `usize` / `isize` for target-width indexing and sizes; do not hard-code those as u64 on all targets.
- A distinct `bool` for comparisons, conditions and `true` / `false`.
- Contextually inferred integer literals, with one documented default when unconstrained
  (`i64` is a reasonable default for this initially 64-bit language). Check literal ranges.
- No implicit mixed-width or signed/unsigned arithmetic. Explicit conversions distinguish proven
  lossless conversion, fallible narrowing, and intentionally truncating conversion.
- Checked ordinary arithmetic in every build profile. Keep wrapping operations explicit;
  provide checked/result-returning operations where failure is recoverable.

The migration should replace bootstrap `num` with the appropriate concrete type, not introduce a
permanent second name for u64. Keep fixed-width semantics identical across native, C, LLVM,
constant evaluation and generic specialization. Signed division must check MIN / -1 as well as
zero. Layout, byte-load/store widths, ABI boundaries and bounds conversions must all agree.

Defer `u128` / `i128` and floating point until their multiword/FP lowering and calling conventions
are supported. Do not advertise names merely because they appear in design sketches.
