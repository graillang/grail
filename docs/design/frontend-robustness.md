# Front-end robustness

A compiler that panics on source text a person can type is a hole in a workhorse language: the user
sees `assertion failed` and a compiler source line where a diagnostic belongs. Two bugs of exactly
that kind were fixed by hand (a character literal with two characters in it asserted inside the
lexer, and `same()` read past a shorter slice and aborted the compiler with `index 4 out of
bounds`), and nothing in the corpus would have told us if a third had arrived. This is the standing
answer: a fuzzer over real sources, a classification rather than a count, the list of what it found,
and a fixed seed of it in `ci.mjs lint`.

## The fuzzer

`tools/fuzz-frontend.mjs` mutates real Grail sources and runs one compiler per case. It looks for one
thing: the compiler failing at its own job.

**Corpus.** Every `tests/**/*.grl`, every `book/examples/*.grl`, and the compiler's own modules
(`compiler/*.grl`) - 218 sources under the default `--max-bytes` cap. The cap exists because a case
is one compiler run and `compiler/native.grl` is 1.5 MB: checking it is a whole compile of the
compiler, minutes per case. `--max-bytes 0` takes that source too when a run can afford it.

**Mutations.** Byte deletion, byte duplication, byte swap, truncation at a random byte, one inserted
byte from a set a person or a bad encoding can produce (`' " ( ) { } ; : = @ #`, digits, a non-ASCII
lead and continuation byte, NUL, newline, backslash, backtick), and line deletion and duplication.
One case is one to three mutations applied in order: one is easiest to shrink, three still leaves a
repro a person can read.

**One case, one project.** The mutated file is written to `<case>/src/<its own name>` beside symlinks
to its sibling modules, plus a one-line `grail.toml`, which is what makes `src` a module root. Then
`grail check src/<name>` runs in that directory. Without the layout, a module that `use`s a sibling
is refused before the front end ever reads it.

**Classification.** `fine` is the language refusing a program: exit 0, or exit 1 with `error: ...` or
`error[Exxxx]: ...` followed by a `-->` location. `bug` is the compiler dying: killed by a signal, or
its own runtime reporting `assertion failed`, `index N out of bounds for length M`, `range A..B out
of bounds`, `unwrap of None or Err`, `arithmetic overflow`, `stack overflow`, `the program aborted`,
`note: this is a compiler bug`, or a run that outlives `--timeout`. Everything else is reported as
itself under `other`, with the reason, because a classification that cannot say "I do not know"
hides bugs.

**Deduplication and shrinking.** A hit is filed under its crash signature: the normalised message
plus the compiler source location the report names (`... @ compiler/native.grl:5874:5`). One entry
per crash site, not one per fuzz hit; the case that reached it keeps its bytes and output under
`.work/fuzz/bugs/NAME/`. `--shrink` walks the bytes down (lines first, then byte runs, then single
bytes) while the case still crashes the same way, and writes `minimal.grl`.

**Determinism.** The corpus is read in sorted order and every case is generated before any case runs,
so `--seed` fixes the cases and `--jobs` changes only the wall clock.

## How to run it

```sh
# 200 mutations from seed 1 against the tree's own compiler (what `ci.mjs lint` runs)
bun tools/fuzz-frontend.mjs --cases 200 --seed 1 --jobs 4 --quiet

# a long run: every source, more cases, shrink what turns up
bun tools/fuzz-frontend.mjs --cases 2000 --jobs 8 --max-bytes 0 --shrink

# the same seed against a compiler you name (a release binary, an older seed)
bun tools/fuzz-frontend.mjs --cases 200 --seed 1 --compiler .work/native/seed/bootstrap
```

The compiler under test is the one this tree builds (`bun tools/native.mjs build`, cached by content
hash); `--compiler PATH` or `GRAIL_COMPILER` names another. The run ends with one line:

```
fuzz: 200 cases, 186 fine, 0 bugs, 0 hangs, 14 other (seed 1, 218 sources, 6 jobs, 25.2s)
```

