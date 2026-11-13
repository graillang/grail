# Packages: manifests, resolution, lockfiles and a registry

This note is the design for Grail's package manager, `grail add/remove/update/tree/fetch` and the build's use of a lockfile. It is written before the implementation and records every
decision the code depends on, including the ones taken without asking (section 10).

The premise is the one the rest of Grail follows: check as early and as locally as possible. A
package manager that resolves at build time, reads a shared mutable directory of unpacked
packages, or downloads while compiling is a machine that fails late and unrepeatably. So the
split of duties here is:

* `grail update` resolves (it is the only command that may change what the lock says),
* `grail fetch` makes the store contain exactly what the lock says, and
* `grail build` reads the lock, verifies what the store holds, and compiles. It never resolves
  and never touches the network.

`grail.toml` is the manifest, `grail.lock` is the resolution, the store is content addressed,
and the compiler learns nothing new: the package manager computes the module set and calls the
existing driver, which already accepts an entry file plus a module list.

## 1. Scope

In scope: manifests with dependencies (registry, path, git), semver requirements, a resolver
with one version per name, a lockfile, a content-addressed cache, a static git index as the
registry, and the CLI around them.

Out of scope, deliberately, in this version: feature flags/optional dependencies (the index
schema reserves room for them and the reader ignores unknown fields, so adding them later is
not a format break), build scripts/`build.grl`, workspaces (see 2.6), publishers (the CLI
only consumes an index; `git push` publishes), and signing beyond the sha256 checksums the
lock records (the existing signing tooling for release artifacts is a separate concern).

## 2. The manifest: `grail.toml`

A project is a directory holding `grail.toml`. `grail new NAME` writes one; `grail build`
without an explicit file requires one.

```toml
[package]
name = "demo"
version = "0.1.0"
grl-version = ">=0.1, <0.2"      # the compilers this package is written for
entry = "src/main.grl"           # optional; this is the default

[dependencies]
logging = "1.2"                                    # registry, caret by default
colors = { path = "../colors" }                    # path dependency
marks = { git = "https://example/marks.git", tag = "v2.0.0" }

[dev-dependencies]
testkit = "0.4"                                    # tests only
```

### 2.1 Keys

`[package]`:

| key | required | meaning |
| --- | --- | --- |
| `name` | yes | package name; the key dependencies use, and the default output name |
| `version` | yes | this package's own version, `MAJOR.MINOR.PATCH[-PRE][+BUILD]` |
| `grl-version` | no | a semver requirement the running compiler's version must satisfy |
| `entry` | no | the program's entry source; default `src/main.grl` |
| `description`, `license`, `repository` | no | metadata; recorded, not used for resolution |

`[dependencies]` and `[dev-dependencies]` map a *name* to either a requirement string (registry
source) or an inline table with exactly one source key and at most one pin:

* `path = "DIR"` — a directory holding its own `grail.toml`. Relative to this manifest.
* `git = "URL"` — a repository, optionally with `rev = "<commit>"`, `tag = "<tag>"` or
  `branch = "<branch>"`. At most one of the three; the default branch is only acceptable when
  the resolution is immediately locked (it is, from `grail add` on).

A registry dependency may add `version = "REQ"` instead of the bare string form. Nothing else
is accepted.

**Unknown keys and unknown tables are errors**, not warnings, with the key and its line. A
manifest is configuration a human typed; silently ignoring `[dev-dependecies]` would make a
test suite run against nothing. This is the same stance the TOML reader takes on syntax it
does not implement (2.3).

`[dev-dependencies]` are resolved and locked with everything else but only enter the module set
for `grail test` (and only for the root package — a dependency's dev-dependencies are never
resolved, exactly as in Cargo).

### 2.2 How packages are found

`grail build` looks for `grail.toml` in the working directory only. No walking up parent
directories: a build either runs in the package it belongs to or it is an error. `-f/--manifest
PATH` exists for tools that need to name one explicitly.

### 2.3 The TOML reader

