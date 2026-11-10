# Grail-facing OS API design

2026-11-08. Status: **design only**. No `.grl` modules are added by this proposal, because the
compiler did not yet accept `extern "C"` declarations when this was written and a non-compiling
module under `lib/`
would break every build. The C contract in [runtime-abi.md](runtime-abi.md) and
`include/grail/` is the implemented part; this document fixes the surface those wrappers will
expose once the FFI increment lands.

> Premise update (2026-11-10): the FFI increment landed - `extern "C"` declarations, calls and
> callbacks are implemented and executed on six targets, and [docs/ffi.md](../ffi.md) is their
> contract. The layering below is still the plan for the OS wrappers, but the capability and error
> design must now be checked against the FFI that exists rather than the one that was anticipated
> ([B2](decisions-b2-b6.md#b2-ambient-host-authority-a-recorded-deviation), and correction 1 in
> [the decision record](decisions-b2-b6.md#corrections-to-earlier-documents)).

## Layers

```
application (safe Grail)
    lib/sys/{fs, process, net, time, env, path, unicode, error}.grl
        unsafe module sys::abi          // extern "C" declarations of include/grail/*
            native backend             // Linux Grail runtime, Windows, macOS
```

- `sys::abi` is the only module allowed to name handles, raw pointers, statuses or `unsafe`.
- `lib/sys/*` wrappers are safe, exhaustive and return `T |? sys::error::Error`; `?` propagates.
- The application never sees a platform descriptor, a negative status or a `void *`.
- The backend is chosen at build target selection, not at run time. There is no dynamic
  dispatch table in the ABI and no "portable" fallback that silently degrades semantics.

## Error type

```grl
module sys::error;

pub struct OsError { pub domain: u64, pub code: u64 }

pub enum Error {
    InvalidArgument, InvalidHandle, InvalidUtf8, NotFound, AccessDenied, AlreadyExists,
    NotADirectory, IsADirectory, DirectoryNotEmpty, NameTooLong, NoSpace, QuotaExceeded,
    ReadOnly, Busy, TimedOut, WouldBlock, Interrupted, ConnectionReset, ConnectionRefused,
    ConnectionAborted, NetworkUnreachable, AddressInUse, AddressInvalid, MessageTooLarge,
    Unsupported, NotInitialized, BrokenPipe, Canceled, Overflow, OutOfMemory,
    TooManyHandles, SymlinkLoop, CrossDevice, NotSeekable,
    System(OsError),
}

pub fn from_status(status: i64) -> Error;
impl Error {
    pub fn is_transient(self: (&Error)) -> bool;
    pub fn show(self: (&Error)) -> string;
}
```

`Error::System` is the only variant that carries the raw platform detail. It is produced for
`GRAIL_E_SYSTEM`; `is_transient` matches `WouldBlock`, `Interrupted`, `TimedOut` and `Busy`.
The mapping from the C statuses is one-to-one and lives in `sys::abi`; the safe enum deliberately
does not expose numeric values, so a future ABI can add statuses without changing user code.

## Conversion rules

| C ABI | Grail |
| --- | --- |
| `int64_t`, `uint64_t` | `i64`, `u64` |
| `grail_handle` | `handle Name;` opaque nominal type |
| `const uint8_t *, uint64_t` | `&[u8]` (expands to the pair at an `extern "C"` call) |
| `uint8_t *, uint64_t` | `&mut [u8]` |
| `T *` out-parameter on a POD record | `&mut T` where `T` is an `extern record` |
| `uint64_t (*)(void *)` | `extern "C" fn(void *) -> u64` |
| negative status | `Error` through `from_status` |
| length-or-error result | `usize`-style `u64` plus an explicit retry helper |

All ABI scalars are 64-bit, so no sub-word widening or truncation is part of the wrapper.
No ABI function returns a structure by value; the wrapper binds a local `extern record` and
passes `&mut local`.

## Handles and ownership

Handles are affine: exactly one successful closer consumes each value. The wrappers do not
implement an implicit destructor for opaque handles yet, because Grail has no checked destructor
implementation for an opaque handle type. The rule is therefore explicit:

- every `File`, `Dir`, `EnvIter`, `Child`, `TcpListener`, `TcpStream`, `UdpSocket`, `Thread`,
  `Mutex`, `Condvar` and `Library` value is closed on every normal and error path;
- `?` propagation cleans up owned values already created in the function, but a handle that was
  moved into a helper is that helper's responsibility;
- a leaked handle is reclaimed by the OS at process exit and is reported by the runtime's live
  handle accounting, not silently freed;
- double close, use after close and use after move are rejected by the wrapper API where the
  compiler can see them; the ABI additionally returns `InvalidHandle` rather than undefined
  behaviour.

Once the compiler supports a checked destructor for opaque resources, `File`/`Child`/`Socket`
can gain one; the C contract already defines the single closer, so the change is purely in the
wrapper.

## Files and directories

```grl
module sys::fs;
use sys::error::Error;

pub handle File;
pub handle Dir;

pub enum FileKind { Unknown, File, Directory, Symlink, Block, Character, Fifo, Socket }
pub struct Stat {
    pub kind: FileKind,
    pub size: u64,
    pub mode: u64,
    pub read_only: bool,
    pub hidden: bool,
    pub executable: bool,
    pub modified_ns: i64,
    pub accessed_ns: i64,
    pub created_ns: i64,
    pub link_count: u64,
    pub device: u64,
    pub inode: u64,
}
pub struct OpenOptions {
    pub read: bool,
    pub write: bool,
    pub create: bool,
    pub truncate: bool,
    pub append: bool,
    pub exclusive: bool,
    pub directory: bool,
    pub no_follow: bool,
    pub sync: bool,
    pub nonblocking: bool,
    pub mode: u64,
}
pub struct DirEntry { pub name: string, pub kind: FileKind, pub is_last: bool }

impl File {
    pub fn open(path: (&[u8]), options: (&OpenOptions)) -> File |? Error;
    pub fn read(self: (&mut File), buffer: (&mut [u8])) -> u64 |? Error;
    pub fn read_all(self: (&mut File)) -> u8[] |? Error;
    pub fn write(self: (&mut File), data: (&[u8])) -> u64 |? Error;
    pub fn write_all(self: (&mut File), data: (&[u8])) -> unit |? Error;
    pub fn seek(self: (&mut File), offset: i64, whence: SeekFrom) -> u64 |? Error;
    pub fn stat(self: (&File)) -> Stat |? Error;
    pub fn sync(self: (&File), data_only: bool) -> unit |? Error;
    pub fn set_nonblocking(self: (&File), enabled: bool) -> unit |? Error;
    pub fn close(self: File) -> unit |? Error;
}

pub fn stat(path: (&[u8]), follow_symlinks: bool) -> Stat |? Error;
pub fn mkdir(path: (&[u8]), parents: bool) -> unit |? Error;
pub fn remove_file(path: (&[u8])) -> unit |? Error;
pub fn remove_dir(path: (&[u8])) -> unit |? Error;
pub fn rename(from: (&[u8]), to: (&[u8]), replace: bool) -> unit |? Error;
pub fn read_link(path: (&[u8])) -> string |? Error;
pub fn real_path(path: (&[u8])) -> string |? Error;
pub fn open_dir(path: (&[u8])) -> Dir |? Error;
pub fn pipe() -> Pipe |? Error;

impl Dir {
    pub fn next(self: (&mut Dir)) -> DirEntry? |? Error;
    pub fn close(self: Dir) -> unit |? Error;
}
```

`read` returns 0 only at end of file; `read_all` owns the buffer and grows it. `write` may write
less than requested and returns the count; `write_all` loops. `Dir::next` returns `None` at the
end and never yields `.` or `..`; names have no trailing separator. `remove_dir` is empty-only;
recursive removal is deliberately not in the ABI (a caller can walk with `Dir`).

## Paths and Unicode

```grl
module sys::path;
pub fn is_absolute(path: (&[u8])) -> bool |? error::Error;
pub fn join(base: (&[u8]), child: (&[u8])) -> string |? error::Error;
pub fn parent(path: (&[u8])) -> string |? error::Error;
pub fn file_name(path: (&[u8])) -> string |? error::Error;
pub fn extension(path: (&[u8])) -> string |? error::Error;
pub fn normalize(path: (&[u8])) -> string |? error::Error;
pub fn current_directory() -> string |? error::Error;
pub fn set_current_directory(path: (&[u8])) -> unit |? error::Error;
pub fn executable() -> string |? error::Error;

module sys::unicode;
pub fn validate(text: (&[u8])) -> u64?;             // byte offset of the first invalid sequence
pub fn to_utf16(text: (&[u8])) -> u16[] |? error::Error;
pub fn from_utf16(units: (&[u16])) -> u8[] |? error::Error;
```

Paths are UTF-8 byte views with `/` as the canonical separator. `normalize` is lexical and does
not touch the file system; `real_path` resolves symlinks. Windows conversion, `\\?\` handling
and reserved-name policy are backend responsibilities (see `runtime/abi/README.md`); macOS
preserves the bytes the file system returns and does not normalize NFD.

## Environment

```grl
module sys::env;
pub struct Entry { pub name: string, pub value: string }
pub handle EnvIter;

pub fn get(name: (&[u8])) -> string? |? error::Error;
pub fn set(name: (&[u8]), value: (&[u8])) -> unit |? error::Error;
pub fn unset(name: (&[u8])) -> unit |? error::Error;
pub fn vars() -> EnvIter |? error::Error;
impl EnvIter {
    pub fn next(self: (&mut EnvIter)) -> Entry? |? error::Error;
    pub fn close(self: EnvIter) -> unit |? error::Error;
}
```

A missing name is `None`; a set-but-empty value is `Some("")`. This intentionally fixes the
current `env::var` behaviour, where an empty value is reported as unset. Iteration is a snapshot
taken at `vars()`, so mutation does not invalidate it.

## Time

```grl
module sys::time;
pub enum Clock { Monotonic, Realtime, ProcessCpu, ThreadCpu }
pub fn now(clock: Clock) -> i64 |? error::Error;
pub fn resolution(clock: Clock) -> i64 |? error::Error;
pub fn sleep(nanoseconds: i64) -> unit |? error::Error;
pub fn local_offset(utc_nanoseconds: i64) -> i64 |? error::Error;
```

`sleep` is the safe, task-aware operation: inside a green task it must suspend that task through
the runtime reactor; inside a native worker it may call the ABI's blocking sleep. The C ABI's
`grail_os_time_sleep` is the blocking primitive, not a license to block a reactor worker.

## Processes

```grl
module sys::process;
pub handle Child;
pub enum ExitKind { Exited, Signaled }
pub struct ExitStatus { pub kind: ExitKind, pub code: i64, pub signal: i64 }
pub struct Command {
    pub program: string,
    pub arguments: string[],
    pub working_directory: string?,
    pub environment: [string: string]?,
    pub replace_environment: bool,
    pub search_path: bool,
    pub new_group: bool,
}

pub fn spawn(command: Command) -> Child |? error::Error;
pub fn run(command: Command) -> ExitStatus |? error::Error;

impl Child {
    pub fn wait(self: (&mut Child)) -> ExitStatus |? error::Error;
    pub fn wait_timeout(self: (&mut Child), timeout_ns: i64) -> ExitStatus? |? error::Error;
    pub fn terminate(self: (&mut Child)) -> unit |? error::Error;
    pub fn kill(self: (&mut Child)) -> unit |? error::Error;
    pub fn id(self: (&Child)) -> u64 |? error::Error;
    pub fn close(self: Child) -> unit |? error::Error;
}
```

`Command` has no shell string; arguments are a vector, and the Windows backend applies the
normative MSVCRT quoting itself. `run` is spawn + wait + close. The first increment inherits
standard streams or uses the null device; explicit `Stdio` variants (pipe/inherit/null/file)
belong to the same family and are added with the pipe wiring, not by a second process API.

## Sockets

```grl
module sys::net;
pub handle TcpListener;
pub handle TcpStream;
pub handle UdpSocket;
pub enum Family { Inet, Inet6 }
pub struct Address { pub family: Family, pub port: u16, pub bytes: u8[] }
pub struct Connection { pub stream: TcpStream, pub peer: Address }

pub fn resolve(host: (&[u8]), family: Family) -> Address[] |? error::Error;
pub fn listen(address: (&Address), backlog: u64) -> TcpListener |? error::Error;
pub fn connect(address: (&Address)) -> TcpStream |? error::Error;
pub fn bind(address: (&Address)) -> UdpSocket |? error::Error;

impl TcpListener {
    pub fn accept(self: (&TcpListener)) -> Connection |? error::Error;
    pub fn local_address(self: (&TcpListener)) -> Address |? error::Error;
    pub fn set_nonblocking(self: (&TcpListener), enabled: bool) -> unit |? error::Error;
    pub fn close(self: TcpListener) -> unit |? error::Error;
}
impl TcpStream {
    pub fn read(self: (&mut TcpStream), buffer: (&mut [u8])) -> u64 |? error::Error;
    pub fn write(self: (&mut TcpStream), data: (&[u8])) -> u64 |? error::Error;
    pub fn peer_address(self: (&TcpStream)) -> Address |? error::Error;
    pub fn shutdown(self: (&TcpStream), how: Shutdown) -> unit |? error::Error;
    pub fn set_nonblocking(self: (&TcpStream), enabled: bool) -> unit |? error::Error;
    pub fn close(self: TcpStream) -> unit |? error::Error;
}
impl UdpSocket {
    pub fn send_to(self: (&UdpSocket), data: (&[u8]), peer: (&Address)) -> u64 |? error::Error;
    pub fn recv_from(self: (&UdpSocket), buffer: (&mut [u8])) -> Datagram |? error::Error;
    pub fn close(self: UdpSocket) -> unit |? error::Error;
}
```

The safe API is blocking; green tasks suspend in the runtime's reactor and never block a
worker. Readiness registration is not exposed. Unix-domain sockets are a later addition with a
separate address type, not a flag on this one.

## OS threads, synchronization and dynamic loading

`grail_thread.h` and `grail_dl.h` are **not** proposed as safe modules. They exist for the
runtime, FFI and tests:

- Safe Grail concurrency remains `parallel_map`, `Mutex<T>`, `Atomic<T>`, `task_scope` and
  `Task<R>`. Handing raw OS threads or mutexes to safe code would bypass `Send`/`Share`,
  structured joining and cancellation checks.
- `sys::dl` is an `unsafe module` because a symbol address is untyped. Loading a library and
  calling a symbol require an `extern "C"` declaration with the correct signature; a safe
  wrapper cannot invent one.
- The ABI mutex is a blocking OS mutex. The language-level `Mutex<T>` remains futex/task aware
  and must not be reimplemented on top of the ABI primitive inside a green-task runtime.

## Mapping from the current `host::*` surface

| Current | New surface | Notes |
| --- | --- | --- |
| `host::argc`, `host::arg` | entry shim → `grail_startup` | arguments are captured before init, UTF-8 on every platform |
| `host::env` | `env::get` | missing vs empty distinguished; runtime copy is authoritative |
| `host::open`, `read_fd`, `write_fd`, `close` | `fs::File` | partial reads/writes are explicit; 0 is EOF |
| `host::read_file`, `write_file` | `fs::File::read_all` / `write_all` | no hidden abort on error |
| `host::exists` | `fs::stat` | kind and metadata, not a boolean-only probe |
| `host::list_dir` | `fs::open_dir` + `Dir::next` | no trailing `/` in names; caller sorts |
| `host::create_dir`, `remove` | `fs::mkdir`, `remove_file`, `remove_dir` | empty-only directory removal |
| `host::exe_path` | `path::executable` | |
| `host::now_ms`, `sleep_ms` | `time::now`, `time::sleep` | nanoseconds; task-aware sleep |
| `host::tcp_listen`, `tcp_accept`, `tcp_connect`, `tcp_port` | `net` | readiness stays private |
| `host::command` | `process::Command`/`run` | argv, not shell syntax |
| `host::command_with` | `process::Command::env_clear` + `env` | the second vector is the child's whole environment |
| `host::environment` | `std::env::vars` | for the additive spelling: this process's entries |
| `host::print`, `host::newline` | runtime stdio | not an OS service; stays in the runtime |
| `host::exit` | runtime exit | not an OS service; cleanup checks stay in the runtime |
| `host::target` | compiler target query | not an OS service |

## Prerequisites and non-goals

Prerequisites owned by other lanes: the frozen `extern "C"` contract (declarations, `&[u8]`
pair expansion, `handle`, `unsafe`, callbacks), Win64 argument registers/shadow space, Mach-O
and Apple ARM64 symbol conventions, and linker inputs. This lane does not edit
`compiler/native.grl`; the wrappers cannot be implemented before those land, by design.

Non-goals for this version: garbage collection, implicit handle destruction, exceptions, async
syntax, shell command strings, recursive directory deletion, Unix-domain sockets, signals,
process groups beyond a flag, file locking, and a public readiness/reactor API. Each omitted
item has a concrete reason in the ABI or ownership model, not an assumption that the platform
cannot provide it.
