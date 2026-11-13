# LSP, debugger and profiler integration plan

Status: **LSP MVP implemented** (JSON-RPC lifecycle, didOpen/didChange and
compiler-sourced diagnostics), **DWARF `.debug_line` + `.debug_info` with type
DIEs implemented for Linux x86-64/AArch64/RISC-V 64, CodeView for Windows
x86-64**, and a **sampling profiler implemented for Linux x86-64**
([profiler.md](profiler.md)). macOS Mach-O DWARF, variable lifetime ranges and
the instrumentation profiler remain design only; debugging a built program is
[debugging.md](debugging.md).
The build, test and distribution foundation in
[cross-platform-ci.md](cross-platform-ci.md) defines the artifact and lane
contract these tools ship through.

## Implemented LSP

The language server is `tools/lsp/main.grl`: a Grail program started by `bun tools/lsp.mjs`,
with JSON-RPC framing, the lifecycle, full-text sync, compiler-sourced diagnostics and
`textDocument/definition` for same-file declarations. Capabilities, the diagnostics mapping,
robustness and the deliberate omissions are documented in [lsp.md](lsp.md); the phase plan
below covers what is still missing.

The server was written after the earlier `tools/lsp.mjs` MVP (JavaScript) and replaces it:
one language server, in the language it serves.

## What exists today

- `grail check`, `grail build`, `grail run`, `grail fmt`, `grail test`,
  `grail debug lines|info` and `grail profile` in `compiler/cli.grl`;
  diagnostics already use `file:line:column: message` on stdout with a non-zero
  exit.
- A token-level formatter (`compiler/fmt.grl`) that is idempotent and
  byte-preserving for compilation.
- Direct assembly emission (`native.grl` -> `machine.grl`) with no source map,
  no DWARF and no symbol table for user functions.
- Distribution packages from `tools/ci.mjs` with `bin/grail`,
  `lib/grail/{runtime.grl,std/}` and `share/doc/grail/`.

A richer machine-readable compiler service is the prerequisite for hover,
symbols, debugger variables and profiling annotations. The LSP MVP deliberately
uses the existing text interface rather than blocking on that work.

## Phase 0: compiler service surface (partially implemented for LSP)

`grail check` already provides the diagnostics the LSP needs. Future work adds:

```sh
grail check --json FILE...        # diagnostics as JSON lines/array
grail symbols --json FILE...      # module, type, function, field, span
grail fmt --check --json FILE...  # formatter edits as text edits
```

Each JSON record would carry `file`, `range {start,end}` with 1-based
line/column, `severity`, `code`, `message`, plus a content hash so clients can
discard stale results. `--json` writes only JSON to stdout; diagnostics keep
their current text form when the flag is absent.

Exit codes stay compatible: `0` clean, non-zero when diagnostics exist. The CI
driver's `preflight`/`lint` contract is unchanged. Until `--json` exists,
`tools/lsp.mjs` parses the documented `file:line:column:` text format.

## Phase 1: language server

The MVP is `tools/lsp.mjs`. A later phase can move the protocol server into
Grail and add the remaining capabilities. A `grail lsp --stdio` subcommand is
future work; today the server is invoked directly.

Transport and lifecycle (implemented):

- JSON-RPC 2.0 over stdio with `Content-Length` framing.
- `initialize`/`initialized`/`shutdown`/`exit`; only implemented capabilities
  are advertised (`textDocumentSync` openClose + full change, UTF-16 positions).
- Standard library modules resolve through `GRAIL_HOME`/`PREFIX/lib/grail` as
  `grail check` already does.

Capabilities by milestone:

| Milestone | Capabilities | Data source |
| --- | --- | --- |
| L1 (**done**) | `publishDiagnostics`, `didOpen/didChange/didClose` | `grail check` text diagnostics |
| L2 | `hover`, `definition`, `references`, `documentSymbol` | `symbols --json` |
| L3 | `textDocument/formatting`, `rangeFormatting`, `codeAction` | `fmt --check --json` |
| L4 | `completion`, `rename`, `signatureHelp`, semantic tokens | compiler service API |

Remaining implementation rules:

- Materialise a temporary workspace snapshot per request; never write into the
  user's tree. The MVP does this for one file.
- Debounce `didChange` (the MVP defaults to 50 ms, configurable with
  `GRAIL_LSP_DEBOUNCE_MS`), cancel superseded requests, and key caches by
  `(content hash, compiler source hash)`.
- Add project/workspace checking and background diagnostics; the MVP checks
  only the open file.
- Package `tools/lsp.mjs` under `lib/grail/lsp/` and add `grail lsp` to the
  binary; `share/grail/package.json` records its digest.
