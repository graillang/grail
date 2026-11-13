# Packages and dependencies

A program that uses another program's code does not take a copy of it; it names it. In Grail that
name is a *package*: a directory with a `grail.toml` manifest, a version, and modules under `src/`.

```toml
[package]
name = "demo"
version = "0.1.0"
grl-version = ">=0.1, <0.2"

[dependencies]
logging = "1.2"
colors = { path = "../colors" }
marks = { git = "https://example/marks.git", tag = "v2.0.0" }

[dev-dependencies]
testkit = "0.4"
```

`grail new` writes the `[package]` table for you. `grail add` writes the rest: it resolves the
dependency, fetches it, and records both in `grail.lock`.

```sh
grail add logging          # a registry package, at the highest version that fits "^1.2.0"
grail add --path ../colors # a directory next to this one
grail add --git URL --tag v2.0.0
grail update               # re-resolve everything, then fetch
grail fetch                # make the local store match the lock
grail tree                 # what the lock resolved to
grail remove logging
```

## One version per package name

A module's identity in Grail is its name: `use logging;` names one module. Two versions of
`logging` in one program would be two modules with the same name, which the compiler refuses. So
the resolver assigns exactly **one version per package name**, and every requirement on that name
in the whole graph must be satisfied by it. When they cannot all be satisfied at once, that is a
conflict, and the message names both sides:

```
error: no version of log satisfies all requirements:
  ^1.0 (from aaa 1.0.0)
  ^2.0 (from bbb 1.0.0)
available: 1.0.0, 2.0.0
```

Nothing is chosen behind your back: the highest version satisfying every requirement wins, and if
that choice turns out to block a requirement discovered later, the resolver reports it instead of
searching. You fix it with one line: pin the version you meant.

```toml
[dependencies]
core = "=1.3.0"
```

## The lockfile

`grail.lock` records the exact version of every package, where it came from (a registry entry, a
directory, or a git commit), the checksum of the bytes that will be compiled, and the resolved
edges between packages. It is written by `grail update` and by `grail add`, and it is the same
bytes for the same resolution on every machine — so a lockfile diff shows exactly what changed.

`grail build`, `check`, `run` and `test` *read* the lock. They do not resolve, and they never use
the network. If the manifest and the lock disagree, the build stops and says which dependency has
no entry:

```
error: dependency <missing> is not in grail.lock: run `grail update`
```

A package with no dependencies has nothing to lock, so a fresh `grail new` project builds without
a lockfile; add a dependency and the lock becomes mandatory.

## The store, and offline builds

Fetched packages live in one content-addressed store, outside any project — `$GRAIL_PKG_STORE`,
else `$GRAIL_HOME/cache/pkg`, else `$XDG_CACHE_HOME/grail/pkg`, else `~/.cache/grail/pkg`. Two
checkouts share it, and deleting it costs nothing but a download.

The store is verified, not trusted: every build hashes each locked package's tree and compares it
with the lock. A tree that no longer matches is refused, not compiled.

`--offline` keeps `add`, `update` and `fetch` away from the network. It still answers everything
the store can answer, and it says exactly what it could not:

```
error: --offline: the repository is not in the store and fetching it needs the network
```

`grail build` needs no flag: it never networked in the first place.

## Path, git and registry sources

A **path** dependency is a directory with its own `grail.toml`. Its version comes from that
manifest, it is not copied anywhere, and an edit to it is visible immediately — which is why path
dependencies belong to development and registry versions belong to releases.

A **git** dependency names a repository and, on the command line, one of `--rev`, `--tag` or
`--branch`. The lock records the *commit*, never the branch, so a moving tag cannot change a
build: `grail update` is what moves it, deliberately.

A **registry** dependency is a name and a version requirement. The registry is a git repository of
plain files — one file per package name, one JSON line per published version, holding the
requirement list and the tarball's sha256 — plus a `config.json` whose `dl` template says where
the archives live:

```json
{"name":"logging","vers":"1.2.0","deps":[{"name":"core","req":"^1.0"}],"cksum":"9f2c…","yanked":false}
```

Publishing is a commit: append the line, push the index, upload the archive. Nothing about that
needs a server, and the client verifies the same checksum whoever serves the bytes.

Which index a project uses is stated once, in the manifest:

```toml
[registry]
index = "https://example/grail-index.git"
```

## What the compiler sees

The package manager's whole contribution to a build is the module list. For each package the
program reaches, it passes every `.grl` under that package's `src/`, plus the root package's own
sources and the entry file — the same explicit list `grail build` has always taken. Dependency
*order* never reaches the compiler, because Grail resolves modules by name.

Three checks happen there rather than in the compiler, because the package manager can say
something more useful: a module name defined by two packages (it names both files), a package
whose `grl-version` this compiler does not satisfy (it names both versions), and a package with no
sources at all.

`grail test` is the one build that sees the root's `[dev-dependencies]`. A dependency's
dev-dependencies are never resolved: tests of a library are not part of using it.
