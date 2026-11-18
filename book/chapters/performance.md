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
- `ecs`: a million entities as structure-of-arrays `f32` columns, a hundred frames of integration;
- `chan`: bounded channels between threads, one to one, many to one, many to many and a ping-pong
  of round trips (Rust's twin uses crossbeam-channel; C's and Zig's are a mutex-and-condition ring).

{{perf:engine#release}}

**Why Grail is behind**, read from the code of the commit charted. `strings` is at parity and `json`
executes the same number of instructions as C and Rust: strings are one block, enums keep their
payloads inline, and a value written before it is read is not zeroed first. What remains:

- **`chan`: threads hand off through the operating system.** Grail's channel is a mutex and two
  conditions around a ring, as C's and Zig's twins are, and lands with them. crossbeam spins
  before it sleeps, so a hand-off rarely parks a thread; Go runs both ends as goroutines on one
  scheduler and never reaches the kernel at all.
- **`bintrees`: the allocator.** Allocating and freeing the nodes are about three fifths of the
  run; Zig's release allocator executes the fewest instructions.
- **`hashmap`: insertion order costs one memory touch.** Grail's map keeps its entries in insertion
  order in a dense vector beside the probe table, like Python's `dict` and Zig's `ArrayHashMap`, so
  a lookup reads the slot and then the key. C's open-addressed table keeps keys in the slots.
- **`iterchain`: a scalar loop.** The chain folds internally (`Map` and `Filter` override `fold`, as
  Rust's adapters do) over a slice iterator that counts an index, so it compiles to one loop with
  no calls, but it is not yet vectorised the way C's and Rust's are.
- **`dyncall` and `ecs`** are bound by the indirect call and by a reload after each store in the
  update loop respectively.

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
tool checks that it does: a build that prints another answer is not charted. Grail's release build
of this program is absent for that reason on the commit charted. With the three updates written as
closure literals at the call, it prints a wrong checksum (the y axis's positions are lost), a
miscompile in the LLVM backend that is being fixed; the development build prints the right one.

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
(the ImGui program is left out where its library is not built). The figures charted were taken with
the release compiler of the commit named. After a one-statement edit to `main` a rebuild costs a
twentieth or less of a cold build, because the store replays every unchanged module and function:
`abgeo`, the largest, builds cold in 9.5 billion instructions and again after an edit in 0.22.

The release runs are short. `abgeo` (the cluster builder and its reader) takes 0.30 billion
instructions, most of it the mesh simplifier's own work; constant tables that it once rebuilt on
every call are now read-only data.

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

**Where Grail is ahead, and where it is behind.** On the commit charted, counting instructions,
Grail is the fastest on every row but one: hello world, the seven engine programs, every check and
build after an edit, every rebuild with nothing changed (a twentieth of the others' cost or less),
and the cold check and cold build of both generated programs except one. The exception is the
cold check of the 104,000-line program (1.7x Zig). Both programs call every function they
declare, so Zig's lazy analysis skips nothing; Zig's cost per line is lower and it pays a fixed cost
for its standard library once, which is why its total grows more slowly. The profiles of the
compiler (`docs/design/compile-speed.md`) place Grail's per-line cost in parsing, the allocator and
the per-function units written to the store.

The chart is the release compiler of the commit named, built with ThinLTO. The wall times were
taken with the machine loaded (the load average is recorded with the run), so they favour the
instruction counts as the measure.

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
