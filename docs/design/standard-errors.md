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

## The interface and the carrier

```grl
pub interface Error { fn message(self: &Self) -> u8[]; }

pub struct Report { message: string, origin: Origin, frames: u8[][], stack: u8[] }
pub enum Origin { None, Os(io::Error) }
```

One interface method, because a message is the only thing every error shape can answer on its own: the
implementors are `errs::Message` (a record holding an owned message, the shape a program's own error
type takes), `errs::Report` and `io::Error` (`impl Error for io::Error`, whose `message` is `show()`).
Everything else about an error - its typed origin, its frames, its stack - is only known by the type
that carries it, so it is asked for on that type, not through the interface. The interface is static,
like every other interface in the stdlib: `Error::message(&value)`, or a `T: Error` bound.

`Report` is the owned carrier, and each field is the smallest thing that answers the question:

- `message` is the root message, owned. `Error::message` on a report answers this, not the whole chain;
  `show()` is the chain.
- `origin` keeps the stdlib failure a report started from as a *typed* value, so a caller that needs
  `io::Error::is_not_found` still has it. It is not a generic cause: there is no implicit `From`
  between error types, so `errs::from_os(e, what)` - or `errs::of(a_message_record)` - is the
  conversion, written by the caller. (The generic `Result<T, E>` this document says the language
  lacks has since landed: see [generic results](generic-results.md). `Report` is used as the `E` of
  a result union, which is unchanged by that.)
- `frames` are the context strings, owned, oldest first.
- `stack` is the captured stack text, empty when nothing was captured.

Constructors are free functions (`rc::new`, `io::from_errno` are the existing precedent), so the
spelling is `errs::report(...)`, and `impl Report` holds the methods.

## Context chaining, and what it costs

`r.context(view("while parsing config"))` takes the report by value, appends the frame and returns it,
so a chain is built by reassignment (`r = r.context(...)`) as ownership moves. Nothing is copied and no
allocation happens for the error path itself: one frame is one owned frame the caller asked for.

There is deliberately no allocation-free `context` variant. A frame the caller writes is text that has
to be stored somewhere; a borrowed frame would either dangle when the call returns or force every error
in the chain to carry the caller's lifetime, which is a much larger design (and one the language's
lifetimes alone cannot express today). A small honest wrapper that allocates one frame per boundary
beats a clever one that does not compile or does not hold.

Walking: `depth()` (frames), `frame(i)`, `cause()` (the root message), `origin()`, `trace()` (the
captured stack). `frame` returns `&a u8[]` - a borrow of the owned frame - rather than a `&[u8]` view:
the checker does not let a view of a record's owned text outlive the borrow of the record it came from,
so `cause()` and `trace()` copy instead. That is a checker rule, not a display decision; when the rule
allows a view of a record's owned text, these can stop copying without an API change.

Printing is deterministic and one line, outermost context first and the cause last, joined with `": "`:

```
while loading app: while parsing config: while opening /x: not found
```

`to_stderr()` writes that line to fd 2 and then, if a stack was captured, one indented frame line per
frame; `show()` returns the same line as bytes for a caller that formats its own report. `print` is a
reserved prelude name, hence `to_stderr`.

## Backtraces on returned errors

Capture is a call-site choice, not a global switch: `errs::report(text)` stores no stack and allocates
nothing extra, `errs::traced(text)` captures the stack at that point. That is the honest opt-in here - a
process-wide `--backtrace` flag would add an allocation inside a function whose cost the caller cannot
see at the call site, and the language has no mutable globals to hold a default.

`host::backtrace()` is the capture. `f_host_backtrace` calls `rt_backtrace`, which walks the
frame-pointer chain outwards from itself and, for each frame, finds

- the function whose range holds the frame's return address, from the new `grail_funcs` table (one
  `(start, name)` entry per function, name 0 for the runtime's own functions), and
- the statement that return address is in, from the existing `grail_sites` table.

Each named frame becomes one line:

```
  at f_parse_config (input.grl:11:5)
```

The name is the function's emitted symbol, which is what the linker, a debugger and the assembly itself
call it; a stdlib frame therefore reads `f_errs_traced`, and the frame that created the error is the one
above it. Frames whose return address is in the runtime's own functions, in libc, or in a function
prologue the statement table cannot name are omitted, exactly as a failed check omits them.

The tables: `site_table` emits the function table into its own section, `grail_funcs`, bracketed exactly
as `grail_sites` is - `__start_`/`__stop_` symbols an ELF linker provides, grouped PE sections
(`grail_funcs$a/$b/$z`) on Windows, and no table at all where the statement table is already off. The
`rt_sites` helper fills five words (statement table start and end, the caller's frame pointer, then the
function table's start and end) into a buffer the caller allocates. A helper emitted before this change
fills three, leaving the function table empty - the same refusal, not a fault, and the reason the change
is bootstrap-safe: a seed compiler's helper never writes past the buffer a newer runtime allocates.

Assumptions, stated because a wrong one would print garbage:

- Every compiled function pushes `%rbp`, links it to its caller's, and keeps it until it returns. The
  emitter does this on every target, and `rt_fail_where` already depends on it.
- `[%rbp]` is the caller's frame pointer and `[%rbp + 8]` the return address.
- The walk stops after 64 frames or 32 named lines, and at the failure buffer's limit.
- The tables' helper is stored in the process state the entry sets, which every thread and task shares,
  so a capture inside a spawned task names that task's frames too (checked against `task_scope`).

Refusal rather than guessing: `rt_backtrace` returns empty text when the build carries no tables
(macOS, the LLVM backend, `--debug`, `--split`, a seed-built compiler) or when the tables are unusable
(no helper in process state, zero-length table), so "no backtrace" is never a malformed backtrace.

What the capture may not do is allocate and not release. This module's string literals are heap values
and the droppers of its functions are not emitted, which a failing check never noticed because it ends
the process; `rt_backtrace` therefore writes its fixed punctuation byte by byte instead of through
`rt_fail_put`. Without that, every captured stack leaked four blocks per frame and the entry shim's
exit-time check aborted the program - which is how the mistake was found.

## Integration with `?`

Nothing new is needed in the language, and nothing is converted implicitly:

- A function returns `T |? errs::Report` (`T | errs::Report` is the older spelling) and `?` moves the
  same payload type up through any number of layers unchanged. Error payload types and modes must match,
  as before.
- A layer that adds context does it explicitly on the failure path:
  `return err.context(view("while opening /x"));`
- A `string`, `u8[]` or `io::Error` failure alternative is *not* converted to `Report` implicitly.
  `errs::from_os(e, what)` (and `errs::of(message)`) is the conversion, written at the boundary where a
  human chose the payload type; the mismatch `?` would otherwise accept silently is a compile error
  there instead.

## What is not here

No exception, no unwinding, no `dyn Error` collection of arbitrary foreign errors, no `From`-style
conversion, no allocation-free context, and no claim that the frame walk is portable beyond the
platforms the site table is emitted for. `Report` holds text and one typed origin; a caller that needs a
different payload writes its own result type and converts explicitly.
