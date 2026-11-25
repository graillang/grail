# Illustrative Grail surface language

**Not executable, not a specification, not agreed syntax.** These examples test coherence; they
are not evidence that the proposed ownership, library, proof or device designs have been implemented.
Source files use `.grl`. Markdown sketches deliberately avoid adding pretend runnable files.
The [follow-up competition](memory-model-competition.md) compares three access surfaces and lexical
capability contexts; the `&` / `&mut` and explicit argument conventions here are not commitments.

Conventions across examples:
- `let` immutable, `mut` mutable; by-value ownership moves nontrivial values, with no implicit clone.
- `&T` / `&mut T` are shared/exclusive loans; no named lifetime variables. Calls use explicit loans.
- `[T]` is generic application, `Slice[T]` a scoped slice view, `.f()` ordinary-function notation.
- `fn(x) { ... }` is a closure; capture ownership/effects must be checked, never guessed unsafely.
- `!T` abbreviates `Result[T, Error]` for a named closed default error union; `!T[E]` is the
  tentative typed-error spelling. `?` propagates from the enclosing function/closure.
- `Unit`, `Option`, `Result`, containers, iterators, tasks and devices are library types.
- `requires`/`ensures`, `proof` and bracketed propositions are optional verification notation.
  Logical reflection is limited to eligible total definitions. Syntax is deliberately unsettled.
- Effect/origin summaries below are comments; actual public interface presentation is undecided.

## 1. Hello world

```grl
fn main(out: &Console) !Unit {
    out.write("Hello, Grail!\n")?
}
```

No ambient console authority; the executable launcher supplies capabilities. `write` may suspend.

## 2. Records and tagged unions

```grl
struct Order { paid: Bool, total: U64 }
enum Status { Pending, Paid(U64), Rejected(String) }

fn amount(s: &Status) U64 {
    match s {
        Pending => 0,
        Paid(n) => n,
        Rejected(_) => 0,
    }
}
```

Matching a shared view projects shared views of nontrivial payloads; it does not move from them.

## 3. Functions and inference

```grl
fn square(x: U32) U32 { x * x }
let answer = square(12)
```

Checked overflow/traps have defined semantics in all build modes; `square` is not total over all U32
inputs if trapping counts as failure. Explicit wrapping arithmetic is a separate library operation.

## 4. Mutation and ownership

```grl
mut xs = Vec[U32].new(mem)
xs.push(10)?
let ys = xs                  // ownership transfer
// xs.len()                  // rejected: moved
```

`mem` is an allocator capability supplied by the surrounding function. Mutation methods request
exclusive access by a declared receiver convention; the exact receiver sugar remains a design choice.
Without such sugar, write `(&mut xs).push(10)?`. No method may silently clone to make a call legal.

## 5. Shared/mutable borrowing, no lifetime names

```grl
fn first[T](xs: &Slice[T]) Option[&T] {
    // exported origin summary: result borrows from xs
    xs.get(0)
}
fn bump(x: &mut U32) Unit { x = x + 1 }

let head = first(&items)
print_item(out, head)?
bump(&mut counter)
```

Loan-place access is transparent (`x` denotes the borrowed place); rebinding a reference needs an
explicit operation, not an ambiguous assignment. `first`'s parameter/result are scoped views.
The origin summary is part of the checked library interface, even if inferred and not written.

## 6. Dynamic graph without persistent borrowed fields

```grl
struct Node { value: U32, edges: Vec[Id[Node]] }
mut graph = Arena[Node].new(mem)
let a = graph.insert(Node { value: 7, edges: Vec.new(mem) })?
let b = graph.insert(Node { value: 9, edges: Vec.new(mem) })?
graph.get_mut(a)?.edges.push(b)?
```

Arena IDs are not raw pointers. With deletion, `get_mut` checks validity; generation wrap must not
make a stale ID valid. Memory of nodes can be retained until arena destruction; that cost is explicit.

## 7. Fused postfix transformations

```grl
let total = orders.iter()
    .filter(fn(o) { o.paid })
    .map(fn(o) { o.total })
    .sum_checked()?
```

Adapters are scoped values retaining a loan; compiler specialization/fusion is a performance target,
not a guaranteed consequence of postfix spelling. Overflow uses the same explicit result model.

## 8. Errors as values

```grl
enum LoadError { Missing, Invalid }
fn parse(data: &Bytes) !Config[LoadError] { /* ordinary Result-producing code */ }

fn load(fs: &Dir, path: Path, mem: &Allocator) !Config {
    let bytes = fs.read_all(path, mem)?
    return parse(&bytes).map_error(fn(e) { Error.Parse(e) })?
}
```

`Error` here is a declared closed union containing the example I/O/parse cases. `!` does not infer
an ever-growing global error universe. The omitted parser is illustrative, not an implemented stub.

## 9. File I/O and cleanup

```grl
fn read_config(fs: &Dir, path: Path, mem: &Allocator) !Bytes {
    mut file = fs.open(path)?
    defer file.release()
    return file.read_all(mem)?
}
```

This sketch requires `release` to be a documented non-suspending cleanup primitive, with an explicit
policy for close errors. It is not an arbitrary user destructor. Fallible flush/finish is a separate
explicit call; async cleanup cannot be smuggled into this `defer` contract.

## 10–11. Networking and colourless suspension

