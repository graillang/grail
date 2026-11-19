# Grail for Rust programmers

One program, written in both languages, covers the everyday constructs. Both run, and their output
is checked to agree.

{{example:cheatsheet}}

| Rust | Grail | Note |
|---|---|---|
| `let x = 5;` | `x := 5;` | Immutable by default in both. |
| `let mut t = 0;` | `mut t = 0;` | |
| `let x: u32 = 5;` | `x: u32 = 5;` | |
| `fn f(a: u64) -> u64 { a }` | `fn f(a: u64) -> u64 { a }` | The last expression of a block, without `;`, is its value; `return` exits early. |
| `trait Shape { fn area(&self) -> u64; }` | `interface Shape { fn area(&self) -> u64; }` | `&self` is `self: &Self`, written either way. |
| `impl Shape for Rect` | `impl Shape for Rect` | |
| `x.abs()`, `x.checked_add(y)`, `x.to_string()` | `x.abs()`, `x.checked_add(y)`, `x.to_string()` | Integer and `char` methods need no `use`; float functions such as `x.sin()` come with `use math;`. |
| `f64::from_bits(b)` | `f64::from_bits(b)` | |
| `trait Ext { .. }` + `impl Ext for u64` | `interface Ext { .. }` + `impl Ext for u64` | Callable as `x.method()` where `Ext`'s module is `use`d; an inherent `impl u64` is the standard library's alone. |
| `fn largest<T: Shape>(items: &[T])` | `fn largest<T: Shape>(items: &T[])` | `T[]` is a vector, `&T[]` its view. |
| `vec![a, b]` | `[a, b]` or `Rect[a, b]` | The element type may lead the literal; `[]` alone needs an expected type. |
| `Option<u64>`, `Some(x)`, `None` | `u64?`, `Some(x)`, `None` | `x!` insists, `?` propagates. |
| `match t { Token::Num(n) => ..., }` | `match t { Num(n) => ..., }` | An arm body is an expression or a block. |
| `(a, b)`, `let (q, r) = ...;` | `(a, b)`, `(q, r) := ...;` | |
| `\|n\| n > 4` | `\|n\| n > 4` | Types are inferred from the call; comparisons see through references. `\|n\| n > 4` abbreviates the function literal `fn(n) { n > 4 }`. |
| `fn helper(..)` nested (no captures), or a closure | `fn helper(..) -> R { .. }` inside a body | A local function is a closure with a name: it may capture, and it may call itself (its result type then written). |
| `F: Fn() -> R + Send + 'static` | `f: FnMut<Send, Owned>() -> R` | Bounds on the closure type: `Send`, `Share` (Rust's `Sync`), `Owned` (no borrows). A bare `Fn(..)` is neither `Send` nor `Share`. |
| `data.par_chunks_mut(n).for_each(f)` (rayon) | `data.par_chunks_mut(n, f)` | Pieces of at most `n` elements; the split never depends on the number of cores. `v.into_par_chunks(n, f)`, `pool::range` and `data.par_chunks_reduce(..)` are the owned, index and folding forms. |
| `rayon::join(a, b)` | `pool::join(a, b)` | `a` may run on another worker; `b` runs here. |
| `v.iter().filter(..).collect()` | `v.iter().filter(..).collect()` | Borrows `v` and yields `&T`, lazily, in both; `iter::of(v)` (`v.into_iter()`) moves the elements out. |
| `Rc::new(v)`, `Rc::clone(&r)` | `rc::new(v)`, `r.clone()` | `Arc` is the same shape. |
| `impl Drop for Guard` | `impl Drop for Guard` | |
| `assert!(b != 0)` at run time | `b: u64 where b != 0` | Proved at the call when it can be, checked otherwise. |
| `unsafe { *p }` | `unsafe { *p }` | Raw pointers are `*T` and `*mut T`; `*p = v` writes through a `*mut T`. |
| `cargo build` | `grail build` | Both carry debug information by default. Grail's development build is optimised and carries line tables and function ranges; `grail build --debug` turns the optimiser off and describes variables too, `--no-debug-info` leaves it all out. |
| `cargo build --release` | `grail build --release` | Neither carries debug information. |
| `macro_rules!` | `@if`, `@for`, comptime calls | Compile-time code is ordinary Grail. |
