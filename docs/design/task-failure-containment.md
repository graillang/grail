# Task failure containment: a failure is a value at the join

Decision record: [decisions-b2-b6.md](decisions-b2-b6.md), B5a (an amendment to B5). This note is
the design of the mechanism; the record states the decision and what breaks if it is wrong.

Status: implemented for the green scheduler on Linux x86-64; see "Limits" for what is not.

## The problem

A task is an ordinary function running on its own stack. Today one of two things happens when it
goes wrong:

- **It returns a failure value.** `fn f(...) -> R` where `R` is `T |? E`, `T?`, or any declared
  enum: the value comes back from `join(t)`, and the caller uses `?` or `match` as it would on any
  other result. This path already works, because a task result is an ordinary value.
- **A runtime check inside it fails.** An out-of-bounds index, a checked-overflow trap, a division
  by zero, `!` on a failed `Option`/`Result`, a failed refinement or `assert`, or an explicit
  `task_fail(msg)`. Every one of those sites calls `rt_fail`, which reports **once per process** and
  ends the process (status 134; SIGABRT from the main thread). One failing task therefore kills
  every other task in the program, plus the work they had already finished. That is the containment
  hole this note closes.

The second path is the hard one because of B5: **abort never unwinds, and nothing may unwind across
the C boundary.** There is no `defer`, there are no unwind tables, and no cleanup runs on an abort
path. Whatever the runtime does with a failed task's stack it may not do by unwinding it.

## What a task already has that a handler needs

The green scheduler already keeps, per task, a **saved context** - the worker's own stack pointer
and the task's stack pointer, switched by `raw_switch` (`compiler/os-linux.grl`, `rt_os_ctx_enter`,
`rt_os_ctx_leave`). That is a containment point in the literal sense: control can leave the task's
stack and land in the scheduler at any point, without any frame in between agreeing to it. This is
the same operation that a task performing a blocking call already uses to give up its stack
(`rt_suspend`), so nothing new is invented and nothing crosses a C frame: the switch is two
`raw_switch` calls inside the runtime.

So the containment point is **the task's own top frame**, installed by the trampoline that starts a
task (`rt_green_main`), and a check failure inside the task does exactly what a suspension does,
except that the task is never resumed:

1. the failure is written into a small fixed-size area of the **task record** - the check kind, its
   two operands, and the address of the *statement entry* that failed, taken from the compiler's
   site table (static data, valid forever; see below);
2. the task is marked finished;
3. control returns to the scheduler on the worker's stack (`rt_os_ctx_leave`);
4. the scheduler takes its ordinary "this task is done" path: it releases the task's stack, publishes
   the result word and wakes the joiner. The abandoned frames are never walked, no destructor runs,
   and the C boundary is never involved.

Nothing is thrown, nothing is caught, no frame is unwound: the stack is *discarded whole*, exactly
the cost B5 already accepts for an abort, scaled down from the process to one task.

**Nothing is allocated at the containment point**, which is a soundness property rather than an
optimization: a check can fail inside a runtime function, and a path that reached the allocator would
turn a contained failure into a deadlock if the failing thread already held the allocator lock. The
kind, the operands and the site entry are numbers, the site walk uses the task record's own scratch
words, and the human-readable text is built later, by the joiner that asked for it. The one exception
is an explicit `task_fail(text)`: it copies the caller's bytes into an owned text *before* leaving
the stack, in ordinary compiled code where no runtime lock is held.

## The join result

`join` stays the "this task must have succeeded" form: it returns `R` and, if the task failed, it
reports the recorded failure at the join site and ends the process - the same status 134 and the
same one-reporter rule as today, so no existing program's behaviour changes, and a task that cannot
fail costs nothing extra.

Containment is a separate, opt-in join that never aborts:

```
try_join(t)   //  -> R |? TaskFailure
```

`R |? TaskFailure` is the language's existing failure shape ([error-propagation.md](error-propagation.md)):
the same structural result type as `string |? Error`, with `TaskFailure` as its failure member. So
the join result is handled with the machinery that already exists and is already checked:

```
v := try_join(t)?;            // propagate: the enclosing fn returns X |? TaskFailure
match try_join(t) {           // or inspect both arms
    v: u64 => { ... }
    f: TaskFailure => { ... }
}
```

`TaskFailure` is a concrete record synthesized by the compiler, `.outcome::Failure`:

