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
output is checked against the C twin's. C++ twins are idiomatic C++20 built with `clang++ -O2`: the
standard containers and algorithms (`std::vector`, `std::sort`, `std::merge`, `std::unordered_map`,
`std::string`), virtual calls, ranges, and a mutex-and-condition channel where C++ has none. All of
them target baseline x86-64 (SSE2), which is what clang, clang++, rustc, Go and Grail emit by
default, so no column gets a newer instruction set than the others. The machine is shared, so wall time is never the figure: each chart says whether it
shows CPU time from `getrusage` (the best of several runs) or, when the machine was heavily loaded,
the user-space instructions executed (from `perf_event_open`, which load does not move). The
scheduler's figures are wall time by nature, the median of several rounds, with the load beside
them.

## The languages at a glance

One panel per thing this chapter measures, one bar per language in each. Within a panel, every
language's figure on each row is divided by the fastest language's figure on that row, so the
fastest scores 1x there. A language's bar is the geometric mean of those multiples over the
panel's rows: 1x would mean it was the fastest on every one, and 1.5x that it typically takes half
as long again as the fastest. All four panels share one logarithmic scale that starts at 1x, so a
bar's length is how far behind the fastest a language is, and each panel lists the fastest first.
Each panel names the file it reads, its figure and the languages it has no bar for:

- **Release builds - run time** sets C, C++, Rust, Go, Zig and Grail's LLVM build side by side over
  the programs of the run-time, engine and parallel charts below (the parallel one at eight
  workers): CPU time, wall time for the parallel ECS.
- **Development builds - run time** sets Grail's native backend against the rivals' debug builds over
  the same programs (Go has one build, so it appears in both panels). C and C++ have no development
  build measured.
- **Compile speed** reads the compile chart: every program (hello world, the generated programs and
  the engine twins) in every scenario (check and build, cold, after a one-function edit, and nothing
  changed) is a row, and the figure is the user-space instructions the toolchain executed. C and
  C++ are clang and clang++ driven by make, as described in the compile-speed section.
- **Scheduler** reads the scheduler chart's wall times. Only three languages have a scheduler twin:
  Grail (its bar is the release build, the LLVM backend), Rust (rayon) and C++ (oneTBB). The importer
  row counts work done, so more is better there and the multiple is inverted: the most rounds over
  each language's rounds.

A language with no figure on some row is averaged over the rows it has, and the table under the
chart says which ones it lacks. Read a bar with its rows in mind: in the release panel, C's, C++'s
and Zig's `chan` twins are mutex-and-condition rings that take about fifteen times as long as
Grail's and Go's channels, and Grail's `ffi_call` is the fastest by more than half, so those two
rows weigh on the panel; without them Grail and C are level (1.20x and 1.21x), then Zig (1.23x),
C++ (1.26x), Rust (1.30x) and Go (1.90x). In the compile panel, a rebuild with nothing changed
costs make next to nothing and every other toolchain some work of its own, which weighs on the
means of the rows it is in.

{{perf:overview}}

## Everything at a glance

One bar per category: how much faster or slower Grail is than the fastest rival in that category,
taking the geometric mean of the category's rows. A green bar to the left of the centre line means
Grail is faster, a red bar to the right that it is slower, on a logarithmic scale. Each category's
best and worst row are marked and named in the table under the chart, and the sections that follow
chart every row.

{{perf:summary}}

## Release builds

The release build is Grail's LLVM backend: the compiler's own code lifted to LLVM IR and compiled
with `clang -O2`, with integer overflow wrapping, as Rust's release profile does.

