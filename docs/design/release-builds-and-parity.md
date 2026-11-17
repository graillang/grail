# Release builds and release parity

Status: proposal (items 5 and 6 of the float assignment), nothing implemented. Branch `gaps12-float`.
**[V]** marks a claim verified in this tree (file:line or a probe), **[A]** an assumption.
Machine: Ryzen 9 7900X, clang 23.1.4, under heavy shared load; timings ±25%.

## 0. Decisions for the owner

| # | Decision | Recommendation |
|---|---|---|
| R1 | What `--release` means | LLVM backend + `clang -O2` per module through the store, overflow wraps by default, no other semantic change. |
| R2 | Overflow precedence | build-mode default < a package's `overflow` manifest key < `--overflow=` on the command line, except that a package that *pins* `overflow` keeps it for its own modules (see 2.3). |
| R3 | Runtime-error locations in release | Messages stay, `--> file:line` is lost in v1 (the site table is a native-stream artefact); restored later from LLVM debug locations. |
| R4 | Release on macOS / Windows | Refused with a message in v1, no silent fallback to native. |
| R5 | Release parity mechanism | One front-end fact - *this sequence's descriptor does not change here* - consumed by the LLVM lifter (load once, real pointers) and by the text optimiser (hoist the header loads). Not `--range-facts`. |
| R6 | `--range-facts` | Keep behind its flag until R5 lands, then delete it if it removes nothing R5 does not. |

## 1. What exists

- **[V]** `--backend=llvm` is an option of the compiler proper; the driver refuses it and says so
  (`compiler/cli.grl:3331`). `tools/native.mjs compileProgram` is the only path that builds with it:
  one whole-program compiler run, then `clang -O2 -c X.s.ll` and a link of both objects.
- **[V]** The compiler accepts `--backend=llvm` together with `--separate --emit-interface --no-entry`
  for one module and writes `m.s` and `m.s.ll` (probe `.work/f/sep`). So per-module LLVM units need
  no compiler change, only driver work.
