# Separate compilation and checked module interfaces (B1)

Decision: **accepted**. This note is the plan of record; it is written against the compiler as it
is today, so every claim about current behaviour can be checked in `compiler/native.grl`.

## What the compiler does today

- Every module named on the command line is parsed into one program: `c.decls` (records, enums,
  unions), `c.funcs` (functions, with `module` and `name`), `c.aliases`, `c.types`. The set is not
  the command line's alone any more: the compiler resolves `use NAME;` through its module roots and
  compiles what it finds, so a driver passes roots rather than a hand-maintained list
  (`docs/design/module-resolution.md`). A module's *index* is still its argument index, which is what
  the rest of this note means by "the file's index".
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
 // grail-interface 4
 module pair
 source "tests/interfaces/pair.grl"
 sha256 "ad1f2b3cf421decab61ea22f7dfc572fec79a74a3078b3ef330f4e49a94db2d0"
 mode typed_refs=1 default_u64=1 overflow=checked target=x86_64
 abi dyn pair size = 16 align = 8 word0 = data word1 = vtable drop = 0
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
- **Nothing, if it is a source module.** Every source module of the program gets an interface,
  except the runtime and the platform modules: `core` gets one like any other module when it is a
  source module of the build (which `use` resolution makes it), and the prelude is not exempt as a
  category. What gets none is not a source module: the synthetic units `.impl_N`, `.inherent_N`,
  `.interface_N`, `.union`, `.result`, `.closure` and `__start`, and the entry's process furniture.
  An implementation's methods travel under the declaration they belong to (`inherent`/`impl`
  sections), a union travels as its members, an environment record travels as the closure type's
  environment, and the process entry belongs to no module at all.
- **The runtime and the platform modules.** `module runtime` - the portable runtime and the platform
  module (`os-linux.grl`, `os-windows.grl`, `darwin.grl`), which all declare it - is the trusted
  base: it is compiled from source in every build and has no interface.
- **Anything the module keeps private** (see Visibility below), except what a public template's body
  needs. `tools/interface-test.mjs` also pins that no body, no local name, no synthetic module and no
  other module's declaration appears in an interface.

### Visibility

`pub` is a checked boundary. Every item - function, `extern` declaration, record, enum, handle,
constant, type alias, interface and inherent method - is private to the module that declares it
unless it carries `pub`. Naming a private item from another module (`m::helper(x)`, `m::Secret {..}`,
`m::hidden`, `p.offset()`, a bound `T: m::Private`, `impl m::Private for T`) is refused at the use:

```
error: `helper` is private to module `vis_lib`
help: declare it `pub` in `vis_lib` to use it from `main`
```

The methods of an `impl Interface for T` are as visible as the interface. Two exemptions keep the
trusted base working: the runtime reaches every module, and its own items (which never take `pub`)
are reachable from the unsafe modules that call into it. Visibility is checked where a name is
resolved, so the compiler's own lookups - an interface being read, a template body replayed in an
importer, which compiles in its own module - are not affected.

An interface carries the public surface: every `pub` item, every interface implementation and closure
environment, and, to a fixpoint, each private item that text already carried mentions - the
private helper a public generic's body calls, a private type a public signature names. A carried
private item is followed by a `private <kind> <name>` line at the end of the file, so an importer
can compile the template against it but cannot name it. Everything else stays out, so an edit to a
private function's signature no longer changes the interfaces of its module's importers.
`tests/visibility/` pins the surface (`visibility-public-surface`, built from interfaces too) and the
four refusals.

A whole-program build given `--interface DIR` compiles every module from its source and requires
each module's interface in `DIR` to say what the source says (a changed source is refused as
stale); interfaces stand in for source only where the source is absent (`--use`, the per-module
build).

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


## Stage 3 as built: generic bodies in interfaces

Implemented on `b1-generics`; `tools/interface-test.mjs` section (e) is the proof and this section is
the record. The interface format went to `// grail-interface 2` for this, and to 3 when pool job
handles (`Job<T>`, spelled `(job T)`) became expressible, which emptied the not-expressible list. It
went to 4 when the `abi` line joined the header: a `&dyn I` is an 8-byte pointer to a 16-byte
`{data@0, vtable@8}` pair (`docs/design/fat-dyn.md`), and two modules that build one for different
layouts cannot be linked together, so the file states the ABI it was compiled against and the reader
refuses a line that differs. A v3 file meeting this compiler fails with the version it was written
in rather than being read as if the line were optional.

### The representation

A type-generic template's declaration text travels in its module's interface, under the `fn` line
that already carried its checked signature:

