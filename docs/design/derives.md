# Derives

Status: **implemented.** `@derive(Eq, Ord, Hash, Clone, Debug)` on a `struct` or an `enum`.

Three things had to be true at once: no macro system (the user cannot substitute tokens), the
expansions must be ordinary Grail that the existing checker, ownership analysis and drop glue accept,
and a field the derive cannot handle must be named rather than silently skipped. The answer is that
the compiler *renders source* and lets its own parser read it - the same parser, the same passes, the
same diagnostics - with a comptime `@for` over the declaration's fields as the only mechanism that
makes the bodies field-wise.

## Where the pieces are

| piece | file |
|---|---|
| the attribute, the renderer, the checks | `compiler/native.grl`, "derives" section |
| `Eq`, `Ord`, `Hash` | `lib/ops.grl`, `lib/order.grl`, `lib/hash.grl` (they already existed) |
| `Clone`, `Debug` | `lib/clone.grl`, `lib/debug.grl` (new) |

`@derive(...)` is parsed as one more declaration attribute, next to `@strict`, `@no_alloc` and
`@no_panic`: it takes no `;` form, further attributes may follow, and the next declaration consumes
it. Names are resolved there, so an unknown name, a repeated name and a `@derive` before something
that is not a `struct` or an `enum` are refused at the attribute.

## The expansion

In the pass that reads a declaration's fields (pass 2), a derived declaration renders the
implementations it asked for and hands the text to `dr_append`. When the file's own items are done,
`dr_parse_tail` appends that text to the *file's own source*, lexes the file again (the prefix is
unchanged, so every token position already recorded still names the same text) and walks the new
tail as ordinary top-level items. `load_file` caches the extended text by file index, so a later pass
- and a generic body replayed after the passes are over - reads the same bytes at the same offsets.

That is why the generated code is not a second-class citizen: `impl` headers, `@for`, `where`
predicates on fields, borrows, moves and drops all behave exactly as they would in a file the user
wrote. `--show-derives` prints the source each `@derive` produced; the corpus case
`derives-show-derives` pins it.

Records and enums differ in one place: a record's fields are reachable as places (`self.@f`), so
`@for f in fields(Self)` is enough for `Eq`, `Ord` and `Hash`, while `Clone` and `Debug` need the
field *names* to build a literal and a format string, so those two are rendered field by field. An
enum has no `fields` loop; each derive renders one `match` arm per variant, in declaration order.

## The five implementations

- **Eq** (`ops::Eq::eq`): records compare field by field (`self.@f == other.@f`), enums compare
  payloads only when both sides are the same variant, otherwise `false`. A nominal payload, reached
  through a reference, compares through its own `ops::Eq`; a scalar, text or bytes payload uses the
  operator the language gives it.
- **Ord** (`order::Ord::less`): lexicographic over the fields; over variants, declaration order first
  and the payload after. It agrees with `Eq` because a field that is not equal in `Eq`'s sense is
  ordered by the same predicate. A caller that only wants a total order gets exactly that: a
  non-orderable field type (`bool`) is refused instead of given an invented order.
- **Hash** (`hash::Hash::hash`): the fold is the hasher's own. Fields are written into one
  `hash::Hasher` in declaration order, and an enum writes its variant index first. The byte stream is
  the algorithm: two values `Eq` calls equal produce the same stream, which is the property a
  keyed table needs. `f64` is refused, as Rust refuses it: a float's equality is not reflexive, so no
  consistent hash exists.
- **Clone** (`clone::Clone::clone`, new): a field-wise copy through each field type's `clone`, which
  makes ownership explicit - a borrowed view has nothing of its own to copy into, so it is refused
  rather than shared, and a vector field is refused rather than bit-copied.
- **Debug** (`debug::Debug::debug`, new): `Name { field: value, ... }` for a record,
  `Name(payload)` / `Name` for an enum, text quoted. Every derived `Debug` also writes an inherent
  `show` that forwards to it, so `println("{}", v)` and `format` use it with no new mechanism.

## Generics

The generated header repeats the declaration's own parameters: its lifetime list, its `Send`/`Share`
classifications, its interface bounds, and - on every parameter some field mentions (found by walking
the field types for the opaque parameter) - the interface this derive implements. `impl<T: ops::Eq>
ops::Eq for Pair<T>` is what makes `Pair<u64>` and `Pair<string>` both work while `Pair<view>` is
refused where the derive needs an owned value. Bodies are checked per specialisation, exactly as a
hand-written generic `impl` is.

Value parameters (`@N: u64`) are refused: a generated header would have to repeat the parameter and
its declared type, and there is no implementation yet that writes one.

## Checks

A derive is checked in the last pass, where every implementation in the build is known, so the
message can name the field and its type:

```
`@derive(Clone)` on `Outer`: field `inner` of type `Inner`: it has no `clone::Clone`
implementation: add `@derive(Clone)` to its type
```

Refused: an unknown name, a repeated name, `@derive` before anything but a struct or an enum, a type
with no fields or variants, a value parameter, a field or payload that cannot do what the derive
needs, `Ord` on a type with no total order, `Hash` on `f64`, and a missing standard-library module
(the message names the file to add).
