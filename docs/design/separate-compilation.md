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

## Stage 2 as built: checked module interfaces

Implemented on `b1-interfaces`; `tools/interface-test.mjs` is the proof and this section is the
record. `compiler/native.grl` carries the writer, the reader and the build path; `compiler/cli.grl`
exposes them as `grail check --interface DIR [--verify]` and `grail build --interface DIR [--verify]`.

### Commands

```
grail check --interface DIR                 # write DIR/<module>.iface + DIR/interfaces.manifest
grail check --interface DIR --verify        # refuse an interface that disagrees with its sources
grail build --interface DIR                 # read DIR/<module>.iface instead of the module's source
grail build --interface DIR --verify        # parse the sources and compare them with DIR
```

`--interface` and `--emit-interface` on the compiler itself are the same two operations for a flat
file list (`grail check`/`grail build` just supply the project's modules).

### What an interface contains

One line per declaration, declarations sorted by name, and a header that states where the file came
from. The format version is the first line, so a file written by another compiler is refused rather
than misread.

```
 // grail-interface 1
 module pair
 source "tests/interfaces/pair.grl"
 sha256 "ad1f2b3cf421decab61ea22f7dfc572fec79a74a3078b3ef330f4e49a94db2d0"
 mode typed_refs=1 default_u64=1 overflow=checked target=x86_64
 unsafe 0
 std 0
 host 0
 templates 0
 type pair::Pair struct params=0 lifetimes=0
 field left u64
 field right u64
 type pair::Which enum params=0 lifetimes=0
 variant First unit
 variant Second u64
 alias pair::Row (named pair::Pair)
 const pair::SCALE u64 int 3
 fn pair::flatten ((named pair::Which)) -> u64
 fn pair::make (u64, u64) -> (named pair::Pair)
 inherent pair::Pair
 fn sum ((ref [1] (named pair::Pair))) -> u64
 lifetimes 1
 digest "90e9eed4bebaf86f0d546893afa2f78c1b32991c77912ef551fc2b8adde33892"
```

Types are written in one canonical prefix spelling (`(ref [1] (named pair::Pair))`: kind word, mode
when it is not 0, regions when there are any, then the payload). A declaration's identity is
`module::name`, never a table index, so an interface is a description of a module and not a dump of
one compiler's internals.

Text was chosen over a binary format because an interface is read by reviewers and by the compiler
in roughly equal measure: a changed declaration has to be one changed line in a review diff.
Ordering is by name for the same reason - moving a function in the source does not reshuffle the
file. Each file ends with a digest of every byte above it, and `DIR/interfaces.manifest` records the
bytes of every interface the emitting run wrote.

The audit metadata the parallelism design asks for travels with it:

- `handle` declarations carry `transfer=N share=N` (default both 0), so a module that reads the
  interface sees the contract its author audited instead of re-deriving default-deny;
- a closure type carries its environment record: `Ty.env` is written as `(closure mode regions
  (params) result ENV)` where `ENV` is either `0` or a `(named .closure::envN ...)` type whose record
  the file carries as an `env envN` section with one `field` line per capture. No source-level
  declaration produces a capturing closure type today (the only producer is a closure expression), so
  no emitted interface contains one yet; the format, the writer and the reader all handle it, and
  `--verify` re-reads every type it writes to prove the reader rebuilds it, so stage 3 starts from a
  format that cannot lose it;
- `T?` / `T | E` unions are structural: the file states their members (`(union 0 (...))`) and the
  reader rebuilds the same synthesised declaration by the same rule, instead of naming a table index.

### What an interface deliberately does not contain

- **Bodies.** A module's code is not in its interface; `--interface` still compiles the bodies it
  needs, because one object for the whole program cannot leave a module out (see "still missing").
- **Local names, statements, comments.** The writer never emits token text: only declarations, types
  and flags.
- **Synthetic compiler modules.** `.impl_N`, `.inherent_N`, `.interface_N`, `.union`, `.result`,
  `.closure` and `__start` never appear as modules: an implementation's methods travel under the
  declaration they belong to (`inherent`/`impl` sections), a union travels as its members, an
  environment record travels as the closure type's environment, and the process entry belongs to no
  module at all.
- **The runtime.** `module runtime` (the portable runtime and the platform module) is the trusted
  base: it is compiled from source in every build and has no interface.
- **Anything the language keeps private.** `pub` is not a visibility boundary in Grail today: a
  caller can name any top-level declaration of another module, and the corpus does so
  (`stream_def::Stream` and `stream_def::fopen` are not `pub`). An interface therefore carries the
  module's whole top-level surface - exactly what an importer can name - and adds a `pub` flag only
  once the language grows a visibility rule to enforce. `tools/interface-test.mjs` pins the part that
  is enforceable now: no body, no local name, no synthetic module and no other module's declaration
  appears in an interface.

### Refusals

All three are named, exit 1, and name the module and the file:

1. **missing** - `--interface DIR` wants `DIR/util.iface` and it is not there;
2. **stale** - the source on the command line no longer hashes to the `sha256` line:
   `grail: DIR/util.iface: module `util` changed since this interface was written: the interface
   records source-sha256 <a> for "src/util.grl", but src/util.grl is <b>`;
3. **disagreeing** - `--verify` (or a mismatched manifest) refuses with the first differing line:
   `grail: DIR/util.iface: module `util` does not match this interface: line 12: the interface says
   `type util::Stream handle params=0 lifetimes=0 transfer=0 share=0`, the sources give
   `... transfer=1 share=0``.

An interface is checked, not trusted: the format version, the module, the compiler modes (typed
refs, numeric default, overflow, target), the source digest, the file's own digest and the manifest
are all verified before one declaration is installed. The trust boundary is stated rather than
implied: whoever can rewrite `DIR` can also rewrite `DIR/interfaces.manifest`, so the manifest is an
integrity check against a stale or edited file, not an authenticity check against a hostile writer -
that is the build cache's problem (stage 4), and it will key on the same digests.

### Generics: option 1, as planned

A type-generic template's body is not in the interface. The file records
`templates 1` for the module and `body "<path>" pos <n>` for each template; an importer that
instantiates one needs that source on its command line, and refuses by name when it is not there.
Nothing is silently stale: the source dependency is exactly as visible as the digest that pins it.

### Stage 2 as built, measured

The compiler's own ten modules emit nine interfaces (the runtime has none) in one run; `--interface`
compiles the same compiler and links a binary that answers `version` and compiles a generic-heavy
corpus program to byte-identical assembly. `tools/interface-test.mjs` records the numbers and runs
the corpus.

### The one place this was wrong, and what it was

An earlier commit of this branch compiled every program that included `lib/hashmap.grl` against
interfaces into `type does not satisfy interface bound`. The interface was complete: `Map` carried
`require 0 hash::Hash` / `require 0 hash::Equal`, its field carried the proofs on `K`, and
`impl<K: hash::Hash + hash::Equal, V> Map<K, V>` travelled with `ptype`/`require` lines. The bug was
one type the **loader** invented: it interned the implementation's self type (`Map<K, V>`) from bare
type parameters *before* the section's requirements were read, and `validate_type_constraints` walks
every nominal type in the store, so that bare `Map<K, V>` was rejected. The self type is now built
once, after the section's names, bounds and requirements are in place, with the same interface proofs
the source parse produces, and the loader no longer interns a half-built one.

Two things were wrong in the test as well, and are worth naming because they made a green run
unlikely to mean what it said:

- it ran a case's program with no arguments and from the repository root, so a case such as
  `lib-zlib` (whose fixture path is relative to the case directory) could never print what it
  expected;
- nothing asserted that the manifest is consulted at all, so a manifest check that compared nothing
  would have looked exactly like a passing tamper test. There is now a case that corrupts only the
  manifest's recorded digest and requires a refusal, separate from the case that edits the interface
  itself.

### What stage 2 does not do, and why

`--interface` reads declarations from interfaces, but the module's **bodies are still parsed and
emitted in the same run**. That is deliberate and it is the honest boundary of stage 2:

- a build still produces one object for the whole program, so it cannot leave a module's code out;
- leaving the code out needs one object per module - the invocation model stage 1's record
  describes - and that driver is stage 4 ("`grail build` learns to plan a module graph") together
  with its cache;
- a generic's typed body has to be in the interface before a module that instantiates it can be
  compiled without its source, and that is stage 3.

What stage 2 does buy is the property it exists for: every cross-module reference in a `--interface`
build is checked against the interface rather than against the imported module's source, and an
interface that is missing, stale or different from its module stops the build by name.

## Stages

- **Stage 1 — per-module emission, no interface files. Done** (`b1-module-emission`; what was built
  and measured is recorded below). Split emission so each module's code goes to its own `.s`,
  assembled in parallel, linked once. No semantic change, no new format; immediately gives parallel
  assembly and smaller diffs in generated code. Verifiable by comparing the result against today's
  single-file build for the native suite, the book and the compiler itself.
- **Stage 2 — interface files, checked. Done** (`b1-interfaces`; what was built, the format and its
  named limits are recorded below). Emit and read interfaces as above; a module compiled against an
  interface refuses to proceed when a hash disagrees. Generics record a source dependency (option 1).
  The compiler keeps a whole-program path (`grail build a.grl b.grl` today) so nothing is forced to
  migrate at once.
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

## What stage 3 and stage 4 still have to solve

Recorded here rather than discovered later:

**Stage 3 - generic bodies in interfaces.**
- a typed body format in a file, so `templates 1` / `body "<path>" pos <n>` becomes a body
  reference and a module can be used without its source;
- closures in signatures: today no declaration-level construct produces a capturing closure type,
  so the environment-record path in the format (`(closure ... env)` plus the `env` section) is
  implemented and verified but unexercised by the corpus - stage 3 is what makes it routine;
- the interface must then carry what replay needs today from the parser: a template's parameter
  lifetimes and bounds are already in the file, its typed body is not;
- a monomorphisation decision follows: a specialisation of a foreign generic currently lands in the
  part of the module that *defines* it, which is right for one object and wrong for one object per
  module.

**Stage 4 - object cache and the incremental driver.**
- one compiler invocation per module (no `__start`, no whole-program stream), which is what lets a
  module's code stop being parsed at all - the thing stage 2 deliberately does not do;
- content-addressed objects keyed by `(source sha256, interface digests, compiler version, flags)`;
  the interface header already carries every input except the compiler version, which is a one-line
  addition to the header;
- the driver plans a module graph instead of taking a file list, and decides which modules must be
  compiled from source because a generic body is needed;
- visibility: `pub` becomes a checked boundary, which shrinks an interface to the exported surface
  and needs a language rule the corpus does not have yet;
- the authenticity question the manifest cannot answer: anything that can rewrite `DIR` can rewrite
  `interfaces.manifest`, so a cache that has to resist a hostile writer needs signed or keyed
  manifests.

