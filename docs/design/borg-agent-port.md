# Porting Borg Agent to Grail

Status: inventory and staged port plan. **Not an approved plan.** Recommendations below are
proposals for discussion, not decisions, and nothing here has been implemented.

Evidence base: `/home/shulgin/agent` inspected read-only at `101cab70` (Borg Agent 0.20.9);
this repository at `329ae0b` on `feature/borg`. No compiler or library source was changed for
this document. Counts come from `rg`/`wc` over `crates/*/src/**/*.rs` and `compiler/*.grl` +
`lib/*.grl` on the date above, and include inline `#[cfg(test)]` code.

## 0. Summary

Borg Agent is a 13-crate, ~363,000-line asynchronous Rust host: one detached writer process per
session, a PostgreSQL journal as the only durable truth, and clients that attach over a Unix
socket or an authenticated relay. Grail is a 24,843-line self-hosting compiler with a 740-line
standard library, three **Linux** CPU targets, a raw-syscall runtime, and — by its own status
table — no user FFI, no separate compilation, and no macOS or Windows target.

The gap is therefore not "translate the code". It is: Grail is missing the OS seam, the FFI
escape hatch, the library/interface layer, and roughly a dozen libraries that Borg treats as
substrate (TLS, HTTP, JSON, TOML, regex, a database driver). What *can* move first is exactly
the part of Borg that has none of those: the protocol data model and its projections.

The single most valuable structural fact for the plan is that **Borg already isolates most
platform-specific work into separate processes** — a headless Wayland compositor
(`borg-display`), a `swiftc`-compiled macOS accessibility helper, a PowerShell UI Automation
helper, and the managed PostgreSQL cluster driven through `initdb`/`pg_ctl`. A Grail host can
keep invoking those programs instead of reimplementing them, which removes a large share of the
FFI surface from the critical path (§11, §13).

## 1. Current architecture

Borg is a **local-first Rust agent host**. One *session actor* owns execution, PostgreSQL owns
durable truth, and every frontend is a client. `docs/architecture.md` in the Borg repo is the
authoritative map; the points that matter for a port:

- A per-session **detached host process** holds an exclusive writer lease and serves a local
  control endpoint.
- All state transitions are journaled as `SessionEvent`s; resume/fork/retry/search/context are
  projections of that journal.
- Two turn routes exist: Borg's own native model-tool loop, and a "compatibility" route that
  delegates the inner loop to an upstream CLI (OpenCode non-Go, Grok Build, Muse Code). Claude,
  Codex and the other routes use the native loop.
- Permissions are **gates, not a sandbox** (trusted-user authority).

### Crate map

| Crate | Rust lines in `src/` | Role | OS surface |
| --- | ---: | --- | --- |
| `borg-agent-runtime` | 183,890 | Session actor, native harness, tools, journal, local control, LSP, MCP, computer use, subagents | Heavy: sockets, signals, `/proc`, `flock`, `inotify`, `setsid`, `killpg`, `prctl` |
| `borg-tui` | 57,482 | Terminal client | TTY, crossterm, clipboard |
| `borg-cli` | 36,568 | Composition, config, login, detached host launch, updater, remote commands, lanes | `libc`, `libloading`, sleep inhibitor, signals |
| `borg-provider` | 29,892 | Provider auth/transport/catalogs, subprocess adapters | Sockets, process groups, credentials |
| `borg-remote` | 18,580 | Enrollment, host supervision, relay, TLS server | axum + rustls + WS |
| `borg-lanes` | 11,618 | Lane/service supervision, workspace leases | `unix` sockets, `flock`, `/proc`, `libc` |
| `borg-view` | 10,923 | Reference projection of events → rows | **None** (pure types) |
| `borg-ui` | 5,004 | Shared presentation, preferences | `dirs` only |
| `borg-gui` | 3,084 | Experimental GPUI shell | Window system |
| `borg-dictation` | 1,875 | Local transcription runtime | Process spawn, archives |
| `borg-display` | 1,812 | Headless Wayland compositor (separate binary) | GPU, dmabuf, Wayland |
| `borg-search` | 1,674 | Web search adapters | HTTPS only |
| `borg-core` | 889 | Wire model, usage contract, compaction | **None** |

