# Generic types and functions

Declare a type parameter directly: `fn identity<T>(value:T)->T`. Uppercase generic names are
types. Lowercase lifetime names appear directly in reference and view types and are inferred;
they are never listed in `<...>`. Concrete arguments are ordinary types, such as `u64`,
`u8[]`, or `u8[][]`. If a declaration also has lifetimes, put them before type parameters.

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
access or copy-loads. No trait system is promised by these examples.

**Try it:** instantiate identity with a string, then consume the returned string exactly once.
