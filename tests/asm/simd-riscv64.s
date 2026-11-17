// The RV64 forms of the native SIMD lowering (machine.grl, docs/design/simd.md S4: mul_add),
// held against clang by `bun tools/asm-oracle.mjs --suite`.
.text
.globl f
f:
fmadd.s ft0,ft0,ft1,ft2
fmadd.d ft0,ft0,ft1,ft2
fmadd.d fa0,fa1,fa2,fa3
fmadd.s ft3,ft4,ft5,ft6
ret
