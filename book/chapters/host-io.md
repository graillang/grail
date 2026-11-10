# Arguments, files and commands

A `main` entry may take one readonly byte view, spelled `&[u8]`, for exactly one command-line
argument. The manifest supplies `grail` when verifying this example.

{{example:arguments}}

The native entry shim rejects the wrong argument count with OS status 2. More general host
access is explicit through `host`. File byte buffers remain owned values:

{{example:files}}

The runner creates `note.txt` containing `Grail` and a newline in this example's scratch directory.
It verifies that `copy.txt` contains the same bytes. It never writes those names into your project
root. `&"note.txt"` is a readonly view of the literal. The low-level host interface is not a rich
error-handling library; for example, file-read failures abort in the current native runtime rather
than returning a typed error union.

{{example:commands}}

Commands receive an argument vector, not shell syntax. `host::command` consumes that vector and
returns a process status; this example executes `/bin/true`. Do not pass untrusted input to a
shell you explicitly choose to launch.

**Try it:** change the input fixture text in `book/book.json`, update the expected output and file,
then run `just book-check` to see the checks catch a mismatch.

## Capabilities instead of ambient access

`host::` is ambient: any module that declares `use host;` can read, write, spawn and connect
anywhere the process can. The standard library's `authority` module turns that into a value. An
`Authority` is an ordinary owned record holding one explicit grant, and the gated functions
enforce it:

{{example:authority}}

`authority::open_read(root)`, `open_write(root)`, `open(root)`, `process()` and `sockets()`
create grants; `authority::read_file`, `write_file`, `spawn`, `connect`, `listen`, `port` and
`close` use them. Containment is decided component by component after normalising `.`, `..` and
duplicate separators, so `/database` is not under `/data` and `/data/../etc/passwd` is refused
before the operating system sees it. `can_read`, `can_write`, `can_spawn` and `can_connect`
report what a value grants, and `authority::Error` keeps an OS error (`not found`) distinct from
a denial (`denied by authority`).

Compiling with `--deny-ambient-host` makes every direct `host::` reference an error unless that
module opts in with `use host;`. The standard-library `authority` module is the only module that
opts in, so a program written against it needs no ambient access; without the switch, ambient
`host::` stays the default. The repository's `docs/authority.md` states the containment rule and
the paths the check does not cover.