There is no TOML library in the Grail standard library and adding a C dependency for a
configuration file is not worth it, so `compiler/pkg.grl` carries a reader for a *subset* and
refuses everything outside it by name and line. Accepted:

* comments (`#` to end of line), blank lines, CRLF or LF line endings;
* tables `[a.b]` (dotted names), one level of nesting used by this manifest and no more;
* keys that are bare (`name`, `dev-dependencies`, letters/digits/`_`/`-`) or basic-quoted
  (`"name"`), and dotted key paths on the left of `=` (`package.name = "x"`);
* values: basic strings with `\" \\ \n \t \r \uXXXX`, literal strings (`'...'`), integers
  (decimal only, optional `+`/`-`), booleans, arrays of any accepted value (with an optional
  trailing comma, as the spec allows), and inline tables `{ k = v, ... }` (no trailing comma,
  as the spec forbids).

Refused with an explicit message naming the construct and the line: floats, dates and times,
multi-line (`"""`/`'''`) strings, array-of-tables (`[[x]]`), dotted-array syntax, escaped
multi-line keys, and anything else the reader does not recognise. The reader never guesses.

The lockfile is JSON, not TOML (section 4), so the TOML writer only has to round-trip what
`grail add` writes: a `[section]` header, sorted `key = value` lines, inline tables for source
descriptors. Rewriting a manifest therefore reorders keys and drops comments; `grail add` only
rewrites the file when it actually changes something, and says when it did.

### 2.4 `grl-version`

Checked before anything else is resolved: the compiler compares its own version
(`native::version()`) against the requirement and refuses with both versions in the message. A
package whose `grl-version` does not match is a package whose diagnostics are meaningless here,
so this is an error, not a warning. Dependencies' `grl-version` are checked too — a dependency
that cannot compile is worth discovering before a 90-second build, not during it.

### 2.5 Versions and requirements

`VERSION := MAJOR "." MINOR "." PATCH ["-" PRE] ["+" BUILD]`, decimal, no leading zeros in the
numeric parts; `PRE` is dot-separated identifiers compared per semver 2.0.0 (numeric
identifiers numerically, and a pre-release sorts before its release).

Requirements are comma-separated comparator conjunctions; nothing else:

| written | means |
| --- | --- |
| `1.2.3` | `^1.2.3` — `>=1.2.3, <2.0.0` |
| `1.2` | `^1.2` — `>=1.2.0, <2.0.0` |
| `1` | `^1` — `>=1.0.0, <2.0.0` |
| `^1.2` | `>=1.2.0, <2.0.0` (`^0.2.3` → `>=0.2.3, <0.3.0`, `^0.0.3` → `=0.0.3`) |
| `~1.2.3` | `>=1.2.3, <1.3.0` (`~1.2` → `>=1.2.0, <1.3.0`, `~1` → `>=1.0.0, <2.0.0`) |
| `=1.2.3` | exactly `1.2.3` |
| `>=1.2, <1.5` | the intersection of comparators |
| `*` | any release (not a pre-release) |

A bare requirement never selects a pre-release: `1.2` does not match `1.3.0-alpha.1`, and
`=1.3.0-alpha.1` only matches that exact version. This is Cargo's rule and it is the one that
keeps an accidental alpha out of everyone's lockfile.

An empty requirement, an unknown operator, or a comparator with the wrong number of parts is an
error with the text and the offset.

### 2.6 Workspaces: not in this version

A workspace is a root `grail.toml` with `[workspace] members = [...]`, shared lockfile and
shared `target/`. It buys two things: one lock for many crates, and one build for their shared
dependencies. Grail already gets the second for free — the build cache
(`grail build --cache`) keys per module across the whole store, so two packages that depend on
`logging 1.2.0` compile it once whether or not they are in a workspace.

