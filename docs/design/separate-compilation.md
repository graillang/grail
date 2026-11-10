# Separate compilation and checked module interfaces (B1)

Decision: **accepted**. This note is the plan of record; it is written against the compiler as it
is today, so every claim about current behaviour can be checked in `compiler/native.grl`.

## What the compiler does today

- Every module named on the command line is parsed into one program: `c.decls` (records, enums,
  unions), `c.funcs` (functions, with `module` and `name`), `c.aliases`, `c.types`.
- Name resolution is by `(module, name)` (`find_decl`, `find_func`), so nominal identity across
  modules already exists — two records with the same name in different modules are different types.
- Symbols mangle to `f_<module>_<name>` (with a leading `_` on Mach-O), except `runtime`, whose
  functions keep their C-visible names because the generated code calls them directly.
- Generic functions and types are **specialised at compile time, in the compiler that compiles the
  call site** (`specialize`, keyed by a canonical key that erases aliases and lifts captured
  lifetimes). The generic's body is therefore needed wherever it is instantiated.
- One assembly file is emitted for the whole program, then assembled and linked once.

The consequence: a program can only be built as one unit, and changing any module recompiles
everything. Borg is about 363,000 lines, most of it in modules with small public surfaces; that
build shape does not scale.

## Target shape

```
grail build --emit-interface  app.iface  app.grl      # public surface only
grail build --use-interface   dep.iface  dep.o        # compile against a surface, not sources
grail link a.o b.o ... -o app
```

A module compiles to an object plus an interface. A dependent recompiles when the interface it read
changes, and a module's object is cached by `(source hash, imported interface hashes, compiler
version, flags)`.

### Interface contents

Text, line-oriented, versioned with a header. Deliberately boring: it is read far more often than
written, and a hand-readable file makes interface diffs reviewable.

- header: format version, module name, compiler version, the source hash it was built from;
- imports: the interfaces this module read, with their hashes (this is what makes rebuilds sound);
- nominal types: kind (record/enum/union), field names and types in declaration order, enum tag
  order, union member types, `c_layout` flag and C field widths;
- aliases: name and the type it denotes (fully resolved);
- functions: mangled symbol, full signature (parameter types, result, whether the result is owned,
  intrinsic ids for `runtime`), and the flags the caller needs (exported, external, unsafe);
- generic **templates**: name, type-parameter count and their bounds, plus a *specialisation
  requirement* marker (see below);
- constants and anything else the front end needs to type a call.

Interfaces are checked, not trusted blindly: an interface whose recorded dependency hash does not
match the interface found on disk is refused with a diagnostic naming both paths.

### Generics: the one real design question

Typed specialisation means the *body* must be available at every instantiation site. Three options:

1. **Source availability.** A module that instantiates a foreign generic also compiles that
   generic's source module. Simple, correct, and preserves today's performance; the cost is that
   interfaces do not fully hide sources for generic-heavy APIs.
2. **Serialized bodies.** Put the generic's typed body into the interface. This is real
   separate compilation, and it needs exactly the typed IR that LLVM stage 3 wants — so it should be
   built once, not twice.
3. **Monomorphic-only.** Instantiate generics inside their defining module and cross the boundary
   with monomorphic symbols. Efficient, but it forbids `vecs::sort_by(&mut v, f)` from another
   module, which the ports already use.

**Staged answer:** v1 ships option 1 — interfaces give checked surfaces, correct incrementality and
per-module objects for non-generic code, and a module that instantiates a foreign generic records
that module as a dependency (so rebuilds stay sound and nothing is silently stale). Option 2 lands
with the typed IR as stage 3, at which point the "source dependency" marker in interfaces becomes a
body reference. Option 3 is rejected: it would break the ports.

## Stages

- **Stage 1 — per-module emission, no interface files. Done** (`b1-module-emission`; what was built
  and measured is recorded below). Split emission so each module's code goes to its own `.s`,
  assembled in parallel, linked once. No semantic change, no new format; immediately gives parallel
  assembly and smaller diffs in generated code. Verifiable by comparing the result against today's
  single-file build for the native suite, the book and the compiler itself.
- **Stage 2 — interface files, checked.** Emit and read interfaces as above; a module compiled
  against an interface refuses to proceed when a hash disagrees. Generics record a source
  dependency (option 1). The compiler keeps a whole-program path (`grail build a.grl b.grl` today)
  so nothing is forced to migrate at once.
- **Stage 3 — generic bodies in interfaces**, once the typed IR exists; drop the source-dependency
  marker.
- **Stage 4 — build cache and incremental driver**: content-addressed objects keyed by source hash +
  interface hashes + compiler version + flags; `grail build` learns to plan a module graph rather
  than take a file list.

Borg's port starts at stage 2. Its build script will need to know module → file, which
`docs/design/borg-agent-port.md` already records as a blocker.

## Stage 1 as built: per-module emission, no interfaces

Implemented on `b1-module-emission`; `tools/split-test.mjs` is the proof and `docs/design/…` this
section is the record.

- **Emission is still one pass over one program, by design.** The optimizer inlines across function
  and module boundaries (`inline_calls` in `compiler/optimize.grl`), and generic specialisations are
  emitted where they are instantiated, so cutting the stream before the optimizer would change the
  code. Stage 1 keeps the single stream and splits it *after* lowering, which is why it can be
  bit-faithful at all.
- The emitter records a boundary whenever the module changes: `part()` in `compiler/native.grl`
  writes `.grail_part <module>` followed by `.text`, one marker per run of module code. `.impl_N`
  and `.inherent_N` are mangling names for one declaration inside a file, not modules a build could
  name, so they resolve to the module that file declares.
- `optimize::optimize_parts` reports the output offset of every marker it keeps, and `inline_calls`
  re-reports them when inlining rewrites the stream, so splitting never rescans the text. The writer
  (`write_parts`) then writes one file per run as a *slice* of the stream: splitting costs no copy,
  and the measured compile time is unchanged.
- `grail build --split` reads `OUT.parts` — the part files in link order plus the `// grail-link:`
  request a single-file build carries at the head of its assembly — assembles every part
  concurrently through `sh -c`, and links the objects once. Without `--split` nothing changes: the
  same compiler, the same single `.s`, the same command line, byte for byte.
