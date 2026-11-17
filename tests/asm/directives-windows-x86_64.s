// Windows (COFF) forms the compiler and runtime write: .def/.scl/.type/.endef, .seh_*, the
// $a/$b/$z data sections, weak externals, indirect calls through import thunks.
.text
.def f
.scl 2
.type 32
.endef
.globl f
f:
.seh_proc f
pushq %rbp
.seh_pushreg %rbp
movq %rsp,%rbp
.seh_setframe %rbp, 0
subq $.F1,%rsp
.seh_stackalloc 80
.seh_endprologue
call g
call *__imp_VirtualAlloc(%rip)
movdqu %xmm6,0(%rsp)
movdqu 16(%rsp),%xmm15
call .Dw
leaq .Ls(%rip),%rax
leaq d(%rip),%rax
movq %rbp,%rsp
popq %rbp
ret
.seh_endproc
.def h
.scl 3
.type 32
.endef
h:
ret
.set .F1,80
.pushsection .rodata
.Ls: .asciz "hi"
.quad f
.quad .Ls
.popsection
.bss
d: .zero 16
.section grail_sites$a,"dr"
__start_grail_sites:
.section grail_sites$b,"dr"
.quad h
.weak .Dw
