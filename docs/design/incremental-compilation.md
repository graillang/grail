# Incremental compilation

Decision: **accepted**. Companion to `docs/design/separate-compilation.md` (the plan of record for
interfaces and per-module objects); this note is the plan of record for *edit cost* — what a change
to a file re-runs, what it does not, and what makes a cached answer impossible to be stale.

Written against the compiler as it is today: `compiler/native.grl` carries the writer/reader of
interfaces and the per-module emission; `compiler/cli.grl` carries the driver, the cache store and
`grail build`; `tools/cache-test.mjs` is the proof.

## The property

> An edit re-runs what the edit can change, and nothing else — and whatever it hands back is byte
> for byte what a clean build of the same tree would produce.

Two halves, and the second is what makes the first worth having:

1. **Reuse.** The unit of reuse is the module run: one compiler invocation, one assembly file, one
   object, one interface. A run is reused when everything it read is unchanged.
2. **Independence.** A module's emitted text must be a function of *that module's* inputs. If
   anything in the emitter lets module *A*'s text depend on module *B*, then B's edit forces A's
   run to be redone (at best) or, if the key does not record it, reuses an object that no longer
   matches (at worst). Independence is therefore not an optimization here; it is what makes the key
   *sound*, and it is enforced before the key is trusted (see "What invalidates what").

## Edit cost, by kind of edit

The driver compiles modules in dependency order (`runtime` first, then each module after the modules
it `use`s). Each run's key names the *surface* of every interface it can read, so:

| edit | re-run | why |
| --- | --- | --- |
| a module's body, interface bytes unchanged | that module only | the surface is unchanged, so no importer's key moved |
| a module's public surface (declaration, signature, `pub` item, bound, `effects` row) | that module, then every run after it | they read its interface, and the interface changed |
| a module's private helper called only from that module | that module only | the private item is not in the interface |
| a leaf module nothing imports | that module only | nothing reads its interface |
| a flag that changes code generation | every module | the flag vector is in every key |
| the compiler itself | every module | the compiler's own digest is in every key |

"A body-only edit must not rerun importers" is a *measurement*, not an assertion: it is one of the
numbers `tools/cache-test.mjs` prints (see "Measurements"), and it fails the tool if the importer
runs.

The one thing per-module compilation deliberately does *not* do is narrow the surface: an interface
carries everything an importer needs, so a change to a `pub` signature is a change to every
importer's inputs. That is not conservatism for its own sake — an importer's object can genuinely
change (a call's argument setup, an inline body, a drop helper's shape).

## Content-addressed artifacts

The store is `.work/cache/<target>/`, and it is keyed, not timestamped:

```
blob/<sha256>      artifact bytes; the file name is the digest of the bytes inside
map/prog/<key>     the linked image, plus the output path and the link inputs
map/lnk/<key>      the linked image
map/mod/<key>      one module run: its object, its interface, its link inputs
fn/<key>           one function-level unit (below): its bytes, its key record, its label counts
```

A *key* is the digest of a text record that names every input the artifact is a function of:

- a module run: the module's name and source digests, the *surface* of every interface the run can
  read (an interface without its `sha256` and `digest` lines, which change with a body), the
  compiler's digest, the assembler's identity, the target, the whole flag vector (`build_argv` is
  the one place the invocation is spelled out, so a flag added later is in the key by
  construction), and the runtime and platform digests;
- the image: every input the build read, each with its digest, plus the output name and the
  contents of every file a `// grail-link:` note names.

Every write lands in `stage/` and is renamed into place; a blob is only handed back after its bytes
have been hashed again and matched against the name it is filed under. A truncated, edited,
corrupted or unreadable entry is a miss and a rebuild, and filing the repaired artifact replaces
the damaged entry instead of leaving it to miss forever (`tools/cache-test.mjs`, (e)).

## Below the module: the function-level cache

**Implemented** (2026-11-15), **made to hold after an edit** (2026-11-16). A module's run is not one
artifact but many: a big module has hundreds of functions, and an edit touches one of them. The
per-function cache makes **one emitted function** the unit of reuse inside a module run that has to
be redone, and after an edit to one body every other body of the module is a hit.

- `compiler/fncache.grl` is the store and the `Unit` type: one file per unit under `<store>/fn/`,
  written through `stage/` and renamed into place, with the key record carried *inside* the file
  and compared on the way out (two keys that hash to the same name are a miss, never a wrong hit),
  and a checksum over the records the emitter will decode.
- `compiler/native.grl` owns what a unit *is* and what its key names (`fn_key`, `fn_surface_now`,
  `fn_flags_now`, `fn_open`, `fn_marks`), how one is produced (`fn_unit_of`) and how one is put
  into a run (`fn_apply`). `compiler/cli.grl` passes `--fn-cache DIR` to every per-module run of a
  build that goes through the store. It is `store/fn/`, so `grail cache clear` and `grail cache
  prune` take it with everything else.
- `tools/cache-test.mjs` sections (i), (j) and (k) and `bun tools/test-native.mjs x86_64
  --unit-identity` are the proof, and print the numbers.

A run that is a full module-level hit never reaches this layer: the compiler does not run at all.
A run that misses replays the unchanged functions and compiles the rest.

