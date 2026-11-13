# Incremental compilation

Notes on the pieces that make a rebuild cheaper and a feedback loop shorter. The build cache
(`grail build --cache`), per-module builds and checked interfaces are described from the outside in
the book (`book/chapters/modules.md`, *Build and tooling*), where the parts a reader can execute are
marked as such; this document is the design behind them. The watch-mode section is the part that
`grail check --watch` and `grail build --watch` implement.

## Watch mode

`grail check --watch` and `grail build --watch` keep one driver process alive and re-run the cycle
when an input changes. The cycle is exactly what one-shot `grail check` or `grail build` does - the
same code path, in the watching process - so watch mode adds no second definition of "check" or
"build" that could drift from the first.

### The input set

The files a cycle reads, in this order:

- the source named on the command line, or, in a project, the entry `grail.pkg` names plus every
  `.grl` under `src/` and under each fetched dependency's `src/` - the same list the one-shot
  command compiles. (A second `FILE` argument is not a module of the first: `grail check a.grl b.grl`
  compiles `a.grl`, so watch mode watches `a.grl`. Modules of the entry are the project's, or the
  standard library's through `use`.)
- the standard modules the sources reach through `use`, found by reading the sources' `use` lines
  (`used_std`), so the set follows the code rather than a hand-maintained list, and a new import
  brings its module into the set on the next poll;
- every file in an `--interface DIR`, when one is given.

The set is recomputed on every poll rather than fixed when the process starts. A source that appears
(a new file under `src/`), disappears, or starts importing something else is therefore a change like
any other, and nothing has to be re-derived by hand.

### Change detection: content, not timestamps

A file's identity, for watch purposes, is a 128-bit content stamp: XXH64 of its bytes with two
different seeds (`lib/xxhash.grl`, the standard library's content hash). A missing file stamps as
two zero words, which is a state like any other.

Content, not mtime, on purpose:

- an editor that writes a file back unchanged, or a formatter that rewrites it with the same bytes,
  is not a change, so it does not spend a cycle;
- a source restored from a backup, checked out by git with an old timestamp, or copied with
  `cp -p` *is* a change, and a timestamp comparison would miss it;
- there is no `stat` in the `host::` surface in any case, so a timestamp scheme would have to shell
  out.

The cost is that each poll reads every input file and hashes it: a few megabytes for a program of a
few modules, once per `--interval` (default 100 ms). That is the price of not missing a change, and
it is paid while the process would otherwise be idle.

### Debounce

Writing a file often means several writes (a truncate, then the content; an editor's save, then a
rename), and a burst of saves across a few files is one intent. After a change is seen, the loop
keeps polling and re-stamps; a cycle runs only when the stamps have been unchanged for the quiet
period - 120 ms by default, `--debounce MS` to change it. One burst is one cycle.

A change that lands *while* a cycle is running is not lost: the poll after the cycle compares against
the pre-cycle stamps, sees it, and runs one more cycle once it settles.

### One cycle, one line

The first cycle runs immediately, before the first poll: a watch that said nothing until a file
changed would look broken on the program that is already correct.

Each cycle then prints its diagnostics - the compiler's own rendering, caret and all, so a terminal
shows what `grail check` would have shown - followed by exactly one summary line:

```
check ok 24 ms
error 3 diagnostics 31 ms
built target/app 210 ms
```

`error` reports the number of distinct diagnostics (`diagnostic` when there is one) and the cycle's
elapsed time. A cycle that failed for a reason that is not a diagnostic (no assembler, no linker)
reports the status without a count. Nothing else is printed between cycles: an idle watch process is
silent, so any line on its output is a cycle.

### `--json`, and where the diagnostics come from

`--json` makes a cycle's report one JSON object on one line, built from the diagnostic structures
rather than from the printed text:

```
{"cycle":2,"status":"error","ms":31,"diagnostics":[{"file":"src/main.grl","line":3,"col":5,"code":"E0005","message":"assignment requires mut"}]}
{"cycle":3,"status":"ok","ms":28,"diagnostics":[]}
```

A build cycle adds `"output":"target/app"`. `status` is `ok` or `error`, `ms` is a number, and
`diagnostics` is always present (empty when the cycle is clean). That is the whole interface an
editor or a language server needs: which cycle, whether it passed, how long it took, and where the
diagnostics are.

The channel behind it is the compiler's `--diagnostics-json FILE`. At the one place a diagnostic is
built (`fail` in `compiler/native.grl`), the compiler appends one JSON object per diagnostic to
`FILE` instead of printing the caret form, and prints nothing; the object carries `file`, `line`,
`col`, `code` (the code `grail explain` knows, or empty), `message`, and `rendered` - the caret form
the compiler would have printed. The re-runs that report the next error of one compile carry the
flag, so one cycle's file holds every diagnostic the cycle had. The driver truncates the file at the
start of a cycle, reads the records back when the cycle ends, deletes it, and both report forms are
built from those fields. No part of the driver parses printed text.

The flag belongs to the compiler; the driver forwards it from `grail check --diagnostics-json FILE`
(and `grail build --diagnostics-json FILE`), which is what an editor calls, and prints nothing of its
own when it is given - the file is the whole report, and the status is the exit code. `rendered`
exists so a driver can show a human what the compiler had to say without a second rendering path in
the driver.

### Locking

No lock is held between cycles, and none is held across a cycle boundary: the watching process takes
nothing, so a `grail build`, a `grail check` or another watching process in the same directory runs
while it waits, and `grail build` beside a watching process is a case in `tools/test-cli.mjs`. The
build cache stages every write and renames it into place, so two builds in one directory produce
either the old or the new entry, never a torn one.

The structured-diagnostics file is named after the moment the cycle started
(`target/watch-<wall-ms>`), so two watching processes never read each other's records, and it is
removed when the cycle ends.

### Exit status, and the signal limit

The exit status of a cycle is the status of the command: 0 when it passed, 1 when it did not, and a
failed cycle keeps the process alive - the next change re-runs it.

A watch process ends when a signal ends it. **It has no SIGINT/SIGTERM handler, so the default
disposition applies: the process dies on the signal and the status the shell sees is 130 (SIGINT) or
143 (SIGTERM), not the last cycle's status.** This is the one requirement of the watch design this
branch does not meet, and the reason is a boundary rather than an omission: catching the signal
needs a runtime seam - a handler that sets a state word, plus a `host::` builtin to read it - in
`compiler/runtime.grl` and in all three platform modules. A new builtin cannot land from this branch,
because the published bootstrap compiler in `compiler/bootstrap/` would not know it, and the compiler
could not be built from its own sources again until a reseed. Until then the last cycle's status is
in the summary line and in `--json`, and the status on termination is the signal's.

### Flags

| flag | meaning |
| --- | --- |
| `--watch` | stay alive and re-run the cycle on change (`build`, `check` only) |
| `--interval MS` | poll period, default 100 |
| `--debounce MS` | quiet period that collapses a burst, default 120 |
| `--json` | one JSON object per line per cycle, and nothing else |

`--watch` is refused by name on `run` and `test`, which have no cycle to repeat, and `--cache` is
refused with `--watch`: a cache hit is a cycle that does not run the compiler, and the point of
watching is that every change is checked.

### The LSP seam

The language server (`tools/lsp/main.grl`) checks the open buffer by running `grail check` on a
scratch file and mapping the printed `file:line:column: message` lines back onto the buffer. With
`--diagnostics-json` the same check produces the position and message as fields, so the server no
longer parses text: it passes the flag, reads the file, and takes `file`, `line`, `col` and
`message` from each record. The record's shape is the one documented above; a server that wants the
detail a human would see can use `rendered`.

### What is not here

- Watch does not make a cycle cheaper: each cycle re-runs the compiler the way a one-shot command
  does. Shortening the cycle is the build cache's axis, not watch mode's.
- mtime is never consulted, so every poll reads every input file. A cheap `stat` in the `host::`
  surface would let a poll skip files whose size and timestamp are unchanged; the hash would still
  decide.
- `--watch` is on `build` and `check` only.
