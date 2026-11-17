// The packed SSE2 forms machine.grl's native SIMD lowering writes (docs/design/simd.md S3), each
// encoded once against clang; tools/lint-asm-ids.mjs requires every mnemonic here.
.text
f:
movups (%rdi),%xmm0
movups %xmm0,16(%rsi)
movups (%rax,%rcx,4),%xmm1
addps %xmm1,%xmm0
subps %xmm1,%xmm0
mulps %xmm1,%xmm0
divps %xmm1,%xmm0
addpd %xmm1,%xmm0
subpd %xmm1,%xmm0
mulpd %xmm1,%xmm0
divpd %xmm1,%xmm0
andps %xmm1,%xmm0
andnps %xmm1,%xmm0
orps %xmm1,%xmm0
paddd %xmm1,%xmm0
psubd %xmm1,%xmm0
paddq %xmm1,%xmm0
psubq %xmm1,%xmm0
paddb %xmm1,%xmm0
psubb %xmm1,%xmm0
pcmpeqd %xmm1,%xmm0
pcmpgtd %xmm1,%xmm0
pcmpeqb %xmm1,%xmm0
pcmpgtb %xmm1,%xmm0
cmpps $1,%xmm1,%xmm0
cmppd $2,%xmm1,%xmm0
shufps $27,%xmm1,%xmm0
pshufd $78,%xmm1,%xmm0
movhlps %xmm1,%xmm0
movlhps %xmm1,%xmm0
movmskps %xmm0,%eax
movmskpd %xmm0,%eax
pminub %xmm1,%xmm0
pmaxub %xmm1,%xmm0
pmovmskb %xmm0,%eax
cvtdq2ps %xmm0,%xmm0
addps %xmm9,%xmm12
vfmadd231ps %xmm1,%xmm0,%xmm2
vfmadd231pd %xmm9,%xmm12,%xmm10
vfmadd231ps %xmm15,%xmm8,%xmm3
vfmadd231pd %xmm2,%xmm13,%xmm14
ret
