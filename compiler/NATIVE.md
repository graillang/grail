# Direct native compiler — Linux x86-64, ARM64 and RISC-V 64

`native.grl` checks Grail source and emits a closed word-machine stream. `machine.grl` performs
static target instruction selection for ARM64 and RISC-V; x86-64 retains the stream's original
register spelling. This is direct native compilation: no C source, LLVM IR, JIT or interpreter.
The compiler, checker, lowering and trusted runtime are all Grail. An assembler and linker encode
instructions and produce static Linux ELF executables; no libc is linked.

See [README.md](README.md) for seed-free builds and cross execution. Generated bootstraps exist
for all three CPUs and are accepted only after execution and byte-for-byte self-compilation.
The Rust seed and unchecked C compiler have been removed, not retained as alternative build routes.

## Invocation and entry

Invocation: `native [--target x86_64|aarch64|riscv64] [--overflow=checked|wrap] OUT.s ENTRY.grl [MODULE.grl...]`. All modules are supplied as source files, including `compiler/runtime.grl` last.
A named `main` in the entry file takes priority and needs no `pub`. Its result defaults to
`unit`, with an implicit return at the end. The entry file may omit its `module` declaration;
dependency files still declare their modules explicitly.

```grl
fn main() {
    println("Hello, world!");
}
```

`print(value)` and `println(value)` are builtin prelude operations for `u64`, strings, byte owners
and byte views; `println()` emits an empty line. Text/buffer output takes a checked readonly borrow
for the call, does not consume the owner, and releases temporary views with normal cleanup.
There is no formatting/interpolation or general display trait. The names `print`/`println` are
reserved. Ordinary unit-returning functions may also omit the result annotation and final return.

Named `main` never prints its return value. Unit main exits with status 0; explicit `->u64`
sets the OS exit status (low eight bits on Linux). A main may accept one readonly argv view;
an incorrect argument count exits with status 2. All cleanup and zero-live-allocation checks still
run before normal process exit.

Existing bootstrap/regression sources without named main retain their first-public-function
entry protocol: zero parameters or one argv view, explicit `u64` result, printed by the legacy
numeric harness. This is not the recommended application entry convention.

## Implementation boundary

| Target | Argument registers (up to six word values) | Result | Runtime |
| --- | --- | --- | --- |
| x86-64 | rdi, rsi, rdx, rcx, r8, r9 | rax | Linux syscall ABI |
| ARM64 | x0–x5 | x0 | Linux AArch64 syscall ABI |
| RISC-V 64 | a0–a5 | a0 | Linux RV64 syscall ABI, RV64IMA / LP64 |

- Uniform one-word value representation and eight-byte local slots; calls have 16-byte-aligned
  frames and architecture-specific return-address/callee-save handling. Recursion works.
- Target lowering preserves unsigned comparison, carry/borrow overflow checks, byte accesses,
  division/remainder, long branches, address relocation and frame constants. Unsupported emitted
  operations fail instead of silently dropping instructions.
- Typed references, generic layouts, records, enums, vectors, text and views share the same checked
  language semantics on each target. `optimize.grl` rewrites each function's word stream before
  target lowering (see *Optimization* below); there is no general register allocator.
- Allocation, UTF-8, collection operations, numeric printing, arguments/environment, file I/O,
  PATH search and process commands are implemented in `runtime.grl`. Its syscall-operation boundary
  maps to native Linux numbers, including openat and clone where open/fork syscalls do not exist.
- Raw memory, mapping and native syscalls are confined to `unsafe module runtime`; safe modules
  cannot call its raw functions or intrinsics. Raw native syscall numbers are architecture-specific;
  portable runtime code calls `rt_syscall` instead. This trusted boundary is not a memory-safety proof.
- Runtime allocation guards, checked size arithmetic, bounds checks and UTF-8 validation remain
  enabled under user `--overflow=wrap` mode. Large allocation unmapping is verified with mincore.
- These are **Linux ports**, not macOS/Windows ports. Other executable formats and OS APIs need
  separate implementations, regardless of CPU architecture.

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

