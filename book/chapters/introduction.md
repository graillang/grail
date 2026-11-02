# Grail by Example

Learn the implemented Grail language by reading small, complete programs, running them,
and changing one thing at a time. Start at the beginning, or use the chapter list and search.

Grail is a systems-language research project. Its native compiler is written in Grail and
reproduces itself through assembly. Owned values are released deterministically; there is no
tracing garbage collector or C runtime in the native path. The checker rejects conflicting
borrows and escaping locals, and generic code treats unknown values as affine.

**This book teaches the current Linux x86-64 native backend, not a promised final language.**
The syntax and tooling are still evolving. See *Current boundaries* before depending on an
unsupported feature. Tests are evidence of behavior, not a language soundness proof.

## How to use the examples

Every example block below comes from a real `.grl` file. Successful examples have checked stdout;
red examples are intentional compiler rejections. `just book-check` verifies both groups against
the checked-in bootstrap. Example commands are run from the repository root.

The book builds as static HTML: no account, CDN, web service, or network is needed to read it.
Use search, the arrow keys, or the previous/next links. Code blocks have copy buttons.

Selected examples include optional Rust comparisons, collapsed by default. Expand **Compare Rust**
to see aligned code and output, or use **Show Rust** for every comparison on the current page.
Comparison notes distinguish actual differences from capabilities both languages share.

**Prerequisites:** Bun 1.4 or newer and `just` for this book. Running Grail examples additionally
requires Linux x86-64 and GNU `as`/`ld`. Checking the Rust comparisons also needs `rustc` (edition 2024). Reading/building the book does not require a C compiler,
Rust, or the example toolchain.