- CI: the tooling job runs the protocol tests; the preflight-gated `lsp` job
  builds the compiler and runs the compiler-backed stdio session.

## Implemented: DWARF line tables and types (Linux x86-64, AArch64, RISC-V 64)

`grail build --debug` and the raw `grail --debug ...` compiler form emit
`.file`/`.loc` directives plus a `.debug_info` compile unit for the three Linux
targets; clang's assembler turns the locations into `.debug_line`. Statement
granularity is line/column accurate, including statements that begin by
pushing a string literal (the compiler re-asserts the last `.loc` after each
`.popsection`).

```sh
grail build --debug
grail debug lines target/hello
grail debug info target/hello
llvm-dwarfdump --debug-line target/hello
llvm-dwarfdump --debug-info target/hello
```

`grail debug lines|info` use `llvm-dwarfdump` and fall back to `readelf`
(`GRAIL_DWARFDUMP`/`GRAIL_READELF` override the tools). The unit is DWARF v4
and names the entry source; each emitted function gets a `DW_TAG_subprogram`
with `DW_AT_name`, `DW_AT_linkage_name`, `DW_AT_low_pc`, `DW_AT_high_pc`,
`DW_AT_decl_file`, `DW_AT_decl_line` and `DW_AT_frame_base`
(`DW_OP_reg6`/rbp on x86-64, `DW_OP_reg29`/x29 on AArch64, `DW_OP_reg8`/s0 on
RISC-V). Parameters and locals are `DW_TAG_formal_parameter`/`DW_TAG_variable`
DIEs with declaration lines, a `DW_AT_type` and a `DW_OP_fbreg` stack
location. Optimisation is skipped in debug builds so a slot stays live for the
whole function: a location is the frame slot, and there are no lifetime ranges
yet, so a variable read after its scope ends shows the slot's last value rather
than nothing.

The types are what a debugger needs to walk a value:

| DIE | what it describes |
|---|---|
| `DW_TAG_base_type` | integers (signed/unsigned, byte size), `f64`, `f32` (as the 8-byte word a slot holds), `bool`, `char` |
| `DW_TAG_pointer_type` | `&T`, `&mut T`, and the handle of every owned value |
| `DW_TAG_structure_type` + `DW_TAG_member` | a record's fields at their offsets (a Grail record is a pointer to its words; an `extern "C"` record is its C layout, inline) |
| `DW_TAG_enumeration_type` + `DW_TAG_enumerator` | an enum's tag word, enumerators named after the variants and valued by the tag the constructor stores |
| `DW_TAG_typedef` | the enum's value type, so a debugger prints `Shape` and `*s` shows `{tag = Square, payload = 7}` |

A sequence (`string`, `u8[]`, `T[]`) is a pointer to the runtime's 24-byte
header `{data, len, cap}`; `data` is a pointer to the first element, not a
`DW_TAG_array_type` with a count, because the length lives in `len` and an
array type would have to state a length the header does not carry. That is the
description Go and Rust emit too, and it gives a debugger the syntactic form it
slices with: `print *values->data@values->len`.

`tools/test-debug-lines.mjs` verifies line rows, subprogram ranges,
parameter/local names and locations, every type DIE above, `llvm-dwarfdump
--verify`, and a real `gdb --batch` session that prints a record, a nested
record, a string, a vector, a C record and an enum tag by name. See
[debugging.md](debugging.md) for the command lines.

### Windows x86-64: CodeView

`--debug --target windows-x86_64` emits the CodeView equivalent: `.cv_loc` line
records (a PDB through `lld-link /DEBUG`), `.debug$T` type records
(`LF_STRUCTURE`, `LF_FIELDLIST`, `LF_MEMBER`, `LF_POINTER`, and the predefined
base-type indices) and a `.debug$S` symbol stream with `S_GPROC32`,
`S_FRAMEPROC` (rbp as the frame register) and one `S_REGREL32` per parameter
and local at `rbp-8*(slot+1)`. `llvm-pdbutil dump --types/--symbols` shows
them; the test asserts the record layouts, the typed locals and the debug PDB's
line rows. CodeView has no record for a Grail enum's tag here, so an enum's word
is the 8-byte unsigned integer it is - labelled as such rather than guessed.

### macOS: not emitted

