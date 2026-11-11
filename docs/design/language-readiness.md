# Language readiness before graphics and porting

Audit date: 2026-11-09, against `main` with the nested-record, float-record and CodeView-locals work.
Updated 2026-11-10: B1 stage 1, B2, B6 (FnMut) and B7 (`byval`) landed, so the rows below report what
the compiler does instead of what was decided for it.
Priority is Windows first, then Linux, then macOS. Evidence is the compiler, the test suites and
the design notes named below; `implementation-status.md` is current except where noted.

## A. Core work - status (2026-11-09)

| # | Item | Status | Evidence |
| --- | --- | --- | --- |
| A1 | FFI floats | **Done** for direct and `cfn` calls and for callbacks (parameters and results) on SysV, Win64, AAPCS64, RV64 LP64D | `tests/ffi/call_abi.grl`, `callback_floats.grl` on 3 Linux targets + Windows x64 (Wine) |
| A2 | FFI narrow integers | **Done** for calls and callbacks (callee-side extension), and narrow C-record field stores write only their width | same; native case `ffi-c-record-narrow-assign` |
| A3 | C records by value | **Done**: results in registers or a hidden pointer on every ABI, including float-field results (SysV eightbyte classes, AAPCS64 HFAs, RV64 flattening); `f32`/`f64` fields; nested records embedded by value; arguments passed by value with `v: byval R` on SysV x86-64, AAPCS64 and RV64, from one classification shared with results. Windows x86-64 and ARM64 refuse the marker rather than guess MSVC's struct rules | `call_records.grl`, `float_records.grl`, `float_record_results.grl`, `nested_records.grl`, `byval_records.grl` |
| A4 | Stack arguments / variadic | **Done**: any number of arguments; variadic C calls on SysV, Win64, AAPCS64 (Linux and Apple's stack convention), RV64 | `call_variadic.grl` on 3 Linux targets + Windows x64; `test-macos` (static) |
| A5 | Windows FFI / COM | **Done**: `extern "C"` calls and callbacks (Win64 thunk); COM methods of any arity and with floats through a typed `cfn` vtable slot | Windows suite: 33 checks, 19 under Wine; `call_com_slot.grl` |
| A6 | Dynamic loading | **Done**: Windows x64 (Wine), Linux x86-64/AArch64/RISC-V (host-TLS bridge; executed under qemu with glibc sysroots), macOS linked for both targets | `dlopen.grl`, `ffi-dynamic-loading`, `test-macos` |
| A7 | Stdlib on Windows | **Done** for files, sockets, processes/threads, output capture | `tools/test-ffi-runtime-windows.mjs`, 4 tests under Wine |
| A8 | Typed OS errors on Windows | **Done** for the host layer (`GetLastError` -> errno) | `io-error-mapping` Wine case |
| A9 | Process stdio capture | **Done** (`pipe`, `spawn_with`, `read_to_end`) | Linux + Wine |
| A10 | Windows ARM64 threads | **Done statically** (bridge emitted and published); no ARM64 Windows runner | ARM64 static checks |
| A11 | Mutable/borrowed captures, borrowed closure params | **Done**: borrowed captures, mutable captures (`FnMut`) and exclusive calls | Closures capture references and views and cannot escape their borrow (native cases `closure-captures-reference`, `closure-borrowed-capture-escape-rejected`); a closure that writes a capture is `FnMut` and calling it takes exclusive access (B6: `closure-fnmut-counter`, `closure-fnmut-second-call-rejected`, `closure-fnmut-not-fn-rejected`). A by-value `FnMut` parameter cannot be called (parameters are not mutable storage); adapters take `&mut FnMut(...)`. `docs/design/closures.md` |
| A12 | Iteration | **Done**: counted and range loops, `for k, v in &map` / `&mut map`, consuming loops over owned vectors, and an iterator protocol: any record with an inherent `fn next(self: &mut Self) -> T?` is iterable by `for x in it` (takes the iterator) or `for x in &mut it` (lends it); an iterator holding `&a T[]` keeps that loan for the loop. `lib/iter.grl` adds lazy adapters over the closure-backed `Iter<T>`: `upto`, `of`, `map`, `filter`, `take`, `enumerate`, `zip`, `collect`. Every sequential stdlib callback takes `FnMut`; the `pool` callbacks that reach a worker stay `Fn` on purpose. Known limits: an iterator holding a reference cannot be lent to a second loop after a first (a pre-existing checker imprecision that `while let` shares), and a closure cannot hand out references into storage it captures, so adapters carry owned items. | Book chapter *Iteration*; cases `iterator-protocol-*`, `iter-adapters-lazy`. |
| A13 | Debug info | **Done**: DWARF lines + base types on Linux x86-64, AArch64 and RISC-V 64 (`--verify` clean; gdb prints typed locals); CodeView on Windows x64 with line tables and S_GPROC32/S_REGREL32 symbols (typed, rbp-relative parameters and locals) in the PDB. DWARF also describes members: records, strings, vectors, views, references and C records show their fields in gdb (`tests/debug_members.grl`). CodeView on Windows carries the same member layout as LF_STRUCTURE/LF_FIELDLIST/LF_MEMBER/LF_POINTER records in the PDB | `tools/test-debug-lines.mjs` |

Every
A-row is done or explicitly partial (A12); nothing in A waits on a B decision any more. B2, B6 and B7
are implemented, and B1 stages 1-4 have landed (per-module emission, checked interfaces, generics
across modules, the build cache). What remains of B1 is one compiler invocation per module, named in
its own section.

## B. Owner decisions (settled 2026-11-10)

All seven are decided, delegated to the implementation by the project owner and recorded in
[decisions-b2-b6.md](decisions-b2-b6.md) with the decision, the alternatives rejected, the
consequence if wrong, and where code, tests or documents enforce it. One line each, so the question
is not asked again:

| # | Decision | Status | One-line summary |
| --- | --- | --- | --- |
| B1 | Separate compilation and checked module interfaces | **Stage 1 implemented** (`grail build --split`, Linux x86-64) | Emission is cut at module boundaries, so each module gets its own assembly file and object and the link happens once: assemble time −38 % and total ~17.3 s → ~16.8 s on the compiler, with identical code. The checked text interface with a hash-verified dependency list is still the plan of record ([separate-compilation.md](separate-compilation.md)). See [B1](decisions-b2-b6.md#b1-separate-compilation-accepted). |
| B2 | Authority / capability model for OS access | **Implemented** (`lib/authority.grl`, `--deny-ambient-host`) | OS access is an owned grant with lexical, component-wise containment, and denial is distinct from an OS error. Ambient `host::` remains the default and is a recorded deviation until untrusted or plugin code arrives. See [authority.md](../authority.md) and [B2](decisions-b2-b6.md#b2-ambient-host-authority-a-recorded-deviation). |
| B3 | Suspension and blocking contract for foreign calls | **Implemented: a foreign call blocks the executing thread** | No green-task offload, suspension effect or isolation is promised for `extern "C"` calls in v1, and FFI stays main-thread-only because the host TLS base is process-wide. See [B3](decisions-b2-b6.md#b3-foreign-calls-block-the-executing-thread). |
| B4 | Windows I/O readiness model | **Implemented: green tasks on Windows (fibers on one scheduler thread), thread-per-task as opt-in, IOCP deferred** | Synchronous `ReadFile`/`WriteFile` and no epoll/eventfd/timerfd, so a blocking host operation runs on a helper thread while the task parks; task semantics now match Linux, and `GRAIL_TASKS=thread` selects the old thread-per-task scheduler. IOCP is a named future work item with a sketch. See [B4](decisions-b2-b6.md#b4-windows-runs-the-same-green-scheduler-thread-per-task-is-opt-in). |
| B5 | Abort / unwind policy | **Decided: abort never unwinds** | `rt_abort` raises `SIGABRT` (Windows: `ExitProcess(134)`) and runs no cleanup at all - no `defer`, no drops, no message; nothing may unwind across the C boundary, which the compiler does not enforce. See [B5](decisions-b2-b6.md#b5-abort-never-unwinds). |
| B6 | Closure capture model | **Implemented, `FnMut` included** | Closures capture direct references/views and cannot outlive the borrow (rejected: `returned borrow escapes its declared input lifetime`); a closure that writes a capture is `FnMut`, its binding must be mutable, and a call takes the closure exclusively. A `FnMut` where `Fn` is required is refused. See [B6](decisions-b2-b6.md#b6-references-captured-fnmut-implemented). |
| B7 | Records passed by value to C | **Implemented** on every ABI, Win64 and Windows ARM64 included | `v: byval R` passes the whole record; bare `R` stays the C `R *`, and the per-ABI result classifier is reused for arguments. See [B7](decisions-b2-b6.md#b7-byval-record-parameters-accepted). |

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
[decisions-b2-b6.md](decisions-b2-b6.md)): B2, B6 and B7 are implemented, B1's stage 1 has landed and
its checked interface artifact is the next increment, B3-B5 describe behaviour the code already has,
and each item names the condition that would reopen it. Graphics work (D3D12 pipelines,
presentation, Metal) waits for the checkpoint after section A.
