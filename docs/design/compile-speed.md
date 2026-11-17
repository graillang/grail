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

Effect claims used to break it: a program in which any function claimed `@no_alloc` or `@no_panic`
was built in one compiler run, because the proof walked every body the claim could reach. Now each
run proves its claims against the summaries of the functions it calls - computed facts carried in
every interface, and `runtime.facts` for the runtime (`docs/design/effects.md`, *Summaries*) - so a
claiming program builds per module and through the store like any other, and the standard library
claims effects where its bodies earn them.

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

## Stage 2: the build store is the default, and it is per user

Stage 2 was written down as "a precompiled runtime, platform module and `core`, shipped with the
toolchain". Measuring first changed its shape: the per-module store `grail build --cache` already
had (`docs/design/incremental-compilation.md`) does exactly this - one compiler run and one object
per module, reused when nothing they are a function of moved - and it was off by default and
private to each project. So stage 2 is two switches and one key:

- **`grail build` and `grail run` go through the store by default** on the Linux targets.
  `--no-cache` is the whole-program build; a build that is one compiler run by nature (`--debug`,
  `--split`, `--whole-program`, `--interface`, `--emit-ir`, `--watch`) is unchanged. The default
  build prints no cache line; `--cache` still prints its one-line report.
- **The store is per user, not per project**: `GRAIL_CACHE_DIR`, else `$GRAIL_HOME/cache/build`,
  else `$XDG_CACHE_HOME/grail/build`, else `$HOME/.cache/grail/build`. Every key already named the
  compiler's own digest, the target, the flag vector and the digest of each input, so two projects
  share exactly the entries that are the same work. The runtime, the platform module, `core` and
  `result` are the same work for every program, which is what "shipped with the toolchain" was
  for: the first build on a machine fills them in, and every project after that links them.
- **A module's key also names its source path.** The object carries the path (a runtime error's
  location), so the same text at another path is another object. Inside one project that could not
  happen; between projects it can.

Measured (best of three, each run in an empty store of its own):

| hello world | before | after |
| --- | --- | --- |
| `build`, first on this machine | 0.72 s | 0.93 s |
| `build` after an edit | 0.72 s | 0.15 s |
| `build`, first build of another project | 0.72 s | 0.15 s |
| `build`, nothing changed | 0.72 s | 0.07 s |
| `build --no-cache` | 0.72 s | 0.73 s |

The first build on a machine is slower than it was - four compiler runs instead of one - and that
is the one build the store cannot help. What the default costs at run time was measured too,
because a per-module build does not inline across modules: `bench/` built both ways runs the same
(fnv 0.97, sieve 0.98, sort 1.00, nbody 0.99 as per-module time over whole-program time; the hot
accessors are emitted inline by the front end, not by the cross-module inliner).

Not done here: `grail check` still checks the runtime, the platform module and `core` from source
every time (0.59 s for hello world). It can read their interfaces from the same store instead.

## Stage 3 began with a measurement: what the instructions are spent on

Counted with callgrind, the compiler executed about 1.9 million machine instructions per source
line on the scaling benchmark and 3.1 million per line on its own sources. A fast compiler spends
thousands. So the next changes were chosen by multiplier, largest first, and each is recorded with
what it bought.

### The compiler that is shipped is built by the optimising backend (3.4x to 6.9x)

The compiler was built by its own native backend, which writes naive code quickly: every value in a
stack slot. The allocator's fast path was 326 instructions. `bun tools/native.mjs release` builds
the same sources through `--backend=llvm` and `clang -O2`, and accepts the result only if it emits,
for the compiler's own sources, byte for byte what the natively built compiler emits. Nothing in
the source changed. The tests keep running the natively built compiler - it is the product of the
backend they exist to test - and `compile-bench --release` measures the one a user runs.

### `grail check` stops when the last diagnostic can have been given (about 2x on a check)

A check ran the whole compiler and threw the assembly away. Every diagnostic is given by the passes
over the source (the effect report included), so `--check` returns after them: no optimiser, no
location table, nothing written.

### A view of a whole vector is the vector's header (7 in 10 allocations gone)

