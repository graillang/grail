# The Grail compiler

The compiler, ownership checker, machine lowering, and Linux runtime are written in Grail:

- `native.grl`: syntax, types, generic checking/specialization, ownership and word-machine emission.
- `ownership.grl`: loan/place graph and control-flow joins.
- `lexer.grl`: tokenization.
- `optimize.grl`: per-function slot forwarding, dead-code removal, register promotion and peepholes.
- `machine.grl`: direct ARM64 / RISC-V instruction selection from the internal word stream.
- `runtime.grl`: allocation, UTF-8, collections and process I/O; `os-linux.grl` / `os-windows.grl`
  provide the target's syscall or Win32 boundary.

There is no Rust seed or unchecked C compiler. Generated assembly bootstraps are the only
bootstrap inputs; the hash manifest records their source provenance and uncompressed contents.

## The `grail` tool

The compiler binary is also the project tool:

```sh
just install                  # grail -> ~/.local/bin, runtime/std -> ~/.local/lib/grail
grail new hello && cd hello   # grail.pkg, src/main.grl, tests/smoke.grl
grail check                   # type-check only (fast feedback, no assembler needed)
grail run                     # build target/hello and run it (arguments after --)
grail test                    # compile and run every program in tests/ (exit 0 = pass)
grail fmt                     # format every .grl file; grail fmt --check for CI
grail build --target aarch64  # cross-compile (x86_64, aarch64, riscv64)
grail add json https://example.org/json.git v1.0   # git dependency, pinned in grail.lock
grail fetch                   # re-fetch dependencies at the locked commits
```

A project is a directory with `grail.pkg` (`name NAME`, optional `entry PATH`, and
`dep NAME GIT-URL [REV]` lines). Its modules are all `.grl` files under `src/`, the `src/`
directories of fetched dependencies (`.grail/deps/NAME`) and the standard library. Dependencies
are cloned with git and their commits are recorded in `grail.lock`; `grail fetch` checks out
the locked commits. There is no registry yet. The runtime/standard library are found through
`GRAIL_HOME`, `PREFIX/lib/grail` next to an installed binary, or the source tree.

`grail fmt` produces the canonical layout: 4-space indentation, one statement per line, braces
on the header line, spaces around binary operators, struct/enum fields one per line, short struct
literals on one line, at most one blank line, comments preserved, and lines over 100 columns
broken at the outermost bracket with one argument per line (long strings/comments are kept).
Formatting is idempotent and does not change meaning: formatted compiler sources compile to
byte-identical assembly. It is a token-level pretty-printer, not yet an expression reflow engine
(e.g. it does not split long operator chains).

### Internal reference migration

Compiler and standard-library source use typed `&value` / `&mut value` references and
`&[u8]` / `&mut [u8]` byte views (named lifetimes precede `mut`). Internal numeric defaults
remain `u64`; user modules still default to `i64`.

For staged self-hosting, pass **both** `--default-u64 --typed-refs` when compiling the compiler
sources with a migration-capable compiler. The narrow `--typed-refs` switch changes reference
syntax independently of numeric defaults. Standard-library modules always use typed references.
The normal native and book regression corpus also enables `--typed-refs`, including safety
rejections; only deliberate removed-syntax rejection inputs retain the old spellings. Ordinary
user modules reject the removed dialect and still default to `i64`. A fixture requiring legacy
semantics must opt out with an explicit, explained `legacyRefs` marker.

Bootstrap artifacts are intentionally not refreshed by this migration. Until their scheduled
refresh, use a tree-built migration-capable compiler for development suites:

```sh
GRAIL_COMPILER=/path/to/tree-built/grail bun tools/test-native.mjs
GRAIL_COMPILER=/path/to/tree-built/grail bun tools/test-cli.mjs
GRAIL_COMPILER=/path/to/tree-built/grail bun tools/book.mjs check
```

The native runner also checks that `compiler/*.grl` and `lib/*.grl` contain no legacy
borrow calls or byte-view type spellings.

