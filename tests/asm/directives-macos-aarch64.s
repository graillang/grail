// macOS arm64 (Mach-O): sections, @PAGE/@PAGEOFF, L temporaries, weak definitions, NOP-padded code alignment.
.build_version macos, 11, 0
.set .F1,80
.text
.globl _main
.p2align 2
_main:
sub sp,sp,#.F1
adrp x13,Lc@PAGE
add x13,x13,Lc@PAGEOFF
adrp x13,_rt_state@PAGE
add x13,x13,_rt_state@PAGEOFF
adrp x13,_rt_state@PAGE+8
add x13,x13,_rt_state@PAGEOFF+8
bl _exit
bl _g
b Lx
Lx:
ret
_g:
ret
.weak_definition _w
_w:
ret
.pushsection __TEXT,__const
.p2align 3
Lc: .byte 1
.quad _main
.quad Lc
.popsection
.section __DATA,__bss
.p2align 4
_rt_state: .space 4096
.text
.p2align 4
_tail:
ret
