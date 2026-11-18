// The NEON forms of the native SIMD lowering (machine.grl simd_a64_packed, docs/design/simd.md S3
// and S4), held against clang by `bun tools/asm-oracle.mjs --suite`.
.text
.globl f
f:
ldr q0,[x1,#16]
ldr q1,[x2,#0]
str q3,[x0,#32]
ldr q17,[x9,#4080]
fadd v0.4s,v0.4s,v1.4s
fsub v0.2d,v0.2d,v1.2d
fmul v0.4s,v0.4s,v1.4s
fdiv v0.2d,v0.2d,v1.2d
add v0.16b,v0.16b,v1.16b
add v0.4s,v0.4s,v1.4s
sub v0.2d,v0.2d,v1.2d
mul v0.4s,v0.4s,v1.4s
mul v0.16b,v0.16b,v1.16b
and v0.16b,v0.16b,v1.16b
orr v0.16b,v0.16b,v1.16b
eor v0.16b,v0.16b,v1.16b
bsl v2.16b,v1.16b,v0.16b
fcmeq v3.4s,v0.4s,v0.4s
fcmge v0.2d,v1.2d,v0.2d
fcmgt v2.4s,v0.4s,v1.4s
cmeq v0.16b,v0.16b,v1.16b
cmgt v0.4s,v1.4s,v0.4s
cmge v0.2d,v0.2d,v1.2d
cmhi v0.16b,v1.16b,v0.16b
cmhs v0.4s,v0.4s,v1.4s
smin v0.4s,v0.4s,v1.4s
smax v0.16b,v0.16b,v1.16b
umin v0.16b,v0.16b,v1.16b
umax v0.4s,v0.4s,v1.4s
not v0.16b,v0.16b
scvtf v0.4s,v0.4s
dup v0.4s,v0.s[0]
dup v0.2d,x9
dup v0.4s,w9
dup v0.16b,w9
ext v1.16b,v0.16b,v0.16b,#8
faddp s0,v0.2s
faddp d0,v0.2d
umaxv b0,v0.16b
uminv b0,v0.16b
umov w9,v0.b[0]
fmla v2.4s,v0.4s,v1.4s
fmla v2.2d,v0.2d,v1.2d
fmla v18.4s,v16.4s,v17.4s
ret
movi d0,#0
movi d24,#0
