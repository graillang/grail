# Borg Agent CPU port

Ten bounded increments of the Borg Agent → Grail port: the JSON substrate its wire documents are
made of, the TOML its configuration files are written in, the protocol-v1 envelope header that
classifies a document, the `agent.toml` loader that applies Borg's compiled-in defaults, the
local-session ownership state that decides whether a session still has an owner, the JSON-RPC frames
and single-in-flight dispatch that ACP, LSP and MCP conversations are built from, and the service
supervision rules — restart policy, backoff, exit semantics — with the layout they write into,
the local IPC transport boundary in front of those frames, the journal rules those frames carry, the typed transcript events they are made of, the permission gates that decide whether a tool
call runs, and the crash-safe persistence of session state through the new C OS ABI.
Borg Agent is read-only here; the reference is its own JSON semantics — `serde_json` 1.0.151 with
`arbitrary_precision`, the crate version and feature set `crates/borg-*` build with. The plan and
staging live in [docs/design/borg-agent-port.md](../docs/design/borg-agent-port.md).

```
src/json.grl                 parser, canonical writer, deep copy, member/array accessors, flatten
src/wire.grl                 protocol-v1 envelope header: discriminant, protocol/version, per-kind fields
src/toml.grl                 TOML subset parser, table assembly, shape walk, accessors
src/config.grl               `agent.toml` → effective settings with Borg's compiled-in defaults
src/session_state.grl        owner record codec, executable identity, `/proc` start time, liveness
src/jsonrpc.grl              JSON-RPC frames, stdio and Content-Length framing, dispatcher state
src/supervisor.grl           restart policy, backoff, service states, layout resolvers
src/transport.grl            socket addressing, peer credentials, connection lifecycle
src/journal.grl              event persistence, cursor arithmetic, resume paging, status
src/events.grl               typed session-event payloads for the transcript kinds
src/permission.grl           permission modes, path scoping, approval grants, denial reasons
src/ffi/store.grl            framed, atomically renamed session-state persistence over sys_grail
                             (kept out of borg/src/*.grl because it needs the FFI module)
tests/json_test.grl          JSON: `json.compact`, `json.scalar`, `json.error` per document
tests/wire_test.grl          protocol: `wire.header <file> <field> <value>`, `wire.error <file> <path> <reason>`
tests/toml_test.grl          TOML: `toml.value <file> <path> <kind> <text>`, `toml.error <file>`
tests/config_test.grl        config: `config.value <file> <key> <value>`, `config.error <file> <path>`
tests/session_test.grl       ownership: `case <name> record|field|active|state|obsolete|start|identity …`
tests/jsonrpc_test.grl       frames: `frame|parse|take|dispatch <name> …`
tests/supervisor_test.grl    supervision: `supervise|home|config|lanes|session|budget <name> …`
tests/transport_test.grl     transport: `address|fits|limits|ucred|peer|conn <name> …`
tests/journal_test.grl       journal: `persistence|cursor|replay|page|status <name> …`
tests/events_test.grl        events: `tag|field|wire|roundtrip|error <name> …`
tests/permission_test.grl    gates: `mode|relative|contains|enrolled|check|grants <name> …`
tests/store_test.grl         persistence: `roundtrip|refuse <case> <result>` (FFI suite)
tests/fixtures/v1/           Borg's protocol-v1 conformance corpus, copied verbatim
tests/fixtures/edge/         number, escape, structure, nesting-limit and malformed documents
tests/fixtures/wire/         envelope mutations: missing, mistyped, wrong protocol, wrong version
tests/fixtures/toml/configs/ Borg's shipped example configurations, copied verbatim
tests/fixtures/toml/cases/   TOML constructs and invalid documents
tests/fixtures/config/       `agent.toml` documents: full, partial, empty, wrong-typed, negative
tests/fixtures/session/      ownership scenarios: records, process observations, stat lines
tests/fixtures/jsonrpc/      frame specs, parse cases, framed buffers, dispatch scripts
tests/fixtures/supervisor/   policies with op scripts, and layout inputs
tests/fixtures/transport/    addressing, limit, peer and connection scenarios
tests/fixtures/journal/      persistence kinds, cursor steps, pages and status scripts
tests/fixtures/events/       one event document per transcript kind, plus malformed ones
tests/fixtures/permission/   modes, path cases, enrolled roots and grant sequences
tests/parity/json.rs         the reference: serde_json compact re-serialisation and scalar walk
tests/parity/wire.rs         the reference: the same header rule over serde_json values
tests/parity/toml.rs         the reference: the toml crate's value model, walked in the same order
tests/parity/config.rs       the reference: Borg's defaults applied to a toml value
tests/parity/session.rs      the reference: Borg's ownership rules, copied verbatim, with citations
tests/parity/ref-acp/        separate crate: the envelope built with agent-client-protocol-schema
tests/parity/anchors.json    the source snippets those rules depend on (checked by `--anchors`)
tests/parity/json.txt        committed reference output (141 lines, 20 documents)
tests/parity/wire.txt        committed reference output (46 lines, 11 documents)
tests/parity/toml.txt        committed reference output (230 lines, 13 documents)
tests/parity/config.txt      committed reference output (66 lines, 6 documents)
tests/parity/session.txt     committed reference output (120 lines, 23 documents)
tests/parity/jsonrpc.txt     committed reference output (71 lines, 22 documents)
tests/parity/supervisor.txt  committed reference output (45 lines, 20 documents)
tests/parity/transport.txt   committed reference output (30 lines, 13 documents)
tests/parity/journal.txt     committed reference output (34 lines, 34 documents)
tests/parity/events.txt      committed reference output (107 lines, 11 documents)
tests/parity/permission.txt  committed reference output (31 lines, 27 documents)
tools/borg-test.mjs          build + compile + run + diff
```