```
fn generic::twice <1> ((tparam 0)) -> (tparam 0)
body 3
line "fn twice<T>(value: T) -> T {"
line "    return value;"
line "}"
```

- one `line` row per source line of the declaration, escaped (`\\`, `\"`, `\xHH` for anything
  outside printable ASCII), because the interface's lexer refuses a raw control byte inside a
  string. A changed statement is one changed line in a review diff, which is the property the text
  format was chosen for;
- `body N` states the row count, so a truncated section is refused rather than half-parsed;
- the reader rebuilds the rows into a *virtual source file* (`<iface>:<module>::<name>`, index
  1000000+) and points the function at it with position 0. `replay_function` already parsed a
  template from `(file, pos)`; it now parses one that no command line mentions, and diagnostics
  inside it name the interface and the template rather than a source file that is not there;
- what is carried is the *checked* declaration, not a typed body: the `fn` line is the checked
  signature (parameter types, result, lifetimes, bounds, interface requirements) and the text is
  the body the declaration pass saw. Nothing is re-derived from a table index, and `--verify`
  re-emits the module and compares, so an edited body is refused by name like any other line.

`grail check --interface DIR` still requires every module's source, because it is describing the
module as it is. A *build* no longer does:

```
grail ... --use DIR            # modules whose source is not on the command line come from DIR
grail ... --no-entry           # this object is one module of a link, not a program
```

### Instantiations are emitted once

The unit of deduplication is the *key*: the template's `module::name` plus a **structural**
spelling of its type arguments (`type_key`) - kind, mode, lifetime slots, the nominal name, the type
arguments, a payload that is a type, an interface's *name* for a proof. It lives in the emitted
symbol:

```
f_pair_make$3075c71d            # 16 hex digits: first 8 bytes of SHA-256 of the key
```

Two properties matter, and they are different:

- **it is total.** Nothing in the walk can refuse. A drop helper is referenced from every scope exit
  and a specialisation from every call, so a name is wanted in the middle of an ordinary build; if
  the name came from the interface's spelling, then any store kind the *format* cannot express would
  fail a build that has nothing to do with interfaces. That is exactly the regression this design
  first shipped, and `type_key` exists so it cannot come back: the interface writer keeps its
  refusal, the naming path cannot reach it, and `tools/interface-test.mjs` asserts that in the
  source as well as in behaviour.
- **it is a function of the type alone.** A position in `c.specs` (what stage 2 emitted, `$0`, `$1`,
  …) is a function of the order this run met instantiations in, of which other modules are in the
  build, and of how much each module instantiates - none of which two compiler invocations can
  reproduce. No index this run chose goes into `type_key`, including the two the store does expose:
  a proof's interface id becomes the interface's name, and an unknown kind's payload is walked as a
  type when it points into the type table. Verified by compiling the same program with its modules
  in different orders and with an extra module present, where the symbol is byte-identical - and by
  the case that decides it, two modules instantiating one generic on a *capturing closure*, whose
  environment record is synthesised per program and named by registration order: both ask for the
  same key, one body serves them, and the linked program prints what the source build prints.

One definition per key, not per entry in `c.specs`: two interned argument lists can describe the same
type (two closures with the same captures, two views of different element types), so the emitter
records the names it has emitted and skips a repeat. The key is the identity; an index is not.

With the key fixed, the ownership rule is one line: **a specialisation's body is emitted by every
module that asks for it, weak, under its content-addressed name; the linker keeps one.** A run that
loaded the template from an interface replays the body the interface carries; nothing is requested
of the defining module, so a module's object depends only on its own source and the interfaces it
read - the property one invocation per module needs. (An earlier version had the defining module
emit the body and importers file `.sreq` requests that its build served with `--serve`; that made an
importer's edit force a rebuild of the defining module and needed the build order iterated to a
fixpoint, and was replaced.)

- The body goes into the *requester's* part, so `--split` keeps a module's code - including the
  instantiations it uses - in that module's part.
- A closure created while a specialisation is replayed is part of that body: it is named
  `<specialisation>_c<n>` by its ordinal within the replay (which every object reaches in the same
  order; a retried body rewinds the ordinal) and emitted weak alongside it.
- `tools/interface-test.mjs` section (e) compiles the entry and two importers against interfaces only,
  checks each emits the instantiation weak under one name, links three copies and runs the program
  against the source build; the closure-key section does the same for an instantiation on a
  capturing closure, which two runs synthesise independently.

