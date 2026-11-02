# Records, fields and vectors

Records have named, explicitly typed fields. Moving one owned field does not move its siblings.
The remaining fields are still released when the record ends.

{{example:records}}

`vec<T>()` creates an owned vector. `vec_push` consumes an element, `vec_pop` removes and returns
one, and `vec_get` returns a typed reference rather than copying an arbitrary element.

{{example:vectors}}

`load(slot)` copies a numeric element. After the reference's last use, growth may reallocate the
vector. `vec_get_mut` grants mutable element storage when exclusive access is available.
Popping an empty vector or indexing out of bounds aborts. Vectors of owners recursively drop their
remaining elements; callers own popped elements.

**Try it:** use `vec<bytes>()`, push `bytes()`, and inspect the popped buffer's length.
