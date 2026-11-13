# Checked effects: `@no_alloc`, `@no_panic`, `@bounded(n)`

Status: implemented (gaps round, G26).

`@no_alloc` and `@no_panic` on a function, and `@bounded(n)` on a loop, are claims the compiler
proves. None of them is trusted.

## How the proof works

Every body the build emits is recorded under the symbol a `call` names it by: user functions,
specialisations, the runtime and the drop helpers. When a body is finished its text is read back for
`call` lines, which become edges of a call graph. The roots are the runtime's allocator (`rt_alloc`,
`rt_alloc_unlocked`, `rt_grow`) and its failure entries (`rt_abort`, `rt_fail`, `rt_trap`,
`rt_refine`, `rt_error`). A fixpoint marks every body that reaches a root, and each claim is checked
against the result after the whole program is emitted. A diagnostic prints the chain that reached
the root.

Because checks the prover removed are not in the emitted text, `@no_panic` is exactly as strong as
the refinement prover and bounds-check elimination: it fails where a check is left.

- A refined parameter's check sits in the function's checked entry. It is recorded as an entry fact,
  not a body fact. A call that reached the `.proved` entry does not inherit it; any other call does.
- An unknown callee in user code (an indirect call, an unrecorded extern) counts as both allocating
  and failing. In the runtime and the drop helpers, an indirect call is the compiler's own dispatch,
  and an unknown name is an assembly stub (the system-call gate); neither is an edge.
- `grail build` compiles a program that claims an effect in one run, since the proof needs every
  body.
- Interface files carry `effects <no_alloc> <no_panic> <strict>` rows after a function, so an
  `--interface` build trusts the definition module's own proof.

## `@bounded(n)`

`@bounded(n)` is proved syntactically: `while i < K` (or `<=`, or with the bound on the left), where
`i` is an unsigned counter the body changes only by a positive constant step, and `K` is a constant
or a refined parameter's bound with `K <= n`. A `for i in a..b` with constant ends needs `b - a <= n`.
Anything else is refused, and the refusal names what is missing.

## Limits

- An element type's user `Drop` reached only through `rt_drop_seq` or a vtable's drop slot is not
  followed. That drop is reached through an indirect call inside trusted code.
- Specialisations of one generic share a record keyed by the template's symbol, which is
  conservative: one allocating instance marks them all.