Drop helpers had the same index-versus-content bug and got the same treatment: `.D<hex>` from the
SHA-256 of `type_key`, emitted `.weak` (a pure function of the type it drops, so two objects that
both emit it emit the same body and the linker merges them) and in a part of their own (`.helpers`)
rather than the runtime's, so a linked build takes each module's code from exactly one object and
merges the helpers. Two further run-local names surfaced the same way once a build had more than one
object, and are fixed here rather than in stage 4 because they are the same bug: a closure body is
now `<module>_c<index>` rather than `c<index>` (an index in this run's closure table), and a request
file carries the environment records its keys mention, so an instantiation on a closure can be served
by the module that defines the template.

### What the caller still checks

The body still replays at the caller for *checking* - once per instantiation - and that is
deliberate: the checker is per-instantiation and there is no typed IR to reuse, so skipping it would
skip the type check of the instantiation itself. What moved is emission and the source dependency.
The replay at the caller is also what makes refusals land where the user wrote the call:

```
tests/interfaces/handle_bad.grl:7:54: type does not satisfy Share: handles::Lock is thread-affine
  (declared transferable, not shareable)
```

### Capability metadata survives an instantiation

An importer can only launder a type through a generic if the generic's checks stop applying at the
instantiation. Three things keep them applying, all of them carried, none re-derived:

- the template's **bounds** (`bound <i> <mask>`, `Send`/`Share`) travel on the `fn` line, and the
  check runs at the call site against the substituted types, so the interface is the authority for
  "this template requires `T: Share`";
- a handle's audited contract (`transfer=`/`share=`) travels on its `type … handle` line, so the
  substituted handle is classified by the interface, not by default-deny;
- a closure type's `Ty.env` travels as `(closure … env)` plus the `env` section, and the reader
  rebuilds the environment record.

The refusal above is produced from the interface alone: `handles.grl` is on neither command line,
and the diagnostic still says which handle and which classification refused it.

### Measured

Measured on this host, with the fixtures and the corpus:

- **The compiler's own build is unaffected.** All of its type parameters are lifetimes
  (`fn sum<a>` in an `inherent` block is `(&a Point)`), so its ten modules carry **no** template
  bodies: `compiler-*.iface` files are unchanged in size and the self-build emits and assembles the
  same text as before. The payload is paid only by a module that actually has `fn f<T>`.
- **A generic-heavy library pays one row per source line.** The corpus's four-module
  `vecs-fold-and-predicates` program carries 29 template bodies (15 in `vecs`, 11 in `core`, 2 in
  `hash`, 1 in `order`); its interfaces go from 10,812 bytes in format 1 to 16,492 in format 2, of
  which 7,044 bytes are the `line` rows. Text, not a blob: `git diff` of an interface shows the
  statement that changed, and the 29 headers cost 0.25 KB of the difference.
- **Emission stops being per importer.** In the interface suite's three-module proof (`main`,
  `generic_a`, `generic_b` instantiate `generic::twice<u64>`), the two importers' objects define the
  body zero times and reference it, the defining module emits it once from the request files alone,
  and the linked program prints and exits exactly as the single-run source build. Before stage 3
  those two modules could not be compiled at all without `generic.grl` on their command lines.

What that is worth for a build shaped like the compiler's: nothing yet, because its modules
instantiate no type-generic template. What it is worth for `lib/`-heavy code (`vecs`, `core`,
`pool`, `hashmap`) is the unit the numbers above size: one body per instantiation per *build*, not
per importing module.

### What stage 3 does not do, and why

- **No typed IR.** The body is text that the body pass replays; the "one parse, no re-check" shape
  needs the typed IR that stage 3 was originally scheduled after, so it is still ahead of us. What
  is gone is the *source* dependency and the duplicate emission.
- **No driver.** `--use`/`--no-entry` are the primitives a driver needs, not the driver. (The
  request protocol this stage first shipped also needed importers built before the defining module
  and iterated to a fixpoint; the weak-emission model that replaced it has no ordering
  constraint.)
- **Requests are not re-checked for bounds.** The defining module re-specialises a request and
  replays the body against the substituted types (which is a real check), but it does not re-run
  `require_constraints` on the request's arguments: the run that asked for it already did.
- **A request is written in the interface format.** The defining module parses it with the interface
  reader, so a type the format cannot spell cannot be asked for across a module boundary: that case
  is refused by name at the boundary rather than named locally, because a type with no spelling
  cannot appear in an exported signature either. Naming the same type *inside* one build - a drop
  helper, a specialisation two modules of that build share - is unaffected: `type_key` is total.
- **A request file has no manifest.** `--use` verifies each interface's own digest; a directory
  rewritten wholesale is trusted, exactly as the manifest's own note says. Signing is stage 4's.
