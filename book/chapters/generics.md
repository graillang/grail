# Generic types and functions

Declare a type parameter directly: `fn identity<T>(value:T)->T`. Uppercase generic names are
types. Lifetime names are lowercase, appear inside reference types such as `&a [u8]`, and are
inferred from the signature; they are never listed in `<...>`. Concrete arguments are ordinary
types, such as `u64`, `u8[]`, or `u8[][]`.

Interface bounds can use an imported name:

```grl
use order::Ord;

fn sort<T: Ord>(items: T[])
```

Without the import, the same bound is written `T: order::Ord`. A `use module::Name;` declaration
imports one type or interface; `use module;` only names the module itself.

{{example:generic-types}}

Constructors can also infer type arguments from fields or payloads, or from a matching return
type. A payload-free variant needs a context or explicit arguments to determine its type.

{{example:generic-functions}}

The compiler specializes generic functions and their drops. Calls infer arguments, or spell them
explicitly as `identity<u64>(42)`. But the body must remain valid for an unknown affine `T`:

{{example:affine-generic}}

Even specializing this function to `u64` does not make duplicating `T` valid. Generic definitions
are checked even when unused. Unconstrained `T` also does not support arbitrary arithmetic, field
access or copy-loads; what a bounded `T` can do is what its interfaces declare.

## Interfaces and default methods