### A unit is a value, produced and applied

A `fncache::Unit` is everything one function's compilation hands the run:

| field | what it is |
| --- | --- |
| `key` | the record below; compared, not trusted by name |
| `text` | the function's emitted assembly, from its `.globl`/`.type` to its last line |
| `facts` | the typed-IR facts its emission recorded, which the optimiser reads |
| `regs` | its *registrations*: every drop helper it names and every specialisation it asks for |

The two halves are separate functions with that value between them. **Produce** is `func` compiling
the body and `fn_unit_of` taking what it left as a `Unit`. **Apply** is `fn_apply`: the function
takes its ordinal in the part, `.gbase LINE` is written, then the text, the facts, and the
registrations made again through the calls a fresh emission makes (`drop_ref_name`, `specialize`).
A cache hit is a load and an apply. A miss that turns out to be a unit is produced, filed, taken
back out of the run (output, fact table, drop requests, ordinal) and applied - so a body compiled
in this run and a body replayed from the store reach the run by one route, and nothing reaches the
run from a unit except through what the unit records. That is the shape parallel body compilation
needs: workers produce units, the parent applies them in order.

### Why a unit's text does not depend on the bodies before it

Three things used to tie a body's bytes to everything emitted before it; each is now the body's own.

- **Labels.** Inside a function a label is `.L<unit prefix>_<f>_<n>`: `f` is the function's ordinal
  in its unit and `n` restarts at 1 with each function (`scope_begin`, `scoped_number`). The frame
  constant (`.F...`) and the refinement strings (`.Lrfp...`, `.Lrfr...`) are spelled the same way.
  Outside any function - drop helpers, the thunk, vtables - a unit's own counter mints
  `.L<prefix>_<n>` as before. Specialisations and closures are emitted after every ordinary body,
  so an edit to a body cannot move a later ordinary function's ordinal; the ordinal is in the key
  all the same. The optimiser reads both spellings (`ir::label_number`) and leaves a body that mixes
  two numberings as written; its own expansion labels (`.Lopt<prefix>_<ordinal * 2^20 + k>`) were
  already per function, counted the same way by `run_range` and by `plan()` for the forked
  workers, so nothing there changed and the output is still the same text at any `GRAIL_JOBS`.
  *Cost:* about one byte per label mention; the compiler's own assembly went from 109,628,863 to
  112,511,826 bytes (+2.6 %) on the same sources. *Rejected:* `f * 2^20 + n` in the one-number
  spelling (no reader changes, 7-10 digits on every label); and keeping run-wide numbers and
  patching them on replay (the output would be today's bytes, but every later body's text would
  still shift after an edit, and the optimiser's body memo, keyed on that text, would miss).
- **Positions.** A function states the line it starts on before its body - `.gbase LINE`, outside
  the unit's text and outside the body the optimiser hashes - and each statement's marker is
  `.gpos FILE DELTA COL RAW`, counting from that line (`site_base`, `site_pos`). A replay writes a
  fresh `.gbase` and the stored text. `site_table` keeps the current base and adds it. A body the
  optimiser copies out to inline elsewhere would carry deltas into a function with another base, so
  the copy's markers are rewritten once, when it is registered (`ir::absolute_positions`, called
  where `inline_candidate` files a copy and where `one_body` takes one from its memo), to
  `.gposa FILE LINE COL RAW`, which `site_table` reads without consulting the base. The memoised
  copy keeps its deltas; the inline pass itself is untouched. *Rejected:* bracketing each inlined
  copy with two `.gbase` lines (the inline pass would have to track bases), and patching absolute
  lines back in on replay (same memo problem as for labels).
- **Registrations.** A body that named a drop helper or asked for a specialisation used to be
  excluded, and one that *used* a specialisation an earlier body had asked for recorded nothing -
  so when the earlier body stopped asking, the replayed one left an undefined symbol
  (`tools/cache-test.mjs` (k) is that program). Now every naming and every request is recorded,
  first of the run or not, in the order the body made it: `1 <type>` for a drop helper, `2
  <template> <n> <type>...` for a specialisation, with types spelled structurally by
  `iface_w_type` and read back by `iface_r_type`; the template is its index in the function table,
  which the declaration surface in the key fixes. Before a unit is filed its registrations are read
  back and must intern to the very types the body named, or the body is not a unit. On apply, all
  of a unit's registrations decode or none of the unit is used. The drop walk follows suit:
  `emit_drops` emits a helper for each type something named, in the order they were first named,
  instead of one for every type the run interned - a replayed body interns nothing, so the old walk
  would have written a different set in a different order with a store than without.

### The rule: which functions are units, and why the rest are not

**1. The body must hand the run nothing a unit does not record.** `fn_marks` takes one counter per
rule at the body's first byte and compares at its last; each rule counts every use, not only the
first of the run. A body that trips one stays as emitted and is never filed. The build's
`grail: fn-cache:` line lists how many bodies each rule kept out.

