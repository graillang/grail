# Debugging a Grail program

Every development build (`grail build`, optimised) carries line tables and function ranges - DWARF
on Linux x86-64, AArch64 and RISC-V 64, CodeView in a PDB on Windows x86-64 - so a debugger can
break on a source line and step by line; code the optimiser inlined is attributed to the calling
statement, and `--no-debug-info` leaves the tables out. `grail build --debug` turns the optimiser
off and describes parameters and locals with their types too, so an ordinary debugger can also walk
a record, read a string and print an enum tag by name. There is no Debug Adapter Protocol server yet
([lsp-debugger-profiler.md](lsp-debugger-profiler.md) says what is missing); this page is the tested
way to debug a binary today.

## The shape of a Grail value in a debugger

Grail values are words, and the debug info describes them as they are - it never reinterprets a slot
as something it is not:

| Grail | in the debugger | what to type |
|---|---|---|
| `u64`, `i64`, `f64`, `bool`, `char` | a scalar in a frame slot | `print total` |
| a record `Point{x, y}` | a *pointer* to its 8-byte fields | `print *p`, `print p->x` |
| an enum `Shape` | a *pointer* to `{tag, payload}`; the tag's type is an enumeration | `print *s` → `{tag = Square, payload = 7}` |
| `string`, `u8[]`, `T[]` | a *pointer* to `{data, len, cap}` | `print *values`, `print *values->data@values->len` |
| `&T`, `&mut T` | a pointer | `print *r` |
| an `extern "C"` record | its C layout, inline | `print *pt` |

A variable's location is its frame slot (`DW_OP_fbreg`), so it is valid for the whole function: a
debug build does not reuse slots, and there are no lifetime ranges yet, so a variable read after its
scope ends shows the slot's last value instead of being reported as uninitialised.

## gdb (Linux x86-64)

```sh
grail build --debug hello.grl -o target/hello
gdb -q target/hello
(gdb) break hello.grl:7            # by source line: the line table is exact
(gdb) run
(gdb) info locals                  # every parameter and local, typed
(gdb) print *p                     # the record a handle points at
(gdb) print p->x
(gdb) print *values->data@values->len
(gdb) print *s                     # {tag = Square, payload = 7}
(gdb) next / step / finish
```

Non-interactively, which is also how `tools/test-debug-lines.mjs` checks it:

```sh
gdb -q -batch -ex 'set debuginfod enabled off' -ex 'break hello.grl:7' -ex run \
    -ex 'print *p' -ex 'print p->x' -ex 'print *values->data@values->len' target/hello
```

`set debuginfod enabled off` keeps gdb from asking about debuginfod for a local binary. On a
cross-built binary (AArch64 or RISC-V 64) use `gdb-multiarch`, or `set architecture` plus
`qemu-aarch64-static -g 1234 ./hello` and `target remote :1234`.

## lldb (works for the DWARF; not verified on macOS, where there is no DWARF yet)

```sh
lldb target/hello
(lldb) breakpoint set --file hello.grl --line 7
(lldb) run
(lldb) frame variable            # parameters and locals
(lldb) print *p
(lldb) print *values->data@values->len
```

lldb reads the same DWARF, so `frame variable` on a Grail frame shows the same typed values gdb
does. It is not part of the test suite: the suite's debugger check is `gdb --batch` on the host, so
lldb's support here is "should work, verified by hand" rather than "pinned".

## What is not there yet

- **macOS**: `--debug` refuses `macos-x86_64`/`macos-aarch64` (Mach-O names its debug sections
  `__DWARF,*` and needs the `dsymutil` step, neither of which is written yet).
- **Windows**: CodeView type records, function symbols and RBP-relative locals are emitted and land
  in a PDB via `lld-link /DEBUG`, but talking to a Windows debugger (cdb/WinDbg) is not documented
  or tested here.
- **No lifetime ranges**, no inlined frames, no expression-level spans: a variable is in its slot for
  the whole function.
- **No DAP server yet**: `tools/dap.mjs` exists as a WIP adapter over gdb's MI and is not
  shippable - `initialize`, `setBreakpoints`, `launch`, verified breakpoints and `stopped` work
  against a real gdb, but the `stackTrace`/`scopes`/`variables` leg still hangs in its end-to-end
  test, so this round's deliverable is the tested gdb/lldb recipe above, not a debug adapter.
  `grail debug lines|info` prints what the compiler emitted, which is the supported way to check the
  tables.
