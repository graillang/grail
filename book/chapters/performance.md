# Performance against other languages

Grail is measured against the fastest existing language on each program, never against its own
past numbers. The project sets itself four targets: release builds as fast as C built with
`clang -O2`; development builds faster than Go's, Zig Debug's and Rust's dev profile; a compiler
that checks and builds faster than Go, Zig and rustc, cold and after a one-function edit; and a
scheduler that matches Rust's rayon and C++'s oneTBB. They are targets, not results. On the commit
charted:

- **Compile speed — build:** Across the three 20-unit projects (`syn1000`, `syn4000` and the
  3-layer generic/interface/HashMap DAG `app2000`, 6 build rows at 4 jobs, every language producing
  a linked debug executable), C (1.26x, 1/6) and Grail (1.26x, 2/6: fastest on edited `syn1000`
  and `syn4000`, tied with C on edited `app2000`) lead, followed by Go (1.61x, fastest on all 3
  cold builds: 0.25 s, 0.64 s and 0.34 s), Rust (2.60x, 20-crate workspace), C++ (4.47x) and Zig
  (5.85x, self-hosted x86-64 backend; fastest 1-process cold build, but 1.25x 4-job scaling and no
  on-disk incremental cache outside `--watch`). Default `grail build` runs the native optimiser and
  writes line tables (`grail build --debug` turns the optimiser off, writes full variable DWARF and
  builds `syn4000` cold in 0.44 s).
- **Compile speed — check:** Across the 5 languages with a type-check-only command (Go is omitted
  because `go vet` compiles and runs static analysis; it stays in the detail tables below), Grail
  leads all 6 rows (1.00x: 0.20 s cold / 0.03 s edited on `syn4000`, 0.14 s / 0.03 s on `app2000`),
  ahead of C (1.42x), Zig (4.25x), Rust (4.44x) and C++ (9.44x).
- **Release builds:** Over the 18 comparable programs (`chan` is kept in the Engine chart below
  because C, C++ and Zig lack a stdlib channel), Zig (1.10x, 9/18) and Grail (1.17x, 3/18:
  `iterchain`, `xform_f32` and `xform_f64`) lead, ahead of C (1.21x, 4/18), C++ (1.24x, 3/18),
  Rust (1.29x) and Go (2.40x). Grail's largest gaps are `sort` (1.72x C++'s `std::merge`, 1.06x
  C's), `nbody` (1.65x Zig, at parity with C) and `ecs_par` at 8 workers (1.55x Zig, 1.24x C).
- **Development builds:** Go's is ahead by 10% (1.18x against Grail-native's 1.30x over the 18
  programs; Grail is faster than Go on `ecs`, `ecs_par`, `json` and `strings`). Grail's is faster
  than Rust's dev profile (7.34x) on all 18 (and 19/19 with `chan`) and faster than Zig Debug
  (3.56x) on 17 of 18 (all except `ffi_call`).
- **Scheduler:** oneTBB is ahead (1.22x against Grail's 1.39x and rayon's 2.35x across the 12
  scheduler rows, excluding the serial `fib(32)` baseline). Grail is fastest on `join` from main
  (146 ns, 0.53x), `join` on a worker (132 ns, 0.61x) and `frame max` (1.11 ms, 0.77x), and within
  3% of rayon on `frame p99` (0.60 ms; 0.58 ms at 24 workers).

Every chart below is drawn from a results file committed under `bench/results/`, so building the
book runs no benchmark. Each chart is followed by its numbers, the machine and load they were taken
on, the commit measured and the commands that reproduce them. `just bench-results` measures again
and refreshes the files; the gate does the same as its last legs.

Every program has a twin in each language: the same algorithm and the same output, written the way
that language is usually written, not hand-vectorised, and built the way its users build it. Every
output is checked against the C twin's. C++ twins are idiomatic C++20 built with `clang++ -O2`: the
standard containers and algorithms (`std::vector`, `std::merge`, `std::unordered_map`,
`std::string`), virtual calls, ranges, a persistent `std::barrier` worker pool for `ecs_par`, and a
mutex-and-condition channel where C++ has none. All of them target baseline x86-64 (SSE2), which is
what clang, clang++, rustc, Go and Grail emit by default, so no column gets a newer instruction set
than the others. Each chart says whether it shows CPU time from `getrusage` (the best of several
runs), wall time (for parallel scaling and the scheduler), or user-space instructions executed
(from `perf_event_open`, which host load does not move).