Declarations use `name := value` for immutable bindings and `mut name = value` for mutable
bindings; `=` only assigns an existing mutable binding. Owned mutation or mutable borrowing
requires `mut`, while a fixed explicit mutable reference/view may use its referent capability.
Parameters are fixed bindings; a by-value owner can be moved into a mutable local. `let` and `var` are not declaration keywords.

Unsigned arithmetic includes `/`, `%`, right-associative `**`, and numeric compound assignments
`+=`, `-=`, `*=`, `/=`, `%=` and `**=`. Addition, subtraction, multiplication and powers abort on
overflow/underflow by default on every target; `0 ** 0` is 1. Explicit `wrapping_add(a,b)`,
`wrapping_sub(a,b)`, `wrapping_mul(a,b)` and `wrapping_pow(a,b)` compute modulo 2⁶⁴. Their numeric
arguments run once, left to right.
Division/remainder by zero abort. `^` remains XOR. Compound targets must be initialized numeric
storage; the target stays valid while the right-hand side runs once, and conflicting mutation
is rejected. Power policy is implemented in the Grail runtime, not handwritten assembly.

Generic functions use a specialization worklist and body replay. Unused templates are checked
with opaque affine type variables; specializing to `u64` does not make `T` copyable or numeric.
Calls infer type arguments or accept explicit `identity<u64>(...)` forms, including cross-module
calls and regular recursion. Expanding polymorphic recursion is bounded. Generic records/enums
support nested/borrowed type arguments, constructor inference and specialized recursive drops.
Lifetimes precede `T` parameters in declarations.

Captured storage supports assignment, `exchange`, generic `replace<T>`, vector push/pop and
caller-side writeback. External writes are checked against declared data-lifetime bounds; weak
updates retain historical guards across control-flow joins. Opaque writes with retained local
frame witnesses propagate incoming guards into every possible frame owner, not just the temporary
reference. **Conservative limit:** opaque external-frame writes without a recoverable invariant
contract are rejected. Whole-frame guards and weak updates may retain borrows longer than needed.
This is not a soundness proof; the explicitly unsafe runtime is trusted.

## Optimization

`optimize.grl` runs on every function of the x86-64-spelled word stream before `machine.grl`
lowers it, so all three targets share it. It is not a general optimizing middle end. Per function:

- forwards frame-slot values already held in a register or known constant within a basic block,
  folds small constants into instructions and propagates register copies;
- removes stores to slots that are never read and register definitions that are dead under
  function-wide liveness; `jcc L; call rt_abort; L:` checks are transparent because `rt_abort`
  never returns;
- promotes the hottest non-escaping slots (weighted by loop depth) into the callee-saved registers
  (rbx, r12–r15 / x19–x23 / s1–s5), saved below the frame and restored before each `leave`;
- fuses `set/test/branch` sequences, replaces division by a power-of-two constant with shift/mask,
  expands the leaf runtime accessors `rt_slot`, `rt_at`, `rt_atb`, `rt_len` and `rt_xchg` inline,
  inlines the fast path of `push` (a runtime call only grows the buffer), and compacts the frame to
  the slots still referenced; small frames are cleared with direct stores instead of `rep stosq`;
- inlines small leaf functions (no calls but `rt_abort`, no callee-saved registers, at most 24
  instructions): their slots move to free scratch registers and each call site gets a copy with
  its own labels. The function itself is still emitted for indirect calls.

The compiler also emits sized-integer comparisons, `& | ^`, checked `+ - *` (8–32 bit, and `+ -` on
`i64`) and division/remainder inline instead of calling `rt_int`, and drops the bounds check of
`v[i]` inside `for i in a..v.len()` / `for i in v.len()` when the body names `v` only as `v[..]` or
`v.len()` and never redeclares `i` or `v`.

Functions whose prologue, epilogue or frame accesses it does not recognize are copied unchanged.
Self-compilation must still reproduce its own assembly byte for byte. There is no loop-invariant
motion, vectorization or instruction scheduling.

## Storage

