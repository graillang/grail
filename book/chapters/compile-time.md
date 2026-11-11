# Compile time

Some values are known before a program runs: a page size, a mask derived from it, the layout of a
record that is read from disk, which operating system the build is for. Grail computes these while
compiling and bakes the answers into the program. The marker for "decided before the program runs"
is `@`.

{{example:comptime}}

- `const PAGE: u64 = 4 * 1024;` and `MASK := PAGE - 1;` are module-level constants. A module has no
  run-time initialiser, so every module binding is computed while compiling; `const` gives the type
  explicitly and `:=` infers it.
- `@assert(condition, "message")` is a compile error carrying the message when the condition is
  false. `size_of` and `align_of` describe the *target*: scalars, handles and C pointers, and
  `extern "C"` records, whose C layout is fixed.
- `@if target.os == .windows { ... } else { ... }` compiles only the branch that holds. The other
  branch is skipped without being type-checked, so it may name functions that exist only on another
  platform. At module level it chooses declarations; inside a function, statements.
- `@expr` folds one operand: `@(PAGE * 2)`.

Constant expressions use literals, other constants, `size_of`, `align_of`, `target.os`,
`target.arch` and `target.pointer_bits`, with the usual operators; arithmetic is checked, so an
overflow is a compile error rather than a wrapped value. Calling a function at compile time comes with the next stage of the design
(`docs/design/comptime.md`).

## Value parameters

A generic list can take values as well as types. `@k: u64` declares one; a call gives it a
constant, and each distinct value is its own specialisation, with the value baked in:

{{example:value-generics}}

Inside the function the value is an ordinary constant of its declared type, and the `@` forms see
it - the `@assert` above runs once per instantiation, so `rotl<64>(x)` is a compile error at the
call. A value parameter cannot be inferred from the arguments, so the call always names it.

The Rust version spreads the same ideas over `const`, `const _: () = assert!(...)` and
`#[cfg(...)]`; Grail uses one marker for all of them.
