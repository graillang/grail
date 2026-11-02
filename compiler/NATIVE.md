# Direct native backend — Linux x86-64

`native.grl` emits GNU assembler syntax directly from Grail source. Grail function bodies do
not go through C, LLVM, a JIT or an interpreter. GNU `as` encodes the instructions; the system
linker supplies executable startup and libc. The backend is written in Grail and compiles itself.

## Build without Rust or the C backend

The committed `bootstrap/native.s` is the assembly generated from `native.grl` and `lexer.grl`.
Only the runtime support object is compiled from C (once):

```sh
mkdir -p seed/.work/native
W=seed/.work/native
cc -O1 -DGRAIL_NATIVE_RUNTIME -c compiler/grail_rt.c -o $W/runtime.o
as --64 compiler/bootstrap/native.s -o $W/bootstrap.o
cc $W/bootstrap.o $W/runtime.o -o $W/native
$W/native $W/stage2.s compiler/native.grl compiler/lexer.grl
as --64 $W/stage2.s -o $W/stage2.o
cc $W/stage2.o $W/runtime.o -o $W/stage2
$W/stage2 $W/stage3.s compiler/native.grl compiler/lexer.grl
cmp $W/stage2.s $W/stage3.s
cmp $W/stage2.s compiler/bootstrap/native.s
```

Compile an application:

```sh
$W/native $W/example.s compiler/examples/native_numbers.grl
as --64 $W/example.s -o $W/example.o
cc $W/example.o $W/runtime.o -o $W/example
$W/example  # 171
```

Invocation: `native OUT.s ENTRY.grl [MODULE.grl...]`. All modules are supplied as source files.
The first public function of the entry module takes no parameters or one argv byte view and
returns `num`. An argv entry with an incorrect argument count exits with status 2.

Alternatively, build with the Rust seed just like `grailc.grl` (publish `host`, compile `lexer`,
build `native`), or compile both Grail modules with the existing C bootstrap.

## Implementation boundary

- System V AMD64 calling convention, up to six one-word parameters, one-word result in `rax`.
- Each local/temporary gets its own stack slot; frames are 16-byte aligned at calls. No register
  allocator or optimization pipeline. Return uses `leave; ret`; recursion works.
- Explicit branch labels for conditionals, loops, break/continue, and enum matches.
- Wrapping u64 arithmetic and unsigned comparisons/remainder; zero remainder divisors abort.
- Operands and call arguments are evaluated left to right, with snapshots before later operands.
- Record fields, enum payloads, typed references, vectors, strings and views use the same uniform
  one-word value ABI as the C bootstrap. Type-directed loads/addressing lower to native instructions.
- Allocation, sequences, byte/text operations and host I/O call a separately compiled support
  runtime. libc is still used. A C runtime is not C compilation of Grail function bodies.

**Not v1 yet:** no ownership checking, no freeing, no general generic functions/types other than
`vec<T>`, no implicit modules, no portable targets or optimizer. This is the shortest independent
native-codegen path to the existing self-hosting subset, not a safety or performance claim.
Inputs should still be checked by the Rust seed. The C backend remains available as a bootstrap
and cross-check, not as an intermediate in this native path.

## Verification and artifact regeneration

```sh
cargo test --manifest-path seed/Cargo.toml --offline --test native_codegen -- --ignored
```

The test builds the backend with both the seed and the C bootstrap, compares emitted assembly,
checks native stage-2/stage-3 equality and the committed artifact, executes differential programs
and abort cases, and uses a native-built C backend to reproduce the existing C bootstrap. To
regenerate `bootstrap/native.s`, copy a fresh stage-2 assembly output after editing `native.grl`
or `lexer.grl`; the test rejects stale artifacts.