`other` cases are `grail: cannot resolve module ...` - a mutation that renamed a `use` target is
refused by the driver before the front end runs, so it is neither a diagnostic nor a crash. The full
classification is in `.work/fuzz/report.json`; exit status is 1 when any case was a `bug` or a hang.

## What it found, and what each one says now

Before: `fuzz: 200 cases, 184 fine, 2 bugs, 0 hangs, 14 other (seed 1, 218 sources, 6 jobs, 25.6s)`
After: `fuzz: 200 cases, 186 fine, 0 bugs, 0 hangs, 14 other (seed 1, 218 sources, 6 jobs, 25.2s)`

### 1. A function whose body never arrives

A declaration the file ends in - `fn f(a: u64` with nothing after it - aborted the compiler:

```
error: index 24 out of bounds for length 24
 --> compiler/native.grl:5874:5
 = called from compiler/native.grl:13624:9
```

Three passes (`func`'s pass 1, pass 3 with type parameters, and the skip-a-reported-body replay) scan
forward to the body's `{`. The token stream ends with an end-of-file token, the scan stepped over it,
and `kind()` indexed `c.toks[pos]` unchecked. It now stops at the end of the file and refuses the way
any missing token is refused:

```
error: expected `{`, found the end of the file
 --> t.grl:1:12
  |
1 | fn f(a: u64
  |            ^
  |
1 | fn f(a: u64
  | -- this `fn` has no body
```

The fix has two halves, and both are needed: `kind`, `tok_text` and `fail` answer "end of file" past
the last token instead of faulting (`kind_at` already did), and `body_brace` stops the scan at EOF
and reports. An EOF-safe `kind` alone would turn the abort into a hang, which is why the scan stop is
not optional.

The other accessors that read `c.toks[c.pos]` already guard: `source_line`, `site_pos`, `emit_loc`
and `position_text` all test `c.toks.len() <= p` first. `decode_literal` and `token_line` take an
index the caller already holds from the stream (a literal token, a recorded declaration), so they
cannot be reached past the end and are unchanged. `fail` was the last unchecked one, and it is
reached by every refusal, so its guard matters more than the others: a refusal at the end of a file
(`struct S` with no body, for one) now draws its caret at the end of the source instead of
faulting.

Doors checked, all of them already refusals: truncated `struct`/`enum` (`unclosed `{``), `match`
(`unclosed `{``), `impl` (`unclosed implementation`), `interface` (`expected interface body`),
`extern C fn` (`extern requires a quoted ABI name`), `use` (module resolution). Regression cases:
`frontend-fn-without-body`, `frontend-fn-without-body-generic`.

### 2. A label on a file's first token

The same input, after the fix above, died one layer deeper:

```
error: index 1 out of bounds for length 1
 --> compiler/native.grl:6327:9
 = called from compiler/native.grl:6488:9    (expect)
 = called from compiler/native.grl:8395:9    (body_brace)
```

`fail` tracked which secondary labels it had drawn by setting the label's token index to 0, and 0 is
also a real token index: the `fn` of the first declaration in a file. The renderer then looked for
the label after the last one and indexed past its list. The marker is now a flag array, plus a guard
when nothing is left to draw. Any refusal that labels the first token of a file went through this,
not just the new one. Regression case: `frontend-fn-without-body` (the label is on token 0 and the
caret is at the end of the file, which is the worst case for that loop).

### 3. The entry refusal pointed into the standard library

Checking a module that has no `main` used to report an error in `lib/result.grl`, at a line the user
never wrote:

```
$ grail check lex.grl          # a module with pub fns and no main
error: executable entry must return u64
   --> .../lib/result.grl:128:1
```

`fail` reports at the cursor, and by the time the entry is checked the cursor is in whatever file the
last pass read. Entry *selection* is unchanged (a module with no `main` still makes its first public
function with at most one parameter the entry); the refusal now says which function that was and
where it is, or that there is none, in the file the caller named:

```
error: the entry `main::helper` was picked because this module has no `main`, and an entry must
return `u64`; it returns `u8[]`. Give the program a `pub fn main()`
 --> input.grl:1:5

error: no `main` and no public function with at most one parameter to use as the entry:
add `pub fn main()`
 --> input.grl:1:1

error: `main` must return unit or u64; this one returns `u8[]`
 --> input.grl:1:1
```

Regression cases: `entry-picked-function-named`, `entry-missing-names-the-file`,
`main-result-type-named`.

### 4. `return;` in a unit function could not be written

```
$ grail check x.grl            # fn main() { return; }
error: expected a name here, found `;`
```

There was no spelling at all for an early return from a unit function: `return;`, `return ();` and
`return unit;` were each refused with a message about the wrong thing. `return` now reads the `;` as
"no value" when the enclosing function's result is unit, and keeps the ordinary expression form
otherwise. A function with a result still has to produce one, and says so:

```
error: `return` needs a value here: this function's result is `u64`, so the `return` has
to produce one
 --> t.grl:1:23
```

Regression cases: `early-return-unit-function` (which also runs: the early return skips the
`println`), `early-return-needs-value`.

### 5. A record that contains itself by value was accepted in silence

```
$ grail check x.grl            # struct N{v:u64,next:N} ... : exit 0
```

No value of that type can ever be built - the field that names the record needs a value of the
record first - so the user had written a type they could never use and the compiler said nothing. It
is refused now, with the caret on the field that closes the cycle:

```
error: `N` contains itself by value: the field `next` carries the record itself, so no value of
it can be built. Break the cycle with an optional field (`N?`, whose value can be `None`), a
reference, or a vector
 --> input.grl:1:16
  |
1 | struct N{v:u64,next:N} fn main()->u64{return 0;}
  |                ^^^^
```

The walk (`needs_record`) follows only the edges a value cannot avoid: a struct needs every field, so
one field that needs the record makes it impossible; an enum needs one variant, so every variant has
to need it (an enum with no payload-free variant is refused the same way). A number, a view, a
vector, a reference and `T?` all end the walk, because each is a value on its own. That is what keeps
the accepted shapes accepted: `next: N?` compiles and runs (`recursive-record-through-optional`),
as do reference fields (`struct N<a> { v: u64, next: &a N<a> }`) and vector fields
(`next: N[]`) - there is no `Rc` in this standard library, and a reference needs a lifetime
parameter, so `N?` is the ordinary spelling; a mutual cycle is refused at whichever record is
completed second (`record-contains-itself-indirectly`).

## Open, and deliberately not bugs

- **`grail check` of one module that the program only reaches through the command line.** Checking
  `compiler/cli.grl` alone reports `unknown function `iface_digest` in `native`` - seven times -
  because `cli.grl` calls `native::...` without a `use native;` and the real build passes every
  module on the command line. That is a refusal of a program the build accepts, i.e. a diagnostic
  disagreement, not a crash; it is on this list rather than fixed here.
- **A mutated `use`.** `grail: cannot resolve module `sys_grail` ...` exits 1 with no `error:` line.
  It is the driver refusing before the front end runs, which is why the fuzzer counts it as `other`
  and names it in the report. A driver refusal in diagnostic form is a separate change.
- **Silent runtime traps** are the same class one layer down: a *program* that dies with an empty
  stderr. The narrowing conversion `u8(300)` was one; it is fixed in `compiler/native.grl` (the
  conversion calls the runtime's reporting path with `value N does not fit in u8`) and covered by
  `runtime-narrowing-conversion-report`.

## The lint seed

`ci.mjs lint` runs 200 mutations from seed 1 with four jobs and fails on any `bug` or hang, so a
front-end crash cannot come back unnoticed. It runs the tree's compiler, not the checked-in seed, so
the check answers for the sources in the tree; a host without the toolchain that builds a compiler
skips the check rather than passing it.
