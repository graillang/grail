Micro-benchmark for docs/design/unboxed-values.md: 1M three-field records in a vector, built by
`push`, then 20 passes of transform-in-place and sum. `aos` is `{x,y,z: f32}`, `aosu` its `u64`
twin (the native backend calls the runtime for every float operation, so the integer twin is the
one that isolates layout), `aosu_shuf` shuffles the vector first, `soa`/`soau` are the same work
over three columns, and the `.c` files are the reference. Build each with both backends
(`compileProgram` in tools/native.mjs, `overflow: 'wrap'`) and time the best of three.