## Run

```sh
just borg-test                          # hermetic: diff against the committed reference
bun tools/borg-test.mjs --regenerate    # rebuild all six references offline
bun tools/borg-test.mjs --anchors       # re-check the copied rules against the Borg checkout
```

`--regenerate` builds `borg/tests/parity/ref` (five binaries) and `ref-acp` (one) with
`cargo build --offline` against the cached `serde_json` 1.0.151, `toml` 1.1.4 and
`agent-client-protocol-schema` 1.5.0. It needs no network and no Borg checkout: the fixtures are
committed, and both sides read the same bytes in the same order (the runner passes the sorted file
list on argv).

## What "parity" means here

Both sides print the same labels from the same documents, so a difference names the exact document
and field:

- `json.compact <file> <canonical>`: the whole document re-serialised with no whitespace and object
  keys in `BTreeMap` order.
- `json.scalar <file> <path> <text>`: one line per scalar, in the reference's walk order, with the
  scalar's exact rendering — numbers as their decimal text, strings quoted and escaped.
- `json.error <file>`: the document was rejected. Only rejection is compared, not the message.
- `wire.header <file> <field> <value>`: header fields in the reference's order.
- `wire.error <file> <path> <reason>`: the path that failed and the layer that rejected it
  (`missing`, `type`, `protocol`, `version`, `envelope`).
- `toml.value <file> <path> <kind> <text>`: one line per node; tables and arrays print their length
  first and then their children in byte key order, so the line sequence *is* the value model.
  Formatting is deliberately not compared — a loader's contract is what a document means.
- `config.value <file> <key> <value>` / `config.error <file> <path>`: effective settings in schema
  order — capabilities after the dependency intersection — with strings quoted so `""` stays
  distinguishable from an absent key.
- `case <name> …`: one scenario per file — the decoded owner record and its fields, the `roundtrip`
  of encoding it back, the `/proc` start-time parse, the identity format, and the derived `active`,
  `state` and `obsolete` decisions.
- `frame|parse|take|dispatch <name> …`: an envelope built from a spec and its canonical bytes; a
  document classified by the envelope rule; one framed message read out of a buffer; and the
  outcome of a dispatch script.
- `supervise <name> <i> <event> <state> delay=… failures=… restarts=…`: one supervision script
  replayed, plus `home|config|lanes|session|budget` for the layout resolvers.
- `address|fits|limits|ucred|peer|conn`: the socket address chosen for a directory, the transport
  limits, a peer-credential verdict, and a connection replayed event by event.
