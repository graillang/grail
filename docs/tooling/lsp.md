# The Grail language server

`tools/lsp/main.grl` is a language server written in Grail. It speaks JSON-RPC 2.0 over
stdio with `Content-Length` framing, and it is the only language server in the tree:
`tools/lsp.mjs` is a three-line launcher that builds the Grail program from this tree and
hands it the parent's stdio. `tools/lsp/analysis.grl` is the part that reads a buffer and
answers questions about it.

```sh
bun tools/lsp.mjs            # build (cached by source digest) and serve on stdio
```

The launcher builds it the way `tools/native.mjs` builds the compiler and every other Grail program
the test harness builds: with the language's one set of modes, and no flags to select them.

## Editors

`editors/vscode/` is a VS Code extension for `.grl` files: a TextMate grammar (scope name
`source.grail`, so any grammar-based editor can use it) plus a client for this server. Its three
settings are the command above — `grail.server.path` (default `bun`), `grail.server.args` (default
`["tools/lsp.mjs"]`) and `grail.server.cwd` (default: the first workspace folder) — and it needs no
dependency beyond the editor. Installing it, pointing it at another server executable, and using
the grammar elsewhere are in [editors/README.md](../../editors/README.md).
`bun tools/grammar-test.mjs` checks the grammar itself.

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
| `textDocument/definition` | a declaration in the same document (`definitionProvider: true`) |
| `textDocument/hover` | the type or signature at a position (`hoverProvider: true`) |
| `textDocument/completion` | names, fields, variants and parameters, trigger characters `.` and `:` |
| `textDocument/rename`, `textDocument/prepareRename` | a sound rename across the open documents |
| `initialize`, `initialized`, `shutdown`, `exit` | the JSON-RPC lifecycle, with the states it implies |

Nothing else is claimed. `references`, `documentSymbol`, `formatting`, `signatureHelp`,
`codeAction`, pull diagnostics and semantic tokens are **not** advertised and answer `-32601`.

## Positions

The protocol's positions are 0-based lines of **UTF-16 code units**; the buffer is bytes. Every
position a request names is converted through the line it lands on (`utf16_offset`), and every
range the server publishes or edits is converted back (`utf16_prefix`). A line with non-ASCII
text therefore maps exactly: `é` is one code unit in two bytes, and an emoji is two code units in
four bytes, so on `    tag := "héllo 😀"; tail := 1;` the `tail` that starts at byte 27 is at
character 24 and is reported as `{line, character: 24}`. A position past the end of the document,
or a character past the end of its line, is `-32602`, never a clamp and never a crash.

## Reading a buffer

`tools/lsp/analysis.grl` is the reader: a lexer, the declarations it can see, the bindings in
scope, and the type of an expression. It is a source-reading approximation, not a compiler, so it
answers from what the open files declare and never guesses. Three rules follow from that:

- a name resolves to its declaration, and a local resolves to the nearest preceding binding of
  that name in an enclosing block **of the same function** — so a shadowed binding is never
  confused with the one it hides;
- a type, a field or a function that is not declared in this file or in another open document has
  no answer (`null`, or an empty completion list);
- a module named in full (`shapes::area`) is answered when `shapes` is another open document;
  when its source is not open, there is no answer and a rename is refused.

The scanner is the one deliberate divergence from `compiler/lexer.grl`. A buffer being typed is
often not lexable — an unterminated string literal, a half-typed character literal — and the strict
lexer asserts on those, which would end the server on a keystroke. The server's scanner consumes
every byte exactly once instead: an unclosed string ends at its line, an unclosed character literal
is punctuation, and the rest of the file is still read.

## Definition

`textDocument/definition` answers, from the same document:

- a call to a function declared in the file resolves to the name in its `fn` header, whether
  the declaration is above or below the call;
- a local use resolves to the nearest preceding declaration of that name in an enclosing
  block: `NAME :=`, `mut NAME =`, `NAME: T =`, a `for NAME` binding, or a parameter of the
  enclosing function header.

A name the file does not declare, a position outside any name, and a member (`x.field`), method
(`x.method()`) or module-qualified (`module::name`) position answer `null`: definition does not
cross documents.

## Hover

Markdown, in a `grail` code block, with the range of the identifier it describes:

