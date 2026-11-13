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
| `vec![a, b]` | `Rect[a, b]` | The element type leads the literal. |
| `Option<u64>`, `Some(x)`, `None` | `u64?`, `Some(x)`, `None` | `x!` insists, `?` propagates. |
| `match t { Token::Num(n) => ..., }` | `match t { Num(n) => ..., }` | An arm body is an expression or a block. |
| `(a, b)`, `let (q, r) = ...;` | `(a, b)`, `(q, r) := ...;` | |
| `\|n\| n > 4` | `\|n: &u64\| -> bool *n > 4` | Written out here; inferred where the call fixes them. |
| `iter().filter(..).collect()` | `iter::collect(iter::filter(iter::of(v), ..))` | Adapters are lazy in both, and also chain as methods. |
| `Rc::new(v)`, `Rc::clone(&r)` | `rc::new(v)`, `r.clone()` | `Arc` is the same shape. |
| `impl Drop for Guard` | `impl Drop for Guard` | |
| `assert!(b != 0)` at run time | `b: u64 where b != 0` | Proved at the call when it can be, checked otherwise. |
| `unsafe { *p }` | `unsafe { p.read() }` | Raw pointers are `*T` and `*mut T`. |
| `macro_rules!` | `@if`, `@for`, comptime calls | Compile-time code is ordinary Grail. |
