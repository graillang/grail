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
map/unit/<key>     one function-level unit (below)
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

A module's run is not one artifact but many: a big module has hundreds of functions, and an edit
touches one of them. The plan is to cache **per function**, so a one-function edit in
`compiler/native.grl` (38k lines, ~2,600 functions) re-emits that function instead of the module.

The unit is *one emitted function body plus the data it needs*, keyed by:

    key = H(function body text, the module's surface snapshot, the interfaces the body reads,
            the layout/global inputs listed below, the compiler and target and flags)

and what it buys is the expensive part of the pipeline for that function: re-use of the *typed*
result and of the emitted body, so the front end does not re-typecheck it and the emitter does not
walk it again.

### What is in the key, and precisely what invalidates a function unit

This is the part that has to be conservative, because a code generator is full of shared state. The
key names, deliberately:

| input | invalidates | why it cannot be left out |
| --- | --- | --- |
| the function's own token span (body text hash) | that function | the obvious one |
| the emitted symbol and signature spelling | that function | a renamed or re-signatured function is a different unit |
| the module's interface surface hash | every function of the module | a `pub` change can change visibility, drop helpers and call conventions for the whole module |
| the surface of every interface the body reads | functions that call across the boundary | a callee's signature, bounds, `effects` and layout reach the emitted body |
| **layout inputs**: the record/enum/union declarations and their field widths the body mentions, and the C-layout flag | functions that mention them | field offsets are baked into the emitted text as immediates |
| **global/static data inputs**: every module-level `const`, static, string literal pool entry and vtable the body references | functions that reference them | a data symbol's identity and initialiser reach the body |
| **the module's label namespace and per-body label count** | functions whose emitted label text would collide | labels are minted per module and per body, so a body's labels depend only on its own minting order — but the *number* a body starts at is part of its text |
| the module's drop-helper set for the types it mentions | functions mentioning those types | helper names are content-addressed from the type, and a new helper changes nothing else — but a *removed* one changes a call |
| compiler digest, target, flag vector, assembler identity | everything | a new compiler or target is a different code generator |

Explicitly **not** in the key, and why that is safe:

- **Other functions' bodies in the same module.** A body reaches another body only through the
  interface-visible signature plus the emitter's cross-references; same-module inlining happens
  during the module's emission from *text* the optimizer has already seen, so the inliner's decision
  is part of the module's run, not of a function unit. Until the inliner is per-function (a later
  stage), a module that inlines re-emits the *caller* when it changes: the unit key includes the
  inliner's verdict for the calls the body makes (`inlined: <callee>@<n>`), so this is recorded
  rather than assumed.
- **The whole module's text.** If a function unit were keyed by the module's emitted text, an edit
  anywhere would miss every unit, which is the problem function units exist to remove.

A unit that cannot be given a complete key (anything the emitter does that the key does not name) is
**not cached**: it is emitted as today. The conservative direction is lexical — a body the key
cannot describe is a body that is always re-emitted, never a body that is reused on a guess.

### Where it plugs in

Per-module runs already produce one assembly file per module: the function-level cache sits inside a
run, between *deciding a module must be compiled* and *emitting its text*. A run that is a full
module-level hit never reaches it. A run that misses replays the unchanged functions' emitted bodies
into its own `.text` under the same symbols; changed functions go through the front end and the
emitter as they do today. Because the emitted text of an unchanged function is *replayed*, not
recomputed, the module's object stays byte-identical to the clean build — which is the property
`tools/cache-test.mjs` compares in every case.

Generics: a specialisation is keyed the same way — the template's body hash, the structural key of
its type arguments (`type_key`, which is already content-addressed and index-free), and the
interfaces it reads — so a specialisation is a unit like any other, and two modules that instantiate
the same key reach the same unit.

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

## Measured: what a per-function unit could skip, and what it cannot

Recorded before the unit was built, because it decided the shape. The predicate for "a function whose
emission needs nothing from the rest of the run" is: it requests no specialisation, creates no
closure, asks for no drop helper, synthesises no declaration or implementation, and records no effect
fact. Counted over the compiler's own sources (`compiler/*.grl`, 1,867 function bodies, 85 MB of
emitted text, on this host at this load):

| | functions | emitted bytes |
| --- | --- | --- |
| self-contained by that predicate | 743 (40 %) | 2.5 MB (2.9 %) |
| not | 1,124 (60 %) | 82.5 MB (97.1 %) |

So a per-function unit that replays a body's emitted text — and its helpers — but skips the front end
would skip 40 % of the *functions* and 3 % of the *work*. The reason is structural: in this compiler
almost every non-trivial body instantiates a generic (`view`, `push`, the iterator adapters), which
registers a specialisation whose own body has to be emitted into the same object, and nearly every
body that owns memory asks for a drop helper for a type interned during its own emission.

Two consequences, and they are why the function-level unit is *designed but not claimed*:

1. a body's emitted text is not a sufficient artifact: the run also needs the specialisations,
   closures and helpers the body *requested*, which is exactly the typed-IR and state serialization
   the typed-IR stage owns. Until that exists, the honest unit is the module run, and its cost is
   what the table below measures;
2. the number to watch is 2.9 %, not 40 %. Anyone revisiting this should re-run the count after the
   typed-IR change, because a body carrying its own specialisations no longer needs them from the
   run — that is the change that moves it.

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
