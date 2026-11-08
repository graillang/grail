# Exclusive views and reborrowing

`&mut data` grants exclusive byte access. `data[index] = byte` or `write(view,index,byte)` writes
through that access. A readonly child can temporarily suspend its exclusive parent; the parent's
access resumes after the child's last use.

{{example:mutable-views}}

This is a reborrow, not an independent second exclusive permission. You cannot write through
`writer` while its readonly child is still used later. Nor can you create unrelated mutable views of
the same live storage and treat them as disjoint.

Mutable access is never implicit. A function that changes bytes takes `&mut [u8]`, and every caller
writes `&mut`:

```grl
fn fill(data: &mut [u8], value: u8) {
    for i in data.len() {
        data[i] = value;
    }
}
fill(&mut data, 9);
```

`&mut data` is a byte view, not deep mutable access to everything reachable from `data`. Vectors,
records, maps and scalars still pass `borrow_mut(owner)` in this preview; the approved model spells
those `&mut owner` as well.

**Try it:** move the assertion using `reader` below the `write`. The compiler should reject it.
