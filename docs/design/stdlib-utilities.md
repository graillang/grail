# Files, processes, time zones and validated text

The standard library's utility surface: what each module promises, what it refuses, and where the
platform layer ends and the library begins. The modules are `lib/fs.grl`, `lib/process.grl`,
`lib/tz.grl` and `lib/utf8.grl`; the runtime operations they rest on are in `compiler/runtime.grl`
(the portable half) and `compiler/os-linux.grl`, `compiler/os-windows.grl`, `compiler/darwin.grl`
(the platform halves).

## The error model

`fs::Error` is a path and an `io::Error`: `tree/one.txt: not found`. `process::Error` is a program
name and an `io::Error`. `tz::Error` is a zone name and a reason. Every fallible operation answers one
of those instead of stopping the program, `?` propagates it inside a library, and a caller that wants
to distinguish cases matches on `kind` (`NotFound` from the operating system, `InvalidUtf8(offset)`
from the text check, `ShortWrite(count)` from a write the platform accepted only partly).
`io::Error` therefore grew the two failures that are not operating-system errors but belong in the
same vocabulary.

Nothing is silently ignored. A directory whose metadata cannot be read is an error, not an empty
listing; a `File` closed twice is `EBADF`, not a no-op; a capture that hit its cap says so.

## The runtime boundary

A host operation's byte argument belongs to the host function, which releases it - the same contract
`host::open` and `host::list_dir` already followed. `stat`, `rename` and `symlink` follow it too. The
alternative does not merely leak: the entry sequence's exit-time allocation check aborts the process
with status 134 after the program has finished its work, which is how the omission was found.

| operation | POSIX | Windows |
| --- | --- | --- |
| `stat(path, follow)` | newfstatat, `AT_SYMLINK_NOFOLLOW` when not following | GetFileAttributesExA (no POSIX mode, owner or inode: 0) |
| `rename(from, to)` | renameat | MoveFileExA with MOVEFILE_REPLACE_EXISTING |
| `symlink(target, link)` | symlinkat | CreateSymbolicLinkA |
| `spawn(argv, env, out, err)` | fork, dup3, execve - no allocation in the child | CreateProcessA with STARTF_USESTDHANDLES |
| `wait(pid)` | wait4, the raw status word | WaitForSingleObject + GetExitCodeProcess, `code << 8` |
| `ready(fd, ms)` | ppoll (the generic ABI has no poll) | WaitForSingleObject on the pipe |
| `cwd()` | /proc/self/cwd | GetCurrentDirectoryA |

The status word a platform reports is `code << 8` for an exit and the signal number in the low bits
when one ended the child; `process::describe` is the single decoder, and Windows (which has no
signals) always reports an exit.

## The file-system walk

`walk` is depth first in byte order. A symbolic link is an entry of its own, reported as `Symlink`;
following one is the caller's choice (`follow_links`), and a link that cannot be followed is reported
and left alone. Cycles are impossible in two ways: a directory whose device and inode repeat one
already on the path is not entered again, and `max_depth` (32 by default) bounds what a platform
without inodes can reach. A tree's `remove_dir_all` never follows a link out of the tree.

Two policies are documented where they matter rather than left to the reader: `rename` replaces a
destination file atomically and refuses a non-empty destination directory, and `copy` creates or
truncates its destination and copies regular files only. `write_atomic` is `write` to a temporary
name beside the destination followed by `rename`.

## Time zones

`TimeZone` is a TZif table: transition instants, one type index per transition, local-time types with
their offsets and abbreviations, and the POSIX `TZ` footer. Version 2 and 3 files are read through
their 64-bit table; a footer rule governs times after the last recorded transition, and that rule can
leave a gap as well as an overlap, so `from_local` checks both. Leap-second records are read past:
`time::Timestamp` counts POSIX seconds, and the two would otherwise disagree.

The ambiguity is data, not a policy: `Unique(instant)`, `Ambiguous(earlier, later)` or
`Skipped(gap start, gap seconds)`. A caller that does not care asks `Resolution::instant`, which takes
the earlier instant of an overlap and answers `None` for a gap - one line, at the one place that
decided.

## Validated text

`Utf8String` states "valid UTF-8" once. Construction is checked (`from_bytes`), given by the language
(`from_text`) or `unsafe` (`from_unchecked`); `concat`, `slice_chars`, `replace` and the ASCII case
maps preserve it by construction, `to_upper`/`to_lower` refuse text above U+007F instead of
half-mapping, and `chars` never has to substitute U+FFFD because there is nothing to substitute.
`as_bytes` and `from_bytes` are the two directions of the interop with the byte-slice string, and
neither copies twice.

The invariant is proved by `utf8-fuzz-construction-invariant`: 10,000 seeded mutations of a valid
string, every accepted value re-validated through the checked constructor, every refusal's offset
inside the bytes it was handed.