Totals: 363,291 lines of Rust in `src/` across 13 crates (371,992 including crate-level
`tests/` and examples); **68 source files** contain
`cfg(unix)`/`cfg(windows)`/`cfg(target_os = …)`; 109 distinct `libc` symbols are called; 175
distinct `BORG_*` environment variables are read.

Only four source files are factored by platform at all, and all of them are desktop adapters:
`computer_use/linux.rs`, `computer_use/linux/windows.rs`, `computer_use/macos.swift` and
`computer_use/windows.ps1`. Every other platform difference is an inline `cfg` branch inside
shared modules — so there is no per-OS backend layer to lift, in Borg or for a port.

## 2. Dependencies

Load-bearing third-party crates and what each one actually buys:

| Dependency | Used for | Porting consequence |
| --- | --- | --- |
| `tokio` (`full`) | Everywhere; the whole host is async | Grail has colourless green tasks + a Linux epoll reactor, no kqueue/IOCP, no suspension-effect contract |
| `serde` / `serde_json` (`arbitrary_precision`) | Every durable event, control frame, config | Needs an exact-decimal-preserving JSON codec (Grail has none) |
| `sqlx` (`postgres`, pinned fork) + `rustls` | Journal, leases, search, relay cursors | A full PostgreSQL wire client, SCRAM auth and TLS are on the path |
| `reqwest` (`rustls`, `multipart`, `stream`, `json`) | Provider APIs, search, relay uploads | Needs TLS + HTTP/1.1 + SSE/WS streaming |
| `axum` + `axum-server` (`tls-rustls`) + `tokio-tungstenite` | Relay server/client | Needs a TLS **server**, not just a client |
| `ts-rs` | Exports 125 wire types to TypeScript | A second frozen contract that a port must match |
| `blu-lang` | Embedded Blu guest interpreter for extensions/workflows | A foreign language runtime inside the host |
| `libloading` | In-process native extensions (C ABI) | Needs `dlopen`/`LoadLibrary` or an out-of-process substitute |
| `ed25519-dalek`, `hmac`, `aes-gcm`, `sha2`, `getrandom` | Device proofs, signatures, credential storage | Pure crypto, but substantial to reimplement |
| `image` (png/jpeg/gif/webp), `zstd`, `zip` | Attachments, screenshots, packaging | Codec libraries: FFI or reimplementation |
| `ratatui`, `crossterm`, `arboard`, `termwiz` (opt) | Terminal UI, clipboard, terminal protocol | TTY, ANSI, OSC 52, wayland-data-control |
| `gpui` | Experimental native GUI shell | Window system |
| `ignore`, `grep-*`, `regex`, `syntect` | File walking, search, permission matching, highlighting | Grail stdlib has no regex or glob |
| `chrono`, `chrono-tz` | Timestamps, tz-aware display | Needs RFC 3339 + tz data |
| `dirs` | Config/home discovery | Needs per-OS known-folder lookup |

Only `borg-core` depends on nothing but `serde` and `serde_json`. Everything else touches the
network, the filesystem, processes, or a window system.

## 3. Operating systems and services used

| Mechanism | Borg use (evidence) | Linux API | macOS equivalent | Windows equivalent |
| --- | --- | --- | --- | --- |
| Unix-domain sockets | Local session control, LSP broker, lane services, private-display control | `AF_UNIX` (`UnixListener`/`UnixStream`) | Same (`LOCAL_PEERCRED` instead of `SO_PEERCRED`) | **Not implemented in Borg** |
| Peer credentials | Verify the connecting user/service (`computer_use/linux/windows.rs:114`) | `SO_PEERCRED`, `ucred` | `LOCAL_PEERCRED` | — |
| Process groups, sessions | Kill whole trees; every provider subprocess started with `process_group(0)` (`borg-provider/src/subprocess.rs`) | `setsid`, `setpgid`, `killpg` | `setpgid`/`killpg` | Job objects |
| Signals | Stop/interrupt, CHLD reaping, `signalfd` for children | `SIGTERM`/`SIGKILL`/`SIGINT`/`SIGHUP`/`SIGCHLD`, `sigprocmask`, `signalfd` | `kqueue`/`signal` | No signals; `TerminateProcess`/console events |
| Parent-death kill | Helper children die with the host | `prctl(PR_SET_PDEATHSIG)` | — | Job object kill-on-close |
| Process inspection | Liveness, ancestry, command line, start time | `/proc/<pid>` | `libproc`/`sysctl` | Toolhelp32/`GetProcessTimes` |
| Advisory locks | Single-writer lease, lane/service/token locks, credentials | `flock` | `flock` | `LockFileEx` |
| File watching | Change detection during turns | `inotify` | `kqueue`/FSEvents | `ReadDirectoryChangesW` |
| Disk space | Preflight for large writes | `statvfs` | `statfs` | `GetDiskFreeSpaceEx` |
| Named FIFOs | Worker plumbing | `mkfifo` | `mkfifo` | Named pipes |
| File modes | `0600` sockets/credentials, `0700` dirs, `O_NOFOLLOW` | `chmod`, `open(2)` flags | Same | ACLs, `FILE_FLAG_*` |
| Clock ticks | CPU-time accounting | `sysconf(_SC_CLK_TCK)` | Same | `GetProcessTimes` |

