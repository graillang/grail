# Language readiness before graphics and porting

Audit date: 2026-11-09, against `main` with the nested-record, float-record and CodeView-locals work.
Priority is Windows first, then Linux, then macOS. Evidence is the compiler, the test suites and
the design notes named below; `implementation-status.md` is current except where noted.

## A. Core work - status (2026-11-09)

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| A1 | FFI floats | **Done** for direct and `cfn` calls and for callbacks (parameters and results) on SysV, Win64, AAPCS64, RV64 LP64D | `tests/ffi/call_abi.grl`, `callback_floats.grl` on 3 Linux targets + Windows x64 (Wine) |
| A2 | FFI narrow integers | **Done** for calls and callbacks (callee-side extension), and narrow C-record field stores write only their width | same; native case `ffi-c-record-narrow-assign` |
| A3 | C records by value | **Done except by-value arguments**: results in registers or a hidden pointer on every ABI, including float-field results (SysV eightbyte classes, AAPCS64 HFAs, RV64 flattening); `f32`/`f64` fields; nested records embedded by value. Remaining: records passed *by value* as arguments (spelling `byval` decided, B7; implementation after B1) | `call_records.grl`, `float_records.grl`, `float_record_results.grl`, `nested_records.grl` |
| A4 | Stack arguments / variadic | **Done**: any number of arguments; variadic C calls on SysV, Win64, AAPCS64 (Linux and Apple's stack convention), RV64 | `call_variadic.grl` on 3 Linux targets + Windows x64; `test-macos` (static) |
| A5 | Windows FFI / COM | **Done**: `extern "C"` calls and callbacks (Win64 thunk); COM methods of any arity and with floats through a typed `cfn` vtable slot | Windows suite: 33 checks, 19 under Wine; `call_com_slot.grl` |
| A6 | Dynamic loading | **Done**: Windows x64 (Wine), Linux x86-64/AArch64/RISC-V (host-TLS bridge; executed under qemu with glibc sysroots), macOS linked for both targets | `dlopen.grl`, `ffi-dynamic-loading`, `test-macos` |
| A7 | Stdlib on Windows | **Done** for files, sockets, processes/threads, output capture | `tools/test-ffi-runtime-windows.mjs`, 4 tests under Wine |
| A8 | Typed OS errors on Windows | **Done** for the host layer (`GetLastError` -> errno) | `io-error-mapping` Wine case |
| A9 | Process stdio capture | **Done** (`pipe`, `spawn_with`, `read_to_end`) | Linux + Wine |
| A10 | Windows ARM64 threads | **Done statically** (bridge emitted and published); no ARM64 Windows runner | ARM64 static checks |
| A11 | Mutable/borrowed captures, borrowed closure params | **Borrowed captures done; `FnMut` deferred** (B6) | Closures capture references and views and cannot escape their borrow (native cases `closure-captures-reference`, `closure-borrowed-capture-escape-rejected`, `closure-capture-mutation-rejected`); mutating captures, mutable/borrowed closure params and generic iterator adapters wait on the deferred `FnMut` work (B6). `docs/design/closures.md` |
| A12 | Iteration | **Partial**: `vecs::fold` (any type), `any/all/count/position_num`; generic predicates need A11 | native case `vecs-fold-and-predicates` |
| A13 | Debug info | **Done for line tables and typed locals**: DWARF lines + base types on Linux x86-64, AArch64 and RISC-V 64 (`--verify` clean; gdb prints typed locals); CodeView on Windows x64 with line tables and S_GPROC32/S_REGREL32 symbols (typed, rbp-relative parameters and locals) in the PDB. Remaining: record/string member layout (owned values show as their 8-byte handle) | `tools/test-debug-lines.mjs` |

Remaining implementable core gap: record and string member layout in the debug info. Everything
else in A1-A13 is either done or waits on a decided item in section B (by-value record arguments get
B7's `byval` spelling; mutating closure captures wait on B6's deferred `FnMut`).

## B. Owner decisions (settled 2026-11-10)

All seven are decided, delegated to the implementation by the project owner and recorded in
[decisions-b2-b6.md](decisions-b2-b6.md) with the decision, the alternatives rejected, the
consequence if wrong, and where code, tests or documents enforce it. One line each, so the question
is not asked again:

| # | Decision | Status | One-line summary |
| --- | --- | --- | --- |
| B1 | Separate compilation and checked module interfaces | **Accepted, implementation starting** | Per-module objects plus a checked text interface with a hash-verified dependency list; the plan of record is [separate-compilation.md](separate-compilation.md). See [B1](decisions-b2-b6.md#b1-separate-compilation-accepted). |
| B2 | Authority / capability model for OS access | **Implemented** (`lib/authority.grl`, `--deny-ambient-host`) | OS access is an owned grant with lexical, component-wise containment, and denial is distinct from an OS error. Ambient `host::` remains the default and is a recorded deviation until untrusted or plugin code arrives. See [authority.md](../authority.md) and [B2](decisions-b2-b6.md#b2-ambient-host-authority-a-recorded-deviation). |
| B3 | Suspension and blocking contract for foreign calls | **Implemented: a foreign call blocks the executing thread** | No green-task offload, suspension effect or isolation is promised for `extern "C"` calls in v1, and FFI stays main-thread-only because the host TLS base is process-wide. See [B3](decisions-b2-b6.md#b3-foreign-calls-block-the-executing-thread). |
| B4 | Windows I/O readiness model | **Implemented: thread-per-task on Windows, IOCP deferred** | Synchronous `ReadFile`/`WriteFile` on Windows; IOCP is a named future work item with a sketch, and green tasks on Windows abort at scheduler start today. See [B4](decisions-b2-b6.md#b4-windows-thread-per-blocking-call-iocp-deferred). |
| B5 | Abort / unwind policy | **Decided: abort never unwinds** | `rt_abort` raises `SIGABRT` (Windows: `ExitProcess(134)`) and runs no cleanup at all - no `defer`, no drops, no message; nothing may unwind across the C boundary, which the compiler does not enforce. See [B5](decisions-b2-b6.md#b5-abort-never-unwinds). |
| B6 | Closure capture model | **Decided: references and views are captured, `FnMut` deferred** | Closures capture direct references/views and cannot outlive the borrow (rejected: `returned borrow escapes its declared input lifetime`); mutating a capture is rejected today, and the six rules for `FnMut` are fixed in advance. See [B6](decisions-b2-b6.md#b6-references-captured-fnmut-deferred). |
| B7 | Records passed by value to C | **Accepted, spelling `byval`**, implementation after B1 | `v: byval R` passes the whole record; bare `R` stays the C `R *`, and the per-ABI result classifier is reused for arguments. See [B7](decisions-b2-b6.md#b7-byval-record-parameters-accepted). |

## C. Libraries (not language core; needed by the ports, scheduled with them)

JSON with exact numbers, TOML, regex/glob, base64/uuid, hashes and crypto, TLS (system stack via
FFI recommended), HTTP, compression and image codecs, arenas and channels.

### C1. SHA-256 and JSON (done)

`lib/sha256.grl` is FIPS 180-4 SHA-256 over byte views: `sha256::new()`, `s.update(&bytes)` (any
split gives the same digest), `s.finish()` (32 bytes), the one-shot `sha256::digest(&bytes)`, and
`sha256::hex(&bytes)`/`sha256::hex_digest(&bytes)` for lowercase hex. It replaces Abundance's
PicoSHA2 content identities. The native case `sha256-nist-sha256sum-and-split-updates` checks the
NIST vectors (empty, `abc`, the 448- and 896-bit messages, one million `a`), 17 generated inputs
against `sha256sum` (1-65537 bytes, around the 55/56/63/64/65-byte padding boundaries) and every
two-part split and byte-at-a-time update of lengths 0-200.

`lib/json.grl` is a strict RFC 8259 parser and serializer for the bounded config adapter that
replaces nlohmann/json. `json::parse(&text)` (or `parse_with(&text, options)`) returns
`json::Value |? json::Error`; a `Value` is `Null`, `Bool`, `Int(i64)`, `Float(f64)`,
`Str(string)`, `Array(Value[])` or `Object(Member[])` with members in document order.

- Numbers: integer syntax (no fraction or exponent) that fits i64 is `Int`, exactly; everything
  else is the correctly rounded `Float` (round half to even, any number of digits). `-0` is
  `Float(-0.0)`. A magnitude that rounds past the f64 range is `NumberOutOfRange`; tiny values
  underflow to zero or a subnormal.
- Strings must be valid UTF-8 and may not contain raw control characters; escapes, including
  `\uXXXX` surrogate pairs, decode to UTF-8, and a lone surrogate is `LoneSurrogate`.
- Duplicate keys are `DuplicateKey` by default; `options.allow_duplicate_keys = true` keeps the
  first position with the last value. Objects of more than 32 members switch to a hash index.
- `options.max_depth` (default 128) bounds array/object nesting, so recursion depth is bounded.
- No extensions: comments, trailing commas, a BOM, `NaN`/`Infinity`, single quotes and
  whitespace other than space/tab/LF/CR are errors. Each error has a kind and a byte offset
  (`e.show()` is `json: <reason> at byte N`), and malformed input never aborts.
- `json::to_text(&v)` is compact and `json::to_pretty(&v)` indents by two spaces. Floats are
  written with the shortest digits that read back exactly and always have a `.` or exponent,
  so `parse(to_text(v))` equals `v` (`json::equal` compares floats by bits). Non-finite floats,
  which `parse` never produces, are written as `null`. Accessors: `get(key)`, `at(i)`, `len()`,
  `is_null()`, `as_bool/as_i64/as_f64/as_str/as_array/as_object` (optional results).

The native case `json-suite-floats-errors-and-round-trips` runs 99 must-accept and 212
must-reject JSONTestSuite-style inputs (written inline by `tests/lib/gen_json_cases.py`, which
also emits 612 decimal strings with CPython-computed f64 bit patterns: exact halfway points, long
mantissas, subnormals and range edges), exact outputs, error offsets, depth and duplicate-key
options, accessors and 2000 float plus i64 text round trips. Implementation-defined
JSONTestSuite cases are decided strictly: lone surrogates, invalid UTF-8, a BOM and numbers
beyond f64 are rejected; very long or huge-exponent numbers that are in range are accepted.

Both modules are outside the compiler's built-in stdlib list (`stdlib_module` in
`compiler/native.grl`), so they compile in the program's literal mode; every integer binding is
annotated, and the native cases run both test programs with `--default-u64` and with default i64
literals (the `grail build`/`grail test` mode).

Costs to know: the CLI compiles every top-level `lib/*.grl` into every program and there is no
dead-code elimination yet, so `json.grl` adds about 0.7 s and 0.7 MB of assembly to each
`grail build`. Writing a float goes through the runtime's positional `{}` formatting (tens of
microseconds for ordinary magnitudes, more for very large or small exponents).

## Order

A1-A5 (one compiler batch), A6, A7-A9, A10, A11-A12, A13; one bootstrap refresh per compiler
batch. The B-items are decided (section B above and
[decisions-b2-b6.md](decisions-b2-b6.md)): B1 and B7 are being implemented, B2-B6 are settled and
binding, and each names the condition that would reopen it. Graphics work (D3D12 pipelines,
presentation, Metal) waits for the checkpoint after section A.
