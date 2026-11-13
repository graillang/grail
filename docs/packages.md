# Packages

Grail's package manager: `grail.toml` manifests, semver resolution, `grail.lock`, a
content-addressed store and a static git index as the registry.
The design and its reasoning are in [design/package-manager.md](design/package-manager.md); this
page is the reference.

## Files

| file | written by | read by |
| --- | --- | --- |
| `grail.toml` | you, `grail new`, `grail add`, `grail remove` | everything |
| `grail.lock` | `grail update`, `grail add`, `grail remove` | `build`, `check`, `run`, `test`, `fetch`, `tree` |

A project is a directory holding `grail.toml`. `grail build` reads the manifest and the lock in
the working directory; it does not search parent directories.

## `grail.toml`

```toml
[package]
name = "demo"                 # required; [a-z][a-z0-9_-]{0,63}
version = "0.1.0"             # required; semver
grl-version = ">=0.1, <0.2"   # optional; the compilers this package supports
entry = "src/main.grl"        # optional; the default is src/main.grl
description = "..."           # optional metadata (also license, repository)

[dependencies]
logging = "1.2"                                    # registry, ^1.2.0
colors = { path = "../colors" }
marks = { git = "URL", rev = "COMMIT" }            # or tag = "...", branch = "..."
exact = { version = "=1.2.3" }                     # a registry dependency, spelled out

[dev-dependencies]
testkit = "0.4"               # tests only: `grail test` sees these, `grail build` does not

[registry]
index = "https://example/grail-index.git"          # or $GRAIL_REGISTRY
```

Unknown tables and unknown keys are errors with the key and the line, so a mistyped
`[dev-dependecies]` cannot silently do nothing. `[workspace]` is refused by name: workspaces are
not implemented (design note, section 2.6).

The TOML reader accepts a subset and refuses the rest explicitly: comments, `[a.b]` tables, bare
and quoted keys, dotted key paths, basic and literal strings, integers, booleans, single-line
arrays (trailing comma allowed) and inline tables (no trailing comma). Floats, dates, multi-line
strings and `[[array.of.tables]]` are refused.

### Version requirements

| written | selects |
| --- | --- |
| `1.2.3`, `1.2`, `1` | `^`: `>=1.2.3 <2.0.0` (`^0.2.3` is `>=0.2.3 <0.3.0`, `^0.0.3` is `=0.0.3`) |
| `^1.2` | same as a bare requirement |
| `~1.2.3`, `~1.2` | `>=1.2.3 <1.3.0` |
| `~1` | `>=1.0.0 <2.0.0` |
| `=1.2.3` | exactly that version |
| `>=1.0, <1.5` | the intersection of the comparators |
| `*` | any release |

A requirement only matches a pre-release when it names one (`=1.3.0-alpha.1`), so `1.2` never
selects `1.3.0-alpha.1`.

## Resolution

One version per package name, everywhere in the graph (module identity is the module *name*, so
two versions of one package would be two modules with the same name). The resolver picks the
highest version that satisfies every requirement on that name, preferring the versions already in
`grail.lock` when they still fit, and refuses rather than guesses when two requirements cannot be
met together:

```
error: no version of log satisfies all requirements:
  ^1.0 (from aaa 1.0.0)
  ^2.0 (from bbb 1.0.0)
available: 1.0.0, 2.0.0
```

It does not backtrack. A conflict that a lower choice would have avoided is reported the same way,
with the remedy in the message's terms: pin the version you meant (`core = "=1.3.0"`).

`grail update NAME` ignores the lock for that one name. `grail update` ignores it for all of them.
Yanked versions are hidden from new resolutions; a version already in the lock stays.

## `grail.lock`

JSON, format 1, deterministic byte for byte: keys in a fixed order, packages and edges sorted by
name, two-space indentation, LF, one final newline. `path` is the dependency's path as the manifest
wrote it, never absolute. `git` is always a commit id. Each fetched package carries the checksum of
its tree.

```json
{
  "lock": 1,
  "root": "demo",
  "packages": [
    {
      "name": "logging",
      "version": "1.2.0",
      "source": "registry",
      "index": "https://example/grail-index.git",
      "tarball": "<sha256 of the archive>",
      "checksum": "<sha256 of the unpacked tree>",
      "dependencies": [
        { "name": "core", "version": "1.0.0" }
      ]
    }
  ]
}
```

