# Round history: the gaps round

This is a record of what was attempted and what it cost, not a feature list. The features are in
CHANGELOG.md and the book; this file exists so the next person does not repeat the mistakes.

## What the round was

The backlog was twenty-odd items across the compiler, the language, the stdlib, tooling, the
runtime and C interop. They were split into one workstream per item, one worker per workstream, one
git worktree each, all branched from `origin/gaps-int2`; integration happened on a branch, in
batches, with the gate deciding when a batch could become `main`.

## What the process got right

- One worktree per workstream meant a worker could not break another's tree, and branches could be
  merged in any order. Nearly every branch arrived green on its own tests.
- "Never weaken a check to go green" was the rule that produced the best work: the effects worker
  found that a claim on a generic had never been checked at all, the honest-workshop case in the
  optimizer turned out to be a latent miscompile of frame constants, and the interface worker's
  round-trip test caught three writer/reader disagreements in its first day.
- Asking each worker to prove a thing rather than assert it produced the round's strongest
  evidence: byte-identical assembly for the optimizer and IR changes, a zero-delta instruction count
  for the two-word slot work, a self-hosting fixpoint for anything that changed the compiler.

## What the process got wrong

1. **Merging into a worktree the director was gating.** Twice. The gate reads the tree it is
   gating, so a merge during a run means the run certifies a tree that no longer exists. The cost
   was two discarded multi-hour gates. The rule that came out of it: one driver per gated worktree,
   and a gated tree is frozen until the gate reports.
2. **Running two reseeds at once.** A seed-publishing run writes `compiler/bootstrap` and the
   staging area; two of them mean a mix, and a mix is worse than either. The cost was an hour and a
   near-miss on publishing a bad seed. The rule: check for a running reseed before starting one.
3. **Running a test suite twice in one checkout.** `tools/interface-test.mjs` used a single shared
   work directory per target and wiped it at start, so a second run deleted the first's interfaces
   mid-run and produced a "compiler bug" (`has no interface for module 'lexer'`) that cost three
   hours of investigation before it was identified as self-inflicted. Fixed in the tool (one work
   directory per run), but the lesson is general: a test harness that mutates a fixed path cannot be
   run concurrently, and a race that presents as a compiler bug is expensive precisely because it
   looks like one.
4. **Trusting a reported bug without reproducing it.** A reported `u32` FFI parameter bug turned out
   not to reproduce at all (the reporting worker had used a stale binary), while the investigation
   found a real bug next door (a C callback entry accepting a byte view that C passes in two words).
   The cost was a day of one worker; the lesson is that "reproduce first" belongs in the brief, and
   it was added to later briefs.

## Things that were slower than they looked

- Reseeding. Three targets, two of them emulated, is 2-3 hours on a loaded host; a batch that
  changes compiler sources pays it, and a batch whose own syntax the seed cannot read (named/default
  arguments) needs a fixpoint compiler as stage 0. Preserve that binary outside `.work` — see
  docs/testing.md, "A build artifact a step depends on is an input".
- Cross-target corpus legs. Nine native legs and six emulated ones; at GATE_JOBS=1 a full gate is
  six hours. Running the legs in parallel is what got them OOM-killed.
- The interface suite. It compiles ~195 corpus programs twice plus the compiler itself, so it is
  40-50 minutes and it is the leg that dominates the tool phase. Splitting the compiler-as-program
  section into its own tool is the obvious next improvement.

## What was deliberately left for the next round

Each of these is a real improvement that did not fit, and each is recorded with the reason:

- Typed-IR stage 3: the IR reader and the per-function codegen cache. The serializer and its format
  are landed and tested; the reader is the half that can disagree with the writer, so the cache key
  is the digest of the parsed structure re-serialised, and a unit whose text does not round-trip is
  a refusal.
- The effects count move that replaces the last text scan was landed in two parts rather than one,
  because a `.proved` entry replays a byte copy of the entry prologue and the parsed stream holds
  those calls twice; the replay range had to reach the IR first.
- An LLVM site table. The statement tables are a native-backend contract today (`--backend=llvm`,
  `--debug`, `--split` and macOS emit none), which is why several containment and backtrace cases are
  scoped to native. Emitting them on LLVM needs the `.gpos` markers to reach the lifter and a
  frame-pointer contract; the corpus says so in the case notes.
- `pool-chunks-mut-timing` is load-sensitive: measured 8/20 aborts under load, identical across
  source/interface/verify builds. The honest reading is that in-place mutation is 1.26x cheaper than
  building owned values against a 1.33x threshold, i.e. a performance finding, not a flaky test. Do
  not lower the constant; make the code faster or measure a median over interleaved rounds.
- SIMD: designed (docs/design/simd.md), not implemented — it needs a 16-byte ABI class through the
  register allocator, and the cheap alternative is a pointer API that is not really SIMD.
- Windows: SChannel TLS and sockets on the IOCP reactor are refused, not half-done, with the reason
  written in the notes.

## Found during the endgame, for the next round's list

Three things that only appeared once the gate was run to the end, all worth naming because each is a
class rather than an incident:

- **A tool that writes a fixed temporary path under `.work` breaks when legs run in parallel.**
  `buildCompiler` named its intermediates after the hash of its inputs, so two tool legs that built
  the compiler in one worktree wrote the same `compiler.s` and `grail.pending.o`; interface-test died
  in clang with "no preprocessable inputs" and windows in ld with "cannot open ...grail.pending.o",
  both inside `command()` where they look like a broken build rather than a collision. Fixed by
  naming the intermediates after the process and claiming the final name with an atomic rename, which
  is also what makes `GATE_JOBS > 1` safe. The rule generalises: any path under `.work` that is not
  unique per process is a race waiting for a parallel gate.
- **Windows ARM64 has unwind records but no `.set .F<n>` frame-constant table.** Checks that assume
  the x86-64 frame-constant table must be scoped to x86-64; the first two attempts got that wrong in
  both directions (assuming the table everywhere, then dropping the check entirely). The honest form
  tolerates its absence on ARM64 and keeps every other check.
- **A suite that stops at its first failure hides the rest of its bugs.** The windows suite had never
  run past its first red in this round, so three separate case bugs — `io::Error` where the stdlib
  now answers `fs::Error`, a named module missing its `entry`, and the frame-table assumption — all
  surfaced at once in the endgame. Running the whole suite early, even with known reds, is cheaper
  than finding them one gate at a time.
