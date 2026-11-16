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
others. Times are CPU time from `getrusage`, the best of several runs, because the machine they run
on is shared.

## Release builds

The release build is Grail's LLVM backend: the compiler's own code lifted to LLVM IR and compiled
with `clang -O2`, with integer overflow wrapping, as Rust's release profile does.

{{perf:bench-rivals#release}}

**Where Grail is behind, and why.** In every row it misses, the cause read from the generated code
is the same. Each iteration re-reads a vector's length and data pointer from its header and keeps
the bounds check inside the loop, because the IR given to LLVM does not say that a store through
the data cannot change the header. A loop whose checks cannot be hoisted cannot be vectorised
either, which is why `xform` stays scalar where C, Rust and Zig emit packed SSE.

- `nbody` is also missing a language feature: Grail has no fixed-size array type, so "15 doubles"
  cannot be stated in a type, and nothing can unroll on it the way Zig does. C with its arrays moved
  to the heap is as fast as with fixed arrays, so the heap itself is not the cost.
- The `xform` rows have a fix on the float branch: with `gaps12-float` (descriptor fields read once,
  element addresses as `getelementptr`), `xform_f32` goes from 5.6x to 1.19x and `xform_f64` to
  1.07x. The chart shows the commit it measured.
- Where the time is at parity (`fnv`, `dot`), Grail still executes 1.2x to 1.9x the instructions
  of C. The serial multiply or add chain sets the pace and hides them; a loop with more independent
  work would not.

## Development builds

The development build is Grail's native backend, the one the tests run: it exists to compile
quickly, as Go's compiler and Zig's debug backend do. Go has one build mode and appears here too.

{{perf:bench-rivals#dev}}

**Why it is behind.** Grail's development build beats Rust's dev profile on every program and
loses to Zig Debug and Go on all of them except the foreign call. The native backend's code shows
three causes:

- a widening integer conversion is a call into the runtime (in `fnv`, once per byte: about 107
  instructions per byte against Go's 11);
- `f32` arithmetic goes through `f64` and back on every operation;
- loop variables live in stack slots, and every access is checked against a length read again
  from memory.

{{perf:bench-rivals#instructions}}

{{perf:bench-rivals#native-cpu}}

{{perf:bench-rivals#provenance}}

## Compile speed

The same programs in four languages: hello world, and N copies of a record, its constructor and a
15-line loop function, for N = 1000 and 4000. Each is checked and built, cold and after one
function body changes. Go has no check command (`go vet` runs analyses, not the type checker's
verdict), so its check is a build whose output is thrown away.

{{perf:compile-rivals#compile}}

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
