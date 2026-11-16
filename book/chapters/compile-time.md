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
- `static TABLE: u64[] = @build();` runs `build` while compiling and keeps its result as one
  read-only object the program borrows (see *Module values* in the modules chapter).

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

## Reflection

`@for f in fields(T) { ... }` compiles its block once per field of a record, in declaration order.
Inside, `f.name` is the field's name as a string, `f.index` its position, and `x.@f` the field
itself, typed as that field is - so one generic function prints, compares or serialises any record:

```grl
fn show<T>(v: &T) {
    @for f in fields(T) {
        println("{} = {}", f.name, v.@f);
    }
}
```

`variants(E)` does the same over an enum's variants (`v.name`, `v.index`). `@embed("logo.png")` is
a file's bytes, read while compiling and placed in the program as `u8[]`; the path is relative to the
source file.

A record takes value parameters as functions do: `struct Ring<T, @N: u64>` makes `Ring<u64, 8>` and
`Ring<u64, 16>` two types, and `fn capacity<T, @N: u64>(r: &Ring<T, N>) -> u64` reads `N` back from
its argument's type.

