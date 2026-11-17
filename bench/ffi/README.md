# FFI call cost against C (docs/ffi.md, "Call cost against C")

`cc -O2 -c fb.c -o fb.o && cc -O2 twin.c fb.o -o twin` builds the C twin (`./twin N` runs row N).
`rowN.grl` is the same loop in Grail, linked against `fb.o` (`lib "fb.o"`): build it native and with
`--backend=llvm`, count user instructions (perf_event), subtract row 0 (the empty loop) and divide
by 10 M. Rows: 0 empty, 1 scalars, 2 byval 16 B, 3 byval {f64,i64}, 4 byval 24 B, 5 record result,
6 f64, 7 f32, 8 &[u8], 9 a callback per call, 10 a callback loop inside C.
