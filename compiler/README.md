# The Grail compiler

The compiler, ownership checker, machine lowering, and Linux runtime are written in Grail:

- `native.grl`: syntax, types, generic checking/specialization, ownership and word-machine emission.
- `ownership.grl`: loan/place graph and control-flow joins.
- `lexer.grl`: tokenization.
- `machine.grl`: direct ARM64 / RISC-V instruction selection from the internal word stream.
- `runtime.grl`: allocation, UTF-8, collections, process I/O and the Linux syscall boundary.

There is no Rust seed or unchecked C compiler. Generated assembly bootstraps are the only
bootstrap inputs; the hash manifest records their source provenance and uncompressed contents.

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
needs `-march=rv64ima -mabi=lp64` when assembling. All three currently target **Linux ELF**.
macOS, Windows and other operating systems are not implemented; sharing a CPU does not imply
sharing an executable format or syscall ABI.

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
