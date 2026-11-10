# The Grail language server

`tools/lsp/main.grl` is a language server written in Grail. It speaks JSON-RPC 2.0 over
stdio with `Content-Length` framing, and it is the only language server in the tree:
`tools/lsp.mjs` is a three-line launcher that builds the Grail program from this tree and
hands it the parent's stdio.

```sh
bun tools/lsp.mjs            # build (cached by source digest) and serve on stdio
```

The launcher builds it with `--default-u64 --typed-refs`, the flags `tools/native.mjs`
already uses for the compiler and the other Grail programs the test harness builds.

Editors point their Grail client at that command. The server needs a `grail` executable to
run the compiler for diagnostics: `GRAIL_LSP_COMPILER`, then `GRAIL_COMPILER`, then `grail`
on `PATH`, in that order. The launcher passes the compiler it built from this tree, so a
checkout works with no configuration; the server itself never builds one.

## What is supported

Exactly what `initialize` advertises, plus the notifications a client must send:

| Capability | Behaviour |
| --- | --- |
| `textDocumentSync` | `openClose: true`, `change: 1` — full-text synchronisation |
| `textDocument/publishDiagnostics` | pushed after every `didOpen` and `didChange`, versioned |
| `textDocument/definition` | a same-file declaration (`definitionProvider: true`) |
| `initialize`, `initialized`, `shutdown`, `exit` | the JSON-RPC lifecycle, with the states it implies |

Nothing else is claimed. `hover`, `completion`, `rename`, `formatting`, `references`,
`documentSymbol` and pull diagnostics are **not** advertised and answer `-32601`.

## Definition

`textDocument/definition` re-lexes the buffer (`compiler/lexer.grl`, in process — no compiler
run) and answers from the same file:

- a call to a function declared in the file resolves to the name in its `fn` header, whether
  the declaration is above or below the call;
- a local use resolves to the nearest preceding declaration of that name in an enclosing
  block: `NAME :=`, `mut NAME`, a `for NAME` binding, or a parameter of the enclosing
  function header.

Block depth comes from `{}` nesting, so a declaration inside a block is not visible outside
it and a nearer one shadows an outer one. A name the file does not declare, a position
outside any name, and a member (`x.field`), method (`x.method()`) or module-qualified
(`module::name`) position answer `null`: this server does not guess across files. A request
without `params`, `textDocument` or `position` is `-32602`.

## Diagnostics come from the compiler

No diagnostic is invented here. For every change the server:

1. writes the buffer to `$TMPDIR/grail-lsp-<n>/<buffer-name>.grl`, where the name is the
   uri's last segment sanitised to `[A-Za-z0-9._-]`;
2. runs `grail check <buffer-name>` in that directory and reads the result back from a file
   in it, then removes every scratch file and directory;
3. parses the compiler's own `file:line:column: message` lines and publishes them.

The compiler prints the first error and exits, so one diagnostic is published per change —
whatever the compiler says, with its message text unchanged (the trailing
`at byte N near '...'` annotation included). A clean check publishes `[]`, which is how a
fixed buffer clears its squiggles; `didClose` publishes `[]` as well.

Positions follow the compiler: its line and column are 1-based and its column counts
**bytes**, while LSP positions are 0-based lines of **UTF-16 code units**, so the server
converts through the document's own line instead of copying the byte offset. The published
range covers one character at that position; the compiler does not report a width.

The check runs under `sh -c` with both streams redirected to the scratch file: `host::command`
inherits this process's stdio and the runtime exposes no descriptor redirection, and the
server's stdout is the protocol channel. If `grail check` cannot be run at all — a missing
compiler, a dead `sh` — the server sends one `window/showMessage` and publishes nothing,
rather than reporting an error that the compiler did not produce.

## Robustness

Malformed input is answered, never fatal:

| Input | Reply |
| --- | --- |
| Header block without a usable `Content-Length` | `-32700`, `id: null`; the frame is discarded and the reader resynchronises on the next header line |
| Body that is not JSON | `-32700`, `id: null` |
| JSON that is not a request | ignored (the server has no outstanding requests) |
| Unknown request method | `-32601` |
| Request before `initialize` | `-32002` |
| Request after `shutdown` | `-32600` |
| Notification the server does not know | ignored, as the specification requires |

A frame that carried no length cannot be bounded, so bytes after it are unattributable; the
server drops them and continues from the next `Content-Length` header. There is no input —
truncated, oversized, mistyped — that terminates the process before `exit`.

## Limits, stated plainly

- One file per check, plus the runtime and standard library that `grail check` always
  includes. Project modules (`grail.pkg` dependencies, sibling modules under `use`) are not
  part of the compilation, so a program is checked as if its other modules were absent.
- Diagnostics are push-only, computed synchronously per change (no debounce, no background
  checking, no cancellation), and only the first compiler error is available.
- No configuration, no `workspace/configuration`, no `workspaceFolders`, no watch events.
- Nothing is cached across buffers: each change writes a scratch tree and runs the compiler.

## Tests

`bun tools/lsp-test.mjs` (also `just lsp-test`) builds the compiler and the server from this
tree and drives a real stdio session:

- the handshake, and that unsupported capabilities are absent from the result;
- a buffer with a deliberate error publishes the compiler's diagnostic at the expected line
  and character with severity Error, and a fixed buffer publishes `[]`;
- a second error at a different line proves the mapping is not pinned to line 1;
- malformed framing, a malformed length and malformed JSON each get `-32700`, and the
  session still produces diagnostics afterwards;
- definition resolves a call to a same-file function, a local use, a use before its own
  `return`, and a parameter, and answers `null` for an undeclared name and for a position
  outside any name;
- `shutdown`/`exit` leave the server with exit status 0 and an empty stderr.

## Why this is a program, not a `grail lsp` subcommand

A subcommand of the `grail` binary is the natural home for this server, and it was the first
design considered. It was rejected for one measurable reason: the server's JSON reader is
`lib/json.grl`, which needs `lib/core.grl` and the map module `lib/hashmap.grl` (+ `lib/hash.grl`)
to compile, so a `use json;` inside the compiler would put all four standard-library modules
into the compiler binary and, through
`compilerSources`, into every checked-in bootstrap seed. Those seeds are ~20 MB of assembly
per target and are what gate `bun tools/ci.mjs build`; growing them for a tool that is not
part of the language is not a trade worth making. Keeping the server a program also keeps
the compiler's source set — and therefore the seed digests — untouched.

If the compiler ever grows a machine-readable diagnostics interface (`grail check --json`,
described in the plan document), the protocol layer here can move behind a
`grail lsp` subcommand without dragging the JSON library in.

The plan for the remaining language-server work — a machine-readable compiler surface,
hover, symbols, formatting and pull diagnostics — is in
[lsp-debugger-profiler.md](lsp-debugger-profiler.md).
