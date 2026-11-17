// macOS arm64 compact unwind: frame-pointer frames with x19-x22 pairs, frameless frames with and without a stack.
.build_version macos, 11, 0
.text
.globl _f
.p2align 2
_f:
.cfi_startproc
stp x29,x30,[sp,#-16]!
mov x29,sp
.cfi_def_cfa w29, 16
.cfi_offset w30, -8
.cfi_offset w29, -16
bl _g
ldp x29,x30,[sp],#16
ret
.cfi_endproc
.globl _g
_g:
.cfi_startproc
ret
.cfi_endproc
L_h:
.cfi_startproc
mov x0,x0
ret
.cfi_endproc
.text
_a:
.cfi_startproc
sub sp,sp,#32
.cfi_def_cfa_offset 32
add sp,sp,#32
ret
.cfi_endproc
_b:
.cfi_startproc
stp x20,x19,[sp,#-32]!
stp x29,x30,[sp,#16]
add x29,sp,#16
.cfi_def_cfa w29, 16
.cfi_offset w30, -8
.cfi_offset w29, -16
.cfi_offset w19, -24
.cfi_offset w20, -32
ret
.cfi_endproc
_c:
.cfi_startproc
.cfi_def_cfa w29, 16
.cfi_offset w30, -8
.cfi_offset w29, -16
.cfi_offset w19, -24
.cfi_offset w20, -32
.cfi_offset w21, -40
.cfi_offset w22, -48
ret
.cfi_endproc
