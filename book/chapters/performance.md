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

**Why Grail is behind**, read from the code of the commit charted:

- **`iterchain`: the adapters are not types.** `Iter<T>` is the erased form: every element is a call
  through a boxed closure returning an option, once per adapter, and nothing inlines through it.
  Rust's chain compiles to the same loop as the hand-written one. Making the adapters types with
  callable bounds is the plan in `docs/design/dyn-and-callable-bounds.md`.
- **`hashmap`: a bucket is a vector.** The standard map chains collisions through a `u64[]` per
  bucket and keeps its entries in insertion order in a second vector, so a lookup reads the
  bucket's own header, then an index, then the entry; growing the table rebuilds every bucket
  vector. Rust's, Go's and Zig's maps are one open-addressed table. (Since replaced: the map is
  now dense entries under one open-addressed index, hashed with SipHash-1-3 as Rust's is.)
- **`ecs`: owned vectors re-read their headers.** The update loop stores through six vectors made
  in the same function, and after each store the next access reloads a length and a data pointer
  and checks the index, so the loop stays scalar where C, Rust and Zig vectorise it.
- **`dyncall`: two calls per dispatch.** Each slot of an interface object's table is a small thunk,
  emitted outside the optimised module, that loads the boxed value and calls the method; neither
  call can be inlined.
- **`strings`: every piece is a new string.** `split` returns owned copies of every line and every
  field, and `format` builds a new string per record, where Rust's and Zig's splits hand out slices
  of the input. The standard library also has no float parser (the JSON module carries one
  privately), so the Grail twin parses a two-decimal number as hundredths over 100.0. (Since
  replaced: `split` hands out views, `parse_f64` is shared with `json`, and `append_format` writes
  into the output; a view is still a small allocation of its own.)
- **`json`**: behind by a similar margin to the dynamic-value parsers of the other languages; where
  its instructions go has not been profiled yet.
- **`bintrees`** is where Grail does best: its allocator's fast path makes it execute fewer
  instructions than C with `malloc` and Rust with `Box`. Zig, with its general-purpose allocator for
  release builds, executes the fewest.

{{perf:engine#dev}}

{{perf:engine#cpu|instructions}}

{{perf:engine#provenance}}

## Compile speed

The same programs in four languages: hello world, and N copies of a record, its constructor and a
15-line loop function, for N = 1000 and 4000. Each is checked and built, cold and after one
function body changes. Go has no check command (`go vet` runs analyses, not the type checker's
verdict), so its check is a build whose output is thrown away.

{{perf:compile-rivals#compile}}

When the chart counts instructions rather than time, work that Grail spreads over forked workers
counts in full: a check of the largest program at four workers executes about a third more
instructions than the same check in one process, though it finishes sooner.

**Why it is behind.**

- **An edited check checks everything again.** `cargo check` is incremental; `grail check` is not
  yet, and it also checks the runtime and the core library from source every time.
- **The checker is one thread.** On the 104,000-line program Zig checks in about half the time,
  also on one thread; about a third of Grail's front end is allocation.
- **A build writes assembly text and parses it again.** For the large program the compiler writes
  35.6 MB of assembly, and clang spends a quarter of the build's CPU time assembling it. Writing
  object code directly is planned.
- After an edit, every unchanged function body is replayed from the build store, but the back end
  and the assembler still go over the whole module.

{{perf:compile-rivals#compile-instructions|compile-cpu}}

{{perf:compile-rivals#compile-wall}}

{{perf:compile-rivals#provenance}}

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