That leaves the shared lockfile, which costs: member requirements must unify against each other
(one version per name across the workspace), paths become relative to a root that is not the
manifest's directory, `grail test` has to learn to run per member, and `grail add` has to work
out which member it is in. Each of those is a place where a half-working workspace produces
*wrong* resolutions rather than missing ones. Since a multi-crate project can already be a
directory of packages that depend on each other with `path = "..."` — the same code, the same
unification, no new syntax — workspaces are postponed until the single-package path has real
users asking for them. The refusal is explicit: `[workspace]` in a manifest is an unknown-table
error whose message says workspaces are not implemented.

## 3. Resolution

### 3.1 One version per name

The resolution assigns exactly one version to each package name, and every requirement on that
name in the graph must be satisfied by it. This is Cargo's model, and for the same reason: a
module's identity in Grail is its *name* (`use logging;` names one module), so two versions of
`logging` in one program would be two modules with the same name. Since the compiler refuses two
modules with one name, the package manager must never produce that graph. The invariant is
therefore not a convenience — it is what makes the build expressible.

### 3.2 Why unification and not a SAT solver

Because a version solver's job is not to find *a* solution, it is to find *the* solution: the
same manifest must produce the same lockfile on every machine, forever, or the lock is not a
lock. SAT solvers answer "is there an assignment", and which assignment they return depends on
their internal heuristics and clause order; making them deterministic means pinning the
heuristic, at which point you have a hand-written resolver with extra indirection.

Full backtracking search also has a cost that is invisible until it hurts: with a few hundred
candidate versions the search space is genuinely large, and a user who asks for a version that
does not exist gets a slow failure instead of an immediate one.

So the resolver is the simple thing that is also predictable:

```
pending  := root requirements (normal deps, plus dev deps for the root when asked)
edges    := every requirement seen so far, with the package that stated it
chosen   := empty map name -> (version, source)

repeat at most MAX_ROUNDS (64):
    pick, deterministically, the first name in pending order that is "dirty"
    reqs  := all live edges to that name
    best  := the highest available version that satisfies every req in reqs
    if no such version: report the two requirements that cannot be met together and stop
    if best != chosen[name]:
        chosen[name] := best
        its own [dependencies] become edges; every name they touch becomes pending
until nothing is dirty
```

"Available versions" for a registry name are the index file's versions that are not yanked;
for a path or git source, it is the single version that source declares. A name required from
two different sources (say `path` here and `git` there) is an immediate error — there is no
unification between sources, because the tree would depend on which one you looked at.

Deterministic by construction: names are visited in the order their first requirement appeared
(which is manifest order, then dependency order), the choice is always the highest satisfying
version, and no hashing or iteration order of a map is consulted.

### 3.3 Failure modes, named

Unification without backtracking (Cargo calls this "the resolver gets one shot") can fail in two
directions, and both diagnostics are part of the design:

1. **A conflict.** `a` needs `log ^1.0`, `b` needs `log ^2.0`. There is no version satisfying
   both, and the message says exactly that, naming both requirers and both requirements:
   `error: no version of log satisfies both "b 1.0.0" (^2.0.0) and "a 1.0.0" (^1.0)`.
2. **A conflict that a lower choice would have avoided.** `a` needs `core ^1`, `b` needs
   `core >=1.0, <1.4`, and `core 1.5.0` exists. Highest-first picks 1.5.0 for `a` first,
   then finds `b` impossible; `core 1.3.0` would have satisfied everyone. The resolver does
   not retry, so it errors. The message says what it chose and what it wanted, and the
   documented remedy is one line in the manifest: pin `core = "=1.3.0"`, or narrow the
   requirement that pulled the newer version up.

   This is a real cost, accepted knowingly: it is the same cost Cargo pays in the "one shot"
   case, it only appears when two requirements' windows overlap below the highest release, and
   the alternative (a search) buys a rare success for a machine the user can no longer predict.
   If it turns out to bite, the place to fix it is one function (`select`), not the format.

Versions already in `grail.lock` are preferred when they still satisfy every requirement, so a
new dependency does not silently upgrade a working tree; `grail update NAME` deliberately
ignores the lock for that one name, and `grail update` ignores it for all.

### 3.4 Cyclic dependencies

