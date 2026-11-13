# Module roots: the compiler resolves `use`

Decision: **accepted, implemented** (`compiler/native.grl`, `compiler/cli.grl`). This note is the
plan of record; the code it describes is `resolve_modules`, `header_of`, `mod_find` and
`input_path` in `compiler/native.grl`.

## The problem it removes

`use NAME;` names a module; it never named a file. Every module of a program had to be named on the
compiler's command line,

```
grail OUT.s ENTRY.grl MODULE.grl...
```

so every driver had to work out the set itself, and each one did it differently: `tools/test-native.mjs`
carried `stdClosure` (scan `lib/*.grl` for `use` lines and append what is missing),
`tools/book.mjs` carried `stdNames` (the same, for `example.std`), `compiler/cli.grl` carried
`used_std` for the same reason, and `tests/native-cases.json` and `book/book.json` listed std modules
by hand - 547 entries over 191 corpus cases, a dozen of which were wrong or incomplete in one round.

The failure mode of a guess that misses a transitive import was not "module not found": it was an
**unknown type or unknown function inside a module the reader did not write**, because the module that
imported the name compiled and the module that defined it did not.

## The design

The compiler closes the module set itself.

- **`--module-root DIR`**, repeatable. `use NAME;` is resolved by looking for `DIR/NAME.grl`.
- **Roots in order.** The explicit `--module-root`s in the order given; then, for every input file the
  command line names that sits in a directory holding `core.grl` - the stdlib layout, which is how the
  compiler already recognises a standard module by location (`in_std_dir`) - that directory; then the
  project's own `src/`, when the working directory holds a `grail.toml`.
- **First root that has the file wins.** Two roots holding `ROOT/NAME.grl` is a precedence rule, not
  an ambiguity: the earlier root answers. `grail build` passes the stdlib root, so a project module
  that shares a std name has to be named on the command line to be used instead.
- **The command line's own files win.** A file named on the command line is that module's file: when
  its declared module name appears, the name is already in the set and no root is consulted. Naming a
  module explicitly is therefore never wrong - only unnecessary - which is what let the workarounds be
  deleted without rewriting every case and tool at once, and what keeps
  `grail build lib/strings.grl`-style invocations working. Two files that declare one module name are
  still the parse's own error; resolution never creates that situation.
- **Transitive, and cycle-safe.** Resolution is a queue over the resolved files: a file's `use` lines
  are read when it is added, and a name enters the set *before* its own `use` lines are read, so
  `a` uses `b` uses `a` terminates with each module compiled once.
- **`core` is implicit.** `Some(x)` and `None` lower to `core::some` and `core::none`, so core is
  compiled whenever a root holds `core.grl`, without a `use core;` line. It is the one name resolution
  looks for unasked, and it is not an error when no root has it (a compiler invocation with no roots
  has no stdlib).
- **`use host;` is not a file.** It is a module's opt-in to the ambient `host::` interface, and
  resolution skips it.
- **Unresolvable is a hard error**, naming the module, the file that asked, and every root searched:

  ```
  grail: cannot resolve module `nosuch` used by bad.grl: no module root holds `nosuch.grl`; searched /repo/lib, src
  ```

  With no roots at all the message says so instead of naming an empty list. This replaces the confusing
  unknown-type report deep inside whatever module did not compile.
- **Interfaces keep their meaning.** Under `--use DIR` (build against interfaces) a `use NAME;` whose
  `DIR/NAME.iface` exists is that interface's module: no source is added for it, so a per-module build
  does not compile a module twice. Resolution runs *before* the interface directory is checked or
  loaded, so the manifest and the `--interface DIR` verification compare the sources the build really
  compiles.

## Reading a header without parsing

Resolution needs a file's module name and its `use` lines before the passes run, so `header_of` scans
the header region of the text - from the start of the file to the first item - and nothing else: blank
lines and `//` comments are skipped, `[unsafe] module NAME;` is the module, `use NAME;` and
`use NAME::item;` are the uses, and the first line that is neither ends the header. That is the whole
grammar of a header, and it costs one read per file (the parse reads the file again).

## Inputs are one list

A file's index stays the command-line argument index it always was. `mod_base` is how many arguments
the command line gave and `mod_files` holds what resolution added, so `input_path(index)` answers the
path for every consumer - diagnostics, `.file` directives, `@embed` bases, interface bookkeeping - and
the three passes iterate `mod_base + mod_files.len()`. A compile-time probe re-compiles the program:
it passes the `--module-root` options through and adds the resolved files to its key, so a change to a
resolved module changes the value the probe computes.

`--print-inputs FILE OUT.s ENTRY ...` writes one `NAME PATH` line per input - the module each file
declares and its path - and builds nothing. It has one caller: `grail build`'s per-module shape, which
has to group a program by module and cannot group by a module set it does not have. The driver asks
(`resolved_groups` in `compiler/cli.grl`), so every module the program has is a group - the standard
ones included - and no unit is compiled twice.

A compile that says `--separate` is one *part* of such a build, and its module set is settled
elsewhere: resolution is off for it, or a unit would compile a module into itself that another unit
also compiles. The same flag is why the driver does not pass `--module-root` to a unit.

`grail check --watch` / `grail build --watch` needs the input *set* rather than the grouping, and
watches every standard module - a superset of what any one program reaches - so a change to any of
them re-runs the cycle; the project's own files come from the lock's plan.

## The driver

`build_argv` in `compiler/cli.grl` is the one place the compiler invocation is spelled out, and the
build cache keys on that vector, so the wiring is one pair of arguments:

```
grail --target T ... --module-root <stdlib> OUT.s ENTRY.grl MODULE.grl...
```

The project root needs nothing: the compiler takes `src/` from the `grail.toml` in the working
directory, which is where `grail build` runs in a project. A project build also still names its
modules from `grail.lock` through `pkg::plan`, so a `grail.toml` that lists a file the lock does not is
still a manifest error rather than a silent resolution.

## What was deleted

- `stdClosure` in `tools/test-native.mjs` and `stdNames` in `tools/book.mjs`; both tools now pass
  `--module-root` (the staged std snapshot, and `lib/`).
- `used_std`, `use_names` and `contains_name` in `compiler/cli.grl`.
- Every `lib/...` entry of `files`/`modules`/`interfaceFiles` in `tests/native-cases.json` (547
  entries over 191 cases) and every `std` entry in `book/book.json` (13 examples).
- What stays: explicitly named modules that are *not* reachable by name - a fixture in
  `compiler/tests/` (`compiler/pkg.grl`, `tests/interfaces/pair.grl`, ...) and the book's own
  `examples/arithmetic.grl`, whose root is the example directory rather than `lib/`. Those entries
  name a file, not a guess about a std module, and a case whose fixture needs one says why in its
  `note`.

## Cases (tests/native-cases.json, names prefixed `useres-`)

- `useres-std-by-name` - a program that says `use fs;` and names no std file.
- `useres-transitive-chain` - program → `useres_chain` → `useres_chain_dep`, both resolved by name.
- `useres-cycle-compiles-once` - `a` uses `b`, `b` uses `a`; the program builds and runs.
- `useres-unresolved-names-roots` - the diagnostic names the module and every root searched.
- `useres-explicit-wins` - a module named on the command line and also present in a root: the named
  file is the one compiled (precedence), with no duplicate-definition error.
- `useres-no-root-is-an-error` - the same `use` with no roots says so.