`source` is `root`, `path`, `git` or `registry`. A package reachable only through the root's dev
edges is marked `"dev": true`. Commit the lockfile.

## Commands

```
grail add NAME[@REQ]                 registry dependency; resolves, fetches and locks it
grail add --path DIR [NAME]          path dependency (name from DIR's manifest)
grail add --git URL [--rev R|--tag T|--branch B] [NAME]
grail remove NAME                    drop the requirement and re-resolve from scratch
grail update [NAME...]               re-resolve (all, or those names), then fetch
grail fetch [--force]                make the store hold exactly what the lock names
grail tree                           the resolved graph, depth-first, from the lock
grail build|check|run|test           use the lock: no resolution, no network
```

`--offline` (on `add`, `update` and `fetch`) forbids `git` and `curl`. Everything the store can
answer is still answered, and anything it cannot says what it wanted:

```
error: --offline: the package archive is not in the store and fetching it needs the network
```

`grail add` writes the manifest only after resolution succeeds, so a failed add leaves a project
that still builds. `grail fetch --force` re-extracts what the store already has — the repair for a
store that failed its checksum verification.

## The store

| order | location |
| --- | --- |
| 1 | `$GRAIL_PKG_STORE` |
| 2 | `$GRAIL_HOME/cache/pkg` |
| 3 | `$XDG_CACHE_HOME/grail/pkg` |
| 4 | `$HOME/.cache/grail/pkg` (`.grail/cache` when even `HOME` is unset) |

```
<store>/src/<key>/        unpacked package trees
<store>/src/<key>.done    the tree digest written when it was unpacked
<store>/tar/<sha256>.tgz  registry archives
<store>/git/<id>/         one clone per git URL
<store>/index/<id>/       one clone per registry index
```

`key` is the archive's sha256 for a registry package and `git-<commit>` for a git package: a name
that cannot collide with a different tree. Every build re-hashes each locked tree and compares it
with the lock; a mismatch stops the build and names both digests.

The tree digest is sha256 over, for each file in path order, `path`, newline, the file's byte
length, newline, its bytes, newline. `.git/` is skipped; symlinks are refused.

## Registry protocol

A registry is a git repository of files:

```
config.json          {"dl": "https://example/crates/{name}-{version}.tar.gz"}
logging              one JSON object per published version, append-only, version order
zz/zz-a-long-name    names longer than 64 characters live under their first two characters
```

A version line:

```json
{"name":"logging","vers":"1.2.0","deps":[{"name":"core","req":"^1.0"}],"cksum":"<sha256>","yanked":false}
```

`deps` may carry `"kind": "dev"`, which is ignored: a published package's dev-dependencies are not
part of using it. Unknown fields are ignored so the format can grow. A line whose `name` disagrees
with its file, or a missing required field, makes the index unusable rather than half-usable.

An archive is a `.tar.gz` with every entry under one `NAME-VERSION/` directory. To publish: append
the line, commit the index, upload the archive. The client verifies the `cksum` before unpacking
and refuses an archive that does not match it.

## Build integration

For every package the program reaches, the build receives every `.grl` under that package's `src/`,
plus the root package's own sources and the entry file. `grail test` additionally includes the
root's dev-dependencies. Three package-level checks run before the compiler sees the module list: a
module name defined by two packages, a `grl-version` this compiler does not satisfy, and a package
with no sources. Dependency order never reaches the compiler, because modules are resolved by name.

## Testing

`bun tools/pkg-test.mjs` builds a compiler and exercises all of the above end to end over local
`file://` git repositories and a local index, with a store of its own: path, git and registry
dependencies, byte-identical lockfiles, a conflict, offline mode, a stale lock, `grl-version`, a
tampered store, a lying index, `remove`, duplicate module names and `tree`. The pure parts (TOML,
semver, requirements, the resolver, the manifest, the lockfile JSON, SHA-256) are `pkg-*` cases in
`tests/native-cases.json`:

```sh
GRAIL_TEST_FILTER='pkg' bun tools/test-native.mjs x86_64
```