## Build

On Linux x86-64, ARM64 or RISC-V 64, install Bun, Clang (used **only as an assembler**) and LLD:

```sh
bun tools/native.mjs build
```

The printed path is the compiler executable. It self-compiles the Grail sources from the delivered
bootstrap. Normal compilation uses no Rust compiler, C source, C compiler backend, or LLVM IR.
The compiler writes assembly; assemble and link it with the corresponding tools:

```sh
GRAIL=$(bun tools/native.mjs build)
"$GRAIL" --target aarch64 hello.s book/examples/hello.grl compiler/runtime.grl
clang --target=aarch64-linux-gnu -c hello.s -o hello.o
ld.lld -m aarch64elf hello.o -o hello
```

Targets: `x86_64`, `aarch64`, `riscv64`. The default is the architecture the compiler itself was
built for. RV64 requires the integer multiply/divide and atomic extensions (RV64IMA), uses the LP64 ABI, and
needs `-march=rv64imafd -mabi=lp64` when assembling. These three target **Linux ELF**.

`--target windows-x86_64` selects the PE/COFF backend on the same x86-64 instruction stream, and
`--target windows-aarch64` selects the ARM64 PE/COFF backend through the shared AArch64 selector:
MSVC `.def` function records, a `grail_entry` PE entry point, Win64 import calls through
`raw_win32`, and COFF short-import libraries written by `tools/windows.mjs`, linked with
`lld-link`. Console, file, time, exit-code and argv programs run under Wine
(`bun tools/windows.mjs check`). The portable runtime is shared and the OS boundary selects
`compiler/os-linux.grl` or `compiler/os-windows.grl`. x86-64 frames get `.pdata`/`.xdata`
descriptions from `.seh_*` directives and ARM64 frames get full `.xdata` records from the ARM64
assembler (the packed form cannot encode a lone `x29/x30` save); neither has an exception
personality. Windows x86-64 has `CreateThread`/join and address waits; ARM64 threads, sockets,
directory streams and `mremap` are not implemented. See
[docs/design/windows-backend.md](../docs/design/windows-backend.md).
macOS and other operating systems are not implemented; sharing a CPU does not imply sharing an
executable format or syscall ABI.

## Checks and profiles

Ordinary `+`, `-`, `*`, `**` and their compound assignments check overflow by default, independently
of target. `--overflow=wrap` explicitly requests wrapping **user arithmetic**; bounds, ownership,
UTF-8 and runtime allocation/arithmetic guards remain enabled. `--overflow=checked` is explicit
default mode. Target and overflow options precede the output path. Explicit `wrapping_*` functions
remain available for local modular arithmetic without changing the entire application.

## Verification

```sh
bun tools/test-native.mjs x86_64
bun tools/test-native.mjs aarch64
bun tools/test-native.mjs riscv64
bun tools/bootstrap.mjs verify all
bun tools/book.mjs check
bun tools/book.mjs check --target=aarch64 --grail-only
```

Cross execution needs the matching `qemu-ARCH-static` executable (including `qemu-x86_64-static`
when cross-running x86-64 from another host), or an executable path in `GRAIL_QEMU_X86_64`,
`GRAIL_QEMU_AARCH64` or `GRAIL_QEMU_RISCV64`. Native hosts execute their own architecture directly.
The tooling preserves arguments as argv entries, validates targets, rejects failed compilation,
and checks that a rejected program cannot overwrite an existing output artifact.

`bun tools/bootstrap.mjs update all` regenerates bootstrap artifacts only after each compiled
compiler executes and reproduces its assembly byte-for-byte. ARM64 and RISC-V bootstraps are
compressed assembly, not opaque executables. Use `gzip -dc` to inspect them.

The regression corpus in `tests/native-cases.json` preserves checked language cases from the
retired independent implementation, supplemented by runtime/ownership/generic audits and all
book examples. Historical research records describe earlier compiler experiments, not supported
build paths.
