# Grail in an editor

`.grl` files get syntax highlighting and the language server's features in VS Code (and in any
editor that reads TextMate grammars):

- `vscode/` — the VS Code extension: language id `grail`, extension `.grl`, the TextMate grammar,
  a language configuration for comments/brackets/indentation, and a client for
  `tools/lsp/main.grl`.
- `vscode/syntaxes/grail.tmLanguage.json` — the grammar on its own, scope name `source.grail`, for
  editors that take a `.tmLanguage.json` file directly.

`bun tools/grammar-test.mjs` checks the grammar (see [Verifying](#verifying)).

## What is highlighted

Declarations and their names (`fn`, `struct`, `enum`, `interface`, `impl`, `handle`, `record`,
`type`, `module`, `use`, `const`, `extern`), `pub` and `mut`, the control keywords (`if`, `else`,
`while`, `loop`, `for`, `in`, `match`, `return`, `break`, `continue`, `unsafe`, `let`), `self` and
`Self`, the built-in types (`u8`..`u64`, `i8`..`i64`, `f32`, `f64`, `bool`, `char`, `string`,
`unit`, `CStr`, `CPtr`, `CMutPtr`, `Fn`, `FnMut`, …), string and character literals with their
escapes, numeric literals in every form the lexer accepts (`0x3FF`, `0b1010`, `1_000`, `65533u32`,
`0u64`, `3.0e38`, `5f32`), `//` comments, and the operators — `->`, `=>`, `::`, `|?`, `:=`, `..`,
`**`, `&&`, `||`, the compound assignments and the single-character ones.

Grail-specific forms have their own scopes:

| Form | Scope |
| --- | --- |
| `@if`, `@for`, `@assert`, `@embed`, `@name(...)`, `@expr` and any other `@` form (`<@k: u64>`, `x.@f`) | `meta.attribute.grail` |
| lifetime parameters and names (`<a>`, `<a, b>`, `&a T`, `&a mut T`, `&a [u8]`) | `storage.modifier.lifetime.grail` |
| `extern "C" lib "vulkan" fn …` | `meta.extern.grail`, with `lib` as `keyword.other.lib.grail` |
| closure heads (`\|x: u64\| -> u64 {`, `\|\|`, `\|x\|`) | `meta.function.closure.grail`, parameters `variable.parameter.grail` |
| a function name after `fn`, and a name called as a function | `entity.name.function.grail` |
| a type name (declared, or written in upper case as Grail style does) | `entity.name.type.grail` |
| a field after `.` | `variable.other.property.grail` |

The grammar is a highlighter, not a checker: it has no scope beyond one line, so an upper-case
identifier is shown as a type even when it is a constant, and a method call is shown like a
function call (`x.method(` gets `entity.name.function.grail`, the `.` stays a period). Anything
that needs the name to be resolved is the language server's job.

## Installing in VS Code

Link the directory into the extensions folder, so edits to the grammar take effect on reload:

```sh
ln -s "$(pwd)/editors/vscode" ~/.vscode/extensions/grail-editors
```

Or package it and install the archive, which is what you hand to someone else:

```sh
cd editors/vscode && npx @vscode/vsce package    # writes grail-0.1.0.vsix
code --install-extension editors/vscode/grail-0.1.0.vsix
```

Either way, reload the window afterwards (Command Palette → *Developer: Reload Window*). A copy
instead of a symlink works too: VS Code loads any directory under `~/.vscode/extensions` that holds
a `package.json`.

The extension has no runtime dependencies: `extension.js` speaks the language server protocol to
the server's stdin/stdout directly (`lib/rpc.js`), because the server advertises full-text
synchronisation and definition and nothing else.

## Pointing the client at the server

The server is the Grail program `tools/lsp/main.grl`; [docs/tooling/lsp.md](../docs/tooling/lsp.md)
documents it, and the documented way to start it in a checkout is:

```sh
bun tools/lsp.mjs            # builds (cached by source digest) and serves on stdio
```

The extension runs exactly that by default, so a checkout needs no configuration:

| Setting | Default | Meaning |
| --- | --- | --- |
| `grail.server.path` | `bun` | the program to run |
| `grail.server.args` | `["tools/lsp.mjs"]` | its arguments |
| `grail.server.cwd` | `""` — the first workspace folder | where it runs |

The first start builds the server and the compiler it checks with, which takes a while; the
**Grail language server** output channel (*Grail: Show Language Server Output*) shows the build and
every message the server sends. If your Grail installation ships a `grail lsp` subcommand later,
set `grail.server.path` to `grail` and `grail.server.args` to `["lsp"]`; any other executable that
speaks the protocol on stdio works too.

Diagnostics run `grail check` from the server, so it needs a compiler: the launcher passes the one
it built from this tree, and `GRAIL_LSP_COMPILER` (then `GRAIL_COMPILER`, then `grail` on `PATH`)
overrides it. Without one, the server reports that once through a notification instead of
publishing an invented error.

Open a `.grl` file inside the workspace folder and you get:

- highlighting, from the grammar;
- diagnostics — the compiler's own message for the first error, refreshed on every change, cleared
  when the buffer is fixed;
- *Go to Definition* (`F12`) to a same-file function, local, `for` binding or parameter.

Command Palette: *Grail: Restart Language Server*, *Grail: Show Language Server Output`.

## Other editors

The grammar is a plain TextMate grammar with scope name `source.grail`; nothing in it is
VS Code-specific. For Sublime Text, copy it next to a `.sublime-syntax`
wrapper or use `PackageDev`; for TextMate itself, drop
`vscode/syntaxes/grail.tmLanguage.json` into `~/Library/Application Support/TextMate/Bundles/`.
Editors that run a language server (Neovim, Emacs, Helix, Kate) start `bun tools/lsp.mjs` the same
way the VS Code setting does, and read the comment/bracket rules from
`vscode/language-configuration.json` or their own equivalents.

## Verifying

```sh
bun tools/grammar-test.mjs
```

It checks that the grammar is valid JSON, that every regex in it compiles in JavaScript (so an
editor on either regex engine highlights the same text), and that fixture lines — nearly all of
them verbatim lines from this tree — tokenize to the scopes claimed above. It uses the real
`vscode-textmate` + `vscode-oniguruma` engine when those packages are installed and always runs a
small self-contained matcher over the grammar's own top-level patterns, so the check works on a
machine with no packages at all. `bun tools/ci.mjs lint` runs it as one of the static checks.