**Limits of these numbers.** Every figure comes from one machine (the CPU and kernel are under each
chart), so a different processor may order the languages differently. The rival twins were written
by the Grail project; they are meant to be idiomatic and are open to correction - each is in
`bench/` or `bench/rivals/`. A best-of-several CPU time has no confidence interval: differences of a
few percent between two columns are within run-to-run variation, and scheduler rows move between
sessions. Instruction counts are not time: two programs with the same count can differ in speed by
their memory access and branch behaviour. A geometric mean hides its rows; each chart below has them
all.

## The languages at a glance

One panel per thing this chapter measures, one bar per language in each. Within a panel, every
language's figure on each row is divided by the fastest language's figure on that row, so the
fastest scores 1x there. A language's bar is the geometric mean of those multiples over the
panel's rows: 1x would mean it was the fastest on every one, and 1.5x that it typically takes half
as long again as the fastest. All four panels share one logarithmic scale that starts at 1x, so a
bar's length is how far a language is from the fastest, and each panel lists the lowest first.
Each panel names the file it reads, its figure and the languages it has no bar for:

- **Compile speed - build** compares all six languages on the 6 multi-unit scaling build rows
  (`syn1000`, `syn4000` and the 3-layer generic `app2000`, cold and edited, 4-job wall time)
  where every toolchain produces a linked debug binary.
- **Compile speed - check** compares the five languages that have a type-check-only mode (Grail, C,
  Zig, Rust and C++; Go is omitted rather than penalised for `go vet`, which runs full compilation
  and static analysis and stays in the detail tables below).
- **Release builds - run time** sets C, C++, Rust, Go, Zig and Grail's LLVM build side by side over
  the 18 comparable programs of the run-time, engine and parallel charts below (the parallel one at
  eight workers; `chan` is shown in the Engine chart below because C, C++ and Zig have no stdlib
  channel and use a mutex-and-condition ring).
- **Development builds - run time** sets Grail's native backend against the rivals' debug builds over
  the same 18 programs (Go has one build, so it appears in both panels). C and C++ have no
  development build measured.
- **Scheduler** reads the scheduler chart's 12 wall-time scheduler rows (the pure-serial `fib(32)`
  baseline stays in the table below and is excluded from the mean). Only three languages have a
  scheduler twin: Grail (its release LLVM build), Rust (rayon) and C++ (oneTBB built with
  `clang++ -O2`). The importer row counts work done, so higher is better there and its multiple is
  inverted.

Each panel's means are taken over the rows every language in it was measured on, so no two bars
average different work; a row some language lacks is left out and named under the panel's
heading. In the release panel, Go's `ffi_call` crosses cgo (19x C), which is Go's real FFI cost;
without `ffi_call` as well as `chan`, Go's release mean moves from 2.41x to 2.13x while the other
five languages stay within 0.02x. In the compile-build panel, Grail's default development build
runs its native optimiser and writes line tables (see the compile-speed section for `grail build
--debug`, which turns the optimiser off and writes full variable DWARF).

{{perf:overview}}

## Everything at a glance

One bar per category: Grail's figure divided by the fastest rival's, the geometric mean of the
category's rows, on a logarithmic scale. Left of 1x Grail's figure is lower (better), right of it
higher; the unit is CPU time unless the category names wall time or instructions. Each category's
best and worst row are marked and named in the table under the chart, and the sections that follow
chart every row.

{{perf:summary}}

## Release builds

The release build is Grail's LLVM backend: the compiler's own code lifted to LLVM IR and compiled
with `clang -O2`, with integer overflow wrapping, as Rust's release profile does. `ffi_call` calls
a separately compiled C function (`grail_bench_abs` in `bench/ffi_target.c`, archived without LTO)
so no compiler can recognise a standard-library builtin and inline away the ABI boundary: Grail, C,
C++, Rust and Zig all measure 0.99 to 1.00 ns per call.