An interface lists the methods a type must provide. A method written with a body is a *default*:
an implementation can leave it out and gets that body, compiled for its own type, or write its own
to override it (Rust's provided methods). A default can call the interface's other methods and the
private helpers of the interface's module.

```grl
interface Shape {
    fn area(self: &Self) -> u64;
    fn name(self: &Self) -> string {
        return "shape";
    }
}

impl Shape for Circle {
    fn area(self: &Self) -> u64 {
        return 3 * self.r * self.r;
    }
}

fn show<T: Shape>(s: &T) {
    println("{} {}", s.name(), s.area());
}
```

Inside `show`, `s.name()` is the bound's method; `Shape::name(s)` is the same call, and is how to
pick one when two bounds declare the same name. An implementation must write every method that has
no default, and only methods the interface declares.

## Interfaces that extend others

`interface Shape: Named { ... }` says every `Shape` is also a `Named` (Rust's supertraits): an
implementation of `Shape` needs one of `Named` for the same type, and anything known to be a
`Shape` - a bound `T: Shape`, a default method's `self`, a `dyn Shape` - can call `Named`'s
methods too. List several with `+`: `interface Store: Read + Write`.

## Generic interface methods

An interface method can have type parameters of its own, after `Self`:
`fn wrap<U>(self: &Self, u: U) -> U[];`. Each implementation writes the same parameters, and each
call is compiled for the types it uses. As in Rust, such a method has no single entry in a `dyn`
vtable, so an interface with one cannot be used as `dyn`.

## Generic implementations

An implementation can be generic itself: `impl<T: Show> Show for Box<T>` makes every `Box<T>` a
`Show` whose `T` is one, and its methods are compiled for each `T` used:

```grl
impl<T: Show> Show for Box<T> {
    fn show(self: &Self) -> u64 {
        return self.v.show() + 100;
    }
}
```

## Where an implementation may live

An `impl I for T` must be written in the module that declares `I` or in the module that declares
`T`; a generic type such as `Box<T>` counts as declared where `Box` is. A type no module declares -
`u64`, `u8[]`, a type parameter in `impl<T> I for T` - leaves only the interface's module. This is
the orphan rule: two modules can never both implement one interface for one type, so which
implementation a call uses never depends on which modules a program happens to `use`.

When you need an interface from one module on a type from another, wrap the type in a struct your
module declares and implement the interface for the wrapper:

```grl
use interface_contracts;
use orphan_point;

struct ValuedPoint {
    p: orphan_point::Point
}
impl interface_contracts::Value for ValuedPoint {
    fn value<a>(self: (&a Self)) -> u64 {
        return self.p.x;
    }
}
```

Writing the impl directly is refused, naming both declaring modules: ``implementation must own the
interface or nominal type: `impl interface_contracts::Value for orphan_point::Point` is written in module `main`,
but the interface is declared in `interface_contracts` and the type in `orphan_point`; move the impl
to one of those modules, or wrap the type ...``.

## Operators

Implement an interface from `ops` and the operator works on your type (Rust's `std::ops`):
`ops::Add`, `Sub`, `Mul`, `Div` and `Rem` give `+ - * / %` (taking both operands), `ops::Eq` gives
`==` and `!=` (borrowing them), and `order::Ord`'s `less` gives `<`, `<=`, `>` and `>=`. A generic
function bounded by one, `fn sum3<T: ops::Add>(a: T, b: T, c: T) -> T { return a + b + c; }`, takes
records and the built-in numbers alike.

```grl
impl ops::Add for V {
    fn add(self: Self, other: Self) -> Self {
        return V { x: self.x + other.x, y: self.y + other.y };
    }
}
```

## Associated types

An interface can leave a type for each implementation to choose: `type Item;` declares it, the
interface's signatures name it `Self::Item`, and an implementation fixes it with `type Item = ...;`
before its methods. A generic function names it through its parameter's bound, `T::Item`:

```grl
interface Source {
    type Item;
    fn pull(self: &mut Self) -> Self::Item?;
}

impl Source for Counter {
    type Item = u64;
    fn pull(self: &mut Self) -> u64? { ... }
}

fn drain<T: Source>(src: &mut T) -> T::Item[] {
    mut out = T::Item[];
    while let Some(x) = src.pull() {
        out.push(x);
    }
    return out;
}
```

`drain(&mut counter)` returns a `u64[]`; the same function drains a source of strings into a
`string[]`. Inside a generic body `T::Item` is as opaque as `T` itself, unless the interface bounds
it - `type Item: order::Ord;` lets generic code compare items with `<` - or the function pins it:
`fn total<I: iter::Iterator<Item = u64>>(it: &mut I) -> u64` sees `I::Item` as `u64`, and a call
with another item type is refused. An interface object names its associated types the same way,
`dyn iter::Iterator<Item = u64>`.

## Interface objects

A generic function is compiled once per type it is used with. When the type is only known at run
time - a list of shapes of different kinds, a plugin - use an interface object instead: `dyn Shape`
holds a value of any type that implements `Shape`, and a method called on it runs that type's
implementation (Rust's `Box<dyn Trait>`; here the box is implicit).

```grl
mut shapes = (dyn Shape)[];
shapes.push(Square { side: 2 });
shapes.push(Circle { r: 1, label: "c" });
for s in &shapes {
    total = total + s.area();
}
```

A value becomes a `dyn Shape` wherever one is expected - a typed binding, an argument, a pushed
element - and is moved into it. `&dyn Shape` and `&mut dyn Shape` borrow one like any value, and
dropping a `dyn Shape` drops what it holds. An interface can be used this way when every method
takes `self: &Self` or `self: &mut Self` first and mentions `Self` nowhere else, and it has no
associated types unless the `dyn` type fixes them (`dyn I<Item = u64>`) (Rust's object safety); a `dyn` value cannot hold borrowed data.

### Borrowing an object

`dyn Shape` owns what it holds: `shapes.push(Square { side: 2 })` moves the square into storage the
compiler allocates for it. When the value is already somewhere and you only want to run its methods,
borrow it instead. `&dyn Shape` and `&mut dyn Shape` are *borrowed interface objects*: `&value` (and
`&mut value`) becomes one wherever a `&dyn Shape` is expected - a typed binding, an argument, a
return - when the value's type implements the interface.

```grl
fn area_of(s: &dyn Shape) -> u64 { return s.area(); }
fn grow_twice(s: &mut dyn Shape) { s.grow(1); s.grow(1); }

mut q = Square { side: 3 };
println("{}", area_of(&q));      // 9
grow_twice(&mut q);              // the mutation reaches q
println("{}", q.side);           // 5

mut shapes = (&dyn Shape)[];
shapes.push(&q);                 // a vector of borrowed objects
for i in shapes.len() { println("{}", shapes[i].area()); }
```

A borrowed object is a pair of words - where the value is, and the table of its methods - kept in
the frame that borrowed it, so building one allocates nothing and the value itself never moves or
copies. `&mut dyn Shape` mutates the original, never a copy. The rules are `&T`'s: the value cannot
be moved or dropped while the borrow lives, a function may return a `&dyn Shape` borrowed from its
inputs, and one borrowed from a local is refused (`fn made() -> &dyn Shape { c := Circle { r: 1 };
return &c; }` does not compile). A record or a vector may hold one, and a struct that stores one
names the lifetime: `struct Wrapper<a> { shape: &a dyn Shape }`.

That pair has a fixed shape, and it is the language's, not the compiler's: a `&dyn Shape` is **one
word**, the address of a 16-byte, 8-byte-aligned pair whose first word is the data pointer and whose
second word is the method table (`docs/design/fat-dyn.md`). The table's first word is the
destructor's slot and its later words are the interface's methods in declaration order. Being one
word is why a `&dyn Shape` sits in a record field, a vector element or a function result exactly
where a `&Square` would, and why it copies like one; the value it points at is the single word
`&q`, so a method dispatched through it writes through that word and the mutation lands in `q`.
`dyn Shape` on its own is one word too - a pointer to a heap cell holding the value and its table -
and dropping it runs the concrete type's destructor through the table's first slot.

Interface files carry the form, so a separately compiled module can take a `&dyn Shape` as
naturally as it takes a `&u64` - and they state the pair's layout, so two modules built for
different layouts are refused rather than linked together.

A borrowed object can cross into C: a shared `&dyn Shape` parameter of an `extern "C"` function is a
`const DynPair *`, one pointer to the two words, so C reads the object at `p->data` and its table at
`p->vtable`. `&mut dyn Shape` is not admitted there - a reference parameter of an `extern "C"`
function otherwise means "C writes through this", and a C callee rewriting a pair is not part of the
ABI.

**Try it:** instantiate identity with a string, then consume the returned string exactly once.
