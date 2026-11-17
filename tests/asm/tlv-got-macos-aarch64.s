// macOS arm64: GOT and thread-local-variable loads (@GOTPAGE/@GOTPAGEOFF, @TLVPPAGE/@TLVPPAGEOFF), __thread_bss/__thread_vars, a compact-unwind frame.
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
adrp x0,_ext@GOTPAGE
ldr x0,[x0,_ext@GOTPAGEOFF]
adrp x0,_tv@TLVPPAGE
ldr x0,[x0,_tv@TLVPPAGEOFF]
ldr x8,[x0]
blr x8
ldp x29,x30,[sp],#16
ret
.cfi_endproc
.globl _g
.p2align 2
_g:
.cfi_startproc
ret
.cfi_endproc
.section __DATA,__thread_bss,thread_local_zerofill
.p2align 3
_tv$tlv$init:
.space 8
.section __DATA,__thread_vars,thread_local_variables
.globl _tv
_tv:
.quad __tlv_bootstrap
.quad 0
.quad _tv$tlv$init