Service and system integration:

- **Managed PostgreSQL.** `$BORG_HOME/pgdata`, port `5433` (`BORG_SESSIONS_PORT`), role/db
  `borg`/`borg_sessions`, log `$BORG_HOME/logs/postgres.log`. Borg does not install PostgreSQL:
  it finds `initdb`/`pg_ctl` on `PATH` or in version-suffixed directories such as
  `/usr/lib/postgresql/17/bin`, provisions under a Borg-home advisory lock, and (Linux only)
  starts the postmaster in **its own systemd unit** so a unit restart cannot take the database
  down (`session_store/cluster/systemd.rs`, whose header documents the 183-rejected-connections
  incident that motivated it). `BORG_SESSIONS_URL` points at an existing server instead.
- **systemd**: the cluster unit, transient `borg-session-<uuid>.scope` for CLI runs, and sleep
  inhibition (`sleep_inhibitor.rs`). macOS uses an IOPM assertion that requires a one-time admin
  authorization; Windows exposes no lid override.
- **Display / desktop**: `borg-display` is a headless Wayland compositor giving one session a
  private GPU-backed display. Linux desktop control needs AT-SPI2 on the session bus plus
  `/dev/uinput` and `wtype` (Wayland) or `xdotool` (X11). macOS compiles and caches a Swift
  `AXUIElement` helper with `swiftc`; Windows uses PowerShell 5.1+/`pwsh` and UI Automation.
- **Clipboard**: `arboard` with `wayland-data-control`; OSC 52 and bracketed paste for remote.
- **Terminal**: crossterm/ratatui against the real terminal. Borg does **not** allocate a PTY
  for model-run commands (piped stdio); it consumes a PTY only when run over SSH.
- **Dynamic loading**: `libloading` loads user extension code in-process behind a hash-pinned
  C ABI (architecture doc decision D8).

## 4. Process and session management

- Interactive work runs in a **detached per-session host**: the CLI re-executes itself with a
  session-host argument (`remote_commands.rs:1609 ensure_detached_session_host`,
  `detach_session_host_command`), then clients talk to it over the session socket.
- Ownership is an **exclusive writer lease** in PostgreSQL plus a presence socket; a bounded
  probe (250 ms) distinguishes "listening" from "serving" (`local_control.rs:937`).
- Commands are acknowledged within 30 s (`CONTROL_COMMAND_TIMEOUT`); a timeout is reported as
  *possibly durable*, never as rejected.
- **Unix-only guarantees**: local session control, concurrent attachment, and owner termination
  all `bail!` on non-Unix (`local_control.rs:857, :991, :2371`). On Windows Borg has no local
  control channel at all; only the relay path remains.
- Stop paths escalate SIGTERM → SIGKILL over the process group, reap with `WNOHANG`, and use
  `PR_SET_PDEATHSIG` for helpers.
- Background work: session-scoped watcher processes, durable jobs/leases (`autonomy.rs`), and
  subagents (in-process actors that may own child sessions).
- `borg-lanes` adds supervised services with health/resume budgets and lane-resource binding;
  service metadata is `spec.json` under `BORG_LANE_DIR`, `BORG_LANES_ROOT`,
  `$XDG_RUNTIME_DIR/borg/lanes`, or a temp directory keyed by euid, addressed by a socket path
  that must stay under the 108-byte `sun_path` limit.

