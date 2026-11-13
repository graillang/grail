# Modules and source files

A module file declares its name; `use` names a dependency and `module::name` qualifies a reference.
The executable entry file may omit its module declaration, as hello world does.
This example calls a public function in another file.

{{example:modules}}

The supporting Grail and Rust files are included in the comparison above.

`use arithmetic;` is enough: the compiler resolves a module it was not handed by looking for
`arithmetic.grl` in each module root it was given, transitively, so a program says what it uses and
not which files implement it. The roots are the `--module-root DIR` options (repeatable, tried in
order), the standard-library directory of any input file that sits beside `core.grl`, and a project's
`src/` when the working directory holds a `grail.toml` - which is why `use fs;` is enough in a project
and why the standard library needs no listing anywhere. A module the command line names explicitly
still wins over a root, so naming a file is never wrong, only unnecessary. A `use` no root answers for
is an error that names the module, the file that asked and every root searched.

This example's helper is named on the command line anyway, because the chapter shows it: it lives
beside the example rather than in a module root, so naming it is how the book's own run finds it.

`docs/design/module-resolution.md` states the rule, the order the roots are tried in and the two
exceptions (`core`, which `Some` and `None` lower to, and `use host;`, which is the ambient interface
rather than a file).

A `use` declaration can name a module or import one member:

```grl
use hashmap;
use order::Ord;
```

After `use order::Ord;`, write `Ord` unqualified in bounds and implementations. Keep
`order::Ord` when a name is ambiguous or the qualified form is clearer. Module functions, types,
variants and interfaces all use `::` for qualification; `.` remains field and method access.

## Visibility

What a module offers other modules is what it marks `pub`; everything else is its own. That holds
for every kind of item: functions, `extern` declarations, records, enums, handles, constants, type
aliases, interfaces and methods.

```grl
module shapes;

pub struct Circle {
    r: u64
}

pub fn area(c: &Circle) -> u64 {
    return 3 * square(c.r);
}

fn square(x: u64) -> u64 {
    return x * x;
}
```

Another module can call `shapes::area` and build a `shapes::Circle`, but `shapes::square(2)` is a
compile error at the call:

```
error: `square` is private to module `shapes`
help: declare it `pub` in `shapes` to use it from `main`
```

As in Rust, the default is private and `pub` is the export. Two differences: a `pub` record's
fields are public with it (Grail has no per-field visibility), and the methods of an
`impl Interface for T` are as visible as the interface they implement. A module's interface file
carries only its public surface, so changing a private function does not make its importers
rebuild - unless a public generic function's body calls it, in which case it travels in the
interface marked private, usable by the generic's code and still not nameable.

The Grail-written compiler is the sole implementation; declarations, generic bodies and
dependencies are checked before an output artifact is replaced.

## Building modules: the work a build can skip

There is no Rust comparison in this section, and that is not an omission: these are build-driver
flags, not language constructs. Rust splits the same job across two programs - `rustc`'s incremental
mode and Cargo's fingerprinting - so a pair of programs would compare nothing a reader could run.
The Grail behaviour is stated below instead, with the one part of it this book can execute marked as
such.

What this tree does:

- `grail build` of a program of more than one module runs the compiler once per module, in dependency
  order. Each run parses its own sources, reads the interfaces the runs before it wrote, writes its
  own interface and one assembly file, and the program is linked once. A program of one module of its
  own - where `grail new` starts - is a single compiler run and a single file, which is all it needs.
  Linux x86-64, AArch64 and RISC-V take this path; Windows and macOS build the whole program, and so
  does `--whole-program`, which asks for the one-run build. `--per-module` asked for this path before
  it was the default, and is still accepted.
- `grail build --split` is the older shape: one run checks the whole program and emits one stream,
  which is then cut at module boundaries so that one object per module can be assembled (Linux
  x86-64, without `--debug` or the LLVM backend). The code does not change: the parts minus their
  prologues concatenate to the single file byte for byte, and the linked programs print the same
  output. That is the shape `tools/split-test.mjs` pins, beside the default build's agreement with
  `--whole-program` on every Linux target.