- an identifier shows its type (`p: Point`), from the binding's annotation or from its
  initializer (`total := add(p.x, 3)` is `u64`), a literal its own type (`u64`, `f64`,
  `string`, and `char` for a non-ASCII character literal — an ASCII character literal is untyped
  and adopts its context, so it answers nothing);
- a call shows the callee's signature (`fn add(a: u64, b: u64) -> u64`), and the function's
  `///` documentation after it when the declaration has one;
- `value.field` shows `x: u64` and which record it belongs to; a method call shows its signature;
- a field written in a record literal (`Point { x: 1 }`) or a pattern shows the field's type;
- a record, enum, alias, constant or handle shows its declaration head (`struct Point { x: u64,
  y: u64 }`, `type Coord = Point`, `const LIMIT: u64`), and an enum variant shows
  `Word::Second(u64)`.

Byte `` ` `` and `&` notation is the source's own: a type is printed as the declaration wrote it
(`&a mut [u8]`), because reformatting it would be a second, unverified pretty-printer.

## Completion

`CompletionItem`s with a `kind`, a `detail` (the type or the signature) and a `sortText`, so an
editor lists parameters, locals, fields, functions and keywords in that order. The context decides
what is offered:

| Where | What |
| --- | --- |
| a bare prefix | keywords and built-in types, the bindings in scope (innermost binding of a name wins), and this file's functions, records, enums, aliases, constants and imports |
| after `.` | the fields of the receiver's record, then the `impl` methods whose receiver is that type |
| after `Type.` or `Type::` | an enum's variants, or the functions an `impl` attaches to the type |
| after `name(` | the parameters of that function or method |
| anywhere else | nothing rather than a guess: an unknown receiver, or an unknown module, answers an empty list |

The server filters by the exact prefix it is given; an editor's own fuzzy matching may show more.

## Rename

`textDocument/prepareRename` answers the identifier's range and its text as the placeholder, and
`textDocument/rename` answers a `WorkspaceEdit` (`changes`) of `TextEdit`s with the new name. Both
answer for:

- a local binding, a `for` binding and a parameter: the declaration plus every use that resolves
  to **that** binding, so a shadowing binding's uses are untouched;
- a module-level function, record, enum, type alias, constant or handle: the declaration, every
  unshadowed use in the defining document, and — in every other open document — a use written in
  full (`mathlib::helper`) or imported by name (`use mathlib::helper;` plus a bare use);
- a record field: its declaration, every `value.field` whose receiver's type is that record, and
  the field's label in a record literal or pattern. A field of the same name in another record is
  a different field and is left alone.

A string literal and a comment are never edited: only tokens are, so a name spelled inside
`"..."` or after `//` stays as it is.

Rename refuses, with `-32001` and a message that says why (`prepareRename` answers `null`):
a keyword, `self`, a built-in such as `println`, an `extern "C"` declaration whose name is the C
symbol, an enum variant (it belongs to its enum), a method (it is named at every call site of its
type), and a name in a module whose source is not open. A `newName` that is not an identifier is
`-32602`.

## Diagnostics come from the compiler

No diagnostic is invented here. For every change the server:

1. writes the buffer to `$TMPDIR/grail-lsp-<n>/<buffer-name>.grl`, where the name is the
   uri's last segment sanitised to `[A-Za-z0-9._-]`;
2. runs `grail check <buffer-name>` in that directory and reads the result back from a file
   in it, then removes every scratch file and directory;
3. parses the compiler's own diagnostic blocks and publishes them.

The compiler prints

```
error[E0002]: unknown function
 --> session.grl:2:5
  |
2 |     missing(1);
  |     ^^^^^^^
```

The `-->` line gives a 1-based line and a 1-based **byte** column; the carets under the excerpt
give the width, which the location alone does not. The server reads both, so the published range
covers the token the compiler underlined and is expressed in UTF-16 code units. A clean check
publishes `[]`, which is how a fixed buffer clears its squiggles; `didClose` publishes `[]` as well.
The message text is the compiler's own, unchanged.

The check runs under `sh -c` with both streams redirected to the scratch file: `host::command`
inherits this process's stdio and the runtime exposes no descriptor redirection, and the
server's stdout is the protocol channel. If `grail check` cannot be completed — a missing
compiler, a dead `sh`, a compiler that stops without a diagnostic — the server sends one
`window/showMessage` and publishes nothing, rather than reporting an error that the compiler
did not produce.

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
| Request without `params`, `textDocument` or `position` | `-32602` |
| Position outside the document | `-32602` |
| Rename of a name it will not rename | `-32001`, with the reason |
| Notification the server does not know | ignored, as the specification requires |

A frame that carried no length cannot be bounded, so bytes after it are unattributable; the
server drops them and continues from the next `Content-Length` header. There is no input —
truncated, oversized, mistyped, or a buffer that is halfway through a string literal — that
terminates the process before `exit`.

## Limits, stated plainly

- One file per check, plus the runtime and standard library that `grail check` always
  includes. Project modules (packages from `grail.toml`, sibling modules under `use`) are not
  part of the compilation, so a program is checked as if its other modules were absent.
- Diagnostics are push-only, computed synchronously per change (no debounce, no background
  checking, no cancellation), and only the first compiler error is available.
- Hover, completion and rename read the documents the editor has open. There is no on-disk
  index, no `workspace/symbol`, and nothing is read from a file that is not open; a rename is
  refused rather than guessed when the declaration is in a module whose source is not open.
- Types are inferred where a binding's initializer (or a loop's iterable) makes the answer
  certain, and not further: generics are only substituted when the receiver's arguments are
  written out, an ASCII character literal has no type of its own, and a call to a function whose
  source is not open answers nothing.
