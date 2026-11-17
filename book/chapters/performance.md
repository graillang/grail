# Performance against other languages

Grail measures itself against the best existing languages, never against its own past numbers.
There are four bars: release builds run at the speed of C built with `clang -O2`, within noise;
development builds run faster than Zig Debug, Rust's dev profile and Go; the compiler is the
fastest of Go, Zig and rustc at checking and building, cold and after a one-function edit; and the
scheduler matches or beats Rust's rayon and C++'s oneTBB. This chapter shows where each bar is
met and where Grail is still behind, and why.

Every chart below is drawn from a results file committed under `bench/results/`, so building the
book runs no benchmark. Each chart is followed by its numbers, the machine and load they were taken
on, the commit measured and the commands that reproduce them. `just bench-results` measures again
and refreshes the files; the gate does the same as its last legs.

Every program has a twin in each language: the same algorithm and the same output, written the way
that language is usually written, not hand-vectorised, and built the way its users build it. Every
output is checked against the C twin's. All of them target baseline x86-64 (SSE2), which is what
clang, rustc, Go and Grail emit by default, so no column gets a newer instruction set than the
others. The machine is shared, so wall time is never the figure: each chart says whether it
shows CPU time from `getrusage` (the best of several runs) or, when the machine was heavily loaded,
the user-space instructions executed (from `perf_event_open`, which load does not move). The
scheduler's figures are wall time by nature, the median of several rounds, with the load beside
them.

## Release builds

The release build is Grail's LLVM backend: the compiler's own code lifted to LLVM IR and compiled
with `clang -O2`, with integer overflow wrapping, as Rust's release profile does.