- **No `__start`/runtime sharing.** `--no-entry` keeps a module's object from defining the process
  state, but two runs still both emit the runtime module, so a full per-module link needs the
  helpers weak (done) and the runtime split out (stage 4). `tools/interface-test.mjs` links each
  module's part from one run and merges the helper parts.

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
- **Stage 4 — build cache and incremental driver. Started** (`b1-cache`; the cache as built is
  recorded below). Content-addressed objects keyed by source hash + interface hashes + compiler
  digest + toolchain + flags are in place and proven by `tools/cache-test.mjs`, and `grail build
  --cache` reuses them. What is left is the other half: one compiler invocation per module, so an
  unchanged module is not re-parsed either, and `grail build` plans a module graph rather than taking
  a file list.
- **Stage 3 — generic bodies in interfaces. Done** (`b1-generics`; the representation, the dedup
  key and the named limits are recorded above). The body travels as checked text rather than typed
  IR - the typed IR is still the thing that would make the *checking* shared too - and a
  specialisation is emitted once, by the module that defines the template, under a
  content-addressed symbol.
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

## Stage 4 as built: a build cache

Implemented on `b1-cache`; `tools/cache-test.mjs` is the proof. `compiler/cli.grl` carries the store and
the driver, and `grail build --cache` is the flag. The build shape is still stage 1's `--split` (the
cache reuses what that produces, per module), so `--cache` implies `--split` and is available where
`--split` is: the Linux x86-64 assembler path, without `--debug`.

### Three entries, each keyed by what determines its artifact

The cache is not one key. Each artifact it can skip producing has its own key, over exactly the inputs
that determine that artifact - nothing that cannot change it, and nothing that can.

| entry | the key | names | what a hit saves |
| --- | --- | --- | --- |
| `map/prog` | every input the build reads (entry, modules, the std modules reached through `use`, the runtime and platform modules, each with its digest), the digest of `DIR/interfaces.manifest` when interfaces are read, the compiler's own digest, the target, the flag vector, the assembler's and the linker's identity, the output name, and the content of every file a `// grail-link:` note names | the linked image | the whole build |
| `map/lnk` | the object digests in link order, the link inputs with their digests, the linker's identity, the target | the linked image | the link |
| `map/mod` | the module's source digest, the digests of the interfaces it reads, the compiler's digest, the assembler's identity, the target, the flag vector, the runtime and platform digests, and the module's position in the emission stream | that module's object | assembling that module |

The flag component is not a list somebody maintains. `build_argv` is the one place the compiler
invocation is spelled out, and the key hashes that vector, so a flag or an input file added to the
driver is in the key by construction - there is no second place to forget. `--debug`, `--overflow=`,
`--backend=llvm`, `--deny-ambient-host`, `--interface`, `--verify-interface` and the capability flags
the compiler takes are all covered for the same reason.

The compiler's own digest is in every key, so a new compiler cannot reuse an old object. The
*assembler* and the *linker* are in the keys for the same reason: an object is a function of the text
and of the assembler, and an image is a function of the objects and of the linker.

### The store

```
.work/cache/<target>/
  blob/<sha256>     artifact bytes; the file name is the digest of the bytes inside it
  map/prog/<key>    `blob <digest>`, `parts <n>`, `output <path>`, `link <digest> <path>` ...
  map/lnk/<key>     `blob <digest>`
  map/mod/<key>     `module <name>`, `asm <digest>`, `blob <digest>`
  stage/            every write lands here first and is renamed into place
```

This is the discipline `tools/native.mjs` and `tools/bootstrap.mjs` already use - content in the
path, write to a staging name, rename into place - extended to a store shared by all builds of a
target. A record is written to `stage/` and `mv`d; a blob is copied to `stage/` and `mv`d. A crash
leaves at worst a file in `stage/`, which the next build overwrites; it can never leave a partial
entry under a name a later build would trust.

A blob is only reused after its bytes have been hashed again and matched against the name it is filed
under, and a module entry is only reused when the digest of the assembly it was built from still
matches the assembly just emitted. So a corrupted, truncated, edited or unreadable entry is a miss and
a rebuild, and filing a repaired artifact replaces the damaged entry instead of leaving it to miss
forever. `tools/cache-test.mjs` damages an object, an image and a record and asserts the rebuild, the
repair and the byte-identical result.

What the store does *not* claim is authenticity: anything that can write `.work/` can plant an entry
whose bytes match its name. That is the same boundary stage 2's `interfaces.manifest` states, and
signed or keyed manifests are still what a cache that has to resist a hostile writer needs.

### What is not in the key, and why that is safe