| rule | why it is not a unit in this pass |
| --- | --- |
| creates a **closure** | the closure body is emitted by a later step from a record a unit does not carry |
| uses a **vtable** (registers one, or names one an earlier body registered) | emitted later from the vtable list |
| adds a **link input** | the link request is program-wide state |
| adds a **constant** | the constant table is read by later bodies |
| uses the **fn thunk** | emitted once, later, if any body used it |
| spells a **position as text** (a refinement's `file:line`, or a statement above the function's own first line) | the text names a line of the file, so it moves when lines above it do |
| **synthesises a declaration** (the first tuple of a size, the first result union, a closure environment) | a replay synthesises nothing, so the bodies after it would start with a different declaration count than the run that filed them, and their keys carry it |
| names a type with **no interface spelling**, in its signature or in a registration | a key or a registration that cannot say the type would be a guess |
| records an **effect** | a run with effect records files no units at all |
| is the **first body of a part** | `part()` writes the `.grail_part`/`.text` marker inside that body's bytes |

Also outside this layer, as before: a generic template (it is replayed per specialisation), a
specialisation replay, and whole runs of the shapes `fn_on` refuses - `--debug`, `--backend=llvm`,
`--emit-ir`, `--export`, PE/Mach-O, ARM/RISC-V, a validating run - and a run whose surface cannot
be spelled, which includes a run with a compile-time constant still pending when the surface is
taken (its value will reach bodies, and the function that computes it is a body, not surface).

**2. The key must name every input the bytes are a function of.** `grail-fnkey 2`:

| field | why it is there |
| --- | --- |
| the part and its label prefix | labels are `.L<prefix>_...`; the prefix is the module's |
| the symbol the label spells | a renamed or re-signatured function is a different unit |
| the option vector (every argument except the output path and `--fn-cache`) | a flag that changes code generation changes every body; the words include the modules the run was told to read (`--use-module`) |
| the **compiler's own identity** | a unit is code *this* compiler emitted (`--fn-cache-id`, or the executable's path, size and time for a hand-run compiler) |
| the **declaration surface** of the run | a field offset, a drop bit, a symbol spelling and a constant's value all reach the text as numbers; it is every declaration, alias, signature, constant, import, interface and implementation, and the surface of every interface the run read. No body is in it. |
| the declaration's own source text | the obvious input, and the only one an ordinary edit moves |
| the typed signature, spelled by `iface_w_type` | types after substitution, structurally |
| the file's index and the column the declaration starts at | `.gpos` prints both |
| the function's ordinal in its unit | its labels spell it |

Gone from the key since version 1: the line the declaration starts at, and the label and `.Lrfp`
numbers it starts at - the three fields that made an edit to one body miss every body after it -
and, since version 3, the declaration count the body starts with (below).

### The declaration count in the key

The count is run-order state: it says how many declarations exist when the body starts, and a
worker compiling one body in isolation would not have it. What moves it during bodies is the
find-or-create synthesis of `.tuple::TupleN` (`tuple_decl`), result unions (`make_union`), the
function-value record (`fn_value_decl`) and closure environments. Measured rather than argued: the
whole x86_64 corpus (689 programs that compile) was compiled with three extra tuple declarations
synthesised before the first body, shifting every later declaration index, and every assembly was
byte-identical to the unshifted compile. So nothing in the emitted text was found to depend on the
count; names reach symbols by module and name (`type_key`), not by index. So the count is not in
the key (version 3), and the experiment is permanent: `--shift-declarations N` synthesises N tuple
declarations before the first body, and `--unit-identity` compiles every case with it and requires
the same assembly. A text dependency on declaration order that creeps in later fails that leg.

### What a run reads

A unit key names the surface of every interface the run read. A module's run reads the interfaces
the driver names (`--use-named`, `--use-module NAME`), which is the list the module key is built
from, so a cold build with every module running at once and a later rebuild of one module compute
the same surface, and the first edit after a cold build replays. (Before that, a run read whatever
interface files its build directory held when it started, and the first rebuild of a module after a
cold build missed every unit once.)

### The test switch

`GRAIL_FN_CACHE=0` in the environment of `grail build` leaves the module store on and the unit
layer off: `--fn-cache` is not passed to the module runs. It exists for `tools/cache-test.mjs`,
whose reference build is the same tree built from an empty store with the layer off - a plain
`grail build` goes through the store too, and would hand back the objects the build under test had
just filed. Nothing else reads it.

## Measured: the function-level cache after the 2026-11-16 pass

Counts are exact; the clock is a shared host's and moves by tens of percent between runs (best of
the runs taken is given, with the range where it matters).

**How many bodies are units.**

| program | bodies | units | not units |
| --- | --- | --- | --- |
| syn1000 (1000 x {record, constructor, 15-line function}), before | 2,001 | 0 | 2,000 (every body names a drop helper or is the first to) |
| syn1000, after | 2,001 | 2,000 | 1: first of part |
| the compiler's own sources, before | 2,707 | 928 | 1,763 |
| the compiler's own sources, after | 2,724 | 2,708 | 16: first of part, one per module |
| the x86_64 corpus (689 programs, runtime and library included each time) | 320,891 | 320,531 | 360 |

Over the corpus the rules that kept a body out, in bodies (a body can meet several): first of part
2,478, a position spelled as text 222, a synthesised declaration 112, a closure 90, a vtable 26,
the fn thunk 12. (The first-of-part count is per part and is not in the 360: those bodies are never
candidates.)

**A rebuild after a one-body edit.**