`view(x)` allocated a two-word record holding what the vector's header already starts with, and
6.8 million of the benchmark's 10.1 million allocations were that. A view of a whole vector is now
the header itself. A view of part of one still has a record, and the two are told apart when a view
is dropped by the address alone: a record is the second word onward of a 32-byte block, so it sits
8 past a multiple of 16, where no block and no static object starts (`rt_view_record`,
`rt_view_free`). Nothing is read to decide, so a view may be dropped after the vector it came from.

### Positions are looked up, not counted (a `--debug` compile: 11.3 s to 2.2 s on 26k lines)

Tokens carry their line and column from the moment the file is read. A debug row, a runtime-error
site and a diagnostic each rescanned the source from the top.

### The borrow checker's questions cost what they ask about (self-check 18.5 s to 7.1 s)

- "This place and everything inside it" walked every place the function had made; places now link
  to their fields, and the walk is the subtree.
- The record of a value was found by scanning the function's records backwards; the latest record
  of each slot is remembered.
- A type was interned by comparing it with every type in the program; the table is hashed.
- The lifetimes a type can carry and whether it holds a borrow were recomputed at every call by
  walking the type's fields, recursively - for the compiler's own 450-field context, at every call
  that passes it. Both are remembered per type until a declaration is added.

A function of 4,000 statements is linear again: the 104k-line benchmark is 4.2x the 26k-line one.

### The optimiser runs in forked workers

The optimiser is a pass over assembly text, one function at a time. The stream is cut between
functions into one piece per processor, each piece is optimised by a forked copy of the compiler
(`host::fork`, Linux), and the pieces come back through pipes in order. The copies share the
parent's memory until they write, so nothing is passed to them. The output is the same text
whatever the number of workers, because the one thing that depended on the functions before -
the numbering of the optimiser's own labels - now depends only on where a function stands in its
unit (`ir::function_begin`). `GRAIL_JOBS=1` keeps it in one process.

What is still one process after it: the front end, the location table and the merge. The inlining
pass no longer scans the stream: the workers note where the call lines of their pieces are, and the
pass visits those.

### Modules compile at the same time

`grail build` runs one compiler process per module and starts each as soon as the modules it reads
are finished; what the build records - objects, link inputs, the cache report - is still taken in
the order a build of one module at a time takes it, so the image does not depend on the scheduling.
A module's cache key names only the interfaces it can read (its dependencies and theirs), which is
also what makes the key the same from one build to the next. 90k lines in 24 modules: 16.9 s one at
a time, 4.0 s together, on the natively built compiler.

### An optimised body is remembered

What the optimiser makes of a body is a function of the body's lines, its facts and its place in
its unit. With a build store the result is filed under a hash of those, so a body that has not
changed since some earlier build is not optimised again. It removes CPU time, not much wall time,
now that the optimiser is spread over every core: what an edit costs is the front end.

### Where that leaves the numbers

Release compiler, best of three, one 24-core host; "baseline" is the tree before any of this.

| | baseline | now |
| --- | --- | --- |
| check hello | 1.12 s | 0.037 s |
| check, N = 1000 (26k lines) | 16.7 s | 0.22 s |
| check, N = 4000 (104k lines) | 165.9 s | 0.91 s |
| `t4000 / t1000` | about 10 | 4.16 |
| check generic (2,000 specialisations) | refused | 0.26 s |
| self-compile (80k lines) | 73.8 s | 2.86 s |
| build, 90k lines in 24 modules, cold | - | 1.36 s |
| build hello after an edit | 1.25 s | 0.14 s |

The natively built compiler, which the tests run, self-compiles in 12.6 s and checks itself in 7.0 s.

### What a build still costs, and what is being done about it

- **An edit recompiles its module's front end.** The per-function cache exists and reuses almost
  nothing: a body is not filed when it registers a drop helper or a specialisation, and its key
  names the line and the label numbers it starts at, so an edit above it is a miss. Making units
  position-independent and their registrations replayable is the next piece of work.
- **The front end is one process.** Bodies are independent once signatures are known; the plan is
  the same as the optimiser's - forked workers over pieces of the declaration list - and it needs
  the same thing first: labels that do not depend on the bodies before.
- **Allocation is still about a third of the front end**: accessors that copy a type's argument
  list, a heap record per value. That is the unboxed-values work (docs/design/unboxed-values.md).
- **The assembler and the linker** are most of a small edit's 0.14 s.

### An edit to one function compiles one function