Allowed. Grail modules may refer to each other in a cycle (the compiler resolves types across
modules), so the resolver does not treat a cycle as an error; it simply does not recurse into
a package it has already chosen. The lock records the cycle as edges, and `grail tree` marks
repeats with `(*)`.

## 4. `grail.lock`

JSON, one object, keys in a fixed order, packages sorted by name, dependency edges sorted by
name. The writer emits `\n` line endings, two-space indentation, no trailing whitespace, and a
final newline, so the same resolution is byte-identical on every machine and the file reviews
as a diff.

```json
{
  "lock": 1,
  "root": "demo",
  "packages": [
    {
      "name": "colors",
      "version": "0.2.1",
      "source": "path",
      "path": "../colors",
      "dependencies": []
    },
    {
      "name": "demo",
      "version": "0.1.0",
      "source": "root",
      "dependencies": [
        { "name": "colors", "version": "0.2.1" },
        { "name": "logging", "version": "1.2.0" }
      ]
    },
    {
      "name": "logging",
      "version": "1.2.0",
      "source": "registry",
      "index": "https://example/grail-index.git",
      "tarball": "<sha256 of the published tarball>",
      "checksum": "<tree digest of the unpacked package>",
      "dependencies": []
    },
    {
      "name": "marks",
      "version": "2.0.0",
      "source": "git",
      "url": "https://example/marks.git",
      "rev": "<40 lowercase hex>",
      "checksum": "<tree digest>",
      "dependencies": []
    }
  ]
}
```

* `lock` is the format version; a bump means an incompatible change and an old `grail` refuses
  it with a message naming both.
* `source` is one of `root`, `path`, `git`, `registry`.
* `path` is the dependency's path exactly as the manifest wrote it (forward slashes), never an
  absolute path: the lockfile must not encode where the machine keeps its checkouts.
* `git` pinning is always a commit (`rev`, 40 hex, lowercase) even when the manifest said `tag`
  or `branch`; the lock does not move when the tag does.
* `tarball` is the sha256 of the downloaded archive, copied from the index and verified against
  the bytes. `checksum` is the tree digest (4.1) of what the build actually compiles.
* `dependencies` are the resolved edges — the graph, not the requirements. Both requirer and
  requested name, with the version that was chosen.
* Dev dependencies of the root are ordinary entries; the `demo` node's edges include them. A
  package that is only reachable through dev edges is marked `"dev": true` so `grail build`
  can leave it out of the module set without re-deriving reachability.

`grail build`, `check`, `run` and `test` verify the lock against the manifest first: the
manifest's root requirements must all be present as edges of the `root` entry, every named
dependency must appear as a package, and the versions must satisfy the requirements. A mismatch
means the lock is stale, and the error says which requirement has no entry and to run
`grail update`. The lock is never silently rewritten by a build.

## 5. The store

### 5.1 Where it lives

| order | location |
| --- | --- |
| 1 | `$GRAIL_PKG_STORE` when set (tests, CI, hermetic builds) |
| 2 | `$GRAIL_HOME/cache/pkg` when `GRAIL_HOME` is set (a self-contained toolchain keeps its cache) |
| 3 | `$XDG_CACHE_HOME/grail/pkg` when `XDG_CACHE_HOME` is set |
| 4 | `$HOME/.cache/grail/pkg`, and `./.grail/cache` when even `HOME` is unset |

`GRAIL_HOME` comes second because it already means "the toolchain lives here"
(`runtime.grl`, `std/`), and a directory that fully describes a toolchain should be movable
with its cache. Nothing in the store is machine-specific; nothing in a project's directory is
written by the store, so two checkouts share one store and a store can be deleted at any time.

### 5.2 Layout and content addressing

```
<store>/
  src/<key>/            unpacked package trees, one directory per resolved source
  tar/<sha256>.tgz      downloaded registry archives, kept for offline re-extraction
  git/<url-digest>/     one clone per git URL
  index/<url-digest>/   one clone per registry index
```