| | before | after |
| --- | --- | --- |
| syn1000, `grail build`: replayed / compiled | 0 / 2,000 | 1,999 / 1 |
| syn1000, wall clock, edit keeps the line count | 2.73 s | 1.98 s |
| syn1000, wall clock, edit adds lines | 2.83 s | 1.97 s |
| syn1000, the same edit with the unit layer off | 2.64 s | 2.80 s |
| syn1000, first edit after a cold build | 2.79 s, 0 replayed | 2.41 s, 1,999 replayed |
| compiler sources, one process (`grail OUT.s compiler/*.grl`): replayed / compiled, edit keeps the line count | 927 / 1 (+1,763 not units) | 2,707 / 1 |
| the same, edit adds lines | 711 / 217 (+1,763 not units) | 2,707 / 1 |
| compiler sources, wall clock, edit keeps the line count | 16.7 s | 6.9 s (6.9-10.2) |
| compiler sources, wall clock, edit adds lines | 20.4 s | 8.7 s (8.7-11.0) |
| compiler sources, the same edit with no unit store | 21.6 s | 13.5 s (13.5-15.5) |

The "before" compiler-source times were taken on the tree before the unboxed-view work was merged,
which made every compile faster, so read the last three rows across, not down: with the store an
edit to one body of the compiler now costs about half of what it costs without it, where it used
to cost three quarters when the line count held and nearly all of it when it did not.

In one process with `GRAIL_JOBS=1` (CPU seconds, same sources): no store 25.7, a cold store 32.4
(filing 2,708 units and as many optimiser memo entries), every body replayed 13.8.

