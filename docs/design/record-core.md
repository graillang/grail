# First field-sensitive record core

2026-10-30. Implemented by-value nominal records, **not full bootstrap v0**. The mixed token example
in `seed/examples/records` executes under clang and TinyCC. A separate Rust control produces the
same 16 / 11 / 5 outputs. See `research/evidence/records30-20261030` and the broader aggregate gates.

```grl
module tokens;
struct Token<a> { span:read<a>, name:string, offset:num }
pub fn make<a>(p:read<a>)->Token<a> {
    return Token{span:p,name:"owned",offset:0};
}
pub fn span<a>(t:Token<a>)->read<a> { return t.span; }
```

Record declarations precede functions in an explicit module. Definitions can name other records;
by-value layout cycles are invalid. Constructors may omit explicit lifetime arguments: actual leaf
origins carry their local loan obligations. Function/field types write lifetime slots explicitly.
Unqualified type names refer to the current module; imported types use `module::Type`.

## Identity, initialization and cleanup

- Each value has separate logical storage identity and field values. A captured span's source is not
  the record's owned storage. Owner move/drop checks inspect own storage and owned descendants,
  not a union of captured roots. Each captured reference keeps its own capability/ancestor identity.
- Number-field reads copy. Other field values move on ordinary projection (`let name=t.name`),
  including affine view fields. Partial state is tracked at every nested field. A whole record can
  cross a call/return only when complete and usable. Moving one field does not erase its siblings.
- Byte builtins borrow field operands: `len(t.name)`, `read(t.span)`, `slice(t.span,...)`, etc. These
  do not silently move an owner out. Mutable byte borrowing of a string remains forbidden. This is
  still a byte-view operation, **not a general reference to the record/descriptor object**.
- Default destruction visits remaining owned leaves in declaration order, recursively. Bindings
  still end in reverse lexical binding order. One-byte local drop flags per owned leaf prevent
  freeing moved fields; complete public record ABI values do not carry those flags.
- At the record's last use, reference captures may expire independently of owned-leaf destruction.
  Default cleanup does not dereference expired span bits. Owned names still remain allocated until
  their lexical scope ends. Liveness currently tracks registers, not per-field future uses, so a
  later name-only use can conservatively retain unrelated captures. Custom user destructors are not
  implemented and cannot be assumed to ignore captures.

`Root::Param(input,path)` distinguishes parameter storage/owned fields from captured reference fields.
Returning a reference into an owned name cannot use the sibling span's lifetime. Returning the span
by value can outlive the carrier. Both have executable positive/negative tests. Local-source escape
checks recurse into returned records instead of checking only a top-level view.

An existing valid unique reference supplies authority independently of its lifetime-origin may-set.
Reborrows freeze its capability/ancestors, not every other reference with an overlapping lifetime
summary. Owner access/creation still checks outstanding origin obligations. The returned-pair test
uses one written lifetime for two disjoint unique fields; duplicate unique borrows of one owner still
reject. This assumes checked producers/valid incoming references, not arbitrary forged FFI pointers.
It does not implement or validate trusted split/iterator APIs.

## Type tables and interface invalidation

Layouts are normalized nominal definitions with ordered names/types and capture lifetime parameters.
A validated immutable context is shared across function checks. Expanded layouts count **all** nodes
(including empty records), bounded to 4,096 nodes / 64 depth; otherwise empty-record fanout could
consume exponential work without adding primitive leaves. Each declaration has at most 64 fields
and 64 lifetime slots. Empty records have a one-byte C representation. Numeric/view/owned layouts
remain the existing native C ABI; this evidence is Linux x86-64 only.

Public signatures retain nominal IDs and lifetime arguments. Module schema **3** includes the
reachable definition closure (including imported types used by public signatures); function payloads
are schema **5**. Private-only definitions do not enter a public surface. Layout/name/order/lifetime
changes therefore invalidate stale native dependents even when nominal function signature words do
not change. Rebuild earlier source/function artifacts; there is no old-schema parser fallback.

## Backend finding

The pinned TinyCC emitted `.rela.eh_frame` function-start relocations with zero addends for every
function in a multi-function object. GNU ld rejected mixed-backend links as overlapping FDEs.
`tcc-unwind-before.txt` retains that evidence. A direct large-record ABI probe worked without those
invalid tables. The TinyCC profile now uses `-fno-asynchronous-unwind-tables`: Grail v0 aborts, not
unwinds. This does not suppress ABI/link validation or postprocess ELF code. Both directions of the
clang/TinyCC record ABI and the actual selected-backend allocator audit now execute successfully.
There is no exception-unwinding/backtrace metadata guarantee for this TinyCC profile.

## Remaining work / no completion claim

General `&T` / `&mut T` references, invariant reference-containing setters, type/const generics,
generic vectors/maps/Result, field assignment/reinitialization, unbalanced ownership joins,
user destructors and full self-hosting remain unfinished. Early-return cleanup is now implemented;
see [return cleanup](return-cleanup.md). Grow/mutate owned
record containers by moving the field out for now; the complete goal still requires normal mutable
container APIs, not a permanent move-out workaround. LLVM comparison explicitly refuses record
layouts; C is the implemented production path. The field tree and slot table do not by themselves
prove a future mutable-reference checker sound. Do not extend the current local label tags into
mutable stores without the required region constraints/instantiation and adversarial gates.
