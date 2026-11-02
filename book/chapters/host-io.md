# Arguments, files and commands

A `main` entry may take one readonly byte view for exactly one command-line argument.
The manifest supplies `grail` when verifying this example.

{{example:arguments}}

The native entry shim rejects the wrong argument count with OS status 2. More general host
access is explicit through `host`. File bytes remain owned values:

{{example:files}}

The runner creates `note.txt` containing `Grail` and a newline in this example's scratch directory.
It verifies that `copy.txt` contains the same bytes. It never writes those names into your project
root. The low-level host interface is not a rich error-handling library; for example, file-read failures
abort in the current native runtime rather than returning a typed `Result`.

{{example:commands}}

Commands receive an argument vector, not shell syntax. `host::command` consumes that vector and
returns a process status; this example executes `/bin/true`. Do not pass untrusted input to a
shell you explicitly choose to launch.

**Try it:** change the input fixture text in `book/book.json`, update the expected output and file,
then run `just book-check` to see the checks catch a mismatch.
