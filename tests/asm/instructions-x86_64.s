// Every x86-64 instruction the internal assembler names, each encoded at least once in the forms
// the compiler writes, held against clang by the asm-oracle suite; tools/lint-asm-ids.mjs fails
// when a mnemonic in compiler/asm_x86.grl has no line here.
.text
.globl f
f:
movq %rax,%rbx
movq 8(%rbp),%r12
movq %r13,-16(%rbp)
movq $5,%rcx
movq $-1,%rax
movq $0,(%r8)
movq (%r12,%rbx,8),%rax
movq %xmm9,%r12
movq %r13,%xmm10
movl %eax,%ecx
movl (%rbx,%rsi,4),%eax
movl $1,%eax
movl $1,g(%rip)
movb %al,(%rdi)
movb 3(%rsi),%cl
movw %ax,(%rdi)
movw 2(%rsi),%cx
movabsq $1099511627776,%rax
movzbq (%r14,%rsi,1),%rax
movzbq %al,%rax
movzwq (%r8,%r9,2),%rcx
movsbq %al,%rax
movswq (%rax),%rcx
movslq %eax,%rcx
movd %eax,%xmm0
movd %xmm0,%eax
movaps %xmm8,%xmm14
leaq 8(%rbp),%rax
leaq g(%rip),%rax
leaq (%r12,%rsi,8),%rax
addq $1,%rax
addq $1000,%rax
addq $1000,%rcx
addq %rbx,%rax
orq %rbx,%rax
orq $16,%rcx
andq $-8,%rsp
andq %rbx,%rax
subq $40,%rsp
subq $.F1,%rsp
xorq %rax,%rax
cmpq $5,-8(%rbp)
cmpq %r13,%rsi
cmpq 8(%r9),%rax
testq %rcx,%rcx
xorl %eax,%eax
andb %cl,%al
pushq %rbp
pushq %r12
popq %r12
popq %rbp
leave
syscall
ud2
mfence
sfence
lfence
lock cmpxchgq %rcx,(%rdi)
lock xaddq %rax,(%rdi)
rep stosq
xchgq %rax,(%rdi)
call g
call *%rax
jmp *%rax
jmp .Lx
.Lx:
divq %rcx
idivq %rcx
mulq %rcx
imulq %rcx,%rax
imulq $24,%rax
incq %rax
decq %rax
negq %r9
notq %rax
shrq $3,%rax
shrq $1,%rax
shlq $5,%r10
shlq %cl,%rax
sarq $3,%rax
addsd %xmm1,%xmm0
subsd %xmm1,%xmm0
mulsd %xmm1,%xmm0
divsd %xmm1,%xmm0
sqrtsd %xmm1,%xmm0
ucomisd %xmm1,%xmm0
cvtsi2sdq %rax,%xmm0
cvttsd2si %xmm0,%rax
cvtsd2ss %xmm8,%xmm2
cvtss2sd %xmm11,%xmm12
addss %xmm9,%xmm10
subss %xmm1,%xmm0
mulss %xmm1,%xmm0
divss %xmm1,%xmm0
sqrtss %xmm1,%xmm0
ucomiss %xmm1,%xmm0
cvttss2si %xmm0,%rax
cvtsi2ssq %rax,%xmm0
movsd (%rax),%xmm0
movsd %xmm12,8(%r12)
movss (%rax),%xmm0
movss 4(%rbx,%rsi,4),%xmm8
movss %xmm9,(%rcx)
movss %xmm12,8(%r12)
movss %xmm1,%xmm8
movzbl %al,%eax
movzwl %cx,%eax
pause
xorps %xmm8,%xmm8
movdqu %xmm6,0(%rsp)
movdqu 16(%rsp),%xmm15
addl $1,%eax
addl $1000,%ecx
subl $1,%eax
lock incl g(%rip)
lock xaddl %eax,g(%rip)
cmovaq %rcx,%rax
cmovgeq (%rdi),%rax
sete %al
setne %cl
je .Lx
jne .Ly
.Ly:
ret
.set .F1,64
.bss
g: .zero 16