**Where an all-hit rebuild of the compiler goes** (`grail profile`, leaf samples, `GRAIL_JOBS=1`):
`rt_alloc_unlocked` 14.6 %, `optimize::run_range` 12.3 %, `rt_int_cast` 7.9 %,
`optimize::lines_of_interest` 7.4 %, `rt_free_unlocked` 7.3 %, `native::site_table` 6.0 %,
`xxhash::read64` 4.6 %, `rt_read_file_blocking` 3.9 %, `rt_copy_bytes` 3.6 %, `rt_int_neg` 3.5 %.
The front end is no longer in the top ten: what is left is the back end walking 100 MB of text
that did not change (the optimiser's line scan even when every body is a memo hit, the inline
pass's index, the site table), the hashing of every body for the memo, and allocation - much of it
the per-fact and per-entry vectors of the two stores' decoders. `fncache::rs`, `iface_r_type` and
`fn_apply` together are under 5 %.

**Costs.** Filing is not free: a cold build of the compiler's sources with a store is about a
quarter more CPU than one without (above), paid once per unit and only by a run that missed. And
the unit covers the front end and the emitter; the optimiser has its own per-body memo
(`one_body`), which this pass makes effective after an edit - a body's text no longer shifts when
another body changes, so its memo entry is found - but the passes over the whole stream still run.

The first body of a part used to be excluded because `part()` writes the part's marker inside its
bytes. Its unit's text starts after the marker (the point `func` takes a unit back to, `apply_mark`),
and a hit or a worker's unit opens the part before it is applied, so since the parallel-bodies pass
the first body is a unit like any other.

## Parallel bodies

**Implemented** (2026-11-16, branch `gaps12-parbodies`). A unit is a value produced by compiling one
body and applied to the run by `fn_apply`, so the bodies of one module can be produced by several
processes and applied by one.

- **When the fork happens.** `par_start` only arms the walk. The parent walks the bodies itself,
  applying hits from the store, and forks when it has compiled `par_threshold` bodies the store did
  not have (`par_fork`: 1 with no store, 16 with one), cutting only the source still ahead of it.
  A rebuild after an edit therefore never forks: forking it anyway made workers load and pipe back
  2,700 hits the parent can load itself, and the compiler's one-body-edit rebuild went from about
  7 s to 13-14 s; with the lazy fork it is 8-11 s on the same loaded host.
- **The shape.** At the fork the source still ahead is cut into slices of about equal size, counted in bytes over the files in
  order. The process forks one worker per slice after the first; the copies share its memory until
  they write, so they start with every declaration, signature, interface and the declaration
  surface. Each worker walks pass 3 like the parent, compiles the bodies of its slice into units -
  keying, loading from the store and filing exactly as one process does - and skips every other
  body the way a hit does (it opens the part and spends the function's ordinal, so its labels are
  numbered as the parent's). It keeps what it made in memory and writes it to its pipe once, when
  it has walked past its slice, so it never waits on the parent while it compiles.
- **The parent** compiles the first slice itself and, as its walk reaches each later body, reads
  that worker's stream (once, the first time it needs it) and applies the unit the worker sent if
  its key is the key the parent computes for the body - the route a cache hit takes. A body a
  worker reported as not a unit (a closure, a vtable, ...: the rules above), or one whose key does
  not match, the parent compiles itself, in place. The walk, its counters and its registrations are
  therefore the ones a single process has, and the output is byte-identical at any worker count.
- **Diagnostics.** Today a body's error is printed by `fail`, and `next_error` runs the compile
  again with that body skipped to report the next one (up to 20 runs); an error outside a body ends
  the compile. A worker never reports: `fail` in a worker exits at once. The parent finds the
  stream short (or the status non-zero), collects every worker, says so under `GRAIL_DEBUG` ("the
  rest of this module is compiled in one process"), and compiles every remaining body itself - so
  the first error, the re-runs, the text, the order and the exit status are exactly one process's.
  A re-run with `--skip-body` does not fork. `tools/jobs-test.mjs` (d) checks three errors spread
  over a 1000-function module, for `grail check` and for a compile.
- **Check runs.** `--check` walks the same way (it returns only before the optimiser), so it is
  parallel too. Its workers send a unit with no text and no facts - a check writes no assembly and
  runs no optimiser - only the key and the registrations, which the parent applies so the
  specialisations and drop helpers the checked bodies ask for are still checked. That is everything
  else a checked body contributes to a check run: the closures and vtables it creates are the
  non-unit rules, so the parent checks those bodies itself, and the effect tables turn the whole
  layer off.
- **What else a body contributes.** Audited before this pass, by every vector `func` and what it
  calls can push to (`c.<field>.push`): besides its text, facts and registrations a body leaves only
  per-body state (borrow and prover state, hints, the `caddr`/`embedded`/`pointers` places, reset
  at its entry), memos that never reach text (`caps_memo`, the interned type table, file caches),
  the interface names a `dyn` type adds to `dyn_ifaces` (read only by `check_interfaces`, which runs
  before any body), diagnostics (`reported`, `diag_json`: only `fail` writes them, and it ends the
  process) and the effect tables (any effect record turns units off for the run). So the store lost
  nothing on a hit before this pass either.
- **The cut cannot matter.** A unit's text is a function of its key - the identity leg shows a
  replay equals a fresh emission, and `--shift-declarations` that declaration indices do not reach
  text - and the parent applies in source order. To make that a test rather than an argument,
  `GRAIL_BODY_SLICE=2` forces two processes with the source cut in two and `GRAIL_BODY_SLICE=1`
  deals the bodies out in turn, so that no process compiles two consecutive bodies;
  `GRAIL_TEST_BODY_WORKER_DIE=1` makes the first worker die at once. The `unit-identity` leg
  compiles every corpus program all three ways and requires the one-process bytes.
- **When.** Not with `--debug`, the LLVM backend, `--emit-ir`, PE/Mach-O, ARM/RISC-V, `--export`,
  a run with effect records or a `--skip-body` re-run (`par_start`'s conditions, the same shape the
  store's units need), and not when the bodies are not worth it, which is measured
  (`par_decide`): the walk compiles alone for its first 50 ms of CPU (read from /proc/self/stat, so
  a loaded machine does not inflate it), estimates from its progress through the source what the
  rest would cost, does not fork at all under half a second, and above it runs one process per
  150 ms of the estimate, up to `GRAIL_JOBS` or the processor count and the tokens the jobserver
  has free.
- **The parent takes a slice.** It compiles the first slice rather than waiting: measured against
  a variant where every slice goes to a worker and the parent only applies, there was no
  difference beyond the host's noise (self-check 6.1-8.9 s against 6.4-8.5 s, self-compile 17.4-19.0
  s against 15.8-19.1 s, load average near 38), and the variant runs one process more, so the
  parent keeps its slice.

### The optimiser's memo under a unit's key

A body the front end applied from a unit is noted where its opening and closing lines are written
(`ir::Known`, filled by `fn_apply`). The optimiser takes those bodies from the notes - `run_range`
scans line by line only the text between them - and keys their memo entries by the unit's key
(plus the meta it always had: the compiler, the unit, the ordinal, the facts digest, the replay
range) instead of an xxhash of the body's text. Sound because a unit's text is a function of its
key, which the identity leg shows; `GRAIL_MEMO_VERIFY=1` optimises every such body again and fails
on any difference, and `tools/cache-test.mjs` (l) runs it on a warm rebuild of the compiler. Every
note is checked to be a whole body before it is used. On the compiler's sources a rebuild after a
one-body edit went from 10.2 to 6.1 CPU seconds in one process, and from 7.8-8.5 to 4.9-5.4 s
at the default job count (self-built compilers, load average 25-28).

### The jobserver

`grail build` runs one compiler process per module, each forks optimiser workers, and each now
forks body workers: bounded by the processor count each, that is hundreds of processes on a large
project. `compiler/jobs.grl` is one counter for the whole build, in GNU make's protocol: a fifo
holding one byte per token, `N - 1` tokens for `N` jobs because every process owns one implicit
token. The outermost `grail build` makes it beside its output (`OUT.jobs`, removed when the build
ends) and names it to the processes it starts in `GRAIL_JOBSERVER`; a build started under `make -j`
finds make's in `MAKEFLAGS` (`--jobserver-auth=fifo:PATH`) and uses it instead. The driver's
module runs, the optimiser's workers (`run_forked`) and the body workers all take tokens from it.

- A token is taken by the process that starts the work and given back by that process after it has
  waited for the work - never by the work itself - so a worker that dies cannot lose one; the
  optimiser's failure exit and every return of the driver give back what they hold.
- A take never waits (`host::read_fd` with bit 62 set reads what is there and returns). A process
  that gets no token runs fewer workers or does the work itself, so no set of processes can each
  hold tokens while waiting for another's - a waiting take would allow that deadlock.
- With no jobserver in the environment a process behaves as before, bounded by its own count.
- `host::open(path, 2)` makes the fifo if it is missing and opens it for reading and writing,
  non-blocking; pipes are close-on-exec, so a pair of descriptors would not reach the module runs.

`tools/jobs-test.mjs` checks a body worker that dies (one-process bytes, the fallback said, every
token back), a 17-run build under `GRAIL_JOBS=3` (at most 7 compiler processes at once: the driver,
and per token one module run - its wrapper and its compiler - or one worker), and a build under a
make-style fifo (its tokens all back afterwards). On the 24-module benchmark with `GRAIL_JOBS=4` the
peak is 9 processes where the previous compiler ran 49.

### An incremental check

`grail check` takes the per-module path a build takes (cli.grl `check_command`, `per_module_build`
with `--check` in the module runs). The module key leaves `--check` out, and so does a unit's key,
so a check and a build of one module agree on both: a check reuses a build's module record
(`unit_restore_check` reads only its interface and facts) or a check's own (`map/check/`, which
holds no object, so a build never takes it), and a check run files full units for the bodies it
checks, which a later build replays. A module with errors reports them as its run gives them; the
modules that read it are not run and print one line each; the modules that do not read it are
still checked. There is no whole-program fallback: an edit with a type error is the commonest
check, and it must not be the slowest. `tools/cache-test.mjs` (m) is the proof.

### Not yet: effects

Any effect claim (`@no_alloc`, `@no_panic`) turns units off for the whole run, so a program with
one gets neither the store's per-function layer nor parallel bodies. The effect checker records per
body which functions it calls and whether it allocates or fails, and settles the claims over the
whole call graph at the end (`fx_solve`). Those per-body records are exactly what a unit would
have to carry - one summary per body: its own allocation and failure facts and its call edges -
for the parent to put them into the effect tables on apply, as it puts the registrations. That is
the next widening of the unit, and it is a contained one: the solver already works from the
tables, not from the bodies.

## What a module run can now skip, per edit (the numbers `tools/cache-test.mjs` prints)

The proof builds a six-module project whose `big` module is generated with 400 functions (2,000 with
`--big`), and prints, for every case, how many bodies were replayed and how many re-emitted:

1. every module run forced to miss with the unit store warm - every filed body replays, the module
   assembly is byte-identical to a clean build's, and the image is byte-identical;
2. one function of the big module edited - one body is re-emitted and every other body of that
   module replays;
3. a body-only edit of another inner function - the module reruns (the module cache's rule) and one
   body inside it is re-emitted;
4. an interface edit - every unit of the runs that read that interface misses, and the units of a
   run that read no such interface still replay.

Section (j) is the same question on a module of the shape real code has - 150 records with a string
field, a constructor and a function each, every body naming a drop helper and instantiating a
generic at a shared type and at a type of its own: an edit that keeps the line count (and adds a
branch, so the body mints more labels), an edit that adds five lines, and one that removes them
again each compile one body and replay the other 298, and the module assembly and the image are
compared byte for byte with the reference build. Section (k) is the undefined-symbol hole: two
bodies instantiate `same<u64>`, the first stops, and the replayed second has to ask for it.
`--units` runs (j) and (k) alone.

The reference build in (h) to (k) is the same tree built to the same output name from an empty
store with `GRAIL_FN_CACHE=0`, because a replayed body that is not the body a fresh emission writes
is a silent miscompile and has to be caught as bytes.

`bun tools/test-native.mjs x86_64 --unit-identity` (gate leg `unit-identity`) asks it of every
program in the corpus: each case that compiles is compiled with no unit store, with an empty one
and with the one that compile filled, and the three assemblies must be identical, with every filed
unit replayed; then the same three with `--debug`, each assembled. Its first run found a crash that
predated this pass (a pending compile-time constant under `--fn-cache`).

## Watch mode

`grail check --watch` and `grail build --watch` keep one driver process alive and re-run the cycle
when an input changes. The cycle is exactly what one-shot `grail check` or `grail build` does - the
same code path, in the watching process - so watch mode adds no second definition of "check" or
"build" that could drift from the first. This section describes what landed; the plan it replaced
(polling mtimes, a `watch: rebuilding (3 files)` line per cycle, `Ctrl-C` reporting the last status)
differed on every point, and where it did the reason is stated.

### The input set

The files a cycle reads:

- a file invocation (`grail check --watch main.grl`): the source named on the command line, and no
  other. A second `FILE` argument is not a module of the first - the driver compiles only the named
  entry - so watching a file the cycle never reads would be a cycle for nothing;
- a project: the plan the package manager resolves from `grail.toml` **and the lock** - the entry
  file plus every module file `grail.lock` names, the root's and its dependencies'. The lock is the
  authority for that list, so the watcher polls the plan's files rather than a hand-built one. Since
  re-planning prints the manifest's problems, the plan runs once per cycle, not once per poll; the
  manifest, the lock and a listing of `src/` are polled as well, and a change to any of them makes
  the next cycle re-plan - which is how a new dependency, a new module or a re-locked version enters
  the set;
- plus the standard modules the sources reach through `use` (found by reading the `use` lines, so a
  new import brings its module into the set on the next poll), and every file in an `--interface
  DIR`.

### Change detection: content, not timestamps

A file's identity is a 128-bit content stamp: XXH64 of its bytes with two different seeds
(`lib/xxhash.grl`, the standard library's content hash). A missing file stamps as two zero words,
which is a state like any other.

Content, not mtime, on purpose:

- an editor that writes a file back unchanged, or a formatter that rewrites it with the same bytes,
  is not a change, so it does not spend a cycle;
- a source restored from a backup or copied with `cp -p` *is* a change, and a timestamp comparison
  would miss it;
- there is no `stat` in the `host::` surface, so a timestamp scheme would have to shell out.

The cost is that each poll reads every input file and hashes it: a few megabytes for a program of a
few modules, once per `--interval` (default 100 ms), paid while the process would otherwise be idle.

### Debounce

Writing a file often means several writes, and a burst of saves across a few files is one intent.
After a change is seen the loop keeps polling; a cycle runs only when the stamps have been unchanged
for the quiet period - 120 ms by default, `--debounce MS` to change it. One burst is one cycle. A
change that lands *while* a cycle runs is not lost: the poll after the cycle compares against the
pre-cycle stamps, and runs one more cycle once it settles.

### One cycle, one line

The first cycle runs immediately, before the first poll: a watch that said nothing until a file
changed would look broken on the program that is already correct.

Each cycle prints its diagnostics - the compiler's own rendering, caret and all - followed by exactly
one summary line:

```
check ok 24 ms
error 3 diagnostics 31 ms
built target/app 210 ms
```

`error` carries the number of distinct diagnostics (`diagnostic` when there is one) and the cycle's
elapsed time; a cycle that failed for a reason that is not a diagnostic (no assembler, no linker)
reports the status without a count. Nothing is printed between cycles: an idle watch process is
silent, so every line on its output is a cycle. (The plan's `watch: rebuilding (3 files)` and
`watch: up to date` lines did not survive: the summary line already says which cycle ran and what it
did, and two lines per cycle is the scrolling the one-line rule exists to avoid.)

### `--json`, and where the diagnostics come from

`--json` makes a cycle one JSON object on one line, built from the diagnostic structures rather than
from printed text:

```
{"cycle":2,"status":"error","ms":31,"diagnostics":[{"file":"src/main.grl","line":3,"col":5,"code":"E0005","message":"assignment requires mut"}]}
{"cycle":3,"status":"ok","ms":28,"diagnostics":[]}
```

A build cycle adds `"output":"target/app"`. `status` is `ok` or `error`, `ms` is a number, and
`diagnostics` is always present (empty when the cycle is clean).

The channel behind it is the compiler's `--diagnostics-json FILE`. At the one place a diagnostic is
built (`fail` in `compiler/native.grl`), the compiler appends one JSON object per diagnostic to
`FILE` instead of printing the caret form, and prints nothing. The object carries `file`, `line`,
`col`, `col_end` (the end of the token the diagnostic points at - the caret run's width, taken from
the token, not from the rendering), `code` (the code `grail explain` knows, or empty), `message`, and
`rendered`, the caret form the compiler would have printed. The re-runs that report one compile's
next error carry the flag, so one cycle's file holds every diagnostic the cycle had. The driver
truncates the file at the start of a cycle, reads the records back when the cycle ends, deletes its
own file, and both report forms are built from those fields. No part of the driver parses printed
text. `grail check --diagnostics-json FILE` exposes the same channel to any other driver, and prints
nothing of its own then: the file is the report and the exit status is the verdict.

### Locking

No lock is held between cycles, and none across a cycle boundary. Nothing in the driver takes a lock
today - the build cache stages every write and renames it into place, so two builds in one directory
produce either the old entry or the new one, never a torn one - so a `grail build`, a `grail check`
or another watching process in the same directory runs while this one waits. That is a case in
`tools/test-cli.mjs`.

The structured-diagnostics file is named after the moment the cycle started
(`target/watch-<wall-ms>`), so two watching processes never read each other's records, and it is
removed when the cycle ends. A listener the caller named (`--diagnostics-json FILE`) is theirs: each
cycle starts it and leaves it in place.

### Exit status, and the signal limit

A cycle's status is the command's: 0 when it passed, 1 when it did not, and a failed cycle keeps the
process alive - the next change re-runs it.

A watch process ends when a signal ends it. **It has no SIGINT/SIGTERM handler, so the default
disposition applies: the process dies on the signal and the status the shell sees is 130 (SIGINT) or
143 (SIGTERM), not the last cycle's.** This is the one requirement of the watch design that is not
met, and the reason is a boundary rather than an omission: catching the signal needs a runtime seam -
a handler that sets a state word, plus a `host::` builtin to read it - in `compiler/runtime.grl` and
in all three platform modules. A new builtin cannot land from this branch, because the published
bootstrap compiler in `compiler/bootstrap/` would not know it and the compiler could not be built
from its own sources again until a reseed. Until then the last cycle's status is in the summary line
and in `--json`, and the status on termination is the signal's. (The plan said `Ctrl-C` exits with
the last cycle's status; that part was not implementable as described.)

### The LSP seam

The language server (`tools/lsp/main.grl`) checks the open buffer by running `grail check` on a
scratch file. It used to map the printed `error[CODE]: message` block, its `-->` line and its caret
run onto the buffer; it now passes `--diagnostics-json`, reads the records, and takes `line`, `col`,
`col_end` and `message` from them, so no diagnostic position comes from parsing text. The plan
deferred this ("recorded here as the next step, not claimed as done"); it is done, and the JSON
object shape is the one documented above, per cycle, plus the per-diagnostic records the server
reads.

### Flags

| flag | meaning |
| --- | --- |
| `--watch` | stay alive and re-run the cycle on change (`build`, `check` only) |
| `--interval MS` | poll period, default 100 |
| `--debounce MS` | quiet period that collapses a burst, default 120 |
| `--json` | one JSON object per line per cycle, and nothing else |
| `--diagnostics-json FILE` | diagnostics as records in FILE, nothing printed |

`--watch` is refused by name on `run` and `test`, which have no cycle to repeat, and `--cache` is
refused with `--watch`: a cache hit is a cycle that does not run the compiler, and the point of
watching is that every change is checked.

### What is not here

- Watch does not make a cycle cheaper: each cycle re-runs the compiler the way a one-shot command
  does. Shortening the cycle is the build cache's axis, not watch mode's.
- mtime is never consulted, so every poll reads every input file. A cheap `stat` in the `host::`
  surface would let a poll skip files whose size and timestamp are unchanged; the hash would still
  decide.
- `--watch` is on `build` and `check` only.

## Measured before it was built: what a per-function unit could skip

Recorded before the unit existed, because it decided the shape, and kept because it predicted the
result. The predicate for "a function whose emission needs nothing from the rest of the run" was: it
requests no specialisation, creates no closure, asks for no drop helper, synthesises no declaration
and records no effect fact. Counted over the compiler's own sources at the time (1,867 bodies, 85 MB
emitted):

| | functions | emitted bytes |
| --- | --- | --- |
| self-contained by that predicate | 743 (40 %) | 2.5 MB (2.9 %) |
| not | 1,124 (60 %) | 82.5 MB (97.1 %) |

The reason is structural: in this compiler almost every non-trivial body instantiates a generic
(`view`, `push`, the iterator adapters), which registers a specialisation whose own body has to be
emitted into the same object, and nearly every body that owns memory asks for a drop helper. The
number to watch was 2.9 %, not 40 %, and the first implementation measured 34 % of bodies and about
5 % of a run's wall clock. The 2026-11-16 pass removed the two largest classes of that predicate -
a specialisation request and a drop-helper naming are now recorded in the unit and made again on
replay - and the compiler's own sources went to 2,708 units of 2,724 bodies.

## Measurements (printed by `tools/cache-test.mjs`)

The proof prints, for each case, the number of module runs reused, how long the build took, and
whether the image is byte-identical to a clean build of the same tree:

1. **a leaf module's edit** — a module nothing imports: one run re-done;
2. **a body-only edit** — the interface is byte-identical afterwards: no importer re-runs
   (the measurement the design exists for);
3. **an interface edit** — the edited module and every run after it re-done;
4. **a one-function edit in a large module** — the compiler's own `compiler/native.grl` if the
   harness can do it in reasonable time, otherwise a scaled-down module of the same shape, and the
   note says which.

Every case ends with a byte comparison against a clean, uncached build of the same tree, and the tool
prints the wall clock of each build and the miss list for each case. Measured on this host (six
module runs; a generated module of 400 functions stands in for the compiler's own `native`; the
absolute times move with the machine's load, the miss lists do not):

| edit | wall clock | runs redone |
| --- | --- | --- |
| nothing changed | 79 ms | none - `program up to date` |
| a leaf module's body | 221 ms | 1 of 6: `helper` |
| a body-only edit (interface surface unchanged) | 215 ms | 1 of 6: `util` |
| an interface edit (`pub` function added) | 4.8 s | 5 of 6: `util` and every run after it |
| one function of a 400-function module | 4.7 s | 1 of 6: `big` |
| (cold build of the same tree, for scale) | 5.8 s | 6 of 6 |

The last row is the honest limit of module-level incrementality: a one-function edit re-runs that
module, because a module is one compiler invocation. Everything else in the module's dependency
graph is reused, which is where the 5.8 s → 4.7 s comes from; the remainder is that module's own
parse, typecheck, codegen and assembly.

## What this does not claim

- **Authenticity.** Anything that can write `.work/` can plant an entry whose bytes match its name.
  The store is an integrity check against staleness and corruption, not against a hostile writer.
- **The toolchain's contents.** The assembler and the linker are identified by the words they are
  invoked with and the version they report, not by hashing a 100 MB binary.
- **Cross-module coupling that predates this note.** The whole-program (`--split`) shape still emits
  a generic specialisation into the part of the module that asked for it first, and its site table
  numbers statements over one stream; both are properties of a one-run build, and both are why
  `grail build`'s default shape — one run per module — is the shape incremental builds use. The
  module entry on the whole-program path additionally records the digest of the assembly its object
  came from and requires it to match, so an object is never reused when its text moved.