- No configuration, no `workspace/configuration`, no `workspaceFolders`, no watch events.
- Nothing is cached across buffers: each request re-reads the open documents, and each change
  writes a scratch tree and runs the compiler.

## Tests

`bun tools/lsp-test.mjs` (also `just lsp-test`) builds the compiler and the server from this
tree and drives a real stdio session:

- the handshake, and that the advertised capabilities are exactly the implemented ones;
- a buffer with a deliberate error publishes the compiler's diagnostic at the expected line
  and character with severity Error, and a fixed buffer publishes `[]`;
- a second error at a different line proves the mapping is not pinned to line 1;
- malformed framing, a malformed length and malformed JSON each get `-32700`, and the
  session still produces diagnostics afterwards;
- definition resolves a call to a same-file function, a local use, a use before its own
  `return`, and a parameter, and answers `null` for an undeclared name and for a position
  outside any name;
- hover answers a signature with its doc comment, a local's type, a field after `.`, a record
  literal's label, a literal, an enum variant, and a position after non-ASCII text with a
  UTF-16 range; and `null` for an undeclared name, a binding it cannot type and an empty line;
- completion answers locals, records, functions and keywords on a bare prefix with the right
  kinds, details and ordering, a record's fields and methods after `.`, an enum's variants
  after `Type.`, a call's parameters after `name(`, the innermost binding under shadowing, and
  an empty list for a receiver it cannot type;
- rename and prepareRename edit exactly a local's own uses (not a shadowing binding's), a
  parameter, a function, a record, a field (declaration, literal label and access, but not the
  same field name in another record), across two open documents, and refuse a keyword, a
  builtin and a module that is not open, with a `-32001` that says why;
- a buffer with an unterminated string or character literal still answers requests;
- `shutdown`/`exit` leave the server with exit status 0 and an empty stderr.

## Why this is a program, not a `grail lsp` subcommand

A subcommand of the `grail` binary is the natural home for this server, and it was the first
design considered. It was rejected for one measurable reason: the server's JSON reader is
`lib/json.grl`, which needs `lib/core.grl` and the map module `lib/hashmap.grl` (+ `lib/hash.grl`)
to compile, so a `use json;` inside the compiler would put all four standard-library modules
into the compiler binary and, through
`compilerSources`, into every checked-in bootstrap seed. Measured on x86-64, the compiler's
assembly grows from 31,214,769 to 31,960,736 bytes (+2.4%, one target of three) for a tool
that is not part of the language, and the seeds are what gate `bun tools/ci.mjs build`. That
is not a trade worth making. Keeping the server a program also keeps
the compiler's source set — and therefore the seed digests — untouched.

If the compiler ever grows a machine-readable diagnostics interface (`grail check --json`,
described in the plan document), the protocol layer here can move behind a
`grail lsp` subcommand without dragging the JSON library in.

The plan for the remaining language-server work — a machine-readable compiler surface,
references, symbols, formatting and pull diagnostics — is in
[lsp-debugger-profiler.md](lsp-debugger-profiler.md).