`key` is the tarball's sha256 for a registry package and `git-<commit>` for a git package.
Both are names that cannot collide with a different tree, and both are known *before* anything
is written — which is what lets extraction be a plain "write files here" with no rename step
(the host interface has no rename) and lets a partially extracted tree be recognised as such
(a directory without its `done` marker is discarded on the next fetch).

`done` is an empty marker file written last, after the tree's digest is computed and matched
against the lock. `src/<key>` without `done` is never used.

### 5.3 The tree digest

`checksum` (and the marker check) is sha256 over the package tree in a canonical form:

```
for each regular file, ordered by its relative path with '/' separators, byte-wise:
    path "\n" decimal(byte length of content) "\n" content "\n"
```

`.git/` and nothing else is skipped; symlinks are refused (they would make the digest and the
build disagree about which bytes are compiled, and the compiler does not follow them anyway).
Modes are not hashed: a package's executable bits are not part of what compiles.

The digest is verified on every build for every package in the lock. That is O(bytes of
dependencies) per build, which for the sizes this is designed for (tens of small packages) is
milliseconds, and it is the check that turns "the store is a cache" into "the store is a cache
the build can trust". A mismatch names the package, the expected digest, the actual digest, and
the `grail fetch --force` that repairs it.

### 5.4 Git packages

`grail fetch` clones (or updates) `<store>/git/<url-digest>/` — a normal clone, so it can be
fetched incrementally — then materializes the pinned commit:

```
git -C <clone> archive --format=tar <rev>  |  tar -x -C <store>/src/git-<rev>
```

`git archive` and not a worktree checkout, because it is written to be reproducible (it honors
`.gitattributes export-ignore` and timestamps aside it is content only) and because it leaves
the clone usable by any number of concurrent builds without a shared HEAD. The clone is an
optimization, not a source of truth: the lock's `rev` is. `--offline` uses the clone if it
already has the commit and fails with "the network is needed to fetch <rev> of <url>" if not.

### 5.5 Registry packages

`grail fetch` downloads `tar/<tarball>.tgz` from the index-derived URL, verifies sha256 against
the lock's `tarball`, then extracts it into `src/<tarball>` stripping the leading
`<name>-<version>/` directory every entry shares (an archive without that single top directory
is refused as malformed), then verifies the tree digest against `checksum`. A checksum mismatch
deletes the partially extracted tree's `done` marker and refuses: the error is not a warning,
because a tarball that does not hash to the index's checksum is either a corrupted mirror or an
attack.

### 5.6 Offline

`--offline` (on `add`, `fetch`, `update`) forbids every `git` and `curl` invocation. Everything
that can be answered from the store still is: `update --offline` resolves against the index
clone and the git clones already present, and `build` is not affected at all because it never
networked in the first place. The error when the store cannot answer is explicit about what it
wanted and what would fix it:

```
error: --offline: the index for registry https://example/grail-index.git is not in the store
  run `grail update` without --offline to clone it
```

## 6. Registry protocol

A registry is a **git repository of plain files** — the static-index design crates.io uses, at
the scale a language in this state actually needs: no server, no API, no database, `git push`
to publish, `git log` to audit, and any HTTP host (or a USB stick, or a `file://` path) can
serve it.

### 6.1 Layout

```
<index>/
  config.json
  colors
  logging
  zz
  zz/very-long-names-are-bucketed
```

* `config.json` is one object: `{"dl": "<url template>"}`. The template may contain `{name}`
  and `{version}`, which are substituted exactly once each; a template with neither is refused
  by the client (it would hand every package the same URL).
* One file per package name, holding one JSON object per line, in version order, append-only.
* A name matching `[a-z][a-z0-9_-]{0,63}` is its own file at the root. A longer name is stored
  under `<first two chars>/<name>` so no directory grows without bound. (crates.io buckets by
  name length; two characters is simpler to implement and to describe, and the rule is
  deterministic from the name alone.) Uppercase letters, dots and leading digits are refused
  by both the index reader and `grail add`, so one name always has one spelling.

### 6.2 A version line

One object per line, no line breaks inside, sorted keys as written by the publisher:

