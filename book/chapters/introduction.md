# Grail by Example

Learn the implemented Grail language by reading small, complete programs, running them,
and changing one thing at a time. Start at the beginning, or use the chapter list and search.

Grail is a systems-language research project. Its native compiler is written in Grail and
reproduces itself through assembly. Owned values are released deterministically; there is no
tracing garbage collector or C runtime in the native path. The checker rejects conflicting
borrows and escaping locals, and generic code treats unknown values as affine.

**This book teaches the Grail compiler as it is today.** Every example is compiled and run by
`just book-check`, next to an equivalent Rust program that is compiled and run too. Linux x86-64
runs natively; Linux AArch64 and RISC-V 64 cross-build and run under qemu; Windows x86-64 builds PE32+
images that run under Wine; Windows AArch64 and macOS build objects but cannot run here.
`docs/platform-status.md` is the authoritative matrix. The few features still missing are listed
under *Current boundaries*. Tests are evidence of behavior, not a proof of soundness.

## How to use the examples

Every example block below comes from a real `.grl` file. Successful examples have checked stdout;
red examples are intentional compiler rejections. `just book-check` verifies both groups against
the checked-in bootstrap. Example commands are run from the repository root.

The book builds as static HTML: no account, CDN, web service, or network is needed to read it.
Use search, the arrow keys, or the previous/next links. Code blocks have copy buttons.

Every example shows Rust alongside Grail by default. **Hide Rust** applies across chapters;
**Show Rust** restores the comparisons. You can also collapse an individual example. Light mode
is the default, and an explicit theme choice is remembered.
Comparison notes distinguish actual differences from capabilities both languages share.

**Prerequisites:** Bun 1.4 or newer and `just` for this book. Running Grail examples additionally
requires a supported Linux CPU, Clang used only as an assembler, and LLD. Checking the Rust comparisons also needs `rustc` (edition 2024). Reading/building the static book needs neither compiler toolchains nor Rust.

**Your own programs:** `just install` puts the `grail` tool on your path. `grail new hello`
creates a project, `grail run` builds and runs it (an optimised development build with line
tables a debugger reads; `--release` for the LLVM build, `--debug` to step through unoptimised code), `grail test` runs the programs in `tests/`,
`grail fmt` applies the canonical layout used in this book, and `grail add NAME` adds a
dependency (`--path` and `--git` for a directory or a repository) resolved into `grail.lock`.

## Why Grail

Grail is a systems language in Rust's family. It has ownership, borrowing and lifetimes, no garbage
collector, no runtime exceptions, and native code. It does not try to be a smaller Rust. Its bet is
that the compiler should check more than memory safety: the invariants a program depends on, stated
in the program and proved where they can be.

### Invariants checked, not just memory

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

### What else is different

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

### Honest tradeoffs

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

### What Grail refuses

- No null: optional values are `T?`.
- No exceptions: errors are values, and `?` propagates them.
- No implicit numeric conversion, and no silent overflow: wrapping is spelled out.
- No interior mutability in safe code: shared mutation goes through `Mutex`.

Each refusal removes a class of bug that a check could not otherwise catch.

## Your first program

Our first program prints one line. This is the complete source file—no import, module declaration,
visibility modifier, return annotation, or manual byte view is needed.

{{example:hello}}

`main` is the program's entry point. `println` borrows its argument for the call and adds a newline.
The omitted result type is `unit`, and reaching the closing brace returns normally with status 0.
There is no automatic numeric output.

Comments are `// ...` to the end of the line, or `/* ... */`, which may span lines or sit inside one
(`add(a, /* left */ b)`). Block comments nest: every `/*` inside one needs its own `*/`, so a stretch
of code that already holds a comment can be commented out whole.

### Run it

From the repository root:

```sh
just book-run hello
```

The runner assembles the checked-in native bootstrap, compiles the example and the Grail runtime,
then uses GNU `as` and `ld` to create a static executable. Artifacts stay under `.work/book/`.
No global compiler installation is changed. Run `just book-check` to verify every example.

A checked Rust version is shown alongside the Grail version by default. Its code and output
are aligned, with a short note below explaining what differs and what is shared. Use **Hide Rust**
to turn comparisons off across the book, or collapse just one example.
On small screens the comparison stacks vertically; you can collapse it at any time.

For raw compiler commands and self-compilation instructions, see `compiler/NATIVE.md`.
A `main` may explicitly return `u64` to set the process exit status; it does not print that number.
Ordinary functions use explicit result types when returning values. A body's last expression,
written without `;`, is its result (`fn double(n: u64) -> u64 { n * 2 }`), and `return` leaves
early. A source file may also
declare an explicit `module`, as later examples do to make their names clear.

**Try it:** add a second `println` call, or use `print("Hello, "); println("world!");` to control
where the newline appears.