Checked module interfaces (`docs/design/separate-compilation.md` has the built shape):
`grail check --interface DIR` writes one file per module plus a manifest, `grail build
--interface DIR` compiles against those files instead of the imported modules' sources, and
`--verify` re-reads the sources and refuses the first declaration that disagrees. A file is a
versioned, length-counted record stream - one writer, one reader, no text in between - and
`grail iface dump FILE` renders the record tree the reader read, so an interface is reviewable
without a second parser; `grail iface roundtrip FILE` reads it back, writes it again and requires
the bytes to be identical. A file is refused by name
when it is missing, stale (the recorded source digest no longer matches), disagreeing with the
sources, written in another format version, truncated, carrying a record this compiler does not know,
or edited (its trailer's digest covers every byte before it); all of that is checked before one
declaration is installed. It carries the handle audits (`transfer=N share=N`) and a closure's
environment record, which is what stops a module that imports a handle from re-deriving the safe
answer for the wrong reason. A generic template's body does travel, so an
importer instantiates a foreign generic without its source; a module's own code is still parsed and
emitted in the run that names it, so the checked surface is real and the rebuild saving is the
cache's.

The build cache (`grail build --cache`). In a per-module build it keeps each module's compiler run:
its key is over the module's own source digests, the surface of every interface it can read (each
interface's bytes before its trailer, so an edit that changes no declaration leaves it alone), the
compiler's and the assembler's
identity, the target and the flag vector. The flag list is not maintained by hand - the key hashes
the invocation vector, so a flag added to the driver is in the key by construction. Entries live under
`.work/cache/<target>/` with the digest in the path and every write staged and renamed, and a blob is
reused only after its bytes are hashed again and match the name it is filed under, so a corrupted or
truncated entry is a miss and a rebuild rather than a wrong answer. A whole-program build keeps the
older objects: the linked image keyed by every input the build reads, the link keyed by the object
digests, and one module's object keyed by its source digest and its place in the emission stream.

What that looks like from the outside, on a three-module project beside the runtime and the start
stub: a first build with a cold store misses everything; an unchanged rebuild reports `program up to
date` and reuses every run (about 15x faster here); editing one module's body reruns that module
alone; changing what it declares reruns the runs after it, because their keys name its interface's
surface; a corrupted object entry is rebuilt and its entry repaired, with output identical to the
uncached build. One honest limit is worth more than the numbers: a module's key names the interfaces
it reads, not the bodies behind them - which is what makes a body edit cheap, and why a surface change
is conservative. The cache also claims no authenticity: anything that can write `.work/` can plant an
entry whose bytes match its name.

Watching instead of rebuilding by hand (`grail check --watch`, `grail build --watch`). One process
stays alive and re-runs the cycle when an input changes: the source named on the command line, or,
in a project, the plan the manifest and the lock resolve (the entry plus every module the lock
names), every standard module (the watcher does not copy the resolver's answer - it watches the
stdlib directory), and every file in an `--interface DIR`. Change detection is a content hash of
each input, not a timestamp, so an editor that writes a file back unchanged spends no cycle and a
file restored with an old timestamp still does. A burst of writes is one cycle: the loop waits for
the files to go quiet (120 ms, `--debounce MS`) before it runs, and it polls every 100 ms
(`--interval MS`). The first cycle runs immediately, an error does not end the process, and each
cycle prints its diagnostics followed by exactly one summary line:

```
check ok 24 ms
error 1 diagnostic 31 ms
built target/app 210 ms
```

No lock is held between cycles, so a `grail build` in the same directory runs while the watching
process waits. `--json` replaces the summary with one JSON object per line per cycle - `cycle`,
`status`, `ms`, `output` for a build, and a `diagnostics` array of `{file, line, col, code,
message}` - which is what an editor or a language server reads; the compiler's own
`--diagnostics-json` seam supplies those fields, so nothing parses printed text. A watch process
ends on a signal, and because the runtime installs no handler the status on termination is the
signal's (130 for SIGINT), not the last cycle's; `docs/design/incremental-compilation.md` states
that limit with the reason. This is a driver loop the book cannot execute, like the flags above.

**Try it:** add another helper and change the call. Keep all source files in the invocation. Then run
`grail check --watch` with the same files, break one, and watch the next cycle report it.