```json
{"name":"logging","vers":"1.2.0","deps":[{"name":"core","req":"^1.0"}],"cksum":"<sha256>","yanked":false}
```

| field | required | meaning |
| --- | --- | --- |
| `name` | yes | must equal the file's name |
| `vers` | yes | a semver version, unique within the file |
| `deps` | yes | array of `{"name": ..., "req": ...}`, optionally `"kind": "dev"` (a dev-dependency of the published package is not resolved and is not recorded in the lock) |
| `cksum` | yes | sha256 of the tarball, 64 lowercase hex |
| `yanked` | no | `true` hides the version from new resolutions; an existing lock keeps it |

Unknown fields are ignored, so a future `features` or `links` field does not break old clients;
missing required fields are an error naming the file, the line and the field. A version line
whose `vers` is not unique in the file, or whose `name` disagrees with the file, makes the whole
index unusable rather than partially usable — a broken index is a publisher bug and copying it
into the store would spread it.

Lines are read in file order and the file order *is* the version order (append-only); the client
sorts by parsed version anyway, so a mis-ordered file is a cosmetic lint, not a resolver bug.

### 6.3 Tarballs

`<dl>` with `{name}` and `{version}` substituted points at a `.tar.gz` holding every entry
under a single `NAME-VERSION/` directory. Nothing else is required: no manifest inside beyond
the package's own `grail.toml` (which is what its requirements come from at publish time; at
*consume* time the index line is authoritative, so a package cannot claim one set of
dependencies in the index and another in its tarball).

`curl -fsSL -o <store>/tar/<cksum>.tgz <url>` — `-f` so an HTML error page is never parsed as
an archive, `-s -S` for a quiet success and a real message on failure, `-L` for mirrors.

### 6.4 Publishing is a commit

```sh
grail-owner: tar -czf logging-1.2.0.tar.gz logging-1.2.0/
grail-owner: sha256sum logging-1.2.0.tar.gz
grail-owner: # append one line to ./logging and git commit && git push
```

The design has no upload step for the same reason it has no server: whoever can push the index
is the registry, and a registry that wants to check artifacts can serve them from a directory it
controls and verify the same sha256 the client verifies.

## 7. CLI

```
grail add NAME[@REQ]              registry dependency, resolved and locked
grail add --path DIR [NAMES]      path dependency (name from DIR's manifest)
grail add --git URL [--rev R|--tag T|--branch B] [NAME]
grail remove NAME                 drop a dependency and re-resolve
grail update [NAME...]            re-resolve (all, or just these), then fetch
grail fetch [--force]             make the store hold exactly what the lock says
grail tree                        print the resolved graph
grail build|check|run|test        use the lock (no resolution, no network)
```

Behaviour details that matter:

* `grail add` writes the manifest, resolves, fetches, and writes the lock, in that order. If
  resolution fails the manifest is left as it was (it is written last before the lock, and the
  old text is restored on failure), so a failed `add` never leaves a project that will not
  build.
* `grail add NAME` with no requirement means `^` of the highest non-pre-release version in the
  store's index, written out explicitly (`logging = "1.2.0"`), so the manifest says what was
  meant rather than "latest".
* `grail remove NAME` re-resolves from scratch, so packages that only that dependency pulled in
  disappear from the lock.
* `grail update` preserves the lock for names that did not change *unless* a requirement forced
  a move; it is not "upgrade everything to the newest possible" — it re-resolves with the
  existing choices preferred, and `grail update NAME` prefers nothing for `NAME`.
* `grail tree` prints one line per package, depth-first, in the order the manifest states, with
  a repeat marked `(*)` and dev-only packages marked `(dev)`. It reads the lock: a tree you did
  not resolve is not worth printing.
* Exit codes: 0 success, 1 error (all of the above print `error: ...` on stderr-equivalent
  output), and nothing writes to a project directory the user did not ask to change except
  `grail.toml` and `grail.lock`.

## 8. Build integration