## 5. IPC and network

| Channel | Shape | Notes |
| --- | --- | --- |
| Local control | One JSON command per `AF_UNIX` connection, JSON reply, then optional live stream (`Hello`/`Event`/`Lagged` frames) | Commands ≤ 1 MiB; reply read bounded to 4096 bytes; 30 s ack timeout |
| LSP broker | JSON-RPC over a Unix socket, one broker per workspace | Long-lived, multiplexed |
| Lane services | `spec.json` + Unix socket per service | Loopback-only front endpoints |
| Private display | Control socket owned by `borg-display` | Every input event and capture goes through it, never the user's seat |
| Borg Remote | axum HTTP/1 + WebSocket over rustls (server); `tokio-tungstenite` client | Opt-in enrollment, `host.json`, device proofs (ed25519), HMAC-signed owner commands |
| MCP | stdio child processes and HTTP servers | Tool schemas are capability-gated |
| ACP | JSON-RPC over stdio (`agent-client-protocol`) | Interoperability adapter, not an authority |
| Providers | HTTPS (reqwest/rustls); some routes are child CLIs whose JSON stdout is parsed | Claude/Codex are native-loop only |
| Runtime protocol v1 | `HostCommand`/`SessionEvent` envelopes with request, correlation and idempotency keys | Fixtures in `crates/borg-agent-runtime/protocol-fixtures/v1/` (5 files) are the conformance authority; 125 `ts-rs` types mirror the same shapes |

Enrollment credentials and secrets live under `$BORG_HOME/remote/host.json` and the provider
credential store, mode `0600`, written through temp-file + `rename`.

## 6. Files and configuration

| Path | Contents |
| --- | --- |
| `$BORG_HOME` (default `~/.borg`, `host_paths.rs`) | All durable host state |
| `$BORG_HOME/pgdata`, `logs/postgres.log` | Managed cluster |
| `$BORG_HOME/remote/sessions/` (owner-only dir, `0600` sockets) | `<uuid>.control.sock`, `<uuid>.control.presence.sock`, `<uuid>.control.owner.json` |
| `$BORG_HOME/remote/host.json` | Enrollment identity/config |
| `$BORG_HOME/state/computer-use` | Cached platform helpers (Swift/PS binaries) |
| `$XDG_RUNTIME_DIR/borg/lanes` | Lane sockets |
| `~/.config/borg/agent.toml` (`dirs::config_dir()`, `BORG_AGENT_*`) | Host configuration |
| `~/.borg/AGENTS.md`, `<project>/AGENTS.md` | Guidance injected into context |
| `<project>/.borg/{skills,extensions,retrievers}`, `.borg/blu.toml`, `.borg/blu.audit.jsonl`, `.borg/blu.reload` | Project-local plugins, adapters, Blu workflows and audit log |

Note the deliberate asymmetry: **configuration** follows XDG/platform dirs, while **durable
state** is pinned under `$BORG_HOME`. A port must keep both behaviours or it will silently
relocate a machine's journal.

## 7. JSON as the boundary

JSON is not an implementation detail here; it is the product's interoperability contract:

- Every control command, every durable event, every fixture and every relay frame is JSON.
- `serde_json` is built with `arbitrary_precision`, so numeric tokens are round-tripped as their
  **exact decimal text**. A naive `f64`/`u64` JSON codec will silently rewrite durable history.
- Enums are internally tagged (`#[serde(tag = "type", rename_all = "snake_case")]`), so tag
  string spelling is part of the schema.
- `Option` fields are omitted rather than null in many types; `u64` sequences and cursors exceed
  2^53; timestamps are RFC 3339 UTC with `Z`; blobs are base64.
- 125 generated `bindings/*.ts` files plus 5 protocol fixtures give a port two independent
  oracles: the Rust types and a frozen serialized corpus.

## 8. Subprocess and platform assumptions

- A POSIX shell for the shell-first `exec` tool (`$BORG_AGENT_SHELL` override), argv arrays with
  `shlex` quoting, inherited cwd/env, and `process_group(0)` on spawn.
