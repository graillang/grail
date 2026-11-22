# Typed slices

`&[T]` and `&mut [T]` borrow a contiguous run of a vector's elements, for every element type, as
`&[u8]` already does for bytes (Go slices, Rust `&[T]`, Zig `[]T`).

## Surface

- Types: `&a [T]`, `&a mut [T]` (lifetime as for any reference; `&[u8]` stays the byte view).
- Creation: `v[a: b]`, `v[a:]`, `v[: b]`, `v[:]` on a `T[]` or on a slice, borrowed shared
  (`&v[a: b]`, or implicitly where a `&[T]` is expected) or exclusively (`&mut v[a: b]`).
  Bounds are checked: `a <= b <= len`.
- Use: `s.len()`, `s.is_empty()`, `s[i]` (read), `s[i] = x` and `s[i] += x` (`&mut` only),
  `&s[i]` / `&mut s[i]` (element references, narrow elements included), `for x in s`
  (each element borrowed: `&T`, or `&mut T` through `&mut [T]`; `for x in &s` is the same loop),
  sub-slicing, `s.copy()` -> `T[]` for plain elements, `{}` formatting,
  `contains` for integer/bool elements, `==` like vectors.
- Not in a slice: anything that changes the length (`push`, `pop`, `insert`, `remove`, `truncate`).
- Generic code over `&[T]` specializes per element type like every generic.

## Representation

A slice is a two-word descriptor `{ptr, len}`, the same as a byte view, allocated and released the
same way. A vector header is `{data, len, cap}`, so the descriptor is a prefix of it: the runtime's
element routines (`rt_slot`, `rt_at`, `rt_slot4`, `rt_at4`, `rt_len`) take either. Slicing a vector
or a slice is `rt_vslice(s, a, b, width)`: `{ptr + a*width, b - a}` with width 8, or 4 for the narrow
element types (`f32`, `u32`, `i32`).

The element type is part of the type (a new kind, `slice`, whose argument is the element type; byte
views keep their own kind so existing byte code is unchanged), so element access, width, narrow
encoding and tagged references follow the vector rules exactly.

## Ownership

A slice is a loan of the vector (or of the slice it came from), tracked like a byte view: shared
slices may coexist; an exclusive slice excludes every other use of the vector while it lives; a
slice cannot outlive its vector, and the vector cannot grow (push/insert/truncate) while one exists.
Reading an element that needs a drop through a slice yields a reference, as with `&v[i]`.

## FFI

Not in this change. `&[f32]`/`&[u32]` already have C's layout (`float*` + count), so passing them as
pointer + length follows later, alongside byte views.

## Verification

Native cases for every operation on word and narrow elements, the ownership rejections (mutation
through a shared slice, growing a borrowed vector, a slice outliving its vector, overlapping
exclusive slices), generic functions over slices; the full native suite on all targets and LLVM.
Port clod's span helper to slices as the first real user.
