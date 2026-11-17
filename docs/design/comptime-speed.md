# Compile-time evaluation at build speed

Status: **proposal** (2026-11-16), branch `gaps12-statics-impl`. Nothing is built. Target, from the
director: 100 run-tier values in a module within one second of extra compile time on this machine,
and a warm rebuild that runs no probe.

## 0. Decisions for the owner

| # | Decision | Recommendation |
|---|---|---|
| R1 | Remove nesting: may a probe compile ever start another probe? | **No.** Inside a probe, a read of a run-tier value that is not known yet calls its initialiser (lazily, once, cycle-checked) instead of resolving it with a nested probe. This alone turns N values from N nested whole-program compiles into N flat ones, and removes the 8-deep limit and the rerun explosion. |
| R2 | One probe for all values of a build? | **Yes** (candidate a, per build rather than per module): every run-tier value a build needs that the cache cannot answer is computed by one probe, which prints them all. N values cost one compile, one link and one run. |
| R3 | Cache key | **The initialiser's call and the bodies it reached** (candidate c), recorded by the probe, checked on the next build against the current sources, instead of today's "the probe text and every input file". An edit outside what a value reaches runs no probe. |
| R4 | Compile only what is reachable (candidate b)? | **Later, measured.** With R1-R3 the probe compile is one per cold build and mostly the runtime and core, which the function cache already replays; (b) matters for very large programs and needs the reachable set before the compile. |
| R5 | An evaluator inside the compiler (candidate d)? | **Not now.** It would save the link and exec (0.11 s of a probe) but not the compile, which is the cost; R1-R3 meet the target without a second implementation of the semantics. |
| R6 | Probe-mode error handling | **A failing probe compile reports once and stops**: no "report the next error" reruns inside a probe (they are what turned depth 9 into a hang). |

## 1. What it costs today (measured)

Machine: this host, x86-64 Linux; the natively built compiler of this branch (`tools/native.mjs
build`, the one the tests use); programs of N statics `static Vk: u64 = @fk();`, each `fk` a 10-20
iteration loop; fresh `.work` (the probe cache) per cold run; a logging `GRAIL_CC` counts probes
(one link each); `GRAIL_COMPTIME_DEPTH` names the depth.

**End to end** (`grail run FILE --no-cache`):

| N | cold | probes | depth reached | warm, unchanged | warm, after adding an unrelated function |
|---|---|---|---|---|---|
| 0 | 1.33 s | 0 | - | 0.66 s | - |
| 1 | 1.12 s | 1 | 1 | 0.60 s | - |
| 2 | 1.64 s | 2 | 2 | 0.62 s | - |
| 4 | 2.83 s | 4 | 4 | 0.64 s | - |
| 8 | 6.5-7.5 s | 8 | 8 | 0.97-1.11 s | 6.72 s, 8 probes |
| 12 | > 240 s, killed | 0 linked | 9+ | - | - |