- Provider CLI adapters parse structured stdout from external CLIs (OpenCode non-Go, Grok Build,
  Muse Code); login flows drive browser/device-code handshakes.
- The updater replaces installed binaries: download, checksum, staged rename, `chmod +x`.
- LSP servers, `git`, `initdb`/`pg_ctl`, FFmpeg (or a managed `imageio-ffmpeg` wheel on macOS),
  and Python/Bun workers are all assumed to exist or be installable on the host.
- Terminal assumptions: a TTY with ANSI, bracketed paste, and optional graphics protocols for
  images.
- 175 `BORG_*` environment variables are read; several (`BORG_AGENT_TOOL_SOCKET`,
  `BORG_AGENT_TOOL_TOKEN`, `BORG_COLLAB_RELAY`) are cross-process authority, not preferences.

## 9. What Grail provides today

| Aspect | State (evidence) |
| --- | --- |
| Compiler | 24,843 lines of Grail (`compiler/*.grl`): lexer, native checker/lowering, ownership, optimizer, machine selection, runtime |
| Standard library | 740 lines across 13 modules (`lib/*.grl`); `io`, `fs`, `process`, `strings`, `vecs`, `hashmap`, `collections`, `math`, `order`, `env`, `core`, `hash`, `concurrent_map` |
| Host operations | 28 `f_host_*` operations: args/env/exe, open/read/write/close/pipe, read_file/write_file, exists/mkdir/create_dir/list_dir/remove, print/newline/print_num, now_ms/sleep_ms/exit/target, and `tcp_connect`/`tcp_listen`/`tcp_accept`/`tcp_port` |
| Syscall boundary | `compiler/runtime.grl` maps **stable operation IDs** to per-architecture Linux syscall numbers (`rt_syscall`); already carries x86-64, AArch64 and RISC-V numbers |
| Targets | Linux only: x86-64, ARM64, RISC-V 64. Assembly + Clang/LLD, no C or Rust seed |
| Errors | Optional `T?` and structural result unions, `?` propagation; `io::from_errno` maps **Linux** errno numbers (`lib/io.grl`) |
| Concurrency | Stackful green tasks on a worker pool, own epoll reactor, `eventfd` fence, futex mutex, word atomics, offload; allocation is serialized |
| Networking | TCP (`AF_INET`) only — `rt_tcp_socket` calls `socket(2, …)`; no `AF_UNIX` |
| Missing (per `docs/design/implementation-status.md`) | User FFI, separate compilation/checked library interfaces, complete typed OS-error library, capability/authority model, suspension-effect contract, network resources/channels, macOS/Windows targets |

The important precedent: Grail already separates portable operation IDs from the syscall ABI.
Adding a per-OS backend is an extension of an existing seam, not a new architecture.

## 10. Gap matrix

| Borg need | Grail today | Work | Stage |
| --- | --- | --- | --- |
| File/dir/env/argv/time | Present (`fs`, `env`, `host` ops) | None | — |
| Pipes, `fork`/`exec`/`wait` | Present (`host::command`) | argv/env/cwd options, `WNOHANG` | 2 |
| JSON (exact decimals) | Absent | Codec in Grail | 0 |
| Unix sockets + peer creds | Absent (`AF_INET` only) | New `AF_UNIX` ops + `SO_PEERCRED` | 2 |
| Signals, process groups, PDEATHSIG | Absent (only `exit`) | New ops + typed results | 2 |
| TOML | Absent | Subset parser | 1 |
| regex / glob | Absent | Library or restricted matcher | 3 |
| TLS (client and server) | Absent | FFI to a system TLS stack, or out-of-process | 4 |
| HTTP/1.1 + SSE + WebSocket | Absent | On top of TCP + TLS | 5 |
| PostgreSQL wire + SCRAM | Absent | Large: auth, extended query, TLS | 4 |
| base64/hex/uuid/RFC3339 | Partially (no base64/uuid) | Small pure modules | 0–1 |
| sha2/hmac/ed25519/aes-gcm | Absent | Pure implementations | 4 |
| zstd/zip/PNG/JPEG/WebP | Absent | Out-of-process or FFI | 6 |
| inotify/`/proc`/`flock`/`statvfs` | Absent | Three per-OS implementations | 3 |
| Threads + blocking offload | Partially (green tasks, offload) | Effect contract for foreign blocking calls | 2 |
| Separate compilation | Absent (whole-program assembly) | Interface/compiled-module layer | 1 |
| FFI | Absent | Language feature + authority policy | 1 |
| D-Bus/AT-SPI2, Wayland/X11/uinput, AXUIElement, UIA/COM | Absent | Out-of-process adapters (recommended) | 7 |
| Blu guest | Absent | Reuse `blu-lang` out-of-process, or port Blu | 7 |

