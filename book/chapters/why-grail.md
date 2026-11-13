# Why Grail

Grail is a systems language in Rust's family. It has ownership, borrowing and lifetimes, no garbage
collector, no runtime exceptions, and native code. It does not try to be a smaller Rust. Its bet is
that the compiler should check more than memory safety: the invariants a program depends on, stated
in the program and proved where they can be.

## Invariants checked, not just memory

A refinement is a predicate on a value, written where the value enters a function, a record or a
result:

{{example:refinements}}

The compiler proves each predicate from the facts at the call site: constants, conditions, loop
bounds and other refinements. Where it cannot, it inserts a check that fails with both locations.
Under `@strict` an unproved obligation is a compile error instead, and the program carries a proof.
A proved refinement also removes the bounds checks it implies. `fn get(v: &u64[], i: u64 where
i < v.len())` indexes with no check at all.

Effects build on the same proofs. `@no_alloc` and `@no_panic` are verified over everything a function
can reach, the runtime included. `@bounded(n)` proves a loop's iteration count. A real-time audio
callback or a frame loop can say what it promises, and the build fails when the promise breaks,
naming the call chain that broke it.

## What else is different

- **One way to bind.** `x := v` binds, `mut x = v` binds for reassignment, and `x: T = v` gives a
  type. Literals pick their type from where they flow.
- **Borrowing without lifetime noise in the common case.** References carry lifetimes, but most
  signatures need none written. Two-phase borrows let `v.push(v.len())` compile.
- **Capabilities, not marker traits.** Whether a value may cross threads (`transferable`) or be
  shared (`shareable`) is derived structurally. A foreign handle has to be classified by an audited
  declaration, and anything unclassified is refused.
- **Compile-time code is Grail.** `@if`, `@for` over a record's fields and compile-time function calls
  replace macros.
- **A self-hosted compiler.** It generates native code for x86-64, AArch64 and RISC-V Linux, and
  cross-builds Windows programs, which are run under Wine in the test suite. An LLVM path produces
  optimised code. Each Linux target has its own checked-in seed, and the compiler reproduces itself
  byte for byte. macOS objects are checked, but a macOS build does not link yet.

## Honest tradeoffs

**Against Rust.** Rust's ecosystem, tooling and real-world experience are far larger. Its trait
system is more expressive: Grail's interfaces have associated types, generic methods and
inheritance, but no specialisation, no higher-ranked bounds and no procedural macros. Grail's prover
is deliberately small (a difference graph, divisibility and float classes, not an SMT solver), so
some true invariants stay runtime checks. Grail's compile times are good but not yet incremental
below the module level. Choose Rust for production systems today. Choose Grail when you want the
compiler to check your program's domain invariants and you can live with a young language.

**Against Go.** Go compiles faster, has a garbage collector that makes ownership disappear, and has a
mature scheduler and standard library. Grail asks you to think about ownership, and gives you
predictable latency, no collector and checked invariants in return. Grail's green-task scheduler is
young next to Go's.

**Against Zig.** Zig gives you more direct control and fewer rules, with explicit allocators and
`comptime`. It trusts the programmer about memory and invariants. Grail checks both, which costs
some freedom: aliasing rules, and an `unsafe` boundary that raw-pointer code must sit behind. Zig's
C interop and cross-compilation are more polished.

## What Grail refuses

- No null: optional values are `T?`.
- No exceptions: errors are values, and `?` propagates them.
- No implicit numeric conversion, and no silent overflow: wrapping is spelled out.
- No interior mutability in safe code: shared mutation goes through `Mutex`.

Each refusal removes a class of bug that a check could not otherwise catch.
