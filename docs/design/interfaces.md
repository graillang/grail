# Static interfaces (implemented subset)

The current compiler supports explicit user-defined interfaces and concrete implementations:

```grl
interface Value{fn value<a>(self:ref<a,Self>)->num;}
impl Value for num{
    fn value<a>(self:ref<a,Self>)->num{return load(self);}
}
fn read<a,T:Value>(value:ref<a,T>)->num{return Value::value(value);}
fn main(){n:=42;assert(read(borrow(n))==42);}
```

`Self` is the implementation's type, not an implicit receiver. For a struct or enum, an implemented
interface method can also be called with dot syntax, `version.less(borrow(other))`, resolved
statically like an inherent method (ambiguity between interfaces is an error). Parameters and passing modes
remain explicit. Calls use `Interface::method(...)` or `module::Interface::method(...)`.
The compiler infers Self from arguments; use an explicit type argument for return-only Self
or a function value, e.g. `Value::value<num>`. There is no runtime method search or vtable.

Generic bounds may combine user interfaces and structural capabilities:
`T:Hash+Equal+Send+Share`. Unknown generic values remain affine. Unused generic bodies are
checked too; a generic body cannot call an interface method without its bound. Record/enum
bounds apply both to explicit type arguments and inferred construction.

Implementations must provide every method with matching types, ownership modes and input/output
lifetime relationships. Lifetime names may differ. Owning Self parameters/results transfer data
normally; an interface does not grant implicit copies. Duplicate/overlapping implementations are
rejected. The implementation's module must own either the interface or the nominal type; foreign
primitive implementations therefore belong in the interface's module. Raw runtime modules cannot
publish/implement safe interfaces. Send/Share remain checked structural capabilities, not traits
whose safety can be overridden with a user implementation.

This is the common foundation for hashing/equality and later callable/iterator contracts, not
separate hard-coded key-type registries. Current restrictions are deliberate and explicit:

- No interface type parameters, associated types, superinterfaces, default methods, generic
  implementation methods or blanket/conditional implementations yet.
- No implicit receiver-method lookup, dynamic interface objects, specialization priority or
  negative implementations.
- Suspension/effect contracts are still missing. Having a method signature does not prove that
  a user implementation is pure, non-suspending, or satisfies a mathematical equality/hash law.
- All participating module sources are checked together; a separately compiled interface
  artifact and incremental ABI policy remain future work.

`compiler/tests/interfaces.grl` exercises static dispatch, module qualification, mixed bounds,
owning Self, method values and lifetime alpha-renaming. Negative cases check missing proofs,
coherence, wrong signatures, ownership moves, return origins and the unsafe-runtime boundary.