## 11. FFI and runtime capabilities required first

Ordered, with the reason each precedes the next:

1. **A per-OS runtime backend seam.** `rt_syscall` already hides numbers behind operation IDs.
   Extend it to `linux`/`darwin`/`windows` backends, and keep `io::from_errno` OS-specific
   (Win32 errors are not errno). Nothing OS-facing can be added honestly before this.
2. **A complete, typed OS-error library.** Borg distinguishes "not found", "denied", "busy",
   "not the owner", "already exists"; Grail's `io::Error` covers six Linux numbers. Every
   fallible OS operation added later inherits this shape.
3. **An FFI boundary (`extern C` declarations, linking, calling convention, no unwinding
   across the boundary, checked pointer/ownership exposure).** This is the single largest
   missing prerequisite. Without it there is no `dlopen` for native extensions, no
   `AXUIElement`/ObjC runtime on macOS, and no COM/UI Automation on Windows. Not everything
   needs it: D-Bus and Wayland are socket protocols, and `evdev`/`uinput` need `ioctl`, which a
   new runtime operation can expose without FFI. `implementation-status.md` records this as
   "Missing" and is explicit that today's raw intrinsics are a *restricted trusted runtime
   boundary, not a safe FFI feature*.
   - Policy: FFI belongs behind the project's authority model — explicit capability, not ambient
     authority — and duplicated only in `unsafe module`-style units, mirroring `runtime`.
4. **Plain-old-data at the FFI edge**: C strings, borrowed byte slices, output pointers, and a
   defined rule for foreign memory lifetimes. Grail's ownership checker rejects unmodelled
   aliasing, so the boundary types must be narrow and copy-based.
5. **Suspension/blocking contract.** Borg's async I/O model blocks constantly. Grail lists
   suspension effects, cancellation that retains borrowed storage, and "lock guards and foreign
   blocking calls need explicit suspension/migration rules" as prerequisites. Without them a
   green-task fleet that calls TLS blocking calls will stall its workers.
6. **Separate compilation and checked library interfaces.** The compiler emits whole-program
   assembly today. A 363,000-line host cannot be built as one unit (and a staged port needs to
   link one ported module at a time).
7. **Exact JSON numbers** — decimal text passthrough, or arbitrary-precision integers, before
   any durable event is written.
8. **A TLS decision**: FFI to a platform stack (OpenSSL; Network.framework on macOS; Schannel on
   Windows) versus a Grail TLS 1.3 subset. A pure-Grail TLS stack is a multi-month project with its own security
   review; FFI is the pragmatic route.

## 12. Pure modules that can port immediately

Modules with no filesystem, process, socket or window-system dependency. Verified by grep:
`borg-core/src/*.rs` and `borg-view/src/*.rs` contain no `std::fs`, `std::process` or `libc`
usage.

| Module | Lines | Dependencies | Why it can move first |
| --- | ---: | --- | --- |
| `borg-core` (`model.rs`, `usage.rs`, `compaction.rs`, `warming.rs`) | 889 | `serde`, `serde_json` | The provider-neutral message/tool/usage contract. Zero OS surface |
| `borg-view` (projection/reducer) | 10,923 | `borg-core` + provider **types**, `chrono`, `uuid` | Deterministic pure functions from events to rows: ideal differential-test target |
| Wire types + fixtures (`protocol-fixtures/v1`, 125 `ts-rs` types) | 5 fixtures | — | Frozen serialized corpus; the oracle for any ported codec |
| Small codecs: base64, hex, UUID formatting, RFC 3339 parse/format, semver compare, shell quoting | dozens | — | Pure integer/string work; needed by everything else |
| Text shaping: width and grapheme segmentation | — | — | Pure tables + string logic; needed by any renderer |