`--debug` refuses `macos-x86_64`/`macos-aarch64` rather than emitting a
half-supported table. The writer's sections are written in ELF's syntax
(`.section .debug_info,"",@progbits`) and Mach-O names them
`__DWARF,__debug_info` with a different assembler directive; getting from there
to a debugger also needs the `dsymutil` step that collects them into a `.dSYM`.
That is its own piece of work, and until it is done the refusal is the honest
answer. Windows AArch64 is refused for the same reason (its CodeView layout
differs from x86-64's).

Not implemented yet: variable lifetime ranges, inlined frames, expression-level
spans, register-allocated variables (debug builds keep everything in a frame
slot), macOS Mach-O DWARF, and a Debug Adapter Protocol server.

## Phase 2: debugger (DAP)

Target: `grail debug` speaks Debug Adapter Protocol over stdio and drives
`gdb` (Linux, RISC-V64 via `gdb-multiarch`), `lldb` (macOS/Linux) or `cdb`
(Windows).

Required compiler work, in order:

1. **Line tables (done for Linux x86-64).** `.file`/`.loc` directives now feed
   clang's assembler; Windows/macOS and expression-level spans remain.
2. **Function symbols.** Emit `.type name,@function`/`.size` and a stable
   unmangled alias (`.globl grail$module$fn`) so breakpoints can resolve.
   Mangled internal names remain for linking.
3. **Variable information (basic DIEs done).** Parameters and locals now have
   `DW_OP_fbreg` stack locations from their slots; location lists for values
   that move between registers and type DIEs remain.
4. **Debug build mode.** `grail build --debug` disables inlining/slot
   forwarding where it would hide user frames, and writes an unstripped
   executable plus a `.grail.json` source map.

Adapter scope:

| Milestone | Features | Blocker |
| --- | --- | --- |
| D1 | launch/attach, breakpoints by file:line, continue, pause, step over/into/out, threads | line tables |
| D2 | stack traces with source locations, scopes, variables, evaluate | DWARF DIEs |
| D3 | conditional breakpoints, watch expressions, reverse debugging | backend support |

Platform matrix: Linux x86-64/AArch64 (gdb), Linux RISC-V64 (gdb-multiarch),
Windows x86-64/AArch64 (cdb or lldb), macOS AArch64/x86-64 (lldb). The adapter
is shared; only the backend command and MI/JSON dialect differ.

Testing: fixture programs with known line/variable expectations, automated
breakpoint/step transcripts per OS in CI. Distribution adds `grail-debug` to the
package only on platforms with an implemented backend.

Remaining blockers: no type DIEs or location lists, no debugger adapter/attach,
and no Windows/macOS debug sections.

## Phase 3: profiler (sampling mode done for Linux x86-64)

The sampling mode changed shape from the original plan. Instead of driving
`perf record` and converting its output, the sampler lives in the program's own
runtime: `grail profile` writes a rendezvous file, the runtime arms an
`ITIMER_PROF`/`SIGPROF` handler that records interrupted instruction pointers
into a fixed buffer without allocating or locking, and the command symbolises
those addresses from the program's ELF `.symtab`. There is no external sampler,
no `perf`, and no frame-pointer change. See [profiler.md](profiler.md) for the
command, the columns and the limitations (leaf-only attribution, inlining, no
line granularity, CPU-time sampling).

Still future work:

- **Instrumentation** (`grail build --profile=instrument`): insert per-function
  entry/exit counters and cycle reads (`rdtsc`, `CNTVCT_EL0`, `rdcycle`) behind a
  runtime flag, then dump a JSON/pprof profile at exit. This is the only option
  on locked-down hosts and gives call counts and inclusive/exclusive cycles.
- Inclusive time and call graphs: the sampling handler currently records a leaf
  only. A frame-pointer or `.eh_frame` unwinder would turn each sample into a
  stack.
- Line and column attribution: `--debug` builds already carry `.debug_line`, so
  the report can be extended to rows of `file:line` the way `grail debug lines`
  reads them today.
- Other targets: AArch64 and RISC-V need their own `ucontext_t` offsets and
  syscall numbers; Windows and macOS need a different sampler.
- Chrome trace JSON / pprof output, flame graphs, and packaging a converter
  under `share/grail/profiler/`.
- CI: a benchmark suite with generous thresholds (no performance gate until
  variance is measured on hosted runners); publish profiles as artifacts, never
  as required checks.

## Delivery order and CI impact

1. Phase 0 JSON diagnostics/symbols (text diagnostics already back L1).
2. LSP L2: hover, definition, references and document symbols.
3. Sampling profiler (done: in-runtime SIGPROF sampler, Linux x86-64).
4. Debugger D1 attach/breakpoints on the now-emitted Linux x86-64 line table.
5. LSP L3/L4, DWARF variable info, instrumentation profiler.

Each phase adds a `grail-<tool>` entry to `share/grail/package.json`, a CI
fixture suite, and documentation under `docs/tooling/`. The distribution matrix
and signing hooks already accommodate additional binaries in the same archives.
