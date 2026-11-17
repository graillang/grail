# Compile-time evaluation in the compiler (CTFE)

Status: **design, not built** (2026-11-17). The long-term replacement for run-tier probes where a
probe is the wrong tool: `grail check`, and statics in the compiler's own sources.

## Why

A probe compiles, links and runs a program (comptime-speed.md). After R1-R4 and the probe base it
costs about 0.1 s per recomputed value, but it still needs a linker, a writable work directory and a
process per batch, and it cannot run where the compiler is compiling *itself* (the lint forbids
run-tier values in `compiler/*.grl`, because a cold build of the compiler would compile the compiler
in a probe). Zig and rustc evaluate in the compiler instead: Zig interprets its typed IR (Sema), and
rustc's Miri-derived interpreter evaluates MIR with an abstract heap.

## What

An interpreter over the checked IR the optimiser already reads (`ir.grl`: typed, after ownership and
refinement checking), run by the compiler after pass 3 for every run-tier value whose reach the
interpreter supports, with the probe as the fallback for the rest.

- **Values**: words (integers of every width, bools), pointers into an abstract heap of blocks
  (vector, string, record, enum payload) with the runtime's layouts, so a result is baked exactly as
  `static_bake` bakes a probe's result today.
- **Semantics**: the native backend's, not a second definition. Integer operations reuse the
  folder's helpers (`literal_fits`, wrapping ops) and follow the build's `--overflow` mode; a failed
  check (overflow, bounds, division, unwrap, a refined parameter) stops evaluation with the same
  message and source location the runtime would print, so `check` and `build` agree by construction.
- **Allocation**: an abstract heap with a step and byte budget (the probe's 30 s limit becomes
  "N steps / M bytes"); exceeding it is an error naming the value.
- **Effects**: no host calls at all. A call into `host::`, an extern, `dyn`, a closure value or inline
  assembly is "not evaluable": the value falls back to a probe (or, in `check` and in the compiler's
  own sources, is an error saying why).
- **Cycles**: the evaluator keeps the values being computed on a stack and reports the same cycle
  message as R1.
- **Caching**: R3's key unchanged (call text, reached bodies, declarations, compiler, target); the
  interpreter is just another way to fill an entry.

## Cost and correctness

The subset needed first is small: integer and bool arithmetic, `if`/`while`/`for`, calls,
vectors/strings (push, index, len), records and plain enums - what the corpus's run-tier values and
the compiler's own tables use. Estimated 1500-2500 lines in a new `compiler/ctfe.grl`.

Keeping it equal to native semantics is the risk. The plan is to differential-test: every corpus
case with run-tier values is evaluated both ways under `GRAIL_CTFE_VERIFY=1`, and any difference is a
failure (the pattern `GRAIL_ASM_UNITS_VERIFY` uses for the assembler).

## Stages

1. Integers, bools, control flow, direct calls; differential mode; corpus cases.
2. Vectors, strings, records, enums; baking from the interpreter's heap.
3. `check` uses CTFE only (no probe): a value it cannot evaluate is an error naming the construct.
4. The lint relaxes for `compiler/*.grl`: a run-tier static whose reach CTFE supports is allowed, and
   `cli.grl`'s flag table becomes one.