Not portable early despite looking pure: anything reachable from `reqwest`, `sqlx`,
`tokio::fs`, `tokio::process`, `libloading`, `arboard`, `gpui`, or `blu-lang`.

## 13. Staged plan

Each stage has a gate: the stage is done when its acceptance check runs on the named OSes.
"Linux" below means Linux x86-64 first, then AArch64/RISC-V.

| Stage | Deliverable | Gate | Linux | macOS | Windows |
| --- | --- | --- | --- | --- | --- |
| 0 | `json` module (parse/print, exact numbers) + fixture tool (§14) | Round-trips all 5 protocol fixtures byte-exactly; decodes into typed records | Yes | Yes (same code) | Yes (same code) |
| 1 | Separate compilation seam; `borg-core` + wire subset in Grail; TOML subset reader | Compiles as ≥2 linked modules; model round-trips events from a real journal capture | Yes | Yes | Yes |
| 2 | Per-OS runtime backends: unix sockets + peer creds, signals, process groups, `WNOHANG`, file modes, locks | Local-control **client** sends one command and reads one status reply from a live Rust host | Yes | `LOCAL_PEERCRED`, `kqueue` | Needs a new IPC decision first (see blocker 6) |
| 3 | Read-only client: attach, tail live frames, render text; `/proc`→`libproc`→Toolhelp equivalents; `inotify`→`kqueue`/RDCW | `borg inspect live`-equivalent output matches the Rust CLI on the same host | Yes | Partly | TUI only |
| 4 | TLS via FFI + PostgreSQL wire client (SCRAM, extended query), journal reader | Reads an existing `~/.borg/pgdata` journal, replays a session | OpenSSL | Network.framework or OpenSSL | Schannel |
| 5 | HTTP/1.1, SSE, WebSocket; provider client for one native-loop provider | One provider turn completes end-to-end from Grail | Yes | Yes | Yes |
| 6 | Tool execution parity: fs/exec tools, LSP client, MCP client, approval gates, attachments | Read-only + shell tools approved and journaled identically | Yes | Yes | Yes |
| 7 | Full host parity: detached host, relay, computer use, extensions, Blu, lanes/services | Two hosts (Rust and Grail) interoperate through the relay and the journal | Yes | Helpers reused | Helpers reused |

Per-OS notes:

- **Linux**: the syscall tables, epoll reactor, futex and `inotify` all exist in some form; this
  is the only track that can reach stage 3 without new concurrency primitives.
- **macOS**: needs a new backend (`kqueue` instead of epoll, `mach_absolute_time`, `libproc`,
  `LOCAL_PEERCRED`), a Mach-O/`ld64` (or `clang` link) output path instead of ELF+LLD, and no
  fork-based spawning assumptions. Accessibility can stay in the existing Swift helper.
- **Windows**: the hardest. There is no `fork`, no signals, no `AF_UNIX` use in Borg today, and
  Borg's own local control channel already refuses to run there. Handle-based I/O (`IOCP`),
  Job objects, named pipes and `Schannel` are all new. Start this track at stage 0–1 only
  (pure modules), and treat the IPC design as a prerequisite, not a port task.

## 14. Smallest useful first port

**Ship a JSON codec plus a protocol-fixture conformance tool, and nothing else.**

- `src/json.grl`: parser and writer for JSON text. Numbers are preserved as their exact source
  text (a `Number` variant holding the literal), so `arbitrary_precision` semantics survive.
  Object keys serialize in sorted order with duplicate keys resolving last-wins, matching
  `serde_json`'s default `Map` (a `BTreeMap`; the workspace does not enable `preserve_order`).
- `src/fixtures.grl`: reads each `protocol-fixtures/v1/*.json` from the Borg checkout (path by
  argument, no hard-coded home directory), decodes the envelope fields it needs, re-encodes, and
  compares against the original text modulo insignificant whitespace.
- A Rust cross-check script (outside Grail) runs the same fixtures through `serde_json` with the
  same feature flags and asserts the two agree, so the Grail side is measured against the real
  contract rather than a hand-written expectation.

Why this and not `borg-core` first: it needs only `fs::read_text` — no FFI, no sockets, no
threads, no clocks — and it is the substrate every later stage depends on. It also drives real
Grail gaps immediately (enums with payloads, ordered maps, string building, error unions), which is exactly the feedback a language project wants before committing to a 10k-line
port. Acceptance: all 5 fixtures round-trip with zero diffs, and the tool exits non-zero on an
injected one-character mutation.

