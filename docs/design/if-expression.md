# `if` in expression position

2026-11-13. `if` is the language's branch statement, and it now also produces a value where a value
is required:

```grl
x := if c { 1 } else { 2 };
show(if c { a } else { b });
return if c { a } else { b };
```

Nothing about the statement form changes. `statement_body` sees an `if` that begins a statement
before any expression is parsed, so the two forms never compete for the same spelling: an `if` in a
statement position is the statement, and an `if` anywhere else (an initializer, an argument, a
`return`, a record field, a match arm expression) is this expression.

## Shape

An arm is one expression in braces, exactly as a match arm body may be one expression:

```grl
label := if n == 0 { "none" } else if n == 1 { "one" } else { "many" };
```

`else if` chains parse as nested `if` expressions; every arm must agree in type, and the whole chain
is one value. The braces are required, as they are for the statement form: an arm without them would
have to guess where its expression ends.

## Lowering

The condition is compiled exactly as a statement `if`'s condition is: it must be `bool`
(`strict_condition`), its temporaries are released at the test, and it states what it proves for each
arm (`pv_ir_atoms`, negated for the `else`), so the refinement prover sees the same facts it sees
today. Then each arm is compiled in its own branch, with its own ownership snapshot, and the two
snapshots are merged where the branches join - the statement form's code, unchanged.

What the expression adds is one word of frame storage. Every arm stores its expression's value into
that word and moves its own temporary out (`move_out`, so the arm's cleanup does not drop what the
join now owns); the word is then owned **once, after the merge** (`own` at the arm's agreed type).
Doing it that way, rather than moving into a per-arm slot, is what makes the ownership record
singular: the checker's places are not path-sensitive, so two arms writing two different slots would
leave two places where the program has one value. A value that is dropped is dropped from that one
place, at the end of the enclosing statement or scope, exactly as any temporary is.

The frame word is allocated before the arms compile and typed after they agree, so its type is
whatever the arms produce; nothing about the layout depends on the source order of the branches.

## Rules, and what is refused by name

- **`else` is required.** Without it the value would not exist when the condition is false. This is
  decided from the token after the `if` arm's block, before either arm is compiled, so it points at
  the `if`: *an `if` in expression position needs an `else`: with the condition false there would be
  no value*, with the help *add `else { ... }`, or write the `if` as a statement (its arms end with
  `;`)*.
- **Both arms agree in type.** The second arm is checked against the first at the arm's own token,
  and the diagnostic names both: *the two arms of an `if` expression must have the same type*, with
  the primary line *the other arm is `u64`, this one is `string`* and a label pointing at the first
  arm. The expected type of the place the value goes into is handed to each arm (`primary` now takes
  it), so a literal, a `None` or a narrower integer adopts the context's type before the arms are
  compared: `n: u8 := if c { 1 } else { 2 };` is two `u8`s, not two `u64`s.
- **An arm is one expression, not a block of statements.** A block has no value: *this arm of an `if`
  expression is a block of statements, so it has no value*, with the help *write one expression for
  the arm's value, or make the arm diverge with `return` or `break`*. The mixed shape is told apart
  and named too: *this arm of an `if` expression holds statements and then a value* (write only the
  value in the arm), and *an arm of an `if` expression is one value, not an assignment*.
- **A diverging arm needs no value.** An arm whose block always leaves the branch - `return`,
  `break`, or a call that aborts - produces no value and stores none. The value's type then comes
  from the arm that has one: `n := if c { 7 } else { return 3; };` is a `u64`. If *both* arms
  diverge there is no value at all and the construct is not an expression: *neither arm of this `if`
  produces a value, so it is not an expression*.
- **A value that borrows is refused.** `r := if c { &a } else { &b }` cannot be lowered soundly by
  this model: the result is one word, and the borrow checker would have to record that the value is
  one arm's loan or the other's. The refusal names the fix: *the result is one word, so it cannot
  name both arms' loans: use the reference inside each arm*. This is a limitation, not a rule of the
  language's semantics: a path-sensitive place (one place with a swap of loans at the join, as MIR
  has) would lift it.

## The ordinary parse failure, made honest

A keyword that is a statement where a value was required used to end in `error[E0001]: undefined
name` with a caret under the keyword - a message about a name that was never a name. `primary` now
recognises the statement words and says what happened: *`for` is a statement, not an expression: it
has no value*, with the help *write it as a statement; an expression position needs a value*. `if`
and `match` are not in that list: both have expression forms.

## `match` in expression position

The same hole exists for `match`, and `x := match n { 0 => 1, _ => 2 };` is still refused (see
`docs/design/match-expression-arms.md` for the arm-body work it builds on); it is the next increment,
and this lowering (one store per arm, one `own` after the merge) is the shape it will use.

## Formatter

`compiler/fmt.grl` is token-based layout, so the form needed no formatter change: `grail fmt`
round-trips `if` expressions in initializers, arguments, returns, record fields and `else if` chains.

Corpus: `exprif-initializer`, `exprif-else-if-chain`, `exprif-argument`, `exprif-record-field`,
`exprif-declared-type`, `exprif-diverging-arm`, `exprif-drops-value`, `exprif-nested-in-match-arm`,
and the refusals `exprif-type-mismatch`, `exprif-missing-else`, `exprif-statement-arm`,
`exprif-statement-block`, `exprif-no-value`, `exprif-borrows`, `exprif-statement-word`.
Book: *Branches and loops*.
