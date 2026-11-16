# Compile speed

Compile speed is the property Grail is meant to be chosen for: Rust's safety with a build that is
fast enough not to think about. This note is the record of what a build costs, what was found each
time it was measured, and the order the remaining work is in. Syntax serves review; this serves
everything else.

## The standing rule

**Checking a caller never requires another function's body** - only its signature or its interface
row. Every feature that reads a callee's body to check a call (an effect proof done whole-program, a
refinement that needs the callee's code, an inferred signature) puts a floor under incremental and
parallel builds that no later work can remove. Effects already obey it (the `effects` row of an
interface file); new features are reviewed against it.

## The benchmark

`bun tools/compile-bench.mjs` times the compiler, not the programs it builds. Every figure is the
best of three runs (the host is shared), and the results are written to `.work/compile-bench.json`.
`--quick` runs the two small scaling sizes and hello world. The gate runs the full form and records
the numbers (`tools/gate.sh`, leg `compile-bench`); it reports and does not yet refuse, because a
threshold on a shared host fails for reasons that are not the compiler's.

- **The scaling trio**: `grail check` on N copies of {a record, its constructor, a 15-line loop
  function} and a `main` that calls each, for N = 250, 1000 and 4000. The work per copy is constant,
  so the time should be linear in N; the tool prints `t4000 / t1000` and the fitted exponent.
- **Hello world**: `grail check` and `grail build`. This is the fixed cost: the runtime, the platform
  module and `core` are compiled from source every time.
- **Generic-heavy**: 100 generic functions, each instantiated at 20 record types (2,000
  specialisations in 3,264 lines).
- **Self-compile**: the compiler compiling its own sources to assembly.

## Stage 1: what the profile showed, and what it bought

Measured on one host, best of three, before (`7970f1d`) and after:

| | before | after | |
| --- | --- | --- | --- |
| check, N = 250 (6.5k lines) | 3.54 s | 1.39 s | 2.5x |
| check, N = 1000 (26k lines) | 16.68 s | 3.99 s | 4.2x |
| check, N = 4000 (104k lines) | 165.9 s (a reviewer's run of the same shape, 88k lines) | 18.03 s | 9.2x |
| `t4000 / t1000` | about 10 | 4.52 | linear is 4 |
| check hello | 1.19 s | 0.59 s | 2.0x |
| build hello | 1.32 s | 0.72 s | 1.8x |
| check generic (2,000 specialisations) | refused: the limit was 1,024 | 6.97 s | |
| self-compile (80k lines) | 73.8 s | 41.6 s | 1.8x |

No language change and no change to what the compiler emits: the self-compile is byte-identical
before and after each step (`tools/test-selfhost.mjs`).

The profile was read two ways - `grail profile` on the compiler process itself (leaf samples) and
`valgrind --tool=callgrind` with the addresses mapped back through the binary's symbol table
(inclusive cost, which is what names the caller of an allocation). What it showed, largest first:

1. **Name lookup was a scan that allocated.** `find_func` compared every function in the program
   with the name it wanted, building two views per comparison: 39 % of all instructions at N = 250
   and growing with the square of the declaration count. Functions, types, specialisations and the
   "has this drop helper / specialisation been emitted" sets now have an open-addressed index beside
   the table (`name_key`, `index_add`). The index is brought up to date by the lookup itself, so the
   dozen places that push to a table did not change. At N = 1000 the drop-helper set alone had become
   39 % of the run once the function scan was gone: the same shape, one level down.
2. **The 1,024-specialisation limit.** It existed to stop a generic that instantiates itself at an
   ever larger type; with a scan behind it, it was also a ceiling on honest programs. The lookup is
   hashed and the limit is 65,536.
3. **Every specialisation re-read and re-tokenised its file.** `load_file` read the source from disk
   and ran the lexer each time a body was replayed. The loaded file stays loaded and earlier files
   come back from a cache: the generic benchmark went from 34.5 s to 7.7 s on this alone.
4. **The allocator lock.** An atomic exchange and release around every allocation and free, in a
   process with one thread: a tenth of the run. The lock is not taken until the process starts its
   second thread (`rt_thread_start` sets state word 3416 first).
5. **Keyword tests copied the token.** `is("while")` copied the current token out of the source to
   compare it - four allocations a question, asked for every keyword at every statement.
6. **The optimiser built a record per comparison.** `same(span_of(s, a, e), w)` made a `Span` to
   compare a few bytes; `ir::same_range` compares in place and answers the same thing.
7. **A declaration's position was counted from the top of the file each time** (`position_text`); it
   now counts on from the previous declaration, as the error-site table already did.

## What is left, and why it is not a stage 1 fix

After stage 1 the allocator is still about 40 % of a build, and it is no longer one caller's fault.
A byte view (`&[u8]`) is a heap record: `view(x)` allocates one, and handing a view on to another
function allocates another, so a function that takes a name and passes it to a helper pays an
allocation and a free per hop. The compiler is written in that idiom throughout
(`same(view(a), view(b))`), and the optimiser reads assembly text line by line through views. No
index removes that; the value representation does. That is stage 3.

The optimiser is the other half of a small build (48 % of hello world): it parses the assembly text
the front end wrote, and then clang parses what it writes. That is stage 4.

## The order of the remaining work

2. **A precompiled runtime, platform module and `core`** - object plus interface, shipped with the
   toolchain - so hello world stops paying for 7.5k lines each time. Target: `build hello` at or
   under 0.3 s.
3. **Unboxed views, records, tuples and options.** Views first: they are the allocation volume
   measured above. The one-word value assumption runs through the optimiser and every backend, so
   this has a design note of its own before any code, and a reseed per sub-stage.
5a. **Independent module compiles in parallel from the driver** (the per-module build and its cache
   exist; this is scheduling).
4. **Direct object emission**, so 100 MB of assembly text is not written, re-parsed by the optimiser
   and parsed again by clang.
5b. **Parallel body checking**: split the compiler context into read-only program-wide tables and
   per-function state, check and lower bodies on worker threads, merge in a fixed order so the
   byte-for-byte self-compile check survives.
6. **Shared generic bodies in debug builds**, decided against the generic-heavy number above and
   after stage 3, because a shared body over unboxed values needs layout passed in.

Targets after 3, 4 and 5a: self-compile at or under 10 s. That one is a target until stage 3's design
note exists.