- Scope: the Linux x86-64 assembler path, without `--debug` and without `--backend=llvm`. The other
  targets run `machine::lower` after the optimizer, which rewrites the stream and with it the marker
  offsets; they keep the whole-program build (their suites pass unchanged either way).

### What is program-wide, and what is not

Only one thing cannot belong to a module, and it gets one synthetic part:

- **the entry stub and process state** — `_start`, the `rt_state` words, the TLS bases and the
  `.note.GNU-stack` note — live in a part named `__start`. They exist exactly once per program;
  duplicating them would define `rt_state` twice, so the choice is synthesis, not duplication.
- There is **no assembler preamble to place**: with `--split` each part file opens with its own
  `.text`, which a fresh assembly file needs anyway.

Everything else is per-unit already, and this is worth stating because the design note assumed
otherwise:

- string literals and other read-only data are emitted *inside* the function that uses them
  (`.pushsection .rodata … .popsection`), so they travel with that function into its module's file.
  There is no program-wide literal pool;
- the runtime's own code is a module (`module runtime` in `compiler/runtime.grl`) and keeps its own
  file with its C-visible symbol names untouched;
- a specialised generic lands in the part of the module that *defines* the generic — its mangled
  name says so — so no body is split across two files.

Nothing is duplicated and nothing is pooled. The one place a module can produce more than one run
(hence more than one file, `OUT.NNN.module.s` in stream order) is a program whose specialisations of
another module's generics are emitted after other modules' code; both files name the module.

### What necessarily differs, and what does not

Two differences from the single-file build are inherent to linking several objects:

- **symbol binding.** A definition that another part calls has to be visible to the linker, so with
  `--split` every function is `.globl`, as are the drop helpers and the process state. Names, sizes
  and order are unchanged; only the local/global split differs — in the compiler's own build the
  symbol table is the same size and `sh_info` moves from 2366 to 1139.
- **link-time alignment.** Each input `.text` carries alignment 4, so the linker pads the gap
  between two parts whenever the previous one ended mid-alignment: 15 bytes across nine boundaries
  for the compiler, 3–15 bytes for the smaller cases. Only padding is inserted; code and data bytes
  are unchanged, and absolute addresses after a padded boundary move by that padding.

`tools/split-test.mjs` pins exactly this, on the book's `modules` example, a generic-heavy native
corpus case (`vecs-fold-and-predicates`: `vecs`, `order`, `hash`, `core` plus runtime) and the
compiler itself:

1. the parts, minus each file's `.text` prologue and the `.globl` lines separate objects need,
   concatenate to the single assembly file byte for byte, in the manifest's order;
2. the objects have the single object's `.text` length and are identical outside relocation fields;
3. the linked programs have the same `.rodata`/`.data`/`.bss`, the same symbol names, the same
   output — and the same exit status — as the single-file build;
4. `grail build --split` builds the same program as `grail build`.

### Measured difference

Host: 24 cores, clang 18 / lld 18; the compiler compiling itself — 10 modules, 33 MB of assembly.

| phase | single file | per module | |
| --- | --- | --- | --- |
| Grail compile (emit) | 15.6–15.8 s | 15.7–15.9 s | unchanged |
| assemble | 1.62–1.65 s | 0.99–1.02 s | −38 % (ten parts at once; 1.74 s if run serially) |
| link | 18–19 ms | 21–22 ms | +3 ms |
| total | ~17.3 s | ~16.8 s | −3 % |

The saving is the assembler's, and it is bounded by the largest part: `native` is 19 MB of the 33 MB
and takes 0.9 s of the 1.0 s, so the parallelism only pays once units get smaller. That is what
stage 2 (a module compiled alone) and stage 4 (object cache) give, and it is why stage 1 does not
try to parallelise the Grail compile itself.

### What stage 2 needs from this

- The part model, but as an *invocation*: one module per compiler run emitting one file, with no
  markers, no `__start` synthesis in every run (the entry stub belongs to the module that holds the
  entry, or to a generated `__start` file) and no shared `c.out`.
- `write_parts`/`OUT.parts` become the manifest of a whole-program build only; the driver grows a
  module graph instead of a file list (`grail build` learns to plan).
- The `.globl` decision becomes a *visibility* decision: a module compiled alone must export only
  what another module calls, which needs the reference tracking stage 2's interface emission
  already implies.
- The cross-module inlining that stage 1 relies on disappears once modules are compiled separately;
  that is correct (a module compiled alone has no other module's bodies) but it means code generated
  by `--split` today is not yet what a per-module build will produce. Comparing them is the stage-2
  acceptance test, not a stage-1 invariant.
- `tools/split-test.mjs` is the harness to extend: it already compares text, objects, images and
  behaviour for both shapes.

## What must stay true

- The whole-program path keeps working: the bootstrap seed, `book.mjs`, `test-native.mjs` and every
  existing tool call the compiler with a flat file list, and none of them should have to change in
  stage 1.
- Symbol names do not change, so stage 1 is a pure build-shape change.
- Diagnostics stay `file:line:column: message`, and an error in a module compiled against an
  interface still names the module the user wrote, not the interface file.
- Self-hosting stays a fixpoint test: the compiler must still compile itself, which after stage 2
  means compiling against its own interfaces — a good stress test for the format.