The package manager's whole contribution to a build is the **module set**: for each package in
the lock that the program actually reaches, every `*.grl` under that package's `src/`, minus
nothing (a library's `src/` may hold any modules it likes), in a deterministic order (packages
in lock order, files sorted by path within a package). The entry file comes from
`[package] entry` of the root. Those paths point into the store or into a path dependency, so
they are absolute (or relative to the root, for path dependencies) and need no new include-root
machinery — the compiler already takes every module file explicitly, exactly as `just book-run`
does. `cli.grl`'s `compile` is called with that list, unchanged.

Three cheap checks live here because they turn a downstream compiler error into a package
error:

1. **A module name defined twice** across the module set (two packages both shipping
   `module util;`) is refused with both files named. The compiler would also reject it, but as
   a duplicate-definition error against generated paths; naming the two packages is what the
   user needs.
2. **`grl-version`** of every package in the module set is checked (2.4).
3. **A missing `src/`** or a package with no `.grl` files at all is refused: it is a
   packaging bug, not an empty library.

Nothing about dependency *order* reaches the compiler: Grail's module resolution is by name, so
the package manager does not compute a topological order for compilation, only for display
(`grail tree`) and for the lock's edges. This is the deliberate "no new compiler-internal
dependency graph": the compiler stays a function from an entry file plus module files to an
object, and reproducibility lives in the module set and its checksums.

`grail test` adds the root's dev-dependencies to the module set; `grail build`, `check` and
`run` do not.

## 9. How this is tested

* `tools/pkg-test.mjs` — end to end, in the style of `tools/test-cli.mjs`: builds the compiler,
  then drives it in `.work/pkg-tests` with a store of its own (`GRAIL_PKG_STORE`), over
  `file://` git repositories and a local index repository it creates itself. Cases: `new`,
  `add --path`, `add --git --tag`, `add` from a local index, byte-identical lock after two
  resolutions, a version conflict (both requirements named), a checksum mismatch (tampered
  store tree and tampered tarball), an offline build and an offline `update`, `grail tree`,
  `grail remove`, a stale lock refused by `build`, and a `grl-version` refusal.
* `tests/native-cases.json` — the pure parts, one `pkg-` case per behaviour: the TOML subset
  (tables, quoted keys, arrays, inline tables, and refusals for `[[x]]`, floats, multi-line
  strings), version parsing and ordering (including pre-releases), requirement matching, the
  resolver's selection and its conflict message, and the tree digest of a fixed file set. These
  are compiled and run with `compiler/pkg.grl` as the module, so they need no store and no
  network.

## 10. Decisions taken here

Recorded so the coordinator can overturn any of them with one line's notice:

1. **Manifest is `grail.toml`.** The old three-line `grail.pkg` format (`name`/`entry`/`dep`
   lines) is deleted with its loader, `grail add NAME URL` and its `.grail/deps` checkout
   directory: two manifest formats is exactly the kind of half-thing this branch is meant to
   remove.
2. **Lockfile is JSON, not TOML.** The writer needs fixed key order and no comments; JSON gives
   that with a parser the index reader needs anyway, and the file is read by tools more often
   than by people past the first day.
3. **No workspaces** (2.6), **no features**, **no build scripts** in this version.
4. **`grail build` never resolves and never networks.** A missing lock or a stale one is an
   error naming `grail update`; a store that cannot satisfy the lock is an error naming
   `grail fetch`.
5. **The store is outside the project**, content addressed, and verified on every build.
6. **Registry = static git index + tarball URLs**, per-package files, `config.json` `dl`
   template, sha256 in the index line and the lock.
7. **`git archive | tar` materialization** for git packages (reproducible, clone-safe), rather
   than a shared worktree checkout.
8. **Unification with highest-first, one shot, no backtracking** (3.3), with the conflict
   diagnostic naming both requirements and the documented pin-based remedy.
9. **`install` is not kept as an alias for `fetch`**; `grail install NAME` was a stub and a
   different idea (installing a toolchain), and keeping the name for fetching dependencies would
   make the future command impossible to add.