| field | type | meaning |
| --- | --- | --- |
| `kind` | `u64` | which failure: 1 index, 2 arithmetic overflow, 3 negative-to-unsigned, 4 no matching variant, 5 division by zero, 6 unwrap of None/Err, 7 range, 8 pop from empty, 9 byte range, 10 C array length, 11 index, 12 assertion, 13 explicit `task_fail` - the numbers `rt_fail` already uses |
| `message` | `string` | the human text without its `error: ` prefix and without the location, e.g. `index 7 out of bounds for length 3`, or the text an explicit `task_fail` gave |
| `site` | `string` | ` --> file:line:col` of the statement that failed, the line the report would print first; empty when the program carries no site table |

The site is the innermost program location only, not the whole ` = called from` chain: walking the
chain needs the failing frames, and by the time a program looks at the value those frames are gone.
Capturing the chain instead would mean formatting text on the failure path, which is the allocation
the containment point must not do.

The union value and the `TaskFailure` record are heap records of 2 and 3 words, and the two texts
are built when the join produces them - the union record on both arms, the failure record and its
texts only on the failure arm. The **success path of a task is untouched**: same trampoline, same
result word, same one published store, no added check, and `join` allocates nothing at all.
Containment is armed for every green task, and arming costs nothing per task: the decision is one
load of the current-task word inside `rt_fail`, which only a failing program reaches.

### Discarding the value is a compile error

A join that can fail must be handled, so the compiler refuses to *drop* an `.outcome` union:

```
try_join(t);                                    // error: the outcome of a joined task must be handled
o := try_join(t);             // and never consumed    -> error at the binding's scope exit
ignore_failure(try_join(t));                    // the explicit opt-out
```

