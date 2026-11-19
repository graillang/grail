# Grail for Rust programmers

One program, written in both languages, covers the everyday constructs. Both run, and their output
is checked to agree.

{{example:cheatsheet}}

| Rust | Grail | Note |
|---|---|---|
| `let x = 5;` | `x := 5;` | Immutable by default in both. |
| `let mut t = 0;` | `mut t = 0;` | |
| `let x: u32 = 5;` | `x: u32 = 5;` | |
| `fn f(a: u64) -> u64 { a }` | `fn f(a: u64) -> u64 { return a; }` | Grail always returns explicitly. |
| `trait Shape { fn area(&self) -> u64; }` | `interface Shape { fn area(self: &Self) -> u64; }` | The receiver is an ordinary typed parameter. |
| `impl Shape for Rect` | `impl Shape for Rect` | |
| `fn largest<T: Shape>(items: &[T])` | `fn largest<T: Shape>(items: &T[])` | `T[]` is a vector, `&T[]` its view. |
| `vec![a, b]` | `[a, b]` or `Rect[a, b]` | The element type may lead the literal; `[]` alone needs an expected type. |
| `Option<u64>`, `Some(x)`, `None` | `u64?`, `Some(x)`, `None` | `x!` insists, `?` propagates. |
| `match t { Token::Num(n) => ..., }` | `match t { Num(n) => ..., }` | An arm body is an expression or a block. |
| `(a, b)`, `let (q, r) = ...;` | `(a, b)`, `(q, r) := ...;` | |
| `\|n\| n > 4` | `\|n: &u64\| -> bool *n > 4` | Written out here; inferred where the call fixes them. |
| `F: Fn() -> R + Send + 'static` | `f: FnMut<Send, Owned>() -> R` | Bounds on the closure type: `Send`, `Share` (Rust's `Sync`), `Owned` (no borrows). A bare `Fn(..)` is neither `Send` nor `Share`. |
| `data.par_chunks_mut(n).for_each(f)` (rayon) | `pool::split_mut(&mut data[0: len], n, f)` | Pieces of at most `n` elements; the split never depends on the number of cores. `pool::split`, `range` and `reduce` are the owned, index and folding forms. |
| `rayon::join(a, b)` | `pool::join(a, b)` | `a` may run on another worker; `b` runs here. |
| `iter().filter(..).collect()` | `iter::collect(iter::filter(iter::of(v), ..))` | Adapters are lazy in both, and also chain as methods. |
| `iter().filter(..).collect()` | `iter::of(v).filter(..).collect()` | Adapters are lazy in both. |
| `Rc::new(v)`, `Rc::clone(&r)` | `rc::new(v)`, `r.clone()` | `Arc` is the same shape. |
| `impl Drop for Guard` | `impl Drop for Guard` | |
| `assert!(b != 0)` at run time | `b: u64 where b != 0` | Proved at the call when it can be, checked otherwise. |
| `unsafe { *p }` | `unsafe { p.read() }` | Raw pointers are `*T` and `*mut T`. |
| `cargo build` | `grail build` | Both carry debug information by default. Grail's development build is optimised and carries line tables and function ranges; `grail build --debug` turns the optimiser off and describes variables too, `--no-debug-info` leaves it all out. |
| `cargo build --release` | `grail build --release` | Neither carries debug information. |
| `macro_rules!` | `@if`, `@for`, comptime calls | Compile-time code is ordinary Grail. |
