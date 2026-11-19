# abn_lang2 lane - state at wrap-up (director's stop order)

Last landed on main from this lane: `ee8b2c01` (increment 1, merged as `fe11d05f`, main was
`b46e0b10` when this was written). Three more increments are committed and pushed, queued in the
landing service, NOT yet on main:

| branch | commit | change |
|---|---|---|
| `abn-langfix2b` | `bacaf002` | compiler: an `Owned` closure field is not a hidden borrow, so a job table moves into `lock_with` (gap 2) |
| `abn-langfix3` | `a4fc2b8e` | json: a duplicate key keeps the last value without leaking the replaced one (lib/json leak) |
| `abn-langfix4` | `c47b1021` | compiler: a closure type nested in `rc::Arc<..>` is one type wherever it is written (gap 3) |

Each carries its corpus case(s) and CHANGELOG entry in the same commit, and each is rebased on the
main it was pushed against (`b46e0b10`). Worktrees: this one (`abn-langfix3`),
`/home/shulgin/grail-w-abn-lang2b` (`abn-langfix2b`), `/home/shulgin/grail-w-abn-lang2c`
(`abn-langfix4`); all clean. Nothing of the powf/asinf session's worktree was touched.

Verification done per increment: float/compound slice 54 passed; closure/capture/loan/dyn/drop
slice 388 passed for gap 2 and again for gap 3; json slice 5 passed.

## Unfinished: the ergonomics items (task item 4) - NOT STARTED

Nothing was edited for these; the scratch worktree was removed. Exactly what each needs, from the
reconnaissance done before the stop order:

- `^=`: a new lexer token kind (`assigned`, not merely number): `compiler/lexer.grl` line 7 lists
  262 `+=` ... 268 `**=`; `^=` must take the next free kind and join every "is an assignment"
  predicate - `compiler/native.grl` `assignment_kind` (`(261 < k) && (k < 267) || k == 268`) at
  43169, 51607, 52348, 52567, 52795, 54557 - plus a `compound_operator` arm mapping it to `^`.
- `Option::unwrap()`: no `unwrap` method exists on the option kind; only `value!` and
  `core.unwrap_option` (`lib/core.grl:11`). Method dispatch for a builtin enum needs a real site.
- `[Record{..}; N]`: two refusals say "a repeated element must be a plain value ...
  build owned elements with push" (`compiler/native.grl` 34457, 47482). Deliberately absent; the
  diagnostic already explains the reason (a repeat has no per-element construction site).
- `v[i].field = x`: a *literal* index works today (`v[0].value = ...` compiles and drops the old
  value); the gap is not reproduced yet with the report's exact shape - check a variable index
  before changing anything.
- `u32(negative i64)`: refuses as a checked conversion; making it wrap is a semantic change
  (Grail's conversions are checked), so the safe form is a diagnostic that names the C++ difference,
  not silent wrapping.

## Compiler hazard found while fixing the json leak (not in the task list, not fixed)

`exchange(&mut a.field, b.field)` on a record field whose type is a record:
`struct V { s: string } struct M { key: string, value: V }` + `x := exchange(&mut m.value, n.value)`
SEGVs, and the same call with the result discarded leaks (aborts in `rt_leak_exit`). `exchange` with
a temporary or a plain local as the source is clean, and a plain store (`slot.value = v`) is clean -
which is the workaround the json fix uses.
