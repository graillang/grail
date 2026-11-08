# Borg Agent CPU port

The first bounded increment of the Borg Agent → Grail port: the JSON substrate its wire and
configuration documents are made of, plus the protocol-v1 envelope header that classifies them.
Borg Agent is read-only here; the reference is its own JSON semantics — `serde_json` 1.0.151 with
`arbitrary_precision`, the crate version and feature set `crates/borg-*` build with. The plan and
staging live in [docs/design/borg-agent-port.md](../docs/design/borg-agent-port.md).

```
src/json.grl                 parser, canonical writer, deep copy, member/array accessors, flatten
src/wire.grl                 protocol-v1 envelope header: discriminant, protocol/version, per-kind fields
tests/json_test.grl          the Grail side: `json.compact`, `json.scalar`, `json.error` per document
tests/wire_test.grl          the Grail side: `wire.header <file> <field> <value>`, `wire.error <file> <path> <reason>`
tests/fixtures/v1/           Borg's protocol-v1 conformance corpus, copied verbatim
tests/fixtures/edge/         number, escape, structure, nesting-limit and malformed documents
tests/fixtures/wire/         envelope mutations: missing, mistyped, wrong protocol, wrong version
tests/parity/json.rs         the reference: serde_json compact re-serialisation and scalar walk
tests/parity/wire.rs         the reference: the same header rule over serde_json values
tests/parity/json.txt        committed reference output (141 lines, 20 documents)
tests/parity/wire.txt        committed reference output (46 lines, 11 documents)
tools/borg-test.mjs          build + compile + run + diff
```

## Run

```sh
just borg-test                          # hermetic: diff against the committed reference
bun tools/borg-test.mjs --regenerate    # rebuild both references from serde_json (offline)
```

`--regenerate` builds `borg/tests/parity/ref`, a two-binary Rust crate, with `cargo build --offline`
against the cached `serde_json` 1.0.151. It needs no network and no Borg checkout: the fixtures are
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

The suite compares **187 lines over 31 documents**, and every value in them comes from
`serde_json` rather than from a restatement: the reference parses with Borg's own crate and prints
what it parsed. `wire.rs` pins the v1 header *rule* (no Rust program classifies these fixtures
without building the whole 363k-line Borg workspace), and uses `serde_json` for every value it
reads, so a divergence in either the parser or the rule is a line difference.

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
- **Smaller findings**: `const` is not accepted (use a function); `mut x := v` is invalid (`mut x = v`);
  match patterns use bare variant names (`Num(t)`, not `Json::Num(t)`); a statement after a diverging
  `loop` is rejected as unreachable; the four `cfg`-free test programs need no compiler flags beyond
  `--default-u64 --typed-refs`, which the runner passes.

## Not in scope yet

Everything else in the port map: the Unix control socket (stage 2), the PostgreSQL journal client
(stage 4), TLS/HTTP (stage 5) and tool execution (stage 6). No network, IPC, UI or compiler/back-end
change is part of this increment.
