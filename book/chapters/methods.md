# Methods

`impl Type { ... }` attaches functions to a struct or enum. A function whose first parameter is the
type itself (or a reference to it) is a method and is called with `value.name(...)`; others are
called through the type, like `Counter::new(...)`. Record literals can use field punning:
`Counter { name, count: 0 }` names the `name` field once and takes its value from the variable in
scope.

{{example:methods}}

The receiver parameter says how the method uses the value: `&Counter` reads it,
`&mut Counter` changes it (so `visits` must be declared `mut`), and `Counter` takes
ownership. Both languages borrow the receiver automatically at the call site, and mutable access
stays explicit in the signature. An elided result reference follows the receiver's lifetime. `format`
builds a `string` with `{}` placeholders, `for day in 1..4` counts 1, 2, 3, and `else if` chains
conditions.

Methods also work on generic types: `impl<T> Stack<T> { ... }`.

**Try it:** remove `mut` from `visits` and read the compiler's message.

## Deriving the boring impls

`@derive(Eq, Ord, Hash, Clone, Debug)` before a `struct` or an `enum` writes the implementations you
would otherwise spell by hand, field by field and in declaration order:

```grail
use clone;
use debug;
use hash;
use ops;
use order;

@derive(Eq, Ord, Hash, Clone, Debug)
struct Point { x: u64, y: u64 }

@derive(Eq, Ord, Clone, Debug)
enum Shape { Circle(u64), Label(string), Point }
```

Each name stands for one standard-library interface, and only what you ask for is generated:

| derive | generated | what it does |
|---|---|---|
| `Eq` | `impl ops::Eq` | `==` and `!=`: every field compares, a variant compares only with its own variant |
| `Ord` | `impl order::Ord` | `<`, `<=`, `>`, `>=`: fields lexicographically, variants in declaration order |
| `Hash` | `impl hash::Hash` | the fields are written into one `hash::Hasher` in order; a variant writes its index first |
| `Clone` | `impl clone::Clone` | a field-wise copy through each field type's own `clone` |
| `Debug` | `impl debug::Debug` and an inherent `show` | `Point { x: 1, y: 2 }`, `Circle(2)`, `Point` |

`Debug` also gives the type the `show` method `println`, `print` and `format` already call, so
`println("{}", p)` prints the derived form. Text is quoted (`name: "ada"`) so a value cannot be
mistaken for a word.

There is no macro system: the compiler renders fixed Grail source for the derives you asked for,
appends it to the file's own text and parses it as ordinary items - so a derived method is checked,
borrowed and dropped exactly like one you wrote. The bodies are the comptime loop over the type's
fields (`@for f in fields(Self)`), which is what makes them field-wise; `--show-derives` prints the
source each `@derive` generated:

```
$ grail build --show-derives program.grl
// @derive on Point (program.grl)
impl ops::Eq for Point {
    fn eq(self: &Self, other: &Self) -> bool {
        mut equal = true;
        @for f in fields(Self) {
            if !(self.@f == other.@f) { equal = false; }
        }
        return equal;
    }
}
...
```

**What it refuses, and why.** A derive is checked against the fields it must handle, and a field it
cannot handle is named rather than silently skipped: `@derive(Clone)` on a struct with a borrowed
view says ``field `right` of type `&u64`: a borrowed view cannot be deep-cloned``, and a field whose
type has no `clone::Clone`, `hash::Hash` or `debug::Debug` implementation says so and tells you to
derive it on that type too. A derived implementation of a nominal field (or a variant payload,
which is reached through a reference) comes from that type's own implementation, so a nested type
that takes part must derive the same thing. `@derive(Ord)` needs an orderable field type - numbers,
`char`, text, bytes, or a type with `order::Ord` - and refuses `bool` instead of inventing an order.
`@derive(Hash)` refuses `f64`, as Rust does: a float has no equality that hash and `Eq` could agree
on.

**Generics.** A generic type derives per specialisation: the generated header repeats the
declaration's own parameters (its `Send`/`Share` classifications and interface bounds included) and
adds the derived interface as a bound on every parameter a field mentions, so

```grail
@derive(Eq, Ord, Hash, Clone, Debug)
struct Pair<T> { first: T, second: T }
```

gives you `Pair<u64>` and `Pair<string>` (and refuses `Pair<view>` where the derive needs an owned
value), each checked where it is instantiated.

The derives follow the standard library's own interfaces, so the modules they name have to be part of
the build: `lib/ops.grl` for `Eq`, `lib/order.grl` for `Ord`, `lib/hash.grl` for `Hash`,
`lib/clone.grl` for `Clone` and `lib/debug.grl` for `Debug`. A build that is missing one says which
file to add.
