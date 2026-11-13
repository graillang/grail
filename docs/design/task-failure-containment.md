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
- **A generic `Result<R, E>`.** Generic enums have since landed
  ([generic-results.md](generic-results.md)), so `Result<R, TaskFailure>` is expressible; the join
  keeps the structural union `R |? TaskFailure` because it needs no type argument at the join and
  composes with member-type matching - `make_union` already synthesizes `.result::Result2_1` for
  `T |? E`, and `.outcome::Outcome2_1` is the same object under another name.
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

## The integration failure, and the word that wrote the header (fixed, gaps2-tmem)

Reproduced with `grail run book/examples/task-failure.grl`: it printed `bad input`, then exited 134
with no message instead of printing the sibling task's `7`. It is fixed; this section records what
the writer was, because the answer is a contract between two branches rather than a bug in either.

The failure was a **16-byte overrun of the task record by the site walk**, and it took the two
branches that touched this area to make it: this one gave the walk a scratch area sized by what the
walk *reads*, and the errors branch's table helper writes more than that.

`rt_sites` (emitted by `compiler/native.grl`) writes **five** words into the buffer it is handed:

```
0  __start_grail_sites   8  __stop_grail_sites   16  the caller's rbp
24 __start_grail_funcs   32 __stop_grail_funcs
```

`rt_site_here` reads only the first three - both statement-table bounds and the frame - and it was
documented and called as a 24-byte scratch: `rt_site_here(t + 208)` on a record whose words
208..232 were called "scratch for the site walk". The record is **240 bytes**, and 240 bytes of
payload plus the allocator's 16-byte block header is *exactly* one 256-byte size class. There is no
slack after word 232: word 240 is not padding, it is the first byte of the **next block**, and word
248 is that block's kind. So the helper's fourth word landed in the record's dead word 232 and its
fifth - `__stop_grail_funcs`, a static address in `grail_funcs`' address range - landed on the next
block's **size** word. That is the observed value: `0x21f7a0` in the build measured here, which is
`__stop_grail_funcs` (and was `0x21f8a8` in the build the earlier write-up measured - the same
symbol, the layout shifted by `0x108`).

Everything the earlier measurements reported follows from that one write:

