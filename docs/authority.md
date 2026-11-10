# Operating-system authority

Grail's OS interface is `host::`: `read_file`, `write_file`, `command`, `tcp_connect`, `env`,
`arg` and the rest. Any module that declares `use host;` can call it, anywhere the process can
reach. That is ambient authority: a function's signature says nothing about the OS work it will
do.

`lib/authority.grl` makes that access a value. An `Authority` is an ordinary owned record with
private fields and methods - not a compiler intrinsic - that carries one explicit grant:

| Constructor | Grants |
| --- | --- |
| `authority::open_read(root)` | read files under `root` |
| `authority::open_write(root)` | write files under `root` |
| `authority::open(root)` | read and write under `root` |
| `authority::process()` | spawn processes |
| `authority::sockets()` | open sockets |

The gated operations take the value and enforce it:

| Operation | Capability | Failure |
| --- | --- | --- |
| `authority::read_file(&a, path)` | read under the root | `Denied` or `Io(io::Error)` |
| `authority::write_file(&a, path, data)` | write under the root | `Denied` or `Io(io::Error)` |
| `authority::spawn(&a, argv)` | spawn | `Denied`; returns the exit status |
| `authority::spawn_with(&a, argv, env)` | spawn | `Denied`; returns the exit status |
| `authority::connect(&a, host, port)`, `listen`, `port`, `close` | sockets | `Denied` or `Io(io::Error)` |

`can_read`, `can_write`, `can_spawn` and `can_connect` report what a value grants, and `root`
returns the normalised root. `authority::Error` has `show()` and carries the OS error unchanged,
so a missing file is `not found` while a path outside the grant is `denied by authority`.

```grl
a := authority::open_read("/data")!;
data := authority::read_file(&a, "reports/q3.txt")!;  // reads /data/reports/q3.txt
match authority::read_file(&a, "../etc/passwd") {
    e: authority::Error => { /* denied by authority */ },
    _ => {}
}
```

## What containment means

`authority::contains(root, path)` is the whole rule, and it is lexical:

- Both `/` and `\` are separators on every platform. A Linux file name may legally contain a
  backslash; refusing it is conservative, never permissive.
- `.` components disappear and empty components collapse, so `/data//./x` is `/data/x`.
- `..` removes the previous component. A `..` with nothing left to remove is `Denied`, so a
  normalised path can never climb above its starting point.
- Containment compares whole components, not string prefixes: `/database` is not under `/data`.
- An absolute path needs an absolute root and must be inside it. A relative path is relative to
  the root, and is refused if it climbs out.
- A root of `/` is an explicit full-filesystem grant. `authority::open_read(".")` stores an empty
  root, which means the process working directory.
- A Windows drive letter is an absolute first component that `..` cannot remove. Drive-relative
  spellings such as `C:name` are treated as `C:/name`; Grail never changes the working directory,
  so the difference is not observable in a Grail program.

The check and the operation use the same resolved path: `read_file` and `write_file` pass the
normalised, root-joined path to `fs::read`/`fs::write`, so a relative path cannot silently read
from the working directory instead of the root.

## The compiler switch

`--deny-ambient-host` turns any reference to `host::` in a module that has not opted in into a
compile error:

```text
$ grail --deny-ambient-host out.s main.grl
main.grl:3:28: ambient host access is denied: add `use host;` to this module or call the gated
authority:: functions (--deny-ambient-host) at byte 123 near '('
```

The opt-in is the module-level declaration the language already has: `use host;` (or
`use host::read_file;`). Grail has no attribute syntax, so this reuses an existing declaration
rather than inventing one. `lib/authority.grl` is the only standard-library module that opts in,
so a program that uses `authority::` needs no ambient access at all:

```text
$ grail build --deny-ambient-host     # grail check and grail test forward it too
```

The switch covers calls, function values (`f := host::read_file;`) and constants, because it
sits where a qualified reference is resolved. A generic body is compiled in a replay pass after
every module has been read, so the compiler remembers each module's opt-in and checks a generic
against the module that defines it, not the module that calls it. Ambient `host::` remains the
default when the switch is absent, so existing programs are unaffected.

### What the switch enforces

- Every `host::name` reference in a module whose `use` lines do not name `host` is rejected with
  the diagnostic above, in every compilation pass.
- The rejection is a normal compile error: exit status 1 and the previous output file is left
  untouched.

### What it cannot enforce

- It is per module, not per call. `use host;` opts the whole module in; there is no per-call
  approval and no attenuation.
- `extern "C"` declarations are a separate route to the same OS calls. A module can declare
  `open`/`read`/`write` itself, and the gate says nothing about it.
- Compiler builtins (`print`, `println`, `assert`, `format`) are not `host::` references.
- It says nothing about *values*: a `u64` file descriptor can be passed around freely, and the
  gated functions cannot tell where it came from.

## Honest limits of the model

- **Symlinks are not resolved.** Containment is lexical. A symlink or hard link inside the root
  that points outside it passes the check, because resolving it needs an OS call the model does
  not have. The check is also not atomic with the open: a path can be swapped between the two
  (TOCTOU).
- **Spawn grants the whole process.** `authority::spawn` and `authority::spawn_with` bound
  *whether* a process is created, not what it may do: a child inherits the parent's full ambient
  authority, runs as the same user, in the same working directory, and `spawn_with` only decides
  what the child starts with. Nothing checks the program, the argument vector or the individual
  environment entries. The child's own reads of its environment - and of anything else - are
  outside the model entirely.
- **Composing an environment.** `spawn_with` takes the child's *complete* environment, so a caller
  that wants to add one variable must start from what it inherits. `authority::environment()`
  returns this process's entries for exactly that; reading your own environment is not gated,
  because every grant already implies the process can see its own configuration.
- **Sockets are gated at open, not at I/O.** `connect`, `listen`, `port` and `close` are gated;
  reading and writing the descriptor still uses `host::read_fd`/`host::write_fd`, so a program
  under `--deny-ambient-host` that needs socket I/O still opts in with `use host;`.
- **Remaining ambient paths**: `host::env`, `host::environment`, `host::command`,
  `host::command_with`, `host::arg`, `host::exe_path`, `host::now_ms`, `host::sleep_ms`,
  `host::exit`, `host::remove`, `host::mkdir`, `host::list_dir`, `host::open`, `host::read_fd`,
  `host::write_fd`, `host::tcp_accept`, and the `fs`, `env`, `process` modules built on them are
  still reachable with `use host;` (or through `fs::`, which opts in itself).
  The model does not remove ambient authority; it gives a checked route and a switch that makes
  the ambient one visible.
- **No runtime enforcement.** An `Authority` is a checked convention for code that goes through
  `authority::`. Nothing stops a module from opting in and calling `host::` directly.

## Tests

`bun tools/test-authority.mjs` (also `just test-authority`, and part of `bun tools/ci.mjs test
--full` on linux-x86_64) runs:

- 57 containment/normalisation cases: `..` escapes, absolute versus relative paths, component
  boundaries, drive letters, both separators, root normalisation, and the grant's stored root;
- a gated read/write round trip in a scratch directory, including refused escapes, a read-only
  grant, a narrower root, an OS error versus a denial, a gated spawn, a gated spawn with an
  explicit environment (refused for a file grant exactly as a plain spawn is), and a
  listen/connect/close socket cycle;
- the compiler switch: a direct `host::read_file` compiles by default and is rejected under
  `--deny-ambient-host`, the same call compiles after `use host;`, a generic body is checked
  against its defining module, the gated route compiles with and without the switch, and
  `grail check --deny-ambient-host` forwards it.
