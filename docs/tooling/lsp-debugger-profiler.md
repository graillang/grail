# LSP, debugger and profiler integration plan

Status: **design only**. Nothing in this document is implemented yet. The build,
test and distribution foundation in [cross-platform-ci.md](cross-platform-ci.md)
defines the artifact and lane contract these tools will ship through.

## What exists today

- `grail check`, `grail build`, `grail run`, `grail fmt` and `grail test` in
  `compiler/cli.grl`; diagnostics already use `file:line:column: message`.
- A token-level formatter (`compiler/fmt.grl`) that is idempotent and
  byte-preserving for compilation.
- Direct assembly emission (`native.grl` -> `machine.grl`) with no source map,
  no DWARF and no symbol table for user functions.
- Distribution packages from `tools/ci.mjs` with `bin/grail`,
  `lib/grail/{runtime.grl,std/}` and `share/doc/grail/`.

The common prerequisite is a machine-readable compiler service: diagnostics,
symbols and source spans must be obtainable without scraping stderr.

## Phase 0: compiler service surface (shared prerequisite)

Add to `compiler/cli.grl` (no change to `compiler/native.grl` language
semantics):

```sh
grail check --json FILE...        # diagnostics as JSON lines/array
grail symbols --json FILE...      # module, type, function, field, span
grail fmt --check --json FILE...  # formatter edits as text edits
```

Each JSON record carries `file`, `range {start,end}` with 1-based
line/column, `severity`, `code`, `message`, plus a content hash so clients can
discard stale results. `--json` writes only JSON to stdout; diagnostics keep
their current text form when the flag is absent.

Exit codes stay compatible: `0` clean, non-zero when diagnostics exist. The CI
driver's `preflight`/`lint` contract is unchanged.

## Phase 1: language server

Ship `grail lsp --stdio` as a thin supervisor, with the protocol implementation
in `tools/lsp.mjs` (Bun, already a build dependency) and the compiler invoked as
`grail check --json` / `grail symbols --json`. A later phase can move the
protocol server into Grail once the compiler exposes an in-process API.

Transport and lifecycle:

- JSON-RPC 2.0 over stdio with `Content-Length` framing.
- `initialize`/`initialized`/`shutdown`/`exit`; advertise only implemented
  capabilities.
- Workspace roots and `grail.pkg` discovery; standard library modules resolved
  through `GRAIL_HOME`/`PREFIX/lib/grail` as `grail check` already does.

Capabilities by milestone:

| Milestone | Capabilities | Data source |
| --- | --- | --- |
| L1 | `textDocument/publishDiagnostics`, `didOpen/didChange/didSave/didClose` | `check --json`, debounced |
| L2 | `hover`, `definition`, `references`, `documentSymbol` | `symbols --json` |
| L3 | `textDocument/formatting`, `rangeFormatting`, `codeAction` | `fmt --check --json` |
| L4 | `completion`, `rename`, `signatureHelp`, semantic tokens | compiler service API |

Implementation rules:

- Keep an in-memory overlay (`uri -> text`) and materialise a temporary
  workspace snapshot per request; never write into the user's tree.
- Debounce `didChange` (150–250 ms), cancel superseded requests, and key caches
  by `(content hash, compiler source hash)`.
- Run one compiler process per snapshot; reuse it only after a stable hash.
- Never block `initialize` on a full workspace check; report diagnostics
  incrementally per open document and then a background workspace pass.

Testing and distribution:

- Golden JSON fixtures for diagnostics/symbols and transcript tests for the
  protocol framing and cancellation.
- Package `tools/lsp.mjs` under `lib/grail/lsp/` and add `grail lsp` to the
  binary; `share/grail/package.json` records its digest.
- CI: Linux x86-64 runs the transcript suite; the matrix's AArch64 and RISC-V64
  lanes run the same fixtures once QEMU is available.

Blockers: `check --json`/`symbols --json` do not exist; the checker does not
retain a queryable symbol table across runs.

## Phase 2: debugger (DAP)

Target: `grail debug` speaks Debug Adapter Protocol over stdio and drives
`gdb` (Linux, RISC-V64 via `gdb-multiarch`), `lldb` (macOS/Linux) or `cdb`
(Windows).

Required compiler work, in order:

1. **Line tables.** Emit `.file`/`.loc` directives alongside instructions so
   clang's assembler produces `.debug_line`. The emitter already tracks source
   offsets for diagnostics; carry the token span into every emitted instruction.
2. **Function symbols.** Emit `.type name,@function`/`.size` and a stable
   unmangled alias (`.globl grail$module$fn`) so breakpoints can resolve.
   Mangled internal names remain for linking.
3. **Variable information.** Emit DWARF `.debug_info` DIEs for parameters and
   locals with location lists; generate location expressions from the existing
   slot assignment in `optimize.grl`. Without this, "step" and "break" work but
   "print variable" does not.
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

Blockers: no source spans in assembly, no DWARF emission, no debug build mode.

## Phase 3: profiler

Two complementary modes, both selected at build time:

- **Sampling** (`grail build --profile=sample`): keep frame pointers and emit
  function symbols; collect with `perf record` (Linux), Instruments (macOS) or
  ETW/WPA (Windows). Provide `tools/profile.mjs` to invoke the platform sampler
  and render a flame graph or pprof profile. No compiler changes beyond
  `-fno-omit-frame-pointer`-style emission and symbol names.
- **Instrumentation** (`grail build --profile=instrument`): insert per-function
  entry/exit counters and cycle reads (`rdtsc`, `CNTVCT_EL0`, `rdcycle`) behind
  a runtime flag, then dump a JSON/pprof profile at exit. This works without an
  external sampler and is the only option on locked-down hosts.

Plan:

1. Add `--profile=sample|instrument|off` to the compiler option parser
   (alongside `--overflow`), with artifact suffix `-profile`.
2. Reuse the runtime allocator/panic counters already maintained by
   `compiler/runtime.grl`; add call counts and inclusive/exclusive cycles per
   function.
3. Emit the Chrome trace JSON and pprof protobuf formats; `tools/profile.mjs`
   converts sampling output to the same shape.
4. CI: a small benchmark suite with generous thresholds (no performance gate
   until variance is measured on the hosted runners); publish profiles as
   artifacts, never as required checks.
5. Package `share/grail/profiler/` with the converter script and document the
   exact commands per OS.

Blockers: no symbol names in binaries, no profiling option, no benchmark
harness. Windows/macOS samplers are untestable until those backends exist.

## Delivery order and CI impact

1. Phase 0 JSON surfaces (compiler-only, no native.grl semantics changes).
2. LSP L1/L2, packaged and tested on Linux x86-64/AArch64.
3. Sampling profiler (symbols + frame pointers).
4. Debugger line tables and D1.
5. LSP L3/L4, DWARF variable info, instrumentation profiler.

Each phase adds a `grail-<tool>` entry to `share/grail/package.json`, a CI
fixture suite, and documentation under `docs/tooling/`. The distribution matrix
and signing hooks already accommodate additional binaries in the same archives.