- **Other modules' bodies.** A module's key names the interfaces it reads, not the bodies behind them -
  that is the point of an interface. But today's front end is one whole-program pass: the optimizer
  inlines across module boundaries and the emitter numbers its local labels over one stream, so a
  module's emitted text can change because *another* module changed. A module entry therefore records
  the digest of the assembly its object was built from, and reuse requires it to match. A stale object
  is impossible; the cost is a miss, and `tools/cache-test.mjs` measures it: editing the entry module
  of a five-part program misses all five, because every later module's local labels are renumbered.
  This is also what keeps stage 3 honest in the meantime: a generic body that moves into an interface
  is not in the importer's key, but a change to it changes the importer's emitted text, and the guard
  catches that.
- **The toolchain's contents.** The assembler and the linker are identified by the words they are
  invoked with and the `--version` they report, not by the digest of their binaries: a 100 MB clang
  would cost more to hash than most builds save. A rebuilt tool that reports the same version from the
  same path is therefore not separated from the old one. This is the one input whose *content* is not
  in the key, and it is deliberate.
- **The rest of the environment.** `GRAIL_HOME`, `GRAIL_ASSEMBLER`, `GRAIL_LINKER` and `GRAIL_SDK`
  reach the key through the paths and words they resolve to. A `PATH` change that resolves a different
  tool with the same words and the same version is not caught.
- **Non-determinism.** If an assembler produced different bytes for the same text, the cache would
  hand back the first result. The identity test - a cached build byte-compared against an uncached one
  - is what would catch it, which is why that comparison is part of the proof and not a nicety.
- **The interface set as a whole** is in the program key but not in a module key, because a module's
  assembly cannot depend on an interface it does not read; its own dependencies are named one by one.

### What it costs, and what it saves

A cached build pays for hashing: the compiler's own binary (12 MB), every source, the tools' version
probes, and a `sh` per digest. That is why the store prefers the host's `sha256sum` when it is there
and falls back to the compiler's own SHA-256 when it is not - the same digest either way, milliseconds
instead of seconds for the big files. On the proof project a cached build costs about 55 ms of that
overhead and saves the 0.7 s build it replaces.

Measured by `tools/cache-test.mjs` (three modules plus runtime and `__start`, five parts; the absolute
times move with the page cache, the ratio does not):

| | |
| --- | --- |
| cold store, cached build | ~0.7-1.5 s - 0 hit, 5 miss |
| unchanged sources, cached build | ~60-120 ms - 5 hit, 0 miss, `program up to date` - 12-13x |
| one module's constant edited | 3 hit, 2 miss (`main`, `util`) - the edited module and the module that reads it |
| one flag changed (`--overflow=wrap`) | 0 hit, 5 miss |
| one interface tampered, no source edited | 4 hit, 1 miss (`main`) - the importer, and nothing else |
| an object entry corrupted | 1 miss (`helper`), rebuilt, entry repaired, output byte-identical |
| an image entry corrupted | relinked, entry repaired, output byte-identical |

### What stage 4 still does not do

- **One compiler invocation per module.** Parsing and code generation are still one whole-program pass,
  so the cache cannot skip the front end for an unchanged module; it skips that module's assembly, and
  the whole build when nothing changed. This is the boundary of what `compiler/cli.grl` can do: one
  invocation per module needs the emitter in `compiler/native.grl` (no `__start` in every run, no
  shared stream), which is stage 4's other half.
- The **label renumbering** above disappears with it: a module compiled alone emits its own text, its
  own labels, and is determined by its own key. At that point the emitted-assembly guard becomes
  redundant and the module entry can be keyed by its inputs alone.
- **Store maintenance.** Every build that opens the store advances its generation
  (`.work/cache/<target>/generation`), and every record a build writes or reuses records that
  generation beside it (`map/<kind>/<key>.used`). `grail cache prune [--keep N]` drops the records no
  build used in the last N (default 10), then every blob no remaining record names, and whatever a
  killed build left in `stage/`; `grail cache clear` empties the store. A store pruned right after a
  build keeps exactly what that build used (`tools/cache-test.mjs`, (f)).

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
- ~~content-addressed objects keyed by `(source sha256, interface digests, compiler digest, toolchain,
  flags)`~~ - built on `b1-cache`, with the key, the store and its limits recorded above in "Stage 4 as
  built";
- one compiler invocation per module (no `__start`, no whole-program stream), which is what lets a
  module's code stop being parsed at all - the thing stage 2 deliberately does not do, and the reason
  the cache cannot yet skip the front end. It also removes the label renumbering that makes an edit
  re-spell every module emitted after it;
- the driver plans a module graph instead of taking a file list, and decides which modules must be
  compiled from source because a generic body is needed;
- the authenticity question the manifest cannot answer: anything that can rewrite `DIR` can rewrite
  `interfaces.manifest`, so a cache that has to resist a hostile writer needs signed or keyed
  manifests. The store added above states the same boundary for itself.