- `persistence|cursor|replay|page|status`: an event kind's persistence, a cursor advanced over a
  sequence of observations, a resume page, and the status a sequence of journaled changes leaves.
- `tag|field|wire|roundtrip|error`: a decoded transcript event, its fields, the exact wire text it
  re-encodes to, and the reason class for a document the shapes reject.
- `mode|relative|contains|enrolled|check|grants`: a permission mode, a relative-path verdict with its
  reason, component-wise containment, enrolled-root membership, a path gate, and grant coverage.

The suite compares **921 lines over 200 documents**, and every value in them comes from
`serde_json` rather than from a restatement: the reference parses with Borg's own crate and prints
what it parsed. `wire.rs` and `config.rs` pin the v1 header *rule* and the default table (no Rust program classifies
these fixtures, or loads this config without building the whole 363k-line Borg workspace), and use
the real crates for every value they read, so a divergence in either the parser or the rule is a
line difference.

## Ported contract (must not drift)

These were measured against `serde_json` 1.0.151, not assumed; each is covered by a fixture.

- **Numbers keep their decimal text.** `123456789012345678901234567890` is not rounded and
  `1.234567890123456789012345678901` keeps all 30 digits. `serde_json` normalises only two things:
  the exponent marker and sign (`1E5`, `1e5` and `1E+5` all become `1e+5`, `1e0005` keeps its
  digits), and a negative *integer* zero (`-0` becomes `0`, while `-0.0` and `-0e0` keep the sign).
- **Objects are ordered by key.** A `BTreeMap` iterates in byte order, so parsing canonicalises
  members; duplicate keys resolve last-wins, as a map insert does.