`u8[]`, `string` and byte views store one byte per element (`rt_pushb`, `rt_atb`, `rt_popb`,
byte-offset views and slices); `T[]` stores eight-byte words. Allocations from fresh arena
memory are not re-zeroed, and blocks of at least 512 KiB grow in place with `mremap`.

Failed assertions and guards abort without unwinding.
`--overflow=wrap` opts user arithmetic into modulo 2⁶⁴, including powers and compound assignments;
checked runtime arithmetic, bounds, UTF-8 and ownership checks remain enabled.

## Verification and artifact regeneration

```sh
bun tools/test-native.mjs x86_64
bun tools/test-native.mjs aarch64
bun tools/test-native.mjs riscv64
bun tools/bootstrap.mjs verify all
bun tools/book.mjs check
```

Cross execution uses QEMU user emulation when the target differs from the host. Tests preserve
existing output on rejection, execute runtime/ownership/generic audits, check guarded failure and
both arithmetic policies, and compare target self-compilation output byte-for-byte. To regenerate
bootstraps, run `bun tools/bootstrap.mjs update all`; failed checks do not replace an artifact.
`manifest.json` records uncompressed bootstrap SHA-256 hashes and Grail source provenance.

## Borrowing and byte indexing syntax

Use `mut name = value` for mutable declarations and `name := value` for fixed bindings.
`&value` creates a readonly byte view; `&mut value` creates an exclusive writable byte view.
The latter requires mutable owned storage or an existing writable capability. Prefix borrowing
binds tighter than binary operators, including bitwise `&`; postfix indexing binds tighter still.
Typed storage references remain `borrow(value)` / `borrow_mut(value)`.

Byte buffers, strings and views support `value[index]` and readonly `value[start:end]` slices.
Either slice bound may be omitted. Indexing implicitly borrows its source readonly and retains
normal lifetime, conflict and bounds checks; a slice is not an owning copy. Bounds run once,
left to right. String u8[] cannot be mutably borrowed. Vectors use the same `v[i]` syntax: numeric elements copy, while non-numeric elements remain
borrowed. `&v[i]` and `&mut v[i]` explicitly borrow element slots. Byte writes use `write` through
a writable view.

The old `var` declaration and `read(...)`, `mut(...)`, `at(...)`, `slice(...)` builtins are removed.
Lifetime-bearing byte-view types remain `read<a>` and `mut<a>`; this change replaces expression
syntax, not the type system.

## Collection expressions and generic parameters

Collection literals are `u8[10, 20, 30]` and `T[...]` (empty forms use `[]`). Use postfix
`.push(value)`, `.pop()`, `.len()`, `.copy()` and `.text()`; strings append with `.append(source)`.
Free collection helper spellings and constructor parentheses are removed. `.pop()` aborts on an
empty collection, unlike Rust's Option-returning pop. Generic user functions and types are checked and specialized by the Grail-written compiler.

`true` and `false` are reserved numeric truth literals (one and zero). Generic type parameters
are uppercase names without a `type` keyword, e.g. `fn identity<T>` and `fn replace<a,T>`;
lowercase names are lifetimes, which precede type parameters. Existing universal checking remains.

## Callable and concurrency foundations

Typed capture-free function values, structural `Send`/`Share` bounds and opaque `atomic<u64>`
are implemented in the sole compiler, including cross-target lowering. See
[callables and transfer](../docs/design/callables-and-transfer.md) for syntax and restrictions.
These foundations do **not** yet provide capturing closures, worker scheduling, task scopes,
cancellation or colourless readiness I/O; those remain in progress.

Explicit static user-defined interfaces and concrete implementations share the bound syntax with
structural capabilities. See [interfaces](../docs/design/interfaces.md) for dispatch, coherence and
current restrictions; generic interfaces, associated types and dynamic objects are not implemented.

Real worker threads (`parallel_map`), `mutex<T>`, hash maps and a sharded concurrent map are
described with their limits in [structured parallelism](../docs/design/structured-parallelism.md).

Sized integers, `bool`, the full operator set and capturing closures are described in
[integers](../docs/design/integers.md) and [closures](../docs/design/closures.md).
