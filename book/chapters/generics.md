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
`string[]`. Inside a generic body `T::Item` is as opaque as `T` itself. Not yet: bounds on an
associated type (`type Item: Ord;`) and pinning one in a bound (`T: Source<Item = u64>`).

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
associated types (Rust's object safety); a `dyn` value cannot hold borrowed data.

**Try it:** instantiate identity with a string, then consume the returned string exactly once.
