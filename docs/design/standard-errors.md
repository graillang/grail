# A standard error interface, context chains and returned-error backtraces

The language has results and `?` ([propagation](error-propagation.md)) but no standard error value:
each layer invents a message record or a `string`, so a caller cannot ask for a cause, add context
without losing the original message, or report where an error was created. `lib/errs.grl` adds that
layer in ordinary Grail, and the native runtime gains one capture path for it.

## What exists, and what this builds on

- A result is written `S |? F` (or `S | F`): a failure returns normally and `?` propagates it. There
  is no unwinding (decision B5) and no implicit `From`, so a layer changes an error's type only by
  writing the conversion.
- `io::Error` is the stdlib's existing error enum (`NotFound`, `PermissionDenied`, …, `Other(code)`)
  with `show()`.
- The native runtime already records every statement's position in an emitted table (`grail_sites`)
  and walks the frame-pointer chain to name the failing statement and its callers (`rt_fail_where`).
  This reuses that walker and that table, and adds a second table naming each function.

## The interface

```grl
pub interface Error { fn message(self: &Self) -> u8[]; }
```

One method, because that is the only thing every error shape can answer without allocating beyond
its own text: the implementors are `errs::Message` (a record holding an owned message),
`errs::Report` (the chain below) and `io::Error` (`impl Error for io::Error`, whose `message` is
`show()`). A caller reads a message without knowing the concrete type; nothing else is claimed. The
interface is static (`Error::message(&value)`, or a `T: Error` bound), like every other interface in
the stdlib: there is no vtable lookup here.

## Context chaining, and what it costs

`Report` is the owned carrier:

```grl
pub struct Report { message: string, origin: Origin, frames: u8[][], trace: u8[] }
pub enum Origin { None, Os(io::Error) }
```

- `message` is the root message, owned.
- `origin` keeps the stdlib failure the report started from as a *typed* value, so a caller that
  needs `io::Error::is_not_found` still has it. It is not a generic cause: there is no `From`, so
  `Report::from_os(e)` (or `Report::of(message_record)`) is the explicit conversion, and a caller
  that wants something else writes it.
- `frames` are context strings in the order they were added, owned.
- `trace` is the captured stack, empty when none was captured.

`report.context(view("while parsing config"))` takes the report by value, appends a frame and returns
it, so the chain is built by reassignment (`r = r.context(...)`) exactly as the value's owner
changes. Nothing is copied and no allocation happens for the error path itself: one frame is one
owned string the caller asked for. There is no zero-allocation "context slot" variant: a frame the
caller writes is text that has to be stored somewhere, and pretending otherwise with a borrowed
lifetime would either lose the context when the call returns or force every error type in the chain
to carry the caller's lifetime.

Walking: `depth()` (frames), `frame(i)`, `cause()` (the root message), `origin()`. Printing is
deterministic and one line, outermost context first and the cause last, joined with `": "`:

```
while loading app: while parsing config: while opening /x: not found
```

`Report::print()` writes that line to stderr and then, if a trace was captured, one indented line
per frame. `Report::show()` returns the line as bytes for a caller that formats its own report.

## Backtraces on returned errors

Capture is a call-site choice, not a global switch: `Report::new(text)` stores no trace and allocates
nothing extra, `Report::traced(text)` captures the stack at that point. That is the honest opt-in
here - a process-wide `--backtrace` flag would make an allocation appear inside a function whose
cost the caller cannot see, and the language has no mutable globals to hold a default.

`host::backtrace()` is the capture: `f_host_backtrace` calls `rt_backtrace`, which walks the
frame-pointer chain outwards from itself, and for every frame finds

- the function whose range holds the frame's return address, from the new `grail_funcs` table (one
  `(start, name)` entry per function, name 0 for the runtime's own functions), and
- the statement the return address is in, from the existing `grail_sites` table.

Each named frame becomes one line:

```
  at f_parse_config (input.grl:11:5)
```

The function's name is its emitted symbol, which is what the linker, a debugger and the assembly
itself call it. Frames whose return address is in the runtime's own functions, in libc, or in a
function prologue the table cannot name are omitted, exactly as a failed check omits them.

Assumptions, stated because a wrong one would print garbage:

- Every compiled function pushes `%rbp`, links it to its caller's, and keeps it until it returns. The
  emitter does this on every target, and `rt_fail_where` already depends on it.
- `[%rbp]` is the caller's frame pointer and `[%rbp + 8]` the return address. The runtime's own
  assembly stubs (`rt_host_thread` and its peers) are prologues of the same shape.
- The walk stops after 64 frames or 32 named lines.

Refusal rather than guessing: `rt_backtrace` returns empty text when the build carries no tables
(macOS, the LLVM backend, `--debug`, `--split`, a seed-built compiler, a platform whose linker does
not bracket the sections) or when the tables are not usable (no `rt_sites` helper in process state).
`Report::print()` then prints the message alone, so "no backtrace" is never a malformed backtrace.
A seed compiler's helper fills only the three words the old runtime reads, so a table this runtime
cannot see reads as a zero-length table - the same refusal, not a fault.

`grail_sites` and `grail_funcs` are separate sections with the same bracketing: `__start_`/
`__stop_` symbols an ELF linker provides, and grouped PE sections (`grail_funcs$a/$b/$z`) on Windows.
The `rt_sites` helper the compiler emits now fills five words (site table start and end, the caller's
frame pointer, then the function table's start and end) into a buffer the caller allocates; a helper
written before this change fills three, which leaves the function table empty rather than lying.

## Integration with `?`

Nothing new is needed in the language, and nothing is converted implicitly:

- A function returns `T |? Report` (`T | Report` is the older spelling) and `?` moves the same
  `Report` type up through any number of layers unchanged; a layer that wants to add context does it
  explicitly on the failure path: `return err.context(view("while opening /x"));`
- A `string` or `u8[]` failure alternative is *not* converted to `Report`, and `io::Error` is not
  converted either: `Report::from_os(e)` is the conversion, written by the caller. This keeps
  `?`'s existing rule (error payload types and modes must match) and reports a mismatch at the
  boundary where a human chose the type, instead of hiding it in a generic `From`.

## What is not here

No exception, no unwinding, no `Error`-typed `dyn` collection of arbitrary foreign errors, no
`From`-style conversion, no allocation-free context, and no claim that the frame walk is portable
beyond the platforms the site table is emitted for. `Report` holds text and one typed origin; a
caller that needs a different payload writes its own result type and converts explicitly.
