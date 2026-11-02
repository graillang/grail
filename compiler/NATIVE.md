# Direct native backend — Linux x86-64

`native.grl` emits GNU assembler syntax directly from Grail source. Grail function bodies do
not go through C, LLVM, a JIT or an interpreter. GNU `as` encodes the instructions; the system
linker produces a static executable with a generated `_start`. There is no libc dependency. The backend is written in Grail and compiles itself.

## Build without Rust or the C backend

The committed `bootstrap/native.s` is generated from `native.grl`, `lexer.grl`, `ownership.grl` and the
Grail-written `runtime.grl`. No support object, C compiler, libc or handwritten assembly runtime
is required:

```sh
mkdir -p seed/.work/native
W=seed/.work/native
as --64 compiler/bootstrap/native.s -o $W/bootstrap.o
ld $W/bootstrap.o -o $W/native
$W/native $W/stage2.s compiler/native.grl compiler/lexer.grl compiler/ownership.grl compiler/runtime.grl
as --64 $W/stage2.s -o $W/stage2.o
ld $W/stage2.o -o $W/stage2
$W/stage2 $W/stage3.s compiler/native.grl compiler/lexer.grl compiler/ownership.grl compiler/runtime.grl
cmp $W/stage2.s $W/stage3.s
cmp $W/stage2.s compiler/bootstrap/native.s
```

Compile an application:

```sh
$W/native $W/example.s compiler/examples/native_numbers.grl compiler/runtime.grl
as --64 $W/example.s -o $W/example.o
ld $W/example.o -o $W/example
$W/example  # 171
```

Invocation: `native OUT.s ENTRY.grl [MODULE.grl...]`. All modules are supplied as source files, including `compiler/runtime.grl` last.
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
- Allocation, sequences, byte/text operations, file I/O, PATH search, process execution and numeric
  printing are implemented in `runtime.grl`. Its explicit `unsafe module runtime` can use raw
  load/store/byte, mapping, process-state and syscall intrinsics. Ordinary modules cannot invoke
  raw intrinsics. This is the trusted runtime boundary, not proof of runtime memory safety.
- The allocator caches mapped arenas, reuses freed blocks by size class, checks double-free state,
  counts live allocations, immediately unmaps single-object large arenas, and unmaps cached slabs
  at shutdown. `runtime_audit.grl` checks reuse and a
  balanced live count after 1,000 allocation/descriptor/free cycles and command execution. `mincore` also verifies that freeing a large allocation really removes
  its mapping.

## Ownership and cleanup checkpoint

Move/initialization checks reject use after move/drop, conditional use of possibly moved storage,
repeating-edge consumption and uninitialized owned values. Type checks preserve lifetime arguments
and shared/mutable modes, and validate argument/return/field shapes. `ownership.grl` also has a
field/loan graph tested independently for disjoint borrowing, reborrow authority and branch joins.

Owned values have runtime live flags. Generated destructors recursively release records, active
enum payloads and vector elements; moves clear source flags/fields. Lexical exits, returns, `?`,
`break` and `continue` perform guarded cleanup. The entry shim checks `rt_live()==0` after program
cleanup and numeric printing, before unmapping cached arenas. This check runs during native
self-compilation as well as application tests. Abort paths do not unwind.

Source-level loans and return-lifetime checks are now connected: live shared/unique borrows
exclude conflicting moves and writes; last-use ending respects lexical scopes, shadows and loop
backedges. Lifetime guards retain captured origins separately from access capabilities. Opaque
reference returns conservatively retain whole input frames, so interior projections cannot free or
replace a still-borrowed object. Unsafe programs fail before replacing an existing output file.

Generic functions use a specialization worklist and body replay. Unused templates are checked
with opaque affine type variables; specializing to `num` does not make `T` copyable or numeric.
Calls infer type arguments or accept explicit `identity<num>(...)` forms, including cross-module
calls and regular recursion. Expanding polymorphic recursion is bounded. Generic records/enums
support nested/borrowed type arguments, constructor inference and specialized recursive drops.
Lifetimes precede `type T` parameters in declarations.

Captured storage supports assignment, `exchange`, generic `replace<T>`, vector push/pop and
caller-side writeback. External writes are checked against declared data-lifetime bounds; weak
updates retain historical guards across control-flow joins. Opaque writes with retained local
frame witnesses propagate incoming guards into every possible frame owner, not just the temporary
reference. **Conservative limit:** opaque external-frame writes without a recoverable invariant
contract are rejected. Whole-frame guards and weak updates may retain borrows longer than needed.
This is not a soundness proof or full Rust-seed parity; the explicitly unsafe runtime is trusted.

There is no optimizer, portable target, or implicit-module support. Panic/failed assertions abort
without unwinding. Older C bootstrap files remain only as an independent recovery/cross-check route;
the native build does not use them.

## Verification and artifact regeneration

```sh
cargo test --manifest-path seed/Cargo.toml --offline --test native_codegen -- --ignored
```

The test builds the backend with both the seed and the C bootstrap, compares emitted assembly,
checks native stage-2/stage-3 equality and the committed artifact, executes differential programs
and abort cases, and uses a native-built C backend to reproduce the existing C bootstrap. To
regenerate `bootstrap/native.s`, copy a fresh stage-2 assembly output after editing `native.grl`,
`lexer.grl`, `ownership.grl` or `runtime.grl`; the test rejects stale artifacts.