{{perf:bench-rivals#release}}

**Where Grail is behind, and why**, read from the generated code of the commit charted:

- **C++ is the fastest on `sort` (0.478 s against C's 0.775 s and Grail's 0.823 s).** `std::merge`
  runs the merge loop in 62% of C's time on random keys, where a branch on each comparison is
  mispredicted half the time. Against C, Grail's release build is 1.06x on `sort` and 1.12x on
  `sieve` (where `sieve.cpp` uses `std::vector<uint8_t>`, matching the byte-per-flag arrays of C,
  Rust, Zig and Grail).
- **A vector owned by the function re-reads its header on every store.** `sieve` and `sort` keep
  their data in vectors created in the same function, and each store through one is followed by a
  reload of its length and data pointer and a bounds check, because the IR given to LLVM does not
  say that a store into the data cannot change the header. Release builds read a *slice's*
  descriptor once per loop, but not yet a vector's.
- **Bounds checks that stay in the loop stop it being unrolled.** `matmul` is 1.05x C (1.07x Zig):
  its inner product no longer reloads anything, but index checks remain in the loop.
- **`nbody` uses fixed-size arrays** (`[f64; 15]`) and matches C and C++ (0.092 s against 0.093 s);
  the 1.65x distance is to Zig (0.056 s), which unrolls the pair loop over its arrays.
- **`xform_f32` (2,000 passes, 0.129 s) and `xform_f64` (1,000 passes, 0.135 s)** are at parity
  with C (1.00x and 0.99x). Where CPU time is at parity (`fnv`, `dot`), Grail still executes ~1.1x
  to 1.5x the instructions of C: the serial dependency chain sets the pace.

## Development builds

The development build is Grail's native backend, the one the tests run: it exists to compile
quickly, as Go's compiler and Zig's debug backend do. Go has one build mode and appears here too.

{{perf:bench-rivals#dev}}

**Where it stands, and why.** Grail's development build takes less CPU time than Rust's dev profile
on all 19 programs and than Zig Debug on 18 of 19 (Zig Debug is ahead only on `ffi_call`, 2.00 ns
against 2.39 ns). Against Go it is ahead on `ecs` (0.77x), `ecs_par` (0.75x at 8 workers), `json` (0.88x) and `strings`
(0.95x), and within 1.2x on `dot_f64`, `fnv`, `matmul`, `sort` and `hashmap`, while trailing
furthest on `iterchain` (2.19x Go, down from 12.71x after targeted multi-round inlining flattened
the adapter chain into `SliceIter::fold`) and `chan` (1.93x Go). A vector or slice a loop does not change keeps its
data pointer and length in registers for the whole loop; an `f32` parameter is rounded once at entry
and the loop stays in single precision; a merge loop branches directly on its conditions. What
remains in the native backend's code:

- every element access is still checked, and loops test at the top and jump back unconditionally,
  where Go's are laid out tight;
- `nbody` (1.80x Go) keeps its bodies in a record and moves `f64` values between general and SSE
  registers on every step;
- in `iterchain` (20 rounds over 10M values, 0.29 s against Go's 0.13 s, beating Zig Debug's
  0.40 s and 7.8x faster than Rust dev's 2.26 s), targeted multi-round inlining now flattens the
  entire adapter chain (`map` -> `filter` -> `fold`) into one call-free loop inside
  `SliceIter::fold`, with remaining cost in checked arithmetic and scalar division by 3
  (docs/design/dyn-and-callable-bounds.md 7.2).

{{perf:bench-rivals#instructions|cpu}}

{{perf:bench-rivals#native-cpu}}

{{perf:bench-rivals#provenance}}

## Engine-shaped programs

Small kernels say what a loop costs; an engine is mostly other work. These eight programs are the
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
- `iterchain`: twenty rounds over ten million numbers through `map`, `filter` and a sum (Go uses
  range-over-func `iter.Seq` adapters; C and Zig have no iterator adapters, so their twins are the
  loop);
- `ecs`: a million entities as structure-of-arrays `f32` columns, each made at its full length and
  then filled, 600 frames of integration;
- `chan`: bounded channels between threads, one to one, many to one, many to many and a ping-pong
  of round trips (Rust's twin uses crossbeam-channel; C's, C++'s and Zig's are a mutex-and-condition
  ring).

{{perf:engine#release}}

**Where Grail stands**, read from the code of the commit charted. In release builds, `iterchain` (0.092 s against Zig's 0.095 s and C's/Rust's 0.096 s) and `chan`
(0.086 s against Go's 0.088 s and 2.8x faster than Rust's crossbeam-channel at 0.240 s) are the
fastest of the six; `hashmap` is 1.08x C (0.068 s against 0.063 s; C++'s `std::unordered_map`
takes 0.198 s, 3.1x C), `json` is 1.08x C++ (0.152 s, faster than Zig, Rust's `serde_json` and
C), `ecs` is 1.09x C (0.216 s against 0.199 s), and `strings` is 1.20x C++ (0.084 s, faster than
Zig, Rust, C and Go). What remains:

- **`chan` (0.086 s against Go's 0.088 s, 0.98x; 2.8x faster than Rust's crossbeam-channel at
  0.240 s).** Grail's channel uses crossbeam-channel's stamped-slot ring (compare-exchange per
  hand-off, spin, then yield, then park). Go runs both ends as goroutines on one scheduler and
  Grail on OS/pool threads, so the development build's CPU time, which counts the spinning side, is
  1.93x Go's.
- **`bintrees` (1.29x Zig; faster than C, C++, Rust and Go).** Allocating and freeing the nodes are
  about three fifths of the run; Zig's release allocator executes the fewest instructions.
- **`hashmap`: insertion order costs one memory touch.** Grail's map keeps its entries in insertion
  order in a dense vector beside the probe table, like Python's `dict` and Zig's `ArrayHashMap`, so
  a lookup reads the slot and then the key, where C's open-addressed table keeps keys in the slots.
- **`iterchain`:** in release builds the chain folds internally (`Map` and `Filter` override `fold`)
  into one loop with no calls, the fastest of the six at baseline x86-64, though it stays scalar where
  C's native-CPU build vectorises further (0.047 s).
- **`dyncall` (1.50x Zig, 1.23x C)** is bound by the indirect interface call.

{{perf:engine#dev}}

{{perf:engine#cpu|instructions}}

{{perf:engine#provenance}}

## Parallel loops

The `ecs` program above, run on several cores: the same million entities and 600 frames, the update
split across workers each frame, at 1, 4 and 8 workers. Grail runs the simulation inside a structured green task (`task_scope`, so `main` sleeps and
`GRAIL_WORKERS=W` uses strictly `W` threads total) using one `parallel_for_zip` over all six
columns per frame, in pieces of 16,384 entities; C uses OpenMP (`parallel for schedule(static)`),
C++ uses a persistent `std::jthread` pool synchronised with `std::barrier`, Rust uses rayon
(`par_iter_mut().zip(..)` over all six columns), Go spawns one goroutine per worker each frame, and
Zig uses a persistent `std.Thread` pool with `noalias` slices and an atomic sense-reversing
barrier. Every runtime uses strictly 1, 4 and 8 total threads and creates its worker threads once
before the 600-frame loop (except Go's goroutines). Each entity's arithmetic is independent and the
final sum is serial, so every program prints the exact serial checksum at any worker count, and the
tool verifies that it does.

A parallel loop is about wall time, so this chart is wall time, best of nine runs, with every
runtime given the same total thread count. Grail's release build scales cleanly from 1 to 4 to 8
workers: **0.229 s** at 1 worker (1.01x Zig's 0.226 s, ahead of C++ 0.248 s, C 0.262 s and Rust
0.276 s), **0.074 s** at 4 workers (tied with C's 0.074 s, ahead of C++ 0.081 s and Rust 0.101 s,
1.14x Zig's 0.065 s), and **0.063 s** at 8 workers (ahead of C++ 0.074 s and 1.6x faster than Rust
rayon's 0.102 s; 1.24x C's 0.051 s and 1.55x Zig's 0.041 s). It executes 4.8–5.0 billion
instructions against 3.8–4.5 billion in Zig/C/C++/Rust: every element access is marked unable to
alias a slice header, so LLVM hoists the data pointers and vectorises the callback 4-wide.

In development builds, Grail-native beats Go at 1 and 8 workers (0.79x and 0.75x Go, 1.12x at 4)
and is 3–6x faster than Zig Debug and 13–23x faster than Rust dev.

{{perf:parallel#release}}

{{perf:parallel#instructions|cpu}}

{{perf:parallel#provenance}}

## Compile speed

The target: Grail compiles faster than Go, Zig and rustc, and its development builds are ready
sooner than Zig Debug's, Rust's dev profile's and Go's; C and C++, compiled by clang and clang++,
are measured beside them.

To avoid skewing the overview with 100-line toolchain start-up, three 20-unit scaling projects are
measured across **20 Grail modules / Go packages / Rust Cargo workspace crates / C and C++
translation units** plus `main`:

- **`syn1000` (~26k lines) and `syn4000` (~104k lines):** flat monomorphic scaling — N copies of a
  record, constructor and 15-line loop function across `m0`..`m19`, with a one-constant edit in
  `m10`.
- **`app2000` (2,000 functions):** a **3-layer dependency DAG** (4 foundation units `base0..3` ->
  8 domain units `mid0..7` -> 8 service units `top0..7` -> `main`) using everyday idiomatic
  generics, interfaces/traits, `Option`/`std::optional`, and hash maps, with a mid-layer edit in
  `mid4` that downstream units depend on.

Every toolchain therefore gets realistic parallel compilation across 4 jobs and real incremental
builds:

- **Grail:** a `grail.toml` project with `src/main.grl` and `src/m0.grl`..`src/m19.grl`, checked
  with `grail check` and built with `grail build` through the build store (which writes line tables
  and function ranges by default, though not yet variable/type DWARF).
- **C and C++:** 21 translation units (`main` plus `m0`..`m19` with per-module headers) built by a
  `Makefile` (`clang -O0 -g -fuse-ld=lld` and `clang++ -std=c++20 -O0 -g -fuse-ld=lld`). `make -jN
  check` runs `-fsyntax-only` only on changed translation units; `make -jN` recompiles only `m10`
  and relinks on an edit.
- **Go:** module `syn` with 20 sub-packages `m0`..`m19`, checked with `go vet ./...` (`go build -o
  /dev/null .` is measured beside it below) and built with `go build -o syn .` (caching the 19
  untouched packages in `GOCACHE` on an edit).
- **Rust:** a 20-crate Cargo workspace (`crates/m0`..`crates/m19` plus root crate `syn`), checked
  with `cargo check --offline -q` and built with `cargo build --offline -q`, so Cargo gets
  cross-crate `-j4` parallelism and skips the 19 untouched crates on an edit.
- **Zig:** `main.zig` importing `m0.zig`..`m19.zig`, checked with `zig build-exe -fno-emit-bin` and
  built with `zig build-exe -O Debug -fno-llvm -fno-lld` (Zig's self-hosted x86-64 backend, which
  Zig 0.15+ makes the default for Debug builds and is 2.4–3.6x faster than 0.14's LLVM debug path).
  One-shot CLI invocations still recompile from scratch on an edit because Zig's incremental
  compilation keeps state in a persistent `zig build --watch` daemon rather than on-disk caches.

Single-file `hello` and the seven engine twins are also measured and shown in the detail tables
below, while the overview panels average the 6 build rows and 6 check rows of `syn1000`, `syn4000` and
`app2000`. Every toolchain's standard library cache is warm before timing (`grail cache warm`,
`GOCACHE`, `zig-cache`, offline Cargo registry). Two passes run: one process (`-j1` / `-p=1` /
`GRAIL_JOBS=1`) for deterministic user-space instruction counts, and four jobs for wall time.

{{perf:compile#compile}}

{{perf:compile#compile-wall}}

**Where Grail stands.** On both the 104,000-line flat project (`syn4000`) and the 3-layer generic
DAG (`app2000`):

- **Incremental edits:** On `syn4000`, Grail leads every language on builds (**0.63 G / 0.10 s**
  against C's 0.84 G / 0.16 s, Rust's 2.44 G / 0.34 s, Go's 6.34 G / 0.35 s, C++'s 2.87 G / 0.48 s
  and Zig's 16.72 G / 1.69 s). On a mid-layer edit to `mid4` in `app2000`, Grail (**0.92 G / 0.13 s**)
  and C (**0.76 G / 0.13 s**) lead, ahead of Go (0.18 s), Rust (0.18 s), C++ (0.35 s) and Zig
  (1.00 s). On edited check, Grail leads both (`syn4000` **0.03 s**, `app2000` **0.03 s**).
- **Cold checks:** Grail leads all six 4-job wall-time check rows (`syn4000` **0.20 s**, `app2000`
  **0.14 s**), ahead of C (0.24 s / 0.15 s), Zig (0.29 s / 0.22 s), Rust (0.91 s / 0.36 s) and C++
  (1.60 s / 0.62 s).
- **Cold builds:** **Go has the fastest 4-job wall time on all three cold builds** (`syn1000`
  **0.25 s**, `syn4000` **0.64 s**, `app2000` **0.34 s** — 2.4–3.1x faster than Rust's 0.69 s /
  2.00 s / 0.81 s), followed by C (0.29 s / 0.80 s / 0.38 s) and Grail (0.29 s / 1.26 s / 0.57 s),
  ahead of Rust (0.69 s / 2.00 s / 0.81 s), Zig (0.70 s / 1.65 s / 1.00 s) and C++ (1.74 s / 2.80 s
  / 1.06 s). In single-process CPU time, Zig's self-hosted backend is actually the fastest on
  `syn4000` cold (2.12 s / 17.49 G), but scales only ~1.25x across 4 cores and recompiles from
  scratch on one-shot CLI edits.
- **Debug-info trade-off:** Default `grail build` runs the native optimiser and writes line tables
  and function ranges (so dev binaries run 5x faster than Rust dev and 2.6x faster than Zig Debug).
  Running `grail build --debug` turns the optimiser off and emits full variable DWARF too — on
  `syn4000`, cold `grail build --debug` takes **0.44 s** (2.6x faster than default `grail build`
  at 1.23 s, and faster than Go's 0.73 s and C's 0.79 s), though `--debug` does not yet reuse the
  incremental build store on edits.

The chart is the release compiler of the commit named, built with ThinLTO and profile-guided
optimisation.

{{perf:compile#compile-go-check}}

{{perf:compile#compile-cpu}}

{{perf:compile#provenance}}

## The scheduler

Joins, spawns, `fib(32)` by nested join, and a simulated game frame loop: 32 systems as jobs, a
parallel pass over a million elements, an I/O task and a background importer, against twins on
rayon and on oneTBB (built with `clang++ -O2`, matching the LLVM backend of Rust and Grail-LLVM so
serial `fib(32)` is comparable across all three). These are wall-clock times measured inside each
program, the median of 9 rounds. The importer row counts how much work the importer got done, so
higher is better there.

{{perf:sched-rivals#scheduler}}

**Where Grail is ahead, and where it is behind.** Grail's release scheduler is the fastest of the
three on `join` from the main thread (146 ns against oneTBB's 275 ns and rayon's 8,700 ns), `join`
on a worker (132 ns against rayon's 215 ns and oneTBB's 292 ns) and `frame max` (1.11 ms against
rayon's 1.45 ms and oneTBB's 1.76 ms), and is within 3% of rayon on `frame p99` (0.60 ms against
0.59 ms; 0.58 ms at 24 workers, beating both). Its Frame class runs ahead of the importer, as
oneTBB's high-priority arena does and as rayon, which has no priorities, cannot. A worker that goes
idle is woken by name, so a burst of forks wakes one worker rather than one per fork. Behind:

- **Nested `fib(32)` join (813 us from main / 793 us in a task against rayon's 439 / 339 us and
  oneTBB's 496 / 403 us).** With `clang++ -O2`, serial `fib(32)` is close across all three
  (4.10 ms Grail-LLVM, 3.62 ms rayon, 3.73 ms oneTBB), so the remaining ~2x gap on nested join is
  real scheduler overhead: each Grail `join` currently makes heap allocations for its closures and
  second result, whereas rayon and oneTBB place joined jobs on the caller's stack with zero heap
  allocation.
- **Spawn-and-wait (648 ns against oneTBB's 317 ns) and burst of 100k spawns (276 ns against
  oneTBB's 201 ns, faster than rayon's 954 ns).** A task scope on the main thread spawns onto a
  single deque, so 24 workers contend stealing one task at a time from that deque.
- **I/O task worst lateness (481 us against rayon's 214 us and oneTBB's 221 us).**
- **The importer gets fewer rounds by design (3,369 against oneTBB's 5,224).** At most a quarter of
  the workers run Background work, where oneTBB lets its low-priority arena take every idle thread.

{{perf:sched-rivals#provenance}}

The design notes behind each row, with the generated code that names each cause, are
`docs/design/runtime-parity.md` and `docs/design/compile-speed.md`.
