# Modules and source files

A module file declares its name; `use` names a dependency and `module::name` qualifies a reference.
The executable entry file may omit its module declaration, as hello world does.
This example calls a public function in another file.

{{example:modules}}

The supporting Grail and Rust files are included in the comparison above.

Unlike an implicit package loader, today's native compiler needs every source file explicitly.
The example manifest lists its helper, and `just book-run modules` supplies both files plus the
Grail runtime. The entry file comes first. `use arithmetic` by itself does not search the disk.

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

What this tree builds today, and what it does not:

- `grail build` reads every file on the command line, checks the whole program, and emits one
  assembly file. `grail build --split` cuts that finished stream at module boundaries and links one
  object per module (Linux x86-64, without `--debug` or the LLVM backend). The code does not change:
  the parts minus their prologues concatenate to the single file byte for byte, and the linked
  programs print the same output. This is the shape `tools/split-test.mjs` pins.
- **Not in this tree yet**, on branches `b1-interfaces` and `b1-cache`: checked module interfaces and
  the build cache flag. Neither is part of `bun tools/book.mjs check`, so nothing below is verified by
  the book - it is the behaviour those branches record, restated so a reader knows what is coming
  rather than discovering it.

Checked module interfaces, as `b1-interfaces` builds them (`docs/design/separate-compilation.md`;
its stage-2 and stage-4 "as built" sections live on those branches):
`grail check --interface DIR` writes one text file per module plus a manifest, `grail build
--interface DIR` compiles against those files instead of the imported modules' sources, and
`--verify` re-reads the sources and refuses the first line that disagrees. A file is refused by name
when it is missing, stale (the recorded source digest no longer matches) or disagreeing with the
sources, and its format version, module, compiler modes and own digest are checked before one
declaration is installed. It carries the handle audits (`transfer=N share=N`) and a closure's
environment record, which is what stops a module that imports a handle from re-deriving the safe
answer for the wrong reason. It does not carry bodies: generics still record a source dependency, and
the module's code is still parsed and emitted in the same run - so the checked surface is real and
the rebuild saving is not yet.

The build cache, as `b1-cache` builds it (`grail build --cache`, which implies `--split`, and is
available where `--split` is). It is not one key but three, each over exactly the inputs that
determine one artifact: the linked image keyed by every input the build reads, the compiler's own
digest, the target, the flag vector and the assembler's and linker's identity; the link keyed by the
object digests; and one module's object keyed by its source digest, the interfaces it reads and its
position in the emission stream. The flag list is not maintained by hand - the key hashes the
invocation vector, so a flag added to the driver is in the key by construction. Entries live under
`.work/cache/<target>/` with the digest in the path and every write staged and renamed, and a blob is
reused only after its bytes are hashed again and match the name it is filed under, so a corrupted or
truncated entry is a miss and a rebuild rather than a wrong answer.

What that looks like from the outside, on the branch's own proof project (three modules plus the
runtime and the start stub, five parts): a first build with a cold store misses everything; an
unchanged rebuild reports `program up to date` and reuses all five; editing one module's constant
misses that module and the one that reads it; a corrupted object entry is rebuilt and its entry
repaired, with output identical to the uncached build. Two honest limits are worth more than the
numbers: a module's key names the interfaces it reads, not the bodies behind them, and because the
front end is still one whole-program pass a module's emitted text can change when *another* module
changes - so a module entry also records the digest of the assembly it was built from and reuse
requires it to match. The cost is a miss, never a stale object. The cache also claims no authenticity:
anything that can write `.work/` can plant an entry whose bytes match its name.

**Try it:** add another helper and change the call. Keep all source files in the invocation.