**One probe, by stage** (the probe for `V0`, run by hand with the compiler's own command line):

| stage | time |
|---|---|
| compile the probe (= the whole program + runtime + core: 1.25 MB of assembly), nested values cached | 0.86 s |
| same, with the per-function cache warm (`--fn-cache`) | 0.22-0.26 s |
| link (`cc -nostdlib -static`) | 0.11-0.13 s |
| run | 0.003 s |
| for scale: a plain compile of a trivial program (runtime + core only) | 0.70 s |

**Where the time goes.**

1. **Nesting.** A probe compiles the whole program, and the whole program reads (or, for statics,
   emits) the other run-tier values, each of which it resolves with a probe of its own. The
   values form a chain: the probe for V0 compiles a program that needs V1, whose probe needs V2,
   and so on - probe k runs at depth k. Each value is linked once (N probes), but the compiles are
   serialised down the chain: cold time is N x (compile + link), about 0.9 s per value.
2. **The depth limit and the reruns.** Past depth 8 the nested compile fails ("compile-time calls
   nest more than 8 deep"), and a failing compile re-runs itself with a body skipped to report the
   next error, up to 20 times (`next_error`, compiler/native.grl). Inside a probe each rerun
   repeats every nested probe below it, so the failure multiplies through the levels: N = 12 had
   linked nothing after 240 s (process tree: chains of `--skip-body` reruns at every level).
3. **Per probe, the compile is the cost**: 85% compile, 12% link, under 1% run. And the compile is
   mostly the runtime and core, which every probe compiles again (a trivial program alone: 0.70 s).
4. **The cache key is everything.** A value is keyed by the probe text and the bytes of every input
   file, so an unchanged rebuild runs no probe (0.97 s for N = 8), but adding one unrelated function
   reruns all of them (6.72 s).

## 2. The candidates, measured or estimated

| | what it removes | cost for N = 100, cold | warm after an unrelated edit | effort, risk |
|---|---|---|---|---|
| today | - | not finite (N > 8 hangs) | all N probes again | - |
| R1 alone (no nesting) | the chain and the explosion | N x ~1.0 s flat (100 s) | all N | small: probe-mode reads become lazy calls |
| (a) one probe for all (needs R1) | N-1 compiles and links | 1 x (0.25-0.62 compile + 0.12 link) + work = **0.4-0.75 s** | one probe | medium: collect every pending value before the third pass |
| (c) precise key | probes for unchanged values | as (a) | **no probe** unless an initialiser or a body it reaches changed | medium: record the reachable bodies' text hashes with each value |
| (b) reachable-only compile | the program's unrelated bodies from the probe compile | as (a), minus the program share of the compile | as (a)+(c) | medium-high: needs the reachable set before compiling; the runtime and core still compile (replayed by the function cache) |
| (d) in-compiler evaluator | link and exec (0.12 s), process spawns | still needs the bodies compiled; saves ~0.12 s once | as (c) | high: a word-machine interpreter (the closed instruction set machine.grl lowers: ~1500-2500 lines), a heap model, the effect refusals, and a second place the semantics can drift |

The 0.4-0.75 s for (a) is today's single-probe numbers: 0.62 s compile with a cold function
cache, 0.22-0.26 s with a warm one, plus the link; 100 trivial initialisers add milliseconds of
run time. That meets "100 values within one second" on the natively built compiler; the release
compiler (LLVM-built) compiles several times faster again.

## 3. The design (R1-R3, R6)

**R1 - a probe never starts a probe.** In `--comptime-probe` mode:

- A read of a run-tier **static** that has no value yet compiles to a guarded lazy initialisation:
  the static's storage is a writable word in the probe (`.data`), 0 until set; the read tests it and,
  if 0, calls a wrapper the probe source defines (`fn grail_init_k() -> T { return M::f(args); }`,
  generated beside the probe's `main` exactly as the probed call is today) and stores the owned
  result. A second word marks "being initialised", so a read during its own initialisation calls
  `rt_comptime_cycle` - the cycle error the runner already reports. The probe is single-threaded,
  so no once-guard is needed.
- A read of a run-tier **constant** compiles to a call of its wrapper each time (a constant is a
  value at every use; a table or a string is a fresh copy, as it is at run time).
- The probe's entry skips the end-of-main leak check: values it built are kept on purpose.

The probe therefore computes every value it needs itself, from source, in one process. There is no
depth, no 8-deep limit and no nested compile.

**R2 - one probe per build.** At the end of the second pass every run-tier initialiser is known
(constants record their call text in the first pass, statics their position in the second;
`@f(...)` in a body is found by scanning bodies' tokens for `@ident(`). The compiler asks the cache
for each (R3); the misses go into one probe whose `main` computes and prints each in a framed form
(`static_dump_src` already prints any baked type; the frame adds the value's key), in declaration
order. The third pass then reads values from the table instead of resolving them one by one.

**R3 - keyed by what the value depends on.** The probe compile knows, from the effect call graph
it records anyway (`fx_edge`), the bodies each initialiser reaches. A cache entry is the value plus
its dependencies: the initialiser's call text, the declaration surface hash (`fn_surface_now`:
types, layouts, signatures, constants), and the source-text hash of every body reached. On the next
build an entry is valid when all of those hash the same in the current sources (the compiler has
every body's span; this is the per-function cache's own key material, `fn_key`). A body edit that
no initialiser reaches, or a new function, invalidates nothing. Entries live in the build store
beside the function cache, not in the working directory.

**R6 - one report.** A probe compile is run with the multi-error reruns off; the outer compile
reports "`f()` did not compile" with the probe's first error.

## 4. Stages, with what each must show

1. **R1 + R6.** Cases: 100 run-tier statics and constants in one module compile and print (today:
   hangs); a cycle through two statics still fails as a cycle; a value that fails to compile reports
   once. Measure: N = 8, 25, 100 cold.
2. **R2.** One probe per build whatever N. Measure: N = 100 cold, target under one second over the
   same program without run-tier values.
3. **R3.** Cases: an unrelated edit runs no probe (pinned by a probe counter the driver reports); an
   edit to a body an initialiser reaches runs exactly one probe; an edit to a type the value's
   function uses invalidates it. Measure: warm after an unrelated edit, target zero probes.
4. **(b), only if large programs show the probe compile as the cost.** Measure the probe compile on
   the largest program in the tree (the compiler itself) before deciding.
