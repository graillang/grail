# A borrowed trait object is one pointer to a `DynPair`

2026-11-13. The ABI of a borrowed interface object (`&dyn I`, `&mut dyn I`), stated once here, in
the book's trait-objects chapter and in the interface file, and implemented by both backends. The
pair `{data, vtable}` used to be a compiler-internal special case: `native.grl` declared it with a
`.gpair` directive in the emitted stream and `optimize.grl`/`llvm.grl` pattern-matched that text.
The layout is a language fact, so it is now named as one: a `DynPair` value with a fixed size and
field order, produced by the front end and carried to the backends as typed IR, where the two-word
frame value becomes a fact about a *declared type* instead of an annotation on an instruction
stream.

## The ABI

```
DynPair       size 16, align 8        { data: *mut u8 @0, vtable: *const VTable @8 }
VTable        size 8*(1+methods)      { drop: fn(*mut u8) @0, method_0 @8, ... }
&dyn I        8 bytes, align 8        one pointer to a DynPair
&mut dyn I    8 bytes, align 8        the same word; mutability is in the type, not the value
dyn I         (owned) 8 bytes         one pointer to a heap cell { value @0, vtable @8 }
```

A borrowed object is therefore a *thin* pointer, exactly like `&T`: same size, same alignment,
same copy, same drop (none - it does not own), same place in a record field, array element or
generic argument. The pair itself is not a value the language can name or copy: it is the
referent the handle points at, 16 bytes written into the borrowing frame at the conversion.

`VTable` word 0 is the drop glue: the concrete type's destructor (a user `impl Drop`, then its
fields) or the literal 0 when the type needs no drop. Words 1.. are the interface's methods in
`dyn_methods` order (superinterfaces first), each a code pointer taking the data pointer as its
receiver. A default method body gets an entry too, so dispatch never looks a name up at run time.

## Why one pointer and not two registers

The alternative is a Rust-shaped fat pointer: a `&dyn I` is `{data, vtable}` by value, two words
in two registers, with no indirection. On x86-64 SysV that is cheap - a 16-byte aggregate of two
INTEGER eightbytes is passed in two registers and returned in `%rax:%rdx` - and the platform
argument is usually decided there. It is the wrong choice for this language, for four reasons:

- **Win64 passes 16-byte aggregates by hidden reference.** Only aggregates of size 1, 2, 4 or 8
  travel in a register; a 16-byte argument is replaced by a pointer to a caller-made copy. Every
  dyn argument would become a caller-side store plus a pointer, i.e. the indirection this
  proposal avoids, performed at every call site instead of once at the conversion.
- **32-bit targets return aggregates through a hidden pointer.** i386 SysV and AAPCS32 have no
  register pair for a 16-byte result: the caller passes `sret` as an extra leading argument. A
  `&dyn`-returning signature would then differ between a 64-bit and a 32-bit target in a way the
  language would have to expose at every foreign boundary.
- **A 16-byte `&dyn` doubles every aggregate that holds one.** `struct Wrapper { shape: &dyn I }`,
  `(&dyn Shape)[]` and every `Option`-shaped wrapper would carry 16 bytes per element and align 8,
  for a value that is a borrow. One word keeps a borrow a borrow.
- **Grail's value model is one word.** A `Val` is a frame slot; every store, load, argument and
  result is one word. A two-word reference makes the two-word value the *ordinary* case, so the
  adjacency/promotion/liveness rule the optimizer has for pairs would have to hold for every
  reference in the program instead of for the conversion that builds one.

The cost of the choice is one store pair and an address computation per conversion, which the
optimizer already folds: the pair is written straight into slots of the borrowing frame with
`movq`s (no call, no allocation), and the handle is a `leaq` of the first slot. `dyn-borrowed-no-alloc`
pins that: a program whose only objects are borrowed has no `rt_rec` call for one, and the
function that builds and returns a `&dyn` still satisfies `@no_alloc`.

The one place a dyn value *is* two words is a result. The pair lives in the returning frame, which
does not outlive `ret`, so `return` hands back both words - data in the first result register,
vtable in the second (`%rax:%rdx`, `x0:x1`, `a0:a1`) - and the caller stores them into its own
frame. There is no platform disagreement about this one: a 16-byte `{ptr, ptr}` aggregate returned
in two registers is SysV, AAPCS64 and RV64's own rule for such a struct, so the shape at the
boundary is the platform's, not an extra Grail convention. It is stated in the IR (a dyn-result
fact) so that the second word stays live at the `ret`.

## The layout is observable, and pinned

