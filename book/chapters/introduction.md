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