```grl
fn fetch(net: &Net, address: Address, mem: &Allocator) !Bytes {
    mut socket = net.connect(address)?
    defer socket.release()
    socket.write_all("GET / HTTP/1.0\r\n\r\n")?
    return socket.read_to_end(mem)?
}
```

Published effect includes network, allocation and suspension, regardless of blocking/evented runtime.
No `async fn`, `await` or duplicate sync implementation. This is a minimal protocol sketch, not a
production HTTP client (TLS, limits, timeouts, parsing and framing still matter).

## 12. Structured concurrency and cooperative cancellation

```grl
fn both(io: &Runtime, net: &Net, mem: &Allocator) !Pair[Bytes, Bytes] {
    return io.scope(fn(s) {
        let left = s.spawn(fn() { fetch(net, Address.a(), mem) })?
        let right = s.spawn(fn() { fetch(net, Address.b(), mem) })?
        let a = left.join()?
        let b = right.join()?
        return Pair(a, b)
    })?
}
```

`spawn` is explicit and fallible. Scope closure capture requires the capability types to permit
concurrent use; not all allocators do. Error exit requests cancellation and joins unfinished children
before borrowed storage is reclaimed. A child can call `s.cancel.check()?` at a documented point;
there is no forced arbitrary-frame destruction or guarantee of termination for a noncooperative task.

## 13. Generics, one interface mechanism

```grl
fn max[T.. Ord](a: T, b: T) T {
    if compare(&a, &b) >= 0 { a } else { b }
}
```

`Ord` supplies ordinary declared operations; it does not overload all operators or launch global
instance search. The unreturned owned argument is disposed. Static specialization has a build cost.

## 14. Staging

```grl
fn chunk[comptime N.. USize](data: &Bytes) USize {
    comptime { assert(N > 0) }
    data.len / N
}
let blocks = chunk[64](&data)
```

Finite stage budgets and cached specialization; no implicit build-time network/filesystem access.
Checking `N > 0` for this specialization is not proving every possible use of `chunk` correct.

## 15. Contract

```grl
fn midpoint(lo: U32, hi: U32) U32
    requires lo <= hi
    ensures lo <= result && result <= hi
{
    lo + (hi - lo) / 2
}
```

The precondition remains checked or cheaply discharged in ordinary builds. The postcondition is not
labelled proved until evidence exists. Proof follows by bounds on unsigned difference/division/addition;
no mathematical-integer replacement may silently skip overflow obligations.

## 16. Explicit inductive proof about an executable algorithm

```grl
fn append[T](xs: List[T], ys: List[T]) List[T] {
    match xs {
        Nil => ys,
        Cons(h, tail) => Cons(h, append(tail, ys)),
    }
}

proof fn append_assoc[T](xs: List[T], ys: List[T], zs: List[T])
    Proof[append(append(xs, ys), zs) == append(xs, append(ys, zs))]
{
    match xs {
        Nil => eq.refl(append(ys, zs)),
        Cons(h, tail) => eq.congr(
            fn(t) { Cons(h, t) },
            append_assoc(tail, ys, zs)
        ),
    }
}
```

This is a complete *illustrative proof-term structure*: unfolding `append` reduces the base case to
reflexivity; congruence lifts the induction hypothesis through `Cons`. The recursive proof decreases
`xs`. Logic sees the reflected total definition of the same `append`, not a separately handwritten
append specification. Ghost uses do not duplicate owned runtime lists; erasure must enforce this.
Nothing here has been machine checked, and this theorem says nothing about a faulty list allocator.
It demonstrates inductive algorithm reasoning, not a claim that a nontrivial systems proof is this easy.
A substantive next proof target is binary search with interval invariants, termination and overflow
obligations; see the validation plan rather than pretending it is solved by an empty proof block.

## 17. CPU parallelism

```grl
let transformed = cpu.map(&samples, mem, fn(x) { transform(x) })?
```

An explicitly parallel library operation. Callback effects/footprints must permit independence;
sequential fallback is allowed only if the API does not require concurrency for progress. Compiler
chooses grain sizes. Ordered result construction, failure selection and allocation behavior need semantics.

## 18–19. GPU work and hardware placement

```grl
fn accelerate(gpu: &Device[Gpu], host: &Buffer[F32, Host]) !Buffer[F32, Host] {
    let input = gpu.upload(host)?
    let output = gpu.map(&input, fn(x) { x * x })?
    return gpu.download(&output)?
}
```

`upload` returns `Buffer[F32,Gpu]` only once transfer completion makes access valid; it may suspend.
A later explicit async transfer API would yield a pending token that retains source ownership/loans.
Host cannot directly index a device buffer. Device kernels are a restricted checked subset; allocation
and capacity admission are fallible. Kernel/backend float semantics and transfer cost remain visible.

## 20. Foreign boundary

```grl
extern "C" fn c_crc(ptr: RawPtr[U8], len: USize) U32

fn crc(data: &Bytes) U32 {
    unsafe { c_crc(data.raw_ptr(), data.len) }
}
```

The wrapper is safe only under an explicitly recorded foreign contract: reads exactly the valid
range, does not retain/free/mutate the pointer, respects ABI, and does not unwind. `unsafe` is not
a proof of that contract; this dependency is listed as assumed until independently validated.
LLVM compatibility alone supplies neither borrow preservation nor whole-program verification.