## Every type is expressible

Format 3 spells every store kind the compiler has; the last one added was the pool job handle
(`Job<T>`, `(job T)`), which had kept the 11 pool programs out of interface builds. `interface-test`
now treats a refusal (`this interface format cannot express a type of that kind`) as a failure, so
a new store kind cannot land without its interface spelling. The refusal itself stays: an interface
is never written with an approximated type.

## One compiler invocation per module (the default build)

`grail build` of a program of more than one module is one compiler run per module. The runtime, the
platform module and the standard library's `core` prelude are in every program and do not count as
modules of their own: what is left is what the program is made of. A program of one module of its own
is a single compiler run and a single assembly file, which is all it needs.

The driver groups the program's sources by the module each declares (the runtime and platform files,
which declare none, are module `runtime`; an entry file without a `module` line is `main`), orders the
groups so each comes after the modules it `use`s - `runtime` first - and compiles each group with its
own compiler run:

    grail <flags> [--use DIR] --emit-interface DIR --separate [--no-entry] <module>.s <its files>

Each run reads the interfaces of the modules built before it and writes its own beside them, so a
module's run parses its own source and nothing else; every specialisation it uses is emitted weak in
its own object (the emission model above). `--separate` says what the run is: one object of a
program, not a program, so every definition becomes global and the run writes one file. The object is
assembled with the target's usual assembler and the program is linked once. Runtime-error locations
work per module: each object carries its own statement table, so a check that fails in a module the
entry never mentions reports that module's `file:line` and the frames above it.

`--whole-program` asks for the older one-run build, `--split` (below) for the older parts shape, and
`--per-module` is still accepted as a name for the default. Windows and macOS have no per-module
object path here, so they build the whole program, and an `--interface` build checks every module
against its interface in one run.

`tools/split-test.mjs` builds a project with a generic from another module and the standard library's
`vecs::sort` both ways and requires the same output from eight separate runs, on x86-64, AArch64 and
RISC-V (the cross targets are run under qemu).

With `--cache`, each module's run is keyed by its inputs alone: the build's flags, compiler and
assembler, the target, the module's name and source digests, and the *surface* of every interface the
run can read (each interface without its `sha256` and `digest` lines, which change with the module's
body). A hit restores the run's object, its link inputs and its interface and skips the compiler run
and the assembler; a miss runs both and files the outputs. The image is filed under the program key,
so a rebuild of unchanged sources prints `program up to date` and runs nothing. Because a module
compiled alone emits its own text and labels, the emitted-assembly guard the whole-program cache needs
is not used on this path. Measured on the eight-run project: a warm rebuild is 8 hit, 0 miss; editing
one module's body is 7 hit, 1 miss (that module); changing its surface reruns it and the runs after
it. The key names every interface present, not just the ones a module reads, so a surface change
reruns some modules that do not import it - conservative, never stale.


### What a run compiles, and what it writes

A run compiles the files it is given and writes one interface per module it compiled from source: a
module a run compiles from source appears in the interface set of that run exactly once, whether the
command line named it, `use` resolution added it, or - for a program that is a list of sources, like
the compiler built against its own modules - it was simply one of the files. The set is every source
module except the runtime and the platform modules (the rule above, stated once, for both shapes). A
module a run read from an interface (`--use`) is not re-read from source in that run: it is
described by the interface it came from, and the run that compiled it from source is the one that
writes that interface. A per-module build therefore writes each interface once per build, and the
interfaces a build leaves behind are its modules' objects minus the runtime, which is the trusted
base and has none. (`tools/cache-test.mjs` (g) counts the runs; the corpus case
`drv-per-module-three-modules` counts the interfaces against the objects.)

The manifest is where that set is visible: an emitting run writes `interfaces.manifest` with one
`MODULE <digest-of-its-interface> <digest-of-its-source>` row per module it wrote. `--interface DIR`
is a verification build - every module given as source is compiled and checked against
`DIR/<module>.iface`, which is what `--verify-interface` says explicitly - so the manifest is also
the set that build checks: a source module the manifest does not describe is refused by name, with
the same diagnostic a missing file earns (it names the module and the file it should be in), and the
refusal comes from the manifest, so an emitting run whose source list and its set disagreed surfaces
at the boundary instead of one module later as an unknown name inside somebody else's module.
Interfaces standing in for source a build does not have is `--use`, which reads the files it is
given and has no manifest to check.

