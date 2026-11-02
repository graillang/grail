# Generic types and functions

Declare a type parameter with `type T`. Concrete arguments are ordinary types, such as `num`,
`bytes`, or `vec<bytes>`. If a declaration also has lifetimes, put them before type parameters.

{{example:generic-types}}

Constructors can also infer type arguments from fields or payloads, or from a matching return
type. A payload-free variant needs a context or explicit arguments to determine its type.

{{example:generic-functions}}

The compiler specializes generic functions and their drops. Calls infer arguments, or spell them
explicitly as `identity<num>(42)`. But the body must remain valid for an unknown affine `T`:

{{example:affine-generic}}

Even specializing this function to `num` does not make duplicating `T` valid. Generic definitions
are checked even when unused. Unconstrained `T` also does not support arbitrary arithmetic, field
access or copy-loads. No trait system is promised by these examples.

**Try it:** instantiate identity with a string, then consume the returned string exactly once.