`ignore_failure(e)` evaluates `e` and drops it by the ordinary rules (so the failure record and its
text are released; nothing leaks), and suppresses the diagnostic. Enforcement is a check in
`release`: when the compiler is about to drop a value whose type is an `.outcome` union *and the
value is still owned there* (the ownership checker's `can_cleanup`), it reports the error instead.
That is why a moved-out value - `?`, a `match` scrutinee, an argument - is not affected, and why the
rule is a property of the type rather than of a call site. It is the same style of check as the
existing "use of moved value": the program cannot get past the front end with a failure it did not
look at.

## Semantics, decided

**A failed task's result does not exist.** There is no placeholder `R`: the success arm of the join
result is simply not produced. Nothing invents a zero value.

**Children are not cancelled.** A task's children are tasks of the same scope, and a scope owns
every task started in it. When a task fails, its children are left running: they are joined by the
scope exit as usual, and each keeps its own outcome. Cancellation stays cooperative and explicit
(`sc.cancel()`), which is what the v1 contract already promises ("cancellation never abandons a
stack"). The alternative - cancel-and-join on failure - was rejected: it would make a failure
*destructively* propagate through work that may be exactly what the program needs to finish, and it
would give the failure path two behaviours depending on who else is watching.

**A join is affine and happens once.** `try_join` consumes the handle exactly as `join` does, so "a
join on an already-failed task" is asked about a *value*, not a handle: the answer is the same every
time the value is inspected (it is a record), and there is no second join. Joining twice is still
the same compile-time error it always was; the runtime's `rt_task_join` double-join abort is kept as
a backstop.

**An unnoticed failure in a scope re-raises at the scope exit.** If a task failed and its handle was
dropped (`abandon`) without a `try_join`, `task_scope` cannot return a failure - its result type is
the body's - so the scope exit reports the recorded failure with `rt_fail`'s own rule: inside a task
it is contained by *that* task's containment point, at the top level it ends the process. It never
silently disappears.

**The abort-once reporter still owns every uncontained failure.** `rt_fail` only consults the
containment point *before* claiming the reporter word, so a top-level failure, a failure in an
offload thread, or a failure inside a C callback still prints once and exits 134 with the same
protocol (`rt_abort_begin`, park, hard exit / SIGABRT from the main thread). A contained failure
never touches that word: the process is not aborting.

**Internal aborts are never contained.** `rt_abort` sites - allocator invariants, a failed
`raw_map`, the end-of-main leak check, stack overflow - are not language-level results and do not
become values. They keep their process-wide meaning. In particular a stack overflow is reported by a
signal handler on the alternate stack, where the task's own stack cannot be left safely.

**The thread-per-task mode does not contain.** With `GRAIL_TASKS=thread` a task owns its OS thread
and there is no scheduler frame to return to, so the mode keeps the process abort. It is the
documented "different semantic", not the default, and it exists for CPU fan-out where a trap is a
bug rather than a value.

## The cost: discarded frames leak, and the stack is recycled

A discarded stack's frames hold owned values whose destructors never run. They are unreachable and
they leak - the same accepted cost as B5's abort, now bounded by one task instead of the process.
Two consequences are stated rather than hidden:

- **The stack mapping itself is recycled.** Stack memory is scratch, not ownership: once the task's
  context is released, the 1 MiB reservation returns to the worker's free list
  (`rt_os_stack_give`) with no destructor and no poisoning, and the next task on that worker starts
  at the same address. Only the *heap* owners of the dead frames leak. Neither leaking the mapping
  nor scrubbing it would make the owned values reachable again, so recycling is the cheaper choice
  and the one that keeps `spawn` bursts cheap.
- **The end-of-main leak counter reports instead of aborting** when a failure was contained.
  `rt_live()` cannot know how many of the live blocks belonged to a discarded stack (there is no
  per-frame slot map, and reconstructing one is exactly the unwind data B5 refuses to emit), so the
  counter cannot subtract them exactly. The epilogue therefore still aborts - with exit 134 - when
  nothing was contained, and after a contained failure it writes
  `note: N allocation(s) still live after M contained task failure(s); the owners of a discarded
  stack are not released` to fd 2 and exits normally. The leak is *reported*, never silently
  accepted, and the note does not claim the count is exactly the discarded frames' owners - it is
  everything still live. Programs that contain nothing are unaffected byte for byte.

## Alternatives considered

- **Unwinding with destructors.** Rejected for the same reasons as B5: it needs CFI on ELF and
  `.pdata` handlers on Windows, a defined interaction with the C ABI, and it replaces deterministic
  scope-exit destruction with a path that must be proven to run exactly once. It also cannot be
  bounded to a task without new tables.
- **A handler installed earlier than the join** (`try_task(body, handler)`, a `catch` block around
  `spawn`). Rejected: it moves the recovery point away from the value, and it makes the failure
  path invisible at the place that has to decide what to do - the opposite of the ledger's standing
  rule against invisible failure paths. Containment is at the join or nowhere.
- **A sentinel result** (`join` returns `0`/`null` on failure plus a flag somewhere). Rejected: a
  task whose result type has no zero value cannot express it, and the flag is a second channel that
  nothing forces a caller to read.
- **A generic `Result<R, E>`.** Ideal, unavailable: user generics for enums are not implemented
  ([error-propagation.md](error-propagation.md)). The structural union `R |? TaskFailure` is the
  language's result shape today and needs no new type machinery - `make_union` already synthesizes
  `.result::Result2_1` for `T |? E`, and `.outcome::Outcome2_1` is the same object under another
  name.
- **Reset the stack instead of discarding it** (memset on release). Rejected: it buys nothing (the
  bytes are dead by construction, and the next task writes its own frame) and costs a 1 MiB write
  per contained failure.

## Verification

`tests/native-cases.json`, all prefixed `tfail-`, each also compiled a second time against emitted
module interfaces:

- `tfail-explicit-failure-at-join` - an explicit failure, its kind and its message at the join;
- `tfail-trap-contained-at-join` - an out-of-bounds index: the process survives, the join reports
  the message, the kind and a non-empty site;
- `tfail-scope-one-fails-one-succeeds` - a failure is one task's outcome: the siblings finish and
  their joins return their values;
- `tfail-child-failure-propagates-to-parent-join` - an unjoined failure inside a nested scope is
  re-raised at that scope exit and contained by the parent task, so the parent's join sees it;
- `tfail-success-path-unchanged` - the same output as before containment existed;
- `tfail-reject-discarded-outcome` - a dropped `try_join` is refused.

`task-scopes-join-cancel-abandon`, `abort-in-green-task-ends-process`, `task-100k-spawn-join-checksum`
and the pool cases keep the `join` and scheduler behaviour they pinned: `abort-in-green-task-ends-process`
still ends the process with status 134 and the same stdout - now because the join re-raises, not
because the failing instruction killed the process.

## Limits

- Green scheduler only; `GRAIL_TASKS=thread` keeps the process abort (a task owns its OS thread
  there, so there is no scheduler frame to return to).
- The failure is a value, not a backtrace: `site` is the failing statement's location, not the
  caller chain (see above).
- A check failure that happens while a task is *not* running (the main thread, an offload thread, a
  C callback) is not contained: there is no task boundary there.
- Child tasks are not cancelled by a parent's failure; a nested scope exit re-raises instead.
- A program that never calls `try_join` behaves exactly as before, including the leak counter.
- Windows and macOS are the same code path (the platform supplies the context switch); only Linux
  x86-64 is verified by the test cases in this change.