The driver builds in the order of the `use` graph plus one edge no source writes: `core`. `Some(value)`
and `None` lower to `core`'s constructors, so a module may need `core` without naming it, and `core` is
resolved into every program with a stdlib root. A unit built before `core` looks `some` up in a module
nothing has declared yet, and the build dies with ``unknown function `some` in `core` `` in whichever
module first writes one - with no `core.iface` left behind, because `core`'s own run never happened.

`core` is not a leaf, so the modules it needs cannot all be built after it: `core` `use`s `result`,
whose `Option` is the type `T?` names, and `result` is a group of its own. Those modules are the
prelude: built before `core`, and the only ones that do not get the implicit dependency on it
(`runtime` is the base every run has). The prelude is the one part of the order the `use` lines do not
already describe.

That order is acyclic only because `result` builds its option values through the variant -
`Option::Some(v)`, not `Some(v)` - inside `lib/result.grl`. The shorthand lowers to `core::some`, so
writing it there would put `result` in `core`'s dependency set and make the prelude circular: `core`
would need `result`'s `Option` for its own signature and `result` would need `core`'s `some` for its
bodies, and one compiler run per module can order neither before the other. Nothing else about the
language changes: `Some(v)` outside `result` still lowers to `core::some`, and a unit that writes one
reads the declaration from `core`'s interface and emits the specialisation weakly in its own object.

## Stage 5 as built: a per-module label namespace and module-local inlining

Implemented on `gaps2-sepcomp`, and the two things this section exists for are the two things that
made one module's edit re-emit the text of every module after it. Both are recorded in
`tools/cache-test.mjs` (the `(b) precision` case) as numbers, and the tool fails if either comes
back.

### Labels are minted per module

The emitter numbered its local labels over one stream: `.L1`, `.L2`, … from the first byte of the
program, so a change in an early module re-spelled the text of every module emitted after it — the
exact bug the opening comment of `tools/cache-test.mjs` recorded. Every label is now minted from a
per-module counter and spelled in that module's namespace:

```
.L<module>_<hash>_<n>          e.g. .Lutil_1f3a9c02_7
```

- the prefix is the emission unit's own name (`util`, `.helpers`, `__start`, or the module a
  synthetic `.impl_N`/`.inherent_N` belongs to), sanitised to identifier characters, followed by
  eight hex digits of a hash of that name, so no two units can collide even after sanitising;
- the counter restarts at 1 in each unit. `part()` — the one place that switches emission unit —
  resets it, and everything that mints a label goes through `label(c)` and `lname(c, n)`, so there
  is no second place to forget;
- the two counters whose values were spelled into a label without going through `lname` are scoped
  the same way: the refinement-obligation counter (`c.ref_next`, `.Lrfp<n>` / `.Lrfr<n>`) is reset
  by `part()`, and the inliner's per-site counter (`_i<n>`, which disambiguates two inline sites of
  one body) restarts at every unit marker;
- the module markers the splitter reads (`.grail_part <module>`) are now emitted whenever the
  optimizer runs, not only with `--split`, and the optimizer records the emission unit of every
  function from them. A single-file build drops the marker lines from its output; a split build
  keeps them, exactly as before, so `tools/split-test.mjs`'s "the parts are the single stream"
  invariant still holds.

### Inlining does not cross a module boundary

`optimize.grl` inlines a small leaf's body at its call sites. That is sound and fast inside a module
and *not* separate compilation across one: it makes a caller's text depend on a body the caller's
module never declared, and once modules are cached separately it makes the caller's object depend on
a source its key does not name.

The gate is therefore: **inline only when the callee's emitted body is in the caller's own emission
unit** — same module, or a body the caller itself emits (a specialisation it requested, a drop
helper). The interface-level door stays open in the same place the format already has one: a body
carried in an interface (`body N` / `line "…"` rows) is available to an importer, so a future
explicit *inline-body* option can permit a cross-module inline exactly where the importer can see
the body it is copying. Nothing is silently inlined from a module whose body is not there.

Consequences, stated rather than discovered:

- the generated code of a whole-program `--split` build is slightly different from before (a small
  leaf called across a boundary is a call now), and it is *the same code* the per-module build
  produces — which is the property that matters, because those two shapes are what
  `tools/split-test.mjs` compares;
- the single-file build keeps cross-module inlining only where the optimizer knows no unit
  boundaries; it emits the same markers, so both shapes inline identically.

### The frame constant, which was a latent miscompile

The per-unit change found a real defect that had nothing to do with caching. A function's frame
constant was `.F<label>`, minted from the same counter, and `.set` defines *one symbol per file*:

```
subq $.F1,%rsp        # this function's frame
...
.set .F1,656          # this function's size
...
.set .F1,80           # another function's size, same name
```

