# Readonly views and slices

`read(owner)` creates a readonly byte view. The view has a descriptor but does not own the
underlying bytes; it retains a checked relationship to their owner. `slice(view,start,end)`
uses a half-open range: start is included and end is excluded.

{{example:views}}

The slice contains only the middle byte. Bounds are checked at runtime. Slices and views do not
make their source immortal: their existence constrains when the owner may move, grow or end.

Readonly view derivation can copy a descriptor while retaining its provenance. That is different
from copying an owning buffer, and different from duplicating an exclusive view.

**Try it:** slice `0,3` instead, then return the first byte. Do not read index 3 from that view.