- **Strings escape minimally.** `"` and `\`, the short escapes for `\b \f \n \r \t`, `\u00xx` in
  lowercase for the remaining C0 controls; DEL, non-ASCII, `/` and `<` are written raw as UTF-8.
- **Nesting is limited to 127 containers**; the 128th is an error, matching `serde_json`'s default
  recursion limit.
- **Encoding is validated strictly**: no leading zeros, no bare `+`, no `NaN`, no trailing commas,
  no BOM, no trailing input, and `\uD800`-style lone surrogates are rejected while surrogate pairs
  combine. Invalid UTF-8 in a string is rejected.
- **The envelope rule**: `protocol` must be `borg.agent_runtime`, `version` must be `1`, and the
  discriminant is the first present of `command`, `event`, `state`, `fixtures`. Commands require
  `request_id`, `correlation_id`, `idempotency_key`, `sequence`, `created_at` and
  `command.{type,session_id}`; events require `session_id`, `cursor` and `event.kind.type`;
  snapshots require `session_id`, `cursor` and `state.status`; the manifest requires `fixture_schema`,
  a `fixtures` array, and `compatibility.{legacy_host_protocol, legacy_host_protocol_version, adapter}`.

## TOML: the subset, and what is refused by name

The subset is the one Borg's own configuration corpus uses, measured over `configs/*.example.toml`
and the two files `borg` writes under `$XDG_CONFIG_HOME/borg`: basic and literal strings with
escapes, integers (decimal, `0x`, `0o`, `0b`, `_` separators, signs), booleans, arrays (multi-line,
trailing comma, comments inside), inline tables, and `[table]` / `[a.b]` headers — with comments.
That corpus contains **no floats, no dates, no multi-line strings, no arrays of tables**, so those
are rejected with `Unsupported` rather than approximated: `1.5` stays an error instead of silently
becoming a rounded number, and a `"""` string is refused instead of being read as three strings.
Dotted keys inside an inline table are refused for the same reason (they would have to nest).

A header with no keys is still a table in the document, so `[approvals]` with every setting
commented out appears as an empty table — that is where a first version diverged from the
reference, and the fixture keeps it honest. Defined twice, a header is an error, as it is upstream.

## Configuration: defaults are Borg's, not invented

`src/config.grl` loads `agent.toml` into effective settings. Every default is cited to the code that
compiles it in (`crates/borg-cli/src/agent_config.rs`):

| Section | Defaults |
| --- | --- |
| `[capabilities]` | `multiplayer`, `subagents`, `autonomous_team`, `shared_work`, `presence`, `cloud_sync`, `web_relay`, `auto_resume_usage_limits`, `watcher_yield` → `true`; `telemetry`, `resume_paused_goal_on_message`, `claude_refusal_fallback` → `false` (`impl Default for CapabilityConfig`) |
| `[usage_count]` | `enabled = false` (derived `Default`) |
| `[prompt]` | `append = ""` (derived `Default`) |
| `[update]` | `auto_install = true`, `check_interval_hours = 24` (`impl Default for UpdateConfig`) |

A key present with the wrong type is an error naming its path — `multiplayer = "yes"` is a mistake,
not a reason to fall back to the default — and a negative `check_interval_hours` is an error rather
than a wrapped `u64`.

Capability values are the *effective* ones. `apply_dependency_intersection`
(`crates/borg-agent-runtime/src/contract.rs:1403`) clears a dependent when its parent is off —
`autonomous_team` without `subagents`, `shared_work` and `presence` without `multiplayer`,
`web_relay` without `cloud_sync` — and the port applies the same intersection, so a configuration
Borg would not honour is not reported as if it would. `cascade.toml` is the fixture that keeps it
honest.

## Session ownership: the pure core

A local session's owner is a small JSON record next to its socket
(`<session-id>.control.owner.json`). Everything Borg decides from that record is pure once the
process table is reduced to observations, so it ports without a socket, a journal or a `/proc`
read:

| Rule | Source | Ported as |
| --- | --- | --- |
| Record shape, schema version 1 | `local_control.rs:405-414` | `OwnerRecord`, `decode`, `encode` |
| Unparseable or unknown schema = absent | `:529-542` | `RecordError::{Parse, Schema}` |
| Executable identity `dev:ino:len:mtime:mtime_nsec` | `:559-572` | `identity` |
| Start time = stat field 19 after the last `") "` | `:607-624` | `start_time` |
| Owner matches: alive, identity, then start time | `:631-649` | `matches` |
| A stale owner may be retired only if it is a different binary, still matching, and holds the lock | `:656-671` | `obsolete` |

`state` names the four outcomes: `Active` is exactly what `local_session_owner_is_active` reports,
and `Stale`, `Invalid` and `Absent` are the three reasons it reports false (a record whose process
is gone or rebuilt, a record that will not parse or has an unknown schema, and no record at all).
Borg collapses those to `false`; a port that reports *why* is more useful and cannot disagree with
it, which is what the scenarios pin down.

**Why this reference is copied rather than linked.** `borg-agent-runtime` builds the whole
363k-line workspace (tokio, sqlx, axum), so a reference binary cannot depend on it. `session.rs`
therefore carries the six functions verbatim, each with its line citation, and
`borg/tests/parity/anchors.json` lists the snippets those functions depend on.
`bun tools/borg-test.mjs --anchors` fails if any of them disappears from the Borg checkout, so an
upstream rule change breaks this suite loudly instead of drifting — deliberately verified by
breaking an anchor.

## JSON-RPC: frames, framing and dispatch

The envelope is the Agent Client Protocol's: `agent-client-protocol-schema` 1.5.0 is the reference,
and the port matches its bytes exactly — `"params": null` when there are no parameters,
`"result": null` for a null result, an id that may be a number, a string or null, and the crate's
own field order. Three Borg behaviours are copied with citations and anchors:

| Rule | Source | Ported as |
| --- | --- | --- |
| stdio framing: one compact object per line, 8 MiB cap | `native_mcp.rs:15`, `write` | `line` |
| header framing: `Content-Length: N\r\n\r\n`, 8 KiB header cap, 8 MiB body cap, `\r\n\r\n` or `\n\n` | `lsp.rs:1487`, `read_message` | `content_length`, `take_frame` |
| dispatch: ids from 1, one in flight, server requests answered with null, unrelated ids ignored, superseded request cancelled | `lsp.rs:1355-1408` | `Dispatcher` |

A completed frame only requires **valid JSON**: Borg reads the body into a value and classifies it
afterwards, so `shape_of` reports how a body would classify without making it a framing error. The
first version of this increment got that backwards and the suite caught it.

**A reference-crate hazard worth recording.** `agent-client-protocol-schema` enables
`serde_json`'s `preserve_order`, which turns every JSON map into an insertion-ordered one. Cargo
unifies features per build graph, so adding that crate to the shared reference silently changed the
*JSON and TOML reference outputs* — caught because the suite diffs them. The ACP reference now lives
in its own crate (`tests/parity/ref-acp`), with its own manifest, so one reference's dependencies
cannot redefine another's output.

## Supervision and layout

A supervised service is a small state machine plus a backoff rule, and the documented file layout is
a set of resolvers. Every rule is copied from `borg-lanes` or `borg-ui` with an anchor:

| Rule | Source | Ported as |
| --- | --- | --- |
| Nine service states | `services.rs:247` | `ServiceState` |
| An exit is transient only when the child exited with a listed code; a signalled child has no code and never is | `services.rs:102` | `is_transient` |
| Backoff is `max(backoff_ms, 50) * 2^min(failures, 6)`, saturating | `services.rs:2029` | `backoff` |
| A transient exit relaunches after the plain `backoff_ms` and counts no failure | `services.rs:1723` | `Supervisor::exited` |
| Any other exit adds a failure, uses the exponential backoff, and fails past `max_restarts` | `services.rs:1723` | `Supervisor::exited` |
| A launch that never happened is a failure too | `services.rs:1701` | `Supervisor::launch_failed` |
| `restarts` counts every relaunch, transient or not | `services.rs:1723` | `Supervisor::exited` |
| Resume budget is readiness + health interval + probe + 2 s, with a 120 s default window | `services.rs:172` | `resume_budget_ms` |
| `BORG_HOME`, then `HOME/.borg`, then the platform home | `host_paths.rs:6` | `host_home` |
| `XDG_CONFIG_HOME`, then `HOME/.config`, then the platform config dir, with `borg` beneath | `preferences.rs:542` | `config_root` |
| `BORG_LANE_DIR`, `BORG_LANES_ROOT`, `XDG_RUNTIME_DIR/borg/lanes`, then a per-euid temp dir | `lanes.rs:379` | `lane_root` |

The layout half is the path half only: it resolves where `agent.toml`, `editor.toml`, `pgdata`,
`logs/postgres.log`, `remote/host.json` and `remote/sessions/<id>.control.*` live. Nothing here starts
a process, reaps one, or touches the filesystem.

## Local IPC transport

The boundary in front of the JSON-RPC frames. Everything here is pure: no socket is opened, because
`socket(AF_UNIX)`, `bind`, `listen`, `accept`, `connect` and `getsockopt` need a runtime operation
Grail does not have yet, and adding one is a compiler/runtime change. What the port does carry is the
rule set a binding has to obey.

| Rule | Source | Ported as |
| --- | --- | --- |
| A long directory path is never passed as `sun_path`: the socket is addressed through `/proc/self/fd/<dirfd>/name` | `services.rs:485` | `socket_address` |
| Direct addresses are capped at 107 usable bytes of the 108-byte `sun_path` | kernel ABI | `usable_sockaddr_bytes` |
| Session directory `0700`, socket `0600` | `local_control.rs:1157, 1166` | `session_dir_mode`, `socket_mode` |
| One command per connection, at most 1 MiB | `local_control.rs:23` | `max_command_bytes` |
| The reply read is bounded to 4096 bytes | `local_control.rs:905` | `max_reply_bytes` |
| `SO_PEERCRED` must fill exactly `sizeof(ucred)` | `computer_use/linux/windows.rs:114` | `credentials_valid` |
| Shutdown stops new commands without cutting a reply in flight | `local_control.rs:1297` | `Connection::shutdown` |

The credential verdict is deliberately thin: the socket is `0600` inside a `0700` directory, so the
owner is the only expected peer, and a different uid is *reported* rather than granted anything.
`peer_verdict` names the peer; the permission bits remain the gate.

Addressing stays consistent with the layout section: `host_home`/`config_root` decide the
directory, `session_file` names `<id>.control.sock` inside it, and `socket_address` decides whether
that path can be a `sun_path` or has to go through the descriptor.

## Journal rules

The journal is a per-session sequence with strictly increasing numbers, and a client resumes by
asking for events after the cursor it last saw. Three rules decide what a reader can rely on, all
copied with anchors:

| Rule | Source | Ported as |
| --- | --- | --- |
| Persistence: audit evidence is durable, progress coalesces, provider chatter is live-only | `session_store.rs:280-400` | `provider_persistence`, `message_persistence`, `reasoning_persistence`, `context_window_persistence`, `delta_persistence` |
| A mirrored child event is only as durable as the child's record, and even a durable child provider event or child metadata stays live | `session_store.rs:365-400` | `subagent_persistence` |
| A cursor only moves forward: the furthest sequence seen is the resume point | `session.rs:3184` | `advance_cursor` |
| Replay is strictly after the cursor, so nothing is delivered twice | `session.rs:14276` | `replayed` |
| A resume reads bounded pages and reports whether more remain | `session.rs:14539` | `resume_page` |

Status is not recomputed from the shape of the events: `StatusChanged` is itself a journaled event
(`contract.rs:408`), so a resumed session's status is the last one written, and the port names the
seven values rather than inventing a transition table. Two details matter and are covered: a
*durable* provider event is the default's opposite (an unlisted provider kind is ephemeral, not
durable), and an assistant message still streaming coalesces while a user or system one is journaled.

## Typed transcript events

`SessionEventKind` is a serde-tagged union (`contract.rs:2624`), and the five transcript kinds are
ported with the serialization details a hand-written encoder gets wrong:

| Kind | Payload | Detail that matters |
| --- | --- | --- |
| `SessionStarted` | none | — |
| `SessionTitled` | `title`, `generated`, `usage_tokens`, `model` | `generated` is always written; `usage_tokens` is a **number**, not a quoted string |
| `StatusChanged` | `status`, `detail` | `detail` is always written, `null` when absent |
| `Message` | `message_id`, `actor`, `text`, `attachments`, `status`, `delivery` | `attachments` is omitted when empty; `delivery` is always written |
| `MessageDelta` | `message_id`, `delta` | — |

An unknown kind is refused by name rather than half-decoded: a reader that ignored it would drop
transcript rows. Each event is compared on three surfaces — decoded fields, the exact wire text the
port re-encodes, and a round-trip back through its own decoder. The wire comparison is what caught
`usage_tokens` being emitted as a string in the first version of this increment.

## Permission gates

Gates decide whether a call runs; they are not a sandbox (`docs/architecture.md` D4). The rules are
copied with anchors, including the denial strings, so a refusal reads the same after a port:

| Rule | Source | Ported as |
| --- | --- | --- |
| Modes are `full_access`, `auto`, `manual` | `contract.rs:374` | `Mode`, `mode_from` |
| Decisions are `allow_once`, `allow_session`, `deny` | `contract.rs:2446` | `Approval`, `approval_name` |
| The requested root must sit under a canonical enrolled root | `filesystem.rs:390` | `root_enrolled` |
| A path must be relative and free of traversal components | `filesystem.rs:404` | `validate_relative` |
| A symlink on the way is refused outright | `filesystem.rs:424` | `check_path` |
| Containment is **component-wise**, so `/w` does not contain `/work` | `filesystem.rs:437` | `contains` |
| An `allow_session` grant covers later calls of the same tool and scope; `allow_once` does not | approval semantics | `Grants` |

The containment rule is the one a port most easily gets wrong: Rust's `Path::starts_with` compares
components, so a string-prefix check would grant `/work` under a `/w` root and `/w2` under `/w`. Both
traps are fixtures, and a prefix mutation fails the suite.

## Persistence through the C OS ABI

`src/ffi/store.grl` writes and reloads session state through the FFI layer that landed with the C OS ABI
(`lib/sys/grail_ffi.grl`, `include/grail/`). It is the first increment that performs real I/O:

| Rule | Source | Ported as |
| --- | --- | --- |
| Write a same-directory temp file, close it, then rename over the destination | `crates/borg-provider/src/credentials.rs:432` | `persist` |
| A stored file carries `"BGS1"`, a little-endian length, then the payload | this port | `frame`, `unframe` |
| A short file, a foreign magic and a length disagreement are refused by name | this port | `SHORT_FILE`, `BAD_MAGIC`, `LENGTH_MISMATCH` |

The rename is the one operation the wrapper does not declare, so the module declares
`grail_os_fs_rename` itself against the same object file; nothing under `lib/` or `compiler/` was
edited. Handles are opaque and module-scoped, so every call is threaded with `?` exactly as the
landed FFI test threads it, and no file type is ever named outside `sys_grail`.

`just borg-store-test` builds the Linux backend into `lib/sys/grail_ffi_linux.o`, compiles the test
with the FFI wrapper, links it against the host C library and runs it in a scratch directory. It is a
separate suite because it needs a C toolchain and a hosted link; the hermetic `borg-test` count above
does not include its eight lines. The test round-trips an empty, a small and a JSON payload, and
refuses a header-only file, a foreign magic, a length that disagrees with the payload, an empty file
and an absent file, naming each reason.

## Limits and findings

- **Not modelled: command, event and snapshot bodies.** The header is what classifies and routes a
  document; modelling every `HostCommand` and `SessionEvent` variant is the next increment, and it
  does not change the rule above.
- **Accessors copy.** `member` and `array_item` return owned values. Projecting a field out of a
  borrowed vector element is not accepted when the borrow would have to outlive a loop back edge or
  escape a function, so the port copies the member list before indexing. Documents here are bounded
  control frames; this is a correctness-first choice, not a performance claim.
- **`string` is a byte sequence in this language.** `"literal"`, `&string` and `view(...)` all satisfy
  a `(&[u8])` parameter, so most conversions in the port are plain borrows; `view` was not needed.
- **No tuples**, so the recursive-descent parser returns `Parsed { value, at }`. Positions travel by
  value; a `&mut` cursor cannot be threaded because a `&mut` parameter is consumed by the call that
  receives it and cannot be used again, and cannot cross a loop back edge.
- **Methods reborrow, free functions do not.** `impl` methods taking `self: (&a mut Reader)` can call
  one another and mutate through `self` in a loop; the equivalent free functions had to be rewritten
  into methods (`Reader`, `Builder`, `Flattener`). Passing a reference-typed argument twice requires
  an explicit reborrow (`&wanted`), which is what `lib/hashmap.grl` already does.
- **Byte helpers take `u64`.** Indexing a `u8[]` yields a word, not a `u8`, so `is_space`, `hex_value`
  and friends are `u64`-valued; `u64(...)` is needed to widen a `u8` payload explicitly.
- **A foreign nominal type cannot be used as a reference parameter or constructed literally.** The
  walk that turns a parsed value into shape lines lives in `borg_toml` (`flatten`) rather than in
  the test, and `empty_table()` exists so `borg_config` can stand in for an absent section. Reading
  an enum field out of a borrow also does not copy, so `Setting` carries a `bool` rather than a kind
  enum.
- **A `match` over a borrow binds references, not copies** — passing one of those bindings to a
  second call, or returning it, is rejected. Reading `entries[index].value` needs a named local
  borrow (`entry := &entries[index]`), and a loop that both borrows an element and returns must go
  through a one-line helper (`copied_entry_value`).
- **The IPC increment stops at the syscall boundary.** `AF_UNIX` sockets, `SO_PEERCRED` and the
  accept loop need new runtime operations; that is a compiler change and out of scope, so this port
  carries the addressing, limits, credential validation and lifecycle rules only.
- **A function may take at most six parameters** when it is lowered to native code ("native function
  exceeds six parameters"); the supervision test hit this building a log line.
- **Matching an `Option`/enum *field* of a borrow moves it**, so the supervisor's policy and state are
  read through one-line copy helpers.
- **Smaller findings**: `const` is not accepted (use a function); `mut x := v` is invalid (`mut x = v`);
  match patterns use bare variant names (`Num(t)`, not `Json::Num(t)`); a statement after a diverging
  `loop` is rejected as unreachable; the four `cfg`-free test programs need no compiler flags beyond
  `--default-u64 --typed-refs`, which the runner passes.

## Not in scope yet

Everything else in the port map: the Unix control socket (stage 2), the PostgreSQL journal client
(stage 4), TLS/HTTP (stage 5) and tool execution (stage 6). No network, IPC, UI or compiler/back-end
change is part of this increment.