A single-file build whose label counter happened to give two functions the same `.F` name therefore
had one function's frame size decide another function's displacements — silently, because the
assembler resolves the symbol and the program merely addresses the wrong part of its frame. It was
reachable before this stage (any program where two functions were minted the same frame number) and
`--split` made it worse, because a part's `.set` lines are a subset and the last definition in the
file can differ between the two shapes. `tools/split-test.mjs` caught it as a `.text` length
difference between the split and single shapes for a generic-heavy program; the frames are now named
in the unit's namespace too (`.F<unit>_<n>`), so a frame constant is unique per file in both shapes.
`tools/cache-test.mjs` and `tools/split-test.mjs` both compare bytes, which is what made it visible.

### The two interface modes, and who must have an interface

There are two ways a build meets an interface, and they ask different things:

- **`--interface DIR` is verification mode.** Every module given as *source* is compared with
  `DIR/<module>.iface`: the interface must be present, must record that module's source digest, and
  must say line for line what the sources say, or the build refuses by name. Nothing comes *from*
  the directory - the build has the sources. This is the mode that catches a stale or edited
  interface, and it is the mode every source module of the program is checked in.
- **`--use DIR` is substitution mode.** A module not given as source on the command line has its
  declarations and its generic bodies taken from `DIR/<module>.iface`; the module named as the
  entry is compiled from its source. This is the build shape `grail build` uses per module: the
  modules built before it were compiled from source into interfaces, and this run reads those.

So *every module whose surface is read by something else must have an interface* - that is what the
per-module build writes as it goes - and a module that is given as source in verification mode must
match the interface it has. A reject case that means "the entry from its source, the library from
its interface" is a `--use` case, not an `--interface` one; using the verification mode there asks
the entry to match an interface nothing wrote, which is a different question and not the one the
case is about.

One strength limit belongs here, next to the effect-fact transport. In a `--use` build a refined
parameter's predicate text is in the interface, but the *file* it was written in is not, so an
obligation in a separately compiled caller cannot be located in that file and keeps its runtime
check: sound, and weaker than the same call compiled from source. Refinements therefore survive
separate compilation as contracts, not (yet) as proofs across it.

### What is still coupled, honestly

The whole-program shape emits a generic specialisation into the part of the *module that asked for
it first*, so the set of instantiations in the program decides which part carries it, and its site
table (`.Lgs<n>`) numbers statements over one stream. Neither exists in the default per-module
build, where each run emits its own weak copy of every specialisation it uses and each object
carries its own site table. The whole-program cache therefore still records the digest of the
assembly each object came from and requires it to match — a stale object remains impossible, and the
cost is a miss, not a wrong binary.

## Stage 6 as built: effect facts in interfaces

`@no_alloc` and `@no_panic` are claims about a function *and everything it calls*
(`docs/design/effects.md`), proved by a fixpoint over the call graph the run emitted. Separate
compilation breaks the fixpoint's premise: the callee's body is not in this run.

The transport is a per-function row, and it is a row *about the symbol*, not about the source text:

```
fn util::touch (u64) -> u64
effects 1 0 0
```

`effects <no_alloc> <no_panic> <strict>` follows the `fn` line of the function it belongs to, so it
is keyed by `module::name` (whose mangled symbol the `fn` line already states) rather than by a
table index or by anything derived from the order this run met declarations in. The reader installs
it on the declaration, so a callee whose body is absent answers the fixpoint with the fact its own
module computed and its own module verified (`fx_callee_alloc` / `fx_callee_panic` consult the
declaration when there is no body in this run).

That gives three properties, and each has a case:

1. **A program that claims `@no_alloc` builds per module.** The claim is proved in the module that
   owns the body, and the importer's claim is proved against the transported fact. `sep-*` cases in
   `tests/native-cases.json` build such a program through the default (one run per module) shape and
   an `--interface` build, and require the same answer.
2. **A missing row is not silently a fact.** A callee with no row and no body in this run is assumed
   to allocate and to fail, so a caller's claim is *refused* with the chain naming the callee rather
   than accepted on an unknown. Conservatism in the safe direction.
3. **A stale row is impossible.** The row lives in the interface, and the interface is pinned by the
   source digest, the file's own digest and the manifest; `--verify` re-emits the module and compares
   the row. A row that survives to a build is a row the module's own run wrote, so it describes a
   body that run proved.

The effects worker owns the proof itself (what the facts are computed from, and the typed-IR change
under it). This note owns the transport: a row per function symbol, spelled in the interface, with
the module's own verification standing behind it — so a change in how facts are computed changes the
*values* in the row, never the shape of the transport.

Incremental compilation — edit cost, the content-addressed store, the function-level unit and watch
mode — is designed in `docs/design/incremental-compilation.md`.