- **[V]** The driver's per-module build (`per_module_build`, `cli.grl:1793`) copies the whole
  command's flags into every unit's compile command, adds `--use`, `--use-named`/`--use-module`,
  `--emit-interface`, `--separate`, `--fn-cache`, and runs `unit-build` = compile then assemble
  (`unit_build_command`, `cli.grl:1766`). Unit keys (`unit_key`, `cli.grl:1531`) hash the target,
  `id.flags` (the command's flags), the compiler digest, the assembler, the sources and the
  interfaces read.
- **[V]** Overflow mode travels as bit 16 of `flags` (`compile_mode`, `cli.grl:983`) and becomes
  `--overflow=wrap` on the compiler command (`cli.grl:868`). An interface file's header records the
  mode (`native.grl:41159`) and a build of the other mode refuses it (`native.grl:42480`).
- **[V]** `effects_claimed` (`cli.grl:285`): any source mentioning `@no_alloc`/`@no_panic` forces a
  single compiler run (`cli.grl:1087`), because the proof covers every reachable body.
- **[V]** The runtime-error location table (`grail_sites`) is built only when
  `site_table_on` = native backend, no `--debug`, no `--split`, not macOS (`native.grl:2245`). It is
  6% of the bench binary (126 KB of 2.1 MB) and 1.29 MB of the 27 MB compiler (`size -A`).
- **[V]** The manifest's `[package]` keys are a closed list (`package_key_ok`, `pkg.grl:2001`):
  name, version, grl-version, entry, description, ...; no build settings.
- **[V]** The LLVM backend now builds and runs on aarch64 and riscv64 (merged
  `origin/gaps12-llvm-targets` d9e211f: weak entry thunks stay weak - the `changed binding to
  STB_GLOBAL` assembler error - and `-mno-outline-atomics` - the undefined `__aarch64_cas8_acq_rel`).
  The float matrix passes with `GRAIL_BACKEND=llvm` on all three.

## 2. `grail build --release` (item 5)

### 2.1 What the flag means

`grail build --release`, `grail run --release` and `grail test --release` (a project's tests; in the
Grail tree it forwards to `test-native.mjs`, which already has `GRAIL_BACKEND=llvm`):

1. every unit is compiled with `--backend=llvm` and its `.s.ll` with `clang -O2 -c` (the same
   triple and `-march` rules `compile_mode` already picks; riscv64 `-march=rv64imafd -mabi=lp64d`);
2. the default overflow mode is `wrap` (2.3);
3. nothing else changes in meaning: the same checks (bounds, refinements that were not proved,
   checked conversions) stay, and their failures stop the program the same way.

Not part of `--release`: `--range-facts`, `--verify-facts`, `-ffast-math`, a different allocator.
`--release --debug` is refused in v1 (the lifter has no line info); `--release --split` is refused
as today's `--split` is with the LLVM path.

### 2.2 Per module, through the store

- `unit_build_command` grows a third step when the compile command has `--backend=llvm`:
  `clang <triple> -O2 -c stem.s.ll -o stem.ll.o`. The unit's result is two objects (`stem.o` from
  the lifted file's data and non-lifted parts, `stem.ll.o`), both stored and restored by
  `unit_restore`, both on the link line.
- The key: `id.flags` already contains the command's words, so `--backend=llvm` and the overflow
  word change it. Make it explicit rather than incidental: `unit_key` gets lines
  `backend native|llvm`, `overflow checked|wrap` (the unit's own, 2.3) and `opt O2`, and the
  assembler identity for an LLVM unit includes clang's version, since clang is now the optimiser
  and a new clang changes the object. Program key (`cache_program_key`) the same.
- The per-function codegen cache (`--fn-cache`) caches native-stream bodies; an LLVM unit skips it
  in v1 (a unit hit still applies). **[A]** the lifter needs the whole unit's stream for its
  facts; per-function caching of `.ll` is a later item.
- `--use-named`/`--use-module` are unchanged: interfaces describe types and signatures, which do
  not depend on the backend. An interface written by a native unit is readable by an LLVM unit and
  the other way round (the header gains no backend field).
- `@no_alloc`/`@no_panic`: release does not make it worse. Such a program is still one compiler
  run, now `--backend=llvm` whole-program followed by one `clang -O2` of the one `.ll` - the path
  `tools/native.mjs` uses today. The cost is clang's time on a large `.ll` (no parallelism); the
  fix is the same as for native (per-module effect summaries), not a release concern.

### 2.3 Overflow: default, manifest key, flag, dependencies

- **Default**: development `checked`, release `wrap`.
- **Manifest**: `[package] overflow = "checked" | "wrap"` (new key in `package_key_ok`, a string
  with exactly those values, refused otherwise).
- **Flag**: `--overflow=checked|wrap` on the command line.
- **Precedence per module**: the module's package pins it if its manifest has the key; else the
  flag if given; else the build mode's default. Rationale for letting a pin beat the flag: a
  package that sets `overflow = "wrap"` does so because its arithmetic is modular (a hash, a PRNG,
  a codec) and is wrong under `checked`; a package that sets `checked` is asking for its
  invariants to be enforced even in release. The flag is for the program's own code and for
  packages that expressed no preference. (Owner decision R2: the alternative is "the flag beats
  everything", simpler but able to break a wrap-pinned dependency.)
- **How it reaches the compiler**: per module, the driver knows each group's package from the
  resolver (`pkg.grl` gives each dependency a module root) and writes `--overflow=` on that
  unit's command. In a single-run build (no store, `@no_alloc` programs, `--no-cache`) the compiler
  needs a per-module table instead: `--overflow-module NAME=wrap` (repeatable), and `c.overflow`
  becomes the mode of the module whose function is being emitted.
- **Generics** (your position, which I share): a body has the mode of the module that *wrote* it.
  The interface's template row carries `overflow`; an instantiation in module B of a template from
  module A is emitted with A's mode. Front-end change: `c.overflow` is saved and set around the
  emission of each specialisation from its template's row, as it is around each module in the
  single-run case. Inlining across modes cannot happen today (the optimiser inlines within a unit)
  **[A]**; if it ever does, the inlined body keeps its own checks, which is what the text already is.
- **Interface header**: keep the field as the module's own mode (it is input to the unit key, and
  `grail check --interface` should still say what it wrote), drop the refusal in
  `native.grl:42480`. Must land with it: the prover no longer reading the mode
  (`gaps12-prover`, as you say) - today offset facts are read only in checked builds, so a mixed
  build would otherwise prove different things for the same body depending on who compiled it.
- **Test**: a two-package program where the dependency pins `wrap` and computes a hash that
  overflows, the root does a checked add that overflows: the dev build aborts at the root's add,
  the release build too if the root pins `checked`, and the hash is identical in all modes.

### 2.4 Runtime-error locations in release

The site table is built from `.gpos` markers in the native stream after optimisation; the LLVM
backend lifts the stream into IR where those markers are not instructions, so the table cannot be
built the same way. Options:

1. **v1 (recommended)**: release failures print the message (`index 7 out of bounds for length 3`,
   refinement text, task failure) and no location, as the LLVM backend does today. Saves 6% of
   binary size.
2. **later**: the lifter turns `.gpos FILE LINE COL` into `!dbg` locations on the call to the
   failing runtime entry, clang emits DWARF `.debug_line`, and the runtime's report maps the return
   address through it (the `grail debug lines` reader exists, `cli.grl` usage). This also gives
   profilers and debuggers line info for release builds. Cost: DWARF line tables in the binary
   (typically larger than `grail_sites`) **[A]** and a reader in the runtime.

### 2.5 Preconditions and risks

- LLVM backend correctness on all three targets: the full corpus with `GRAIL_BACKEND=llvm` on
  aarch64 and riscv64 has not been run green in this tree; it must be, before `--release` is
  offered there.
- Build time: `clang -O2` per unit. Measure on the compiler's own build and `abundance/`, report
  development vs release wall time; target release ≤ 3x development **[A]**.
- macOS and Windows: refused (R4) until the lifter handles Mach-O/PE streams.

## 3. Release parity (item 6)

### 3.1 Where the gap is (measured)

| | f32 xform | f32 dot | f64 xform | f64 dot |
|---|---:|---:|---:|---:|
| `--backend=llvm` today (µs/pass, 1M) | ~700-950 | ~620 | ~640-1000 | ~620 |
| C `clang -O2 -fno-vectorize` | 230 | 610 | 310 | 650 |
| C `clang -O2` | 77 | 611 | 160 | 656 |

Dot products are at parity already **[V]** (Q7 fixed the f64 one). The transforms are 3-4x off
scalar C and ~9x off vectorised C. The three blockers of the SIMD note, section 1.3, read from the
optimised IR **[V]**: per access `load len` + `icmp` + `br abort` with the length *reloaded*, all
addresses `inttoptr`, no alias information.

A C model of the Grail shape, `.work/simd/model.c`, with the descriptor `{data, len}` passed by
pointer and a noreturn failure call, `clang -O2` **[V]**:

| shape | µs/pass | packed `mulps` |
|---|---:|---:|
| A: today - data and len reloaded at every access | 406 | 0 |
| B: data and len loaded **once**, every check kept against those values | **72** | 2 |
| C: B + front-end loop versioning (`n <= y.len` checked once) | 76 | 4 |
| D: C + `restrict` (noalias) | 80 | 4 |

So **B is enough**: once the descriptor's two words are known not to change in the loop, clang
removes the check that the loop bound implies, versions the loop for the other one itself, adds its
own runtime alias check and vectorises. Loop versioning in the front end and `noalias` buy nothing
measurable on this loop. That fixes the order of the work.

### 3.2 The fact

**SEQ-STABLE(slot s, region R)**: during R, the descriptor reached through the word in slot `s` is
not written - its `data` and `len` are the values they had on entry to R - and no store in R writes
descriptor memory (element storage and descriptors are separate allocations, `llvm-backend.md:399`).

Where the front end gets it, from what it already knows:

- **Slices** (`&[T]`, `&mut [T]`, kind 27, and byte views): a slice's descriptor never changes while
  the slice lives - a `&mut [T]` permits element writes only, and the borrow checker forbids
  anything that would move the vector under it (push, reallocation, `&mut v`, move). So for a
  slice-typed slot the fact holds for every region in which the slot is not itself reassigned; the
  front end states it once per slot (`R` = the function) and the consumers treat a write to the
  slot as the start of a new value, which they already track.
- **Owned vectors** (`T[]`, kind 6) in a loop: the fact holds for loop `L` when nothing in `L`'s body
  can change the header: no length-changing method (`push`, `pop`, `append`, `insert`, `remove`,
  `clear`, `reserve`, ...), no assignment or move of the place, no `&mut` of the *whole* place (an
  element loan - `member_place(root, 0, elem)`, `native.grl` `index_view` - is fine), and no call
  that receives a whole-place exclusive loan. In `ownership.grl` terms: within `L` no exclusive loan
  whose `source` is the vector's root place itself (only its element child), and no `take`/`write`
  of the root. The front end emits it at the loop's end, when the body is known, as
  `fact_stable(fn, slot, loop-start label, loop-end label)`.
- **Not** stated: a vector reached through a reference to a record that is written in the loop, an
  `unsafe module`'s code (as F2, `native.grl:13381`), a slot whose address escapes to a call that
  could write it (the lifter's existing escape rule).

It travels in `llvm::Facts` beside F1/F2 (`native.grl:436`), recorded when `wants_facts` - which
must become true on the native path too, for the second consumer. One fact table, two consumers.

### 3.3 Consumer 1: the LLVM lifter (provenance)

At a checked accessor (`rt_slot`, `rt_slot4`, `rt_at*`, `rt_slotb`; `llvm.grl:1676`) whose argument
0 is a SEQ-STABLE slot in its region, the lifter:

1. loads `data` and `len` **once** - at function entry for a slice parameter, at the loop
   preheader (the block before the loop-start label) for a loop fact - as `load ptr` and `load i64`
   from a `ptr` with `!invariant.load` and `dereferenceable(16|24)`, and keeps the two SSA values per
   slot for the region;
2. emits the accessor as `icmp ult %i, %len` + `br` to the cold abort, and the element address as
   `getelementptr` on the `ptr` data - no `inttoptr`, so the address has provenance;
3. does nothing else. Model B says clang does the rest.

Step 2 (noalias), only if a benchmark needs it: an exclusive slice parameter's data gets its own
`!alias.scope`, every other sequence's accesses `!noalias` to it. Model D says the transform does
not need it; nbody might (many accesses, `energy(&p, &v, &m)`), to be measured before building it.

Q7 belongs here: the `f64` loop kept `rt_fail` calls in the body because `rt_fail` was not known to
be non-returning - fixed (`never_returns`, `llvm.grl`) **[V]**; what remains for `f64` is exactly
the f32 story, so the same fact fixes both.

**Test** (the bit-identical oracle is not at risk: no float operation changes, only where loads
happen): `--verify-facts` gains a SEQ-STABLE mode - at every accessor using the hoisted values, also
reload `data`/`len` and abort on a mismatch, so a wrong fact fails on the first access after the
header changed. The corpus under `GRAIL_BACKEND=llvm GRAIL_VERIFY_FACTS=1` on three targets. A
negative test per exclusion rule (push in the loop, `&mut v` passed to a call in the loop,
reassigned slice slot): the fact must be absent (an `asmAbsent`-style pin on the `.s.ll`).

**Measured by**: `bench/xform_f32`, `xform_f64` with `GRAIL_BACKEND=llvm`: target parity with
`clang -O2` (vectorised, ±20%) - that is model B; `bench/nbody`, `sort` must not regress.

### 3.4 Consumer 2: the text optimiser (native descriptor hoisting)

For the native backend (implementation to /root/optimiser_labels, who owns the optimiser):
the optimiser reads `fact_stable` for the function (it already receives `&c.facts`,
`optimize.grl:1160`). For a loop region `[start, end)` and a stable slot `s` whose word is not
written inside the region:

- in the preheader: `movq S,%rX; movq (%rX),%rD; movq 8(%rX),%rL` into two free callee-saved
  registers per vector (the promotion machinery's register pool; when the pool is short, prefer
  the vector with more accesses in the loop - same 4^depth weights);
- each pseudo-op 40/41/44/49/51 on that descriptor becomes `cmpq %rL,%rsi; jae <abort>` and
  `leaq/movl (%rD,%rsi,W)` - no descriptor load; 47/48/50 (proven) lose the `movq (%rdi),%rax`.
- the loop bound: `while i < n` with `n := x.len()` keeps `n` in a slot today; with the fact it is
  `%rL` itself.

The loop guard's 0/1-word materialisation (`setb; movzbq; testq; jz`) is a separate peephole the
optimiser owner may already have.

Expected: the f64 transform's three header reloads per element go; with xmm promotion P1 already
in (`gaps12-xmm`, xform_f32 −38%), within 3x of scalar C for f64 **[A]**.

### 3.5 Front-end prover: slice lengths do not die

The refinement prover drops a fact about `v.len()` at "a method call or a `&mut` on a vector (its
length), and a call" (`book/chapters/refinements.md`). For a slice the length cannot change while
the slice lives, so `n == x.len()` and `i < x.len()` facts about a slice should survive calls and
element writes. With that, `x[i]` in the transform is proved (`i < n`, `n == x.len()`), which removes
the check on native as well and leaves only `y[i]`. Small, independent, and measured by the same
benchmark on both backends.

### 3.6 Why not `--range-facts`

It rebuilds, from the untyped word stream, facts the front end has exactly: which word is a
sequence, its identity, its length, whether a call can change it. It costs 70-90% more compile time
for zero checks removed on the corpus (`typed-ir.md:737-812`), and each of its drop rules
(escaping slots, unknown calls) exists because the stream lost the loan information the borrow
checker had. SEQ-STABLE is the same information at the source, at the cost of one fact per slot or
loop. Once 3.3 lands, re-measure `--range-facts` on bench/ and the corpus; if it removes nothing
more, delete it with its tests and docs.

### 3.7 Staged plan

| Step | What | Files | Measured by | Risk to the oracle |
|---|---|---|---|---|
| P0 | `--release` in the driver (2.1-2.2), refusals (R4, `--debug`) | `cli.grl`, `tools/native.mjs`, book | dev vs release build time on the compiler and abundance; bench/ through `grail build --release` equals `GRAIL_BACKEND=llvm` | none (same lifter) |
| P1 | overflow default, manifest key, per-module mode, template-row mode, header check dropped | `cli.grl`, `pkg.grl`, `native.grl` | the two-package test (2.3) | none; needs `gaps12-prover` |
| P2 | SEQ-STABLE fact for slices (function-wide) + lifter consumer + verify mode | `native.grl`, `llvm.grl` | xform_f32/f64 LLVM: ~700 → ≤100 µs (model B: 72) | none: no float op changes |
| P3 | SEQ-STABLE for owned vectors in loops (loan-based) | `native.grl`, `ownership.grl` (a query: "exclusive loan of root in region") | nbody, sort, sieve on LLVM | a wrong exclusion - caught by the verify mode |
| P4 | native consumer: descriptor hoisting | `optimize.grl`, `ir.grl` (/root/optimiser_labels) | xform_f64 native ≤ 3x scalar C | none |
| P5 | prover: slice length facts survive | `native.grl` prover | checks removed in bench/ `.s` (asm pins) | a wrong proof - `--verify-facts` on native keeps the check and aborts |
| P6 | noalias scopes, only if nbody/sort need them | `llvm.grl` | nbody LLVM | none |
| P7 | release error locations via `!dbg` (2.4) | `llvm.grl`, runtime | a failing release program prints `-->` | none |

P2 is the smallest change that gets the transform to vectorise; P0 and P1 are what makes it reach a
`grail build` user. Each ships alone.

## State (owner /root/simd_layout_design, updated 2026-11-17)

Landed on main: P0 `--release` driver, P1 one overflow mode per build, P2 SEQ-STABLE slices (xform at
parity), release check messages (`rt_trap` kinds), the stale-length miscompile fix, lifter table
lookups and forked lift, rt_f32_from_int -> sitofp/uitofp, raw code follows the overflow mode, the
memcpy redeclaration fix, the thread-pointer lift reverted (pool crash; owner /root/thread_alloc).

In the landing queue: `gaps12-llvm-parts` (dcdb1b2): `grail llvm-compile`, parallel `clang -O2` over
a lifted module cut in parts, used by every release unit and by the release-compiler build.

Next, in order: ThinLTO on top (owner /root/xinline); per-part store caching and the shipped
`grail` = release build (accepted by tools/native.mjs release; native build kept as bootstrap);
release compile speed against cargo/Go/Zig on syn1000/syn4000; P3 owned-vector loop hoists with
TBAA (parked branch gaps12-p3-wip); P5 prover slice lengths; P7 release error locations.
Release-compiler builds run under `flock /home/shulgin/grail-release.lock`.