{{perf:bench-rivals#release}}

**Where Grail is behind, and why**, read from the generated code of the commit charted:

- **A vector owned by the function re-reads its header on every store.** `sieve` and `sort` keep
  their data in vectors created in the same function, and each store through one is followed by a
  reload of its length and data pointer and a bounds check, because the IR given to LLVM does not
  say that a store into the data cannot change the header. Release builds now read a *slice's*
  descriptor once (which is what brought `xform` from about 7x to within
  1.3x of C), but it does not yet cover vectors.
- **Bounds checks that stay in the loop stop it being unrolled.** `matmul`'s inner product no longer
  reloads anything, but both index checks remain, so its loop is about 11 instructions an iteration
  where C's unrolled loop is about 4.
- **`nbody` now uses fixed-size arrays** (`[f64; 15]`) and executes the same
  number of instructions as C; the remaining distance is to Zig, which unrolls the whole pair loop
  over its arrays.
- Where the time is at parity (`fnv`, `dot`), Grail still executes 1.2x to 1.5x the instructions of
  C: the serial multiply or add chain sets the pace and hides them.

## Development builds

The development build is Grail's native backend, the one the tests run: it exists to compile
quickly, as Go's compiler and Zig's debug backend do. Go has one build mode and appears here too.

{{perf:bench-rivals#dev}}

**Why it is behind.** Grail's development build beats Rust's dev profile on every program and
loses to Zig Debug and Go on most. Its integer widenings are now free (in `fnv` that took it from
about 107 instructions per byte to 17, against Go's 11), and what remains in the native backend's
code is:

- every element access is checked against a length read again from memory, with the vector's data
  pointer loaded again beside it;
- loops test at the top and jump back unconditionally, and values move between registers on every
  step, where Go's loops are laid out tight;
- `f32` arithmetic goes through `f64` and back on every operation (`xform_f32`, `dot_f32`, `matmul`).

{{perf:bench-rivals#instructions|cpu}}

{{perf:bench-rivals#native-cpu}}

{{perf:bench-rivals#provenance}}

## Engine-shaped programs

Small kernels say what a loop costs; an engine is mostly other work. These seven programs are the
shapes a game engine spends its frames on, each with the same algorithm and output in C, Rust, Go
and Zig, written the way each language is usually written:

- `hashmap`: a million `u64` keys inserted into the standard map, all looked up, half removed, all
  looked up again (C has no standard map, so its twin is the open-addressing table a C program
  writes for itself);
- `bintrees`: the benchmarks game's binary trees at depth 16, allocation-heavy;
- `strings`: a million `name,int,decimal` lines built, split, parsed and formatted again;
- `json`: a 10 MB document built, parsed into each language's dynamic value, walked and serialised
  (Rust with `serde_json`; C, which has no JSON library, with a compact hand-written one);
- `dyncall`: a million shapes of three kinds behind an interface object, one indirect call each;
- `iterchain`: ten million numbers through `map`, `filter` and a sum (Go and Zig have no iterator
  adapters in their standard libraries, so their twins are the loop; Go's uses range-over-func);
- `ecs`: a million entities as structure-of-arrays `f32` columns, a hundred frames of integration.

{{perf:engine#release}}

**Why Grail is behind**, read from the code of the commit charted. The standard map, strings and
interface calls each got faster in the last round of work (the map is now a single open-addressed
table, so hashmap fell from 22x the fewest instructions to 3.5x), and what remains is:

- **`iterchain`: the adapters are not types.** `Iter<T>` is the erased form: every element is a call
  through a boxed closure returning an option, once per adapter, and nothing inlines through it.
  Rust's chain compiles to the same loop as the hand-written one. Making the adapters types with
  callable bounds is the plan in `docs/design/dyn-and-callable-bounds.md`.
- **`ecs`: owned vectors re-read their headers.** The update loop stores through six vectors made
  in the same function, and after each store the next access reloads a length and a data pointer
  and checks the index, so the loop stays scalar where C, Rust and Zig vectorise it.
- **`hashmap`, `strings`, `json`, `dyncall`** are within 2x to 3.5x: what is left is allocation per
  piece (a new string per split field and per formatted record, a box per interface object) and
  bounds checks in the inner loops.
- **`bintrees`** is where Grail does best against `malloc` and `Box`; Zig, with its release
  allocator, executes the fewest instructions.

{{perf:engine#dev}}

{{perf:engine#cpu|instructions}}

{{perf:engine#provenance}}

## Parallel loops

The `ecs` program above, run on several cores: the same million entities and hundred frames, the
update split across workers each frame, at 1, 4 and 8 workers. Grail uses `pool::zip3` over the
position and velocity columns, one call per axis, in pieces of 16,384 entities; C uses OpenMP
(`parallel for schedule(static)`), Rust uses rayon (`par_iter_mut().zip(..)` over all six columns,
pieces of at least 16,384), Go one goroutine per core, and Zig one `std.Thread` per core. The
others fuse the six columns into one loop, the usual way to write it in each; Grail's library has a
zip of at most four columns, hence one call per axis. Each entity's arithmetic is independent and
the final sum is serial, so every program prints the serial checksum at any worker count, and the
tool checks that it does.

A parallel loop is about time, so this chart is wall time, best of several runs, with every runtime
told the same number of threads. It needs a machine doing nothing else, and the figures charted
until the next quiet window were taken on a shared one: read the instruction table under it for
what each runtime does, and the chart only for the shape.

{{perf:parallel#release}}

{{perf:parallel#instructions|cpu}}

{{perf:parallel#provenance}}

## Abundance: the engine itself

The programs above are written for comparison; Abundance's port is the engine this language is
being built beside. `bun tools/abundance-perf.mjs` builds every program of the port's parity suite
(`abundance/tests/*_test.grl`) through the build store - cold, and after one statement is added to
`main` - runs its development and release builds with the suite's own arguments, checks the output
against the C++ reference, and profiles the slowest release run. `--branch REF` adds another
compiler's columns, so a change is measured on the engine the same way.

{{perf:abundance#abundance-compile}}

{{perf:abundance#abundance-run}}

**What it found.** Every program of the port builds through the store and matches its reference
(the ImGui program is left out where its library is not built). A cold build of a test program is
3 to 12 G instructions, most of it the port modules it imports; after a one-statement edit to
`main` it is 0.17 to 0.37 G, a twentieth or less, because the store replays every unchanged module
and function. The first measurement found a store fault that stopped eight programs building - a
module's `u64` constant above 2^63 could not be read back from its interface - and its fix is on
main.

`abgeo` (the cluster builder and its reader) is the slowest release run, and its time goes to
building vectors rather than to geometry: growing them (`rt_grow`) and pushing onto them
(`rt_push`) lead the profile, with integer conversion (`rt_int`) third.

{{perf:abundance#abundance-compile-cpu}}

{{perf:abundance#abundance-run-cpu}}

{{perf:abundance#provenance}}

## Compile speed

The bar: Grail compiles faster than Go, Zig and rustc, and its development builds are ready sooner
than Zig Debug's, Rust's dev profile's and Go's. The same programs are written in all four
languages: hello world, a generated program of N records, constructors and 15-line loop functions
(N = 1000 and 4000, about 26,000 and 104,000 lines), and the seven engine-shaped programs above.
Each is measured five ways: a check cold and after a one-function edit, and a build cold, after
the edit, and again with nothing changed. Go has no check command; `go vet` type-checks and then
runs its analyses, and it is what Go's column shows. A build whose output is thrown away is in a
table of its own further down.

The figure is the user-space instructions of the tool and every process it started, with every
toolchain held to one process (`GRAIL_JOBS=1`, `GOMAXPROCS=1 -p=1`, `cargo -j1`; Zig's build-exe has
no job flag). The standard library is warm for every toolchain, as it is after an
install: Grail's store holds what `grail cache warm` builds (every standard module, which the
installers run), Go's build cache its standard library, Zig's cache its compiler runtime, and cargo
works from its registry. "Cold" means a project's first build, not a toolchain's. Instruction counts do not move with the load of the shared machine, where time does.
A second chart shows wall time with four jobs each, this machine's cap.

{{perf:compile#compile}}

{{perf:compile#compile-wall}}

**Where Grail is ahead, and where it is behind.** On the commit charted, Grail is the fastest on
every row of hello world and the seven engine programs except one (iterchain's check after an edit,
level with cargo): a project's first check, its first build, a rebuild after an edit and a rebuild
with nothing changed. A no-op rebuild is decided from fingerprints without reading the program
again, and the build store files its results in-process. On the generated programs, Grail wins
every edited build and no-op rebuild, and the edited check of the smaller one. It is behind in
three places, with their causes from profiles of the compiler on these programs:

- **A cold check of a large program** (1.6x Zig at 26,000 lines, 3.2x at 104,000). The check of
  one large module hashes its interface with SHA-256 (11 % of the instructions), writes the
  interface (10 %) and still emits code text that it throws away (6 %); allocation and copying are
  about a quarter. Zig checks the same program on one thread in a third of the instructions.
- **A check of a large program after an edit** (1.4x Zig at 104,000 lines). The whole module is
  checked again, at about half the cold cost, where `cargo check` re-checks only what changed.
- **A cold build** (1.6x Go). The optimiser is a third of the build and re-reads the front end's
  instruction text (about 18 %), and the assembler reads the optimiser's text again. A cold build of
  the 104,000-line program also grew from 38 to 53 billion instructions between two recent commits
  of the compiler; that regression is being traced.

{{perf:compile#compile-go-check}}

{{perf:compile#compile-cpu}}

{{perf:compile#provenance}}

## The scheduler

Joins, spawns, `fib(32)` by nested join, and a simulated game frame loop: 32 systems as jobs, a
parallel pass over a million elements, an I/O task and a background importer, against twins on
rayon and on oneTBB. These are wall-clock times measured inside each program, the median of several
rounds. The importer row counts how much work the importer got done, so higher is better there.

{{perf:sched-rivals#scheduler}}

**Where Grail is behind, and what load does to it.** In a quieter run (load average about 20 on
24 CPUs, recorded in `docs/design/runtime-parity.md`), Grail's frame loop had the best tail latency
of the three: its Frame class runs ahead of the importer, as oneTBB's high-priority arena does and
as rayon, which has no priorities, cannot. The run charted here was taken with the machine
oversubscribed (load average 37), and there oneTBB's worst frames barely moved while Grail's grew
several times over. Grail's scheduler holds its tail only while it has the cores to itself, and
that is a finding in its own right. Everything else is behind under either load:

- **A join allocates.** Each one makes about five heap allocations for its closures and its
  second result; rayon's join puts a job that lives on the caller's stack onto a deque and
  allocates nothing.
- **The main thread is not a worker.** Joining from `main` posts the work and waits to be woken,
  as rayon does; oneTBB's main thread is a slot of its arena and joins directly.
- **The calls themselves are slower.** Serial `fib(32)`, with no scheduler involved, is 3x
  oneTBB's: Grail's calling convention carries three hidden registers through every call.
- **The importer gets fewer rounds by design.** At most a quarter of the workers run Background
  work, where oneTBB lets its low-priority arena take every idle thread.

{{perf:sched-rivals#provenance}}

The design notes behind each row, with the generated code that names each cause, are
`docs/design/runtime-parity.md` and `docs/design/compile-speed.md`.