- **`kind` was correct and `size` was not.** The helper's last store ends at byte 247, so word 248
  (the next block's kind) is untouched; `rt_alloc_unlocked` also writes word 8 to 1 on both the
  reuse and the bump path, while it writes word 0 only on the bump path. A block taken from the
  per-size free list therefore keeps a word 0 written *while it was free* - which is exactly the
  last write the walk's fifth word makes - and `rt_free_unlocked` reads it as a size. As
  `>= 512 KiB` the block is treated as its own arena, the arena list does not contain it, and
  `rt_abort` fires. The stack is `rt_scope_end` -> `rt_free` -> `rt_free_unlocked` -> `rt_abort`
  because the first `rt_free(t)` in the reap loop is the first free of a record that came off the
  free list.
- **A watchpoint on the header stayed silent afterwards** because the write happens before the
  record exists: at `rt_site_here`'s call, the block after the failing record is not yet that
  task's record. A watchpoint set on `t + 240` at `rt_contain_site`'s entry is already too late -
  the site argument is evaluated in the caller, which is why the earlier investigation concluded
  the block "was written while free" and could not catch the writer.
- **`--debug` passed** because it changes block adjacency and the free list's contents, so the
  overrun lands somewhere that is later bump-allocated (and so re-labelled with a size).
- **The second record was the bad one**, because only a record that *follows* a failing record is
  inside the overrun.
- **The free list's use of word 1 is not the defect.** `rt_alloc_unlocked` overwrites word 8 with 1
  on both paths, so a link word is never handed out as a kind; the header that goes stale is word 0,
  which nothing restores because nothing is supposed to write it while the block is free.

### The fix

The walk's scratch is the **five words the helper writes**, `200..240`, entirely inside the record:
`rt_site_here(t + 200)`. The record's containment area is now:

```
160 kind   168 a   176 b   184 the site   192 the message   200..240 the site walk's scratch
```

Word 184 has to give up one bit for the "184 and 192 are already texts" flag that used to be its own
word 200: the walk needs those 40 bytes, and 240 bytes is the largest record that stays in the
256-byte size class. A statement-table entry is an 8-byte-aligned address in a 24-byte stride and an
allocation is at least 16-byte aligned, so bit 0 of the site word is free: `rt_contain_site` stores
the entry with bit 0 clear, `rt_contain_text` stores its text with bit 0 set, and `rt_task_site`
masks it. `rt_site_here`'s comment now says its scratch is sized by what the helper writes, not by
what the walk reads, and why (a helper emitted before the function table existed writes fewer -
never more - so a caller must not size the area from its own needs).

The scratch fix removed the overrun; it did not remove the *shape* that produced it. The contract
was still "a bare pointer and fixed offsets", so the next word either branch added to the helper
would land past the caller's area again, and a caller sizing its area from its own needs is a
mistake the code cannot see. `gaps3-rthand` replaced the contract itself: `rt_sites(out, capacity)`
writes only what the capacity admits, returns the count it wrote, and the runtime reads only that
many and refuses a count it did not offer - so the record's five-word area is sized by the offer and
verified by the answer, and a caller that offers nothing (`0`, which is what a runtime emitted before
the argument existed sends) is answered with the three words its 24-byte scratch holds. What each
side may write and read is in
[runtime-abi.md](runtime-abi.md#what-the-compiler-hands-the-runtime-a-handshake-that-carries-its-length);
the record's area is unchanged, because the descriptor is still five words when it is asked for in
full.

Rejected, in order of how tempting they were:

- **Grow the record to 248 bytes.** Correct and one line, but 248 + 16 crosses into the 512-byte
  class and doubles the heap cost of every live task, which is the one thing the record layout is
  tuned for (a 100k spawn burst costs records, not stacks). The bit is cheaper than the doubling
  and is where the record's two-word header says the limit is.
- **Re-store the size word on the reuse path** (`raw_store(block, size)` next to the kind store).
  This makes the bug disappear without fixing it: word 0 is an allocator invariant, so a stale value
  there is real corruption somewhere, and re-writing it on reuse converts every future overrun into
  silent aliasing. `rt_free_unlocked` keeps its abort.
- **A canary in `rt_alloc_unlocked`** (abort when a reused block's size word does not match its
  bin). It would have named this bug at allocation instead of at free, but the free path already
  aborts on the same corruption and the canary adds a new way for unrelated latent damage to end a
  process; the overrun was the bug, not the reporting.
- **A three-word helper contract** (make `rt_sites` write only the statement table and the frame,
  and give `rt_backtrace` its function-table bounds another way). The runtime is deliberately the
  tolerant side of this contract - `rt_backtrace` already reads the function-table words of a helper
  "emitted before the function table existed" as zeros - because the helper comes from the compiler
  and a checked-in seed's helper is older than the runtime it is compiled with. Sizing the scratch
  from what the walk reads is precisely the assumption that failed.

### Verification

`tmem-contained-then-joined` is the book example's shape as a corpus case: a scope whose first task
is contained and whose second task is spawned after that join and joined. `tmem-contained-then-
joined-thrice` runs the same scope three times, so the block the walk's fifth word lands on is one
the allocator has already handed out and reclaimed - the reuse path that reads the size word instead
of writing it. Both abort 5 times out of 5 against the runtime before this fix and pass after it,
and `book/examples/task-failure.grl` prints `bad input` then `7` and exits 0.

The command that reproduces it, in one line, is worth keeping:

```
C=$(bun tools/native.mjs build 2>&1 | tail -1); GRAIL_COMPILER=$C $C run book/examples/task-failure.grl
```

The runtime is read from the tree by every build (`compiler/cli.grl` locates `compiler/runtime.grl`
beside the compiler), so reverting `compiler/runtime.grl` alone reproduces the abort without
rebuilding the compiler - which is how the before/after counts above were taken.