{{perf:bench-rivals#release}}

**Where Grail is behind, and why**, read from the generated code of the commit charted:

- **C++ is the fastest of all on `sort` and `sieve`.** `std::merge` runs the merge loop in 63% of
  C's time while executing more instructions than C: its loop suits random data, where a branch on
  each comparison is mispredicted half the time. `std::vector<bool>` packs eight flags into a byte
  where every other twin spends a byte on each. Against C, Grail's release build is 1.30x on `sort`
  and 1.14x on `sieve`; against C++, 2.06x and 1.69x. The merge loop is the next target.
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

**Why it is behind.** Grail's development build beats Rust's dev profile and Zig Debug on every
program, and runs at 1.06x to 1.78x Go's time. Its integer widenings are free (in `fnv` that took it
from about 107 instructions per byte to 17, against Go's 11). A vector or slice a loop does not
change keeps its data pointer and length in registers for the whole loop, with each element's
address folded into the load or store; an `f32` parameter is rounded once at entry and the loop
stays in single precision. That took `xform_f32` from 0.43 to 0.089 seconds (Go 0.084) and
`xform_f64` from 0.16 to 0.10, and `sort`, whose merge loop now branches directly on its conditions
instead of building booleans, from 1.53 to 1.17. What remains in the native backend's code:

- every element access is still checked, and loops test at the top and jump back unconditionally,
  where Go's are laid out tight;
- `nbody` (1.78x, the furthest) keeps its bodies in a record and moves `f64` values between general
  and SSE registers on every step;
- the native optimiser judges each function for inlining once, before its own calls are inlined, so
  a chain of small closures (`iterchain`, 1.86x) is not flattened.

{{perf:bench-rivals#instructions|cpu}}

{{perf:bench-rivals#native-cpu}}

{{perf:bench-rivals#provenance}}

## Engine-shaped programs

Small kernels say what a loop costs; an engine is mostly other work. These seven programs are the
shapes a game engine spends its frames on, each with the same algorithm and output in C, C++, Rust,
Go and Zig, written the way each language is usually written:

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
- `ecs`: a million entities as structure-of-arrays `f32` columns, each made at its full length and
  then filled, a hundred frames of integration;
- `chan`: bounded channels between threads, one to one, many to one, many to many and a ping-pong
  of round trips (Rust's twin uses crossbeam-channel; C's and Zig's are a mutex-and-condition ring).

{{perf:engine#release}}

**Where Grail stands**, read from the code of the commit charted. `strings` and `json` are at
parity with the fastest (C++ on both; `json` 0.99x, `strings` 1.00x): strings are one block, enums
keep their payloads inline, and a value written before it is read is not zeroed first. `ecs` is
within 1.07x of C, and `chan` is level with Go (0.087 seconds each). What remains:

- **`chan`, from 2.4x Go to level with it.** Grail's channel is crossbeam-channel's design (a ring
  of stamped slots, a compare-exchange per hand-off, spin, then yield, then park). A waiting side
  now watches only its slot's stamp after each pause, where it re-read the other side's counter and
  took that cache line away just before the other side's compare-exchange. Go runs both ends as
  goroutines on one scheduler and Grail on two threads, so the development build's CPU time, which
  counts the spinning side, is still 2.9x Go's.
- **`bintrees`: the allocator.** Allocating and freeing the nodes are about three fifths of the
  run; Zig's release allocator executes the fewest instructions.
- **`hashmap`: insertion order costs one memory touch.** Grail's map keeps its entries in insertion
  order in a dense vector beside the probe table, like Python's `dict` and Zig's `ArrayHashMap`, so
  a lookup reads the slot and then the key. C's open-addressed table keeps keys in the slots. This
  row is bound by memory: in this run C's own time rose 14% over the previous run with the same
  instructions, and Grail's moved with it (1.21x C, from 1.00x, with identical instructions).
  C++'s `std::unordered_map`, a node per entry, takes 3x C's time.
- **`iterchain`: a scalar loop.** The chain folds internally (`Map` and `Filter` override `fold`, as
  Rust's adapters do) over a slice iterator that counts an index, so it compiles to one loop with
  no calls, but it is not yet vectorised the way C's and Rust's are.
- **`dyncall`** is bound by the indirect call. `ecs` no longer reloads a column after each store;
  in the development build it now takes less CPU time than Go's (0.83x).

{{perf:engine#dev}}

{{perf:engine#cpu|instructions}}

{{perf:engine#provenance}}

## Parallel loops

The `ecs` program above, run on several cores: the same million entities and hundred frames, the
update split across workers each frame, at 1, 4 and 8 workers. Grail uses `parallel_for_zip` over
each axis's velocity and position columns, one call per axis, in pieces of 16,384 entities; C uses OpenMP
(`parallel for schedule(static)`), Rust uses rayon (`par_iter_mut().zip(..)` over all six columns,
pieces of at least 16,384), Go one goroutine per core, and Zig one `std.Thread` per core. The
others fuse the six columns into one loop, the usual way to write it in each; Grail's library has a
zip of at most four columns, hence one call per axis. Each entity's arithmetic is independent and
the final sum is serial, so every program prints the serial checksum at any worker count, and the
tool checks that it does: a build that prints another answer is not charted.

A parallel loop is about time, so this chart is wall time, best of nine runs, with every runtime
told the same number of threads (C++ splits each frame across `std::jthread`s statically), taken
with the machine otherwise idle (load average under 6). Grail's release build is the fastest of all
on one worker (0.64x C's OpenMP) and on four (0.90x), and 1.21x C's on eight, where it is no faster
than on four. Its development build is faster than Go at every worker count (0.67x to 0.83x). Timed
inside the program, its hundred frames on eight workers are as fast as OpenMP's at best but vary
from run to run, where OpenMP's do not. Work stealing gives each frame's pieces to whichever worker asks
first; OpenMP's static schedule gives every thread the same slice every frame, which most likely
keeps that slice in the thread's own cache. Handing a piece to the worker that ran it last is the
next step. The development build's set-up loop was a serial third of its run until a conversion
from a 64-bit integer to `f32` became one instruction; on four workers it went from 0.36 to 0.11
seconds.

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
`abgeo`, the largest, builds cold in 8.4 billion instructions and again after an edit in 0.21.

The release runs are short. `abgeo` (the cluster builder and its reader) takes 0.27 billion
instructions, most of it the mesh simplifier's own work; constant tables that it once rebuilt on
every call are now read-only data.

{{perf:abundance#abundance-compile-cpu}}

{{perf:abundance#abundance-run-cpu}}

{{perf:abundance#provenance}}

## Compile speed

The bar: Grail compiles faster than Go, Zig and rustc, and its development builds are ready sooner
than Zig Debug's, Rust's dev profile's and Go's; C and C++, compiled by clang and clang++, are
measured beside them. The same programs are written in all six languages: hello world, a generated program of N records, constructors and 15-line loop functions
(N = 1000 and 4000, about 26,000 and 104,000 lines), and the seven engine-shaped programs above.
Each is measured five ways: a check cold and after a one-function edit, and a build cold, after
the edit, and again with nothing changed. Go has no check command; `go vet` type-checks and then
runs its analyses, and it is what Go's column shows. A build whose output is thrown away is in a
table of its own further down.

C and C++ are built the way a C project's edit loop builds: each program is one translation unit
with a one-target Makefile, and `make` builds it. A check is `clang -fsyntax-only` (`clang++
-std=c++20 -fsyntax-only`), which parses and type-checks without generating code, as `grail check`,
`cargo check` and Zig's `-fno-emit-bin` do. A build is `-O0 -g`, linked with lld (`-fuse-ld=lld`):
no optimisation and full debug information, which is what every other column's development build
does too (Zig Debug, Rust's dev profile, `go build`, and `grail build`), and a fast modern linker, as
the others have (Go's and Zig's own, rustc's rust-lld, Grail's ld.lld), so neither the debug
information nor the linker sets C apart. After a one-function edit, make recompiles the one
translation unit and links it again; with nothing changed, make finds the program up to date and
does nothing else. A build system is part of every column - cargo, `go build`'s cache, Zig's cache
and Grail's store each decide what to rebuild - and make is C's, so its own cost is what C's
nothing-changed rows count. C has no project cache to empty for a cold build, and its standard
libraries ship compiled, as the others' are warm.

The figure is the user-space instructions of the tool and every process it started, with every
toolchain held to one process (`GRAIL_JOBS=1`, `GOMAXPROCS=1 -p=1`, `cargo -j1`; Zig's build-exe has
no job flag). The standard library is warm for every toolchain, as it is after an
install: Grail's store holds what `grail cache warm` builds (every standard module, which the
installers run), Go's build cache its standard library, Zig's cache its compiler runtime, and cargo
works from its registry. "Cold" means a project's first build, not a toolchain's. Instruction counts do not move with the load of the shared machine, where time does.
A second chart shows wall time with four jobs each, this machine's cap.

{{perf:compile#compile}}

{{perf:compile#compile-wall}}

**Where Grail is ahead.** On the commit charted, counting instructions, Grail is the fastest on
every row: hello world, the engine programs, every check and build after an edit, every rebuild
with nothing changed (a twentieth of the others' cost or less), and the cold check and cold build of
both generated programs. The closest row is the cold check of the 104,000-line program, 0.93x
Zig's (3.05 against 3.28 billion instructions, 0.31 against 0.33 seconds). Both programs call every
function they declare, so Zig's lazy analysis skips nothing. The profiles that got the check there
are in `docs/design/compile-speed.md`: allocator fast paths, one cache file per module, no drop calls
on literal string views, and a frame cleared only where a slot is read before it is written.

The chart is the release compiler of the commit named, built with ThinLTO and profile-guided
optimisation, and measured with the machine otherwise idle.

{{perf:compile#compile-go-check}}

{{perf:compile#compile-cpu}}

{{perf:compile#provenance}}

## The scheduler

Joins, spawns, `fib(32)` by nested join, and a simulated game frame loop: 32 systems as jobs, a
parallel pass over a million elements, an I/O task and a background importer, against twins on
rayon and on oneTBB. These are wall-clock times measured inside each program, the median of several
rounds. The importer row counts how much work the importer got done, so higher is better there.

{{perf:sched-rivals#scheduler}}

**Where Grail is ahead, and where it is behind.** Measured with the machine otherwise idle, Grail's
frame loop has the best tail latency of the three (p99 0.82 ms against rayon's 1.12 and oneTBB's
1.67, and the smallest worst frame): its Frame class runs ahead of the importer, as oneTBB's
high-priority arena does and as rayon, which has no priorities, cannot. A join from the main thread
costs less than oneTBB's (196 ns against 280). A worker that goes idle is woken by name: the
waker takes one parked worker and counts it searching before waking it, so a burst of forks
wakes one where it used to wake dozens (99.7% fewer futex wakes over the scheduler run). These
rows are one session's medians; the join and spawn rows move by a third between sessions. On an oversubscribed machine (load average 37, an earlier
run) oneTBB's worst frames barely moved while Grail's grew several times over: Grail's scheduler
holds its tail while it has the cores to itself. Behind:

- **A join allocates.** Each one makes about five heap allocations for its closures and its
  second result; rayon's join puts a job that lives on the caller's stack onto a deque and
  allocates nothing.
- **A burst of spawns from `main` costs 1.6x oneTBB's** (269 ns a spawn on 24 workers against 168;
  it was 1.1 us this morning). A task scope on the main thread spawns onto a deque of its own, as
  oneTBB's arena slot does, with the deque's head on its own cache line. What remains is 24 workers
  stealing one task at a time from that one deque.
- **The `fib(32)` rows measure GCC's recursive inlining more than the scheduler.** oneTBB's twin is
  C++ built with g++, which inlines `fib` into itself: serial `fib(32)` takes 46 to 50 million
  instructions there. LLVM never inlines a recursive call into itself, so clang's C (67 million)
  and rayon's Rust don't get this either, and neither does Grail's release build (67 million, the
  same code as clang's). Per join, Grail's work-stealing join costs
  about 1,050 instructions against oneTBB's 920, and its main thread runs fewer instructions than
  oneTBB's. What remains of the gap in the join rows is that serial difference plus the noise of
  wall time on a loaded machine.
- **The importer gets fewer rounds by design.** At most a quarter of the workers run Background
  work, where oneTBB lets its low-priority arena take every idle thread.

{{perf:sched-rivals#provenance}}

The design notes behind each row, with the generated code that names each cause, are
`docs/design/runtime-parity.md` and `docs/design/compile-speed.md`.
