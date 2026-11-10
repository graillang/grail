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

- **Stage 1 — per-module emission, no interface files.** Split emission so each module's code goes
  to its own `.s`, assembled in parallel, linked once. No semantic change, no new format; immediately
  gives parallel assembly and smaller diffs in generated code. Verifiable by comparing the linked
  result byte for byte against today's single-file build for the native suite and the book.
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

## What must stay true

- The whole-program path keeps working: the bootstrap seed, `book.mjs`, `test-native.mjs` and every
  existing tool call the compiler with a flat file list, and none of them should have to change in
  stage 1.
- Symbol names do not change, so stage 1 is a pure build-shape change.
- Diagnostics stay `file:line:column: message`, and an error in a module compiled against an
  interface still names the module the user wrote, not the interface file.
- Self-hosting stays a fixpoint test: the compiler must still compile itself, which after stage 2
  means compiling against its own interfaces — a good stress test for the format.