## 15. Exact blockers

1. **No user FFI.** Blocks a real TLS client, `dlopen`-based extensions, macOS `AXUIElement`,
   and Windows COM/UI Automation. D-Bus, Wayland and `evdev`/`uinput` are reachable without FFI
   (sockets and `ioctl`), but only by growing the runtime's operation set. Where FFI is refused,
   the affected pieces become out-of-process adapters.
2. **No separate compilation / checked library interfaces.** The compiler reads every module
   source and emits whole-program assembly. A 363,000-line port cannot be built or linked
   incrementally.
3. **No macOS or Windows target at all.** The runtime is a Linux syscall table; `io::from_errno`
   maps Linux numbers; output is ELF via Clang/LLD. Three stages of the plan require two entirely
   new backends.
4. **No JSON, TOML, TLS, HTTP or regex in the standard library**, and no `AF_UNIX`
   (`rt_tcp_socket` is `AF_INET` only). Each is load-bearing for the protocol or the control
   channel.
5. **The journal is a PostgreSQL wire client.** `sqlx` with SCRAM and TLS is the only durable
   store by design (`docs/session-store-backends.md` explicitly refuses a second store). A Grail
   host must either implement that client or cannot read durable history.
6. **Windows has no local control channel even in Borg.** `local_control.rs:991` refuses
   non-Unix; attachment and owner termination likewise. A Windows port needs a new IPC design
   decision (named pipe or loopback TCP) with its own security review — porting cannot supply it.
7. **Concurrency primitives are Linux-specific.** epoll, `eventfd`, futex and `clone` are hard-
   coded in `runtime.grl`; allocation is serialized; the project's own status says multi-thread
   scheduler safety is unproven.
8. **No suspension-effect contract or cancellation rule for foreign blocking calls**, which is
   precisely what an async host full of blocking I/O needs (blockers 5 and 7 compound here).
9. **Exact JSON numbers.** `serde_json` `arbitrary_precision` is enabled; Grail has integers and
   floats but no decimal-text number type.
10. **Blu.** Extensions/workflows execute an embedded `blu-lang` guest; the port needs either an
    out-of-process Blu or a Grail Blu implementation.
11. **175 `BORG_*` environment variables and systemd/launchd expectations** are part of the
    operational contract (authority tokens, relay URLs, unit names), not incidental config.
12. **No regex/glob in the stdlib**, while Borg uses both for permission matching, search and
    tool routing.

## 16. Open decisions

- **FFI or sidecars.** If Grail will not host FFI soon, stages 4–7 can still proceed by keeping
  TLS/HTTP, the database client, and the platform adapters as *external processes* speaking the
  existing JSON/Unix-socket protocols. That is a different product shape — a protocol client
  rather than a host — and should be chosen deliberately.
- **Port the host, or write a Grail client first.** A Grail client that speaks protocol v1 to an
  unmodified Rust host delivers user-visible value at stage 3, long before parity, and never
  risks forking the journal. This is the lower-risk reading of the same plan.
- **Keep platform adapters out of process.** `borg-display`, the Swift helper, the PowerShell
  helper, `pg_ctl`, LSP servers and provider CLIs are already separate programs. Reusing them
  removes most of the FFI surface; reimplementing them in Grail is not required for parity.
- **If FFI is approved**, order it behind the authority model (explicit capability, no ambient
  authority) and treat `unsafe module`-style units as the only place foreign calls appear.

## 17. What was and was not verified

Verified by reading source and generated artifacts at the commits named above: crate inventory
and sizes, dependency list, platform-conditional file count, distinct `libc` symbols, host and
environment surface, control-socket framing and bounds, storage layout and service supervision,
Grail's operation table, syscall indirection, target list and documented capability gaps.

Not verified: runtime behaviour under load; Borg on macOS or Windows in practice; any Grail-side
implementation of the proposed stages (none was written); whether `SO_PEERCRED` checks are
uniform across every Unix control socket; and PostgreSQL's exact extended-query surface used by
`sqlx`, which determines the size of the stage 4 client.
