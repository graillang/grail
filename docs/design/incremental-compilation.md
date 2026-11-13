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

`grail build --watch` and `grail check --watch` keep one process warm and rebuild on change:

- it watches the project's sources, its manifest and the interfaces directory, polling mtimes with a
  short interval (no platform-specific event layer), debounced so a burst of writes is one build;
- each cycle prints one line — `watch: rebuilding (3 files)` then the build's own output, or
  `watch: up to date` — and nothing when nothing changed, so the terminal does not scroll;
- the first error is reported with its diagnostics and the *exit code of the build that failed* is
  what `--watch` leaves behind if it is used non-interactively; in the loop it reports and keeps
  watching, because that is the point of a watcher;
- it does not hold the compiler's file lock across cycles: the lock is taken inside each build and
  released before sleeping, so a second `grail build` in another terminal is never blocked;
- `Ctrl-C` exits with the last cycle's status.

The LSP (`tools/lsp/main.grl`) already re-drives `grail check` per buffer edit. It is *not* rewired
onto the watch process in this stage, and the reason is the shape of the interface rather than the
size of the change: the LSP needs a request/response channel with a document version, while watch
mode is a fire-and-forget loop over the file system. The seam is `--watch --json` emitting one JSON
object per cycle (`{"ok":bool,"diagnostics":[…]}`), which the LSP can read from the same fd it
already reads `grail check`'s stderr from; that is recorded here as the next step, not claimed as
done.

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

Every case ends with a byte comparison against a clean, uncached build of the same tree.

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