Because the handle points at a real object, the layout is part of the language's foreign
interface: a C function handed a `&dyn I` reads the data pointer at offset 0 and the vtable at
offset 8. `dynf-pair-layout-extern-c` does exactly that through `extern "C"` (it prints the
concrete value, the first method's slot and the drop slot the C side can see), so the note is not
the only statement of the ABI: a test pins it, and it fails if either word moves.

## Two modules must agree: the interface carries the ABI

A `&dyn I` crosses a module boundary, so separately compiled modules must build the same pair. The
interface format (`// grail-interface 4`) therefore carries one `abi` header line, written by
`iface_module_text` and checked by `iface_load`:

```
abi dyn pair size = 16 align = 8 word0 = data word1 = vtable drop = 0
```

The reader compares it with the canonical line this compiler writes and refuses a file whose line
differs, naming the file and both spellings - a module compiled against another layout cannot be
linked into a program by accident. The format version went to 4 because a v3 file has no such
line: a required field added inside an existing version is exactly the writer/reader disagreement
the typed-interface work exists to remove, so a v3 file meeting this compiler fails loudly
(`was written in interface format 3, this compiler reads format 4`) instead of being read as if
the line were optional.

## Where the pair goes in the IR

The `.gpair` directive is gone from the emitter. `dyn_pair` (native.grl) allocates the two adjacent
frame slots of a `DynPair` and records it for the function with `llvm::fact_dyn_pair`; the `return`
of a borrowed object records `llvm::fact_dyn_result`. Those facts travel beside the instruction
stream in the typed-IR fact table (`docs/design/typed-ir.md`), keyed by the function's body symbol,
and both consumers read them there rather than out of the text:

- `optimize.grl` takes the fact table and, for each function it parses (it learns the body symbol
  from the `.type ...,@function` line), fills its two-word slot model from the facts;
- `llvm.grl` does the same in `function_pairs`, one alloca per pair instead of two.

Why this is the right carrier: the fact table already exists for exactly this purpose ("facts
travel beside `out`, never in it"), it is keyed per function, and it is truncated with the rest of
a function's facts when a body is re-emitted after a retry, so a discarded attempt cannot leave a
pair record behind. It is also the channel the typed-IR work needs for the same kind of "the shape
of this value is a language fact, not an instruction shape" information, so its shape is kept
stable: a kind, a function name and two integers.

The pair's *words* are opaque to the value passes - never promoted into registers, never
forwarded, their stores never dead - because the only reader of word 1 is the `leaq` of word 0,
which no pass reasons about. `NATIVE.md` states the rule; the rule is now stated in this note as
a property of the `DynPair` type (a 16-byte value with an address that both words are part of),
not as a property of a directive the emitter happened to write.

## Owned objects and drop glue

`dyn I` is unchanged: one word, a pointer to a heap cell `{value, vtable}` built by `dyn_box` with
`rt_rec(2)`, whose word 1 is the vtable `emit_vtables` writes. Dropping an owned object reads the
cell's vtable and calls word 0 with the value word; where the concrete type needs no drop, word 0
is 0 and the cell is freed without a call. `&d`, `&mut d` on an owned object builds the pair from
the cell (data = the value word, vtable = `8(%cell)`) instead of from a concrete type, so a
borrowed view of an owned object has the same ABI as a borrowed view of any other value.

## Generic specialisation

A conversion to `&dyn I` needs a concrete type: a type parameter (`T`) is refused
("a borrowed interface object needs a concrete type, not a type parameter"), because the pair's
vtable is a static symbol chosen at the conversion. Inside a generic `impl`, though, nothing is
special: `register_vtable` requests the method symbol for `(interface, concrete)` while
specialisations are still being emitted, so `impl<T> Shape for Wrap<T>` and `impl Shape for Sq`
both produce a vtable whose entries name specialised bodies. The ABI is the same for every one of
them, which is the point of stating it: a vtable is a table of pointers to Grail-internal
functions, and their calling convention (receiver first, six argument words, two-word result) is
the one the rest of the compiler uses.

## Cases

- `dynf-pair-layout-extern-c` - the layout through `extern "C"`: data at 0, vtable at 8, the first
  method at `VTable+8`, the drop slot at `VTable+0`.
- `dynf-borrowed-mut-method` - a `&mut dyn` method mutating through the object, observed after the
  borrow ends.
- `dynf-owned-dyn-field` - an owned `dyn I` in a record field, passed by value, returned from a
  call and dropped with the record, with the destructor running once.
- `dynf-pair-fields-and-vectors` - a `&dyn` in a record field and in a vector, and a `&dyn`
  returned from a function, all one word.
- `dynf-pair-optimized` - a function that builds pairs is optimized (its accumulator is promoted;
  the frame shape shows it), i.e. building a `&dyn` does not opt a function out of the optimizer.
- `dyn-borrowed-no-alloc` (existing) - the pair costs no allocation.
