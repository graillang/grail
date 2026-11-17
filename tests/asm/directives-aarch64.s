// Every ELF directive the compiler, its runtime and the LLVM backend's native half write, in the
// forms they write them: the internal assembler's object must equal clang's
// (`bun tools/asm-oracle.mjs --suite`, the landing suite `asm-oracle`). A new directive in an emitter goes here too.
.set .Fx,64
.text
.globl f
.type f,@function
.hidden f
f:
sub sp,sp,#.Fx
adrp x9,g_guard
add x9,x9,:lo12:g_guard
bl h
csel x11,x10,x9,hi
yield
ret
.weak h
.globl g
.protected g
.type g,@function
g:
ret
.internal k
.globl k
k:
ret
.comm g_guard,8,8
.pushsection .rodata
.p2align 3
.Ls: .asciz "s\n\"q"
.ascii "ab"
.byte 1,2
.short 3
.word 4
.long 5
.quad .Ls
.quad f+8
.balign 8
.zero 3
.popsection
.data
.p2align 3
d: .quad 7
.bss
.p2align 4
b: .zero 16
.section .tbss,"awT",@nobits
.p2align 3
t: .zero 8
.section grail_sites,"a"
.quad .Ls
.section .note.GNU-stack,"",@progbits