After an edit to one body, every other body of the module is replayed from the build store's unit
layer rather than checked and emitted again (`docs/design/incremental-compilation.md`, "Below the
module"): a body's assembly no longer depends on the bodies before it - labels are numbered per
function, positions count from the function's first line - and a stored body records the drop
helpers and specialisations it asks the build for. On the compiler's own sources that is 2,707 of
2,708 unit bodies replayed after a one-body edit (it was 927, or 711 when the edit added a line),
and the rebuild takes about half the time of one with no store (6.9 s against 13.5 s on a shared
host; 13.8 against 25.7 CPU seconds in one process). On syn1000 through `grail build`, 1,999 of
2,000 bodies replay where none did, 2.7 s to 2.0 s.

What an all-hit rebuild still pays is the back end's whole-stream work - the optimiser's line scan
over text whose every body is a memo hit, the inline pass's index, the site table - and the
assembler; the front end has left the profile's top ten. That is the argument for stages 4 and 5b
below: units are already values that are produced and applied separately, which is what workers
compiling the bodies that miss need.

## Against Go, Zig and rustc

The bar, since 2026-11-16: **the fastest of Go, Zig and rustc on equivalent programs**, checking
and building, cold and after a one-function edit.

`bun tools/compile-rivals.mjs [--runs N] [--sizes 1000,4000]` writes the same programs in all four
languages: hello world, and the scaling trio of `tools/compile-bench.mjs` (N copies of a record,
its constructor and a 15-line loop function, and a `main` calling each) at N = 1000 and 4000. All
four print the same number. Each is timed four ways:

| step | Grail | Go | Zig | Rust |
| --- | --- | --- | --- | --- |
| check | `grail check main.grl` | `go build -o /dev/null .` | `zig build-exe -fno-emit-bin main.zig` | `cargo check` |
| build | `grail build main.grl` (the build store) | `go build -o syn .` | `zig build-exe -O Debug main.zig` | `cargo build` (the dev profile) |

Go has no check. `go vet` runs analyses, not the type checker's verdict, so Go's check is a build
whose output is thrown away. Zig 0.14's Debug build uses LLVM by default. Its own x86 backend
(`-fno-llvm -fno-lld`, the default from 0.15) was no faster on syn4000 here (7.3 CPU s against
6.9, single runs), so the table keeps the default.

"Cold" is a project's first build on a machine whose toolchain caches are warm. Each cold run has
new source text (a seed in `main`) and empty project caches: a new `target/` for cargo, and for
Grail a new build store holding only what a hello-world build put there (the runtime, platform
module and `core`, which the other toolchains ship precompiled). Go keeps its standard library in
GOCACHE and Zig its compiler_rt in its global cache. "Edited" is the same step again after one
function body changed (`% 1000` to `% 1001` in `work{N/2}`; hello world's string), reusing what the
cold step left: cargo's incremental state, Grail's store, Go's and Zig's caches. The figure is CPU
seconds (user + sys of the tool and every process it waited for, `tools/rivals/measure.c`), best of
three, with wall seconds beside it.

Measured 2026-11-16 on 24 cores, load average about 22. The compiler is the release compiler
(`bun tools/native.mjs release`, `gaps13-int` db2d35e). Versions: go1.27.3, zig 0.14.1,
rustc/cargo 1.98.0.

| program, step | Grail | Go | Zig | Rust | Grail / fastest |
| --- | --- | --- | --- | --- | --- |
| hello check, cold | 0.045 (0.05) | 0.179 (0.10) | 0.176 (0.15) | 0.053 (0.05) | **0.85x** |
| hello check, edited | 0.046 (0.05) | 0.168 (0.09) | 0.177 (0.15) | 0.032 (0.03) | 1.45x |
| hello build, cold | 0.146 (0.15) | 0.156 (0.08) | 1.072 (1.03) | 0.098 (0.08) | 1.49x |
| hello build, edited | 0.141 (0.14) | 0.176 (0.09) | 1.069 (1.03) | 0.068 (0.05) | 2.09x |
| syn1000 check, cold | 0.198 (0.20) | 1.310 (0.40) | 0.234 (0.20) | 0.699 (0.70) | **0.84x** |
| syn1000 check, edited | 0.204 (0.21) | 1.368 (0.44) | 0.227 (0.19) | 0.221 (0.22) | **0.93x** |
| syn1000 build, cold | 1.541 (1.06) | 1.346 (0.41) | 1.905 (1.86) | 1.466 (1.33) | 1.15x |
| syn1000 build, edited | 0.926 (0.76) | 1.366 (0.40) | 2.166 (2.24) | 0.850 (0.78) | 1.09x |
| syn4000 check, cold | 0.733 (0.74) | 5.906 (1.75) | 0.424 (0.38) | 2.990 (3.00) | 1.73x |
| syn4000 check, edited | 0.753 (0.76) | 5.940 (1.81) | 0.414 (0.38) | 0.964 (0.97) | 1.82x |
| syn4000 build, cold | 8.204 (5.53) | 6.056 (2.12) | 5.572 (5.63) | 6.840 (6.91) | 1.47x |
| syn4000 build, edited | 4.428 (3.34) | 5.720 (1.92) | 4.948 (4.90) | 4.052 (3.85) | 1.09x |

Go spreads one package over every core, so its wall time is a third of its CPU time: by wall clock
Go is the fastest builder of the large programs (2.1 s for syn4000, against Grail's 5.5 s).

**Met**: a cold check of hello world, and both checks of syn1000.

**Missed, and why:**

- **A check after an edit checks everything again.** `cargo check` is incremental: hello 0.032 s,
  syn4000 0.96 s against its own 2.99 s cold. Grail's check has no store and costs the same edited
  as cold. It also still checks the runtime, the platform module and `core` from source every time
  (the "Not done" of stage 2).
- **syn4000 check, 1.7x Zig's.** Grail's front end is one process, single-threaded (0.73 CPU s in
  0.74 s of wall time), and about a third of it is allocation (see "What a build still costs"). Zig
  checks the same 104k lines in 0.42 s, also on one thread. Parallel body checking (5b below) and
  the unboxed values (3) are the planned fixes. This run did not profile further.
- **A build writes and re-reads assembly text.** A whole-program build of syn4000 (`grail OUT.s`
  then clang, measured the same way): the compiler takes 4.8 CPU s (42 G instructions) and writes
  35.6 MB of assembly, clang spends 2.0 CPU s (15.5 G instructions) parsing and assembling it, and
  the link takes 0.04 s. A quarter of the build's CPU is the assembler, which is stage 4's case for
  direct object emission. Through the store, `grail build` adds about 1.4 CPU s on top (8.2 against
  6.8): hashing, filing units and per-module compiler runs.
- **hello build, 1.5x to 2.1x cargo's.** What a small build has left is the assembler and the
  linker over the program's module, plus the runtime objects linked from the store. cargo's 0.068 s
  is rustc's incremental codegen of one changed function and a link.
- **syn1000 and syn4000 builds after an edit, 1.09x cargo's.** The unit layer replays every
  unchanged body, but the back end's whole-stream work and the assembler still run over the whole
  module (see "An edit to one function compiles one function").
### Bodies in parallel, and one jobserver for the build

A module's function bodies are compiled by forked workers into units and applied in source order
by the parent (`docs/design/incremental-compilation.md`, "Parallel bodies"); `grail check` the same
way, its units carrying only registrations. One GNU-make-style jobserver per build bounds module
runs, optimiser workers and body workers together. Integer conversions are in line: a widening is
no code at all, on every target and backend, and a narrowing a compare and a branch.

Best of three on a shared host (load average 20-40), before = 723c743, after = this pass:

| | `GRAIL_JOBS=1` before | after | default before | after |
| --- | --- | --- | --- | --- |
| self-compile | 24.3 s | 24.8 s | 14.0 s | 11.4 s |
| self `--check` | 10.7 s | 8.3 s | 7.5 s | 3.7 s |
| syn4000 `grail check` | 7.4 s | 5.5 s | 5.9 s | 4.1 s |
| syn4000 `grail build --no-cache` | 16.7 s | 14.1 s | 10.6 s | 11.0 s |
| 24-module cold `grail build --cache` | | | 10.9-12.8 s | 10.0-12.9 s |

At `GRAIL_JOBS=1` the gain is the in-line conversions alone (`rt_int_cast` was 8 % of the
compiler's profile; 0.3 % now). At the default the self-check halves; the self-compile gains less
because its back end - the optimiser's whole-stream passes and the assembler - is now most of it,
and syn4000's build is one module whose optimiser workers already used the machine. The 24-module
cold build is within noise: its modules are small enough that each runs in one process, and 24
of them already fill 24 processors. FNV-1a over 64 MiB eight times (`bench/fnv.grl`): 3.71 s to
0.84 s; the instructions of its 1 MiB variant, by valgrind, 1.11 G to 0.25 G.

### Parallel bodies, measured against the rivals

`gaps12-parbodies` compiles a module's bodies in forked workers (`grail check` too) and keeps every
integer widening in line. `bun tools/compile-rivals.mjs --branch gaps12-parbodies` measured
7b93225; `--compiler` measured this tree's release compiler (`gaps13-int` db2d35e sources) right
after it, so both runs saw the same load (average 25 to 32 on 24 cores). Each figure is Grail's CPU
seconds, with wall seconds in brackets. "Best rival" is the fastest of Go, Zig and cargo by CPU in
each run.

| program, step | db2d35e | parbodies 7b93225 | best rival, each run | CPU ratio before | CPU ratio after | wall ratio before / after |
| --- | --- | --- | --- | --- | --- | --- |
| hello check, cold | 0.076 (0.08) | 0.069 (0.05) | 0.073 / 0.062 | 1.03x | 1.12x | 1.03x / 0.80x |
| hello check, edited | 0.066 (0.07) | 0.064 (0.04) | 0.040 / 0.033 | 1.64x | 1.92x | 1.73x / 1.38x |
| hello build, cold | 0.208 (0.22) | 0.165 (0.17) | 0.142 / 0.132 | 1.46x | 1.25x | 1.60x / 1.59x |
| hello build, edited | 0.212 (0.22) | 0.152 (0.15) | 0.099 / 0.092 | 2.15x | 1.66x | 2.54x / 2.14x |
| syn1000 check, cold | 0.291 (0.29) | 0.578 (0.21) | 0.320 / 0.341 | 0.91x | 1.70x | 1.03x / 0.71x |
| syn1000 check, edited | 0.214 (0.21) | 0.574 (0.23) | 0.293 / 0.285 | 0.73x | 2.02x | 0.70x / 0.75x |
| syn1000 build, cold | 2.375 (1.98) | 2.514 (1.64) | 1.454 / 1.391 | 1.63x | 1.81x | 2.61x / 2.72x |
| syn1000 build, edited | 1.474 (1.40) | 1.421 (1.19) | 1.144 / 1.066 | 1.29x | 1.33x | 1.75x / 1.83x |
| syn4000 check, cold | 0.949 (0.96) | 3.409 (0.85) | 0.500 / 0.476 | 1.90x | 7.16x | 1.99x / 1.95x |
| syn4000 check, edited | 1.086 (1.11) | 3.490 (0.95) | 0.545 / 0.498 | 1.99x | 7.00x | 2.13x / 2.05x |
| syn4000 build, cold | 8.922 (7.65) | 12.100 (6.17) | 6.234 / 5.829 | 1.43x | 2.08x | 2.82x / 3.13x |
| syn4000 build, edited | 5.876 (4.88) | 5.184 (3.90) | 4.505 / 3.793 | 1.30x | 1.37x | 1.94x / 2.08x |

What it shows:

- **Wall time falls, CPU time rises.** On syn4000 a check takes 0.85 s of wall time instead of 0.96
  s, and a cold build 6.2 s instead of 7.7 s. The CPU behind the check is 3.6x larger (3.4 s
  against 0.95 s), because the forked workers do work the single process did not (each re-derives
  what it needs) on a machine whose cores were already taken. On this host Zig's single-threaded
  check (0.44 to 0.50 s) is still the fastest on both measures.
- **An edited check costs what a cold one does, before and after.** The check's units carry only
  registrations, and nothing reuses them across an edit (the branch's own note: "`grail check` the
  same way, its units carrying only registrations"). cargo's incremental check (0.97 s on syn4000
  after an edit, against 3.2 s cold) is the bar this misses.
- **An edited build improves**: 3.9 s wall against 4.9 s, close to cargo's 3.6 s.
- Hello world is unchanged, as it should be: one small module has nothing to fork.

## The order of the remaining work

2. *(done: see above.)* What is left of it is `grail check` reading interfaces from the store.
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
