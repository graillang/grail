# `grail doc`: reference documentation from the sources

`grail doc` renders the documentation a source tree already carries: one HTML page per module, a
JSON index, and a searchable list of every declaration. It reads the sources; it does not need to
build them, and it never runs a program it documents.

```sh
grail doc                                  # lib/ -> docs/api/
grail doc --out build/api lib              # the same, somewhere else
grail doc --out build/api compiler         # any directory or .grl file
```

It prints one line when it is done (`grail doc: 29 modules, 582 declarations -> docs/api`) and
returns 1 only when it cannot write its output. A file it cannot make sense of is documented as far
as it can be, never fatal.

## What a doc comment is

Grail has no doc-comment syntax: the compiler drops every comment before a declaration exists, so
nothing in the language can carry one. The convention is therefore the one the standard library and
the compiler already write - **a `//` comment block directly above a declaration or a field** - and
`grail doc` reads it from the source text. The compiler is unchanged, so a comment costs nothing,
and `grail doc` prints the same documentation for the same bytes.

A block is the declaration's documentation when it is contiguous and sits directly above it; a
comment at the end of a line documents nothing. A block after `module NAME;` and before the first
declaration documents the module, not that first declaration.

## What it documents

- **Functions**: the signature as written (type parameters, parameters, result), the refinement
  clauses it carries (`where` on a parameter, `ensures` on the result), and the claims it makes
  (`@no_alloc`, `@no_panic`, `@strict`).
- **Records, enums and interfaces**: the fields or variants with their types and their own doc
  comments, and - for an interface - each method's signature.
- **Implementations** (`impl I for T`) and **aliases**.

`union` is not a declaration in Grail (a union is the structural `A | B` in a result type), so there
is no union section to generate. Interface implementations are listed as `impl` items, which is what
the language calls the relationship a `derives` attribute would name in another language.

## The output

| file | what it is |
|---|---|
| `index.html` | every module, and a search box over every declaration name (an inline script: the tree works from the file system, with no server) |
| `<module>.html` | one page per module: functions, then records and enums, then interfaces, then implementations, each with an anchor `<kind>-<name>` (`#fn-find`, `#struct-Entry`) |
| `index.json` | the same model, machine-readable: `{"schema": 1, "sources": ..., "modules": [{"name", "path", "page", "doc", "items": [{"kind", "name", "anchor", "line", "signature", "doc", "clauses", "effects", "members": [{"name", "type", "doc"}]}]}]}` |

Cross-references: an identifier in a doc body links to its declaration's page when **exactly one**
declaration in the tree has that name. A name two modules both declare (`len`, `map`) is left as
plain text, because linking it to whichever page came first would be a confident wrong answer.

Determinism is a requirement, because a generated tree is reviewed as a diff: files are sorted by
path, modules by name, declarations stay in source order, anchors are derived from the kind and the
name, and nothing depends on a clock or on directory-listing order. Generating twice from the same
sources produces byte-identical pages (`tools/test-cli.mjs` pins it).

The default output, `docs/api/`, is generated output and is not committed; pick any `--out` you like.
