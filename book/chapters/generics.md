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

**Try it:** instantiate identity with a string, then consume the returned string exactly once.
