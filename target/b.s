.text
.type f_main_main,@function
f_main_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1,%rsp
subq $48,%rsp
movq %rbx,-.F1-8(%rbp)
movq %r12,-.F1-16(%rbp)
movq %r13,-.F1-24(%rbp)
movq %r14,-.F1-32(%rbp)
movq %r15,-.F1-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
leaq -.F1(%rbp),%rdi
movq $.F1/8-0,%rcx
xorl %eax,%eax
rep stosq
call rt_new
movq %rax,-8(%rbp)
movq $1,-16(%rbp)
movabsq $2,%rdi
call rt_rec
movq %rax,-24(%rbp)
movq %rax,%rcx
movq $1,0(%rcx)
movq $2,8(%rcx)
movq $1,-32(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt1
call rt_push
jmp .Lopt2
.Lopt1:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt2:
movabsq $2,%rdi
call rt_rec
movq %rax,-40(%rbp)
movq %rax,%rcx
movq $3,0(%rcx)
movq $4,8(%rcx)
movq $1,-48(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt3
call rt_push
jmp .Lopt4
.Lopt3:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt4:
movq -8(%rbp),%rax
movq %rax,-56(%rbp)
movq $0,-16(%rbp)
movq $1,-64(%rbp)
cmpq $0,-48(%rbp)
je .L2
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D16
.L2:
cmpq $0,-32(%rbp)
je .L3
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D16
.L3:
cmpq $0,-16(%rbp)
je .L4
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D17
.L4:
leaq -56(%rbp),%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-80(%rbp)
movq $0,%r13
.L5:
movq -80(%rbp),%rcx
cmpq %rcx,%r13
jae .L7
movq -72(%rbp),%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt5
call rt_abort
.Lopt5:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
movq 0(%rax),%rax
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.L6:
incq %r13
jmp .L5
.L7:
movq -56(%rbp),%rax
movq %rax,-96(%rbp)
movq $0,-64(%rbp)
movq $1,-104(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-112(%rbp)
movq $0,%r14
.L8:
movq -112(%rbp),%rcx
cmpq %rcx,%r14
jae .L10
movq -96(%rbp),%rdi
movq %r14,%rsi
movq $0,%r10
movq $0,%r11
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt13_i1
call rt_abort
.Lopt13_i1:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq %rax,%r10
movq (%rax),%rax
movq %rax,%r11
movq %r10,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r11,%rax
jmp .Lret_i1
xorq %rax,%rax
jmp .Lret_i1
.Lret_i1:
movq %rax,%r12
movq $1,%rbx
movq 8(%rax),%rax
movq %rax,-120(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
cmpq $0,%rbx
je .L11
movq $0,%rbx
movq %r12,%rdi
call .D16
.L11:
.L9:
incq %r14
jmp .L8
.L10:
cmpq $0,%rbx
je .L12
movq $0,%rbx
movq %r12,%rdi
call .D16
.L12:
cmpq $0,-104(%rbp)
je .L13
movq $0,-104(%rbp)
movq -96(%rbp),%rdi
call .D17
.L13:
cmpq $0,%rbx
je .L14
movq $0,%rbx
movq %r12,%rdi
call .D16
.L14:
call rt_new
movq %rax,-128(%rbp)
movq $1,-136(%rbp)
movq %rax,%rdi
movabsq $7,%rsi
call rt_pushb_checked
movq -128(%rbp),%rdi
movabsq $8,%rsi
call rt_pushb_checked
movq -128(%rbp),%rax
movq %rax,-144(%rbp)
movq $0,-136(%rbp)
movq $1,-152(%rbp)
cmpq $0,-136(%rbp)
je .L15
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D2
.L15:
leaq -144(%rbp),%rax
movq (%rax),%rax
movq %rax,-160(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-168(%rbp)
movq $0,%r15
.L16:
movq -168(%rbp),%rcx
cmpq %rcx,%r15
jae .L18
movq -160(%rbp),%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt6
call rt_abort
.Lopt6:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-176(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.L17:
incq %r15
jmp .L16
.L18:
leaq -144(%rbp),%rax
movq (%rax),%rax
movq %rax,-184(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-192(%rbp)
movq $0,-200(%rbp)
.L19:
movq -192(%rbp),%rcx
movq -200(%rbp),%rax
cmpq %rcx,%rax
jae .L21
movq -184(%rbp),%rdi
movq -200(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt7
call rt_abort
.Lopt7:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-208(%rbp)
movabsq $1,%rcx
addq $1,%rax
jnc .L22
call rt_abort
.L22:
movq %rax,-216(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.L20:
incq -200(%rbp)
jmp .L19
.L21:
.pushsection .rodata
.L23:
.byte 104
.byte 105
.byte 0
.popsection
leaq .L23(%rip),%rax
movq %rax,-224(%rbp)
movq %rax,%rdi
movabsq $2,%rsi
call rt_string_lit
movq %rax,-232(%rbp)
movq $1,-240(%rbp)
movq %rax,-248(%rbp)
movq $0,-240(%rbp)
movq $1,-256(%rbp)
cmpq $0,-240(%rbp)
je .L24
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D3
.L24:
leaq -248(%rbp),%rax
movq (%rax),%rax
movq %rax,-264(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-272(%rbp)
movq $0,-280(%rbp)
.L25:
movq -272(%rbp),%rcx
movq -280(%rbp),%rax
cmpq %rcx,%rax
jae .L27
movq -264(%rbp),%rdi
movq -280(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt8
call rt_abort
.Lopt8:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-288(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.L26:
incq -280(%rbp)
jmp .L25
.L27:
.pushsection .rodata
.L28:
.byte 97
.byte 98
.byte 0
.popsection
leaq .L28(%rip),%rax
movq %rax,-296(%rbp)
movq %rax,%rdi
movabsq $2,%rsi
call rt_string_lit
movq %rax,-304(%rbp)
movq $1,-312(%rbp)
movq %rax,-320(%rbp)
movq $0,-312(%rbp)
movq $1,-328(%rbp)
leaq -320(%rbp),%rax
movq %rax,-336(%rbp)
cmpq $0,-312(%rbp)
je .L29
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L29:
movq -336(%rbp),%rax
movq (%rax),%rax
movq %rax,-344(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-352(%rbp)
movq $0,-360(%rbp)
.L30:
movq -352(%rbp),%rcx
movq -360(%rbp),%rax
cmpq %rcx,%rax
jae .L32
movq -344(%rbp),%rdi
movq -360(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt9
call rt_abort
.Lopt9:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-368(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.L31:
incq -360(%rbp)
jmp .L30
.L32:
movq $0,-376(%rbp)
cmpq $0,-328(%rbp)
je .L33
movq $0,-328(%rbp)
movq -320(%rbp),%rdi
call .D3
.L33:
cmpq $0,-312(%rbp)
je .L34
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L34:
cmpq $0,-256(%rbp)
je .L35
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D3
.L35:
cmpq $0,-240(%rbp)
je .L36
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D3
.L36:
cmpq $0,-152(%rbp)
je .L37
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D2
.L37:
cmpq $0,-136(%rbp)
je .L38
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D2
.L38:
cmpq $0,%rbx
je .L39
movq %r12,%rdi
call .D16
.L39:
cmpq $0,-104(%rbp)
je .L40
movq $0,-104(%rbp)
movq -96(%rbp),%rdi
call .D17
.L40:
cmpq $0,-64(%rbp)
je .L41
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D17
.L41:
cmpq $0,-48(%rbp)
je .L42
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D16
.L42:
cmpq $0,-32(%rbp)
je .L43
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D16
.L43:
cmpq $0,-16(%rbp)
je .L44
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D17
.L44:
movq -376(%rbp),%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
movq -.F1-24(%rbp),%r13
movq -.F1-32(%rbp),%r14
movq -.F1-40(%rbp),%r15
leave
ret
cmpq $0,-328(%rbp)
je .L45
movq $0,-328(%rbp)
movq -320(%rbp),%rdi
call .D3
.L45:
cmpq $0,-312(%rbp)
je .L46
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L46:
cmpq $0,-256(%rbp)
je .L47
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D3
.L47:
cmpq $0,-240(%rbp)
je .L48
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D3
.L48:
cmpq $0,-152(%rbp)
je .L49
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D2
.L49:
cmpq $0,-136(%rbp)
je .L50
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D2
.L50:
cmpq $0,%rbx
je .L51
movq $0,%rbx
movq %r12,%rdi
call .D16
.L51:
cmpq $0,-104(%rbp)
je .L52
movq $0,-104(%rbp)
movq -96(%rbp),%rdi
call .D17
.L52:
cmpq $0,-64(%rbp)
je .L53
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D17
.L53:
cmpq $0,-48(%rbp)
je .L54
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D16
.L54:
cmpq $0,-32(%rbp)
je .L55
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D16
.L55:
cmpq $0,-16(%rbp)
je .L56
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D17
.L56:
cmpq $0,-328(%rbp)
je .L57
movq $0,-328(%rbp)
movq -320(%rbp),%rdi
call .D3
.L57:
cmpq $0,-312(%rbp)
je .L58
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L58:
cmpq $0,-256(%rbp)
je .L59
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D3
.L59:
cmpq $0,-240(%rbp)
je .L60
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D3
.L60:
cmpq $0,-152(%rbp)
je .L61
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D2
.L61:
cmpq $0,-136(%rbp)
je .L62
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D2
.L62:
cmpq $0,%rbx
je .L63
movq %r12,%rdi
call .D16
.L63:
cmpq $0,-104(%rbp)
je .L64
movq $0,-104(%rbp)
movq -96(%rbp),%rdi
call .D17
.L64:
cmpq $0,-64(%rbp)
je .L65
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D17
.L65:
cmpq $0,-48(%rbp)
je .L66
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D16
.L66:
cmpq $0,-32(%rbp)
je .L67
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D16
.L67:
cmpq $0,-16(%rbp)
je .L68
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D17
.L68:
xorq %rax,%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
movq -.F1-24(%rbp),%r13
movq -.F1-32(%rbp),%r14
movq -.F1-40(%rbp),%r15
leave
ret
.set .F1,384
.type rt_abort,@function
rt_abort:
pushq %rbp
movq %rsp,%rbp
subq $.F69,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movabsq $39,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-8(%rbp)
movabsq $62,%rdi
movq -8(%rbp),%rsi
movabsq $6,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $60,%rdi
movabsq $134,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F69,16
.type rt_error,@function
rt_error:
pushq %rbp
movq %rsp,%rbp
subq $.F70,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F70,16
.type rt_div,@function
rt_div:
pushq %rbp
movq %rsp,%rbp
subq $.F71,%rsp
subq $48,%rsp
movq %rbx,-.F71-8(%rbp)
movq %r12,-.F71-16(%rbp)
movq %r13,-.F71-24(%rbp)
movq %r14,-.F71-32(%rbp)
movq %r15,-.F71-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L72
call rt_abort
jmp .L73
.L72:
.L73:
movq $0,-24(%rbp)
movq -8(%rbp),%rax
movq %rax,-32(%rbp)
.L74:
movq -32(%rbp),%rax
movq -16(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L75
movq -16(%rbp),%rax
movq %rax,%rbx
movq $1,%r12
.L76:
movq %rbx,%rax
addq %rbx,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%r14
movq %rbx,%rax
addq %rbx,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq %r14,%rax
andq %rcx,%rax
testq %rax,%rax
jz .L77
movq %rbx,%rax
addq %rbx,%rax
jnc .L78
call rt_abort
.L78:
movq %rax,%rbx
movq %r12,%rax
addq %r12,%rax
jnc .L79
call rt_abort
.L79:
movq %rax,%r12
jmp .L76
.L77:
movq -32(%rbp),%rax
subq %rbx,%rax
jnc .L80
call rt_abort
.L80:
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
addq %r12,%rax
jnc .L81
call rt_abort
.L81:
movq %rax,-24(%rbp)
jmp .L74
.L75:
movq -24(%rbp),%rax
movq -.F71-8(%rbp),%rbx
movq -.F71-16(%rbp),%r12
movq -.F71-24(%rbp),%r13
movq -.F71-32(%rbp),%r14
movq -.F71-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F71-8(%rbp),%rbx
movq -.F71-16(%rbp),%r12
movq -.F71-24(%rbp),%r13
movq -.F71-32(%rbp),%r14
movq -.F71-40(%rbp),%r15
leave
ret
.set .F71,48
.type rt_allocator_lock,@function
rt_allocator_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F82,%rsp
subq $16,%rsp
movq %rbx,-.F82-8(%rbp)
movq %r12,-.F82-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
addq $64,%rax
jnc .L83
call rt_abort
.L83:
movq %rax,%r12
.L84:
movq %r12,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%rbx
cmpq $0,%rax
je .L85
jmp .L84
.L85:
movabsq $0,%rax
movq -.F82-8(%rbp),%rbx
movq -.F82-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F82-8(%rbp),%rbx
movq -.F82-16(%rbp),%r12
leave
ret
.set .F82,16
.type rt_allocator_unlock,@function
rt_allocator_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F86,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $64,%rcx
movq -8(%rbp),%rax
addq $64,%rax
jnc .L87
call rt_abort
.L87:
movq %rax,-16(%rbp)
movq -16(%rbp),%rdi
movabsq $0,%rax
sfence
movq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F86,16
.type rt_alloc,@function
rt_alloc:
pushq %rbp
movq %rsp,%rbp
subq $.F88,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
call rt_allocator_lock
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_alloc_unlocked
movq %rax,-16(%rbp)
call rt_allocator_unlock
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F88,16
.type rt_free,@function
rt_free:
pushq %rbp
movq %rsp,%rbp
subq $.F89,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
call rt_allocator_lock
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free_unlocked
call rt_allocator_unlock
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F89,16
.type rt_alloc_unlocked,@function
rt_alloc_unlocked:
pushq %rbp
movq %rsp,%rbp
subq $.F90,%rsp
subq $48,%rsp
movq %rbx,-.F90-8(%rbp)
movq %r12,-.F90-16(%rbp)
movq %r13,-.F90-24(%rbp)
movq %r14,-.F90-32(%rbp)
movq %r15,-.F90-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F90(%rbp),%rdi
movq $.F90/8-1,%rcx
xorl %eax,%eax
rep stosq
leaq rt_state(%rip),%rax
movq %rax,%r14
movq -8(%rbp),%rcx
movabsq $1152921504606846976,%rax
cmpq %rcx,%rax
jae .L91
call rt_abort
jmp .L92
.L91:
.L92:
movq $32,%rbx
movq $0,%r13
.L93:
movq -8(%rbp),%rax
addq $16,%rax
jnc .L95
call rt_abort
.L95:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L94
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L96
call rt_abort
.L96:
movq %rax,%rbx
movq %r13,%rax
addq $1,%rax
jnc .L97
call rt_abort
.L97:
movq %rax,%r13
jmp .L93
.L94:
movq %r14,%rax
addq $256,%rax
jnc .L98
call rt_abort
.L98:
movq %rax,-16(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L99
call rt_abort
.L99:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L100
call rt_abort
.L100:
movq %rax,-24(%rbp)
movq (%rax),%rax
movq %rax,%r15
movq $0,-32(%rbp)
cmpq $0,%rax
je .L101
movq %r15,%rax
addq $8,%rax
jnc .L103
call rt_abort
.L103:
movq (%rax),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $1,-32(%rbp)
jmp .L102
.L101:
movq %r14,%rax
addq $768,%rax
jnc .L104
call rt_abort
.L104:
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L105
call rt_abort
.L105:
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L106
call rt_abort
.L106:
movq %rax,-48(%rbp)
movq %r14,%rax
addq $1280,%rax
jnc .L107
call rt_abort
.L107:
movq %rax,-56(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L108
call rt_abort
.L108:
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L109
call rt_abort
.L109:
movq %rax,-64(%rbp)
movq (%rax),%rax
movq %rax,-72(%rbp)
cmpq $0,%rax
jne .L110
movq $1048576,-80(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L112
call rt_abort
.L112:
movq %rax,%rcx
movabsq $1048576,%rax
cmpq %rcx,%rax
jae .L113
movabsq $16,%rcx
movq %rbx,%rax
addq $16,%rax
jnc .L115
call rt_abort
.L115:
movq %rax,-80(%rbp)
jmp .L114
.L113:
.L114:
movq -80(%rbp),%rax
movq %rax,%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,-88(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i2
xorq %rax,%rax
jmp .Lret_i2
.Lret_i2:
testq %rax,%rax
jz .L116
call rt_abort
jmp .L117
.L116:
.L117:
movq %r14,%rax
addq $32,%rax
jnc .L118
call rt_abort
.L118:
movq (%rax),%rax
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rcx,%rax
addq $8,%rax
jnc .L119
call rt_abort
.L119:
movq %rax,-96(%rbp)
movq -80(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r14,%rax
addq $32,%rax
jnc .L120
call rt_abort
.L120:
movq %rax,-104(%rbp)
movq -88(%rbp),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $16,%rax
jnc .L121
call rt_abort
.L121:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $16,%rcx
movq -80(%rbp),%rax
subq $16,%rax
jnc .L122
call rt_abort
.L122:
movq %rax,-112(%rbp)
movq -112(%rbp),%rdi
movq %rbx,%rsi
call rt_div
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L111
.L110:
.L111:
movq -48(%rbp),%rax
movq (%rax),%rax
movq %rax,%r15
addq %rbx,%rax
jnc .L123
call rt_abort
.L123:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -64(%rbp),%rax
movq (%rax),%rax
movq %rax,-120(%rbp)
subq $1,%rax
jnc .L124
call rt_abort
.L124:
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
movq %r15,%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
.L102:
movq %r15,%rax
addq $8,%rax
jnc .L125
call rt_abort
.L125:
movq %rax,-128(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %r15,%rax
addq $16,%rax
jnc .L126
call rt_abort
.L126:
movq %rax,-136(%rbp)
movq -32(%rbp),%rax
testq %rax,%rax
jz .L127
movq $0,%r12
.L129:
movq %rbx,%rax
subq $16,%rax
jnc .L131
call rt_abort
.L131:
movq %rax,%rcx
cmpq %rcx,%r12
jae .L130
movq -136(%rbp),%rax
addq %r12,%rax
jnc .L132
call rt_abort
.L132:
movq %rax,-144(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r12,%rax
addq $8,%rax
jnc .L133
call rt_abort
.L133:
movq %rax,%r12
jmp .L129
.L130:
jmp .L128
.L127:
.L128:
movq %r14,%rax
addq $24,%rax
jnc .L134
call rt_abort
.L134:
movq %rax,-152(%rbp)
movq %r14,%rax
addq $24,%rax
jnc .L135
call rt_abort
.L135:
movq (%rax),%rax
movq %rax,-160(%rbp)
addq $1,%rax
jnc .L136
call rt_abort
.L136:
movq -152(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -136(%rbp),%rax
movq -.F90-8(%rbp),%rbx
movq -.F90-16(%rbp),%r12
movq -.F90-24(%rbp),%r13
movq -.F90-32(%rbp),%r14
movq -.F90-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F90-8(%rbp),%rbx
movq -.F90-16(%rbp),%r12
movq -.F90-24(%rbp),%r13
movq -.F90-32(%rbp),%r14
movq -.F90-40(%rbp),%r15
leave
ret
.set .F90,160
.type rt_free_unlocked,@function
rt_free_unlocked:
pushq %rbp
movq %rsp,%rbp
subq $.F137,%rsp
subq $48,%rsp
movq %rbx,-.F137-8(%rbp)
movq %r12,-.F137-16(%rbp)
movq %r13,-.F137-24(%rbp)
movq %r14,-.F137-32(%rbp)
movq %r15,-.F137-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F137(%rbp),%rdi
movq $.F137/8-1,%rcx
xorl %eax,%eax
rep stosq
movq -8(%rbp),%rax
cmpq $0,%rax
jne .L138
movabsq $0,%rax
movq -.F137-8(%rbp),%rbx
movq -.F137-16(%rbp),%r12
movq -.F137-24(%rbp),%r13
movq -.F137-32(%rbp),%r14
movq -.F137-40(%rbp),%r15
leave
ret
jmp .L139
.L138:
.L139:
leaq rt_state(%rip),%rax
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
subq $16,%rax
jnc .L140
call rt_abort
.L140:
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
addq $8,%rax
jnc .L141
call rt_abort
.L141:
movq (%rax),%rax
movq %rax,-40(%rbp)
cmpq $2,%rax
jne .L142
movabsq $0,%rax
movq -.F137-8(%rbp),%rbx
movq -.F137-16(%rbp),%r12
movq -.F137-24(%rbp),%r13
movq -.F137-32(%rbp),%r14
movq -.F137-40(%rbp),%r15
leave
ret
jmp .L143
.L142:
.L143:
movq -24(%rbp),%rax
addq $8,%rax
jnc .L144
call rt_abort
.L144:
movq (%rax),%rax
movq %rax,-48(%rbp)
movabsq $1,%rcx
cmpq $1,%rax
je .L145
call rt_abort
jmp .L146
.L145:
.L146:
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
cmpq $524288,%rax
setb %al
movzbq %al,%rax
movq %rax,-72(%rbp)
cmpq $0,%rax
jne .L147
movq -8(%rbp),%rax
subq $32,%rax
jnc .L149
call rt_abort
.L149:
movq %rax,%r14
movq -16(%rbp),%rax
addq $32,%rax
jnc .L150
call rt_abort
.L150:
movq %rax,%rbx
.L151:
movq %rbx,%rax
movq (%rax),%rax
cmpq %r14,%rax
je .L152
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%r15
movq %rax,-80(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L153
call rt_abort
jmp .L154
.L153:
.L154:
movq %r15,%rbx
jmp .L151
.L152:
movq %r14,%rax
addq $8,%rax
jnc .L155
call rt_abort
.L155:
movq (%rax),%rax
movq %rax,-88(%rbp)
movq %r14,%rax
movq (%rax),%rax
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
addq $24,%rax
jnc .L156
call rt_abort
.L156:
movq %rax,-96(%rbp)
movq -16(%rbp),%rax
addq $24,%rax
jnc .L157
call rt_abort
.L157:
movq (%rax),%rax
movq %rax,-104(%rbp)
subq $1,%rax
jnc .L158
call rt_abort
.L158:
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $11,%rdi
movq %r14,%rsi
movq -88(%rbp),%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i3
xorq %rax,%rax
jmp .Lret_i3
.Lret_i3:
testq %rax,%rax
jz .L159
call rt_abort
jmp .L160
.L159:
.L160:
movabsq $0,%rax
movq -.F137-8(%rbp),%rbx
movq -.F137-16(%rbp),%r12
movq -.F137-24(%rbp),%r13
movq -.F137-32(%rbp),%r14
movq -.F137-40(%rbp),%r15
leave
ret
jmp .L148
.L147:
.L148:
movq $32,%r12
movq $0,%r13
.L161:
movq -56(%rbp),%rcx
cmpq %rcx,%r12
jae .L162
movabsq $2,%rcx
movq %r12,%rax
mulq %rcx
jnc .L163
call rt_abort
.L163:
movq %rax,%r12
movq %r13,%rax
addq $1,%rax
jnc .L164
call rt_abort
.L164:
movq %rax,%r13
jmp .L161
.L162:
movq -16(%rbp),%rax
addq $256,%rax
jnc .L165
call rt_abort
.L165:
movq %rax,-112(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L166
call rt_abort
.L166:
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L167
call rt_abort
.L167:
movq %rax,-120(%rbp)
movq -24(%rbp),%rax
addq $8,%rax
jnc .L168
call rt_abort
.L168:
movq %rax,-128(%rbp)
movq -120(%rbp),%rax
movq (%rax),%rax
movq -128(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -24(%rbp),%rax
movq -120(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
addq $24,%rax
jnc .L169
call rt_abort
.L169:
movq %rax,-136(%rbp)
movq -16(%rbp),%rax
addq $24,%rax
jnc .L170
call rt_abort
.L170:
movq (%rax),%rax
movq %rax,-144(%rbp)
subq $1,%rax
jnc .L171
call rt_abort
.L171:
movq -136(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F137-8(%rbp),%rbx
movq -.F137-16(%rbp),%r12
movq -.F137-24(%rbp),%r13
movq -.F137-32(%rbp),%r14
movq -.F137-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F137-8(%rbp),%rbx
movq -.F137-16(%rbp),%r12
movq -.F137-24(%rbp),%r13
movq -.F137-32(%rbp),%r14
movq -.F137-40(%rbp),%r15
leave
ret
.set .F137,144
.type rt_grow,@function
rt_grow:
pushq %rbp
movq %rsp,%rbp
subq $.F172,%rsp
subq $48,%rsp
movq %rbx,-.F172-8(%rbp)
movq %r12,-.F172-16(%rbp)
movq %r13,-.F172-24(%rbp)
movq %r14,-.F172-32(%rbp)
movq %r15,-.F172-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movabsq $0,%rcx
cmpq $0,%r15
jne .L173
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq -.F172-8(%rbp),%rbx
movq -.F172-16(%rbp),%r12
movq -.F172-24(%rbp),%r13
movq -.F172-32(%rbp),%r14
movq -.F172-40(%rbp),%r15
leave
ret
jmp .L174
.L173:
.L174:
movq %r15,%rax
subq $16,%rax
jnc .L175
call rt_abort
.L175:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
cmpq $524288,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L176
movq -32(%rbp),%rax
movq %rax,%rbx
.L178:
movq -24(%rbp),%rax
addq $16,%rax
jnc .L180
call rt_abort
.L180:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L179
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L181
call rt_abort
.L181:
movq %rax,%rbx
jmp .L178
.L179:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jne .L182
movq %r15,%rax
movq -.F172-8(%rbp),%rbx
movq -.F172-16(%rbp),%r12
movq -.F172-24(%rbp),%r13
movq -.F172-32(%rbp),%r14
movq -.F172-40(%rbp),%r15
leave
ret
jmp .L183
.L182:
.L183:
call rt_allocator_lock
leaq rt_state(%rip),%rax
movq %rax,-56(%rbp)
movq %r15,%rax
subq $32,%rax
jnc .L184
call rt_abort
.L184:
movq %rax,-64(%rbp)
movq -56(%rbp),%rax
addq $32,%rax
jnc .L185
call rt_abort
.L185:
movq %rax,%r12
.L186:
movq %r12,%rax
movq (%rax),%rax
movq -64(%rbp),%rcx
cmpq %rcx,%rax
je .L187
movq %r12,%rax
movq (%rax),%rax
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
jne .L188
call rt_abort
jmp .L189
.L188:
.L189:
movq %r13,%r12
jmp .L186
.L187:
movq -64(%rbp),%rax
addq $8,%rax
jnc .L190
call rt_abort
.L190:
movq (%rax),%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L191
call rt_abort
.L191:
movq %rax,-80(%rbp)
movabsq $25,%rdi
movq -64(%rbp),%rsi
movq -72(%rbp),%rdx
movq %rax,%rcx
movabsq $1,%r8
call rt_syscall4
movq %rax,-88(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i4
xorq %rax,%rax
jmp .Lret_i4
.Lret_i4:
testq %rax,%rax
jz .L192
call rt_abort
jmp .L193
.L192:
.L193:
movq -88(%rbp),%rax
movq %r12,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $8,%rax
jnc .L194
call rt_abort
.L194:
movq %rax,-96(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L195
call rt_abort
.L195:
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $16,%rax
jnc .L196
call rt_abort
.L196:
movq %rax,-104(%rbp)
movq %rbx,%rax
movq -104(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
call rt_allocator_unlock
movq -88(%rbp),%rax
addq $32,%rax
jnc .L197
call rt_abort
.L197:
movq -.F172-8(%rbp),%rbx
movq -.F172-16(%rbp),%r12
movq -.F172-24(%rbp),%r13
movq -.F172-32(%rbp),%r14
movq -.F172-40(%rbp),%r15
leave
ret
jmp .L177
.L176:
.L177:
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq %rax,-112(%rbp)
movq %rax,-120(%rbp)
movq -16(%rbp),%rax
movq -120(%rbp),%rdi
movq %r15,%rsi
movq %rax,%rdx
call rt_copy_bytes
movq %r15,%rdi
call rt_free
movq -112(%rbp),%rax
movq -.F172-8(%rbp),%rbx
movq -.F172-16(%rbp),%r12
movq -.F172-24(%rbp),%r13
movq -.F172-32(%rbp),%r14
movq -.F172-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F172-8(%rbp),%rbx
movq -.F172-16(%rbp),%r12
movq -.F172-24(%rbp),%r13
movq -.F172-32(%rbp),%r14
movq -.F172-40(%rbp),%r15
leave
ret
.set .F172,128
.type rt_live,@function
rt_live:
pushq %rbp
movq %rsp,%rbp
subq $.F198,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
call rt_allocator_lock
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $24,%rcx
movq -8(%rbp),%rax
addq $24,%rax
jnc .L199
call rt_abort
.L199:
movq (%rax),%rax
movq %rax,-16(%rbp)
call rt_allocator_unlock
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F198,16
.type rt_shutdown,@function
rt_shutdown:
pushq %rbp
movq %rsp,%rbp
subq $.F200,%rsp
subq $32,%rsp
movq %rbx,-.F200-8(%rbp)
movq %r12,-.F200-16(%rbp)
movq %r13,-.F200-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
addq $32,%rax
jnc .L201
call rt_abort
.L201:
movq (%rax),%rax
movq %rax,%rbx
.L202:
cmpq $0,%rbx
je .L203
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $8,%rax
jnc .L204
call rt_abort
.L204:
movq (%rax),%rax
movabsq $11,%rdi
movq %rbx,%rsi
movq %rax,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r12,%rbx
jmp .L202
.L203:
movq -8(%rbp),%rax
addq $32,%rax
jnc .L205
call rt_abort
.L205:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movabsq $0,%rax
movq -.F200-8(%rbp),%rbx
movq -.F200-16(%rbp),%r12
movq -.F200-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F200-8(%rbp),%rbx
movq -.F200-16(%rbp),%r12
movq -.F200-24(%rbp),%r13
leave
ret
.set .F200,32
.type rt_new,@function
rt_new:
pushq %rbp
movq %rsp,%rbp
subq $.F206,%rsp
movabsq $24,%rdi
call rt_alloc
leave
ret
xorq %rax,%rax
leave
ret
.set .F206,32
.type rt_push,@function
rt_push:
pushq %rbp
movq %rsp,%rbp
subq $.F207,%rsp
subq $32,%rsp
movq %rbx,-.F207-8(%rbp)
movq %r12,-.F207-16(%rbp)
movq %r13,-.F207-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L208
call rt_abort
.L208:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L209
call rt_abort
.L209:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L210
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L212
call rt_abort
.L212:
movq %rax,%r13
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L213
movq $8,%r13
jmp .L214
.L213:
.L214:
movq %r13,%rcx
movabsq $144115188075855872,%rax
cmpq %r13,%rax
jae .L215
call rt_abort
jmp .L216
.L215:
.L216:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L217
call rt_abort
.L217:
movq %rax,-48(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L218
call rt_abort
.L218:
movq -40(%rbp),%rdi
movq -48(%rbp),%rsi
movq %rax,%rdx
call rt_grow
movq %rax,-56(%rbp)
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L219
call rt_abort
.L219:
movq %rax,-64(%rbp)
movq %r13,%rax
movq -64(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
jmp .L211
.L210:
.L211:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L220
call rt_abort
.L220:
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L221
call rt_abort
.L221:
movq %rax,-80(%rbp)
movq -16(%rbp),%rax
movq -80(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L222
call rt_abort
.L222:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L223
call rt_abort
.L223:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F207-8(%rbp),%rbx
movq -.F207-16(%rbp),%r12
movq -.F207-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F207-8(%rbp),%rbx
movq -.F207-16(%rbp),%r12
movq -.F207-24(%rbp),%r13
leave
ret
.set .F207,96
.type rt_fill,@function
rt_fill:
pushq %rbp
movq %rsp,%rbp
subq $.F224,%rsp
subq $48,%rsp
movq %rbx,-.F224-8(%rbp)
movq %r12,-.F224-16(%rbp)
movq %r13,-.F224-24(%rbp)
movq %r14,-.F224-32(%rbp)
movq %r15,-.F224-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,-16(%rbp)
movq %rdx,%r12
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r12,%rcx
movabsq $144115188075855872,%rax
cmpq %r12,%rax
jae .L225
call rt_abort
jmp .L226
.L225:
.L226:
cmpq $0,%r12
je .L227
movq %r13,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L229
call rt_abort
.L229:
movq -32(%rbp),%rdi
movabsq $0,%rsi
movq %rax,%rdx
call rt_grow
movq %rax,-40(%rbp)
movq %r13,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $16,%rax
jnc .L230
call rt_abort
.L230:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L228
.L227:
.L228:
movq $0,%rbx
.L231:
cmpq %r12,%rbx
jae .L232
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r14
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L233
call rt_abort
.L233:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L234
call rt_abort
.L234:
movq %rax,%r15
movq -16(%rbp),%rax
movq %r15,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L235
call rt_abort
.L235:
movq %rax,%rbx
jmp .L231
.L232:
movq %r13,%rax
addq $8,%rax
jnc .L236
call rt_abort
.L236:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movabsq $0,%rax
movq -.F224-8(%rbp),%rbx
movq -.F224-16(%rbp),%r12
movq -.F224-24(%rbp),%r13
movq -.F224-32(%rbp),%r14
movq -.F224-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F224-8(%rbp),%rbx
movq -.F224-16(%rbp),%r12
movq -.F224-24(%rbp),%r13
movq -.F224-32(%rbp),%r14
movq -.F224-40(%rbp),%r15
leave
ret
.set .F224,64
.type rt_fillb,@function
rt_fillb:
pushq %rbp
movq %rsp,%rbp
subq $.F237,%rsp
subq $48,%rsp
movq %rbx,-.F237-8(%rbp)
movq %r12,-.F237-16(%rbp)
movq %r13,-.F237-24(%rbp)
movq %r14,-.F237-32(%rbp)
movq %r15,-.F237-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r15
movq %rdx,%r14
movq $0,-32(%rbp)
movq %r15,%rcx
movabsq $255,%rax
cmpq %r15,%rax
jae .L238
call rt_abort
jmp .L239
.L238:
.L239:
movq %r13,%rdi
movq %r14,%rsi
call rt_reserveb
movq $0,%rbx
.L240:
cmpq %r14,%rbx
jae .L241
movq %r13,%rax
movq (%rax),%rax
addq %rbx,%rax
jnc .L242
call rt_abort
.L242:
movq %rax,%r12
movq %r15,%rax
movq %r12,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L243
call rt_abort
.L243:
movq %rax,%rbx
jmp .L240
.L241:
movq %r13,%rax
addq $8,%rax
jnc .L244
call rt_abort
.L244:
movq %rax,-32(%rbp)
movq %r14,%rax
movq -32(%rbp),%rcx
movq %r14,(%rcx)
xorq %r14,%rax
movabsq $0,%rax
movq -.F237-8(%rbp),%rbx
movq -.F237-16(%rbp),%r12
movq -.F237-24(%rbp),%r13
movq -.F237-32(%rbp),%r14
movq -.F237-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F237-8(%rbp),%rbx
movq -.F237-16(%rbp),%r12
movq -.F237-24(%rbp),%r13
movq -.F237-32(%rbp),%r14
movq -.F237-40(%rbp),%r15
leave
ret
.set .F237,32
.type rt_pushb,@function
rt_pushb:
pushq %rbp
movq %rsp,%rbp
subq $.F245,%rsp
subq $16,%rsp
movq %rbx,-.F245-8(%rbp)
movq %r12,-.F245-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L246
call rt_abort
.L246:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L247
call rt_abort
.L247:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L248
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L250
call rt_abort
.L250:
movq %rbx,%rdi
movq %rax,%rsi
call rt_reserveb
jmp .L249
.L248:
.L249:
movq %rbx,%rax
movq (%rax),%rax
addq %r12,%rax
jnc .L251
call rt_abort
.L251:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
andq $255,%rax
movq -32(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L252
call rt_abort
.L252:
movq %rax,-40(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L253
call rt_abort
.L253:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F245-8(%rbp),%rbx
movq -.F245-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F245-8(%rbp),%rbx
movq -.F245-16(%rbp),%r12
leave
ret
.set .F245,48
.type rt_pushb_checked,@function
rt_pushb_checked:
pushq %rbp
movq %rsp,%rbp
subq $.F254,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rcx
movabsq $255,%rax
cmpq %rcx,%rax
jae .L255
call rt_abort
jmp .L256
.L255:
.L256:
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt10
call rt_pushb
jmp .Lopt11
.Lopt10:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt11:
leave
ret
xorq %rax,%rax
leave
ret
.set .F254,16
.type rt_reserveb,@function
rt_reserveb:
pushq %rbp
movq %rsp,%rbp
subq $.F257,%rsp
subq $32,%rsp
movq %rbx,-.F257-8(%rbp)
movq %r12,-.F257-16(%rbp)
movq %r13,-.F257-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq %rsi,%r13
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r12,%rax
addq $16,%rax
jnc .L258
call rt_abort
.L258:
movq (%rax),%rax
movq %rax,-24(%rbp)
addq $1,%rax
jnc .L259
call rt_abort
.L259:
movq %rax,%rcx
cmpq %rcx,%r13
jae .L260
movabsq $0,%rax
movq -.F257-8(%rbp),%rbx
movq -.F257-16(%rbp),%r12
movq -.F257-24(%rbp),%r13
leave
ret
jmp .L261
.L260:
.L261:
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L262
call rt_abort
.L262:
movq %rax,%rbx
movq %rax,-32(%rbp)
cmpq $16,%rax
jae .L263
movq $16,%rbx
jmp .L264
.L263:
.L264:
.L265:
cmpq %r13,%rbx
jae .L266
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L267
call rt_abort
.L267:
movq %rax,%rbx
jmp .L265
.L266:
movq %rbx,%rcx
movabsq $1152921504606846976,%rax
cmpq %rbx,%rax
jae .L268
call rt_abort
jmp .L269
.L268:
.L269:
movabsq $8,%rcx
movq %r12,%rax
addq $8,%rax
jnc .L270
call rt_abort
.L270:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %r12,%rax
movq (%rax),%rax
movq %rax,-48(%rbp)
movq -48(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rbx,%rdx
call rt_grow
movq %rax,-56(%rbp)
movq %r12,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $16,%rax
jnc .L271
call rt_abort
.L271:
movq %rax,-64(%rbp)
movq %rbx,%rax
movq -64(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movabsq $0,%rax
movq -.F257-8(%rbp),%rbx
movq -.F257-16(%rbp),%r12
movq -.F257-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F257-8(%rbp),%rbx
movq -.F257-16(%rbp),%r12
movq -.F257-24(%rbp),%r13
leave
ret
.set .F257,64
.type rt_copy_bytes,@function
rt_copy_bytes:
pushq %rbp
movq %rsp,%rbp
subq $.F272,%rsp
subq $48,%rsp
movq %rbx,-.F272-8(%rbp)
movq %r12,-.F272-16(%rbp)
movq %r13,-.F272-24(%rbp)
movq %r14,-.F272-32(%rbp)
movq %r15,-.F272-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r12
movq %rsi,%r13
movq %rdx,%r14
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,%rbx
.L273:
movq %rbx,%rax
addq $8,%rax
jnc .L275
call rt_abort
.L275:
movq %rax,%r15
movq %r14,%rax
addq $1,%rax
jnc .L276
call rt_abort
.L276:
movq %rax,%rcx
cmpq %rcx,%r15
jae .L274
movq %r12,%rax
addq %rbx,%rax
jnc .L277
call rt_abort
.L277:
movq %rax,-32(%rbp)
movq %r13,%rax
addq %rbx,%rax
jnc .L278
call rt_abort
.L278:
movq (%rax),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L279
call rt_abort
.L279:
movq %rax,%rbx
jmp .L273
.L274:
.L280:
cmpq %r14,%rbx
jae .L281
movq %r12,%rax
addq %rbx,%rax
jnc .L282
call rt_abort
.L282:
movq %rax,-40(%rbp)
movq %r13,%rax
addq %rbx,%rax
jnc .L283
call rt_abort
.L283:
movzbq (%rax),%rax
movq -40(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L284
call rt_abort
.L284:
movq %rax,%rbx
jmp .L280
.L281:
movabsq $0,%rax
movq -.F272-8(%rbp),%rbx
movq -.F272-16(%rbp),%r12
movq -.F272-24(%rbp),%r13
movq -.F272-32(%rbp),%r14
movq -.F272-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F272-8(%rbp),%rbx
movq -.F272-16(%rbp),%r12
movq -.F272-24(%rbp),%r13
movq -.F272-32(%rbp),%r14
movq -.F272-40(%rbp),%r15
leave
ret
.set .F272,48
.type rt_bytes_truncate,@function
rt_bytes_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F285,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L286
call rt_abort
.L286:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
jae .L287
movq -8(%rbp),%rax
addq $8,%rax
jnc .L289
call rt_abort
.L289:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L288
.L287:
.L288:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F285,32
.type rt_popb,@function
rt_popb:
pushq %rbp
movq %rsp,%rbp
subq $.F290,%rsp
subq $16,%rsp
movq %rbx,-.F290-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L291
call rt_abort
.L291:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L292
call rt_abort
jmp .L293
.L292:
.L293:
movq %rbx,%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L294
call rt_abort
.L294:
movq %rax,-32(%rbp)
subq $1,%rax
jnc .L295
call rt_abort
.L295:
movzbq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L296
call rt_abort
.L296:
movq %rax,-48(%rbp)
movq %rcx,%rax
subq $1,%rax
jnc .L297
call rt_abort
.L297:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F290-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F290-8(%rbp),%rbx
leave
ret
.set .F290,48
.type rt_random_seed,@function
rt_random_seed:
pushq %rbp
movq %rsp,%rbp
subq $.F298,%rsp
subq $48,%rsp
movq %rbx,-.F298-8(%rbp)
movq %r12,-.F298-16(%rbp)
movq %r13,-.F298-24(%rbp)
movq %r14,-.F298-32(%rbp)
movq %r15,-.F298-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $8,%rdi
call rt_alloc
movq %rax,-8(%rbp)
movq $0,%rbx
.L299:
movabsq $8,%rcx
cmpq $8,%rbx
jae .L300
movq $318,%r13
movabsq $0,%rax
cmpq $0,%rax
je .L301
movq $278,%r13
jmp .L302
.L301:
.L302:
movq -8(%rbp),%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L303
call rt_abort
.L303:
movq %rax,%r14
movabsq $8,%rax
subq %rbx,%rax
jnc .L304
call rt_abort
.L304:
movq %rax,%r15
movq %r13,%rax
movq %r14,%rdi
movq %r15,%rsi
movabsq $0,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq %rax,%r12
movq %rax,-16(%rbp)
movabsq $18446744073709551612,%rcx
cmpq %rcx,%rax
jne .L305
jmp .L306
.L305:
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $8,%rax
subq %rbx,%rax
jnc .L307
call rt_abort
.L307:
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L308
call rt_abort
.L308:
testq %rax,%rax
jz .L309
call rt_abort
jmp .L310
.L309:
.L310:
movq %rbx,%rax
addq %r12,%rax
jnc .L311
call rt_abort
.L311:
movq %rax,%rbx
.L306:
jmp .L299
.L300:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F298-8(%rbp),%rbx
movq -.F298-16(%rbp),%r12
movq -.F298-24(%rbp),%r13
movq -.F298-32(%rbp),%r14
movq -.F298-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F298-8(%rbp),%rbx
movq -.F298-16(%rbp),%r12
movq -.F298-24(%rbp),%r13
movq -.F298-32(%rbp),%r14
movq -.F298-40(%rbp),%r15
leave
ret
.set .F298,32
.type rt_slotu,@function
rt_slotu:
pushq %rbp
movq %rsp,%rbp
subq $.F312,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $8,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L313
call rt_abort
.L313:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L314
call rt_abort
.L314:
leave
ret
xorq %rax,%rax
leave
ret
.set .F312,32
.type rt_slotb,@function
rt_slotb:
pushq %rbp
movq %rsp,%rbp
subq $.F315,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L316
call rt_abort
.L316:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L317
call rt_abort
jmp .L318
.L317:
.L318:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L319
call rt_abort
.L319:
leave
ret
xorq %rax,%rax
leave
ret
.set .F315,32
.type rt_atbu,@function
rt_atbu:
pushq %rbp
movq %rsp,%rbp
subq $.F320,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L321
call rt_abort
.L321:
movzbq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F320,16
.type rt_atb,@function
rt_atb:
pushq %rbp
movq %rsp,%rbp
subq $.F322,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L323
call rt_abort
.L323:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L324
call rt_abort
jmp .L325
.L324:
.L325:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L326
call rt_abort
.L326:
movzbq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F322,32
.type rt_pop,@function
rt_pop:
pushq %rbp
movq %rsp,%rbp
subq $.F327,%rsp
subq $16,%rsp
movq %rbx,-.F327-8(%rbp)
movq %r12,-.F327-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L328
call rt_abort
.L328:
movq (%rax),%rax
movq %rax,%r12
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L329
call rt_abort
jmp .L330
.L329:
.L330:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L331
call rt_abort
.L331:
movq %rax,-32(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L332
call rt_abort
.L332:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L333
call rt_abort
.L333:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-48(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L334
call rt_abort
.L334:
movq %rax,-56(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L335
call rt_abort
.L335:
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L336
call rt_abort
.L336:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L337
call rt_abort
.L337:
movq %rax,-72(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L338
call rt_abort
.L338:
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F327-8(%rbp),%rbx
movq -.F327-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F327-8(%rbp),%rbx
movq -.F327-16(%rbp),%r12
leave
ret
.set .F327,80
.type rt_len,@function
rt_len:
pushq %rbp
movq %rsp,%rbp
subq $.F339,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L340
call rt_abort
.L340:
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F339,16
.type rt_slot,@function
rt_slot:
pushq %rbp
movq %rsp,%rbp
subq $.F341,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L342
call rt_abort
.L342:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L343
call rt_abort
jmp .L344
.L343:
.L344:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L345
call rt_abort
.L345:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L346
call rt_abort
.L346:
leave
ret
xorq %rax,%rax
leave
ret
.set .F341,32
.type rt_take,@function
rt_take:
pushq %rbp
movq %rsp,%rbp
subq $.F347,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt12
call rt_abort
.Lopt12:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq %rax,-24(%rbp)
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -32(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F347,32
.type rt_at,@function
rt_at:
pushq %rbp
movq %rsp,%rbp
subq $.F348,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt14
call rt_abort
.Lopt14:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F348,16
.type rt_write,@function
rt_write:
pushq %rbp
movq %rsp,%rbp
subq $.F349,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L350
call rt_abort
.L350:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq -32(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-40(%rbp)
movq -24(%rbp),%rcx
movabsq $255,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L351
call rt_abort
.L351:
testq %rax,%rax
jz .L352
call rt_abort
jmp .L353
.L352:
.L353:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L354
call rt_abort
.L354:
movq %rax,-48(%rbp)
movq -24(%rbp),%rax
movq -48(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F349,48
.type rt_slice,@function
rt_slice:
pushq %rbp
movq %rsp,%rbp
subq $.F355,%rsp
subq $16,%rsp
movq %rbx,-.F355-8(%rbp)
movq %r12,-.F355-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,-8(%rbp)
movq %rsi,%rbx
movq %rdx,%r12
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r12,%rax
cmpq %rbx,%r12
setb %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L356
call rt_abort
.L356:
movq (%rax),%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L357
call rt_abort
.L357:
testq %rax,%rax
jz .L358
call rt_abort
jmp .L359
.L358:
.L359:
movabsq $24,%rdi
call rt_alloc
movq %rax,-40(%rbp)
movq %rax,-48(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
addq %rbx,%rax
jnc .L360
call rt_abort
.L360:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
addq $8,%rax
jnc .L361
call rt_abort
.L361:
movq %rax,-56(%rbp)
movq %r12,%rax
subq %rbx,%rax
jnc .L362
call rt_abort
.L362:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F355-8(%rbp),%rbx
movq -.F355-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F355-8(%rbp),%rbx
movq -.F355-16(%rbp),%r12
leave
ret
.set .F355,64
.type rt_vslice,@function
rt_vslice:
pushq %rbp
movq %rsp,%rbp
subq $.F363,%rsp
subq $16,%rsp
movq %rbx,-.F363-8(%rbp)
movq %r12,-.F363-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,-8(%rbp)
movq %rsi,%rbx
movq %rdx,%r12
movq %rcx,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq %r12,%rax
cmpq %rbx,%r12
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L364
call rt_abort
.L364:
movq (%rax),%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L365
call rt_abort
.L365:
testq %rax,%rax
jz .L366
call rt_abort
jmp .L367
.L366:
.L367:
movabsq $24,%rdi
call rt_alloc
movq %rax,-48(%rbp)
movq %rax,-56(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-64(%rbp)
movq %rbx,%rax
movq -32(%rbp),%rcx
mulq %rcx
jnc .L368
call rt_abort
.L368:
movq %rax,%rcx
movq -64(%rbp),%rax
addq %rcx,%rax
jnc .L369
call rt_abort
.L369:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
addq $8,%rax
jnc .L370
call rt_abort
.L370:
movq %rax,-72(%rbp)
movq %r12,%rax
subq %rbx,%rax
jnc .L371
call rt_abort
.L371:
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
movq -.F363-8(%rbp),%rbx
movq -.F363-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F363-8(%rbp),%rbx
movq -.F363-16(%rbp),%r12
leave
ret
.set .F363,80
.type rt_view,@function
rt_view:
pushq %rbp
movq %rsp,%rbp
subq $.F372,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L373
call rt_abort
.L373:
movq (%rax),%rax
movq -8(%rbp),%rdi
movabsq $0,%rsi
movq %rax,%rdx
call rt_slice
leave
ret
xorq %rax,%rax
leave
ret
.set .F372,16
.type rt_load_sized,@function
rt_load_sized:
pushq %rbp
movq %rsp,%rbp
subq $.F374,%rsp
subq $48,%rsp
movq %rbx,-.F374-8(%rbp)
movq %r12,-.F374-16(%rbp)
movq %r13,-.F374-24(%rbp)
movq %r14,-.F374-32(%rbp)
movq %r15,-.F374-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,%r14
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r13
movq $1,%r12
movq $0,%rbx
.L375:
cmpq %r14,%rbx
jae .L376
movq %r15,%rax
addq %rbx,%rax
jnc .L377
call rt_abort
.L377:
movzbq (%rax),%rax
movq %r12,%rcx
mulq %rcx
jnc .L378
call rt_abort
.L378:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L379
call rt_abort
.L379:
movq %rax,%r13
movabsq $256,%rcx
movq %r12,%rax
mulq %rcx
jnc .L380
call rt_abort
.L380:
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L381
call rt_abort
.L381:
movq %rax,%rbx
jmp .L375
.L376:
movq %r14,%rax
cmpq $8,%r14
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L382
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L384:
movq %rax,%rcx
cmpq %rcx,%r13
jb .L385
movq %r13,%rax
subq %r12,%rax
movq %rax,%r13
jmp .L386
.L385:
.L386:
jmp .L383
.L382:
.L383:
movq %r13,%rax
movq -.F374-8(%rbp),%rbx
movq -.F374-16(%rbp),%r12
movq -.F374-24(%rbp),%r13
movq -.F374-32(%rbp),%r14
movq -.F374-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F374-8(%rbp),%rbx
movq -.F374-16(%rbp),%r12
movq -.F374-24(%rbp),%r13
movq -.F374-32(%rbp),%r14
movq -.F374-40(%rbp),%r15
leave
ret
.set .F374,32
.type rt_store_sized,@function
rt_store_sized:
pushq %rbp
movq %rsp,%rbp
subq $.F387,%rsp
subq $48,%rsp
movq %rbx,-.F387-8(%rbp)
movq %r12,-.F387-16(%rbp)
movq %r13,-.F387-24(%rbp)
movq %r14,-.F387-32(%rbp)
movq %r15,-.F387-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,-16(%rbp)
movq %rdx,%r15
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movq %rax,%r12
movq $0,%rbx
.L388:
cmpq %r15,%rbx
jae .L389
movq %r14,%rax
addq %rbx,%rax
jnc .L390
call rt_abort
.L390:
movq %rax,%r13
movq %r12,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L391:
movq %r13,%rcx
movq %rdx,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L392:
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L393
call rt_abort
.L393:
movq %rax,%rbx
jmp .L388
.L389:
movabsq $0,%rax
movq -.F387-8(%rbp),%rbx
movq -.F387-16(%rbp),%r12
movq -.F387-24(%rbp),%r13
movq -.F387-32(%rbp),%r14
movq -.F387-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F387-8(%rbp),%rbx
movq -.F387-16(%rbp),%r12
movq -.F387-24(%rbp),%r13
movq -.F387-32(%rbp),%r14
movq -.F387-40(%rbp),%r15
leave
ret
.set .F387,32
.type rt_f32_bits,@function
rt_f32_bits:
pushq %rbp
movq %rsp,%rbp
subq $.F394,%rsp
subq $48,%rsp
movq %rbx,-.F394-8(%rbp)
movq %r12,-.F394-16(%rbp)
movq %r13,-.F394-24(%rbp)
movq %r14,-.F394-32(%rbp)
movq %r15,-.F394-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movabsq $63,%rax
cmpq $63,%rax
jnc .L395
call rt_abort
.L395:
movabsq $63,%rcx
movq %r14,%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
movabsq $63,%rax
cmpq $31,%rax
jnc .L396
call rt_abort
.L396:
movabsq $31,%rcx
movq -16(%rbp),%rax
shlq %cl,%rax
movq %rax,%r12
movabsq $63,%rax
cmpq $52,%rax
jnc .L397
call rt_abort
.L397:
movabsq $52,%rcx
movq %r14,%rax
shrq %cl,%rax
movq %rax,-24(%rbp)
andq $2047,%rax
movq %rax,%rbx
movabsq $4503599627370495,%rcx
movq %r14,%rax
andq %rcx,%rax
movq %rax,%r13
cmpq $2047,%rbx
jne .L398
movabsq $63,%rax
cmpq $29,%rax
jnc .L400
call rt_abort
.L400:
movabsq $29,%rcx
movq %r13,%rax
shrq %cl,%rax
movq %rax,%r15
movq %r13,%rax
cmpq $0,%r13
setne %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq %r15,%rax
cmpq $0,%r15
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L401
movq $4194304,%r15
jmp .L402
.L401:
.L402:
movq %r12,%rax
orq $2139095040,%rax
orq %r15,%rax
movq -.F394-8(%rbp),%rbx
movq -.F394-16(%rbp),%r12
movq -.F394-24(%rbp),%r13
movq -.F394-32(%rbp),%r14
movq -.F394-40(%rbp),%r15
leave
ret
jmp .L399
.L398:
.L399:
cmpq $0,%rbx
jne .L403
movq %r12,%rax
movq -.F394-8(%rbp),%rbx
movq -.F394-16(%rbp),%r12
movq -.F394-24(%rbp),%r13
movq -.F394-32(%rbp),%r14
movq -.F394-40(%rbp),%r15
leave
ret
jmp .L404
.L403:
.L404:
movabsq $896,%rax
cmpq %rbx,%rax
jae .L405
movq %rbx,%rax
subq $896,%rax
jnc .L407
call rt_abort
.L407:
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $23,%rax
jnc .L408
call rt_abort
.L408:
movabsq $23,%rcx
movq -40(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L409
call rt_abort
.L409:
movabsq $29,%rcx
movq %r13,%rax
shrq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F394-8(%rbp),%rbx
movq -.F394-16(%rbp),%r12
movq -.F394-24(%rbp),%r13
movq -.F394-32(%rbp),%r14
movq -.F394-40(%rbp),%r15
leave
ret
jmp .L406
.L405:
.L406:
movabsq $897,%rax
subq %rbx,%rax
jnc .L410
call rt_abort
.L410:
movq %rax,-56(%rbp)
movabsq $4503599627370496,%rcx
movq %r13,%rax
orq %rcx,%rax
movq %rax,-64(%rbp)
movq -56(%rbp),%rcx
movabsq $29,%rax
addq %rcx,%rax
jnc .L411
call rt_abort
.L411:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L412
call rt_abort
.L412:
movq -64(%rbp),%rax
shrq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
orq %rcx,%rax
movq -.F394-8(%rbp),%rbx
movq -.F394-16(%rbp),%r12
movq -.F394-24(%rbp),%r13
movq -.F394-32(%rbp),%r14
movq -.F394-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F394-8(%rbp),%rbx
movq -.F394-16(%rbp),%r12
movq -.F394-24(%rbp),%r13
movq -.F394-32(%rbp),%r14
movq -.F394-40(%rbp),%r15
leave
ret
.set .F394,80
.type rt_f32_from_bits,@function
rt_f32_from_bits:
pushq %rbp
movq %rsp,%rbp
subq $.F413,%rsp
subq $48,%rsp
movq %rbx,-.F413-8(%rbp)
movq %r12,-.F413-16(%rbp)
movq %r13,-.F413-24(%rbp)
movq %r14,-.F413-32(%rbp)
movq %r15,-.F413-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movabsq $63,%rax
cmpq $31,%rax
jnc .L414
call rt_abort
.L414:
movabsq $31,%rcx
movq -8(%rbp),%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
andq $1,%rax
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $63,%rax
jnc .L415
call rt_abort
.L415:
movabsq $63,%rcx
movq -24(%rbp),%rax
shlq %cl,%rax
movq %rax,%r15
movabsq $63,%rax
cmpq $23,%rax
jnc .L416
call rt_abort
.L416:
movabsq $23,%rcx
movq -8(%rbp),%rax
shrq %cl,%rax
movq %rax,-32(%rbp)
andq $255,%rax
movq %rax,-40(%rbp)
movq -8(%rbp),%rax
andq $8388607,%rax
movq %rax,%r12
movq -40(%rbp),%rax
cmpq $255,%rax
jne .L417
movabsq $9218868437227405312,%rcx
movq %r15,%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L419
call rt_abort
.L419:
movabsq $29,%rcx
movq %r12,%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F413-8(%rbp),%rbx
movq -.F413-16(%rbp),%r12
movq -.F413-24(%rbp),%r13
movq -.F413-32(%rbp),%r14
movq -.F413-40(%rbp),%r15
leave
ret
jmp .L418
.L417:
.L418:
movq -40(%rbp),%rax
cmpq $0,%rax
jne .L420
cmpq $0,%r12
jne .L422
movq %r15,%rax
movq -.F413-8(%rbp),%rbx
movq -.F413-16(%rbp),%r12
movq -.F413-24(%rbp),%r13
movq -.F413-32(%rbp),%r14
movq -.F413-40(%rbp),%r15
leave
ret
jmp .L423
.L422:
.L423:
movq $22,%rbx
.L424:
movq %rbx,%rcx
movabsq $63,%rax
cmpq %rbx,%rax
jnc .L426
call rt_abort
.L426:
movq %r12,%rax
shrq %cl,%rax
andq $1,%rax
cmpq $0,%rax
jne .L425
movq %rbx,%rax
subq $1,%rax
jnc .L427
call rt_abort
.L427:
movq %rax,%rbx
jmp .L424
.L425:
movq %rbx,%rcx
movabsq $63,%rax
cmpq %rbx,%rax
jnc .L428
call rt_abort
.L428:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
subq %rcx,%rax
jnc .L429
call rt_abort
.L429:
movq %rax,-56(%rbp)
movabsq $52,%rax
subq %rbx,%rax
jnc .L430
call rt_abort
.L430:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L431
call rt_abort
.L431:
movq -56(%rbp),%rax
shlq %cl,%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $874,%rax
jnc .L432
call rt_abort
.L432:
movq %rax,-80(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L433
call rt_abort
.L433:
movabsq $52,%rcx
movq -80(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r15,%rax
orq %rcx,%rax
movq -72(%rbp),%rcx
orq %rcx,%rax
movq -.F413-8(%rbp),%rbx
movq -.F413-16(%rbp),%r12
movq -.F413-24(%rbp),%r13
movq -.F413-32(%rbp),%r14
movq -.F413-40(%rbp),%r15
leave
ret
jmp .L421
.L420:
.L421:
movq -40(%rbp),%rax
addq $896,%rax
jnc .L434
call rt_abort
.L434:
movq %rax,-88(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L435
call rt_abort
.L435:
movabsq $52,%rcx
movq -88(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r15,%rax
orq %rcx,%rax
movq %rax,-96(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L436
call rt_abort
.L436:
movabsq $29,%rcx
movq %r12,%rax
shlq %cl,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
orq %rcx,%rax
movq -.F413-8(%rbp),%rbx
movq -.F413-16(%rbp),%r12
movq -.F413-24(%rbp),%r13
movq -.F413-32(%rbp),%r14
movq -.F413-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F413-8(%rbp),%rbx
movq -.F413-16(%rbp),%r12
movq -.F413-24(%rbp),%r13
movq -.F413-32(%rbp),%r14
movq -.F413-40(%rbp),%r15
leave
ret
.set .F413,96
.type rt_view_ptr,@function
rt_view_ptr:
pushq %rbp
movq %rsp,%rbp
subq $.F437,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F437,16
.type rt_cstr_view,@function
rt_cstr_view:
pushq %rbp
movq %rsp,%rbp
subq $.F438,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L439
call rt_abort
.L439:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L440
call rt_abort
jmp .L441
.L440:
.L441:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L442
call rt_abort
.L442:
movq %rax,-40(%rbp)
movq -40(%rbp),%rax
subq $1,%rax
jnc .L443
call rt_abort
.L443:
movzbq (%rax),%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
je .L444
call rt_abort
jmp .L445
.L444:
.L445:
movq -32(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F438,48
.type rt_append,@function
rt_append:
pushq %rbp
movq %rsp,%rbp
subq $.F446,%rsp
subq $32,%rsp
movq %rbx,-.F446-8(%rbp)
movq %r12,-.F446-16(%rbp)
movq %r13,-.F446-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
addq $8,%rax
jnc .L447
call rt_abort
.L447:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $8,%rax
jnc .L448
call rt_abort
.L448:
movq (%rax),%rax
movq %rax,%r13
movq %r12,%rcx
addq %r12,%rax
jnc .L449
call rt_abort
.L449:
movq %rbx,%rdi
movq %rax,%rsi
call rt_reserveb
movq %rbx,%rax
movq (%rax),%rax
movq %r13,%rcx
addq %r13,%rax
jnc .L450
call rt_abort
.L450:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rdi
movq -32(%rbp),%rsi
movq %r12,%rdx
call rt_copy_bytes
movq %rbx,%rax
addq $8,%rax
jnc .L451
call rt_abort
.L451:
movq %rax,-40(%rbp)
movq %r13,%rax
addq %r12,%rax
jnc .L452
call rt_abort
.L452:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F446-8(%rbp),%rbx
movq -.F446-16(%rbp),%r12
movq -.F446-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F446-8(%rbp),%rbx
movq -.F446-16(%rbp),%r12
movq -.F446-24(%rbp),%r13
leave
ret
.set .F446,48
.type rt_copy,@function
rt_copy:
pushq %rbp
movq %rsp,%rbp
subq $.F453,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
call rt_new
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
call rt_append
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F453,32
.type rt_vec_copy,@function
rt_vec_copy:
pushq %rbp
movq %rsp,%rbp
subq $.F454,%rsp
subq $48,%rsp
movq %rbx,-.F454-8(%rbp)
movq %r12,-.F454-16(%rbp)
movq %r13,-.F454-24(%rbp)
movq %r14,-.F454-32(%rbp)
movq %r15,-.F454-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq $0,-16(%rbp)
call rt_new
movq %rax,%r14
movq %r13,%rax
addq $8,%rax
jnc .L455
call rt_abort
.L455:
movq (%rax),%rax
movq %rax,%r15
movq $0,%rbx
.L456:
cmpq %r15,%rbx
jae .L457
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L458
call rt_abort
.L458:
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L459
call rt_abort
.L459:
movq (%rax),%rax
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt16
call rt_push
jmp .Lopt17
.Lopt16:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt17:
movq %rbx,%rax
addq $1,%rax
jnc .L460
call rt_abort
.L460:
movq %rax,%rbx
jmp .L456
.L457:
movq %r14,%rax
movq -.F454-8(%rbp),%rbx
movq -.F454-16(%rbp),%r12
movq -.F454-24(%rbp),%r13
movq -.F454-32(%rbp),%r14
movq -.F454-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F454-8(%rbp),%rbx
movq -.F454-16(%rbp),%r12
movq -.F454-24(%rbp),%r13
movq -.F454-32(%rbp),%r14
movq -.F454-40(%rbp),%r15
leave
ret
.set .F454,16
.type rt_lit,@function
rt_lit:
pushq %rbp
movq %rsp,%rbp
subq $.F461,%rsp
subq $16,%rsp
movq %rbx,-.F461-8(%rbp)
movq %r12,-.F461-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,-8(%rbp)
movq %rsi,%rbx
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
call rt_new
movq %rax,%r12
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq %rbx,%rsi
call rt_reserveb
movq %r12,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -32(%rbp),%rdi
movq -8(%rbp),%rsi
movq %rbx,%rdx
call rt_copy_bytes
movq %r12,%rax
addq $8,%rax
jnc .L462
call rt_abort
.L462:
movq %rax,-40(%rbp)
movq %rbx,%rax
movq -40(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movq %r12,%rax
movq -.F461-8(%rbp),%rbx
movq -.F461-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F461-8(%rbp),%rbx
movq -.F461-16(%rbp),%r12
leave
ret
.set .F461,48
.type rt_rec,@function
rt_rec:
pushq %rbp
movq %rsp,%rbp
subq $.F463,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $144115188075855872,%rax
cmpq %rcx,%rax
jae .L464
call rt_abort
jmp .L465
.L464:
.L465:
movabsq $8,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L466
call rt_abort
.L466:
movq %rax,%rdi
call rt_alloc
leave
ret
xorq %rax,%rax
leave
ret
.set .F463,16
.type rt_enum,@function
rt_enum:
pushq %rbp
movq %rsp,%rbp
subq $.F467,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $16,%rdi
call rt_alloc
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -24(%rbp),%rax
addq $8,%rax
jnc .L468
call rt_abort
.L468:
movq %rax,-40(%rbp)
movq -16(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -24(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F467,48
.type rt_enum_retag,@function
rt_enum_retag:
pushq %rbp
movq %rsp,%rbp
subq $.F469,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L470
call rt_abort
.L470:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -24(%rbp),%rax
movq -16(%rbp),%rdi
movq %rax,%rsi
call rt_enum
leave
ret
xorq %rax,%rax
leave
ret
.set .F469,32
.type rt_xchg,@function
rt_xchg:
pushq %rbp
movq %rsp,%rbp
subq $.F471,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -24(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F471,32
.type rt_drop_seq,@function
rt_drop_seq:
pushq %rbp
movq %rsp,%rbp
subq $.F472,%rsp
subq $16,%rsp
movq %rbx,-.F472-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rbx
je .L473
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_free
jmp .L474
.L473:
.L474:
movabsq $0,%rax
movq -.F472-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F472-8(%rbp),%rbx
leave
ret
.set .F472,16
.type rt_pack,@function
rt_pack:
pushq %rbp
movq %rsp,%rbp
subq $.F475,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L476
call rt_abort
.L476:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $1,%rcx
movq -24(%rbp),%rax
addq $1,%rax
jnc .L477
call rt_abort
.L477:
movq %rax,%rdi
call rt_alloc
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-48(%rbp)
movq -16(%rbp),%rax
movq -40(%rbp),%rdi
movq -48(%rbp),%rsi
movq %rax,%rdx
call rt_copy_bytes
movq -32(%rbp),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L478
call rt_abort
.L478:
movq %rax,-56(%rbp)
movq -56(%rbp),%rcx
movabsq $0,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -32(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F475,64
.type rt_cstr,@function
rt_cstr:
pushq %rbp
movq %rsp,%rbp
subq $.F479,%rsp
subq $32,%rsp
movq %rbx,-.F479-8(%rbp)
movq %r12,-.F479-16(%rbp)
movq %r13,-.F479-24(%rbp)
movq %r14,-.F479-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_pack
movq %rax,%r12
movq -8(%rbp),%rax
addq $8,%rax
jnc .L480
call rt_abort
.L480:
movq (%rax),%rax
movq %rax,%r14
movq $0,%rbx
.L481:
cmpq %r14,%rbx
jae .L482
movq %r12,%rax
addq %rbx,%rax
jnc .L483
call rt_abort
.L483:
movzbq (%rax),%rax
movabsq $0,%rcx
cmpq $0,%rax
jne .L484
movq %r12,%rdi
call rt_free
movabsq $0,%rax
movq -.F479-8(%rbp),%rbx
movq -.F479-16(%rbp),%r12
movq -.F479-24(%rbp),%r13
movq -.F479-32(%rbp),%r14
leave
ret
jmp .L485
.L484:
.L485:
movq %rbx,%rax
addq $1,%rax
jnc .L486
call rt_abort
.L486:
movq %rax,%rbx
jmp .L481
.L482:
movq %r12,%rax
movq -.F479-8(%rbp),%rbx
movq -.F479-16(%rbp),%r12
movq -.F479-24(%rbp),%r13
movq -.F479-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F479-8(%rbp),%rbx
movq -.F479-16(%rbp),%r12
movq -.F479-24(%rbp),%r13
movq -.F479-32(%rbp),%r14
leave
ret
.set .F479,16
.type f_host_target,@function
f_host_target:
pushq %rbp
movq %rsp,%rbp
subq $.F487,%rsp
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F487,16
.type f_host_argc,@function
f_host_argc:
pushq %rbp
movq %rsp,%rbp
subq $.F488,%rsp
leaq rt_state(%rip),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F488,32
.type f_host_arg,@function
f_host_arg:
pushq %rbp
movq %rsp,%rbp
subq $.F489,%rsp
subq $32,%rsp
movq %rbx,-.F489-8(%rbp)
movq %r12,-.F489-16(%rbp)
movq %r13,-.F489-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
leaq rt_state(%rip),%rax
movq (%rax),%rax
jmp .Lret_i5
xorq %rax,%rax
jmp .Lret_i5
.Lret_i5:
movq %rax,%rcx
movq -8(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L490
call rt_abort
jmp .L491
.L490:
.L491:
leaq rt_state(%rip),%rax
movq %rax,-24(%rbp)
addq $8,%rax
jnc .L492
call rt_abort
.L492:
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L493
call rt_abort
.L493:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L494
call rt_abort
.L494:
movq (%rax),%rax
movq %rax,%r13
movq $0,%rbx
.L495:
movq %r13,%rax
addq %rbx,%rax
jnc .L497
call rt_abort
.L497:
movzbq (%rax),%rax
movabsq $0,%rcx
cmpq $0,%rax
je .L496
movq %rbx,%rax
addq $1,%rax
jnc .L498
call rt_abort
.L498:
movq %rax,%rbx
jmp .L495
.L496:
movq %r13,%rdi
movq %rbx,%rsi
call rt_lit
movq -.F489-8(%rbp),%rbx
movq -.F489-16(%rbp),%r12
movq -.F489-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F489-8(%rbp),%rbx
movq -.F489-16(%rbp),%r12
movq -.F489-24(%rbp),%r13
leave
ret
.set .F489,32
.type f_host_read_file,@function
f_host_read_file:
pushq %rbp
movq %rsp,%rbp
subq $.F499,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i6
movabsq $0,%rax
jmp .Lret_i6
jmp .L894_i6
.L893_i6:
.L894_i6:
movq %r8,%rax
addq $16,%rax
jnc .L895_i6
call rt_abort
.L895_i6:
movq (%rax),%rax
jmp .Lret_i6
xorq %rax,%rax
jmp .Lret_i6
.Lret_i6:
movq %rax,-16(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
je .L500
leaq rt_read_file_blocking(%rip),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
call rt_offload
leave
ret
jmp .L501
.L500:
.L501:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_read_file_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F499,32
.type rt_read_file_blocking,@function
rt_read_file_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F502,%rsp
subq $48,%rsp
movq %rbx,-.F502-8(%rbp)
movq %r12,-.F502-16(%rbp)
movq %r13,-.F502-24(%rbp)
movq %r14,-.F502-32(%rbp)
movq %r15,-.F502-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L503
call rt_abort
jmp .L504
.L503:
.L504:
movabsq $2,%rdi
movq -16(%rbp),%rsi
movabsq $524288,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%r15
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r15,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i7
xorq %rax,%rax
jmp .Lret_i7
.Lret_i7:
testq %rax,%rax
jz .L505
call rt_abort
jmp .L506
.L505:
.L506:
movabsq $4096,%rdi
call rt_alloc
movq %rax,%r13
call rt_new
movq %rax,-24(%rbp)
.L507:
movabsq $1,%rax
testq %rax,%rax
jz .L508
movabsq $0,%rdi
movq %r15,%rsi
movq %r13,%rdx
movabsq $4096,%rcx
call rt_syscall
movq %rax,%r12
cmpq $0,%rax
jne .L509
jmp .L508
jmp .L510
.L509:
.L510:
movabsq $0,%rax
subq $4,%rax
movq %rax,%rcx
cmpq %rcx,%r12
jne .L511
jmp .L507
jmp .L512
.L511:
.L512:
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i8
xorq %rax,%rax
jmp .Lret_i8
.Lret_i8:
testq %rax,%rax
jz .L513
call rt_abort
jmp .L514
.L513:
.L514:
movq $0,%rbx
.L515:
cmpq %r12,%rbx
jae .L516
movq %r13,%rax
addq %rbx,%rax
jnc .L517
call rt_abort
.L517:
movzbq (%rax),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt18
call rt_pushb
jmp .Lopt19
.Lopt18:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt19:
movq %rbx,%rax
addq $1,%rax
jnc .L518
call rt_abort
.L518:
movq %rax,%rbx
jmp .L515
.L516:
jmp .L507
.L508:
movabsq $3,%rdi
movq %r15,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r13,%rdi
call rt_free
movq -24(%rbp),%rax
movq -.F502-8(%rbp),%rbx
movq -.F502-16(%rbp),%r12
movq -.F502-24(%rbp),%r13
movq -.F502-32(%rbp),%r14
movq -.F502-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F502-8(%rbp),%rbx
movq -.F502-16(%rbp),%r12
movq -.F502-24(%rbp),%r13
movq -.F502-32(%rbp),%r14
movq -.F502-40(%rbp),%r15
leave
ret
.set .F502,32
.type rt_write_all,@function
rt_write_all:
pushq %rbp
movq %rsp,%rbp
subq $.F519,%rsp
subq $48,%rsp
movq %rbx,-.F519-8(%rbp)
movq %r12,-.F519-16(%rbp)
movq %r13,-.F519-24(%rbp)
movq %r14,-.F519-32(%rbp)
movq %r15,-.F519-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,%r12
movq $0,-32(%rbp)
movq $0,%rbx
.L520:
cmpq %r12,%rbx
jae .L521
movq -16(%rbp),%rax
addq %rbx,%rax
jnc .L522
call rt_abort
.L522:
movq %rax,%r13
movq %r12,%rax
subq %rbx,%rax
jnc .L523
call rt_abort
.L523:
movabsq $1,%rdi
movq -8(%rbp),%rsi
movq %r13,%rdx
movq %rax,%rcx
call rt_syscall
movq %rax,%r14
movq %rax,%r15
movabsq $0,%rax
subq $4,%rax
movq %rax,%rcx
cmpq %rcx,%r15
jne .L524
jmp .L520
jmp .L525
.L524:
.L525:
movq %r14,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i9
xorq %rax,%rax
jmp .Lret_i9
.Lret_i9:
testq %rax,%rax
jz .L526
movabsq $0,%rax
subq %r14,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
movq -.F519-40(%rbp),%r15
leave
ret
jmp .L527
.L526:
.L527:
cmpq $0,%r14
jne .L528
movabsq $5,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
movq -.F519-40(%rbp),%r15
leave
ret
jmp .L529
.L528:
.L529:
movq %rbx,%rax
addq %r14,%rax
jnc .L530
call rt_abort
.L530:
movq %rax,%rbx
jmp .L520
.L521:
movabsq $0,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
movq -.F519-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
movq -.F519-40(%rbp),%r15
leave
ret
.set .F519,32
.type f_host_write_file,@function
f_host_write_file:
pushq %rbp
movq %rsp,%rbp
subq $.F531,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i10
movabsq $0,%rax
jmp .Lret_i10
jmp .L894_i10
.L893_i10:
.L894_i10:
movq %r8,%rax
addq $16,%rax
jnc .L895_i10
call rt_abort
.L895_i10:
movq (%rax),%rax
jmp .Lret_i10
xorq %rax,%rax
jmp .Lret_i10
.Lret_i10:
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
je .L532
leaq rt_write_file_blocking(%rip),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rdi
movq -8(%rbp),%rsi
movq %rax,%rdx
call rt_offload
leave
ret
jmp .L533
.L532:
.L533:
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_write_file_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F531,32
.type rt_write_file_blocking,@function
rt_write_file_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F534,%rsp
subq $32,%rsp
movq %rbx,-.F534-8(%rbp)
movq %r12,-.F534-16(%rbp)
movq %r13,-.F534-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,-8(%rbp)
movq %rsi,%rbx
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,%r13
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rcx
cmpq $0,%r13
jne .L535
movq %rbx,%rdi
call rt_free
movabsq $22,%rax
movq -.F534-8(%rbp),%rbx
movq -.F534-16(%rbp),%r12
movq -.F534-24(%rbp),%r13
leave
ret
jmp .L536
.L535:
.L536:
movabsq $2,%rdi
movq %r13,%rsi
movabsq $524865,%rdx
movabsq $438,%rcx
call rt_syscall
movq %rax,%r12
movq %r13,%rdi
call rt_free
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i11
xorq %rax,%rax
jmp .Lret_i11
.Lret_i11:
testq %rax,%rax
jz .L537
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
subq %r12,%rax
movq -.F534-8(%rbp),%rbx
movq -.F534-16(%rbp),%r12
movq -.F534-24(%rbp),%r13
leave
ret
jmp .L538
.L537:
.L538:
movq %rbx,%rdi
call rt_pack
movq %rax,-24(%rbp)
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %r12,%rdi
movq -24(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-32(%rbp)
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_free
movabsq $0,%rcx
movq -32(%rbp),%rax
cmpq $0,%rax
je .L539
movq -32(%rbp),%rax
movq -.F534-8(%rbp),%rbx
movq -.F534-16(%rbp),%r12
movq -.F534-24(%rbp),%r13
leave
ret
jmp .L540
.L539:
.L540:
movq -40(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i12
xorq %rax,%rax
jmp .Lret_i12
.Lret_i12:
testq %rax,%rax
jz .L541
movq -40(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F534-8(%rbp),%rbx
movq -.F534-16(%rbp),%r12
movq -.F534-24(%rbp),%r13
leave
ret
jmp .L542
.L541:
.L542:
movabsq $0,%rax
movq -.F534-8(%rbp),%rbx
movq -.F534-16(%rbp),%r12
movq -.F534-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F534-8(%rbp),%rbx
movq -.F534-16(%rbp),%r12
movq -.F534-24(%rbp),%r13
leave
ret
.set .F534,48
.type f_host_print,@function
f_host_print:
pushq %rbp
movq %rsp,%rbp
subq $.F543,%rsp
subq $16,%rsp
movq %rbx,-.F543-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rdi
call rt_pack
movq %rax,-16(%rbp)
movq %rbx,%rdi
movq 8(%rdi),%rax
movabsq $1,%rdi
movq -16(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_free
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
je .L544
call rt_abort
jmp .L545
.L544:
.L545:
movabsq $0,%rax
movq -.F543-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F543-8(%rbp),%rbx
leave
ret
.set .F543,32
.type rt_pow,@function
rt_pow:
pushq %rbp
movq %rsp,%rbp
subq $.F546,%rsp
subq $32,%rsp
movq %rbx,-.F546-8(%rbp)
movq %r12,-.F546-16(%rbp)
movq %r13,-.F546-24(%rbp)
movq %r14,-.F546-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%r12
movq -16(%rbp),%rax
movq %rax,%rbx
movq $1,%r13
.L547:
cmpq $0,%rbx
je .L548
movabsq $2,%rcx
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L549:
testq %rdx,%rdx
jz .L550
movq %r13,%rax
movq %r12,%rcx
mulq %rcx
jnc .L552
call rt_abort
.L552:
movq %rax,%r13
jmp .L551
.L550:
.L551:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
cmpq $0,%rax
je .L553
movq %r12,%rax
movq %r12,%rcx
mulq %rcx
jnc .L555
call rt_abort
.L555:
movq %rax,%r12
jmp .L554
.L553:
.L554:
jmp .L547
.L548:
movq %r13,%rax
movq -.F546-8(%rbp),%rbx
movq -.F546-16(%rbp),%r12
movq -.F546-24(%rbp),%r13
movq -.F546-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F546-8(%rbp),%rbx
movq -.F546-16(%rbp),%r12
movq -.F546-24(%rbp),%r13
movq -.F546-32(%rbp),%r14
leave
ret
.set .F546,16
.type rt_wrapping_pow,@function
rt_wrapping_pow:
pushq %rbp
movq %rsp,%rbp
subq $.F556,%rsp
subq $32,%rsp
movq %rbx,-.F556-8(%rbp)
movq %r12,-.F556-16(%rbp)
movq %r13,-.F556-24(%rbp)
movq %r14,-.F556-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%r12
movq -16(%rbp),%rax
movq %rax,%rbx
movq $1,%r13
.L557:
cmpq $0,%rbx
je .L558
movabsq $2,%rcx
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L559:
testq %rdx,%rdx
jz .L560
movq %r13,%rax
movq %r12,%rcx
imulq %rcx,%rax
movq %rax,%r13
jmp .L561
.L560:
.L561:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
cmpq $0,%rax
je .L562
movq %r12,%rax
movq %r12,%rcx
imulq %rcx,%rax
movq %rax,%r12
jmp .L563
.L562:
.L563:
jmp .L557
.L558:
movq %r13,%rax
movq -.F556-8(%rbp),%rbx
movq -.F556-16(%rbp),%r12
movq -.F556-24(%rbp),%r13
movq -.F556-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F556-8(%rbp),%rbx
movq -.F556-16(%rbp),%r12
movq -.F556-24(%rbp),%r13
movq -.F556-32(%rbp),%r14
leave
ret
.set .F556,16
.type rt_print_number,@function
rt_print_number:
pushq %rbp
movq %rsp,%rbp
subq $.F564,%rsp
subq $48,%rsp
movq %rbx,-.F564-8(%rbp)
movq %r12,-.F564-16(%rbp)
movq %r13,-.F564-24(%rbp)
movq %r14,-.F564-32(%rbp)
movq %r15,-.F564-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $32,%rdi
call rt_alloc
movq %rax,%r13
movq $31,%rbx
movq -8(%rbp),%rax
movq %rax,%r12
movq -16(%rbp),%rax
testq %rax,%rax
jz .L565
movq $30,%rbx
movq %r13,%rax
addq $31,%rax
jnc .L567
call rt_abort
.L567:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
jmp .L566
.L565:
.L566:
.L568:
movabsq $1,%rax
testq %rax,%rax
jz .L569
movq %r13,%rax
addq %rbx,%rax
jnc .L570
call rt_abort
.L570:
movq %rax,%r14
movabsq $10,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L571
call rt_abort
.L571:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L572
call rt_abort
.L572:
movq %r14,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
movq %rax,%r15
cmpq $0,%rax
jne .L573
jmp .L569
jmp .L574
.L573:
.L574:
movq %rbx,%rax
subq $1,%rax
jnc .L575
call rt_abort
.L575:
movq %rax,%rbx
jmp .L568
.L569:
movq %r13,%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L576
call rt_abort
.L576:
movq %rax,-32(%rbp)
movabsq $32,%rax
subq %rbx,%rax
jnc .L577
call rt_abort
.L577:
movabsq $1,%rdi
movq -32(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-40(%rbp)
movq %r13,%rdi
call rt_free
movabsq $0,%rcx
movq -40(%rbp),%rax
cmpq $0,%rax
je .L578
call rt_abort
jmp .L579
.L578:
.L579:
movabsq $0,%rax
movq -.F564-8(%rbp),%rbx
movq -.F564-16(%rbp),%r12
movq -.F564-24(%rbp),%r13
movq -.F564-32(%rbp),%r14
movq -.F564-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F564-8(%rbp),%rbx
movq -.F564-16(%rbp),%r12
movq -.F564-24(%rbp),%r13
movq -.F564-32(%rbp),%r14
movq -.F564-40(%rbp),%r15
leave
ret
.set .F564,48
.type rt_print_num,@function
rt_print_num:
pushq %rbp
movq %rsp,%rbp
subq $.F580,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $1,%rsi
call rt_print_number
leave
ret
xorq %rax,%rax
leave
ret
.set .F580,16
.type rt_print_newline,@function
rt_print_newline:
pushq %rbp
movq %rsp,%rbp
subq $.F581,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $1,%rdi
call rt_alloc
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
movabsq $1,%rdi
movq -8(%rbp),%rsi
movabsq $1,%rdx
call rt_write_all
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
je .L582
call rt_abort
jmp .L583
.L582:
.L583:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F581,32
.type f_host_print_num,@function
f_host_print_num:
pushq %rbp
movq %rsp,%rbp
subq $.F584,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $0,%rsi
call rt_print_number
leave
ret
xorq %rax,%rax
leave
ret
.set .F584,16
.type f_host_newline,@function
f_host_newline:
pushq %rbp
movq %rsp,%rbp
subq $.F585,%rsp
call rt_print_newline
leave
ret
xorq %rax,%rax
leave
ret
.set .F585,16
.type rt_exec_paths,@function
rt_exec_paths:
pushq %rbp
movq %rsp,%rbp
subq $.F586,%rsp
subq $48,%rsp
movq %rbx,-.F586-8(%rbp)
movq %r12,-.F586-16(%rbp)
movq %r13,-.F586-24(%rbp)
movq %r14,-.F586-32(%rbp)
movq %r15,-.F586-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F586(%rbp),%rdi
movq $.F586/8-1,%rcx
xorl %eax,%eax
rep stosq
call rt_new
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt20
call rt_push
jmp .Lopt21
.Lopt20:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt21:
leaq rt_state(%rip),%rax
movq %rax,-32(%rbp)
addq $16,%rax
jnc .L587
call rt_abort
.L587:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
.L588:
movq -8(%rbp),%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L590
call rt_abort
.L590:
movzbq (%rax),%rax
movq %rax,-64(%rbp)
cmpq $0,%rax
je .L589
movq -8(%rbp),%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L591
call rt_abort
.L591:
movzbq (%rax),%rax
movq %rax,-72(%rbp)
cmpq $47,%rax
jne .L592
movq $1,-56(%rbp)
jmp .L593
.L592:
.L593:
movq -48(%rbp),%rax
addq $1,%rax
jnc .L594
call rt_abort
.L594:
movq %rax,-48(%rbp)
jmp .L588
.L589:
movq -56(%rbp),%rax
testq %rax,%rax
jz .L595
movq -16(%rbp),%rax
movq -.F586-8(%rbp),%rbx
movq -.F586-16(%rbp),%r12
movq -.F586-24(%rbp),%r13
movq -.F586-32(%rbp),%r14
movq -.F586-40(%rbp),%r15
leave
ret
jmp .L596
.L595:
.L596:
movq -40(%rbp),%rax
movq %rax,-80(%rbp)
movq $0,%r14
.L597:
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-88(%rbp)
cmpq $0,%rax
je .L598
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-96(%rbp)
movzbq (%rax),%rax
movq %rax,-104(%rbp)
cmpq $80,%rax
jne .L599
movq -96(%rbp),%rax
addq $1,%rax
jnc .L601
call rt_abort
.L601:
movzbq (%rax),%rax
movq %rax,-112(%rbp)
cmpq $65,%rax
jne .L602
movq -96(%rbp),%rax
addq $2,%rax
jnc .L604
call rt_abort
.L604:
movzbq (%rax),%rax
movq %rax,-120(%rbp)
cmpq $84,%rax
jne .L605
movq -96(%rbp),%rax
addq $3,%rax
jnc .L607
call rt_abort
.L607:
movzbq (%rax),%rax
movq %rax,-128(%rbp)
cmpq $72,%rax
jne .L608
movq -96(%rbp),%rax
addq $4,%rax
jnc .L610
call rt_abort
.L610:
movzbq (%rax),%rax
movq %rax,-136(%rbp)
cmpq $61,%rax
jne .L611
movq -96(%rbp),%rax
addq $5,%rax
jnc .L613
call rt_abort
.L613:
movq %rax,%r14
jmp .L598
jmp .L612
.L611:
.L612:
jmp .L609
.L608:
.L609:
jmp .L606
.L605:
.L606:
jmp .L603
.L602:
.L603:
jmp .L600
.L599:
.L600:
movq -80(%rbp),%rax
addq $8,%rax
jnc .L614
call rt_abort
.L614:
movq %rax,-80(%rbp)
jmp .L597
.L598:
movq $0,-144(%rbp)
movabsq $0,%rcx
cmpq $0,%r14
jne .L615
movabsq $14,%rdi
call rt_alloc
movq %rax,-144(%rbp)
movq %rax,-152(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $1,%rax
jnc .L617
call rt_abort
.L617:
movq %rax,-160(%rbp)
movq %rax,%rcx
movabsq $98,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $2,%rax
jnc .L618
call rt_abort
.L618:
movq %rax,-168(%rbp)
movq %rax,%rcx
movabsq $105,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $3,%rax
jnc .L619
call rt_abort
.L619:
movq %rax,-176(%rbp)
movq %rax,%rcx
movabsq $110,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $4,%rax
jnc .L620
call rt_abort
.L620:
movq %rax,-184(%rbp)
movq %rax,%rcx
movabsq $58,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $5,%rax
jnc .L621
call rt_abort
.L621:
movq %rax,-192(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $6,%rax
jnc .L622
call rt_abort
.L622:
movq %rax,-200(%rbp)
movq %rax,%rcx
movabsq $117,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $7,%rax
jnc .L623
call rt_abort
.L623:
movq %rax,-208(%rbp)
movq %rax,%rcx
movabsq $115,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $8,%rax
jnc .L624
call rt_abort
.L624:
movq %rax,-216(%rbp)
movq %rax,%rcx
movabsq $114,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $9,%rax
jnc .L625
call rt_abort
.L625:
movq %rax,-224(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $10,%rax
jnc .L626
call rt_abort
.L626:
movq %rax,-232(%rbp)
movq %rax,%rcx
movabsq $98,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $11,%rax
jnc .L627
call rt_abort
.L627:
movq %rax,-240(%rbp)
movq %rax,%rcx
movabsq $105,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $12,%rax
jnc .L628
call rt_abort
.L628:
movq %rax,-248(%rbp)
movq %rax,%rcx
movabsq $110,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
movq %rax,%r14
jmp .L616
.L615:
.L616:
movq $0,-256(%rbp)
.L629:
movabsq $1,%rax
testq %rax,%rax
jz .L630
movq -256(%rbp),%rax
movq %rax,%r12
.L631:
movq %r14,%rax
addq %r12,%rax
jnc .L633
call rt_abort
.L633:
movzbq (%rax),%rax
movq %rax,-264(%rbp)
cmpq $0,%rax
je .L632
movq %r14,%rax
addq %r12,%rax
jnc .L634
call rt_abort
.L634:
movzbq (%rax),%rax
movq %rax,-272(%rbp)
cmpq $58,%rax
jne .L635
jmp .L632
jmp .L636
.L635:
.L636:
movq %r12,%rax
addq $1,%rax
jnc .L637
call rt_abort
.L637:
movq %rax,%r12
jmp .L631
.L632:
movq %r12,%rax
movq -256(%rbp),%rcx
subq %rcx,%rax
jnc .L638
call rt_abort
.L638:
movq %rax,-280(%rbp)
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L639
call rt_abort
.L639:
movq %rax,-288(%rbp)
movabsq $2,%rcx
addq $2,%rax
jnc .L640
call rt_abort
.L640:
movq %rax,%rdi
call rt_alloc
movq %rax,%r15
movq $0,%rbx
.L641:
movq -280(%rbp),%rcx
cmpq %rcx,%rbx
jae .L642
movq %r15,%rax
addq %rbx,%rax
jnc .L643
call rt_abort
.L643:
movq %rax,-296(%rbp)
movq %r14,%rax
movq -256(%rbp),%rcx
addq %rcx,%rax
jnc .L644
call rt_abort
.L644:
addq %rbx,%rax
jnc .L645
call rt_abort
.L645:
movzbq (%rax),%rax
movq -296(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L646
call rt_abort
.L646:
movq %rax,%rbx
jmp .L641
.L642:
movq -280(%rbp),%rax
cmpq $0,%rax
je .L647
movq %r15,%rax
addq %rbx,%rax
jnc .L649
call rt_abort
.L649:
movq %rax,-304(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L650
call rt_abort
.L650:
movq %rax,%rbx
jmp .L648
.L647:
.L648:
movq $0,%r13
.L651:
movq -48(%rbp),%rcx
cmpq %rcx,%r13
jae .L652
movq %r15,%rax
addq %rbx,%rax
jnc .L653
call rt_abort
.L653:
addq %r13,%rax
jnc .L654
call rt_abort
.L654:
movq %rax,-312(%rbp)
movq -8(%rbp),%rax
addq %r13,%rax
jnc .L655
call rt_abort
.L655:
movzbq (%rax),%rax
movq -312(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $1,%rax
jnc .L656
call rt_abort
.L656:
movq %rax,%r13
jmp .L651
.L652:
movq -16(%rbp),%rdi
movq %r15,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt22
call rt_push
jmp .Lopt23
.Lopt22:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt23:
movq %r14,%rax
addq %r12,%rax
jnc .L657
call rt_abort
.L657:
movzbq (%rax),%rax
movq %rax,-320(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L658
jmp .L630
jmp .L659
.L658:
.L659:
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L660
call rt_abort
.L660:
movq %rax,-256(%rbp)
jmp .L629
.L630:
movq -144(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq -.F586-8(%rbp),%rbx
movq -.F586-16(%rbp),%r12
movq -.F586-24(%rbp),%r13
movq -.F586-32(%rbp),%r14
movq -.F586-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F586-8(%rbp),%rbx
movq -.F586-16(%rbp),%r12
movq -.F586-24(%rbp),%r13
movq -.F586-32(%rbp),%r14
movq -.F586-40(%rbp),%r15
leave
ret
.set .F586,320
.type rt_exec,@function
rt_exec:
pushq %rbp
movq %rsp,%rbp
subq $.F661,%rsp
subq $48,%rsp
movq %rbx,-.F661-8(%rbp)
movq %r12,-.F661-16(%rbp)
movq %r13,-.F661-24(%rbp)
movq %r14,-.F661-32(%rbp)
movq %r15,-.F661-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-24(%rbp)
addq $16,%rax
jnc .L662
call rt_abort
.L662:
movq (%rax),%rax
movq %rax,%r15
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq $0,%rbx
.L663:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L664
movq %r13,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i13
call rt_abort
.Lopt15_i13:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i13
xorq %rax,%rax
jmp .Lret_i13
.Lret_i13:
movq %rax,%r12
movabsq $59,%rdi
movq %r12,%rsi
movq %r14,%rdx
movq %r15,%rcx
call rt_syscall
movq %rbx,%rax
addq $1,%rax
jnc .L665
call rt_abort
.L665:
movq %rax,%rbx
jmp .L663
.L664:
movabsq $0,%rax
movq -.F661-8(%rbp),%rbx
movq -.F661-16(%rbp),%r12
movq -.F661-24(%rbp),%r13
movq -.F661-32(%rbp),%r14
movq -.F661-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F661-8(%rbp),%rbx
movq -.F661-16(%rbp),%r12
movq -.F661-24(%rbp),%r13
movq -.F661-32(%rbp),%r14
movq -.F661-40(%rbp),%r15
leave
ret
.set .F661,32
.type rt_drop_exec_paths,@function
rt_drop_exec_paths:
pushq %rbp
movq %rsp,%rbp
subq $.F666,%rsp
subq $32,%rsp
movq %rbx,-.F666-8(%rbp)
movq %r12,-.F666-16(%rbp)
movq %r13,-.F666-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq $0,-16(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq $1,%rbx
.L667:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L668
movq %r12,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i14
call rt_abort
.Lopt15_i14:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i14
xorq %rax,%rax
jmp .Lret_i14
.Lret_i14:
movq %rax,%rdi
call rt_free
movq %rbx,%rax
addq $1,%rax
jnc .L669
call rt_abort
.L669:
movq %rax,%rbx
jmp .L667
.L668:
movq %r12,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
leave
ret
.set .F666,16
.type f_host_command,@function
f_host_command:
pushq %rbp
movq %rsp,%rbp
subq $.F670,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i15
movabsq $0,%rax
jmp .Lret_i15
jmp .L894_i15
.L893_i15:
.L894_i15:
movq %r8,%rax
addq $16,%rax
jnc .L895_i15
call rt_abort
.L895_i15:
movq (%rax),%rax
jmp .Lret_i15
xorq %rax,%rax
jmp .Lret_i15
.Lret_i15:
movq %rax,-16(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
je .L671
leaq rt_command_blocking(%rip),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
call rt_offload
leave
ret
jmp .L672
.L671:
.L672:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_command_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F670,32
.type rt_command_blocking,@function
rt_command_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F673,%rsp
subq $48,%rsp
movq %rbx,-.F673-8(%rbp)
movq %r12,-.F673-16(%rbp)
movq %r13,-.F673-24(%rbp)
movq %r14,-.F673-32(%rbp)
movq %r15,-.F673-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
leaq -.F673(%rbp),%rdi
movq $.F673/8-1,%rcx
xorl %eax,%eax
rep stosq
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq $278,-16(%rbp)
movq $0,%r12
addq $1,%rax
jnc .L674
call rt_abort
.L674:
movq %rax,-24(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L675
call rt_abort
.L675:
movq %rax,%rdi
call rt_alloc
movq %rax,%r14
cmpq $0,%r13
je .L676
.L678:
movq %r13,%rcx
cmpq %r13,%r12
jae .L679
movq %r15,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i16
call rt_abort
.Lopt15_i16:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i16
xorq %rax,%rax
jmp .Lret_i16
.Lret_i16:
movq %rax,%rdi
call rt_cstr
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L680
jmp .L679
jmp .L681
.L680:
.L681:
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L682
call rt_abort
.L682:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L683
call rt_abort
.L683:
movq %rax,-48(%rbp)
movq -32(%rbp),%rax
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $1,%rax
jnc .L684
call rt_abort
.L684:
movq %rax,%r12
jmp .L678
.L679:
movq %r13,%rcx
cmpq %r13,%r12
jne .L685
movq %r14,%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_exec_paths
movq %rax,-56(%rbp)
movabsq $57,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-64(%rbp)
movq %rax,-72(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L687
movq -56(%rbp),%rdi
movq %r14,%rsi
call rt_exec
movabsq $60,%rdi
movabsq $127,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L688
.L687:
.L688:
movq -64(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i17
xorq %rax,%rax
jmp .Lret_i17
.Lret_i17:
testq %rax,%rax
jz .L689
movq -64(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%rcx
movabsq $256,%rax
addq %rcx,%rax
jnc .L691
call rt_abort
.L691:
movq %rax,-16(%rbp)
jmp .L690
.L689:
movabsq $8,%rdi
call rt_alloc
movq %rax,-80(%rbp)
movq $0,-88(%rbp)
.L692:
movabsq $1,%rax
testq %rax,%rax
jz .L693
movabsq $61,%rdi
movq -64(%rbp),%rsi
movq -80(%rbp),%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-88(%rbp)
movq %rax,-96(%rbp)
movabsq $0,%rax
subq $4,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
cmpq %rcx,%rax
je .L694
jmp .L693
jmp .L695
.L694:
.L695:
jmp .L692
.L693:
movq -88(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i18
xorq %rax,%rax
jmp .Lret_i18
.Lret_i18:
testq %rax,%rax
jz .L696
movq -88(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%rcx
movabsq $256,%rax
addq %rcx,%rax
jnc .L698
call rt_abort
.L698:
movq %rax,-16(%rbp)
jmp .L697
.L696:
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-104(%rbp)
movq %rax,-112(%rbp)
andq $127,%rax
movq %rax,-120(%rbp)
movq %rax,-128(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L699
movq -120(%rbp),%rcx
movabsq $128,%rax
addq %rcx,%rax
jnc .L701
call rt_abort
.L701:
movq %rax,-16(%rbp)
jmp .L700
.L699:
movq -104(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,-136(%rbp)
movabsq $255,%rcx
andq $255,%rax
movq %rax,-16(%rbp)
.L700:
.L697:
movq -80(%rbp),%rax
movq %rax,%rdi
call rt_free
.L690:
movq -56(%rbp),%rax
movq %rax,%rdi
call rt_drop_exec_paths
jmp .L686
.L685:
.L686:
jmp .L677
.L676:
.L677:
movq $0,%rbx
.L702:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L703
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L704
call rt_abort
.L704:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L705
call rt_abort
.L705:
movq (%rax),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rax
addq $1,%rax
jnc .L706
call rt_abort
.L706:
movq %rax,%rbx
jmp .L702
.L703:
movq %r14,%rdi
call rt_free
movq $0,%rbx
.L707:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L708
movq %r15,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i19
call rt_abort
.Lopt15_i19:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i19
xorq %rax,%rax
jmp .Lret_i19
.Lret_i19:
movq %rax,%rdi
call rt_drop_seq
movq %rbx,%rax
addq $1,%rax
jnc .L709
call rt_abort
.L709:
movq %rax,%rbx
jmp .L707
.L708:
movq %r15,%rdi
call rt_drop_seq
movq -16(%rbp),%rax
movq -.F673-8(%rbp),%rbx
movq -.F673-16(%rbp),%r12
movq -.F673-24(%rbp),%r13
movq -.F673-32(%rbp),%r14
movq -.F673-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F673-8(%rbp),%rbx
movq -.F673-16(%rbp),%r12
movq -.F673-24(%rbp),%r13
movq -.F673-32(%rbp),%r14
movq -.F673-40(%rbp),%r15
leave
ret
.set .F673,144
.type rt_utf8,@function
rt_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F710,%rsp
subq $48,%rsp
movq %rbx,-.F710-8(%rbp)
movq %r12,-.F710-16(%rbp)
movq %r13,-.F710-24(%rbp)
movq %r14,-.F710-32(%rbp)
movq %r15,-.F710-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,-16(%rbp)
movq $0,%rbx
.L711:
movq -16(%rbp),%rcx
cmpq %rcx,%rbx
jae .L712
movq %r15,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt24
call rt_abort
.Lopt24:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq $0,%r14
cmpq $128,%rax
jae .L713
movq %rbx,%rax
addq $1,%rax
jnc .L715
call rt_abort
.L715:
movq %rax,%rbx
jmp .L711
jmp .L714
.L713:
.L714:
movabsq $193,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %r12,%rax
cmpq $224,%r12
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L716
movq $2,%r14
jmp .L717
.L716:
.L717:
movabsq $223,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq %r12,%rax
cmpq $240,%r12
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L718
movq $3,%r14
jmp .L719
.L718:
.L719:
movabsq $239,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
movq %r12,%rax
cmpq $245,%r12
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L720
movq $4,%r14
jmp .L721
.L720:
.L721:
movq %r14,%rax
cmpq $0,%r14
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq %r14,%rax
jnc .L722
call rt_abort
.L722:
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L723
call rt_abort
.L723:
testq %rax,%rax
jz .L724
call rt_abort
jmp .L725
.L724:
.L725:
movq %rbx,%rax
addq $1,%rax
jnc .L726
call rt_abort
.L726:
movq %r15,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt25
call rt_abort
.Lopt25:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
cmpq $128,%rax
setb %al
movzbq %al,%rax
movq %rax,-72(%rbp)
movq -56(%rbp),%rcx
movabsq $191,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L727
call rt_abort
.L727:
testq %rax,%rax
jz .L728
call rt_abort
jmp .L729
.L728:
.L729:
movq %r12,%rax
cmpq $224,%r12
sete %al
movzbq %al,%rax
movq %rax,-80(%rbp)
movq -56(%rbp),%rax
cmpq $160,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L730
call rt_abort
jmp .L731
.L730:
.L731:
movq %r12,%rax
cmpq $237,%r12
sete %al
movzbq %al,%rax
movq %rax,-88(%rbp)
movq -56(%rbp),%rcx
movabsq $159,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L732
call rt_abort
jmp .L733
.L732:
.L733:
movq %r12,%rax
cmpq $240,%r12
sete %al
movzbq %al,%rax
movq %rax,-96(%rbp)
movq -56(%rbp),%rax
cmpq $144,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L734
call rt_abort
jmp .L735
.L734:
.L735:
movq %r12,%rax
cmpq $244,%r12
sete %al
movzbq %al,%rax
movq %rax,-104(%rbp)
movq -56(%rbp),%rcx
movabsq $143,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L736
call rt_abort
jmp .L737
.L736:
.L737:
movq $2,%r13
.L738:
cmpq %r14,%r13
jae .L739
movq %rbx,%rax
addq %r13,%rax
jnc .L740
call rt_abort
.L740:
movq %r15,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt26
call rt_abort
.Lopt26:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-112(%rbp)
movq %rax,-120(%rbp)
cmpq $128,%rax
setb %al
movzbq %al,%rax
movq %rax,-128(%rbp)
movq -112(%rbp),%rcx
movabsq $191,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -128(%rbp),%rax
addq %rcx,%rax
jnc .L741
call rt_abort
.L741:
testq %rax,%rax
jz .L742
call rt_abort
jmp .L743
.L742:
.L743:
movq %r13,%rax
addq $1,%rax
jnc .L744
call rt_abort
.L744:
movq %rax,%r13
jmp .L738
.L739:
movq %rbx,%rax
addq %r14,%rax
jnc .L745
call rt_abort
.L745:
movq %rax,%rbx
jmp .L711
.L712:
movabsq $0,%rax
movq -.F710-8(%rbp),%rbx
movq -.F710-16(%rbp),%r12
movq -.F710-24(%rbp),%r13
movq -.F710-32(%rbp),%r14
movq -.F710-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F710-8(%rbp),%rbx
movq -.F710-16(%rbp),%r12
movq -.F710-24(%rbp),%r13
movq -.F710-32(%rbp),%r14
movq -.F710-40(%rbp),%r15
leave
ret
.set .F710,128
.type rt_text,@function
rt_text:
pushq %rbp
movq %rsp,%rbp
subq $.F746,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_utf8
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_copy
leave
ret
xorq %rax,%rax
leave
ret
.set .F746,16
.type rt_string_lit,@function
rt_string_lit:
pushq %rbp
movq %rsp,%rbp
subq $.F747,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_lit
movq %rax,-24(%rbp)
movq %rax,%rdi
call rt_utf8
movq -24(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F747,32
.type rt_append_text,@function
rt_append_text:
pushq %rbp
movq %rsp,%rbp
subq $.F748,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_utf8
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_append
leave
ret
xorq %rax,%rax
leave
ret
.set .F748,16
.type rt_atomic_new,@function
rt_atomic_new:
pushq %rbp
movq %rsp,%rbp
subq $.F749,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $8,%rdi
call rt_alloc
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rdi
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F749,32
.type rt_atomic_load,@function
rt_atomic_load:
pushq %rbp
movq %rsp,%rbp
subq $.F750,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq (%rdi),%rax
mfence
leave
ret
xorq %rax,%rax
leave
ret
.set .F750,16
.type rt_atomic_load_relaxed,@function
rt_atomic_load_relaxed:
pushq %rbp
movq %rsp,%rbp
subq $.F751,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq (%rdi),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F751,16
.type rt_atomic_load_acquire,@function
rt_atomic_load_acquire:
pushq %rbp
movq %rsp,%rbp
subq $.F752,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq (%rdi),%rax
lfence
leave
ret
xorq %rax,%rax
leave
ret
.set .F752,16
.type rt_atomic_store,@function
rt_atomic_store:
pushq %rbp
movq %rsp,%rbp
subq $.F753,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F753,16
.type rt_atomic_store_relaxed,@function
rt_atomic_store_relaxed:
pushq %rbp
movq %rsp,%rbp
subq $.F754,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F754,16
.type rt_atomic_store_release,@function
rt_atomic_store_release:
pushq %rbp
movq %rsp,%rbp
subq $.F755,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
sfence
movq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F755,16
.type rt_atomic_compare_exchange,@function
rt_atomic_compare_exchange:
pushq %rbp
movq %rsp,%rbp
subq $.F756,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rdi
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
lock cmpxchgq %rcx,(%rdi)
leave
ret
xorq %rax,%rax
leave
ret
.set .F756,32
.type rt_atomic_fetch_add,@function
rt_atomic_fetch_add:
pushq %rbp
movq %rsp,%rbp
subq $.F757,%rsp
subq $48,%rsp
movq %rbx,-.F757-8(%rbp)
movq %r12,-.F757-16(%rbp)
movq %r13,-.F757-24(%rbp)
movq %r14,-.F757-32(%rbp)
movq %r15,-.F757-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq %r14,%rdi
movq (%rdi),%rax
mfence
movq %rax,%rbx
.L758:
movabsq $1,%rax
testq %rax,%rax
jz .L759
movq %rbx,%rax
addq %r15,%rax
movq %rax,%r12
movq %r14,%rdi
movq %rbx,%rax
movq %r12,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
cmpq %rbx,%rax
jne .L760
movq %rbx,%rax
movq -.F757-8(%rbp),%rbx
movq -.F757-16(%rbp),%r12
movq -.F757-24(%rbp),%r13
movq -.F757-32(%rbp),%r14
movq -.F757-40(%rbp),%r15
leave
ret
jmp .L761
.L760:
.L761:
movq %r13,%rbx
jmp .L758
.L759:
movabsq $0,%rax
movq -.F757-8(%rbp),%rbx
movq -.F757-16(%rbp),%r12
movq -.F757-24(%rbp),%r13
movq -.F757-32(%rbp),%r14
movq -.F757-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F757-8(%rbp),%rbx
movq -.F757-16(%rbp),%r12
movq -.F757-24(%rbp),%r13
movq -.F757-32(%rbp),%r14
movq -.F757-40(%rbp),%r15
leave
ret
.set .F757,16
.type rt_atomic_fetch_sub,@function
rt_atomic_fetch_sub:
pushq %rbp
movq %rsp,%rbp
subq $.F762,%rsp
subq $48,%rsp
movq %rbx,-.F762-8(%rbp)
movq %r12,-.F762-16(%rbp)
movq %r13,-.F762-24(%rbp)
movq %r14,-.F762-32(%rbp)
movq %r15,-.F762-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq %r14,%rdi
movq (%rdi),%rax
mfence
movq %rax,%rbx
.L763:
movabsq $1,%rax
testq %rax,%rax
jz .L764
movq %rbx,%rax
subq %r15,%rax
movq %rax,%r12
movq %r14,%rdi
movq %rbx,%rax
movq %r12,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
cmpq %rbx,%rax
jne .L765
movq %rbx,%rax
movq -.F762-8(%rbp),%rbx
movq -.F762-16(%rbp),%r12
movq -.F762-24(%rbp),%r13
movq -.F762-32(%rbp),%r14
movq -.F762-40(%rbp),%r15
leave
ret
jmp .L766
.L765:
.L766:
movq %r13,%rbx
jmp .L763
.L764:
movabsq $0,%rax
movq -.F762-8(%rbp),%rbx
movq -.F762-16(%rbp),%r12
movq -.F762-24(%rbp),%r13
movq -.F762-32(%rbp),%r14
movq -.F762-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F762-8(%rbp),%rbx
movq -.F762-16(%rbp),%r12
movq -.F762-24(%rbp),%r13
movq -.F762-32(%rbp),%r14
movq -.F762-40(%rbp),%r15
leave
ret
.set .F762,16
.type rt_atomic_swap,@function
rt_atomic_swap:
pushq %rbp
movq %rsp,%rbp
subq $.F767,%rsp
subq $32,%rsp
movq %rbx,-.F767-8(%rbp)
movq %r12,-.F767-16(%rbp)
movq %r13,-.F767-24(%rbp)
movq %r14,-.F767-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,%r14
movq %r13,%rdi
movq (%rdi),%rax
mfence
movq %rax,%rbx
.L768:
movabsq $1,%rax
testq %rax,%rax
jz .L769
movq %r13,%rdi
movq %rbx,%rax
movq %r14,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r12
cmpq %rbx,%rax
jne .L770
movq %rbx,%rax
movq -.F767-8(%rbp),%rbx
movq -.F767-16(%rbp),%r12
movq -.F767-24(%rbp),%r13
movq -.F767-32(%rbp),%r14
leave
ret
jmp .L771
.L770:
.L771:
movq %r12,%rbx
jmp .L768
.L769:
movabsq $0,%rax
movq -.F767-8(%rbp),%rbx
movq -.F767-16(%rbp),%r12
movq -.F767-24(%rbp),%r13
movq -.F767-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F767-8(%rbp),%rbx
movq -.F767-16(%rbp),%r12
movq -.F767-24(%rbp),%r13
movq -.F767-32(%rbp),%r14
leave
ret
.set .F767,16
.type rt_mutex_new,@function
rt_mutex_new:
pushq %rbp
movq %rsp,%rbp
subq $.F772,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $16,%rdi
call rt_alloc
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -16(%rbp),%rax
addq $8,%rax
jnc .L773
call rt_abort
.L773:
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F772,32
.type rt_mutex_unlock,@function
rt_mutex_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F774,%rsp
subq $16,%rsp
movq %rbx,-.F774-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_sub
movq %rax,-16(%rbp)
movabsq $1,%rcx
cmpq $1,%rax
je .L775
movq %rbx,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $129,%rdx
movabsq $1,%rcx
call rt_syscall
jmp .L776
.L775:
.L776:
movabsq $0,%rax
movq -.F774-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F774-8(%rbp),%rbx
leave
ret
.set .F774,16
.type rt_cpus,@function
rt_cpus:
pushq %rbp
movq %rsp,%rbp
subq $.F777,%rsp
subq $32,%rsp
movq %rbx,-.F777-8(%rbp)
movq %r12,-.F777-16(%rbp)
movq %r13,-.F777-24(%rbp)
movq %r14,-.F777-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movabsq $128,%rdi
call rt_alloc
movq %rax,%r14
movabsq $204,%rdi
movabsq $0,%rsi
movabsq $128,%rdx
movq %rax,%rcx
call rt_syscall
movq %rax,-8(%rbp)
movq $0,%r12
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i20
xorq %rax,%rax
jmp .Lret_i20
.Lret_i20:
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L778
movq $0,%r13
.L780:
movabsq $128,%rcx
cmpq $128,%r13
jae .L781
movq %r14,%rax
addq %r13,%rax
jnc .L782
call rt_abort
.L782:
movzbq (%rax),%rax
movq %rax,%rbx
.L783:
cmpq $0,%rbx
je .L784
movq %rbx,%rax
andq $1,%rax
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L785
call rt_abort
.L785:
movq %rax,%r12
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L786:
movq %rax,%rbx
jmp .L783
.L784:
movq %r13,%rax
addq $1,%rax
jnc .L787
call rt_abort
.L787:
movq %rax,%r13
jmp .L780
.L781:
jmp .L779
.L778:
.L779:
movq %r14,%rdi
call rt_free
cmpq $0,%r12
jne .L788
movq $1,%r12
jmp .L789
.L788:
.L789:
movq %r12,%rax
movq -.F777-8(%rbp),%rbx
movq -.F777-16(%rbp),%r12
movq -.F777-24(%rbp),%r13
movq -.F777-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F777-8(%rbp),%rbx
movq -.F777-16(%rbp),%r12
movq -.F777-24(%rbp),%r13
movq -.F777-32(%rbp),%r14
leave
ret
.set .F777,16
.type rt_thread_spawn,@function
rt_thread_spawn:
pushq %rbp
movq %rsp,%rbp
subq $.F790,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
leaq -.F790(%rbp),%rdi
movq $.F790/8-2,%rcx
xorl %eax,%eax
rep stosq
movabsq $1048576,%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
movq %rax,-32(%rbp)
movq -32(%rbp),%rax
movq %rax,-40(%rbp)
movq -40(%rbp),%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,-48(%rbp)
movq -48(%rbp),%rax
movq %rax,-56(%rbp)
movq -56(%rbp),%rax
movq %rax,-64(%rbp)
movq -64(%rbp),%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i21
xorq %rax,%rax
jmp .Lret_i21
.Lret_i21:
movq %rax,-72(%rbp)
movq -72(%rbp),%rax
testq %rax,%rax
jz .L791
call rt_abort
movq %rax,-80(%rbp)
jmp .L792
.L791:
.L792:
movabsq $10,%rax
movq %rax,-88(%rbp)
movq -88(%rbp),%rax
movq %rax,-96(%rbp)
movq -56(%rbp),%rax
movq %rax,-104(%rbp)
movabsq $4096,%rax
movq %rax,-112(%rbp)
movq -112(%rbp),%rax
movq %rax,-120(%rbp)
movabsq $0,%rax
movq %rax,-128(%rbp)
movq -128(%rbp),%rax
movq %rax,-136(%rbp)
movq -96(%rbp),%rdi
movq -104(%rbp),%rsi
movq -120(%rbp),%rdx
movq -136(%rbp),%rcx
call rt_syscall
movq %rax,-144(%rbp)
movq -144(%rbp),%rax
movq %rax,-152(%rbp)
movq -152(%rbp),%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i22
xorq %rax,%rax
jmp .Lret_i22
.Lret_i22:
movq %rax,-160(%rbp)
movq -160(%rbp),%rax
testq %rax,%rax
jz .L793
call rt_abort
movq %rax,-168(%rbp)
jmp .L794
.L793:
.L794:
movabsq $24,%rax
movq %rax,-176(%rbp)
movq -176(%rbp),%rax
movq %rax,-184(%rbp)
movq -184(%rbp),%rdi
call rt_alloc
movq %rax,-192(%rbp)
movq -192(%rbp),%rax
movq %rax,-200(%rbp)
movq -200(%rbp),%rax
movq %rax,-208(%rbp)
movabsq $8,%rax
movq %rax,-216(%rbp)
movq -216(%rbp),%rcx
movq -208(%rbp),%rax
addq %rcx,%rax
jnc .L795
call rt_abort
.L795:
movq %rax,-224(%rbp)
movq -224(%rbp),%rax
movq %rax,-232(%rbp)
movq -56(%rbp),%rax
movq %rax,-240(%rbp)
movq -232(%rbp),%rcx
movq -240(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-248(%rbp)
movq -200(%rbp),%rax
movq %rax,-256(%rbp)
movabsq $16,%rax
movq %rax,-264(%rbp)
movq -264(%rbp),%rcx
movq -256(%rbp),%rax
addq %rcx,%rax
jnc .L796
call rt_abort
.L796:
movq %rax,-272(%rbp)
movq -272(%rbp),%rax
movq %rax,-280(%rbp)
movq -32(%rbp),%rax
movq %rax,-288(%rbp)
movq -280(%rbp),%rcx
movq -288(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-296(%rbp)
movq -56(%rbp),%rax
movq %rax,-304(%rbp)
movq -32(%rbp),%rcx
movq -304(%rbp),%rax
addq %rcx,%rax
jnc .L797
call rt_abort
.L797:
movq %rax,-312(%rbp)
movq -312(%rbp),%rax
movq %rax,-320(%rbp)
movq -320(%rbp),%rax
movq %rax,-328(%rbp)
movabsq $64,%rax
movq %rax,-336(%rbp)
movq -336(%rbp),%rcx
movq -328(%rbp),%rax
subq %rcx,%rax
jnc .L798
call rt_abort
.L798:
movq %rax,-344(%rbp)
movq -344(%rbp),%rax
movq %rax,-352(%rbp)
movq -352(%rbp),%rax
movq %rax,-360(%rbp)
movabsq $24,%rax
movq %rax,-368(%rbp)
movq -368(%rbp),%rcx
movq -360(%rbp),%rax
addq %rcx,%rax
jnc .L799
call rt_abort
.L799:
movq %rax,-376(%rbp)
movq -376(%rbp),%rax
movq %rax,-384(%rbp)
movq -8(%rbp),%rax
movq %rax,-392(%rbp)
movq -384(%rbp),%rcx
movq -392(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-400(%rbp)
movq -352(%rbp),%rax
movq %rax,-408(%rbp)
movabsq $32,%rax
movq %rax,-416(%rbp)
movq -416(%rbp),%rcx
movq -408(%rbp),%rax
addq %rcx,%rax
jnc .L800
call rt_abort
.L800:
movq %rax,-424(%rbp)
movq -424(%rbp),%rax
movq %rax,-432(%rbp)
movq -16(%rbp),%rax
movq %rax,-440(%rbp)
movq -432(%rbp),%rcx
movq -440(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-448(%rbp)
movq -320(%rbp),%rax
movq %rax,-456(%rbp)
movabsq $80,%rax
movq %rax,-464(%rbp)
movq -464(%rbp),%rcx
movq -456(%rbp),%rax
subq %rcx,%rax
jnc .L801
call rt_abort
.L801:
movq %rax,-472(%rbp)
movq -472(%rbp),%rax
movq %rax,-480(%rbp)
leaq rt_thread_main(%rip),%rax
movq %rax,-488(%rbp)
movq -488(%rbp),%rax
movq %rax,-496(%rbp)
movq -480(%rbp),%rcx
movq -496(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-504(%rbp)
movq -320(%rbp),%rax
movq %rax,-512(%rbp)
movabsq $72,%rax
movq %rax,-520(%rbp)
movq -520(%rbp),%rcx
movq -512(%rbp),%rax
subq %rcx,%rax
jnc .L802
call rt_abort
.L802:
movq %rax,-528(%rbp)
movq -528(%rbp),%rax
movq %rax,-536(%rbp)
movq -352(%rbp),%rax
movq %rax,-544(%rbp)
movq -536(%rbp),%rcx
movq -544(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-552(%rbp)
movabsq $3477248,%rax
movq %rax,-560(%rbp)
movq -560(%rbp),%rax
movq %rax,-568(%rbp)
movq -320(%rbp),%rax
movq %rax,-576(%rbp)
movabsq $80,%rax
movq %rax,-584(%rbp)
movq -584(%rbp),%rcx
movq -576(%rbp),%rax
subq %rcx,%rax
jnc .L803
call rt_abort
.L803:
movq %rax,-592(%rbp)
movq -592(%rbp),%rax
movq %rax,-600(%rbp)
movq -200(%rbp),%rax
movq %rax,-608(%rbp)
movq -568(%rbp),%rdi
movq -600(%rbp),%rsi
movq -608(%rbp),%rdx
movq %rdx,%r10
movl $56,%eax
syscall
testq %rax,%rax
jnz .L804
xorl %ebp,%ebp
popq %rax
popq %rdi
call *%rax
movl $60,%eax
xorl %edi,%edi
syscall
ud2
.L804:
movq %rax,-616(%rbp)
movq -616(%rbp),%rax
movq %rax,-624(%rbp)
movq -624(%rbp),%rax
movq %rax,-632(%rbp)
movq -632(%rbp),%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i23
xorq %rax,%rax
jmp .Lret_i23
.Lret_i23:
movq %rax,-640(%rbp)
movq -640(%rbp),%rax
testq %rax,%rax
jz .L805
call rt_abort
movq %rax,-648(%rbp)
jmp .L806
.L805:
.L806:
movq -200(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F790,656
.type rt_thread_spawn_detached,@function
rt_thread_spawn_detached:
pushq %rbp
movq %rsp,%rbp
subq $.F807,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
leaq -.F807(%rbp),%rdi
movq $.F807/8-2,%rcx
xorl %eax,%eax
rep stosq
movabsq $1048576,%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
movq %rax,-32(%rbp)
movq -32(%rbp),%rax
movq %rax,-40(%rbp)
movq -40(%rbp),%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,-48(%rbp)
movq -48(%rbp),%rax
movq %rax,-56(%rbp)
movq -56(%rbp),%rax
movq %rax,-64(%rbp)
movq -64(%rbp),%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i24
xorq %rax,%rax
jmp .Lret_i24
.Lret_i24:
movq %rax,-72(%rbp)
movq -72(%rbp),%rax
testq %rax,%rax
jz .L808
call rt_abort
movq %rax,-80(%rbp)
jmp .L809
.L808:
.L809:
movabsq $10,%rax
movq %rax,-88(%rbp)
movq -88(%rbp),%rax
movq %rax,-96(%rbp)
movq -56(%rbp),%rax
movq %rax,-104(%rbp)
movabsq $4096,%rax
movq %rax,-112(%rbp)
movq -112(%rbp),%rax
movq %rax,-120(%rbp)
movabsq $0,%rax
movq %rax,-128(%rbp)
movq -128(%rbp),%rax
movq %rax,-136(%rbp)
movq -96(%rbp),%rdi
movq -104(%rbp),%rsi
movq -120(%rbp),%rdx
movq -136(%rbp),%rcx
call rt_syscall
movq %rax,-144(%rbp)
movq -144(%rbp),%rax
movq %rax,-152(%rbp)
movq -152(%rbp),%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i25
xorq %rax,%rax
jmp .Lret_i25
.Lret_i25:
movq %rax,-160(%rbp)
movq -160(%rbp),%rax
testq %rax,%rax
jz .L810
call rt_abort
movq %rax,-168(%rbp)
jmp .L811
.L810:
.L811:
movq -56(%rbp),%rax
movq %rax,-176(%rbp)
movq -32(%rbp),%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L812
call rt_abort
.L812:
movq %rax,-184(%rbp)
movq -184(%rbp),%rax
movq %rax,-192(%rbp)
movq -192(%rbp),%rax
movq %rax,-200(%rbp)
movabsq $64,%rax
movq %rax,-208(%rbp)
movq -208(%rbp),%rcx
movq -200(%rbp),%rax
subq %rcx,%rax
jnc .L813
call rt_abort
.L813:
movq %rax,-216(%rbp)
movq -216(%rbp),%rax
movq %rax,-224(%rbp)
movq -224(%rbp),%rax
movq %rax,-232(%rbp)
movabsq $24,%rax
movq %rax,-240(%rbp)
movq -240(%rbp),%rcx
movq -232(%rbp),%rax
addq %rcx,%rax
jnc .L814
call rt_abort
.L814:
movq %rax,-248(%rbp)
movq -248(%rbp),%rax
movq %rax,-256(%rbp)
movq -8(%rbp),%rax
movq %rax,-264(%rbp)
movq -256(%rbp),%rcx
movq -264(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-272(%rbp)
movq -224(%rbp),%rax
movq %rax,-280(%rbp)
movabsq $32,%rax
movq %rax,-288(%rbp)
movq -288(%rbp),%rcx
movq -280(%rbp),%rax
addq %rcx,%rax
jnc .L815
call rt_abort
.L815:
movq %rax,-296(%rbp)
movq -296(%rbp),%rax
movq %rax,-304(%rbp)
movq -16(%rbp),%rax
movq %rax,-312(%rbp)
movq -304(%rbp),%rcx
movq -312(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-320(%rbp)
movq -192(%rbp),%rax
movq %rax,-328(%rbp)
movabsq $80,%rax
movq %rax,-336(%rbp)
movq -336(%rbp),%rcx
movq -328(%rbp),%rax
subq %rcx,%rax
jnc .L816
call rt_abort
.L816:
movq %rax,-344(%rbp)
movq -344(%rbp),%rax
movq %rax,-352(%rbp)
leaq rt_thread_main(%rip),%rax
movq %rax,-360(%rbp)
movq -360(%rbp),%rax
movq %rax,-368(%rbp)
movq -352(%rbp),%rcx
movq -368(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-376(%rbp)
movq -192(%rbp),%rax
movq %rax,-384(%rbp)
movabsq $72,%rax
movq %rax,-392(%rbp)
movq -392(%rbp),%rcx
movq -384(%rbp),%rax
subq %rcx,%rax
jnc .L817
call rt_abort
.L817:
movq %rax,-400(%rbp)
movq -400(%rbp),%rax
movq %rax,-408(%rbp)
movq -224(%rbp),%rax
movq %rax,-416(%rbp)
movq -408(%rbp),%rcx
movq -416(%rbp),%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rax,-424(%rbp)
movabsq $3477248,%rax
movq %rax,-432(%rbp)
movq -432(%rbp),%rax
movq %rax,-440(%rbp)
movq -192(%rbp),%rax
movq %rax,-448(%rbp)
movabsq $80,%rax
movq %rax,-456(%rbp)
movq -456(%rbp),%rcx
movq -448(%rbp),%rax
subq %rcx,%rax
jnc .L818
call rt_abort
.L818:
movq %rax,-464(%rbp)
movq -464(%rbp),%rax
movq %rax,-472(%rbp)
movq -224(%rbp),%rax
movq %rax,-480(%rbp)
movabsq $40,%rax
movq %rax,-488(%rbp)
movq -488(%rbp),%rcx
movq -480(%rbp),%rax
addq %rcx,%rax
jnc .L819
call rt_abort
.L819:
movq %rax,-496(%rbp)
movq -496(%rbp),%rax
movq %rax,-504(%rbp)
movq -440(%rbp),%rdi
movq -472(%rbp),%rsi
movq -504(%rbp),%rdx
movq %rdx,%r10
movl $56,%eax
syscall
testq %rax,%rax
jnz .L820
xorl %ebp,%ebp
popq %rax
popq %rdi
call *%rax
movl $60,%eax
xorl %edi,%edi
syscall
ud2
.L820:
movq %rax,-512(%rbp)
movq -512(%rbp),%rax
movq %rax,-520(%rbp)
movq -520(%rbp),%rax
movq %rax,-528(%rbp)
movq -528(%rbp),%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i26
xorq %rax,%rax
jmp .Lret_i26
.Lret_i26:
movq %rax,-536(%rbp)
movq -536(%rbp),%rax
testq %rax,%rax
jz .L821
call rt_abort
movq %rax,-544(%rbp)
jmp .L822
.L821:
.L822:
movabsq $0,%rax
movq %rax,-552(%rbp)
movq -552(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F807,560
.type rt_thread_main,@function
rt_thread_main:
pushq %rbp
movq %rsp,%rbp
subq $.F823,%rsp
subq $16,%rsp
movq %rbx,-.F823-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
movq %rbx,%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movq %rbx,%rax
movq %rbx,%rsi
movl $4098,%edi
movl $158,%eax
syscall
movq %rsi,rt_grail_tls(%rip)
movq %rbx,%rax
addq $24,%rax
jnc .L824
call rt_abort
.L824:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L825
call rt_abort
.L825:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
movq -16(%rbp),%rax
call *%rax
movabsq $0,%rax
movq -.F823-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F823-8(%rbp),%rbx
leave
ret
.set .F823,32
.type rt_thread_join,@function
rt_thread_join:
pushq %rbp
movq %rsp,%rbp
subq $.F826,%rsp
subq $32,%rsp
movq %rbx,-.F826-8(%rbp)
movq %r12,-.F826-16(%rbp)
movq %r13,-.F826-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
.L827:
movabsq $1,%rax
testq %rax,%rax
jz .L828
movq %rbx,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movq %rax,%r13
cmpq $0,%rax
jne .L829
jmp .L828
jmp .L830
.L829:
.L830:
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $0,%rdx
movq %r12,%rcx
call rt_syscall
jmp .L827
.L828:
movq %rbx,%rax
addq $8,%rax
jnc .L831
call rt_abort
.L831:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L832
call rt_abort
.L832:
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $11,%rdi
movq -16(%rbp),%rsi
movq %rax,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i27
xorq %rax,%rax
jmp .Lret_i27
.Lret_i27:
testq %rax,%rax
jz .L833
call rt_abort
jmp .L834
.L833:
.L834:
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
movq -.F826-8(%rbp),%rbx
movq -.F826-16(%rbp),%r12
movq -.F826-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F826-8(%rbp),%rbx
movq -.F826-16(%rbp),%r12
movq -.F826-24(%rbp),%r13
leave
ret
.set .F826,32
.type rt_parallel_worker,@function
rt_parallel_worker:
pushq %rbp
movq %rsp,%rbp
subq $.F835,%rsp
subq $48,%rsp
movq %rbx,-.F835-8(%rbp)
movq %r12,-.F835-16(%rbp)
movq %r13,-.F835-24(%rbp)
movq %r14,-.F835-32(%rbp)
movq %r15,-.F835-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r12
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq %r12,%rax
movq (%rax),%rax
movq %rax,%r13
movq %r12,%rax
addq $8,%rax
jnc .L836
call rt_abort
.L836:
movq (%rax),%rax
movq %rax,%r14
movq %r12,%rax
addq $16,%rax
jnc .L837
call rt_abort
.L837:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %r12,%rax
addq $24,%rax
jnc .L838
call rt_abort
.L838:
movq (%rax),%rax
movq %rax,%r15
movq %r12,%rax
addq $32,%rax
jnc .L839
call rt_abort
.L839:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %r12,%rax
addq $56,%rax
jnc .L840
call rt_abort
.L840:
movq (%rax),%rax
movq %rax,-32(%rbp)
.L841:
movabsq $1,%rax
testq %rax,%rax
jz .L842
movabsq $40,%rcx
movq %r12,%rax
addq $40,%rax
jnc .L843
call rt_abort
.L843:
movq %rax,-40(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movq %rax,%rbx
movq -16(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L844
jmp .L842
jmp .L845
.L844:
.L845:
movq -32(%rbp),%rax
cmpq $0,%rax
jne .L846
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L848
call rt_abort
.L848:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L849
call rt_abort
.L849:
movq %rax,-56(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L850
call rt_abort
.L850:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L851
call rt_abort
.L851:
movq (%rax),%rax
movq %rax,-64(%rbp)
movq -64(%rbp),%rdi
movq %r15,%rsi
movq %r13,%rax
call *%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L847
.L846:
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L852
call rt_abort
.L852:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L853
call rt_abort
.L853:
movq %rax,-72(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L854
call rt_abort
.L854:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L855
call rt_abort
.L855:
movq (%rax),%rax
movq %rax,-80(%rbp)
movq -32(%rbp),%rdi
movq -80(%rbp),%rsi
movq %r15,%rdx
movq %r13,%rax
call *%rax
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
.L847:
jmp .L841
.L842:
movabsq $48,%rcx
movq %r12,%rax
addq $48,%rax
jnc .L856
call rt_abort
.L856:
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movabsq $0,%rax
movq -.F835-8(%rbp),%rbx
movq -.F835-16(%rbp),%r12
movq -.F835-24(%rbp),%r13
movq -.F835-32(%rbp),%r14
movq -.F835-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F835-8(%rbp),%rbx
movq -.F835-16(%rbp),%r12
movq -.F835-24(%rbp),%r13
movq -.F835-32(%rbp),%r14
movq -.F835-40(%rbp),%r15
leave
ret
.set .F835,96
.type rt_parallel_map,@function
rt_parallel_map:
pushq %rbp
movq %rsp,%rbp
subq $.F857,%rsp
subq $48,%rsp
movq %rbx,-.F857-8(%rbp)
movq %r12,-.F857-16(%rbp)
movq %r13,-.F857-24(%rbp)
movq %r14,-.F857-32(%rbp)
movq %r15,-.F857-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movq $0,-136(%rbp)
movq $0,-144(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
call rt_new
movq %rax,-48(%rbp)
movq $0,%r14
.L858:
movq -40(%rbp),%rcx
cmpq %rcx,%r14
jae .L859
movq -48(%rbp),%rdi
movabsq $0,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt27
call rt_push
jmp .Lopt28
.Lopt27:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt28:
movq %r14,%rax
addq $1,%rax
jnc .L860
call rt_abort
.L860:
movq %rax,%r14
jmp .L858
.L859:
movabsq $64,%rdi
call rt_alloc
movq %rax,%r13
movq %rax,-56(%rbp)
addq $56,%rax
jnc .L861
call rt_abort
.L861:
movq %rax,-64(%rbp)
movq -32(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $40,%rax
jnc .L862
call rt_abort
.L862:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r13,%rax
addq $48,%rax
jnc .L863
call rt_abort
.L863:
movq %rax,-80(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
movq %r13,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $8,%rax
jnc .L864
call rt_abort
.L864:
movq %rax,-88(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $16,%rax
jnc .L865
call rt_abort
.L865:
movq %rax,-96(%rbp)
movq -40(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $24,%rax
jnc .L866
call rt_abort
.L866:
movq %rax,-104(%rbp)
movq -16(%rbp),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $32,%rax
jnc .L867
call rt_abort
.L867:
movq %rax,-112(%rbp)
movq -48(%rbp),%rax
movq (%rax),%rax
movq -112(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
call rt_cpus
movq %rax,%r12
movq %rax,-120(%rbp)
cmpq $4,%rax
jae .L868
movq $4,%r12
jmp .L869
.L868:
.L869:
movabsq $64,%rax
cmpq %r12,%rax
jae .L870
movq $64,%r12
jmp .L871
.L870:
.L871:
movq -40(%rbp),%rax
cmpq %r12,%rax
jae .L872
movq -40(%rbp),%rax
movq %rax,%r12
jmp .L873
.L872:
.L873:
cmpq $0,%r12
jne .L874
movq $1,%r12
jmp .L875
.L874:
.L875:
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L876
call rt_abort
.L876:
movq %rax,%rdi
call rt_alloc
movq %rax,%r15
movq $1,%rbx
.L877:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L878
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L879
call rt_abort
.L879:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L880
call rt_abort
.L880:
movq %rax,-128(%rbp)
leaq rt_parallel_worker(%rip),%rax
movq %rax,-136(%rbp)
movq -136(%rbp),%rdi
movq %r13,%rsi
call rt_thread_spawn
movq -128(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L881
call rt_abort
.L881:
movq %rax,%rbx
jmp .L877
.L878:
movq %r13,%rdi
call rt_parallel_worker
movq $1,%rbx
.L882:
cmpq %r12,%rbx
jae .L883
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L884
call rt_abort
.L884:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L885
call rt_abort
.L885:
movq (%rax),%rax
movq %rax,%rdi
call rt_thread_join
movq %rbx,%rax
addq $1,%rax
jnc .L886
call rt_abort
.L886:
movq %rax,%rbx
jmp .L882
.L883:
movabsq $48,%rcx
movq %r13,%rax
addq $48,%rax
jnc .L887
call rt_abort
.L887:
movq %rax,%rdi
call rt_atomic_load
movq %r12,%rcx
cmpq %r12,%rax
je .L888
call rt_abort
jmp .L889
.L888:
.L889:
movq %r15,%rdi
call rt_free
movq %r13,%rdi
call rt_free
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_drop_seq
movq -48(%rbp),%rax
movq -.F857-8(%rbp),%rbx
movq -.F857-16(%rbp),%r12
movq -.F857-24(%rbp),%r13
movq -.F857-32(%rbp),%r14
movq -.F857-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F857-8(%rbp),%rbx
movq -.F857-16(%rbp),%r12
movq -.F857-24(%rbp),%r13
movq -.F857-32(%rbp),%r14
movq -.F857-40(%rbp),%r15
leave
ret
.set .F857,144
.type rt_thread_init,@function
rt_thread_init:
pushq %rbp
movq %rsp,%rbp
subq $.F890,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movq -8(%rbp),%rax
addq $128,%rax
jnc .L891
call rt_abort
.L891:
movq %rax,-16(%rbp)
movq %rax,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
movq %rax,%rsi
movl $4098,%edi
movl $158,%eax
syscall
movq %rsi,rt_grail_tls(%rip)
movabsq $0,%rax
jmp .Lret_i28
xorq %rax,%rax
jmp .Lret_i28
.Lret_i28:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F890,16
.type rt_current,@function
rt_current:
pushq %rbp
movq %rsp,%rbp
subq $.F892,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq %fs:0,%rax
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L893
movabsq $0,%rax
leave
ret
jmp .L894
.L893:
.L894:
movq -8(%rbp),%rax
addq $16,%rax
jnc .L895
call rt_abort
.L895:
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F892,16
.type rt_spin_lock,@function
rt_spin_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F896,%rsp
subq $16,%rsp
movq %rbx,-.F896-8(%rbp)
movq %r12,-.F896-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq $0,-16(%rbp)
.L897:
movq %r12,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%rbx
cmpq $0,%rax
je .L898
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L897
.L898:
movabsq $0,%rax
movq -.F896-8(%rbp),%rbx
movq -.F896-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F896-8(%rbp),%rbx
movq -.F896-16(%rbp),%r12
leave
ret
.set .F896,16
.type rt_spin_unlock,@function
rt_spin_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F899,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $0,%rax
sfence
movq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F899,16
.type rt_sched,@function
rt_sched:
pushq %rbp
movq %rsp,%rbp
subq $.F900,%rsp
subq $48,%rsp
movq %rbx,-.F900-8(%rbp)
movq %r12,-.F900-16(%rbp)
movq %r13,-.F900-24(%rbp)
movq %r14,-.F900-32(%rbp)
movq %r15,-.F900-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
leaq rt_state(%rip),%rax
movq %rax,%r14
movq %rax,-8(%rbp)
movabsq $72,%rcx
addq $72,%rax
jnc .L901
call rt_abort
.L901:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
cmpq $0,%rax
je .L902
movq -16(%rbp),%rax
movq -.F900-8(%rbp),%rbx
movq -.F900-16(%rbp),%r12
movq -.F900-24(%rbp),%r13
movq -.F900-32(%rbp),%r14
movq -.F900-40(%rbp),%r15
leave
ret
jmp .L903
.L902:
.L903:
movq %r14,%rax
addq $80,%rax
jnc .L904
call rt_abort
.L904:
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L905
movabsq $4096,%rax
movabsq $4096,%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,%r12
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i29
xorq %rax,%rax
jmp .Lret_i29
.Lret_i29:
testq %rax,%rax
jz .L907
call rt_abort
jmp .L908
.L907:
.L908:
movabsq $291,%rdi
movabsq $524288,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-48(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i30
xorq %rax,%rax
jmp .Lret_i30
.Lret_i30:
testq %rax,%rax
jz .L909
call rt_abort
jmp .L910
.L909:
.L910:
movq %r12,%rax
addq $40,%rax
jnc .L911
call rt_abort
.L911:
movq %rax,-56(%rbp)
movq -48(%rbp),%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $290,%rdi
movabsq $0,%rsi
movabsq $526336,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-64(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i31
xorq %rax,%rax
jmp .Lret_i31
.Lret_i31:
testq %rax,%rax
jz .L912
call rt_abort
jmp .L913
.L912:
.L913:
movq %r12,%rax
addq $48,%rax
jnc .L914
call rt_abort
.L914:
movq %rax,-72(%rbp)
movq -64(%rbp),%rax
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $4096,%rax
movabsq $4096,%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,-80(%rbp)
movq %rax,-88(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq -80(%rbp),%rax
movabsq $233,%rdi
movq -48(%rbp),%rsi
movabsq $1,%rdx
movq -64(%rbp),%rcx
movq %rax,%r8
call rt_syscall4
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i32
xorq %rax,%rax
jmp .Lret_i32
.Lret_i32:
testq %rax,%rax
jz .L915
call rt_abort
jmp .L916
.L915:
.L916:
movabsq $11,%rdi
movq -80(%rbp),%rsi
movabsq $4096,%rdx
movabsq $0,%rcx
call rt_syscall
call rt_cpus
movq %rax,%r13
movq %rax,-96(%rbp)
cmpq $4,%rax
jae .L917
movq $4,%r13
jmp .L918
.L917:
.L918:
movabsq $64,%rax
cmpq %r13,%rax
jae .L919
movq $64,%r13
jmp .L920
.L919:
.L920:
movq %r12,%rax
addq $32,%rax
jnc .L921
call rt_abort
.L921:
movq %rax,-104(%rbp)
movq %r13,%rax
movq -104(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L922
call rt_abort
.L922:
movq %rax,-112(%rbp)
movq %r12,%rax
movq -112(%rbp),%rdi
xchgq %rax,(%rdi)
xorq %rax,%rax
movq $0,%rbx
.L923:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L924
leaq rt_worker_loop(%rip),%rax
movq %rax,%r15
movq %r15,%rdi
movq %r12,%rsi
call rt_thread_spawn_detached
movq %rbx,%rax
addq $1,%rax
jnc .L925
call rt_abort
.L925:
movq %rax,%rbx
jmp .L923
.L924:
leaq rt_reactor(%rip),%rax
movq %rax,-120(%rbp)
movq -120(%rbp),%rdi
movq %r12,%rsi
call rt_thread_spawn_detached
movq %r12,%rax
movq -.F900-8(%rbp),%rbx
movq -.F900-16(%rbp),%r12
movq -.F900-24(%rbp),%r13
movq -.F900-32(%rbp),%r14
movq -.F900-40(%rbp),%r15
leave
ret
jmp .L906
.L905:
.L906:
.L926:
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L928
call rt_abort
.L928:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,-128(%rbp)
cmpq $0,%rax
jne .L927
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L926
.L927:
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L929
call rt_abort
.L929:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq -.F900-8(%rbp),%rbx
movq -.F900-16(%rbp),%r12
movq -.F900-24(%rbp),%r13
movq -.F900-32(%rbp),%r14
movq -.F900-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F900-8(%rbp),%rbx
movq -.F900-16(%rbp),%r12
movq -.F900-24(%rbp),%r13
movq -.F900-32(%rbp),%r14
movq -.F900-40(%rbp),%r15
leave
ret
.set .F900,128
.type rt_enqueue,@function
rt_enqueue:
pushq %rbp
movq %rsp,%rbp
subq $.F930,%rsp
subq $16,%rsp
movq %rbx,-.F930-8(%rbp)
movq %r12,-.F930-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
call rt_sched
movq %rax,%rbx
movq %rax,%rdi
call rt_spin_lock
movq %r12,%rax
addq $32,%rax
jnc .L931
call rt_abort
.L931:
movq %rax,-16(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L932
call rt_abort
.L932:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L933
movq %rbx,%rax
addq $8,%rax
jnc .L935
call rt_abort
.L935:
movq %rax,-40(%rbp)
movq %r12,%rax
movq -40(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L934
.L933:
movq -24(%rbp),%rax
addq $32,%rax
jnc .L936
call rt_abort
.L936:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
.L934:
movq %rbx,%rax
addq $16,%rax
jnc .L937
call rt_abort
.L937:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movq %rbx,%rdi
call rt_spin_unlock
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L938
call rt_abort
.L938:
movq %rax,-64(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movq %rbx,%rax
addq $24,%rax
jnc .L939
call rt_abort
.L939:
movq %rax,-72(%rbp)
movabsq $202,%rdi
movq %rax,%rsi
movabsq $129,%rdx
movabsq $1,%rcx
call rt_syscall
movabsq $0,%rax
movq -.F930-8(%rbp),%rbx
movq -.F930-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F930-8(%rbp),%rbx
movq -.F930-16(%rbp),%r12
leave
ret
.set .F930,80
.type rt_dequeue,@function
rt_dequeue:
pushq %rbp
movq %rsp,%rbp
subq $.F940,%rsp
subq $48,%rsp
movq %rbx,-.F940-8(%rbp)
movq %r12,-.F940-16(%rbp)
movq %r13,-.F940-24(%rbp)
movq %r14,-.F940-32(%rbp)
movq %r15,-.F940-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
.L941:
movabsq $1,%rax
testq %rax,%rax
jz .L942
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L943
call rt_abort
.L943:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r14
movq %rbx,%rdi
call rt_spin_lock
movq %rbx,%rax
addq $8,%rax
jnc .L944
call rt_abort
.L944:
movq (%rax),%rax
movq %rax,%r12
movq %rax,%r15
movabsq $0,%rcx
cmpq $0,%rax
je .L945
movq %r12,%rax
addq $32,%rax
jnc .L947
call rt_abort
.L947:
movq (%rax),%rax
movq %rax,%r13
movq %rbx,%rax
addq $8,%rax
jnc .L948
call rt_abort
.L948:
movq %rax,-16(%rbp)
movq %r13,%rax
movq -16(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movabsq $0,%rcx
cmpq $0,%r13
jne .L949
movq %rbx,%rax
addq $16,%rax
jnc .L951
call rt_abort
.L951:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
jmp .L950
.L949:
.L950:
movq %rbx,%rdi
call rt_spin_unlock
movq %r12,%rax
movq -.F940-8(%rbp),%rbx
movq -.F940-16(%rbp),%r12
movq -.F940-24(%rbp),%r13
movq -.F940-32(%rbp),%r14
movq -.F940-40(%rbp),%r15
leave
ret
jmp .L946
.L945:
.L946:
movq %rbx,%rdi
call rt_spin_unlock
movq %rbx,%rax
addq $24,%rax
jnc .L952
call rt_abort
.L952:
movq %rax,-32(%rbp)
movabsq $202,%rdi
movq -32(%rbp),%rsi
movabsq $128,%rdx
movq %r14,%rcx
call rt_syscall
jmp .L941
.L942:
movabsq $0,%rax
movq -.F940-8(%rbp),%rbx
movq -.F940-16(%rbp),%r12
movq -.F940-24(%rbp),%r13
movq -.F940-32(%rbp),%r14
movq -.F940-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F940-8(%rbp),%rbx
movq -.F940-16(%rbp),%r12
movq -.F940-24(%rbp),%r13
movq -.F940-32(%rbp),%r14
movq -.F940-40(%rbp),%r15
leave
ret
.set .F940,32
.type rt_worker_loop,@function
rt_worker_loop:
pushq %rbp
movq %rsp,%rbp
subq $.F953,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movq %fs:0,%rax
movq %rax,-16(%rbp)
.L954:
movabsq $1,%rax
testq %rax,%rax
jz .L955
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_dequeue
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
addq $16,%rax
jnc .L956
call rt_abort
.L956:
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $8,%rcx
movq -16(%rbp),%rax
addq $8,%rax
jnc .L957
call rt_abort
.L957:
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
movq (%rax),%rax
movq -40(%rbp),%rdi
movq %rax,%rsi
leaq .L958(%rip),%rax
pushq %rbp
pushq %rbx
pushq %r12
pushq %r13
pushq %r14
pushq %r15
pushq %rax
movq %rsp,(%rdi)
movq %rsi,%rsp
popq %rax
popq %r15
popq %r14
popq %r13
popq %r12
popq %rbx
popq %rbp
jmp *%rax
.L958:
xorl %eax,%eax
movq -16(%rbp),%rax
addq $16,%rax
jnc .L959
call rt_abort
.L959:
movq %rax,-48(%rbp)
movq -48(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
addq $144,%rax
jnc .L960
call rt_abort
.L960:
movq (%rax),%rax
testq %rax,%rax
jz .L961
movq -24(%rbp),%rax
addq $8,%rax
jnc .L963
call rt_abort
.L963:
movq (%rax),%rax
movq %rax,-56(%rbp)
movq -24(%rbp),%rax
addq $16,%rax
jnc .L964
call rt_abort
.L964:
movq (%rax),%rax
movq %rax,-64(%rbp)
movabsq $11,%rdi
movq -56(%rbp),%rsi
movq -64(%rbp),%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i33
xorq %rax,%rax
jmp .Lret_i33
.Lret_i33:
testq %rax,%rax
jz .L965
call rt_abort
jmp .L966
.L965:
.L966:
movabsq $96,%rcx
movq -24(%rbp),%rax
addq $96,%rax
jnc .L967
call rt_abort
.L967:
movq %rax,-72(%rbp)
movq -72(%rbp),%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -24(%rbp),%rax
addq $96,%rax
jnc .L968
call rt_abort
.L968:
movq %rax,-80(%rbp)
movabsq $202,%rdi
movq -80(%rbp),%rsi
movabsq $129,%rdx
movabsq $2147483647,%rcx
call rt_syscall
movabsq $88,%rcx
movq -24(%rbp),%rax
addq $88,%rax
jnc .L969
call rt_abort
.L969:
movq %rax,-88(%rbp)
movq -88(%rbp),%rdi
movabsq $1,%rsi
call rt_atomic_swap
movq %rax,-96(%rbp)
movq -96(%rbp),%rcx
movabsq $1,%rax
cmpq %rcx,%rax
jae .L970
movq -96(%rbp),%rax
movq %rax,%rdi
call rt_wake
jmp .L971
.L970:
.L971:
jmp .L962
.L961:
movq -24(%rbp),%rax
addq $136,%rax
jnc .L972
call rt_abort
.L972:
movq (%rax),%rax
testq %rax,%rax
jz .L973
movq -24(%rbp),%rax
addq $136,%rax
jnc .L975
call rt_abort
.L975:
movq %rax,-104(%rbp)
movq -104(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_enqueue
jmp .L974
.L973:
movq -24(%rbp),%rax
addq $24,%rax
jnc .L976
call rt_abort
.L976:
movq %rax,-112(%rbp)
movq -112(%rbp),%rdi
movabsq $1,%rax
movabsq $2,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-120(%rbp)
movabsq $1,%rcx
movq -120(%rbp),%rax
cmpq $1,%rax
je .L977
movabsq $24,%rcx
movq -24(%rbp),%rax
addq $24,%rax
jnc .L979
call rt_abort
.L979:
movq %rax,-128(%rbp)
movq -128(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_enqueue
jmp .L978
.L977:
.L978:
.L974:
.L962:
jmp .L954
.L955:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F953,128
.type rt_green_main,@function
rt_green_main:
pushq %rbp
movq %rsp,%rbp
subq $.F980,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i34
movabsq $0,%rax
jmp .Lret_i34
jmp .L894_i34
.L893_i34:
.L894_i34:
movq %r8,%rax
addq $16,%rax
jnc .L895_i34
call rt_abort
.L895_i34:
movq (%rax),%rax
jmp .Lret_i34
xorq %rax,%rax
jmp .Lret_i34
.Lret_i34:
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
addq $40,%rax
jnc .L981
call rt_abort
.L981:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
addq $48,%rax
jnc .L982
call rt_abort
.L982:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
addq $56,%rax
jnc .L983
call rt_abort
.L983:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $64,%rax
jnc .L984
call rt_abort
.L984:
movq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $3,%rcx
movq -56(%rbp),%rax
cmpq $3,%rax
jne .L985
movabsq $72,%rcx
movq -8(%rbp),%rax
addq $72,%rax
jnc .L987
call rt_abort
.L987:
movq (%rax),%rax
movq -32(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
movq -24(%rbp),%rax
call *%rax
movq %rax,-48(%rbp)
jmp .L986
.L985:
movq -40(%rbp),%rax
movq -32(%rbp),%rdi
movq %rax,%rsi
movq -24(%rbp),%rax
call *%rax
movq %rax,-48(%rbp)
.L986:
movq -8(%rbp),%rax
addq $80,%rax
jnc .L988
call rt_abort
.L988:
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -8(%rbp),%rax
addq $144,%rax
jnc .L989
call rt_abort
.L989:
movq %rax,-72(%rbp)
movq -72(%rbp),%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %fs:0,%rax
movq %rax,-80(%rbp)
movabsq $8,%rcx
movq -80(%rbp),%rax
addq $8,%rax
jnc .L990
call rt_abort
.L990:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L991(%rip),%rax
pushq %rbp
pushq %rbx
pushq %r12
pushq %r13
pushq %r14
pushq %r15
pushq %rax
movq %rsp,(%rdi)
movq %rsi,%rsp
popq %rax
popq %r15
popq %r14
popq %r13
popq %r12
popq %rbx
popq %rbp
jmp *%rax
.L991:
xorl %eax,%eax
call rt_abort
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F980,80
.type rt_suspend,@function
rt_suspend:
pushq %rbp
movq %rsp,%rbp
subq $.F992,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $24,%rax
jnc .L993
call rt_abort
.L993:
movq %rax,-16(%rbp)
movq -16(%rbp),%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
cmpq $0,%rax
je .L994
movabsq $24,%rcx
movq -8(%rbp),%rax
addq $24,%rax
jnc .L996
call rt_abort
.L996:
movq %rax,-32(%rbp)
movq -32(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
jmp .L995
.L994:
.L995:
movq %fs:0,%rax
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq -40(%rbp),%rax
addq $8,%rax
jnc .L997
call rt_abort
.L997:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L998(%rip),%rax
pushq %rbp
pushq %rbx
pushq %r12
pushq %r13
pushq %r14
pushq %r15
pushq %rax
movq %rsp,(%rdi)
movq %rsi,%rsp
popq %rax
popq %r15
popq %r14
popq %r13
popq %r12
popq %rbx
popq %rbp
jmp *%rax
.L998:
xorl %eax,%eax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F992,48
.type rt_wake,@function
rt_wake:
pushq %rbp
movq %rsp,%rbp
subq $.F999,%rsp
subq $48,%rsp
movq %rbx,-.F999-8(%rbp)
movq %r12,-.F999-16(%rbp)
movq %r13,-.F999-24(%rbp)
movq %r14,-.F999-32(%rbp)
movq %r15,-.F999-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
.L1000:
movabsq $1,%rax
testq %rax,%rax
jz .L1001
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1002
call rt_abort
.L1002:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movq %rax,%r13
cmpq $2,%rax
jne .L1003
movq %rbx,%rax
addq $24,%rax
jnc .L1005
call rt_abort
.L1005:
movq %rax,%r14
movq %rax,%rdi
movabsq $2,%rax
movabsq $0,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r15
movabsq $2,%rcx
cmpq $2,%rax
jne .L1006
movq %rbx,%rdi
call rt_enqueue
movabsq $0,%rax
movq -.F999-8(%rbp),%rbx
movq -.F999-16(%rbp),%r12
movq -.F999-24(%rbp),%r13
movq -.F999-32(%rbp),%r14
movq -.F999-40(%rbp),%r15
leave
ret
jmp .L1007
.L1006:
.L1007:
jmp .L1004
.L1003:
cmpq $3,%r12
jne .L1008
movabsq $0,%rax
movq -.F999-8(%rbp),%rbx
movq -.F999-16(%rbp),%r12
movq -.F999-24(%rbp),%r13
movq -.F999-32(%rbp),%r14
movq -.F999-40(%rbp),%r15
leave
ret
jmp .L1009
.L1008:
.L1009:
movq %rbx,%rax
addq $24,%rax
jnc .L1010
call rt_abort
.L1010:
movq %rax,-16(%rbp)
movq %rax,%rdi
movq %r12,%rax
movabsq $3,%rcx
lock cmpxchgq %rcx,(%rdi)
cmpq %r12,%rax
jne .L1011
movabsq $0,%rax
movq -.F999-8(%rbp),%rbx
movq -.F999-16(%rbp),%r12
movq -.F999-24(%rbp),%r13
movq -.F999-32(%rbp),%r14
movq -.F999-40(%rbp),%r15
leave
ret
jmp .L1012
.L1011:
.L1012:
.L1004:
jmp .L1000
.L1001:
movabsq $0,%rax
movq -.F999-8(%rbp),%rbx
movq -.F999-16(%rbp),%r12
movq -.F999-24(%rbp),%r13
movq -.F999-32(%rbp),%r14
movq -.F999-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F999-8(%rbp),%rbx
movq -.F999-16(%rbp),%r12
movq -.F999-24(%rbp),%r13
movq -.F999-32(%rbp),%r14
movq -.F999-40(%rbp),%r15
leave
ret
.set .F999,16
.type rt_yield,@function
rt_yield:
pushq %rbp
movq %rsp,%rbp
subq $.F1013,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i35
movabsq $0,%rax
jmp .Lret_i35
jmp .L894_i35
.L893_i35:
.L894_i35:
movq %r8,%rax
addq $16,%rax
jnc .L895_i35
call rt_abort
.L895_i35:
movq (%rax),%rax
jmp .Lret_i35
xorq %rax,%rax
jmp .Lret_i35
.Lret_i35:
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1014
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
leave
ret
jmp .L1015
.L1014:
.L1015:
movq -8(%rbp),%rax
addq $136,%rax
jnc .L1016
call rt_abort
.L1016:
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %fs:0,%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -32(%rbp),%rax
addq $8,%rax
jnc .L1017
call rt_abort
.L1017:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1018(%rip),%rax
pushq %rbp
pushq %rbx
pushq %r12
pushq %r13
pushq %r14
pushq %r15
pushq %rax
movq %rsp,(%rdi)
movq %rsi,%rsp
popq %rax
popq %r15
popq %r14
popq %r13
popq %r12
popq %rbx
popq %rbp
jmp *%rax
.L1018:
xorl %eax,%eax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1013,32
.type rt_mutex_lock,@function
rt_mutex_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F1019,%rsp
subq $32,%rsp
movq %rbx,-.F1019-8(%rbp)
movq %r12,-.F1019-16(%rbp)
movq %r13,-.F1019-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i36
movabsq $0,%rax
jmp .Lret_i36
jmp .L894_i36
.L893_i36:
.L894_i36:
movq %r8,%rax
addq $16,%rax
jnc .L895_i36
call rt_abort
.L895_i36:
movq (%rax),%rax
jmp .Lret_i36
xorq %rax,%rax
jmp .Lret_i36
.Lret_i36:
movq %rax,-16(%rbp)
cmpq $0,%rax
je .L1020
.L1022:
movq %rbx,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
je .L1023
call rt_yield
jmp .L1022
.L1023:
movabsq $0,%rax
movq -.F1019-8(%rbp),%rbx
movq -.F1019-16(%rbp),%r12
movq -.F1019-24(%rbp),%r13
leave
ret
jmp .L1021
.L1020:
.L1021:
movq %rbx,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r12
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1024
movabsq $0,%rax
movq -.F1019-8(%rbp),%rbx
movq -.F1019-16(%rbp),%r12
movq -.F1019-24(%rbp),%r13
leave
ret
jmp .L1025
.L1024:
.L1025:
movabsq $2,%rcx
cmpq $2,%r12
je .L1026
movq %rbx,%rdi
movabsq $2,%rsi
call rt_atomic_swap
movq %rax,%r12
jmp .L1027
.L1026:
.L1027:
.L1028:
cmpq $0,%r12
je .L1029
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $128,%rdx
movabsq $2,%rcx
call rt_syscall
movq %rbx,%rdi
movabsq $2,%rsi
call rt_atomic_swap
movq %rax,%r12
jmp .L1028
.L1029:
movabsq $0,%rax
movq -.F1019-8(%rbp),%rbx
movq -.F1019-16(%rbp),%r12
movq -.F1019-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1019-8(%rbp),%rbx
movq -.F1019-16(%rbp),%r12
movq -.F1019-24(%rbp),%r13
leave
ret
.set .F1019,32
.type rt_scope_begin,@function
rt_scope_begin:
pushq %rbp
movq %rsp,%rbp
subq $.F1030,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $32,%rdi
call rt_alloc
movq %rax,-16(%rbp)
movq %rax,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
addq $16,%rax
jnc .L1031
call rt_abort
.L1031:
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1030,32
.type rt_scope_token,@function
rt_scope_token:
pushq %rbp
movq %rsp,%rbp
subq $.F1032,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L1033
call rt_abort
.L1033:
leave
ret
xorq %rax,%rax
leave
ret
.set .F1032,16
.type rt_cancelled,@function
rt_cancelled:
pushq %rbp
movq %rsp,%rbp
subq $.F1034,%rsp
subq $16,%rsp
movq %rbx,-.F1034-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rbx,%rcx
cmpq %rbx,%rax
jne .L1035
movabsq $8,%rcx
movq %rbx,%rax
addq $8,%rax
jnc .L1037
call rt_abort
.L1037:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq -.F1034-8(%rbp),%rbx
leave
ret
jmp .L1036
.L1035:
.L1036:
movq %rbx,%rdi
movq (%rdi),%rax
mfence
movq -.F1034-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1034-8(%rbp),%rbx
leave
ret
.set .F1034,16
.type rt_cancel,@function
rt_cancel:
pushq %rbp
movq %rsp,%rbp
subq $.F1038,%rsp
subq $16,%rsp
movq %rbx,-.F1038-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L1039
call rt_abort
.L1039:
movq %rax,-16(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1040
call rt_abort
.L1040:
movq (%rax),%rax
movq %rax,%rbx
.L1041:
cmpq $0,%rbx
je .L1042
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1043
call rt_abort
.L1043:
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1044
movq %rbx,%rdi
call rt_wake
jmp .L1045
.L1044:
.L1045:
movq %rbx,%rax
addq $120,%rax
jnc .L1046
call rt_abort
.L1046:
movq (%rax),%rax
movq %rax,%rbx
jmp .L1041
.L1042:
movabsq $0,%rax
movq -.F1038-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1038-8(%rbp),%rbx
leave
ret
.set .F1038,16
.type rt_task_spawn,@function
rt_task_spawn:
pushq %rbp
movq %rsp,%rbp
subq $.F1047,%rsp
subq $32,%rsp
movq %rbx,-.F1047-8(%rbp)
movq %r12,-.F1047-16(%rbp)
movq %r13,-.F1047-24(%rbp)
movq %r14,-.F1047-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq %r8,-40(%rbp)
leaq -.F1047(%rbp),%rdi
movq $.F1047/8-5,%rcx
xorl %eax,%eax
rep stosq
movabsq $152,%rdi
call rt_alloc
movq %rax,%rbx
movq %rax,-48(%rbp)
addq $40,%rax
jnc .L1048
call rt_abort
.L1048:
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $48,%rax
jnc .L1049
call rt_abort
.L1049:
movq %rax,-64(%rbp)
movq -24(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $56,%rax
jnc .L1050
call rt_abort
.L1050:
movq %rax,-72(%rbp)
movq %r12,%rax
addq $16,%rax
jnc .L1051
call rt_abort
.L1051:
movq (%rax),%rax
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $64,%rax
jnc .L1052
call rt_abort
.L1052:
movq %rax,-80(%rbp)
movq -32(%rbp),%rax
movq -80(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $72,%rax
jnc .L1053
call rt_abort
.L1053:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $8,%rax
jnc .L1054
call rt_abort
.L1054:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $112,%rax
jnc .L1055
call rt_abort
.L1055:
movq %rax,-96(%rbp)
movq -40(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $120,%rax
jnc .L1056
call rt_abort
.L1056:
movq %rax,-104(%rbp)
movq %r12,%rax
addq $24,%rax
jnc .L1057
call rt_abort
.L1057:
movq (%rax),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $24,%rax
jnc .L1058
call rt_abort
.L1058:
movq %rax,-112(%rbp)
movq %rbx,%rax
movq -112(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movq $262144,-120(%rbp)
movabsq $262144,%rax
movabsq $262144,%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,%r13
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i37
xorq %rax,%rax
jmp .Lret_i37
.Lret_i37:
testq %rax,%rax
jz .L1059
call rt_abort
jmp .L1060
.L1059:
.L1060:
movabsq $10,%rdi
movq %r13,%rsi
movabsq $4096,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i38
xorq %rax,%rax
jmp .Lret_i38
.Lret_i38:
testq %rax,%rax
jz .L1061
call rt_abort
jmp .L1062
.L1061:
.L1062:
movq %rbx,%rax
addq $8,%rax
jnc .L1063
call rt_abort
.L1063:
movq %rax,-128(%rbp)
movq %r13,%rax
movq -128(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1064
call rt_abort
.L1064:
movq %rax,-136(%rbp)
movq -120(%rbp),%rax
movq -136(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $0,-144(%rbp)
movq $8,%r14
movq $0,-152(%rbp)
movabsq $0,%rax
cmpq $1,%rax
jne .L1065
movq $22,%r14
jmp .L1066
.L1065:
.L1066:
movq -144(%rbp),%rax
cmpq $2,%rax
jne .L1067
movq $26,%r14
movq $25,-152(%rbp)
jmp .L1068
.L1067:
.L1068:
movq %r13,%rax
movq -120(%rbp),%rcx
addq %rcx,%rax
jnc .L1069
call rt_abort
.L1069:
movq %rax,-160(%rbp)
movabsq $8,%rcx
movq %r14,%rax
mulq %rcx
jnc .L1070
call rt_abort
.L1070:
movq %rax,%rcx
movq -160(%rbp),%rax
subq %rcx,%rax
jnc .L1071
call rt_abort
.L1071:
movq %rax,-168(%rbp)
movq %rax,-176(%rbp)
movabsq $8,%rcx
movq -152(%rbp),%rax
mulq %rcx
jnc .L1072
call rt_abort
.L1072:
movq %rax,%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L1073
call rt_abort
.L1073:
movq %rax,-184(%rbp)
leaq rt_green_main(%rip),%rax
movq -184(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -168(%rbp),%rax
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rdi
call rt_enqueue
movq %rbx,%rax
movq -.F1047-8(%rbp),%rbx
movq -.F1047-16(%rbp),%r12
movq -.F1047-24(%rbp),%r13
movq -.F1047-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1047-8(%rbp),%rbx
movq -.F1047-16(%rbp),%r12
movq -.F1047-24(%rbp),%r13
movq -.F1047-32(%rbp),%r14
leave
ret
.set .F1047,192
.type rt_task_wait,@function
rt_task_wait:
pushq %rbp
movq %rsp,%rbp
subq $.F1074,%rsp
subq $48,%rsp
movq %rbx,-.F1074-8(%rbp)
movq %r12,-.F1074-16(%rbp)
movq %r13,-.F1074-24(%rbp)
movq %r14,-.F1074-32(%rbp)
movq %r15,-.F1074-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1075
call rt_abort
.L1075:
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1076
movabsq $0,%rax
movq -.F1074-8(%rbp),%rbx
movq -.F1074-16(%rbp),%r12
movq -.F1074-24(%rbp),%r13
movq -.F1074-32(%rbp),%r14
movq -.F1074-40(%rbp),%r15
leave
ret
jmp .L1077
.L1076:
.L1077:
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i39
movabsq $0,%rax
jmp .Lret_i39
jmp .L894_i39
.L893_i39:
.L894_i39:
movq %r8,%rax
addq $16,%rax
jnc .L895_i39
call rt_abort
.L895_i39:
movq (%rax),%rax
jmp .Lret_i39
xorq %rax,%rax
jmp .Lret_i39
.Lret_i39:
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
cmpq $0,%rax
je .L1078
movq %rbx,%rax
addq $88,%rax
jnc .L1080
call rt_abort
.L1080:
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rax
movq -16(%rbp),%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L1081
.L1083:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1085
call rt_abort
.L1085:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $0,%rcx
cmpq $0,%rax
jne .L1084
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_suspend
jmp .L1083
.L1084:
jmp .L1082
.L1081:
.L1082:
.L1086:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1088
call rt_abort
.L1088:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
jne .L1087
call rt_yield
jmp .L1086
.L1087:
movabsq $0,%rax
movq -.F1074-8(%rbp),%rbx
movq -.F1074-16(%rbp),%r12
movq -.F1074-24(%rbp),%r13
movq -.F1074-32(%rbp),%r14
movq -.F1074-40(%rbp),%r15
leave
ret
jmp .L1079
.L1078:
.L1079:
.L1089:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1091
call rt_abort
.L1091:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r14
cmpq $0,%rax
jne .L1090
movq %rbx,%rax
addq $96,%rax
jnc .L1092
call rt_abort
.L1092:
movq %rax,%r15
movabsq $202,%rdi
movq %rax,%rsi
movabsq $128,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L1089
.L1090:
movabsq $0,%rax
movq -.F1074-8(%rbp),%rbx
movq -.F1074-16(%rbp),%r12
movq -.F1074-24(%rbp),%r13
movq -.F1074-32(%rbp),%r14
movq -.F1074-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1074-8(%rbp),%rbx
movq -.F1074-16(%rbp),%r12
movq -.F1074-24(%rbp),%r13
movq -.F1074-32(%rbp),%r14
movq -.F1074-40(%rbp),%r15
leave
ret
.set .F1074,48
.type rt_task_join,@function
rt_task_join:
pushq %rbp
movq %rsp,%rbp
subq $.F1093,%rsp
subq $16,%rsp
movq %rbx,-.F1093-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
addq $104,%rax
jnc .L1094
call rt_abort
.L1094:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1095
call rt_abort
jmp .L1096
.L1095:
.L1096:
movq %rbx,%rdi
call rt_task_wait
movq %rbx,%rax
addq $104,%rax
jnc .L1097
call rt_abort
.L1097:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %rbx,%rax
addq $80,%rax
jnc .L1098
call rt_abort
.L1098:
movq (%rax),%rax
movq -.F1093-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1093-8(%rbp),%rbx
leave
ret
.set .F1093,32
.type rt_task_abandon,@function
rt_task_abandon:
pushq %rbp
movq %rsp,%rbp
subq $.F1099,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $104,%rax
jnc .L1100
call rt_abort
.L1100:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1101
movq -8(%rbp),%rax
addq $104,%rax
jnc .L1103
call rt_abort
.L1103:
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
movabsq $2,%rax
movq $2,(%rcx)
xorq $2,%rax
jmp .L1102
.L1101:
.L1102:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1099,32
.type rt_reactor_fence,@function
rt_reactor_fence:
pushq %rbp
movq %rsp,%rbp
subq $.F1104,%rsp
subq $16,%rsp
movq %rbx,-.F1104-8(%rbp)
movq %r12,-.F1104-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $72,%rcx
addq $72,%rax
jnc .L1105
call rt_abort
.L1105:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%rbx
movq %rax,-16(%rbp)
cmpq $0,%rax
jne .L1106
movabsq $0,%rax
movq -.F1104-8(%rbp),%rbx
movq -.F1104-16(%rbp),%r12
leave
ret
jmp .L1107
.L1106:
.L1107:
movabsq $56,%rcx
movq %rbx,%rax
addq $56,%rax
jnc .L1108
call rt_abort
.L1108:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $8,%rdi
call rt_alloc
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %rbx,%rax
addq $48,%rax
jnc .L1109
call rt_abort
.L1109:
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $1,%rdi
movq %rax,%rsi
movq -24(%rbp),%rdx
movabsq $8,%rcx
call rt_syscall
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_free
.L1110:
movabsq $56,%rcx
movq %rbx,%rax
addq $56,%rax
jnc .L1112
call rt_abort
.L1112:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %r12,%rcx
cmpq %r12,%rax
jne .L1111
call rt_yield
jmp .L1110
.L1111:
movabsq $0,%rax
movq -.F1104-8(%rbp),%rbx
movq -.F1104-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1104-8(%rbp),%rbx
movq -.F1104-16(%rbp),%r12
leave
ret
.set .F1104,48
.type rt_scope_end,@function
rt_scope_end:
pushq %rbp
movq %rsp,%rbp
subq $.F1113,%rsp
subq $48,%rsp
movq %rbx,-.F1113-8(%rbp)
movq %r12,-.F1113-16(%rbp)
movq %r13,-.F1113-24(%rbp)
movq %r14,-.F1113-32(%rbp)
movq %r15,-.F1113-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1114
call rt_abort
.L1114:
movq (%rax),%rax
movq %rax,%rbx
movq %rax,%r12
.L1115:
movabsq $0,%rcx
cmpq $0,%r12
je .L1116
movq %r12,%rdi
call rt_task_wait
movq %r12,%rax
addq $120,%rax
jnc .L1117
call rt_abort
.L1117:
movq (%rax),%rax
movq %rax,%r12
jmp .L1115
.L1116:
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1118
call rt_abort
.L1118:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1119
call rt_reactor_fence
jmp .L1120
.L1119:
.L1120:
.L1121:
movabsq $0,%rcx
cmpq $0,%rbx
je .L1122
movq %rbx,%rdi
call rt_task_wait
movq %rbx,%rax
addq $104,%rax
jnc .L1123
call rt_abort
.L1123:
movq (%rax),%rax
movq %rax,%r14
movabsq $0,%rcx
cmpq $0,%rax
jne .L1124
call rt_abort
jmp .L1125
.L1124:
.L1125:
movq %rbx,%rax
addq $112,%rax
jnc .L1126
call rt_abort
.L1126:
movq (%rax),%rax
movq %rax,%r13
movq %r14,%rax
cmpq $2,%r14
sete %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %r13,%rax
cmpq $0,%r13
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1127
movabsq $80,%rcx
movq %rbx,%rax
addq $80,%rax
jnc .L1129
call rt_abort
.L1129:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
movq %r13,%rax
call *%rax
jmp .L1128
.L1127:
.L1128:
movabsq $120,%rcx
movq %rbx,%rax
addq $120,%rax
jnc .L1130
call rt_abort
.L1130:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rdi
call rt_free
movq -40(%rbp),%rax
movq %rax,%rbx
jmp .L1121
.L1122:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F1113-8(%rbp),%rbx
movq -.F1113-16(%rbp),%r12
movq -.F1113-24(%rbp),%r13
movq -.F1113-32(%rbp),%r14
movq -.F1113-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1113-8(%rbp),%rbx
movq -.F1113-16(%rbp),%r12
movq -.F1113-24(%rbp),%r13
movq -.F1113-32(%rbp),%r14
movq -.F1113-40(%rbp),%r15
leave
ret
.set .F1113,48
.type rt_reactor,@function
rt_reactor:
pushq %rbp
movq %rsp,%rbp
subq $.F1131,%rsp
subq $48,%rsp
movq %rbx,-.F1131-8(%rbp)
movq %r12,-.F1131-16(%rbp)
movq %r13,-.F1131-24(%rbp)
movq %r14,-.F1131-32(%rbp)
movq %r15,-.F1131-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movabsq $4096,%rax
movabsq $4096,%rsi
movl $9,%eax
xorl %edi,%edi
movl $3,%edx
movl $34,%r10d
movq $-1,%r8
xorl %r9d,%r9d
syscall
movq %rax,%r13
movq %rax,-16(%rbp)
addq $2048,%rax
jnc .L1132
call rt_abort
.L1132:
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
addq $40,%rax
jnc .L1133
call rt_abort
.L1133:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq $16,%r14
movabsq $0,%rax
cmpq $0,%rax
jne .L1134
movq $12,%r14
jmp .L1135
.L1134:
.L1135:
.L1136:
movabsq $1,%rax
testq %rax,%rax
jz .L1137
movabsq $0,%rax
subq $1,%rax
movabsq $281,%rdi
movq -32(%rbp),%rsi
movq %r13,%rdx
movabsq $64,%rcx
movq %rax,%r8
call rt_syscall4
movq %rax,-40(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i40
xorq %rax,%rax
jmp .Lret_i40
.Lret_i40:
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L1138
movq $0,%rbx
.L1140:
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
jae .L1141
movq %rbx,%rax
movq %r14,%rcx
mulq %rcx
jnc .L1142
call rt_abort
.L1142:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1143
call rt_abort
.L1143:
addq $8,%rax
jnc .L1144
call rt_abort
.L1144:
movq %rax,%r12
cmpq $12,%r14
jne .L1145
movabsq $12,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1147
call rt_abort
.L1147:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1148
call rt_abort
.L1148:
movq %rax,-56(%rbp)
addq $4,%rax
jnc .L1149
call rt_abort
.L1149:
movq %rax,%r12
jmp .L1146
.L1145:
.L1146:
movq %r12,%rax
movq (%rax),%rax
movq %rax,-64(%rbp)
movq %rax,-72(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1150
movq -8(%rbp),%rax
addq $48,%rax
jnc .L1152
call rt_abort
.L1152:
movq (%rax),%rax
movq %rax,-80(%rbp)
movabsq $0,%rdi
movq %rax,%rsi
movq -24(%rbp),%rdx
movabsq $8,%rcx
call rt_syscall
jmp .L1151
.L1150:
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_wake
.L1151:
movq %rbx,%rax
addq $1,%rax
jnc .L1153
call rt_abort
.L1153:
movq %rax,%rbx
jmp .L1140
.L1141:
jmp .L1139
.L1138:
.L1139:
movabsq $56,%rcx
movq -8(%rbp),%rax
addq $56,%rax
jnc .L1154
call rt_abort
.L1154:
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
jmp .L1136
.L1137:
movabsq $0,%rax
movq -.F1131-8(%rbp),%rbx
movq -.F1131-16(%rbp),%r12
movq -.F1131-24(%rbp),%r13
movq -.F1131-32(%rbp),%r14
movq -.F1131-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1131-8(%rbp),%rbx
movq -.F1131-16(%rbp),%r12
movq -.F1131-24(%rbp),%r13
movq -.F1131-32(%rbp),%r14
movq -.F1131-40(%rbp),%r15
leave
ret
.set .F1131,96
.type rt_wait_fd,@function
rt_wait_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1155,%rsp
subq $32,%rsp
movq %rbx,-.F1155-8(%rbp)
movq %r12,-.F1155-16(%rbp)
movq %r13,-.F1155-24(%rbp)
movq %r14,-.F1155-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i41
movabsq $0,%rax
jmp .Lret_i41
jmp .L894_i41
.L893_i41:
.L894_i41:
movq %r8,%rax
addq $16,%rax
jnc .L895_i41
call rt_abort
.L895_i41:
movq (%rax),%rax
jmp .Lret_i41
xorq %rax,%rax
jmp .Lret_i41
.Lret_i41:
movq %rax,%rbx
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1156
movabsq $8,%rdi
call rt_alloc
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
movabsq $4294967295,%rcx
movq %r13,%rax
andq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $4294967296,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L1158
call rt_abort
.L1158:
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L1159
call rt_abort
.L1159:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $271,%rdi
movq -32(%rbp),%rsi
movabsq $1,%rdx
movabsq $0,%rcx
call rt_syscall
movq -32(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F1155-8(%rbp),%rbx
movq -.F1155-16(%rbp),%r12
movq -.F1155-24(%rbp),%r13
movq -.F1155-32(%rbp),%r14
leave
ret
jmp .L1157
.L1156:
.L1157:
movq %rbx,%rax
addq $72,%rax
jnc .L1160
call rt_abort
.L1160:
movq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1161
call rt_abort
.L1161:
movq %rax,-64(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -56(%rbp),%rax
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1162
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1164
call rt_abort
.L1164:
movq %rax,-72(%rbp)
movq %rax,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
subq $125,%rax
movq -.F1155-8(%rbp),%rbx
movq -.F1155-16(%rbp),%r12
movq -.F1155-24(%rbp),%r13
movq -.F1155-32(%rbp),%r14
leave
ret
jmp .L1163
.L1162:
.L1163:
call rt_sched
movq %rax,-80(%rbp)
movabsq $40,%rcx
addq $40,%rax
jnc .L1165
call rt_abort
.L1165:
movq (%rax),%rax
movq %rax,%r14
movabsq $16,%rdi
call rt_alloc
movq %rax,%r12
movq %rax,-88(%rbp)
movq -16(%rbp),%rax
addq $1073741824,%rax
jnc .L1166
call rt_abort
.L1166:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
cmpq $0,%rax
jne .L1167
movq %r12,%rax
addq $4,%rax
jnc .L1169
call rt_abort
.L1169:
movq %rax,-96(%rbp)
movq %rbx,%rax
movq -96(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
jmp .L1168
.L1167:
movq %r12,%rax
addq $8,%rax
jnc .L1170
call rt_abort
.L1170:
movq %rax,-104(%rbp)
movq %rbx,%rax
movq -104(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
.L1168:
movabsq $233,%rdi
movq %r14,%rsi
movabsq $1,%rdx
movq %r13,%rcx
movq %r12,%r8
call rt_syscall4
movq %rax,-112(%rbp)
movq %rax,-120(%rbp)
movabsq $0,%rax
subq $17,%rax
movq %rax,%rcx
movq -120(%rbp),%rax
cmpq %rcx,%rax
jne .L1171
movabsq $233,%rdi
movq %r14,%rsi
movabsq $3,%rdx
movq %r13,%rcx
movq %r12,%r8
call rt_syscall4
movq %rax,-112(%rbp)
jmp .L1172
.L1171:
.L1172:
movq %r12,%rdi
call rt_free
movq -112(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i42
xorq %rax,%rax
jmp .Lret_i42
.Lret_i42:
testq %rax,%rax
jz .L1173
call rt_abort
jmp .L1174
.L1173:
.L1174:
movq %rbx,%rdi
call rt_suspend
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1175
call rt_abort
.L1175:
movq %rax,-128(%rbp)
movq %rax,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $233,%rdi
movq %r14,%rsi
movabsq $2,%rdx
movq %r13,%rcx
movabsq $0,%r8
call rt_syscall4
movq -56(%rbp),%rax
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1176
movabsq $0,%rax
subq $125,%rax
movq -.F1155-8(%rbp),%rbx
movq -.F1155-16(%rbp),%r12
movq -.F1155-24(%rbp),%r13
movq -.F1155-32(%rbp),%r14
leave
ret
jmp .L1177
.L1176:
.L1177:
movabsq $0,%rax
movq -.F1155-8(%rbp),%rbx
movq -.F1155-16(%rbp),%r12
movq -.F1155-24(%rbp),%r13
movq -.F1155-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1155-8(%rbp),%rbx
movq -.F1155-16(%rbp),%r12
movq -.F1155-24(%rbp),%r13
movq -.F1155-32(%rbp),%r14
leave
ret
.set .F1155,128
.type f_host_sleep_ms,@function
f_host_sleep_ms:
pushq %rbp
movq %rsp,%rbp
subq $.F1178,%rsp
subq $48,%rsp
movq %rbx,-.F1178-8(%rbp)
movq %r12,-.F1178-16(%rbp)
movq %r13,-.F1178-24(%rbp)
movq %r14,-.F1178-32(%rbp)
movq %r15,-.F1178-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $32,%rdi
call rt_alloc
movq %rax,%r14
movq %rax,-16(%rbp)
movabsq $16,%rcx
addq $16,%rax
jnc .L1179
call rt_abort
.L1179:
movq %rax,-24(%rbp)
movq -8(%rbp),%rdi
movabsq $1000,%rsi
call rt_div
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r14,%rax
addq $24,%rax
jnc .L1180
call rt_abort
.L1180:
movq %rax,-32(%rbp)
movabsq $1000,%rcx
movq -8(%rbp),%rax
testq %rcx,%rcx
jnz .L1181
call rt_abort
.L1181:
xorq %rdx,%rdx
divq %rcx
movabsq $1000000,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1182
call rt_abort
.L1182:
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i43
movabsq $0,%rax
jmp .Lret_i43
jmp .L894_i43
.L893_i43:
.L894_i43:
movq %r8,%rax
addq $16,%rax
jnc .L895_i43
call rt_abort
.L895_i43:
movq (%rax),%rax
jmp .Lret_i43
xorq %rax,%rax
jmp .Lret_i43
.Lret_i43:
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L1183
movq %r14,%rax
addq $16,%rax
jnc .L1185
call rt_abort
.L1185:
movq %rax,-48(%rbp)
movabsq $35,%rdi
movq %rax,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r14,%rdi
call rt_free
movabsq $0,%rax
movq -.F1178-8(%rbp),%rbx
movq -.F1178-16(%rbp),%r12
movq -.F1178-24(%rbp),%r13
movq -.F1178-32(%rbp),%r14
movq -.F1178-40(%rbp),%r15
leave
ret
jmp .L1184
.L1183:
.L1184:
movabsq $283,%rdi
movabsq $1,%rsi
movabsq $526336,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rbx
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i44
xorq %rax,%rax
jmp .Lret_i44
.Lret_i44:
testq %rax,%rax
jz .L1186
call rt_abort
jmp .L1187
.L1186:
.L1187:
movabsq $286,%rdi
movq %rbx,%rsi
movabsq $0,%rdx
movq %r14,%rcx
movabsq $0,%r8
call rt_syscall4
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i45
xorq %rax,%rax
jmp .Lret_i45
.Lret_i45:
testq %rax,%rax
jz .L1188
call rt_abort
jmp .L1189
.L1188:
.L1189:
movabsq $8,%rdi
call rt_alloc
movq %rax,%r15
.L1190:
movabsq $0,%rdi
movq %rbx,%rsi
movq %r15,%rdx
movabsq $8,%rcx
call rt_syscall
movabsq $8,%rcx
cmpq $8,%rax
je .L1191
movq %rbx,%rdi
movabsq $1,%rsi
call rt_wait_fd
cmpq $0,%rax
je .L1192
jmp .L1191
jmp .L1193
.L1192:
.L1193:
jmp .L1190
.L1191:
movabsq $3,%rdi
movq %rbx,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r15,%rdi
call rt_free
movq %r14,%rdi
call rt_free
movabsq $0,%rax
movq -.F1178-8(%rbp),%rbx
movq -.F1178-16(%rbp),%r12
movq -.F1178-24(%rbp),%r13
movq -.F1178-32(%rbp),%r14
movq -.F1178-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1178-8(%rbp),%rbx
movq -.F1178-16(%rbp),%r12
movq -.F1178-24(%rbp),%r13
movq -.F1178-32(%rbp),%r14
movq -.F1178-40(%rbp),%r15
leave
ret
.set .F1178,48
.type f_host_now_ms,@function
f_host_now_ms:
pushq %rbp
movq %rsp,%rbp
subq $.F1194,%rsp
subq $16,%rsp
movq %rbx,-.F1194-8(%rbp)
movq $0,%rbx
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $16,%rdi
call rt_alloc
movq %rax,%rbx
movabsq $228,%rdi
movabsq $1,%rsi
movq %rax,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-8(%rbp)
movabsq $1000,%rcx
mulq %rcx
jnc .L1195
call rt_abort
.L1195:
movq %rax,-16(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
addq $8,%rax
jnc .L1196
call rt_abort
.L1196:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $1000000,%rsi
call rt_div
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1197
call rt_abort
.L1197:
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F1194-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1194-8(%rbp),%rbx
leave
ret
.set .F1194,32
.type f_host_pipe,@function
f_host_pipe:
pushq %rbp
movq %rsp,%rbp
subq $.F1198,%rsp
subq $16,%rsp
movq %rbx,-.F1198-8(%rbp)
movq $0,%rbx
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $8,%rdi
call rt_alloc
movq %rax,%rbx
movabsq $293,%rdi
movq %rax,%rsi
movabsq $526336,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i46
xorq %rax,%rax
jmp .Lret_i46
.Lret_i46:
testq %rax,%rax
jz .L1199
call rt_abort
jmp .L1200
.L1199:
.L1200:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-8(%rbp)
movq %rbx,%rdi
call rt_free
call rt_new
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $4294967295,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt29
call rt_push
jmp .Lopt30
.Lopt29:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt30:
movq -8(%rbp),%rdi
movabsq $4294967296,%rsi
call rt_div
movq -16(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt31
call rt_push
jmp .Lopt32
.Lopt31:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt32:
movq -16(%rbp),%rax
movq -.F1198-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1198-8(%rbp),%rbx
leave
ret
.set .F1198,32
.type f_host_read_fd,@function
f_host_read_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1201,%rsp
subq $48,%rsp
movq %rbx,-.F1201-8(%rbp)
movq %r12,-.F1201-16(%rbp)
movq %r13,-.F1201-24(%rbp)
movq %r14,-.F1201-32(%rbp)
movq %r15,-.F1201-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
call rt_new
movq %rax,%r14
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1202
movq %r14,%rax
movq -.F1201-8(%rbp),%rbx
movq -.F1201-16(%rbp),%r12
movq -.F1201-24(%rbp),%r13
movq -.F1201-32(%rbp),%r14
movq -.F1201-40(%rbp),%r15
leave
ret
jmp .L1203
.L1202:
.L1203:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq %rax,%r13
.L1204:
movabsq $1,%rax
testq %rax,%rax
jz .L1205
movq -16(%rbp),%rax
movabsq $0,%rdi
movq %r15,%rsi
movq %r13,%rdx
movq %rax,%rcx
call rt_syscall
movq %rax,%r12
movq %rax,-24(%rbp)
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
cmpq %rcx,%rax
jne .L1206
movq %r15,%rdi
movabsq $1,%rsi
call rt_wait_fd
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1208
jmp .L1205
jmp .L1209
.L1208:
.L1209:
jmp .L1207
.L1206:
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i47
xorq %rax,%rax
jmp .Lret_i47
.Lret_i47:
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1210
movq $0,%rbx
.L1212:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L1213
movq %r13,%rax
addq %rbx,%rax
jnc .L1214
call rt_abort
.L1214:
movzbq (%rax),%rax
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt33
call rt_pushb
jmp .Lopt34
.Lopt33:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt34:
movq %rbx,%rax
addq $1,%rax
jnc .L1215
call rt_abort
.L1215:
movq %rax,%rbx
jmp .L1212
.L1213:
jmp .L1211
.L1210:
.L1211:
jmp .L1205
.L1207:
jmp .L1204
.L1205:
movq %r13,%rdi
call rt_free
movq %r14,%rax
movq -.F1201-8(%rbp),%rbx
movq -.F1201-16(%rbp),%r12
movq -.F1201-24(%rbp),%r13
movq -.F1201-32(%rbp),%r14
movq -.F1201-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1201-8(%rbp),%rbx
movq -.F1201-16(%rbp),%r12
movq -.F1201-24(%rbp),%r13
movq -.F1201-32(%rbp),%r14
movq -.F1201-40(%rbp),%r15
leave
ret
.set .F1201,48
.type f_host_write_fd,@function
f_host_write_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1216,%rsp
subq $48,%rsp
movq %rbx,-.F1216-8(%rbp)
movq %r12,-.F1216-16(%rbp)
movq %r13,-.F1216-24(%rbp)
movq %r14,-.F1216-32(%rbp)
movq %r15,-.F1216-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_pack
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,%r14
movq $0,%rbx
.L1217:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L1218
movq -24(%rbp),%rax
addq %rbx,%rax
jnc .L1219
call rt_abort
.L1219:
movq %rax,%r15
movq %r14,%rax
subq %rbx,%rax
jnc .L1220
call rt_abort
.L1220:
movabsq $1,%rdi
movq %r13,%rsi
movq %r15,%rdx
movq %rax,%rcx
call rt_syscall
movq %rax,%r12
movq %rax,-32(%rbp)
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
cmpq %rcx,%rax
jne .L1221
movq %r13,%rdi
movabsq $4,%rsi
call rt_wait_fd
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1223
jmp .L1218
jmp .L1224
.L1223:
.L1224:
jmp .L1222
.L1221:
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i48
xorq %rax,%rax
jmp .Lret_i48
.Lret_i48:
testq %rax,%rax
jz .L1225
jmp .L1218
jmp .L1226
.L1225:
.L1226:
movq %rbx,%rax
addq %r12,%rax
jnc .L1227
call rt_abort
.L1227:
movq %rax,%rbx
.L1222:
jmp .L1217
.L1218:
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rax
movq -.F1216-8(%rbp),%rbx
movq -.F1216-16(%rbp),%r12
movq -.F1216-24(%rbp),%r13
movq -.F1216-32(%rbp),%r14
movq -.F1216-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1216-8(%rbp),%rbx
movq -.F1216-16(%rbp),%r12
movq -.F1216-24(%rbp),%r13
movq -.F1216-32(%rbp),%r14
movq -.F1216-40(%rbp),%r15
leave
ret
.set .F1216,48
.type f_host_close,@function
f_host_close:
pushq %rbp
movq %rsp,%rbp
subq $.F1228,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $3,%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-16(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i49
xorq %rax,%rax
jmp .Lret_i49
.Lret_i49:
testq %rax,%rax
jz .L1229
movq -16(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
leave
ret
jmp .L1230
.L1229:
.L1230:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1228,16
.type rt_offload_main,@function
rt_offload_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1231,%rsp
subq $16,%rsp
movq %rbx,-.F1231-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L1232
call rt_abort
.L1232:
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $16,%rcx
movq %rbx,%rax
addq $16,%rax
jnc .L1233
call rt_abort
.L1233:
movq (%rax),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq -16(%rbp),%rax
call *%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
addq $24,%rax
jnc .L1234
call rt_abort
.L1234:
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1235
call rt_abort
.L1235:
movq %rax,-48(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $40,%rcx
movq %rbx,%rax
addq $40,%rax
jnc .L1236
call rt_abort
.L1236:
movq (%rax),%rax
movq %rax,%rdi
call rt_wake
movabsq $0,%rax
movq -.F1231-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1231-8(%rbp),%rbx
leave
ret
.set .F1231,48
.type rt_offload,@function
rt_offload:
pushq %rbp
movq %rsp,%rbp
subq $.F1237,%rsp
subq $32,%rsp
movq %rbx,-.F1237-8(%rbp)
movq %r12,-.F1237-16(%rbp)
movq %r13,-.F1237-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L893_i50
movabsq $0,%rax
jmp .Lret_i50
jmp .L894_i50
.L893_i50:
.L894_i50:
movq %r8,%rax
addq $16,%rax
jnc .L895_i50
call rt_abort
.L895_i50:
movq (%rax),%rax
jmp .Lret_i50
xorq %rax,%rax
jmp .Lret_i50
.Lret_i50:
movq %rax,%r13
movabsq $48,%rdi
call rt_alloc
movq %rax,%rbx
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L1238
call rt_abort
.L1238:
movq %rax,-40(%rbp)
movq -16(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1239
call rt_abort
.L1239:
movq %rax,-48(%rbp)
movq -24(%rbp),%rax
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $40,%rax
jnc .L1240
call rt_abort
.L1240:
movq %rax,-56(%rbp)
movq %r13,%rax
movq -56(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
leaq rt_offload_main(%rip),%rax
movq %rax,-64(%rbp)
movq -64(%rbp),%rdi
movq %rbx,%rsi
call rt_thread_spawn
movq %rax,-72(%rbp)
.L1241:
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1243
call rt_abort
.L1243:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $0,%rcx
cmpq $0,%rax
jne .L1242
movq %r13,%rdi
call rt_suspend
jmp .L1241
.L1242:
movq -72(%rbp),%rax
movq %rax,%rdi
call rt_thread_join
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1244
call rt_abort
.L1244:
movq (%rax),%rax
movq %rax,-80(%rbp)
movq %rbx,%rdi
call rt_free
movq -80(%rbp),%rax
movq -.F1237-8(%rbp),%rbx
movq -.F1237-16(%rbp),%r12
movq -.F1237-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1237-8(%rbp),%rbx
movq -.F1237-16(%rbp),%r12
movq -.F1237-24(%rbp),%r13
leave
ret
.set .F1237,80
.type rt_bytes_from,@function
rt_bytes_from:
pushq %rbp
movq %rsp,%rbp
subq $.F1245,%rsp
subq $32,%rsp
movq %rbx,-.F1245-8(%rbp)
movq %r12,-.F1245-16(%rbp)
movq %r13,-.F1245-24(%rbp)
movq %r14,-.F1245-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,%r14
call rt_new
movq %rax,%r12
movq $0,%rbx
.L1246:
cmpq %r14,%rbx
jae .L1247
movq %r13,%rax
addq %rbx,%rax
jnc .L1248
call rt_abort
.L1248:
movzbq (%rax),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt35
call rt_pushb
jmp .Lopt36
.Lopt35:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt36:
movq %rbx,%rax
addq $1,%rax
jnc .L1249
call rt_abort
.L1249:
movq %rax,%rbx
jmp .L1246
.L1247:
movq %r12,%rax
movq -.F1245-8(%rbp),%rbx
movq -.F1245-16(%rbp),%r12
movq -.F1245-24(%rbp),%r13
movq -.F1245-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1245-8(%rbp),%rbx
movq -.F1245-16(%rbp),%r12
movq -.F1245-24(%rbp),%r13
movq -.F1245-32(%rbp),%r14
leave
ret
.set .F1245,16
.type f_host_env,@function
f_host_env:
pushq %rbp
movq %rsp,%rbp
subq $.F1250,%rsp
subq $48,%rsp
movq %rbx,-.F1250-8(%rbp)
movq %r12,-.F1250-16(%rbp)
movq %r13,-.F1250-24(%rbp)
movq %r14,-.F1250-32(%rbp)
movq %r15,-.F1250-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,%r14
leaq rt_state(%rip),%rax
movq %rax,-16(%rbp)
addq $16,%rax
jnc .L1251
call rt_abort
.L1251:
movq (%rax),%rax
movq %rax,-24(%rbp)
.L1252:
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1253
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,%r13
movq $0,%rbx
movq $1,-40(%rbp)
.L1254:
cmpq %r14,%rbx
jae .L1255
movq %r13,%rax
addq %rbx,%rax
jnc .L1256
call rt_abort
.L1256:
movzbq (%rax),%rax
movq %rax,%r15
movq -8(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt37
call rt_abort
.Lopt37:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r15
je .L1257
movq $0,-40(%rbp)
jmp .L1255
jmp .L1258
.L1257:
.L1258:
movq %rbx,%rax
addq $1,%rax
jnc .L1259
call rt_abort
.L1259:
movq %rax,%rbx
jmp .L1254
.L1255:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L1260
movq %r13,%rax
addq %r14,%rax
jnc .L1262
call rt_abort
.L1262:
movzbq (%rax),%rax
movq %rax,-48(%rbp)
cmpq $61,%rax
jne .L1263
movq $0,%r12
.L1265:
movq %r13,%rax
addq %r14,%rax
jnc .L1267
call rt_abort
.L1267:
movq %rax,-56(%rbp)
addq $1,%rax
jnc .L1268
call rt_abort
.L1268:
addq %r12,%rax
jnc .L1269
call rt_abort
.L1269:
movzbq (%rax),%rax
movq %rax,-64(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1266
movq %r12,%rax
addq $1,%rax
jnc .L1270
call rt_abort
.L1270:
movq %rax,%r12
jmp .L1265
.L1266:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r13,%rax
addq %r14,%rax
jnc .L1271
call rt_abort
.L1271:
movq %rax,-72(%rbp)
movabsq $1,%rcx
addq $1,%rax
jnc .L1272
call rt_abort
.L1272:
movq %rax,-80(%rbp)
movq -80(%rbp),%rdi
movq %r12,%rsi
call rt_bytes_from
movq -.F1250-8(%rbp),%rbx
movq -.F1250-16(%rbp),%r12
movq -.F1250-24(%rbp),%r13
movq -.F1250-32(%rbp),%r14
movq -.F1250-40(%rbp),%r15
leave
ret
jmp .L1264
.L1263:
.L1264:
jmp .L1261
.L1260:
.L1261:
movq -24(%rbp),%rax
addq $8,%rax
jnc .L1273
call rt_abort
.L1273:
movq %rax,-24(%rbp)
jmp .L1252
.L1253:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
call rt_new
movq -.F1250-8(%rbp),%rbx
movq -.F1250-16(%rbp),%r12
movq -.F1250-24(%rbp),%r13
movq -.F1250-32(%rbp),%r14
movq -.F1250-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1250-8(%rbp),%rbx
movq -.F1250-16(%rbp),%r12
movq -.F1250-24(%rbp),%r13
movq -.F1250-32(%rbp),%r14
movq -.F1250-40(%rbp),%r15
leave
ret
.set .F1250,80
.type f_host_exe_path,@function
f_host_exe_path:
pushq %rbp
movq %rsp,%rbp
subq $.F1274,%rsp
subq $32,%rsp
movq %rbx,-.F1274-8(%rbp)
movq %r12,-.F1274-16(%rbp)
movq %r13,-.F1274-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $16,%rdi
call rt_alloc
movq %rax,%rbx
movq %rax,-8(%rbp)
movq %rax,%rcx
movabsq $7310238724270485551,%rax
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L1275
call rt_abort
.L1275:
movq %rax,-16(%rbp)
movq %rax,%rcx
movabsq $111567768086124,%rax
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $4096,%rdi
call rt_alloc
movq %rax,%r12
movq %rbx,%rdi
movq %rax,%rsi
movabsq $4095,%rdx
call rt_readlinkat
movq %rax,-24(%rbp)
movq %rbx,%rdi
call rt_free
call rt_new
movq %rax,%r13
movq -24(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i51
xorq %rax,%rax
jmp .Lret_i51
.Lret_i51:
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1276
movq %r13,%rdi
call rt_free
movq -24(%rbp),%rax
movq %r12,%rdi
movq %rax,%rsi
call rt_bytes_from
movq %rax,%r13
jmp .L1277
.L1276:
.L1277:
movq %r12,%rdi
call rt_free
movq %r13,%rax
movq -.F1274-8(%rbp),%rbx
movq -.F1274-16(%rbp),%r12
movq -.F1274-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1274-8(%rbp),%rbx
movq -.F1274-16(%rbp),%r12
movq -.F1274-24(%rbp),%r13
leave
ret
.set .F1274,32
.type f_host_exists,@function
f_host_exists:
pushq %rbp
movq %rsp,%rbp
subq $.F1278,%rsp
subq $16,%rsp
movq %rbx,-.F1278-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,%rbx
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rcx
cmpq $0,%rbx
jne .L1279
movabsq $0,%rax
movq -.F1278-8(%rbp),%rbx
leave
ret
jmp .L1280
.L1279:
.L1280:
movq %rbx,%rdi
call rt_faccessat
movq %rax,-16(%rbp)
movq %rbx,%rdi
call rt_free
movq -16(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i52
xorq %rax,%rax
jmp .Lret_i52
.Lret_i52:
movq %rax,-24(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1278-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1278-8(%rbp),%rbx
leave
ret
.set .F1278,32
.type f_host_mkdir,@function
f_host_mkdir:
pushq %rbp
movq %rsp,%rbp
subq $.F1281,%rsp
subq $16,%rsp
movq %rbx,-.F1281-8(%rbp)
movq %r12,-.F1281-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,%rbx
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
cmpq $0,%rbx
jne .L1282
movabsq $22,%rax
movq -.F1281-8(%rbp),%rbx
movq -.F1281-16(%rbp),%r12
leave
ret
jmp .L1283
.L1282:
.L1283:
movabsq $0,%rax
subq $100,%rax
movq %rax,-16(%rbp)
movabsq $258,%rdi
movq %rax,%rsi
movq %rbx,%rdx
movabsq $493,%rcx
call rt_syscall
movq %rax,%r12
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
subq $17,%rax
movq %rax,%rcx
cmpq %rcx,%r12
jne .L1284
movabsq $0,%rax
movq -.F1281-8(%rbp),%rbx
movq -.F1281-16(%rbp),%r12
leave
ret
jmp .L1285
.L1284:
.L1285:
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i53
xorq %rax,%rax
jmp .Lret_i53
.Lret_i53:
testq %rax,%rax
jz .L1286
movabsq $0,%rax
subq %r12,%rax
movq -.F1281-8(%rbp),%rbx
movq -.F1281-16(%rbp),%r12
leave
ret
jmp .L1287
.L1286:
.L1287:
movabsq $0,%rax
movq -.F1281-8(%rbp),%rbx
movq -.F1281-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1281-8(%rbp),%rbx
movq -.F1281-16(%rbp),%r12
leave
ret
.set .F1281,16
.type f_host_list_dir,@function
f_host_list_dir:
pushq %rbp
movq %rsp,%rbp
subq $.F1288,%rsp
subq $48,%rsp
movq %rbx,-.F1288-8(%rbp)
movq %r12,-.F1288-16(%rbp)
movq %r13,-.F1288-24(%rbp)
movq %r14,-.F1288-32(%rbp)
movq %r15,-.F1288-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F1288(%rbp),%rdi
movq $.F1288/8-1,%rcx
xorl %eax,%eax
rep stosq
call rt_new
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L1289
movq -16(%rbp),%rax
movq -.F1288-8(%rbp),%rbx
movq -.F1288-16(%rbp),%r12
movq -.F1288-24(%rbp),%r13
movq -.F1288-32(%rbp),%r14
movq -.F1288-40(%rbp),%r15
leave
ret
jmp .L1290
.L1289:
.L1290:
movabsq $2,%rdi
movq -24(%rbp),%rsi
movabsq $524288,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -32(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i54
xorq %rax,%rax
jmp .Lret_i54
.Lret_i54:
testq %rax,%rax
jz .L1291
movq -16(%rbp),%rax
movq -.F1288-8(%rbp),%rbx
movq -.F1288-16(%rbp),%r12
movq -.F1288-24(%rbp),%r13
movq -.F1288-32(%rbp),%r14
movq -.F1288-40(%rbp),%r15
leave
ret
jmp .L1292
.L1291:
.L1292:
movabsq $8192,%rdi
call rt_alloc
movq %rax,-40(%rbp)
.L1293:
movabsq $1,%rax
testq %rax,%rax
jz .L1294
movabsq $217,%rdi
movq -32(%rbp),%rsi
movq -40(%rbp),%rdx
movabsq $8192,%rcx
call rt_syscall
movq %rax,-48(%rbp)
movq %rax,-56(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i55
xorq %rax,%rax
jmp .Lret_i55
.Lret_i55:
movq %rax,%rcx
movq -64(%rbp),%rax
addq %rcx,%rax
jnc .L1295
call rt_abort
.L1295:
testq %rax,%rax
jz .L1296
jmp .L1294
jmp .L1297
.L1296:
.L1297:
movq $0,%r14
.L1298:
movq -48(%rbp),%rcx
cmpq %rcx,%r14
jae .L1299
movq -40(%rbp),%rax
addq %r14,%rax
jnc .L1300
call rt_abort
.L1300:
movq %rax,%r12
movq %rax,-72(%rbp)
addq $16,%rax
jnc .L1301
call rt_abort
.L1301:
movzbq (%rax),%rax
movq %rax,-80(%rbp)
movq %r12,%rax
addq $17,%rax
jnc .L1302
call rt_abort
.L1302:
movzbq (%rax),%rax
movq %rax,-88(%rbp)
movabsq $256,%rcx
mulq %rcx
jnc .L1303
call rt_abort
.L1303:
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L1304
call rt_abort
.L1304:
movq %rax,-96(%rbp)
movq %r12,%rax
addq $18,%rax
jnc .L1305
call rt_abort
.L1305:
movzbq (%rax),%rax
movq %rax,-104(%rbp)
movq $0,%rbx
.L1306:
movq %r12,%rax
addq $19,%rax
jnc .L1308
call rt_abort
.L1308:
addq %rbx,%rax
jnc .L1309
call rt_abort
.L1309:
movzbq (%rax),%rax
cmpq $0,%rax
je .L1307
movq %rbx,%rax
addq $1,%rax
jnc .L1310
call rt_abort
.L1310:
movq %rax,%rbx
jmp .L1306
.L1307:
movq %r12,%rax
addq $19,%rax
jnc .L1311
call rt_abort
.L1311:
movzbq (%rax),%rax
movq %rax,-112(%rbp)
cmpq $46,%rax
sete %al
movzbq %al,%rax
movq %rax,-120(%rbp)
movq %rbx,%rax
cmpq $1,%rbx
sete %al
movzbq %al,%rax
movq %rax,-128(%rbp)
movq %rbx,%rax
cmpq $2,%rbx
sete %al
movzbq %al,%rax
movq %rax,-136(%rbp)
movq %r12,%rax
addq $20,%rax
jnc .L1312
call rt_abort
.L1312:
movzbq (%rax),%rax
movq %rax,-144(%rbp)
cmpq $46,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -136(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -128(%rbp),%rax
addq %rcx,%rax
jnc .L1313
call rt_abort
.L1313:
movq %rax,%rcx
movq -120(%rbp),%rax
andq %rcx,%rax
movq %rax,-152(%rbp)
cmpq $0,%rax
jne .L1314
movabsq $19,%rcx
movq %r12,%rax
addq $19,%rax
jnc .L1316
call rt_abort
.L1316:
movq %rax,-160(%rbp)
movq -160(%rbp),%rdi
movq %rbx,%rsi
call rt_bytes_from
movq %rax,%r15
movq -104(%rbp),%rax
cmpq $4,%rax
jne .L1317
movq %r15,%rdi
movabsq $47,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt38
call rt_pushb
jmp .Lopt39
.Lopt38:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt39:
jmp .L1318
.L1317:
.L1318:
movq -16(%rbp),%rdi
movq %r15,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt40
call rt_push
jmp .Lopt41
.Lopt40:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt41:
jmp .L1315
.L1314:
.L1315:
movq %r14,%rax
movq -96(%rbp),%rcx
addq %rcx,%rax
jnc .L1319
call rt_abort
.L1319:
movq %rax,%r14
jmp .L1298
.L1299:
jmp .L1293
.L1294:
movabsq $3,%rdi
movq -32(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq -.F1288-8(%rbp),%rbx
movq -.F1288-16(%rbp),%r12
movq -.F1288-24(%rbp),%r13
movq -.F1288-32(%rbp),%r14
movq -.F1288-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1288-8(%rbp),%rbx
movq -.F1288-16(%rbp),%r12
movq -.F1288-24(%rbp),%r13
movq -.F1288-32(%rbp),%r14
movq -.F1288-40(%rbp),%r15
leave
ret
.set .F1288,160
.type rt_int_mask,@function
rt_int_mask:
pushq %rbp
movq %rsp,%rbp
subq $.F1320,%rsp
subq $32,%rsp
movq %rbx,-.F1320-8(%rbp)
movq %r12,-.F1320-16(%rbp)
movq %r13,-.F1320-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
cmpq $64,%r13
jne .L1321
movabsq $18446744073709551615,%rax
movq -.F1320-8(%rbp),%rbx
movq -.F1320-16(%rbp),%r12
movq -.F1320-24(%rbp),%r13
leave
ret
jmp .L1322
.L1321:
.L1322:
movq $1,%r12
movq $0,%rbx
.L1323:
cmpq %r13,%rbx
jae .L1324
movq %r12,%rax
addq %r12,%rax
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L1325
call rt_abort
.L1325:
movq %rax,%rbx
jmp .L1323
.L1324:
movq %r12,%rax
subq $1,%rax
jnc .L1326
call rt_abort
.L1326:
movq -.F1320-8(%rbp),%rbx
movq -.F1320-16(%rbp),%r12
movq -.F1320-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1320-8(%rbp),%rbx
movq -.F1320-16(%rbp),%r12
movq -.F1320-24(%rbp),%r13
leave
ret
.set .F1320,16
.type rt_int_neg,@function
rt_int_neg:
pushq %rbp
movq %rsp,%rbp
subq $.F1327,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1327,16
.type rt_int_fit,@function
rt_int_fit:
pushq %rbp
movq %rsp,%rbp
subq $.F1328,%rsp
subq $16,%rsp
movq %rbx,-.F1328-8(%rbp)
movq %r12,-.F1328-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movabsq $64,%rcx
movq -16(%rbp),%rax
cmpq $64,%rax
jne .L1329
movabsq $1,%rax
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
leave
ret
jmp .L1330
.L1329:
.L1330:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_int_mask
movq %rax,%r12
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1331
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1333:
movq %rax,-32(%rbp)
addq $1,%rax
jnc .L1334
call rt_abort
.L1334:
movq %rax,-40(%rbp)
movq %rbx,%rax
movq -40(%rbp),%rcx
addq %rcx,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
movq -40(%rbp),%rcx
addq %rcx,%rax
cmpq %r12,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L1335
call rt_abort
.L1335:
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
leave
ret
jmp .L1332
.L1331:
.L1332:
movq %rbx,%rax
cmpq %r12,%rbx
setb %al
movzbq %al,%rax
movq %rax,-56(%rbp)
movq %rbx,%rax
cmpq %r12,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L1336
call rt_abort
.L1336:
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
leave
ret
.set .F1328,64
.type rt_int_truncate,@function
rt_int_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F1337,%rsp
subq $16,%rsp
movq %rbx,-.F1337-8(%rbp)
movq %r12,-.F1337-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $64,%rcx
movq -16(%rbp),%rax
cmpq $64,%rax
jne .L1338
movq -8(%rbp),%rax
movq -.F1337-8(%rbp),%rbx
movq -.F1337-16(%rbp),%r12
leave
ret
jmp .L1339
.L1338:
.L1339:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_int_mask
movq %rax,%rbx
movq -8(%rbp),%rax
andq %rbx,%rax
movq %rax,%r12
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1340
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1342:
movq %rax,-32(%rbp)
addq $1,%rax
jnc .L1343
call rt_abort
.L1343:
movq %rax,-40(%rbp)
movq %r12,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%r12
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L1344
movabsq $18446744073709551615,%rax
xorq %rbx,%rax
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L1346
call rt_abort
.L1346:
movq -.F1337-8(%rbp),%rbx
movq -.F1337-16(%rbp),%r12
leave
ret
jmp .L1345
.L1344:
.L1345:
jmp .L1341
.L1340:
.L1341:
movq %r12,%rax
movq -.F1337-8(%rbp),%rbx
movq -.F1337-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1337-8(%rbp),%rbx
movq -.F1337-16(%rbp),%r12
leave
ret
.set .F1337,48
.type rt_int_abs,@function
rt_int_abs:
pushq %rbp
movq %rsp,%rbp
subq $.F1347,%rsp
subq $16,%rsp
movq %rbx,-.F1347-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i56
xorq %rax,%rax
jmp .Lret_i56
.Lret_i56:
testq %rax,%rax
jz .L1348
movabsq $0,%rax
subq %rbx,%rax
movq -.F1347-8(%rbp),%rbx
leave
ret
jmp .L1349
.L1348:
.L1349:
movq %rbx,%rax
movq -.F1347-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1347-8(%rbp),%rbx
leave
ret
.set .F1347,16
.type rt_int,@function
rt_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1350,%rsp
subq $48,%rsp
movq %rbx,-.F1350-8(%rbp)
movq %r12,-.F1350-16(%rbp)
movq %r13,-.F1350-24(%rbp)
movq %r14,-.F1350-32(%rbp)
movq %r15,-.F1350-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r12
movq %rdx,%rbx
movq %rcx,-32(%rbp)
leaq -.F1350(%rbp),%rdi
movq $.F1350/8-4,%rcx
xorl %eax,%eax
rep stosq
movq -32(%rbp),%rax
andq $255,%rax
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1351:
movq %rax,-48(%rbp)
andq $1,%rax
movq %rax,-56(%rbp)
movq -32(%rbp),%rax
movq %rax,%rdx
andq $511,%rdx
shrq $9,%rax
.L1352:
movq %rax,-64(%rbp)
andq $1,%rax
movq %rax,-72(%rbp)
movq $0,%r14
movq $0,%r15
cmpq $43,%r13
jne .L1353
movq %r12,%rax
addq %rbx,%rax
movq %rax,%r14
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1355
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1357
movq %r12,%rax
xorq %r14,%rax
movq %rax,-80(%rbp)
movq %rbx,%rax
xorq %r14,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
andq %rcx,%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i57
xorq %rax,%rax
jmp .Lret_i57
.Lret_i57:
movq %rax,%r15
jmp .L1358
.L1357:
movq %r14,%rax
cmpq %r12,%r14
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1358:
jmp .L1356
.L1355:
.L1356:
jmp .L1354
.L1353:
.L1354:
cmpq $45,%r13
jne .L1359
movq %r12,%rax
subq %rbx,%rax
movq %rax,%r14
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1361
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1363
movq %r12,%rax
xorq %rbx,%rax
movq %rax,-88(%rbp)
movq %r12,%rax
xorq %r14,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
andq %rcx,%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i58
xorq %rax,%rax
jmp .Lret_i58
.Lret_i58:
movq %rax,%r15
jmp .L1364
.L1363:
movq %r12,%rax
cmpq %rbx,%r12
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1364:
jmp .L1362
.L1361:
.L1362:
jmp .L1360
.L1359:
.L1360:
cmpq $42,%r13
jne .L1365
movq %r12,%rax
movq %rbx,%rcx
imulq %rcx,%rax
movq %rax,%r14
movabsq $64,%rcx
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1367
movq %r12,%rdi
call rt_int_abs
movq %rax,-96(%rbp)
movq %rbx,%rdi
call rt_int_abs
movq %rax,-104(%rbp)
movq -96(%rbp),%rax
movq -104(%rbp),%rcx
imulq %rcx,%rax
movq %rax,-112(%rbp)
movabsq $0,%rcx
movq -96(%rbp),%rax
cmpq $0,%rax
je .L1369
movq -96(%rbp),%rax
movq -112(%rbp),%rdi
movq %rax,%rsi
call rt_div
movq -104(%rbp),%rcx
cmpq %rcx,%rax
je .L1371
movq $1,%r15
jmp .L1372
.L1371:
.L1372:
jmp .L1370
.L1369:
.L1370:
movq %r15,%rax
cmpq $0,%r15
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1373
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i59
xorq %rax,%rax
jmp .Lret_i59
.Lret_i59:
movq %rax,-120(%rbp)
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i60
xorq %rax,%rax
jmp .Lret_i60
.Lret_i60:
movq %rax,%rcx
movq -120(%rbp),%rax
xorq %rcx,%rax
testq %rax,%rax
jz .L1375
movq -112(%rbp),%rcx
movabsq $9223372036854775808,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r15
jmp .L1376
.L1375:
movq -112(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1376:
jmp .L1374
.L1373:
.L1374:
jmp .L1368
.L1367:
.L1368:
jmp .L1366
.L1365:
.L1366:
movq %r13,%rax
cmpq $47,%r13
sete %al
movzbq %al,%rax
movq %rax,-128(%rbp)
movq %r13,%rax
cmpq $37,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -128(%rbp),%rax
addq %rcx,%rax
jnc .L1377
call rt_abort
.L1377:
testq %rax,%rax
jz .L1378
movabsq $0,%rcx
cmpq $0,%rbx
jne .L1380
call rt_abort
jmp .L1381
.L1380:
.L1381:
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1382
movq %r12,%rdi
call rt_int_abs
movq %rax,-136(%rbp)
movq %rbx,%rdi
call rt_int_abs
movq -136(%rbp),%rdi
movq %rax,%rsi
call rt_div
movq %rax,-144(%rbp)
movq %r12,%rdi
call rt_int_abs
movq %rax,-152(%rbp)
movq %rbx,%rdi
call rt_int_abs
movq %rax,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L1384
call rt_abort
.L1384:
movq %rax,%rcx
movq -152(%rbp),%rax
subq %rcx,%rax
jnc .L1385
call rt_abort
.L1385:
movq %rax,-160(%rbp)
movabsq $47,%rcx
cmpq $47,%r13
jne .L1386
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i61
xorq %rax,%rax
jmp .Lret_i61
.Lret_i61:
movq %rax,-168(%rbp)
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i62
xorq %rax,%rax
jmp .Lret_i62
.Lret_i62:
movq %rax,%rcx
movq -168(%rbp),%rax
xorq %rcx,%rax
testq %rax,%rax
jz .L1388
movq -144(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%r14
jmp .L1389
.L1388:
movq -144(%rbp),%rax
movq %rax,%r14
.L1389:
movq -40(%rbp),%rax
cmpq $64,%rax
sete %al
movzbq %al,%rax
movq %rax,-176(%rbp)
movabsq $9223372036854775808,%rcx
movq %r14,%rax
cmpq %rcx,%r14
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -176(%rbp),%rax
andq %rcx,%rax
movq %rax,-184(%rbp)
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i63
xorq %rax,%rax
jmp .Lret_i63
.Lret_i63:
movq %rax,-192(%rbp)
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i64
xorq %rax,%rax
jmp .Lret_i64
.Lret_i64:
movq %rax,-200(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -192(%rbp),%rax
xorq %rcx,%rax
movq %rax,%rcx
movq -184(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1390
movq $1,%r15
jmp .L1391
.L1390:
.L1391:
jmp .L1387
.L1386:
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i65
xorq %rax,%rax
jmp .Lret_i65
.Lret_i65:
testq %rax,%rax
jz .L1392
movq -160(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%r14
jmp .L1393
.L1392:
movq -160(%rbp),%rax
movq %rax,%r14
.L1393:
.L1387:
jmp .L1383
.L1382:
movq %r12,%rdi
movq %rbx,%rsi
call rt_div
movq %rax,-208(%rbp)
cmpq $47,%r13
jne .L1394
movq -208(%rbp),%rax
movq %rax,%r14
jmp .L1395
.L1394:
movq -208(%rbp),%rax
movq %rbx,%rcx
mulq %rcx
jnc .L1396
call rt_abort
.L1396:
movq %rax,%rcx
movq %r12,%rax
subq %rcx,%rax
jnc .L1397
call rt_abort
.L1397:
movq %rax,%r14
.L1395:
.L1383:
jmp .L1379
.L1378:
.L1379:
cmpq $38,%r13
jne .L1398
movq %r12,%rax
andq %rbx,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1399
.L1398:
.L1399:
cmpq $94,%r13
jne .L1400
movq %r12,%rax
xorq %rbx,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1401
.L1400:
.L1401:
cmpq $124,%r13
jne .L1402
movabsq $18446744073709551615,%rax
xorq %rbx,%rax
movq %rax,%rcx
movq %r12,%rax
andq %rcx,%rax
addq %rbx,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1403
.L1402:
.L1403:
movq %r13,%rax
cmpq $271,%r13
sete %al
movzbq %al,%rax
movq %rax,-216(%rbp)
movq %r13,%rax
cmpq $272,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -216(%rbp),%rax
addq %rcx,%rax
jnc .L1404
call rt_abort
.L1404:
testq %rax,%rax
jz .L1405
movq %rbx,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,-224(%rbp)
cmpq $0,%rax
jne .L1407
movabsq $0,%rcx
movq -72(%rbp),%rax
cmpq $0,%rax
jne .L1409
call rt_abort
jmp .L1410
.L1409:
.L1410:
movabsq $0,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1408
.L1407:
.L1408:
movq $1,-232(%rbp)
movq $0,-240(%rbp)
.L1411:
movq -240(%rbp),%rax
cmpq %rbx,%rax
jae .L1412
movq -232(%rbp),%rax
addq %rax,%rax
movq %rax,-232(%rbp)
movq -240(%rbp),%rax
addq $1,%rax
jnc .L1413
call rt_abort
.L1413:
movq %rax,-240(%rbp)
jmp .L1411
.L1412:
movabsq $271,%rcx
cmpq $271,%r13
jne .L1414
movq %r12,%rax
movq -232(%rbp),%rcx
imulq %rcx,%rax
movq %rax,-248(%rbp)
movq -56(%rbp),%rax
movq -248(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1415
.L1414:
.L1415:
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i66
xorq %rax,%rax
jmp .Lret_i66
.Lret_i66:
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1416
movabsq $0,%rax
subq %r12,%rax
movq %rax,-256(%rbp)
movabsq $1,%rcx
subq $1,%rax
movq %rax,-264(%rbp)
movq -232(%rbp),%rax
movq -264(%rbp),%rdi
movq %rax,%rsi
call rt_div
movq %rax,%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,-272(%rbp)
subq $1,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1417
.L1416:
.L1417:
movq -232(%rbp),%rax
movq %r12,%rdi
movq %rax,%rsi
call rt_div
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1406
.L1405:
.L1406:
cmpq $258,%r13
jne .L1418
movq %r12,%rax
cmpq %rbx,%r12
sete %al
movzbq %al,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1419
.L1418:
.L1419:
cmpq $259,%r13
jne .L1420
movq %r12,%rax
cmpq %rbx,%r12
setne %al
movzbq %al,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1421
.L1420:
.L1421:
movq %r13,%rax
cmpq $60,%r13
sete %al
movzbq %al,%rax
movq %rax,-280(%rbp)
movq %r13,%rax
cmpq $62,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -280(%rbp),%rax
addq %rcx,%rax
jnc .L1422
call rt_abort
.L1422:
movq %rax,-288(%rbp)
movq %r13,%rax
cmpq $269,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -288(%rbp),%rax
addq %rcx,%rax
jnc .L1423
call rt_abort
.L1423:
movq %rax,-296(%rbp)
movq %r13,%rax
cmpq $270,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -296(%rbp),%rax
addq %rcx,%rax
jnc .L1424
call rt_abort
.L1424:
testq %rax,%rax
jz .L1425
movq %r12,-304(%rbp)
movq %rbx,-312(%rbp)
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1427
movabsq $9223372036854775808,%rcx
movq %r12,%rax
xorq %rcx,%rax
movq %rax,-304(%rbp)
movabsq $9223372036854775808,%rcx
movq %rbx,%rax
xorq %rcx,%rax
movq %rax,-312(%rbp)
jmp .L1428
.L1427:
.L1428:
cmpq $60,%r13
jne .L1429
movq -304(%rbp),%rax
movq -312(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1430
.L1429:
.L1430:
cmpq $62,%r13
jne .L1431
movq -312(%rbp),%rax
movq -304(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1432
.L1431:
.L1432:
cmpq $269,%r13
jne .L1433
movq -312(%rbp),%rax
movq -304(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-320(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1434
.L1433:
.L1434:
movq -304(%rbp),%rax
movq -312(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-328(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1426
.L1425:
.L1426:
movabsq $267,%rcx
cmpq $267,%r13
jne .L1435
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i67
xorq %rax,%rax
jmp .Lret_i67
.Lret_i67:
testq %rax,%rax
jz .L1437
call rt_abort
jmp .L1438
.L1437:
.L1438:
movq $1,-336(%rbp)
movq $0,-344(%rbp)
.L1439:
movq -344(%rbp),%rax
cmpq %rbx,%rax
jae .L1440
movq -32(%rbp),%rax
movabsq $42,%rdi
movq -336(%rbp),%rsi
movq %r12,%rdx
movq %rax,%rcx
call rt_int
movq %rax,-336(%rbp)
movq -344(%rbp),%rax
addq $1,%rax
jnc .L1441
call rt_abort
.L1441:
movq %rax,-344(%rbp)
jmp .L1439
.L1440:
movq -336(%rbp),%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1436
.L1435:
.L1436:
movq %r15,%rax
cmpq $0,%r15
sete %al
movzbq %al,%rax
movq %rax,-352(%rbp)
movq -40(%rbp),%rax
cmpq $64,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -352(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1442
movq -56(%rbp),%rax
movq %r14,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_fit
movq %rax,-360(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%r15
jmp .L1443
.L1442:
.L1443:
testq %r15,%r15
jz .L1444
movabsq $0,%rcx
movq -72(%rbp),%rax
cmpq $0,%rax
jne .L1446
call rt_abort
jmp .L1447
.L1446:
.L1447:
movq -56(%rbp),%rax
movq %r14,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
jmp .L1445
.L1444:
.L1445:
movq %r14,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1350-8(%rbp),%rbx
movq -.F1350-16(%rbp),%r12
movq -.F1350-24(%rbp),%r13
movq -.F1350-32(%rbp),%r14
movq -.F1350-40(%rbp),%r15
leave
ret
.set .F1350,368
.type rt_int_cast,@function
rt_int_cast:
pushq %rbp
movq %rsp,%rbp
subq $.F1448,%rsp
subq $32,%rsp
movq %rbx,-.F1448-8(%rbp)
movq %r12,-.F1448-16(%rbp)
movq %r13,-.F1448-24(%rbp)
movq %r14,-.F1448-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq %rdx,%r14
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1449:
movq %rax,-32(%rbp)
andq $1,%rax
movq %rax,-40(%rbp)
movq %r14,%rax
andq $255,%rax
movq %rax,%r12
movq %r14,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1450:
movq %rax,-48(%rbp)
movabsq $1,%rcx
andq $1,%rax
movq %rax,-56(%rbp)
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i68
xorq %rax,%rax
jmp .Lret_i68
.Lret_i68:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
movq %rax,-64(%rbp)
movq $1,%r13
movabsq $0,%rcx
movq -56(%rbp),%rax
cmpq $0,%rax
jne .L1451
movq -64(%rbp),%rax
testq %rax,%rax
jz .L1453
movq $0,%r13
jmp .L1454
.L1453:
movabsq $64,%rcx
cmpq $64,%r12
jae .L1455
movq %r12,%rdi
call rt_int_mask
movq %rax,%rcx
movq %rbx,%rax
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,-72(%rbp)
movq %r12,%rdi
call rt_int_mask
movq %rax,%rcx
movq %rbx,%rax
cmpq %rcx,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L1457
call rt_abort
.L1457:
movq %rax,%r13
jmp .L1456
.L1455:
.L1456:
.L1454:
jmp .L1452
.L1451:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L1458
movabsq $64,%rcx
cmpq $64,%r12
jae .L1460
movq %rbx,%rdi
movq %r12,%rsi
movabsq $1,%rdx
call rt_int_fit
movq %rax,%r13
jmp .L1461
.L1460:
.L1461:
jmp .L1459
.L1458:
movq %r12,%rdi
call rt_int_mask
movq %rax,-80(%rbp)
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1462:
movq %rax,-88(%rbp)
movq %rbx,%rax
movq -88(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,-96(%rbp)
movq %rbx,%rax
cmpq %rcx,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
addq %rcx,%rax
jnc .L1463
call rt_abort
.L1463:
movq %rax,%r13
.L1459:
.L1452:
cmpq $0,%r13
jne .L1464
movq %r14,%rax
movq %rax,%rdx
andq $511,%rdx
shrq $9,%rax
.L1466:
movq %rax,-104(%rbp)
movabsq $1,%rcx
andq $1,%rax
testq %rax,%rax
jz .L1467
movq -56(%rbp),%rax
movq %rbx,%rdi
movq %r12,%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1448-8(%rbp),%rbx
movq -.F1448-16(%rbp),%r12
movq -.F1448-24(%rbp),%r13
movq -.F1448-32(%rbp),%r14
leave
ret
jmp .L1468
.L1467:
.L1468:
call rt_abort
jmp .L1465
.L1464:
.L1465:
movq %rbx,%rax
movq -.F1448-8(%rbp),%rbx
movq -.F1448-16(%rbp),%r12
movq -.F1448-24(%rbp),%r13
movq -.F1448-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1448-8(%rbp),%rbx
movq -.F1448-16(%rbp),%r12
movq -.F1448-24(%rbp),%r13
movq -.F1448-32(%rbp),%r14
leave
ret
.set .F1448,112
.type rt_print_int,@function
rt_print_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1469,%rsp
subq $16,%rsp
movq %rbx,-.F1469-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1470:
movq %rax,-32(%rbp)
movabsq $1,%rcx
andq $1,%rax
movq %rax,-40(%rbp)
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i69
xorq %rax,%rax
jmp .Lret_i69
.Lret_i69:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1471
movabsq $1,%rdi
call rt_alloc
movq %rax,-48(%rbp)
movq %rax,-56(%rbp)
movq %rax,%rcx
movabsq $45,%rax
movb %al,(%rcx)
xorq %rax,%rax
movabsq $1,%rdi
movq -48(%rbp),%rsi
movabsq $1,%rdx
call rt_write_all
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rcx
movq -64(%rbp),%rax
cmpq $0,%rax
je .L1473
call rt_abort
jmp .L1474
.L1473:
.L1474:
movq %rbx,%rcx
movabsq $0,%rax
subq %rbx,%rax
movq %rax,-72(%rbp)
movq -16(%rbp),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_print_number
movq -.F1469-8(%rbp),%rbx
leave
ret
jmp .L1472
.L1471:
.L1472:
movq -16(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_print_number
movq -.F1469-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1469-8(%rbp),%rbx
leave
ret
.set .F1469,80
.type rt_print_bool,@function
rt_print_bool:
pushq %rbp
movq %rsp,%rbp
subq $.F1475,%rsp
subq $16,%rsp
movq %rbx,-.F1475-8(%rbp)
movq %r12,-.F1475-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq -8(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movabsq $4,%rax
addq %rcx,%rax
jnc .L1476
call rt_abort
.L1476:
movq %rax,%r12
movabsq $8,%rdi
call rt_alloc
movq %rax,%rbx
movq -8(%rbp),%rax
testq %rax,%rax
jz .L1477
movq %rbx,%rcx
movabsq $116,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1479
call rt_abort
.L1479:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $114,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L1480
call rt_abort
.L1480:
movq %rax,-32(%rbp)
movq %rax,%rcx
movabsq $117,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L1481
call rt_abort
.L1481:
movq %rax,-40(%rbp)
movq %rax,%rcx
movabsq $101,%rax
movb %al,(%rcx)
xorq %rax,%rax
jmp .L1478
.L1477:
movq %rbx,%rcx
movabsq $102,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1482
call rt_abort
.L1482:
movq %rax,-48(%rbp)
movq %rax,%rcx
movabsq $97,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L1483
call rt_abort
.L1483:
movq %rax,-56(%rbp)
movq %rax,%rcx
movabsq $108,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L1484
call rt_abort
.L1484:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $115,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $4,%rax
jnc .L1485
call rt_abort
.L1485:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $101,%rax
movb %al,(%rcx)
xorq %rax,%rax
.L1478:
movq %r12,-80(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1486
movq %rbx,%rax
addq %r12,%rax
jnc .L1488
call rt_abort
.L1488:
movq %rax,-88(%rbp)
movq %rax,%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1489
call rt_abort
.L1489:
movq %rax,-80(%rbp)
jmp .L1487
.L1486:
.L1487:
movq -80(%rbp),%rax
movabsq $1,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-96(%rbp)
movq %rbx,%rdi
call rt_free
movabsq $0,%rcx
movq -96(%rbp),%rax
cmpq $0,%rax
je .L1490
call rt_abort
jmp .L1491
.L1490:
.L1491:
movabsq $0,%rax
movq -.F1475-8(%rbp),%rbx
movq -.F1475-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1475-8(%rbp),%rbx
movq -.F1475-16(%rbp),%r12
leave
ret
.set .F1475,96
.type rt_sockaddr,@function
rt_sockaddr:
pushq %rbp
movq %rsp,%rbp
subq $.F1492,%rsp
subq $16,%rsp
movq %rbx,-.F1492-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $16,%rdi
call rt_alloc
movq %rax,%rbx
movq -16(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1493:
movabsq $256,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1494
call rt_abort
.L1494:
movq %rax,-24(%rbp)
movq -16(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1495
call rt_abort
.L1495:
movq %rax,-32(%rbp)
movabsq $65536,%rcx
mulq %rcx
jnc .L1496
call rt_abort
.L1496:
movq %rax,%rcx
movabsq $2,%rax
addq %rcx,%rax
jnc .L1497
call rt_abort
.L1497:
movq %rax,-40(%rbp)
movabsq $4294967296,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L1498
call rt_abort
.L1498:
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L1499
call rt_abort
.L1499:
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L1500
call rt_abort
.L1500:
movq %rax,-48(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
movq -.F1492-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1492-8(%rbp),%rbx
leave
ret
.set .F1492,48
.type rt_tcp_socket,@function
rt_tcp_socket:
pushq %rbp
movq %rsp,%rbp
subq $.F1501,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movabsq $41,%rdi
movabsq $2,%rsi
movabsq $526337,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,-8(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i70
xorq %rax,%rax
jmp .Lret_i70
.Lret_i70:
testq %rax,%rax
jz .L1502
call rt_abort
jmp .L1503
.L1502:
.L1503:
movq -8(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1501,16
.type f_host_tcp_listen,@function
f_host_tcp_listen:
pushq %rbp
movq %rsp,%rbp
subq $.F1504,%rsp
subq $16,%rsp
movq %rbx,-.F1504-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
call rt_tcp_socket
movq %rax,%rbx
movq -8(%rbp),%rax
movabsq $0,%rdi
movq %rax,%rsi
call rt_sockaddr
movq %rax,-16(%rbp)
movabsq $49,%rdi
movq %rbx,%rsi
movq %rax,%rdx
movabsq $16,%rcx
call rt_syscall
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -24(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i71
xorq %rax,%rax
jmp .Lret_i71
.Lret_i71:
testq %rax,%rax
jz .L1505
call rt_abort
jmp .L1506
.L1505:
.L1506:
movabsq $50,%rdi
movq %rbx,%rsi
movabsq $128,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i72
xorq %rax,%rax
jmp .Lret_i72
.Lret_i72:
testq %rax,%rax
jz .L1507
call rt_abort
jmp .L1508
.L1507:
.L1508:
movq %rbx,%rax
movq -.F1504-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1504-8(%rbp),%rbx
leave
ret
.set .F1504,32
.type f_host_tcp_port,@function
f_host_tcp_port:
pushq %rbp
movq %rsp,%rbp
subq $.F1509,%rsp
subq $16,%rsp
movq %rbx,-.F1509-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movabsq $24,%rdi
call rt_alloc
movq %rax,%rbx
movq %rax,-16(%rbp)
addq $16,%rax
jnc .L1510
call rt_abort
.L1510:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $16,%rax
movq $16,(%rcx)
xorq $16,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1511
call rt_abort
.L1511:
movabsq $51,%rdi
movq -8(%rbp),%rsi
movq %rbx,%rdx
movq %rax,%rcx
call rt_syscall
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i73
xorq %rax,%rax
jmp .Lret_i73
.Lret_i73:
testq %rax,%rax
jz .L1512
call rt_abort
jmp .L1513
.L1512:
.L1513:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $65536,%rsi
call rt_div
movq %rax,-40(%rbp)
movabsq $65536,%rcx
movq %rax,%rdx
andq $65535,%rdx
shrq $16,%rax
.L1514:
movq %rdx,-48(%rbp)
movq %rbx,%rdi
call rt_free
movq -48(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1515:
movabsq $256,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1516
call rt_abort
.L1516:
movq %rax,-56(%rbp)
movq -48(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L1517
call rt_abort
.L1517:
movq -.F1509-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1509-8(%rbp),%rbx
leave
ret
.set .F1509,64
.type f_host_tcp_accept,@function
f_host_tcp_accept:
pushq %rbp
movq %rsp,%rbp
subq $.F1518,%rsp
subq $32,%rsp
movq %rbx,-.F1518-8(%rbp)
movq %r12,-.F1518-16(%rbp)
movq %r13,-.F1518-24(%rbp)
movq %r14,-.F1518-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq $0,-16(%rbp)
.L1519:
movabsq $1,%rax
testq %rax,%rax
jz .L1520
movq %r12,%rdi
call rt_accept4
movq %rax,%rbx
movq %rax,%r13
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
cmpq %rcx,%r13
jne .L1521
movq %r12,%rdi
movabsq $1,%rsi
call rt_wait_fd
movabsq $0,%rcx
cmpq $0,%rax
je .L1523
movabsq $0,%rax
subq $125,%rax
movq -.F1518-8(%rbp),%rbx
movq -.F1518-16(%rbp),%r12
movq -.F1518-24(%rbp),%r13
movq -.F1518-32(%rbp),%r14
leave
ret
jmp .L1524
.L1523:
.L1524:
jmp .L1522
.L1521:
movq %rbx,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i74
xorq %rax,%rax
jmp .Lret_i74
.Lret_i74:
testq %rax,%rax
jz .L1525
call rt_abort
jmp .L1526
.L1525:
.L1526:
movq %rbx,%rax
movq -.F1518-8(%rbp),%rbx
movq -.F1518-16(%rbp),%r12
movq -.F1518-24(%rbp),%r13
movq -.F1518-32(%rbp),%r14
leave
ret
.L1522:
jmp .L1519
.L1520:
movabsq $0,%rax
movq -.F1518-8(%rbp),%rbx
movq -.F1518-16(%rbp),%r12
movq -.F1518-24(%rbp),%r13
movq -.F1518-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1518-8(%rbp),%rbx
movq -.F1518-16(%rbp),%r12
movq -.F1518-24(%rbp),%r13
movq -.F1518-32(%rbp),%r14
leave
ret
.set .F1518,16
.type rt_ipv4,@function
rt_ipv4:
pushq %rbp
movq %rsp,%rbp
subq $.F1527,%rsp
subq $48,%rsp
movq %rbx,-.F1527-8(%rbp)
movq %r12,-.F1527-16(%rbp)
movq %r13,-.F1527-24(%rbp)
movq %r14,-.F1527-32(%rbp)
movq %r15,-.F1527-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-16(%rbp)
movq $0,%rbx
movq $1,%r13
movq $0,%r14
movq $0,%r12
.L1528:
movq -16(%rbp),%rcx
cmpq %rcx,%r12
jae .L1529
movq -8(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt42
call rt_abort
.Lopt42:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r15
movq %rax,-24(%rbp)
cmpq $46,%rax
jne .L1530
movq %rbx,%rax
movq %r13,%rcx
mulq %rcx
jnc .L1532
call rt_abort
.L1532:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1533
call rt_abort
.L1533:
movq %rax,%r14
movabsq $256,%rcx
movq %r13,%rax
mulq %rcx
jnc .L1534
call rt_abort
.L1534:
movq %rax,%r13
movq $0,%rbx
jmp .L1531
.L1530:
movabsq $10,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1535
call rt_abort
.L1535:
addq %r15,%rax
jnc .L1536
call rt_abort
.L1536:
movq %rax,-32(%rbp)
subq $48,%rax
jnc .L1537
call rt_abort
.L1537:
movq %rax,%rbx
.L1531:
movq %r12,%rax
addq $1,%rax
jnc .L1538
call rt_abort
.L1538:
movq %rax,%r12
jmp .L1528
.L1529:
movq %rbx,%rax
movq %r13,%rcx
mulq %rcx
jnc .L1539
call rt_abort
.L1539:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1540
call rt_abort
.L1540:
movq %rax,%r14
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r14,%rax
movq -.F1527-8(%rbp),%rbx
movq -.F1527-16(%rbp),%r12
movq -.F1527-24(%rbp),%r13
movq -.F1527-32(%rbp),%r14
movq -.F1527-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1527-8(%rbp),%rbx
movq -.F1527-16(%rbp),%r12
movq -.F1527-24(%rbp),%r13
movq -.F1527-32(%rbp),%r14
movq -.F1527-40(%rbp),%r15
leave
ret
.set .F1527,32
.type f_host_tcp_connect,@function
f_host_tcp_connect:
pushq %rbp
movq %rsp,%rbp
subq $.F1541,%rsp
subq $48,%rsp
movq %rbx,-.F1541-8(%rbp)
movq %r12,-.F1541-16(%rbp)
movq %r13,-.F1541-24(%rbp)
movq %r14,-.F1541-32(%rbp)
movq %r15,-.F1541-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
call rt_tcp_socket
movq %rax,%r12
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_ipv4
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
call rt_sockaddr
movq %rax,%r13
.L1542:
movabsq $1,%rax
testq %rax,%rax
jz .L1543
movabsq $42,%rdi
movq %r12,%rsi
movq %r13,%rdx
movabsq $16,%rcx
call rt_syscall
movq %rax,%rbx
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%r15
movabsq $0,%rax
subq $106,%rax
movq %rax,%rcx
movq %rbx,%rax
cmpq %rcx,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1544
call rt_abort
.L1544:
testq %rax,%rax
jz .L1545
movq %r13,%rdi
call rt_free
movq %r12,%rax
movq -.F1541-8(%rbp),%rbx
movq -.F1541-16(%rbp),%r12
movq -.F1541-24(%rbp),%r13
movq -.F1541-32(%rbp),%r14
movq -.F1541-40(%rbp),%r15
leave
ret
jmp .L1546
.L1545:
.L1546:
movabsq $0,%rax
subq $115,%rax
movq %rax,%rcx
movq %rbx,%rax
cmpq %rcx,%rbx
sete %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movabsq $0,%rax
subq $114,%rax
movq %rax,%rcx
movq %rbx,%rax
cmpq %rcx,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L1547
call rt_abort
.L1547:
testq %rax,%rax
jz .L1548
movq %r12,%rdi
movabsq $4,%rsi
call rt_wait_fd
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1550
movq %r13,%rdi
call rt_free
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
subq $125,%rax
movq -.F1541-8(%rbp),%rbx
movq -.F1541-16(%rbp),%r12
movq -.F1541-24(%rbp),%r13
movq -.F1541-32(%rbp),%r14
movq -.F1541-40(%rbp),%r15
leave
ret
jmp .L1551
.L1550:
.L1551:
jmp .L1549
.L1548:
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
cmpq %rcx,%rbx
jne .L1552
call rt_yield
jmp .L1553
.L1552:
movq %r13,%rdi
call rt_free
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rbx,%rax
movq -.F1541-8(%rbp),%rbx
movq -.F1541-16(%rbp),%r12
movq -.F1541-24(%rbp),%r13
movq -.F1541-32(%rbp),%r14
movq -.F1541-40(%rbp),%r15
leave
ret
.L1553:
.L1549:
jmp .L1542
.L1543:
movabsq $0,%rax
movq -.F1541-8(%rbp),%rbx
movq -.F1541-16(%rbp),%r12
movq -.F1541-24(%rbp),%r13
movq -.F1541-32(%rbp),%r14
movq -.F1541-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1541-8(%rbp),%rbx
movq -.F1541-16(%rbp),%r12
movq -.F1541-24(%rbp),%r13
movq -.F1541-32(%rbp),%r14
movq -.F1541-40(%rbp),%r15
leave
ret
.set .F1541,48
.type f_host_open,@function
f_host_open:
pushq %rbp
movq %rsp,%rbp
subq $.F1554,%rsp
subq $16,%rsp
movq %rbx,-.F1554-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,%rbx
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
cmpq $0,%rbx
jne .L1555
movabsq $0,%rax
subq $22,%rax
movq -.F1554-8(%rbp),%rbx
leave
ret
jmp .L1556
.L1555:
.L1556:
movq $524288,-24(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1557
movq $524865,-24(%rbp)
jmp .L1558
.L1557:
.L1558:
movabsq $2,%rdi
movq %rbx,%rsi
movq -24(%rbp),%rdx
movabsq $438,%rcx
call rt_syscall
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F1554-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1554-8(%rbp),%rbx
leave
ret
.set .F1554,32
.type rt_print_raw,@function
rt_print_raw:
pushq %rbp
movq %rsp,%rbp
subq $.F1559,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movabsq $1,%rdi
movq -8(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
je .L1560
call rt_abort
jmp .L1561
.L1560:
.L1561:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1559,32
.type rt_fmt_raw,@function
rt_fmt_raw:
pushq %rbp
movq %rsp,%rbp
subq $.F1562,%rsp
subq $32,%rsp
movq %rbx,-.F1562-8(%rbp)
movq %r12,-.F1562-16(%rbp)
movq %r13,-.F1562-24(%rbp)
movq %r14,-.F1562-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,%r13
movq %rdx,%r14
movq $0,-32(%rbp)
movq $0,%rbx
.L1563:
cmpq %r14,%rbx
jae .L1564
movq %r13,%rax
addq %rbx,%rax
jnc .L1565
call rt_abort
.L1565:
movzbq (%rax),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt43
call rt_pushb
jmp .Lopt44
.Lopt43:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt44:
movq %rbx,%rax
addq $1,%rax
jnc .L1566
call rt_abort
.L1566:
movq %rax,%rbx
jmp .L1563
.L1564:
movabsq $0,%rax
movq -.F1562-8(%rbp),%rbx
movq -.F1562-16(%rbp),%r12
movq -.F1562-24(%rbp),%r13
movq -.F1562-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1562-8(%rbp),%rbx
movq -.F1562-16(%rbp),%r12
movq -.F1562-24(%rbp),%r13
movq -.F1562-32(%rbp),%r14
leave
ret
.set .F1562,32
.type rt_fmt_num,@function
rt_fmt_num:
pushq %rbp
movq %rsp,%rbp
subq $.F1567,%rsp
subq $48,%rsp
movq %rbx,-.F1567-8(%rbp)
movq %r12,-.F1567-16(%rbp)
movq %r13,-.F1567-24(%rbp)
movq %r14,-.F1567-32(%rbp)
movq %r15,-.F1567-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $24,%rdi
call rt_alloc
movq %rax,%r15
movq $24,%rbx
movq -16(%rbp),%rax
movq %rax,%r12
.L1568:
movabsq $1,%rax
testq %rax,%rax
jz .L1569
movq %rbx,%rax
subq $1,%rax
jnc .L1570
call rt_abort
.L1570:
movq %rax,%rbx
movq %r15,%rax
addq %rbx,%rax
jnc .L1571
call rt_abort
.L1571:
movq %rax,%r13
movabsq $10,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1572
call rt_abort
.L1572:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L1573
call rt_abort
.L1573:
movq %r13,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
movq %rax,%r14
cmpq $0,%rax
jne .L1574
jmp .L1569
jmp .L1575
.L1574:
.L1575:
jmp .L1568
.L1569:
movq %r15,%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L1576
call rt_abort
.L1576:
movq %rax,-24(%rbp)
movabsq $24,%rax
subq %rbx,%rax
jnc .L1577
call rt_abort
.L1577:
movq -8(%rbp),%rdi
movq -24(%rbp),%rsi
movq %rax,%rdx
call rt_fmt_raw
movq %r15,%rdi
call rt_free
movabsq $0,%rax
movq -.F1567-8(%rbp),%rbx
movq -.F1567-16(%rbp),%r12
movq -.F1567-24(%rbp),%r13
movq -.F1567-32(%rbp),%r14
movq -.F1567-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1567-8(%rbp),%rbx
movq -.F1567-16(%rbp),%r12
movq -.F1567-24(%rbp),%r13
movq -.F1567-32(%rbp),%r14
movq -.F1567-40(%rbp),%r15
leave
ret
.set .F1567,32
.type rt_fmt_int,@function
rt_fmt_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1578,%rsp
subq $16,%rsp
movq %rbx,-.F1578-8(%rbp)
movq %r12,-.F1578-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1579:
movq %rax,-32(%rbp)
movabsq $1,%rcx
andq $1,%rax
movq %rax,-40(%rbp)
movq %r12,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i75
xorq %rax,%rax
jmp .Lret_i75
.Lret_i75:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1580
movq %rbx,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt45
call rt_pushb
jmp .Lopt46
.Lopt45:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt46:
movq %r12,%rcx
movabsq $0,%rax
subq %r12,%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_fmt_num
movq -.F1578-8(%rbp),%rbx
movq -.F1578-16(%rbp),%r12
leave
ret
jmp .L1581
.L1580:
.L1581:
movq %rbx,%rdi
movq %r12,%rsi
call rt_fmt_num
movq -.F1578-8(%rbp),%rbx
movq -.F1578-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1578-8(%rbp),%rbx
movq -.F1578-16(%rbp),%r12
leave
ret
.set .F1578,48
.type rt_fmt_bool,@function
rt_fmt_bool:
pushq %rbp
movq %rsp,%rbp
subq $.F1582,%rsp
subq $16,%rsp
movq %rbx,-.F1582-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1583
movq %rbx,%rdi
movabsq $116,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt47
call rt_pushb
jmp .Lopt48
.Lopt47:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt48:
movq %rbx,%rdi
movabsq $114,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt49
call rt_pushb
jmp .Lopt50
.Lopt49:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt50:
movq %rbx,%rdi
movabsq $117,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt51
call rt_pushb
jmp .Lopt52
.Lopt51:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt52:
movq %rbx,%rdi
movabsq $101,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt53
call rt_pushb
jmp .Lopt54
.Lopt53:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt54:
jmp .L1584
.L1583:
movq %rbx,%rdi
movabsq $102,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt55
call rt_pushb
jmp .Lopt56
.Lopt55:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt56:
movq %rbx,%rdi
movabsq $97,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt57
call rt_pushb
jmp .Lopt58
.Lopt57:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt58:
movq %rbx,%rdi
movabsq $108,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt59
call rt_pushb
jmp .Lopt60
.Lopt59:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt60:
movq %rbx,%rdi
movabsq $115,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt61
call rt_pushb
jmp .Lopt62
.Lopt61:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt62:
movq %rbx,%rdi
movabsq $101,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt63
call rt_pushb
jmp .Lopt64
.Lopt63:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt64:
.L1584:
movabsq $0,%rax
movq -.F1582-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1582-8(%rbp),%rbx
leave
ret
.set .F1582,16
.type rt_fmt_seq,@function
rt_fmt_seq:
pushq %rbp
movq %rsp,%rbp
subq $.F1585,%rsp
subq $32,%rsp
movq %rbx,-.F1585-8(%rbp)
movq %r12,-.F1585-16(%rbp)
movq %r13,-.F1585-24(%rbp)
movq %r14,-.F1585-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,%r12
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r14
movq $0,%rbx
.L1586:
cmpq %r14,%rbx
jae .L1587
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt65
call rt_abort
.Lopt65:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt66
call rt_pushb
jmp .Lopt67
.Lopt66:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt67:
movq %rbx,%rax
addq $1,%rax
jnc .L1588
call rt_abort
.L1588:
movq %rax,%rbx
jmp .L1586
.L1587:
movabsq $0,%rax
movq -.F1585-8(%rbp),%rbx
movq -.F1585-16(%rbp),%r12
movq -.F1585-24(%rbp),%r13
movq -.F1585-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1585-8(%rbp),%rbx
movq -.F1585-16(%rbp),%r12
movq -.F1585-24(%rbp),%r13
movq -.F1585-32(%rbp),%r14
leave
ret
.set .F1585,16
.type rt_fmt_finish,@function
rt_fmt_finish:
pushq %rbp
movq %rsp,%rbp
subq $.F1589,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_text
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_drop_seq
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1589,16
.type rt_f64_pow2,@function
rt_f64_pow2:
pushq %rbp
movq %rsp,%rbp
subq $.F1590,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591
call rt_abort
.L1591:
movq %rax,-16(%rbp)
movabsq $4503599627370496,%rcx
movq -16(%rbp),%rax
imulq %rcx,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1590,16
.type rt_f64_neg,@function
rt_f64_neg:
pushq %rbp
movq %rsp,%rbp
subq $.F1592,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $9223372036854775808,%rcx
movq -8(%rbp),%rax
xorq %rcx,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1592,16
.type rt_f64_abs,@function
rt_f64_abs:
pushq %rbp
movq %rsp,%rbp
subq $.F1593,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $9223372036854775807,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1593,16
.type rt_f64_is_nan,@function
rt_f64_is_nan:
pushq %rbp
movq %rsp,%rbp
subq $.F1594,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rcx
movq %rax,%xmm0
movq %rax,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1594,16
.type rt_f64_sqrt,@function
rt_f64_sqrt:
pushq %rbp
movq %rsp,%rbp
subq $.F1595,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%xmm0
sqrtsd %xmm0,%xmm0
movq %xmm0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1595,16
.type rt_f64_op,@function
rt_f64_op:
pushq %rbp
movq %rsp,%rbp
subq $.F1596,%rsp
subq $32,%rsp
movq %rbx,-.F1596-8(%rbp)
movq %r12,-.F1596-16(%rbp)
movq %r13,-.F1596-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq $0,-32(%rbp)
cmpq $43,%rbx
jne .L1597
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1596-8(%rbp),%rbx
movq -.F1596-16(%rbp),%r12
movq -.F1596-24(%rbp),%r13
leave
ret
jmp .L1598
.L1597:
.L1598:
cmpq $45,%rbx
jne .L1599
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1596-8(%rbp),%rbx
movq -.F1596-16(%rbp),%r12
movq -.F1596-24(%rbp),%r13
leave
ret
jmp .L1600
.L1599:
.L1600:
cmpq $42,%rbx
jne .L1601
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
mulsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1596-8(%rbp),%rbx
movq -.F1596-16(%rbp),%r12
movq -.F1596-24(%rbp),%r13
leave
ret
jmp .L1602
.L1601:
.L1602:
movabsq $47,%rcx
cmpq $47,%rbx
jne .L1603
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
divsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1596-8(%rbp),%rbx
movq -.F1596-16(%rbp),%r12
movq -.F1596-24(%rbp),%r13
leave
ret
jmp .L1604
.L1603:
.L1604:
call rt_abort
movabsq $0,%rax
movq -.F1596-8(%rbp),%rbx
movq -.F1596-16(%rbp),%r12
movq -.F1596-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1596-8(%rbp),%rbx
movq -.F1596-16(%rbp),%r12
movq -.F1596-24(%rbp),%r13
leave
ret
.set .F1596,32
.type rt_f64_cmp,@function
rt_f64_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F1605,%rsp
subq $32,%rsp
movq %rbx,-.F1605-8(%rbp)
movq %r12,-.F1605-16(%rbp)
movq %r13,-.F1605-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq %rsi,%rbx
movq %rdx,%r12
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
cmpq $60,%r13
jne .L1606
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
jmp .L1607
.L1606:
.L1607:
cmpq $62,%r13
jne .L1608
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
jmp .L1609
.L1608:
.L1609:
cmpq $269,%r13
jne .L1610
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L1612
call rt_abort
.L1612:
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
jmp .L1611
.L1610:
.L1611:
cmpq $270,%r13
jne .L1613
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L1615
call rt_abort
.L1615:
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
jmp .L1614
.L1613:
.L1614:
cmpq $258,%r13
jne .L1616
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
jmp .L1617
.L1616:
.L1617:
movabsq $259,%rcx
cmpq $259,%r13
jne .L1618
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
jmp .L1619
.L1618:
.L1619:
call rt_abort
movabsq $0,%rax
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1605-8(%rbp),%rbx
movq -.F1605-16(%rbp),%r12
movq -.F1605-24(%rbp),%r13
leave
ret
.set .F1605,48
.type rt_f64_from_int,@function
rt_f64_from_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1620,%rsp
subq $16,%rsp
movq %rbx,-.F1620-8(%rbp)
movq %r12,-.F1620-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1621:
movq %rax,-24(%rbp)
movabsq $1,%rcx
andq $1,%rax
testq %rax,%rax
jz .L1622
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq -.F1620-8(%rbp),%rbx
movq -.F1620-16(%rbp),%r12
leave
ret
jmp .L1623
.L1622:
.L1623:
movabsq $9223372036854775808,%rcx
cmpq %rcx,%rbx
jae .L1624
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq -.F1620-8(%rbp),%rbx
movq -.F1620-16(%rbp),%r12
leave
ret
jmp .L1625
.L1624:
.L1625:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%r12
movq %rbx,%rax
andq $1,%rax
movq %rax,-32(%rbp)
movq %r12,%rax
andq $1,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1626
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1628
call rt_abort
.L1628:
movq %rax,%r12
jmp .L1627
.L1626:
.L1627:
movq %r12,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq %rax,%rcx
movq %rax,%xmm0
movq %rax,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1620-8(%rbp),%rbx
movq -.F1620-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1620-8(%rbp),%rbx
movq -.F1620-16(%rbp),%r12
leave
ret
.set .F1620,48
.type rt_int_from_f64,@function
rt_int_from_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F1629,%rsp
subq $32,%rsp
movq %rbx,-.F1629-8(%rbp)
movq %r12,-.F1629-16(%rbp)
movq %r13,-.F1629-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movq -16(%rbp),%rax
andq $255,%rax
movq %rax,%r12
movq -16(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1630:
movq %rax,-24(%rbp)
andq $1,%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
movq %rbx,%rcx
movq %rbx,%xmm0
movq %rbx,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1631
call rt_abort
jmp .L1632
.L1631:
.L1632:
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i76
call rt_abort
.L1591_i76:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i76
xorq %rax,%rax
jmp .Lret_i76
.Lret_i76:
movq %rax,-48(%rbp)
movq -32(%rbp),%rax
testq %rax,%rax
jz .L1633
movabsq $1,%rcx
movq %r12,%rax
subq $1,%rax
jnc .L1635
call rt_abort
.L1635:
movq %rax,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i77
call rt_abort
.L1591_i77:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i77
xorq %rax,%rax
jmp .Lret_i77
.Lret_i77:
movq %rax,-56(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775808,%rcx
movq %r8,%rax
xorq %rcx,%rax
jmp .Lret_i78
xorq %rax,%rax
jmp .Lret_i78
.Lret_i78:
movq %rax,%r13
cmpq $64,%r12
jae .L1636
movq %r13,%rax
movq -48(%rbp),%rcx
movq %r13,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq %rax,%r13
jmp .L1637
.L1636:
.L1637:
movq %rbx,%rax
movq -56(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1638
call rt_abort
jmp .L1639
.L1638:
.L1639:
cmpq $64,%r12
jae .L1640
movq %r13,%rax
movq %rbx,%rcx
movq %r13,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq %rax,-72(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1642
call rt_abort
jmp .L1643
.L1642:
.L1643:
jmp .L1641
.L1640:
movq %rbx,%rax
movq %r13,%rcx
movq %rbx,%xmm0
movq %r13,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1644
call rt_abort
jmp .L1645
.L1644:
.L1645:
.L1641:
movq %rbx,%rax
movq %rbx,%xmm0
cvttsd2si %xmm0,%rax
movq -.F1629-8(%rbp),%rbx
movq -.F1629-16(%rbp),%r12
movq -.F1629-24(%rbp),%r13
leave
ret
jmp .L1634
.L1633:
.L1634:
movq -48(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775808,%rcx
movq %r8,%rax
xorq %rcx,%rax
jmp .Lret_i79
xorq %rax,%rax
jmp .Lret_i79
.Lret_i79:
movq %rax,-80(%rbp)
movq %rbx,%rcx
movq %rax,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq %rax,-88(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1646
call rt_abort
jmp .L1647
.L1646:
.L1647:
movq %r12,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i80
call rt_abort
.L1591_i80:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i80
xorq %rax,%rax
jmp .Lret_i80
.Lret_i80:
movq %rax,-96(%rbp)
movq %rbx,%rax
movq -96(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq %rax,-104(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1648
call rt_abort
jmp .L1649
.L1648:
.L1649:
movabsq $63,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i81
call rt_abort
.L1591_i81:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i81
xorq %rax,%rax
jmp .Lret_i81
.Lret_i81:
movq %rax,-112(%rbp)
movq %rbx,%rax
movq -112(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1650
movq %rbx,%rax
movq %rbx,%xmm0
cvttsd2si %xmm0,%rax
movq -.F1629-8(%rbp),%rbx
movq -.F1629-16(%rbp),%r12
movq -.F1629-24(%rbp),%r13
leave
ret
jmp .L1651
.L1650:
.L1651:
movq %rbx,%rax
movq -112(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq %rax,%xmm0
cvttsd2si %xmm0,%rax
movq %rax,-120(%rbp)
movabsq $9223372036854775808,%rcx
addq %rcx,%rax
movq -.F1629-8(%rbp),%rbx
movq -.F1629-16(%rbp),%r12
movq -.F1629-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1629-8(%rbp),%rbx
movq -.F1629-16(%rbp),%r12
movq -.F1629-24(%rbp),%r13
leave
ret
.set .F1629,128
.type rt_f64_trunc,@function
rt_f64_trunc:
pushq %rbp
movq %rsp,%rbp
subq $.F1652,%rsp
subq $16,%rsp
movq %rbx,-.F1652-8(%rbp)
movq %r12,-.F1652-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L1653
call rt_abort
.L1653:
movabsq $52,%rcx
movq %rbx,%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
andq $2047,%rax
movq %rax,%r12
movq %rax,%rcx
movabsq $1074,%rax
cmpq %rcx,%rax
jae .L1654
movq %rbx,%rax
movq -.F1652-8(%rbp),%rbx
movq -.F1652-16(%rbp),%r12
leave
ret
jmp .L1655
.L1654:
.L1655:
cmpq $1023,%r12
jae .L1656
movabsq $9223372036854775808,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq -.F1652-8(%rbp),%rbx
movq -.F1652-16(%rbp),%r12
leave
ret
jmp .L1657
.L1656:
.L1657:
movabsq $1075,%rax
subq %r12,%rax
jnc .L1658
call rt_abort
.L1658:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1659
call rt_abort
.L1659:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,-32(%rbp)
subq $1,%rax
jnc .L1660
call rt_abort
.L1660:
movq %rax,-40(%rbp)
movq %rax,%rcx
movabsq $18446744073709551615,%rax
subq %rcx,%rax
jnc .L1661
call rt_abort
.L1661:
movq %rax,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq -.F1652-8(%rbp),%rbx
movq -.F1652-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1652-8(%rbp),%rbx
movq -.F1652-16(%rbp),%r12
leave
ret
.set .F1652,48
.type rt_f64_floor,@function
rt_f64_floor:
pushq %rbp
movq %rsp,%rbp
subq $.F1662,%rsp
subq $16,%rsp
movq %rbx,-.F1662-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_f64_trunc
movq %rax,%rbx
movq -8(%rbp),%rax
movq %rbx,%rcx
movq %rax,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1663
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i82
call rt_abort
.L1591_i82:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i82
xorq %rax,%rax
jmp .Lret_i82
.Lret_i82:
movq %rax,-16(%rbp)
movq %rbx,%rax
movq -16(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1662-8(%rbp),%rbx
leave
ret
jmp .L1664
.L1663:
.L1664:
movq %rbx,%rax
movq -.F1662-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1662-8(%rbp),%rbx
leave
ret
.set .F1662,16
.type rt_f64_ceil,@function
rt_f64_ceil:
pushq %rbp
movq %rsp,%rbp
subq $.F1665,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_f64_trunc
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
movq -8(%rbp),%rcx
movq %rax,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1666
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i83
call rt_abort
.L1591_i83:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i83
xorq %rax,%rax
jmp .Lret_i83
.Lret_i83:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,%xmm0
movq %rcx,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
leave
ret
jmp .L1667
.L1666:
.L1667:
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1665,32
.type rt_f64_round,@function
rt_f64_round:
pushq %rbp
movq %rsp,%rbp
subq $.F1668,%rsp
subq $16,%rsp
movq %rbx,-.F1668-8(%rbp)
movq %r12,-.F1668-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r12,%rdi
call rt_f64_trunc
movq %rax,%rbx
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775807,%rcx
movq %r8,%rax
andq %rcx,%rax
jmp .Lret_i84
xorq %rax,%rax
jmp .Lret_i84
.Lret_i84:
movq %rax,-16(%rbp)
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i85
call rt_abort
.L1591_i85:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i85
xorq %rax,%rax
jmp .Lret_i85
.Lret_i85:
movq %rax,-24(%rbp)
movabsq $4503599627370496,%rcx
subq %rcx,%rax
jnc .L1669
call rt_abort
.L1669:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1670
movq %rbx,%rax
movq -.F1668-8(%rbp),%rbx
movq -.F1668-16(%rbp),%r12
leave
ret
jmp .L1671
.L1670:
.L1671:
movabsq $63,%rax
cmpq $63,%rax
jnc .L1672
call rt_abort
.L1672:
movabsq $63,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1673
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i86
call rt_abort
.L1591_i86:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i86
xorq %rax,%rax
jmp .Lret_i86
.Lret_i86:
movq %rax,-48(%rbp)
movq %rbx,%rax
movq -48(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1668-8(%rbp),%rbx
movq -.F1668-16(%rbp),%r12
leave
ret
jmp .L1674
.L1673:
.L1674:
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1591_i87
call rt_abort
.L1591_i87:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i87
xorq %rax,%rax
jmp .Lret_i87
.Lret_i87:
movq %rax,-56(%rbp)
movq %rbx,%rax
movq -56(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1668-8(%rbp),%rbx
movq -.F1668-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1668-8(%rbp),%rbx
movq -.F1668-16(%rbp),%r12
leave
ret
.set .F1668,64
.type rt_f64_min,@function
rt_f64_min:
pushq %rbp
movq %rsp,%rbp
subq $.F1675,%rsp
subq $16,%rsp
movq %rbx,-.F1675-8(%rbp)
movq %r12,-.F1675-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
movq %rbx,%rcx
movq %rbx,%xmm0
movq %rbx,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1676
movq %r12,%rax
movq -.F1675-8(%rbp),%rbx
movq -.F1675-16(%rbp),%r12
leave
ret
jmp .L1677
.L1676:
.L1677:
movq %r12,%rax
movq %r12,%rcx
movq %r12,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L1678
movq %rbx,%rax
movq -.F1675-8(%rbp),%rbx
movq -.F1675-16(%rbp),%r12
leave
ret
jmp .L1679
.L1678:
.L1679:
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1680
movq %r12,%rax
movq -.F1675-8(%rbp),%rbx
movq -.F1675-16(%rbp),%r12
leave
ret
jmp .L1681
.L1680:
.L1681:
movq %rbx,%rax
movq -.F1675-8(%rbp),%rbx
movq -.F1675-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1675-8(%rbp),%rbx
movq -.F1675-16(%rbp),%r12
leave
ret
.set .F1675,32
.type rt_f64_max,@function
rt_f64_max:
pushq %rbp
movq %rsp,%rbp
subq $.F1682,%rsp
subq $16,%rsp
movq %rbx,-.F1682-8(%rbp)
movq %r12,-.F1682-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
movq %rbx,%rcx
movq %rbx,%xmm0
movq %rbx,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1683
movq %r12,%rax
movq -.F1682-8(%rbp),%rbx
movq -.F1682-16(%rbp),%r12
leave
ret
jmp .L1684
.L1683:
.L1684:
movq %r12,%rax
movq %r12,%rcx
movq %r12,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L1685
movq %rbx,%rax
movq -.F1682-8(%rbp),%rbx
movq -.F1682-16(%rbp),%r12
leave
ret
jmp .L1686
.L1685:
.L1686:
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1687
movq %r12,%rax
movq -.F1682-8(%rbp),%rbx
movq -.F1682-16(%rbp),%r12
leave
ret
jmp .L1688
.L1687:
.L1688:
movq %rbx,%rax
movq -.F1682-8(%rbp),%rbx
movq -.F1682-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1682-8(%rbp),%rbx
movq -.F1682-16(%rbp),%r12
leave
ret
.set .F1682,32
.type rt_f64_is_finite,@function
rt_f64_is_finite:
pushq %rbp
movq %rsp,%rbp
subq $.F1689,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L1690
call rt_abort
.L1690:
movabsq $52,%rcx
movq -8(%rbp),%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
andq $2047,%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
cmpq $2047,%rax
setne %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1689,32
.type rt_f64_is_infinite,@function
rt_f64_is_infinite:
pushq %rbp
movq %rsp,%rbp
subq $.F1691,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $9223372036854775807,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
movq %rax,-16(%rbp)
movabsq $9218868437227405312,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
sete %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1691,16
.type rt_float_step,@function
rt_float_step:
pushq %rbp
movq %rsp,%rbp
subq $.F1692,%rsp
subq $32,%rsp
movq %rbx,-.F1692-8(%rbp)
movq %r12,-.F1692-16(%rbp)
movq %r13,-.F1692-24(%rbp)
movq %r14,-.F1692-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r13,%rax
movq %r13,%rcx
movq %r13,%xmm0
movq %r13,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1693
movq %r13,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
movq -.F1692-24(%rbp),%r13
movq -.F1692-32(%rbp),%r14
leave
ret
jmp .L1694
.L1693:
.L1694:
movq %r13,%rbx
movabsq $9223372036854775808,%rax
movq %rax,%r14
movabsq $9218868437227405312,%rax
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1695
movq %r13,%rdi
call rt_f32_bits
movq %rax,%rbx
movabsq $2147483648,%r14
movq $2139095040,-40(%rbp)
jmp .L1696
.L1695:
.L1696:
movq %r14,%rax
subq $1,%rax
jnc .L1697
call rt_abort
.L1697:
movq %rax,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
andq %r14,%rax
movq %rax,-56(%rbp)
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movq %rbx,%r12
movq -48(%rbp),%rax
cmpq $0,%rax
jne .L1698
movq $1,%r12
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1700
movabsq $1,%rcx
movq %r14,%rax
orq $1,%rax
movq %rax,%r12
jmp .L1701
.L1700:
.L1701:
jmp .L1699
.L1698:
movq -16(%rbp),%rax
movq -64(%rbp),%rcx
cmpq %rcx,%rax
je .L1702
movq -48(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
je .L1704
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L1706
call rt_abort
.L1706:
movq %rax,%r12
jmp .L1705
.L1704:
.L1705:
jmp .L1703
.L1702:
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L1707
call rt_abort
.L1707:
movq %rax,%r12
.L1703:
.L1699:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1708
movq %r12,%rdi
call rt_f32_from_bits
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
movq -.F1692-24(%rbp),%r13
movq -.F1692-32(%rbp),%r14
leave
ret
jmp .L1709
.L1708:
.L1709:
movq %r12,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
movq -.F1692-24(%rbp),%r13
movq -.F1692-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
movq -.F1692-24(%rbp),%r13
movq -.F1692-32(%rbp),%r14
leave
ret
.set .F1692,64
.type rt_big,@function
rt_big:
pushq %rbp
movq %rsp,%rbp
subq $.F1710,%rsp
subq $48,%rsp
movq %rbx,-.F1710-8(%rbp)
movq %r12,-.F1710-16(%rbp)
movq %r13,-.F1710-24(%rbp)
movq %r14,-.F1710-32(%rbp)
movq %r15,-.F1710-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $384,%rdi
call rt_alloc
movq %rax,%r13
movq $0,%rbx
.L1711:
cmpq $48,%rbx
jae .L1712
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1713
call rt_abort
.L1713:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1714
call rt_abort
.L1714:
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1715
call rt_abort
.L1715:
movq %rax,%rbx
jmp .L1711
.L1712:
movq -8(%rbp),%rax
movq %rax,%r12
movq $0,%rbx
.L1716:
cmpq $0,%r12
je .L1717
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1718
call rt_abort
.L1718:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1719
call rt_abort
.L1719:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1720
call rt_abort
.L1720:
xorq %rdx,%rdx
divq %rcx
movq %r15,%rcx
movq %rdx,%rax
movq %rdx,(%rcx)
xorq %rdx,%rax
movq %r12,%rdi
movabsq $1000000000,%rsi
call rt_div
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L1721
call rt_abort
.L1721:
movq %rax,%rbx
jmp .L1716
.L1717:
movq %r13,%rax
movq -.F1710-8(%rbp),%rbx
movq -.F1710-16(%rbp),%r12
movq -.F1710-24(%rbp),%r13
movq -.F1710-32(%rbp),%r14
movq -.F1710-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1710-8(%rbp),%rbx
movq -.F1710-16(%rbp),%r12
movq -.F1710-24(%rbp),%r13
movq -.F1710-32(%rbp),%r14
movq -.F1710-40(%rbp),%r15
leave
ret
.set .F1710,16
.type rt_big_mul,@function
rt_big_mul:
pushq %rbp
movq %rsp,%rbp
subq $.F1722,%rsp
subq $48,%rsp
movq %rbx,-.F1722-8(%rbp)
movq %r12,-.F1722-16(%rbp)
movq %r13,-.F1722-24(%rbp)
movq %r14,-.F1722-32(%rbp)
movq %r15,-.F1722-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,-16(%rbp)
movq $0,%r13
movq $0,%rbx
.L1723:
cmpq $48,%rbx
jae .L1724
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1725
call rt_abort
.L1725:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1726
call rt_abort
.L1726:
movq (%rax),%rax
movq -16(%rbp),%rcx
mulq %rcx
jnc .L1727
call rt_abort
.L1727:
addq %r13,%rax
jnc .L1728
call rt_abort
.L1728:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1729
call rt_abort
.L1729:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1730
call rt_abort
.L1730:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1731
call rt_abort
.L1731:
xorq %rdx,%rdx
divq %rcx
movq %r15,%rcx
movq %rdx,%rax
movq %rdx,(%rcx)
xorq %rdx,%rax
movq %r12,%rdi
movabsq $1000000000,%rsi
call rt_div
movq %rax,%r13
movq %rbx,%rax
addq $1,%rax
jnc .L1732
call rt_abort
.L1732:
movq %rax,%rbx
jmp .L1723
.L1724:
movabsq $0,%rcx
cmpq $0,%r13
je .L1733
call rt_abort
jmp .L1734
.L1733:
.L1734:
movabsq $0,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
movq -.F1722-24(%rbp),%r13
movq -.F1722-32(%rbp),%r14
movq -.F1722-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
movq -.F1722-24(%rbp),%r13
movq -.F1722-32(%rbp),%r14
movq -.F1722-40(%rbp),%r15
leave
ret
.set .F1722,16
.type rt_big_add,@function
rt_big_add:
pushq %rbp
movq %rsp,%rbp
subq $.F1735,%rsp
subq $48,%rsp
movq %rbx,-.F1735-8(%rbp)
movq %r12,-.F1735-16(%rbp)
movq %r13,-.F1735-24(%rbp)
movq %r14,-.F1735-32(%rbp)
movq %r15,-.F1735-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r13
movq $0,%rbx
.L1736:
cmpq $48,%rbx
jae .L1737
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1738
call rt_abort
.L1738:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1739
call rt_abort
.L1739:
movq (%rax),%rax
movq %rax,%r14
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1740
call rt_abort
.L1740:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1741
call rt_abort
.L1741:
movq (%rax),%rax
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1742
call rt_abort
.L1742:
addq %r13,%rax
jnc .L1743
call rt_abort
.L1743:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1744
call rt_abort
.L1744:
movq %rax,%rcx
movq -8(%rbp),%rax
addq %rcx,%rax
jnc .L1745
call rt_abort
.L1745:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1746
call rt_abort
.L1746:
xorq %rdx,%rdx
divq %rcx
movq %r15,%rcx
movq %rdx,%rax
movq %rdx,(%rcx)
xorq %rdx,%rax
movq %r12,%rdi
movabsq $1000000000,%rsi
call rt_div
movq %rax,%r13
movq %rbx,%rax
addq $1,%rax
jnc .L1747
call rt_abort
.L1747:
movq %rax,%rbx
jmp .L1736
.L1737:
movabsq $0,%rcx
cmpq $0,%r13
je .L1748
call rt_abort
jmp .L1749
.L1748:
.L1749:
movabsq $0,%rax
movq -.F1735-8(%rbp),%rbx
movq -.F1735-16(%rbp),%r12
movq -.F1735-24(%rbp),%r13
movq -.F1735-32(%rbp),%r14
movq -.F1735-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1735-8(%rbp),%rbx
movq -.F1735-16(%rbp),%r12
movq -.F1735-24(%rbp),%r13
movq -.F1735-32(%rbp),%r14
movq -.F1735-40(%rbp),%r15
leave
ret
.set .F1735,32
.type rt_big_sub,@function
rt_big_sub:
pushq %rbp
movq %rsp,%rbp
subq $.F1750,%rsp
subq $48,%rsp
movq %rbx,-.F1750-8(%rbp)
movq %r12,-.F1750-16(%rbp)
movq %r13,-.F1750-24(%rbp)
movq %r14,-.F1750-32(%rbp)
movq %r15,-.F1750-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r15
movq $0,%rbx
.L1751:
cmpq $48,%rbx
jae .L1752
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1753
call rt_abort
.L1753:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1754
call rt_abort
.L1754:
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1755
call rt_abort
.L1755:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1756
call rt_abort
.L1756:
movq (%rax),%rax
addq %r15,%rax
jnc .L1757
call rt_abort
.L1757:
movq %rax,%r13
cmpq %r13,%r12
jae .L1758
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1760
call rt_abort
.L1760:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1761
call rt_abort
.L1761:
movq %rax,-24(%rbp)
movq %r12,%rax
addq $1000000000,%rax
jnc .L1762
call rt_abort
.L1762:
subq %r13,%rax
jnc .L1763
call rt_abort
.L1763:
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $1,%r15
jmp .L1759
.L1758:
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1764
call rt_abort
.L1764:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1765
call rt_abort
.L1765:
movq %rax,-32(%rbp)
movq %r12,%rax
subq %r13,%rax
jnc .L1766
call rt_abort
.L1766:
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $0,%r15
.L1759:
movq %rbx,%rax
addq $1,%rax
jnc .L1767
call rt_abort
.L1767:
movq %rax,%rbx
jmp .L1751
.L1752:
movabsq $0,%rax
movq -.F1750-8(%rbp),%rbx
movq -.F1750-16(%rbp),%r12
movq -.F1750-24(%rbp),%r13
movq -.F1750-32(%rbp),%r14
movq -.F1750-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1750-8(%rbp),%rbx
movq -.F1750-16(%rbp),%r12
movq -.F1750-24(%rbp),%r13
movq -.F1750-32(%rbp),%r14
movq -.F1750-40(%rbp),%r15
leave
ret
.set .F1750,32
.type rt_big_cmp,@function
rt_big_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F1768,%rsp
subq $48,%rsp
movq %rbx,-.F1768-8(%rbp)
movq %r12,-.F1768-16(%rbp)
movq %r13,-.F1768-24(%rbp)
movq %r14,-.F1768-32(%rbp)
movq %r15,-.F1768-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq $48,%rbx
.L1769:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L1770
movq %rbx,%rax
subq $1,%rax
jnc .L1771
call rt_abort
.L1771:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L1772
call rt_abort
.L1772:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1773
call rt_abort
.L1773:
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1774
call rt_abort
.L1774:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1775
call rt_abort
.L1775:
movq (%rax),%rax
movq %rax,%r13
cmpq %r13,%r12
jae .L1776
movabsq $0,%rax
movq -.F1768-8(%rbp),%rbx
movq -.F1768-16(%rbp),%r12
movq -.F1768-24(%rbp),%r13
movq -.F1768-32(%rbp),%r14
movq -.F1768-40(%rbp),%r15
leave
ret
jmp .L1777
.L1776:
.L1777:
cmpq %r12,%r13
jae .L1778
movabsq $2,%rax
movq -.F1768-8(%rbp),%rbx
movq -.F1768-16(%rbp),%r12
movq -.F1768-24(%rbp),%r13
movq -.F1768-32(%rbp),%r14
movq -.F1768-40(%rbp),%r15
leave
ret
jmp .L1779
.L1778:
.L1779:
jmp .L1769
.L1770:
movabsq $1,%rax
movq -.F1768-8(%rbp),%rbx
movq -.F1768-16(%rbp),%r12
movq -.F1768-24(%rbp),%r13
movq -.F1768-32(%rbp),%r14
movq -.F1768-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1768-8(%rbp),%rbx
movq -.F1768-16(%rbp),%r12
movq -.F1768-24(%rbp),%r13
movq -.F1768-32(%rbp),%r14
movq -.F1768-40(%rbp),%r15
leave
ret
.set .F1768,16
.type rt_big_shift,@function
rt_big_shift:
pushq %rbp
movq %rsp,%rbp
subq $.F1780,%rsp
subq $32,%rsp
movq %rbx,-.F1780-8(%rbp)
movq %r12,-.F1780-16(%rbp)
movq %r13,-.F1780-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq %rsi,%r13
movq $0,%rbx
.L1781:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L1782
movq %r12,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %rbx,%rax
addq $1,%rax
jnc .L1783
call rt_abort
.L1783:
movq %rax,%rbx
jmp .L1781
.L1782:
movabsq $0,%rax
movq -.F1780-8(%rbp),%rbx
movq -.F1780-16(%rbp),%r12
movq -.F1780-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1780-8(%rbp),%rbx
movq -.F1780-16(%rbp),%r12
movq -.F1780-24(%rbp),%r13
leave
ret
.set .F1780,16
.type rt_push_text,@function
rt_push_text:
pushq %rbp
movq %rsp,%rbp
subq $.F1784,%rsp
subq $16,%rsp
movq %rbx,-.F1784-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq -16(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt68
call rt_pushb
jmp .Lopt69
.Lopt68:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt69:
movq -24(%rbp),%rax
cmpq $0,%rax
je .L1785
movq -24(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt70
call rt_pushb
jmp .Lopt71
.Lopt70:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt71:
jmp .L1786
.L1785:
.L1786:
movq -32(%rbp),%rax
cmpq $0,%rax
je .L1787
movq -32(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt72
call rt_pushb
jmp .Lopt73
.Lopt72:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt73:
jmp .L1788
.L1787:
.L1788:
movabsq $0,%rax
movq -.F1784-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1784-8(%rbp),%rbx
leave
ret
.set .F1784,32
.type rt_fmt_f64,@function
rt_fmt_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F1789,%rsp
subq $48,%rsp
movq %rbx,-.F1789-8(%rbp)
movq %r12,-.F1789-16(%rbp)
movq %r13,-.F1789-24(%rbp)
movq %r14,-.F1789-32(%rbp)
movq %r15,-.F1789-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r12
movq %rsi,%r13
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r13,%rax
movq %r13,%rcx
movq %r13,%xmm0
movq %r13,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1790
movq %r12,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F1789-8(%rbp),%rbx
movq -.F1789-16(%rbp),%r12
movq -.F1789-24(%rbp),%r13
movq -.F1789-32(%rbp),%r14
movq -.F1789-40(%rbp),%r15
leave
ret
jmp .L1791
.L1790:
.L1791:
movq %r13,%rcx
movabsq $9223372036854775807,%rax
cmpq %r13,%rax
jae .L1792
movq %r12,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt74
call rt_pushb
jmp .Lopt75
.Lopt74:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt75:
jmp .L1793
.L1792:
.L1793:
movq %r13,%rdi
movabsq $4503599627370496,%rsi
call rt_div
movq %rax,-32(%rbp)
andq $2047,%rax
movq %rax,%rbx
movabsq $4503599627370495,%rcx
movq %r13,%rax
andq %rcx,%rax
movq %rax,%r14
cmpq $2047,%rbx
jne .L1794
movq %r12,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F1789-8(%rbp),%rbx
movq -.F1789-16(%rbp),%r12
movq -.F1789-24(%rbp),%r13
movq -.F1789-32(%rbp),%r14
movq -.F1789-40(%rbp),%r15
leave
ret
jmp .L1795
.L1794:
.L1795:
movq %rbx,%rax
cmpq $0,%rbx
sete %al
movzbq %al,%rax
movq %rax,-40(%rbp)
movq %r14,%rax
cmpq $0,%r14
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1796
movq %r12,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt76
call rt_pushb
jmp .Lopt77
.Lopt76:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt77:
movabsq $0,%rax
movq -.F1789-8(%rbp),%rbx
movq -.F1789-16(%rbp),%r12
movq -.F1789-24(%rbp),%r13
movq -.F1789-32(%rbp),%r14
movq -.F1789-40(%rbp),%r15
leave
ret
jmp .L1797
.L1796:
.L1797:
movq %r14,-48(%rbp)
movq $0,-56(%rbp)
cmpq $0,%rbx
jne .L1798
movq $1074,%r15
movq $1,-56(%rbp)
jmp .L1799
.L1798:
movabsq $4503599627370496,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1800
call rt_abort
.L1800:
movq %rax,-48(%rbp)
cmpq $1075,%rbx
jae .L1801
movabsq $1075,%rax
subq %rbx,%rax
jnc .L1803
call rt_abort
.L1803:
movq %rax,%r15
movq $1,-56(%rbp)
jmp .L1802
.L1801:
movq %rbx,%rax
subq $1075,%rax
jnc .L1804
call rt_abort
.L1804:
movq %rax,%r15
.L1802:
.L1799:
movq %r14,%rax
cmpq $0,%r14
sete %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movabsq $1,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -64(%rbp),%rax
andq %rcx,%rax
movq %r12,%rdi
movq -48(%rbp),%rsi
movq %r15,%rdx
movq -56(%rbp),%rcx
movq %rax,%r8
call rt_fmt_shortest
movq -.F1789-8(%rbp),%rbx
movq -.F1789-16(%rbp),%r12
movq -.F1789-24(%rbp),%r13
movq -.F1789-32(%rbp),%r14
movq -.F1789-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1789-8(%rbp),%rbx
movq -.F1789-16(%rbp),%r12
movq -.F1789-24(%rbp),%r13
movq -.F1789-32(%rbp),%r14
movq -.F1789-40(%rbp),%r15
leave
ret
.set .F1789,64
.type rt_fmt_shortest,@function
rt_fmt_shortest:
pushq %rbp
movq %rsp,%rbp
subq $.F1805,%rsp
subq $48,%rsp
movq %rbx,-.F1805-8(%rbp)
movq %r12,-.F1805-16(%rbp)
movq %r13,-.F1805-24(%rbp)
movq %r14,-.F1805-32(%rbp)
movq %r15,-.F1805-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq %r8,-40(%rbp)
leaq -.F1805(%rbp),%rdi
movq $.F1805/8-5,%rcx
xorl %eax,%eax
rep stosq
movq -16(%rbp),%rax
andq $1,%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_big
movq %rax,%rbx
movabsq $1,%rdi
call rt_big
movq %rax,%r13
movabsq $1,%rdi
call rt_big
movq %rax,-64(%rbp)
movabsq $1,%rdi
call rt_big
movq %rax,-72(%rbp)
movabsq $0,%rcx
movq -32(%rbp),%rax
cmpq $0,%rax
jne .L1806
movq -24(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_big_shift
movq -24(%rbp),%rax
movq -64(%rbp),%rdi
movq %rax,%rsi
call rt_big_shift
movq -24(%rbp),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_big_shift
jmp .L1807
.L1806:
movq -24(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_big_shift
.L1807:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %r13,%rdi
movabsq $2,%rsi
call rt_big_mul
movq -40(%rbp),%rax
testq %rax,%rax
jz .L1808
movq %rbx,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %r13,%rdi
movabsq $2,%rsi
call rt_big_mul
movq -64(%rbp),%rdi
movabsq $2,%rsi
call rt_big_mul
jmp .L1809
.L1808:
.L1809:
movabsq $0,%rdi
call rt_big
movq %rax,%r15
movq $0,-80(%rbp)
movq $0,-88(%rbp)
.L1810:
movabsq $1,%rax
testq %rax,%rax
jz .L1811
movq -64(%rbp),%rax
movq %r15,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_big_add
movq %r15,%rdi
movq %r13,%rsi
call rt_big_cmp
movq %rax,-96(%rbp)
movq %rax,-104(%rbp)
cmpq $2,%rax
sete %al
movzbq %al,%rax
movq %rax,-112(%rbp)
movq -96(%rbp),%rax
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq -56(%rbp),%rcx
andq %rcx,%rax
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L1812
call rt_abort
.L1812:
testq %rax,%rax
jz .L1813
movq %r13,%rdi
movabsq $10,%rsi
call rt_big_mul
movq -88(%rbp),%rax
testq %rax,%rax
jz .L1815
movq -80(%rbp),%rax
cmpq $1,%rax
jne .L1817
movq $0,-88(%rbp)
jmp .L1818
.L1817:
.L1818:
movabsq $1,%rcx
movq -80(%rbp),%rax
subq $1,%rax
jnc .L1819
call rt_abort
.L1819:
movq %rax,-80(%rbp)
jmp .L1816
.L1815:
movabsq $1,%rcx
movq -80(%rbp),%rax
addq $1,%rax
jnc .L1820
call rt_abort
.L1820:
movq %rax,-80(%rbp)
.L1816:
jmp .L1814
.L1813:
jmp .L1811
.L1814:
jmp .L1810
.L1811:
.L1821:
movabsq $1,%rax
testq %rax,%rax
jz .L1822
movq -64(%rbp),%rax
movq %r15,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_big_add
movq %r15,%rdi
movabsq $10,%rsi
call rt_big_mul
movq %r15,%rdi
movq %r13,%rsi
call rt_big_cmp
movq %rax,-120(%rbp)
movq %rax,-128(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-136(%rbp)
movq -120(%rbp),%rax
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq %rax,-144(%rbp)
movq -56(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -144(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -136(%rbp),%rax
addq %rcx,%rax
jnc .L1823
call rt_abort
.L1823:
testq %rax,%rax
jz .L1824
movq %rbx,%rdi
movabsq $10,%rsi
call rt_big_mul
movq -64(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq -72(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq -88(%rbp),%rax
testq %rax,%rax
jz .L1826
movabsq $1,%rcx
movq -80(%rbp),%rax
addq $1,%rax
jnc .L1828
call rt_abort
.L1828:
movq %rax,-80(%rbp)
jmp .L1827
.L1826:
movabsq $0,%rcx
movq -80(%rbp),%rax
cmpq $0,%rax
jne .L1829
movq $1,-88(%rbp)
movq $1,-80(%rbp)
jmp .L1830
.L1829:
movabsq $1,%rcx
movq -80(%rbp),%rax
subq $1,%rax
jnc .L1831
call rt_abort
.L1831:
movq %rax,-80(%rbp)
.L1830:
.L1827:
jmp .L1825
.L1824:
jmp .L1822
.L1825:
jmp .L1821
.L1822:
call rt_new
movq %rax,-152(%rbp)
.L1832:
movabsq $1,%rax
testq %rax,%rax
jz .L1833
movq %rbx,%rdi
movabsq $10,%rsi
call rt_big_mul
movq -64(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq -72(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq $0,%r12
.L1834:
movq %rbx,%rdi
movq %r13,%rsi
call rt_big_cmp
movabsq $0,%rcx
cmpq $0,%rax
je .L1835
movq %rbx,%rdi
movq %r13,%rsi
call rt_big_sub
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1836
call rt_abort
.L1836:
movq %rax,%r12
jmp .L1834
.L1835:
movq -72(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_big_cmp
movq %rax,-160(%rbp)
movq %rax,-168(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-176(%rbp)
movq -160(%rbp),%rax
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq -56(%rbp),%rcx
andq %rcx,%rax
movq %rax,%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L1837
call rt_abort
.L1837:
movq %rax,-184(%rbp)
movq -64(%rbp),%rax
movq %r15,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_big_add
movq %r15,%rdi
movq %r13,%rsi
call rt_big_cmp
movq %rax,-192(%rbp)
movq %rax,-200(%rbp)
cmpq $2,%rax
sete %al
movzbq %al,%rax
movq %rax,-208(%rbp)
movq -192(%rbp),%rax
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq -56(%rbp),%rcx
andq %rcx,%rax
movq %rax,%rcx
movq -208(%rbp),%rax
addq %rcx,%rax
jnc .L1838
call rt_abort
.L1838:
movq %rax,-216(%rbp)
movq -184(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-224(%rbp)
movq -216(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -224(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1839
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt78
call rt_push
jmp .Lopt79
.Lopt78:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt79:
jmp .L1832
jmp .L1840
.L1839:
.L1840:
movq -216(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -184(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1841
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt80
call rt_push
jmp .Lopt81
.Lopt80:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt81:
jmp .L1833
jmp .L1842
.L1841:
.L1842:
movq -184(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -216(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1843
movq %r12,%rax
addq $1,%rax
jnc .L1845
call rt_abort
.L1845:
movq -152(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt82
call rt_push
jmp .Lopt83
.Lopt82:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt83:
jmp .L1833
jmp .L1844
.L1843:
.L1844:
movq %r15,%rdi
movq %rbx,%rsi
movq %rbx,%rdx
call rt_big_add
movq %r15,%rdi
movq %r13,%rsi
call rt_big_cmp
movq %rax,-232(%rbp)
cmpq $0,%rax
jne .L1846
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt84
call rt_push
jmp .Lopt85
.Lopt84:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt85:
jmp .L1847
.L1846:
movq %r12,%rax
addq $1,%rax
jnc .L1848
call rt_abort
.L1848:
movq -152(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt86
call rt_push
jmp .Lopt87
.Lopt86:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt87:
.L1847:
jmp .L1833
jmp .L1832
.L1833:
movq -152(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-240(%rbp)
movq -80(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L1849
call rt_abort
.L1849:
testq %rax,%rax
jz .L1850
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt88
call rt_pushb
jmp .Lopt89
.Lopt88:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt89:
movq -8(%rbp),%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt90
call rt_pushb
jmp .Lopt91
.Lopt90:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt91:
movq $0,-248(%rbp)
movq -88(%rbp),%rax
testq %rax,%rax
jz .L1852
movq -80(%rbp),%rax
movq %rax,-248(%rbp)
jmp .L1853
.L1852:
.L1853:
movq $0,-256(%rbp)
.L1854:
movq -256(%rbp),%rax
movq -248(%rbp),%rcx
cmpq %rcx,%rax
jae .L1855
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt92
call rt_pushb
jmp .Lopt93
.Lopt92:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt93:
movq -256(%rbp),%rax
addq $1,%rax
jnc .L1856
call rt_abort
.L1856:
movq %rax,-256(%rbp)
jmp .L1854
.L1855:
movq $0,-256(%rbp)
.L1857:
movq -256(%rbp),%rax
movq -240(%rbp),%rcx
cmpq %rcx,%rax
jae .L1858
movq -256(%rbp),%rax
movq -152(%rbp),%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i88
call rt_abort
.Lopt15_i88:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i88
xorq %rax,%rax
jmp .Lret_i88
.Lret_i88:
movq %rax,%rcx
movabsq $48,%rax
addq %rcx,%rax
jnc .L1859
call rt_abort
.L1859:
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt94
call rt_pushb
jmp .Lopt95
.Lopt94:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt95:
movq -256(%rbp),%rax
addq $1,%rax
jnc .L1860
call rt_abort
.L1860:
movq %rax,-256(%rbp)
jmp .L1857
.L1858:
jmp .L1851
.L1850:
movq $0,-264(%rbp)
.L1861:
movq -264(%rbp),%rax
movq -240(%rbp),%rcx
cmpq %rcx,%rax
jae .L1862
movq -264(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jne .L1863
movq -8(%rbp),%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt96
call rt_pushb
jmp .Lopt97
.Lopt96:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt97:
jmp .L1864
.L1863:
.L1864:
movq -264(%rbp),%rax
movq -152(%rbp),%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i89
call rt_abort
.Lopt15_i89:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i89
xorq %rax,%rax
jmp .Lret_i89
.Lret_i89:
movq %rax,%rcx
movabsq $48,%rax
addq %rcx,%rax
jnc .L1865
call rt_abort
.L1865:
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt98
call rt_pushb
jmp .Lopt99
.Lopt98:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt99:
movq -264(%rbp),%rax
addq $1,%rax
jnc .L1866
call rt_abort
.L1866:
movq %rax,-264(%rbp)
jmp .L1861
.L1862:
.L1867:
movq -264(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jae .L1868
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt100
call rt_pushb
jmp .Lopt101
.Lopt100:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt101:
movq -264(%rbp),%rax
addq $1,%rax
jnc .L1869
call rt_abort
.L1869:
movq %rax,-264(%rbp)
jmp .L1867
.L1868:
.L1851:
movq -152(%rbp),%rax
movq %rax,%rdi
call rt_drop_seq
movq %rbx,%rdi
call rt_free
movq %r13,%rdi
call rt_free
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -72(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r15,%rdi
call rt_free
movabsq $0,%rax
movq -.F1805-8(%rbp),%rbx
movq -.F1805-16(%rbp),%r12
movq -.F1805-24(%rbp),%r13
movq -.F1805-32(%rbp),%r14
movq -.F1805-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1805-8(%rbp),%rbx
movq -.F1805-16(%rbp),%r12
movq -.F1805-24(%rbp),%r13
movq -.F1805-32(%rbp),%r14
movq -.F1805-40(%rbp),%r15
leave
ret
.set .F1805,272
.type rt_print_f64,@function
rt_print_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F1870,%rsp
subq $16,%rsp
movq %rbx,-.F1870-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
call rt_new
movq %rax,%rbx
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
call rt_fmt_f64
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1871
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt102
call rt_pushb
jmp .Lopt103
.Lopt102:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt103:
jmp .L1872
.L1871:
.L1872:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_pack
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movabsq $1,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1873
call rt_abort
jmp .L1874
.L1873:
.L1874:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1870-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1870-8(%rbp),%rbx
leave
ret
.set .F1870,48
.type rt_f32_round,@function
rt_f32_round:
pushq %rbp
movq %rsp,%rbp
subq $.F1875,%rsp
subq $48,%rsp
movq %rbx,-.F1875-8(%rbp)
movq %r12,-.F1875-16(%rbp)
movq %r13,-.F1875-24(%rbp)
movq %r14,-.F1875-32(%rbp)
movq %r15,-.F1875-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F1875(%rbp),%rdi
movq $.F1875/8-1,%rcx
xorl %eax,%eax
rep stosq
movabsq $9223372036854775808,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
movq %rax,%r15
movq -8(%rbp),%rdi
movabsq $4503599627370496,%rsi
call rt_div
movq %rax,-16(%rbp)
andq $2047,%rax
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
cmpq $2047,%rax
jne .L1876
movq -8(%rbp),%rax
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
jmp .L1877
.L1876:
.L1877:
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L1878
movq %r15,%rax
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
jmp .L1879
.L1878:
.L1879:
movabsq $4503599627370495,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
movq %rax,-40(%rbp)
movabsq $4503599627370496,%rcx
addq %rcx,%rax
jnc .L1880
call rt_abort
.L1880:
movq %rax,-48(%rbp)
movq $29,-56(%rbp)
movq -24(%rbp),%rax
cmpq $897,%rax
jae .L1881
movq -24(%rbp),%rcx
movabsq $926,%rax
subq %rcx,%rax
jnc .L1883
call rt_abort
.L1883:
movq %rax,-56(%rbp)
jmp .L1882
.L1881:
.L1882:
movq -56(%rbp),%rcx
movabsq $53,%rax
cmpq %rcx,%rax
jae .L1884
movq %r15,%rax
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
jmp .L1885
.L1884:
.L1885:
movq -56(%rbp),%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1886
call rt_abort
.L1886:
movq -48(%rbp),%rax
shrq %cl,%rax
movq %rax,-64(%rbp)
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1887
call rt_abort
.L1887:
movq -64(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
subq %rcx,%rax
jnc .L1888
call rt_abort
.L1888:
movq %rax,-72(%rbp)
movq -56(%rbp),%rax
subq $1,%rax
jnc .L1889
call rt_abort
.L1889:
movq %rax,-80(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1890
call rt_abort
.L1890:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,-88(%rbp)
movq -64(%rbp),%rax
movq %rax,%r12
movq -88(%rbp),%rax
movq -72(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-96(%rbp)
movq -88(%rbp),%rcx
movq -72(%rbp),%rax
cmpq %rcx,%rax
sete %al
movzbq %al,%rax
movq %rax,-104(%rbp)
movq -64(%rbp),%rax
andq $1,%rax
movq %rax,-112(%rbp)
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
addq %rcx,%rax
jnc .L1891
call rt_abort
.L1891:
testq %rax,%rax
jz .L1892
movq %r12,%rax
addq $1,%rax
jnc .L1894
call rt_abort
.L1894:
movq %rax,%r12
jmp .L1893
.L1892:
.L1893:
cmpq $0,%r12
jne .L1895
movq %r15,%rax
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
jmp .L1896
.L1895:
.L1896:
movq $0,%rbx
.L1897:
movq %rbx,%rax
addq $1,%rax
jnc .L1899
call rt_abort
.L1899:
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1900
call rt_abort
.L1900:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,%r14
movq %r12,%rax
addq $1,%rax
jnc .L1901
call rt_abort
.L1901:
movq %rax,%rcx
cmpq %rcx,%r14
jae .L1898
movq %rbx,%rax
addq $1,%rax
jnc .L1902
call rt_abort
.L1902:
movq %rax,%rbx
jmp .L1897
.L1898:
movq -24(%rbp),%rax
subq $52,%rax
jnc .L1903
call rt_abort
.L1903:
movq -56(%rbp),%rcx
addq %rcx,%rax
jnc .L1904
call rt_abort
.L1904:
addq %rbx,%rax
jnc .L1905
call rt_abort
.L1905:
movq %rax,-120(%rbp)
movq %rax,%rcx
movabsq $1150,%rax
cmpq %rcx,%rax
jae .L1906
movabsq $9218868437227405312,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1908
call rt_abort
.L1908:
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
jmp .L1907
.L1906:
.L1907:
movabsq $4503599627370496,%rcx
movq -120(%rbp),%rax
mulq %rcx
jnc .L1909
call rt_abort
.L1909:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1910
call rt_abort
.L1910:
movq %rax,-128(%rbp)
movabsq $52,%rax
subq %rbx,%rax
jnc .L1911
call rt_abort
.L1911:
movq %rax,-136(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1912
call rt_abort
.L1912:
movq %r12,%rax
shlq %cl,%rax
movq %rax,-144(%rbp)
movabsq $4503599627370496,%rcx
subq %rcx,%rax
jnc .L1913
call rt_abort
.L1913:
movq %rax,%rcx
movq -128(%rbp),%rax
addq %rcx,%rax
jnc .L1914
call rt_abort
.L1914:
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1875-8(%rbp),%rbx
movq -.F1875-16(%rbp),%r12
movq -.F1875-24(%rbp),%r13
movq -.F1875-32(%rbp),%r14
movq -.F1875-40(%rbp),%r15
leave
ret
.set .F1875,144
.type rt_f32_from_int,@function
rt_f32_from_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1915,%rsp
subq $48,%rsp
movq %rbx,-.F1915-8(%rbp)
movq %r12,-.F1915-16(%rbp)
movq %r13,-.F1915-24(%rbp)
movq %r14,-.F1915-32(%rbp)
movq %r15,-.F1915-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r14,%rbx
movq $0,-24(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1916:
movq %rax,-32(%rbp)
movabsq $1,%rcx
andq $1,%rax
movq %rax,-40(%rbp)
movq %r14,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i90
xorq %rax,%rax
jmp .Lret_i90
.Lret_i90:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1917
movq $1,-24(%rbp)
movabsq $0,%rax
subq %r14,%rax
movq %rax,%rbx
jmp .L1918
.L1917:
.L1918:
movq $0,%r12
.L1919:
movq %rbx,%rcx
movabsq $9007199254740991,%rax
cmpq %rbx,%rax
jae .L1920
movabsq $1,%rcx
movq %rbx,%rax
andq $1,%rax
movq %rax,%r13
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
testq %r13,%r13
jz .L1921
movq %rbx,%rax
orq $1,%rax
movq %rax,%rbx
jmp .L1922
.L1921:
.L1922:
movq %r12,%rax
addq $1,%rax
jnc .L1923
call rt_abort
.L1923:
movq %rax,%r12
jmp .L1919
.L1920:
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq %rax,%r15
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
cmpq $0,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1924
movabsq $4503599627370496,%rcx
movq %r12,%rax
mulq %rcx
jnc .L1926
call rt_abort
.L1926:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1927
call rt_abort
.L1927:
movq %rax,%r15
jmp .L1925
.L1924:
.L1925:
movq %r15,%rdi
call rt_f32_round
movq %rax,-56(%rbp)
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1928
movq -56(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775808,%rcx
movq %r8,%rax
xorq %rcx,%rax
jmp .Lret_i91
xorq %rax,%rax
jmp .Lret_i91
.Lret_i91:
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
jmp .L1929
.L1928:
.L1929:
movq -56(%rbp),%rax
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
.set .F1915,64
.type rt_fmt_f32,@function
rt_fmt_f32:
pushq %rbp
movq %rsp,%rbp
subq $.F1930,%rsp
subq $48,%rsp
movq %rbx,-.F1930-8(%rbp)
movq %r12,-.F1930-16(%rbp)
movq %r13,-.F1930-24(%rbp)
movq %r14,-.F1930-32(%rbp)
movq %r15,-.F1930-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq %rsi,%r13
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq %r13,%rax
movq %r13,%rcx
movq %r13,%xmm0
movq %r13,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1931
movq %rbx,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
jmp .L1932
.L1931:
.L1932:
movq %r13,%rcx
movabsq $9223372036854775807,%rax
cmpq %r13,%rax
jae .L1933
movq %rbx,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt104
call rt_pushb
jmp .Lopt105
.Lopt104:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt105:
jmp .L1934
.L1933:
.L1934:
movq %r13,%rdi
movabsq $4503599627370496,%rsi
call rt_div
movq %rax,-32(%rbp)
andq $2047,%rax
movq %rax,%r12
movabsq $4503599627370495,%rcx
movq %r13,%rax
andq %rcx,%rax
movq %rax,%r15
cmpq $2047,%r12
jne .L1935
movq %rbx,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
jmp .L1936
.L1935:
.L1936:
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq %rax,-40(%rbp)
movq %r15,%rax
cmpq $0,%r15
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1937
movq %rbx,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt106
call rt_pushb
jmp .Lopt107
.Lopt106:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt107:
movabsq $0,%rax
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
jmp .L1938
.L1937:
.L1938:
movabsq $896,%rax
cmpq %r12,%rax
jae .L1939
movabsq $896,%rcx
movq %r12,%rax
subq $896,%rax
jnc .L1941
call rt_abort
.L1941:
movq %rax,%r14
movq %r15,%rdi
movabsq $536870912,%rsi
call rt_div
movq %rax,-48(%rbp)
movq %rax,-56(%rbp)
addq $8388608,%rax
jnc .L1942
call rt_abort
.L1942:
movq %rax,-64(%rbp)
cmpq $150,%r14
jae .L1943
movabsq $150,%rax
subq %r14,%rax
jnc .L1945
call rt_abort
.L1945:
movq %rax,-72(%rbp)
movq -48(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-80(%rbp)
movabsq $1,%rax
cmpq %r14,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
andq %rcx,%rax
movq %rbx,%rdi
movq -64(%rbp),%rsi
movq -72(%rbp),%rdx
movabsq $1,%rcx
movq %rax,%r8
call rt_fmt_shortest
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
jmp .L1944
.L1943:
.L1944:
movq %r14,%rax
subq $150,%rax
jnc .L1946
call rt_abort
.L1946:
movq %rax,-88(%rbp)
movq -48(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rbx,%rdi
movq -64(%rbp),%rsi
movq -88(%rbp),%rdx
movabsq $0,%rcx
movq %rax,%r8
call rt_fmt_shortest
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
jmp .L1940
.L1939:
.L1940:
movabsq $4503599627370496,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1947
call rt_abort
.L1947:
movq %rax,-96(%rbp)
movabsq $926,%rax
subq %r12,%rax
jnc .L1948
call rt_abort
.L1948:
movq %rax,-104(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1949
call rt_abort
.L1949:
movq -96(%rbp),%rax
shrq %cl,%rax
movq %rax,-112(%rbp)
movq %rbx,%rdi
movq %rax,%rsi
movabsq $149,%rdx
movabsq $1,%rcx
movabsq $0,%r8
call rt_fmt_shortest
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1930-8(%rbp),%rbx
movq -.F1930-16(%rbp),%r12
movq -.F1930-24(%rbp),%r13
movq -.F1930-32(%rbp),%r14
movq -.F1930-40(%rbp),%r15
leave
ret
.set .F1930,112
.type rt_print_f32,@function
rt_print_f32:
pushq %rbp
movq %rsp,%rbp
subq $.F1950,%rsp
subq $16,%rsp
movq %rbx,-.F1950-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
call rt_new
movq %rax,%rbx
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
call rt_fmt_f32
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1951
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt108
call rt_pushb
jmp .Lopt109
.Lopt108:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt109:
jmp .L1952
.L1951:
.L1952:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_pack
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movabsq $1,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1953
call rt_abort
jmp .L1954
.L1953:
.L1954:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1950-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1950-8(%rbp),%rbx
leave
ret
.set .F1950,48
.type rt_char_from,@function
rt_char_from:
pushq %rbp
movq %rsp,%rbp
subq $.F1955,%rsp
subq $16,%rsp
movq %rbx,-.F1955-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $1114111,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movabsq $55295,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $57344,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1956
call rt_abort
.L1956:
testq %rax,%rax
jz .L1957
call rt_abort
jmp .L1958
.L1957:
.L1958:
movq %rbx,%rax
movq -.F1955-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1955-8(%rbp),%rbx
leave
ret
.set .F1955,32
.type rt_print_char,@function
rt_print_char:
pushq %rbp
movq %rsp,%rbp
subq $.F1959,%rsp
subq $16,%rsp
movq %rbx,-.F1959-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
call rt_new
movq %rax,%rbx
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
call rt_push_utf8
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1960
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt110
call rt_pushb
jmp .Lopt111
.Lopt110:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt111:
jmp .L1961
.L1960:
.L1961:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_pack
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movabsq $1,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1962
call rt_abort
jmp .L1963
.L1962:
.L1963:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1959-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1959-8(%rbp),%rbx
leave
ret
.set .F1959,48
.type rt_char_upper,@function
rt_char_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F1964,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $1,%rsi
call rt_case_map
leave
ret
xorq %rax,%rax
leave
ret
.set .F1964,16
.type rt_char_lower,@function
rt_char_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F1965,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $0,%rsi
call rt_case_map
leave
ret
xorq %rax,%rax
leave
ret
.set .F1965,16
.type rt_char_is_upper,@function
rt_char_is_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F1966,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $0,%rsi
call rt_case_map
movq -8(%rbp),%rcx
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1966,16
.type rt_char_is_lower,@function
rt_char_is_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F1967,%rsp
subq $16,%rsp
movq %rbx,-.F1967-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rdi
movabsq $1,%rsi
call rt_case_map
cmpq %rbx,%rax
setne %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
cmpq $223,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1968
call rt_abort
.L1968:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $312,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1969
call rt_abort
.L1969:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $329,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L1970
call rt_abort
.L1970:
movq -.F1967-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1967-8(%rbp),%rbx
leave
ret
.set .F1967,32
.type rt_char_is_alpha,@function
rt_char_is_alpha:
pushq %rbp
movq %rsp,%rbp
subq $.F1971,%rsp
subq $16,%rsp
movq %rbx,-.F1971-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %rbx,%rdi
call rt_char_is_upper
movq %rax,-16(%rbp)
movq %rbx,%rdi
call rt_char_is_lower
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1972
call rt_abort
.L1972:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $170,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1973
call rt_abort
.L1973:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $186,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L1974
call rt_abort
.L1974:
movq %rax,-40(%rbp)
movabsq $19967,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
cmpq $40960,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L1975
call rt_abort
.L1975:
movq -.F1971-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1971-8(%rbp),%rbx
leave
ret
.set .F1971,48
.type rt_char_is_digit,@function
rt_char_is_digit:
pushq %rbp
movq %rsp,%rbp
subq $.F1976,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $47,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
cmpq $58,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
andq %rcx,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1976,16
.type rt_char_is_alnum,@function
rt_char_is_alnum:
pushq %rbp
movq %rsp,%rbp
subq $.F1977,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_char_is_alpha
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $47,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r9
movq %r8,%rax
cmpq $58,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq %r9,%rax
andq %rcx,%rax
jmp .Lret_i92
xorq %rax,%rax
jmp .Lret_i92
.Lret_i92:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1978
call rt_abort
.L1978:
leave
ret
xorq %rax,%rax
leave
ret
.set .F1977,16
.type rt_char_is_space,@function
rt_char_is_space:
pushq %rbp
movq %rsp,%rbp
subq $.F1979,%rsp
subq $16,%rsp
movq %rbx,-.F1979-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movabsq $8,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
cmpq $14,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
andq %rcx,%rax
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $32,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1980
call rt_abort
.L1980:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $133,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L1981
call rt_abort
.L1981:
movq %rax,-40(%rbp)
movq %rbx,%rax
cmpq $160,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L1982
call rt_abort
.L1982:
movq %rax,-48(%rbp)
movq %rbx,%rax
cmpq $5760,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L1983
call rt_abort
.L1983:
movq %rax,-56(%rbp)
movabsq $8191,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movq %rbx,%rax
cmpq $8203,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -64(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L1984
call rt_abort
.L1984:
movq %rax,-72(%rbp)
movq %rbx,%rax
cmpq $8232,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L1985
call rt_abort
.L1985:
movq %rax,-80(%rbp)
movq %rbx,%rax
cmpq $8233,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L1986
call rt_abort
.L1986:
movq %rax,-88(%rbp)
movq %rbx,%rax
cmpq $8239,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L1987
call rt_abort
.L1987:
movq %rax,-96(%rbp)
movq %rbx,%rax
cmpq $8287,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
addq %rcx,%rax
jnc .L1988
call rt_abort
.L1988:
movq %rax,-104(%rbp)
movq %rbx,%rax
cmpq $12288,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
addq %rcx,%rax
jnc .L1989
call rt_abort
.L1989:
movq -.F1979-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1979-8(%rbp),%rbx
leave
ret
.set .F1979,112
.type rt_char_is_ascii,@function
rt_char_is_ascii:
pushq %rbp
movq %rsp,%rbp
subq $.F1990,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
cmpq $128,%rax
setb %al
movzbq %al,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1990,16
.type rt_char_len_utf8,@function
rt_char_len_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F1991,%rsp
subq $16,%rsp
movq %rbx,-.F1991-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
cmpq $128,%rbx
jae .L1992
movabsq $1,%rax
movq -.F1991-8(%rbp),%rbx
leave
ret
jmp .L1993
.L1992:
.L1993:
cmpq $2048,%rbx
jae .L1994
movabsq $2,%rax
movq -.F1991-8(%rbp),%rbx
leave
ret
jmp .L1995
.L1994:
.L1995:
cmpq $65536,%rbx
jae .L1996
movabsq $3,%rax
movq -.F1991-8(%rbp),%rbx
leave
ret
jmp .L1997
.L1996:
.L1997:
movabsq $4,%rax
movq -.F1991-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1991-8(%rbp),%rbx
leave
ret
.set .F1991,16
.type rt_seq_chars,@function
rt_seq_chars:
pushq %rbp
movq %rsp,%rbp
subq $.F1998,%rsp
subq $48,%rsp
movq %rbx,-.F1998-8(%rbp)
movq %r12,-.F1998-16(%rbp)
movq %r13,-.F1998-24(%rbp)
movq %r14,-.F1998-32(%rbp)
movq %r15,-.F1998-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq $0,-120(%rbp)
movq $0,-128(%rbp)
call rt_new
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq $0,%r14
.L1999:
movq -24(%rbp),%rcx
cmpq %rcx,%r14
jae .L2000
movq -8(%rbp),%rdi
movq %r14,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt112
call rt_abort
.Lopt112:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rbx
movq %rax,%r13
movq $0,-32(%rbp)
cmpq $128,%rax
jae .L2001
movq $0,%r12
jmp .L2002
.L2001:
movq %rbx,%rax
andq $224,%rax
movq %rax,-40(%rbp)
cmpq $192,%rax
jne .L2003
movq $1,%r12
movq %rbx,%rax
andq $31,%rax
movq %rax,%r13
movq $128,-32(%rbp)
jmp .L2004
.L2003:
movq %rbx,%rax
andq $240,%rax
movq %rax,-48(%rbp)
cmpq $224,%rax
jne .L2005
movq $2,%r12
movq %rbx,%rax
andq $15,%rax
movq %rax,%r13
movq $2048,-32(%rbp)
jmp .L2006
.L2005:
movq %rbx,%rax
andq $248,%rax
movq %rax,-56(%rbp)
cmpq $240,%rax
jne .L2007
movq $3,%r12
movq %rbx,%rax
andq $7,%rax
movq %rax,%r13
movq $65536,-32(%rbp)
jmp .L2008
.L2007:
movq $99,%r12
.L2008:
.L2006:
.L2004:
.L2002:
cmpq $99,%r12
jne .L2009
movq -16(%rbp),%rdi
movabsq $65533,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt113
call rt_push
jmp .Lopt114
.Lopt113:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt114:
movq %r14,%rax
addq $1,%rax
jnc .L2011
call rt_abort
.L2011:
movq %rax,%r14
jmp .L1999
jmp .L2010
.L2009:
.L2010:
movq $1,-64(%rbp)
movq $1,%r15
.L2012:
movq %r12,%rax
addq $1,%rax
jnc .L2014
call rt_abort
.L2014:
movq %rax,%rcx
cmpq %rcx,%r15
jae .L2013
movq %r14,%rax
addq %r15,%rax
jnc .L2015
call rt_abort
.L2015:
movq %rax,-72(%rbp)
addq $1,%rax
jnc .L2016
call rt_abort
.L2016:
movq %rax,%rcx
movq -24(%rbp),%rax
cmpq %rcx,%rax
jae .L2017
movq $0,-64(%rbp)
jmp .L2013
jmp .L2018
.L2017:
.L2018:
movq %r14,%rax
addq %r15,%rax
jnc .L2019
call rt_abort
.L2019:
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt115
call rt_abort
.Lopt115:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-80(%rbp)
movq %rax,-88(%rbp)
andq $192,%rax
movq %rax,-96(%rbp)
cmpq $128,%rax
je .L2020
movq $0,-64(%rbp)
jmp .L2013
jmp .L2021
.L2020:
.L2021:
movabsq $64,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2022
call rt_abort
.L2022:
movq %rax,-104(%rbp)
movq -80(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
addq %rcx,%rax
jnc .L2023
call rt_abort
.L2023:
movq %rax,%r13
movq %r15,%rax
addq $1,%rax
jnc .L2024
call rt_abort
.L2024:
movq %rax,%r15
jmp .L2012
.L2013:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L2025
movq %r13,%rax
movq -32(%rbp),%rcx
cmpq %rcx,%r13
setb %al
movzbq %al,%rax
movq %rax,-112(%rbp)
movabsq $1114111,%rax
cmpq %r13,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L2027
call rt_abort
.L2027:
movq %rax,-120(%rbp)
movabsq $55295,%rax
cmpq %r13,%rax
setb %al
movzbq %al,%rax
movq %rax,-128(%rbp)
movq %r13,%rax
cmpq $57344,%r13
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -128(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -120(%rbp),%rax
addq %rcx,%rax
jnc .L2028
call rt_abort
.L2028:
testq %rax,%rax
jz .L2029
movq $0,-64(%rbp)
jmp .L2030
.L2029:
.L2030:
jmp .L2026
.L2025:
.L2026:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L2031
movq -16(%rbp),%rdi
movq %r13,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt116
call rt_push
jmp .Lopt117
.Lopt116:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt117:
movq %r12,%rax
addq $1,%rax
jnc .L2033
call rt_abort
.L2033:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2034
call rt_abort
.L2034:
movq %rax,%r14
jmp .L2032
.L2031:
movq -16(%rbp),%rdi
movabsq $65533,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt118
call rt_push
jmp .Lopt119
.Lopt118:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt119:
movq %r14,%rax
addq $1,%rax
jnc .L2035
call rt_abort
.L2035:
movq %rax,%r14
.L2032:
jmp .L1999
.L2000:
movq -16(%rbp),%rax
movq -.F1998-8(%rbp),%rbx
movq -.F1998-16(%rbp),%r12
movq -.F1998-24(%rbp),%r13
movq -.F1998-32(%rbp),%r14
movq -.F1998-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1998-8(%rbp),%rbx
movq -.F1998-16(%rbp),%r12
movq -.F1998-24(%rbp),%r13
movq -.F1998-32(%rbp),%r14
movq -.F1998-40(%rbp),%r15
leave
ret
.set .F1998,128
.type rt_big_half,@function
rt_big_half:
pushq %rbp
movq %rsp,%rbp
subq $.F2036,%rsp
subq $48,%rsp
movq %rbx,-.F2036-8(%rbp)
movq %r12,-.F2036-16(%rbp)
movq %r13,-.F2036-24(%rbp)
movq %r14,-.F2036-32(%rbp)
movq %r15,-.F2036-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq $0,-16(%rbp)
movq $0,%r13
movq $48,%rbx
.L2037:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2038
movq %rbx,%rax
subq $1,%rax
jnc .L2039
call rt_abort
.L2039:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2040
call rt_abort
.L2040:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2041
call rt_abort
.L2041:
movq (%rax),%rax
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2042
call rt_abort
.L2042:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2043
call rt_abort
.L2043:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2044
call rt_abort
.L2044:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2045
call rt_abort
.L2045:
movq %rax,-16(%rbp)
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq -16(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L2046:
movq %rdx,%r13
jmp .L2037
.L2038:
movq %r13,%rax
movq -.F2036-8(%rbp),%rbx
movq -.F2036-16(%rbp),%r12
movq -.F2036-24(%rbp),%r13
movq -.F2036-32(%rbp),%r14
movq -.F2036-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2036-8(%rbp),%rbx
movq -.F2036-16(%rbp),%r12
movq -.F2036-24(%rbp),%r13
movq -.F2036-32(%rbp),%r14
movq -.F2036-40(%rbp),%r15
leave
ret
.set .F2036,16
.type rt_big_is_zero,@function
rt_big_is_zero:
pushq %rbp
movq %rsp,%rbp
subq $.F2047,%rsp
subq $32,%rsp
movq %rbx,-.F2047-8(%rbp)
movq %r12,-.F2047-16(%rbp)
movq %r13,-.F2047-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq $0,%rbx
.L2048:
cmpq $48,%rbx
jae .L2049
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2050
call rt_abort
.L2050:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L2051
call rt_abort
.L2051:
movq (%rax),%rax
cmpq $0,%rax
je .L2052
movabsq $0,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
leave
ret
jmp .L2053
.L2052:
.L2053:
movq %rbx,%rax
addq $1,%rax
jnc .L2054
call rt_abort
.L2054:
movq %rax,%rbx
jmp .L2048
.L2049:
movabsq $1,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
leave
ret
.set .F2047,16
.type rt_fmt_f64_fixed,@function
rt_fmt_f64_fixed:
pushq %rbp
movq %rsp,%rbp
subq $.F2055,%rsp
subq $48,%rsp
movq %rbx,-.F2055-8(%rbp)
movq %r12,-.F2055-16(%rbp)
movq %r13,-.F2055-24(%rbp)
movq %r14,-.F2055-32(%rbp)
movq %r15,-.F2055-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
leaq -.F2055(%rbp),%rdi
movq $.F2055/8-3,%rcx
xorl %eax,%eax
rep stosq
movq -16(%rbp),%rax
movq %rax,%rcx
movq %rax,%xmm0
movq %rax,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L2056
movq %r15,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F2055-8(%rbp),%rbx
movq -.F2055-16(%rbp),%r12
movq -.F2055-24(%rbp),%r13
movq -.F2055-32(%rbp),%r14
movq -.F2055-40(%rbp),%r15
leave
ret
jmp .L2057
.L2056:
.L2057:
movq -16(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
jae .L2058
movq %r15,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt120
call rt_pushb
jmp .Lopt121
.Lopt120:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt121:
jmp .L2059
.L2058:
.L2059:
movq -16(%rbp),%rdi
movabsq $4503599627370496,%rsi
call rt_div
movq %rax,-40(%rbp)
andq $2047,%rax
movq %rax,-48(%rbp)
movabsq $4503599627370495,%rcx
movq -16(%rbp),%rax
andq %rcx,%rax
movq %rax,-56(%rbp)
movq -48(%rbp),%rax
cmpq $2047,%rax
jne .L2060
movq %r15,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F2055-8(%rbp),%rbx
movq -.F2055-16(%rbp),%r12
movq -.F2055-24(%rbp),%r13
movq -.F2055-32(%rbp),%r14
movq -.F2055-40(%rbp),%r15
leave
ret
jmp .L2061
.L2060:
.L2061:
movq -56(%rbp),%rax
movq %rax,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
jne .L2062
movq $1074,-72(%rbp)
movq $1,-80(%rbp)
jmp .L2063
.L2062:
movabsq $4503599627370496,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L2064
call rt_abort
.L2064:
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
cmpq $1075,%rax
jae .L2065
movq -48(%rbp),%rcx
movabsq $1075,%rax
subq %rcx,%rax
jnc .L2067
call rt_abort
.L2067:
movq %rax,-72(%rbp)
movq $1,-80(%rbp)
jmp .L2066
.L2065:
movabsq $1075,%rcx
movq -48(%rbp),%rax
subq $1075,%rax
jnc .L2068
call rt_abort
.L2068:
movq %rax,-72(%rbp)
.L2066:
.L2063:
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_big
movq %rax,-88(%rbp)
movq $0,%rbx
.L2069:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2070
movq -88(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq %rbx,%rax
addq $1,%rax
jnc .L2071
call rt_abort
.L2071:
movq %rax,%rbx
jmp .L2069
.L2070:
movabsq $0,%rcx
movq -80(%rbp),%rax
cmpq $0,%rax
jne .L2072
movq -72(%rbp),%rax
movq -88(%rbp),%rdi
movq %rax,%rsi
call rt_big_shift
jmp .L2073
.L2072:
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,%rbx
.L2074:
movq -72(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2075
movq -96(%rbp),%rax
testq %rax,%rax
jz .L2076
movq $1,-104(%rbp)
jmp .L2077
.L2076:
.L2077:
movq -88(%rbp),%rax
movq %rax,%rdi
call rt_big_half
movq %rax,-96(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2078
call rt_abort
.L2078:
movq %rax,%rbx
jmp .L2074
.L2075:
movq -104(%rbp),%rax
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,-112(%rbp)
movq -88(%rbp),%rax
movq (%rax),%rax
movq %rax,-120(%rbp)
andq $1,%rax
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L2079
call rt_abort
.L2079:
movq %rax,-128(%rbp)
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2080
movabsq $1,%rdi
call rt_big
movq %rax,-136(%rbp)
movq -88(%rbp),%rdi
movq %rdi,%rsi
movq %rax,%rdx
call rt_big_add
movq -136(%rbp),%rax
movq %rax,%rdi
call rt_free
jmp .L2081
.L2080:
.L2081:
.L2073:
call rt_new
movq %rax,%r14
movq $47,-144(%rbp)
.L2082:
movq -144(%rbp),%rcx
movabsq $0,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-152(%rbp)
movabsq $8,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L2084
call rt_abort
.L2084:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2085
call rt_abort
.L2085:
movq (%rax),%rax
movq %rax,-160(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2083
movq -144(%rbp),%rax
subq $1,%rax
jnc .L2086
call rt_abort
.L2086:
movq %rax,-144(%rbp)
jmp .L2082
.L2083:
movabsq $8,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L2087
call rt_abort
.L2087:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2088
call rt_abort
.L2088:
movq (%rax),%rax
movq %rax,-168(%rbp)
movq %r14,%rdi
movq %rax,%rsi
call rt_fmt_num
movq -144(%rbp),%rax
movq %rax,%rbx
.L2089:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2090
movq %rbx,%rax
subq $1,%rax
jnc .L2091
call rt_abort
.L2091:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2092
call rt_abort
.L2092:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2093
call rt_abort
.L2093:
movq (%rax),%rax
movq %rax,-176(%rbp)
movq $100000000,%r12
.L2094:
movq %r12,%rcx
movabsq $0,%rax
cmpq %r12,%rax
jae .L2095
movq -176(%rbp),%rdi
movq %r12,%rsi
call rt_div
movabsq $10,%rcx
testq %rcx,%rcx
jnz .L2096
call rt_abort
.L2096:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L2097
call rt_abort
.L2097:
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt122
call rt_pushb
jmp .Lopt123
.Lopt122:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt123:
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
jmp .L2094
.L2095:
jmp .L2089
.L2090:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-184(%rbp)
movq %rax,-192(%rbp)
movq -24(%rbp),%rax
addq $1,%rax
jnc .L2098
call rt_abort
.L2098:
movq %rax,%rcx
movq -192(%rbp),%rax
cmpq %rcx,%rax
jae .L2099
movq -24(%rbp),%rax
addq $1,%rax
jnc .L2101
call rt_abort
.L2101:
movq -184(%rbp),%rcx
subq %rcx,%rax
jnc .L2102
call rt_abort
.L2102:
movq %rax,-200(%rbp)
movq %r15,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt124
call rt_pushb
jmp .Lopt125
.Lopt124:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt125:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2103
movq %r15,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt126
call rt_pushb
jmp .Lopt127
.Lopt126:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt127:
jmp .L2104
.L2103:
.L2104:
movq -200(%rbp),%rax
subq $1,%rax
jnc .L2105
call rt_abort
.L2105:
movq %rax,-200(%rbp)
.L2106:
movq -200(%rbp),%rcx
movabsq $0,%rax
cmpq %rcx,%rax
jae .L2107
movq %r15,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt128
call rt_pushb
jmp .Lopt129
.Lopt128:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt129:
movq -200(%rbp),%rax
subq $1,%rax
jnc .L2108
call rt_abort
.L2108:
movq %rax,-200(%rbp)
jmp .L2106
.L2107:
movq $0,%rbx
.L2109:
movq -184(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2110
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt130
call rt_abort
.Lopt130:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r15,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt131
call rt_pushb
jmp .Lopt132
.Lopt131:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt132:
movq %rbx,%rax
addq $1,%rax
jnc .L2111
call rt_abort
.L2111:
movq %rax,%rbx
jmp .L2109
.L2110:
jmp .L2100
.L2099:
movq $0,%rbx
.L2112:
movq -184(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2113
movq -184(%rbp),%rax
movq -24(%rbp),%rcx
subq %rcx,%rax
jnc .L2114
call rt_abort
.L2114:
movq %rax,%rcx
movq %rbx,%rax
cmpq %rcx,%rbx
sete %al
movzbq %al,%rax
movq %rax,-208(%rbp)
movq -24(%rbp),%rax
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -208(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2115
movq %r15,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt133
call rt_pushb
jmp .Lopt134
.Lopt133:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt134:
jmp .L2116
.L2115:
.L2116:
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt135
call rt_abort
.Lopt135:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r15,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt136
call rt_pushb
jmp .Lopt137
.Lopt136:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt137:
movq %rbx,%rax
addq $1,%rax
jnc .L2117
call rt_abort
.L2117:
movq %rax,%rbx
jmp .L2112
.L2113:
.L2100:
movq %r14,%rdi
call rt_drop_seq
movq -88(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F2055-8(%rbp),%rbx
movq -.F2055-16(%rbp),%r12
movq -.F2055-24(%rbp),%r13
movq -.F2055-32(%rbp),%r14
movq -.F2055-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2055-8(%rbp),%rbx
movq -.F2055-16(%rbp),%r12
movq -.F2055-24(%rbp),%r13
movq -.F2055-32(%rbp),%r14
movq -.F2055-40(%rbp),%r15
leave
ret
.set .F2055,208
.type rt_print_acc,@function
rt_print_acc:
pushq %rbp
movq %rsp,%rbp
subq $.F2118,%rsp
subq $16,%rsp
movq %rbx,-.F2118-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2119
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt138
call rt_pushb
jmp .Lopt139
.Lopt138:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt139:
jmp .L2120
.L2119:
.L2120:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq %rbx,%rdi
call rt_pack
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movabsq $1,%rdi
movq -32(%rbp),%rsi
movq %rax,%rdx
call rt_write_all
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L2121
call rt_abort
jmp .L2122
.L2121:
.L2122:
movq -32(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2118-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2118-8(%rbp),%rbx
leave
ret
.set .F2118,48
.type f_host_exit,@function
f_host_exit:
pushq %rbp
movq %rsp,%rbp
subq $.F2123,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
andq $255,%rax
movq %rax,-16(%rbp)
movabsq $231,%rdi
movq -16(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2123,16
.type rt_fmt_value,@function
rt_fmt_value:
pushq %rbp
movq %rsp,%rbp
subq $.F2124,%rsp
subq $48,%rsp
movq %rbx,-.F2124-8(%rbp)
movq %r12,-.F2124-16(%rbp)
movq %r13,-.F2124-24(%rbp)
movq %r14,-.F2124-32(%rbp)
movq %r15,-.F2124-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq %rsi,%r14
movq %rdx,-24(%rbp)
leaq -.F2124(%rbp),%rdi
movq $.F2124/8-3,%rcx
xorl %eax,%eax
rep stosq
movabsq $1,%rcx
movq -24(%rbp),%rax
cmpq $1,%rax
jne .L2125
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_num
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2126
.L2125:
.L2126:
movabsq $2,%rcx
movq -24(%rbp),%rax
cmpq $2,%rax
jne .L2127
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_bool
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2128
.L2127:
.L2128:
movabsq $3,%rcx
movq -24(%rbp),%rax
cmpq $3,%rax
jne .L2129
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_f64
movq $1,-40(%rbp)
movq -32(%rbp),%rax
movq %rax,%r15
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-48(%rbp)
.L2131:
movq -48(%rbp),%rcx
cmpq %rcx,%r15
jae .L2132
movq %rbx,%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt140
call rt_abort
.Lopt140:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
cmpq $46,%rax
sete %al
movzbq %al,%rax
movq %rax,-72(%rbp)
movq -56(%rbp),%rax
cmpq $101,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2133
call rt_abort
.L2133:
movq %rax,-80(%rbp)
movq -56(%rbp),%rax
cmpq $110,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L2134
call rt_abort
.L2134:
movq %rax,-88(%rbp)
movq -56(%rbp),%rax
cmpq $78,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2135
call rt_abort
.L2135:
testq %rax,%rax
jz .L2136
movq $0,-40(%rbp)
jmp .L2137
.L2136:
.L2137:
movq %r15,%rax
addq $1,%rax
jnc .L2138
call rt_abort
.L2138:
movq %rax,%r15
jmp .L2131
.L2132:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2139
movq %rbx,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt141
call rt_pushb
jmp .Lopt142
.Lopt141:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt142:
movq %rbx,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt143
call rt_pushb
jmp .Lopt144
.Lopt143:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt144:
jmp .L2140
.L2139:
.L2140:
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2130
.L2129:
.L2130:
movq -24(%rbp),%rax
cmpq $4,%rax
jne .L2141
movq %rbx,%rdi
movabsq $34,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt145
call rt_pushb
jmp .Lopt146
.Lopt145:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt146:
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_seq
movq %rbx,%rdi
movabsq $34,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt147
call rt_pushb
jmp .Lopt148
.Lopt147:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt148:
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2142
.L2141:
.L2142:
movq -24(%rbp),%rax
cmpq $6,%rax
jne .L2143
movq %rbx,%rdi
movabsq $39,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt149
call rt_pushb
jmp .Lopt150
.Lopt149:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt150:
movq %rbx,%rdi
movq %r14,%rsi
call rt_push_utf8
movq %rbx,%rdi
movabsq $39,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt151
call rt_pushb
jmp .Lopt152
.Lopt151:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt152:
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2144
.L2143:
.L2144:
movabsq $7,%rcx
movq -24(%rbp),%rax
cmpq $7,%rax
jne .L2145
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-96(%rbp)
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_f32
movq $1,-104(%rbp)
movq -96(%rbp),%rax
movq %rax,-112(%rbp)
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-120(%rbp)
.L2147:
movq -112(%rbp),%rax
movq -120(%rbp),%rcx
cmpq %rcx,%rax
jae .L2148
movq -112(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt153
call rt_abort
.Lopt153:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-128(%rbp)
movq %rax,-136(%rbp)
cmpq $46,%rax
sete %al
movzbq %al,%rax
movq %rax,-144(%rbp)
movq -128(%rbp),%rax
cmpq $101,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -144(%rbp),%rax
addq %rcx,%rax
jnc .L2149
call rt_abort
.L2149:
movq %rax,-152(%rbp)
movq -128(%rbp),%rax
cmpq $110,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
addq %rcx,%rax
jnc .L2150
call rt_abort
.L2150:
movq %rax,-160(%rbp)
movq -128(%rbp),%rax
cmpq $78,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -160(%rbp),%rax
addq %rcx,%rax
jnc .L2151
call rt_abort
.L2151:
testq %rax,%rax
jz .L2152
movq $0,-104(%rbp)
jmp .L2153
.L2152:
.L2153:
movq -112(%rbp),%rax
addq $1,%rax
jnc .L2154
call rt_abort
.L2154:
movq %rax,-112(%rbp)
jmp .L2147
.L2148:
movq -104(%rbp),%rax
testq %rax,%rax
jz .L2155
movq %rbx,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt154
call rt_pushb
jmp .Lopt155
.Lopt154:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt155:
movq %rbx,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt156
call rt_pushb
jmp .Lopt157
.Lopt156:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt157:
jmp .L2156
.L2155:
.L2156:
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2146
.L2145:
.L2146:
movq -24(%rbp),%rax
andq $4095,%rax
movq %rax,-168(%rbp)
movabsq $5,%rcx
cmpq $5,%rax
jne .L2157
movq -24(%rbp),%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,-176(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-184(%rbp)
movq %rbx,%rdi
movabsq $91,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt158
call rt_pushb
jmp .Lopt159
.Lopt158:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt159:
movq $0,%r12
.L2159:
movq -184(%rbp),%rcx
cmpq %rcx,%r12
jae .L2160
movabsq $0,%rcx
cmpq $0,%r12
je .L2161
movq %rbx,%rdi
movabsq $44,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt160
call rt_pushb
jmp .Lopt161
.Lopt160:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt161:
movq %rbx,%rdi
movabsq $32,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt162
call rt_pushb
jmp .Lopt163
.Lopt162:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt163:
jmp .L2162
.L2161:
.L2162:
movq %r14,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i93
call rt_abort
.Lopt15_i93:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i93
xorq %rax,%rax
jmp .Lret_i93
.Lret_i93:
movq %rax,-192(%rbp)
movq -176(%rbp),%rax
movq %rbx,%rdi
movq -192(%rbp),%rsi
movq %rax,%rdx
call rt_fmt_value
movq %r12,%rax
addq $1,%rax
jnc .L2163
call rt_abort
.L2163:
movq %rax,%r12
jmp .L2159
.L2160:
movq %rbx,%rdi
movabsq $93,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt164
call rt_pushb
jmp .Lopt165
.Lopt164:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt165:
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2158
.L2157:
.L2158:
movq -24(%rbp),%rax
andq $4095,%rax
movq %rax,-200(%rbp)
movabsq $8,%rcx
cmpq $8,%rax
jne .L2164
movq -24(%rbp),%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,-208(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-216(%rbp)
movq %rbx,%rdi
movabsq $91,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt166
call rt_pushb
jmp .Lopt167
.Lopt166:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt167:
movq $0,%r13
.L2166:
movq -216(%rbp),%rcx
cmpq %rcx,%r13
jae .L2167
movabsq $0,%rcx
cmpq $0,%r13
je .L2168
movq %rbx,%rdi
movabsq $44,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt168
call rt_pushb
jmp .Lopt169
.Lopt168:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt169:
movq %rbx,%rdi
movabsq $32,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt170
call rt_pushb
jmp .Lopt171
.Lopt170:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt171:
jmp .L2169
.L2168:
.L2169:
movq %r14,%rdi
movq %r13,%rsi
call rt_at4
movq %rax,-224(%rbp)
movq -208(%rbp),%rax
movq -224(%rbp),%rdi
movq %rax,%rsi
call rt_narrow_decode
movq %rax,-232(%rbp)
movq -208(%rbp),%rax
movq %rbx,%rdi
movq -232(%rbp),%rsi
movq %rax,%rdx
call rt_fmt_value
movq %r13,%rax
addq $1,%rax
jnc .L2170
call rt_abort
.L2170:
movq %rax,%r13
jmp .L2166
.L2167:
movq %rbx,%rdi
movabsq $93,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt172
call rt_pushb
jmp .Lopt173
.Lopt172:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt173:
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2165
.L2164:
.L2165:
movq -24(%rbp),%rcx
movabsq $1023,%rax
cmpq %rcx,%rax
jae .L2171
movabsq $1024,%rcx
movq -24(%rbp),%rax
subq $1024,%rax
jnc .L2173
call rt_abort
.L2173:
movq %rbx,%rdi
movq %r14,%rsi
movq %rax,%rdx
call rt_fmt_int
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
jmp .L2172
.L2171:
.L2172:
call rt_abort
movabsq $0,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2124-8(%rbp),%rbx
movq -.F2124-16(%rbp),%r12
movq -.F2124-24(%rbp),%r13
movq -.F2124-32(%rbp),%r14
movq -.F2124-40(%rbp),%r15
leave
ret
.set .F2124,240
.type f_host_remove,@function
f_host_remove:
pushq %rbp
movq %rsp,%rbp
subq $.F2174,%rsp
subq $16,%rsp
movq %rbx,-.F2174-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,%rbx
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
cmpq $0,%rbx
jne .L2175
movabsq $22,%rax
movq -.F2174-8(%rbp),%rbx
leave
ret
jmp .L2176
.L2175:
.L2176:
movq $0,-24(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2177
movq $512,-24(%rbp)
jmp .L2178
.L2177:
.L2178:
movabsq $0,%rax
subq $100,%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movabsq $263,%rdi
movq -32(%rbp),%rsi
movq %rbx,%rdx
movq %rax,%rcx
call rt_syscall
movq %rax,-40(%rbp)
movq %rbx,%rdi
call rt_free
movq -40(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i94
xorq %rax,%rax
jmp .Lret_i94
.Lret_i94:
testq %rax,%rax
jz .L2179
movq -40(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F2174-8(%rbp),%rbx
leave
ret
jmp .L2180
.L2179:
.L2180:
movabsq $0,%rax
movq -.F2174-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2174-8(%rbp),%rbx
leave
ret
.set .F2174,48
.type f_host_create_dir,@function
f_host_create_dir:
pushq %rbp
movq %rsp,%rbp
subq $.F2181,%rsp
subq $16,%rsp
movq %rbx,-.F2181-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_cstr
movq %rax,%rbx
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
cmpq $0,%rbx
jne .L2182
movabsq $22,%rax
movq -.F2181-8(%rbp),%rbx
leave
ret
jmp .L2183
.L2182:
.L2183:
movabsq $0,%rax
subq $100,%rax
movq %rax,-16(%rbp)
movabsq $258,%rdi
movq %rax,%rsi
movq %rbx,%rdx
movabsq $493,%rcx
call rt_syscall
movq %rax,-24(%rbp)
movq %rbx,%rdi
call rt_free
movq -24(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i95
xorq %rax,%rax
jmp .Lret_i95
.Lret_i95:
testq %rax,%rax
jz .L2184
movq -24(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F2181-8(%rbp),%rbx
leave
ret
jmp .L2185
.L2184:
.L2185:
movabsq $0,%rax
movq -.F2181-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2181-8(%rbp),%rbx
leave
ret
.set .F2181,32
.type rt_fmt_pad,@function
rt_fmt_pad:
pushq %rbp
movq %rsp,%rbp
subq $.F2186,%rsp
subq $48,%rsp
movq %rbx,-.F2186-8(%rbp)
movq %r12,-.F2186-16(%rbp)
movq %r13,-.F2186-24(%rbp)
movq %r14,-.F2186-32(%rbp)
movq %r15,-.F2186-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r14
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq %r8,-40(%rbp)
movq %r9,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,-112(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%r15
movq $0,-56(%rbp)
movq $0,%rbx
.L2187:
cmpq %r15,%rbx
jae .L2188
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt174
call rt_abort
.Lopt174:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-64(%rbp)
andq $192,%rax
movq %rax,-72(%rbp)
cmpq $128,%rax
je .L2189
movq -56(%rbp),%rax
addq $1,%rax
jnc .L2191
call rt_abort
.L2191:
movq %rax,-56(%rbp)
jmp .L2190
.L2189:
.L2190:
movq %rbx,%rax
addq $1,%rax
jnc .L2192
call rt_abort
.L2192:
movq %rax,%rbx
jmp .L2187
.L2188:
movq $0,-80(%rbp)
movq -56(%rbp),%rax
movq -24(%rbp),%rcx
cmpq %rcx,%rax
jae .L2193
movq -24(%rbp),%rax
movq -56(%rbp),%rcx
subq %rcx,%rax
jnc .L2195
call rt_abort
.L2195:
movq %rax,-80(%rbp)
jmp .L2194
.L2193:
.L2194:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2196
movq $0,%rbx
cmpq $0,%r15
je .L2198
movq %r14,%rdi
movabsq $0,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt175
call rt_abort
.Lopt175:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-88(%rbp)
cmpq $45,%rax
jne .L2200
movq %r13,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt176
call rt_pushb
jmp .Lopt177
.Lopt176:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt177:
movq $1,%rbx
jmp .L2201
.L2200:
.L2201:
jmp .L2199
.L2198:
.L2199:
movq $0,-96(%rbp)
.L2202:
movq -96(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jae .L2203
movq %r13,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt178
call rt_pushb
jmp .Lopt179
.Lopt178:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt179:
movq -96(%rbp),%rax
addq $1,%rax
jnc .L2204
call rt_abort
.L2204:
movq %rax,-96(%rbp)
jmp .L2202
.L2203:
.L2205:
movq %r15,%rcx
cmpq %r15,%rbx
jae .L2206
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt180
call rt_abort
.Lopt180:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt181
call rt_pushb
jmp .Lopt182
.Lopt181:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt182:
movq %rbx,%rax
addq $1,%rax
jnc .L2207
call rt_abort
.L2207:
movq %rax,%rbx
jmp .L2205
.L2206:
movq %r14,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2186-8(%rbp),%rbx
movq -.F2186-16(%rbp),%r12
movq -.F2186-24(%rbp),%r13
movq -.F2186-32(%rbp),%r14
movq -.F2186-40(%rbp),%r15
leave
ret
jmp .L2197
.L2196:
.L2197:
movq $0,-104(%rbp)
movq -32(%rbp),%rax
cmpq $2,%rax
jne .L2208
movq -80(%rbp),%rax
movq %rax,-104(%rbp)
jmp .L2209
.L2208:
.L2209:
movabsq $3,%rcx
movq -32(%rbp),%rax
cmpq $3,%rax
jne .L2210
movq -80(%rbp),%rdi
movabsq $2,%rsi
call rt_div
movq %rax,-104(%rbp)
jmp .L2211
.L2210:
.L2211:
movq -80(%rbp),%rax
movq -104(%rbp),%rcx
subq %rcx,%rax
jnc .L2212
call rt_abort
.L2212:
movq %rax,-112(%rbp)
movq $0,%r12
.L2213:
movq -104(%rbp),%rcx
cmpq %rcx,%r12
jae .L2214
movq -48(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_push_char
movq %r12,%rax
addq $1,%rax
jnc .L2215
call rt_abort
.L2215:
movq %rax,%r12
jmp .L2213
.L2214:
movq $0,%rbx
.L2216:
cmpq %r15,%rbx
jae .L2217
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt183
call rt_abort
.Lopt183:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt184
call rt_pushb
jmp .Lopt185
.Lopt184:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt185:
movq %rbx,%rax
addq $1,%rax
jnc .L2218
call rt_abort
.L2218:
movq %rax,%rbx
jmp .L2216
.L2217:
movq $0,%r12
.L2219:
movq -112(%rbp),%rcx
cmpq %rcx,%r12
jae .L2220
movq -48(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_push_char
movq %r12,%rax
addq $1,%rax
jnc .L2221
call rt_abort
.L2221:
movq %rax,%r12
jmp .L2219
.L2220:
movq %r14,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2186-8(%rbp),%rbx
movq -.F2186-16(%rbp),%r12
movq -.F2186-24(%rbp),%r13
movq -.F2186-32(%rbp),%r14
movq -.F2186-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2186-8(%rbp),%rbx
movq -.F2186-16(%rbp),%r12
movq -.F2186-24(%rbp),%r13
movq -.F2186-32(%rbp),%r14
movq -.F2186-40(%rbp),%r15
leave
ret
.set .F2186,112
.type rt_push_char,@function
rt_push_char:
pushq %rbp
movq %rsp,%rbp
subq $.F2222,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt186
call rt_pushb
jmp .Lopt187
.Lopt186:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt187:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2222,16
.type rt_seq_cmp,@function
rt_seq_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2223,%rsp
subq $48,%rsp
movq %rbx,-.F2223-8(%rbp)
movq %r12,-.F2223-16(%rbp)
movq %r13,-.F2223-24(%rbp)
movq %r14,-.F2223-32(%rbp)
movq %r15,-.F2223-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq $0,%rbx
movq $1,%r12
.L2224:
movq %rbx,%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,%r15
movq %rbx,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq %r15,%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2225
movq -16(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt188
call rt_abort
.Lopt188:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt189
call rt_abort
.Lopt189:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r14
cmpq %r14,%r13
je .L2226
cmpq %r14,%r13
jae .L2228
movq $0,%r12
jmp .L2229
.L2228:
movq $2,%r12
.L2229:
jmp .L2225
jmp .L2227
.L2226:
.L2227:
movq %rbx,%rax
addq $1,%rax
jnc .L2230
call rt_abort
.L2230:
movq %rax,%rbx
jmp .L2224
.L2225:
cmpq $1,%r12
jne .L2231
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2233
movq $0,%r12
jmp .L2234
.L2233:
.L2234:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2235
movq $2,%r12
jmp .L2236
.L2235:
.L2236:
jmp .L2232
.L2231:
.L2232:
movq -8(%rbp),%rax
cmpq $258,%rax
jne .L2237
movq %r12,%rax
cmpq $1,%r12
sete %al
movzbq %al,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
jmp .L2238
.L2237:
.L2238:
movq -8(%rbp),%rax
cmpq $259,%rax
jne .L2239
movq %r12,%rax
cmpq $1,%r12
setne %al
movzbq %al,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
jmp .L2240
.L2239:
.L2240:
movq -8(%rbp),%rax
cmpq $60,%rax
jne .L2241
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
jmp .L2242
.L2241:
.L2242:
movq -8(%rbp),%rax
cmpq $62,%rax
jne .L2243
movq %r12,%rax
cmpq $2,%r12
sete %al
movzbq %al,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
jmp .L2244
.L2243:
.L2244:
movq -8(%rbp),%rax
cmpq $269,%rax
jne .L2245
movq %r12,%rax
cmpq $2,%r12
setne %al
movzbq %al,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
jmp .L2246
.L2245:
.L2246:
movabsq $270,%rcx
movq -8(%rbp),%rax
cmpq $270,%rax
jne .L2247
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
jmp .L2248
.L2247:
.L2248:
call rt_abort
movabsq $0,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2223-8(%rbp),%rbx
movq -.F2223-16(%rbp),%r12
movq -.F2223-24(%rbp),%r13
movq -.F2223-32(%rbp),%r14
movq -.F2223-40(%rbp),%r15
leave
ret
.set .F2223,48
.type rt_vec_cmp,@function
rt_vec_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2249,%rsp
subq $48,%rsp
movq %rbx,-.F2249-8(%rbp)
movq %r12,-.F2249-16(%rbp)
movq %r13,-.F2249-24(%rbp)
movq %r14,-.F2249-32(%rbp)
movq %r15,-.F2249-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq $0,%rbx
movq $1,%r12
.L2250:
movq %rbx,%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,%r15
movq %rbx,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq %r15,%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2251
movq -16(%rbp),%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i96
call rt_abort
.Lopt15_i96:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i96
xorq %rax,%rax
jmp .Lret_i96
.Lret_i96:
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i97
call rt_abort
.Lopt15_i97:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i97
xorq %rax,%rax
jmp .Lret_i97
.Lret_i97:
movq %rax,%r14
cmpq %r14,%r13
je .L2252
cmpq %r14,%r13
jae .L2254
movq $0,%r12
jmp .L2255
.L2254:
movq $2,%r12
.L2255:
jmp .L2251
jmp .L2253
.L2252:
.L2253:
movq %rbx,%rax
addq $1,%rax
jnc .L2256
call rt_abort
.L2256:
movq %rax,%rbx
jmp .L2250
.L2251:
movabsq $1,%rcx
cmpq $1,%r12
jne .L2257
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2259
movq $0,%r12
jmp .L2260
.L2259:
.L2260:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2261
movq $2,%r12
jmp .L2262
.L2261:
.L2262:
jmp .L2258
.L2257:
.L2258:
movq -8(%rbp),%rdi
movq %r12,%rsi
call rt_order_result
movq -.F2249-8(%rbp),%rbx
movq -.F2249-16(%rbp),%r12
movq -.F2249-24(%rbp),%r13
movq -.F2249-32(%rbp),%r14
movq -.F2249-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2249-8(%rbp),%rbx
movq -.F2249-16(%rbp),%r12
movq -.F2249-24(%rbp),%r13
movq -.F2249-32(%rbp),%r14
movq -.F2249-40(%rbp),%r15
leave
ret
.set .F2249,48
.type rt_order_result,@function
rt_order_result:
pushq %rbp
movq %rsp,%rbp
subq $.F2263,%rsp
subq $16,%rsp
movq %rbx,-.F2263-8(%rbp)
movq %r12,-.F2263-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
cmpq $258,%rbx
jne .L2264
movq %r12,%rax
cmpq $1,%r12
sete %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
jmp .L2265
.L2264:
.L2265:
cmpq $259,%rbx
jne .L2266
movq %r12,%rax
cmpq $1,%r12
setne %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
jmp .L2267
.L2266:
.L2267:
cmpq $60,%rbx
jne .L2268
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
jmp .L2269
.L2268:
.L2269:
cmpq $62,%rbx
jne .L2270
movq %r12,%rax
cmpq $2,%r12
sete %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
jmp .L2271
.L2270:
.L2271:
cmpq $269,%rbx
jne .L2272
movq %r12,%rax
cmpq $2,%r12
setne %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
jmp .L2273
.L2272:
.L2273:
movabsq $270,%rcx
cmpq $270,%rbx
jne .L2274
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
jmp .L2275
.L2274:
.L2275:
call rt_abort
movabsq $0,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
leave
ret
.set .F2263,16
.type rt_concat,@function
rt_concat:
pushq %rbp
movq %rsp,%rbp
subq $.F2276,%rsp
subq $48,%rsp
movq %rbx,-.F2276-8(%rbp)
movq %r12,-.F2276-16(%rbp)
movq %r13,-.F2276-24(%rbp)
movq %r14,-.F2276-32(%rbp)
movq %r15,-.F2276-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
call rt_new
movq %rax,%r12
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r15
movq $0,%rbx
.L2277:
cmpq %r15,%rbx
jae .L2278
movq %r13,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt190
call rt_abort
.Lopt190:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt191
call rt_pushb
jmp .Lopt192
.Lopt191:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt192:
movq %rbx,%rax
addq $1,%rax
jnc .L2279
call rt_abort
.L2279:
movq %rax,%rbx
jmp .L2277
.L2278:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq $0,%rbx
.L2280:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2281
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt193
call rt_abort
.Lopt193:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt194
call rt_pushb
jmp .Lopt195
.Lopt194:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt195:
movq %rbx,%rax
addq $1,%rax
jnc .L2282
call rt_abort
.L2282:
movq %rax,%rbx
jmp .L2280
.L2281:
movq %r12,%rax
movq -.F2276-8(%rbp),%rbx
movq -.F2276-16(%rbp),%r12
movq -.F2276-24(%rbp),%r13
movq -.F2276-32(%rbp),%r14
movq -.F2276-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2276-8(%rbp),%rbx
movq -.F2276-16(%rbp),%r12
movq -.F2276-24(%rbp),%r13
movq -.F2276-32(%rbp),%r14
movq -.F2276-40(%rbp),%r15
leave
ret
.set .F2276,32
.type rt_concat_text,@function
rt_concat_text:
pushq %rbp
movq %rsp,%rbp
subq $.F2283,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_concat
movq %rax,-24(%rbp)
movq %rax,%rdi
call rt_utf8
movq -24(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2283,32
.type rt_seq_match,@function
rt_seq_match:
pushq %rbp
movq %rsp,%rbp
subq $.F2284,%rsp
subq $48,%rsp
movq %rbx,-.F2284-8(%rbp)
movq %r12,-.F2284-16(%rbp)
movq %r13,-.F2284-24(%rbp)
movq %r14,-.F2284-32(%rbp)
movq %r15,-.F2284-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r14
movq %rdx,%r15
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq %r14,%rax
movq -32(%rbp),%rcx
addq %rcx,%rax
jnc .L2285
call rt_abort
.L2285:
movq %rax,%rcx
movq -40(%rbp),%rax
cmpq %rcx,%rax
jae .L2286
movabsq $0,%rax
movq -.F2284-8(%rbp),%rbx
movq -.F2284-16(%rbp),%r12
movq -.F2284-24(%rbp),%r13
movq -.F2284-32(%rbp),%r14
movq -.F2284-40(%rbp),%r15
leave
ret
jmp .L2287
.L2286:
.L2287:
movq $0,%rbx
.L2288:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2289
movq %r14,%rax
addq %rbx,%rax
jnc .L2290
call rt_abort
.L2290:
movq %r13,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt196
call rt_abort
.Lopt196:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq %r15,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt197
call rt_abort
.Lopt197:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r12
je .L2291
movabsq $0,%rax
movq -.F2284-8(%rbp),%rbx
movq -.F2284-16(%rbp),%r12
movq -.F2284-24(%rbp),%r13
movq -.F2284-32(%rbp),%r14
movq -.F2284-40(%rbp),%r15
leave
ret
jmp .L2292
.L2291:
.L2292:
movq %rbx,%rax
addq $1,%rax
jnc .L2293
call rt_abort
.L2293:
movq %rax,%rbx
jmp .L2288
.L2289:
movabsq $1,%rax
movq -.F2284-8(%rbp),%rbx
movq -.F2284-16(%rbp),%r12
movq -.F2284-24(%rbp),%r13
movq -.F2284-32(%rbp),%r14
movq -.F2284-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2284-8(%rbp),%rbx
movq -.F2284-16(%rbp),%r12
movq -.F2284-24(%rbp),%r13
movq -.F2284-32(%rbp),%r14
movq -.F2284-40(%rbp),%r15
leave
ret
.set .F2284,48
.type rt_seq_contains,@function
rt_seq_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F2294,%rsp
subq $48,%rsp
movq %rbx,-.F2294-8(%rbp)
movq %r12,-.F2294-16(%rbp)
movq %r13,-.F2294-24(%rbp)
movq %r14,-.F2294-32(%rbp)
movq %r15,-.F2294-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r15
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r15
jae .L2295
movabsq $0,%rax
movq -.F2294-8(%rbp),%rbx
movq -.F2294-16(%rbp),%r12
movq -.F2294-24(%rbp),%r13
movq -.F2294-32(%rbp),%r14
movq -.F2294-40(%rbp),%r15
leave
ret
jmp .L2296
.L2295:
.L2296:
movq $0,%rbx
.L2297:
movq %r15,%rax
movq -24(%rbp),%rcx
subq %rcx,%rax
jnc .L2299
call rt_abort
.L2299:
addq $1,%rax
jnc .L2300
call rt_abort
.L2300:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2298
movq %r13,%rdi
movq %rbx,%rsi
movq %r14,%rdx
call rt_seq_match
testq %rax,%rax
jz .L2301
movabsq $1,%rax
movq -.F2294-8(%rbp),%rbx
movq -.F2294-16(%rbp),%r12
movq -.F2294-24(%rbp),%r13
movq -.F2294-32(%rbp),%r14
movq -.F2294-40(%rbp),%r15
leave
ret
jmp .L2302
.L2301:
.L2302:
movq %rbx,%rax
addq $1,%rax
jnc .L2303
call rt_abort
.L2303:
movq %rax,%rbx
jmp .L2297
.L2298:
movabsq $0,%rax
movq -.F2294-8(%rbp),%rbx
movq -.F2294-16(%rbp),%r12
movq -.F2294-24(%rbp),%r13
movq -.F2294-32(%rbp),%r14
movq -.F2294-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2294-8(%rbp),%rbx
movq -.F2294-16(%rbp),%r12
movq -.F2294-24(%rbp),%r13
movq -.F2294-32(%rbp),%r14
movq -.F2294-40(%rbp),%r15
leave
ret
.set .F2294,32
.type rt_seq_starts,@function
rt_seq_starts:
pushq %rbp
movq %rsp,%rbp
subq $.F2304,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movabsq $0,%rsi
movq %rax,%rdx
call rt_seq_match
leave
ret
xorq %rax,%rax
leave
ret
.set .F2304,16
.type rt_seq_ends,@function
rt_seq_ends:
pushq %rbp
movq %rsp,%rbp
subq $.F2305,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2306
movabsq $0,%rax
leave
ret
jmp .L2307
.L2306:
.L2307:
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
subq %rcx,%rax
jnc .L2308
call rt_abort
.L2308:
movq %rax,-40(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_seq_match
leave
ret
xorq %rax,%rax
leave
ret
.set .F2305,48
.type rt_case_map,@function
rt_case_map:
pushq %rbp
movq %rsp,%rbp
subq $.F2309,%rsp
subq $16,%rsp
movq %rbx,-.F2309-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
leaq -.F2309(%rbp),%rdi
movq $.F2309/8-2,%rcx
xorl %eax,%eax
rep stosq
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2310
cmpq $940,%rbx
jne .L2312
movabsq $902,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2313
.L2312:
.L2313:
cmpq $941,%rbx
jne .L2314
movabsq $904,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2315
.L2314:
.L2315:
cmpq $942,%rbx
jne .L2316
movabsq $905,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2317
.L2316:
.L2317:
cmpq $943,%rbx
jne .L2318
movabsq $906,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2319
.L2318:
.L2319:
cmpq $972,%rbx
jne .L2320
movabsq $908,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2321
.L2320:
.L2321:
cmpq $973,%rbx
jne .L2322
movabsq $910,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2323
.L2322:
.L2323:
cmpq $974,%rbx
jne .L2324
movabsq $911,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2325
.L2324:
.L2325:
movabsq $96,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $123,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2326
movq %rbx,%rax
subq $32,%rax
jnc .L2328
call rt_abort
.L2328:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2327
.L2326:
.L2327:
movabsq $223,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $255,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
andq %rcx,%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
cmpq $247,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2329
movq %rbx,%rax
subq $32,%rax
jnc .L2331
call rt_abort
.L2331:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2330
.L2329:
.L2330:
cmpq $255,%rbx
jne .L2332
movabsq $376,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2333
.L2332:
.L2333:
movabsq $255,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
cmpq $384,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2334
movq %rbx,%rax
cmpq $311,%rbx
setb %al
movzbq %al,%rax
movq %rax,-56(%rbp)
movabsq $312,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movq %rbx,%rax
cmpq $329,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -64(%rbp),%rax
andq %rcx,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L2336
call rt_abort
.L2336:
movq %rax,-72(%rbp)
movabsq $329,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2337
call rt_abort
.L2337:
testq %rax,%rax
jz .L2338
movq %rbx,%rax
cmpq $311,%rbx
setb %al
movzbq %al,%rax
movq %rax,-80(%rbp)
movabsq $329,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L2340
call rt_abort
.L2340:
movq %rax,-88(%rbp)
movq %rbx,%rax
andq $1,%rax
movq %rax,-96(%rbp)
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
andq %rcx,%rax
movq %rax,-104(%rbp)
movq %rbx,%rax
cmpq $305,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
andq %rcx,%rax
movq %rax,-112(%rbp)
movq %rbx,%rax
cmpq $383,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -112(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2341
movq %rbx,%rax
subq $1,%rax
jnc .L2343
call rt_abort
.L2343:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2342
.L2341:
.L2342:
movabsq $312,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-120(%rbp)
movq %rbx,%rax
cmpq $329,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -120(%rbp),%rax
andq %rcx,%rax
movq %rax,-128(%rbp)
movq %rbx,%rax
andq $1,%rax
movq %rax,-136(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -128(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2344
movq %rbx,%rax
subq $1,%rax
jnc .L2346
call rt_abort
.L2346:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2345
.L2344:
.L2345:
jmp .L2339
.L2338:
.L2339:
jmp .L2335
.L2334:
.L2335:
movabsq $944,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-144(%rbp)
movq %rbx,%rax
cmpq $970,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -144(%rbp),%rax
andq %rcx,%rax
movq %rax,-152(%rbp)
movq %rbx,%rax
cmpq $962,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2347
movq %rbx,%rax
subq $32,%rax
jnc .L2349
call rt_abort
.L2349:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2348
.L2347:
.L2348:
cmpq $962,%rbx
jne .L2350
movabsq $931,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2351
.L2350:
.L2351:
movabsq $1071,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-160(%rbp)
movq %rbx,%rax
cmpq $1104,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -160(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2352
movq %rbx,%rax
subq $32,%rax
jnc .L2354
call rt_abort
.L2354:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2353
.L2352:
.L2353:
movabsq $1103,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-168(%rbp)
movq %rbx,%rax
cmpq $1120,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -168(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2355
movq %rbx,%rax
subq $80,%rax
jnc .L2357
call rt_abort
.L2357:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2356
.L2355:
.L2356:
movq %rbx,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2311
.L2310:
.L2311:
cmpq $902,%rbx
jne .L2358
movabsq $940,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2359
.L2358:
.L2359:
cmpq $904,%rbx
jne .L2360
movabsq $941,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2361
.L2360:
.L2361:
cmpq $905,%rbx
jne .L2362
movabsq $942,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2363
.L2362:
.L2363:
cmpq $906,%rbx
jne .L2364
movabsq $943,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2365
.L2364:
.L2365:
cmpq $908,%rbx
jne .L2366
movabsq $972,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2367
.L2366:
.L2367:
cmpq $910,%rbx
jne .L2368
movabsq $973,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2369
.L2368:
.L2369:
cmpq $911,%rbx
jne .L2370
movabsq $974,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2371
.L2370:
.L2371:
movabsq $64,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-176(%rbp)
movq %rbx,%rax
cmpq $91,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -176(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2372
movq %rbx,%rax
addq $32,%rax
jnc .L2374
call rt_abort
.L2374:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2373
.L2372:
.L2373:
movabsq $191,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-184(%rbp)
movq %rbx,%rax
cmpq $223,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -184(%rbp),%rax
andq %rcx,%rax
movq %rax,-192(%rbp)
movq %rbx,%rax
cmpq $215,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -192(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2375
movq %rbx,%rax
addq $32,%rax
jnc .L2377
call rt_abort
.L2377:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2376
.L2375:
.L2376:
cmpq $376,%rbx
jne .L2378
movabsq $255,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2379
.L2378:
.L2379:
movabsq $255,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-200(%rbp)
movq %rbx,%rax
cmpq $384,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -200(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2380
movq %rbx,%rax
cmpq $311,%rbx
setb %al
movzbq %al,%rax
movq %rax,-208(%rbp)
movabsq $329,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -208(%rbp),%rax
addq %rcx,%rax
jnc .L2382
call rt_abort
.L2382:
movq %rax,-216(%rbp)
movq %rbx,%rax
andq $1,%rax
movq %rax,-224(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -216(%rbp),%rax
andq %rcx,%rax
movq %rax,-232(%rbp)
movq %rbx,%rax
cmpq $304,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -232(%rbp),%rax
andq %rcx,%rax
movq %rax,-240(%rbp)
movq %rbx,%rax
cmpq $382,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -240(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2383
movq %rbx,%rax
addq $1,%rax
jnc .L2385
call rt_abort
.L2385:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2384
.L2383:
.L2384:
movabsq $312,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-248(%rbp)
movq %rbx,%rax
cmpq $329,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -248(%rbp),%rax
andq %rcx,%rax
movq %rax,-256(%rbp)
movq %rbx,%rax
andq $1,%rax
movq %rax,-264(%rbp)
cmpq $1,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -256(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2386
movq %rbx,%rax
addq $1,%rax
jnc .L2388
call rt_abort
.L2388:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2387
.L2386:
.L2387:
jmp .L2381
.L2380:
.L2381:
movabsq $912,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-272(%rbp)
movq %rbx,%rax
cmpq $940,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -272(%rbp),%rax
andq %rcx,%rax
movq %rax,-280(%rbp)
movq %rbx,%rax
cmpq $930,%rbx
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -280(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2389
movq %rbx,%rax
addq $32,%rax
jnc .L2391
call rt_abort
.L2391:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2390
.L2389:
.L2390:
movabsq $1039,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-288(%rbp)
movq %rbx,%rax
cmpq $1072,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -288(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2392
movq %rbx,%rax
addq $32,%rax
jnc .L2394
call rt_abort
.L2394:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2393
.L2392:
.L2393:
movabsq $1023,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,-296(%rbp)
movq %rbx,%rax
cmpq $1040,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -296(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2395
movq %rbx,%rax
addq $80,%rax
jnc .L2397
call rt_abort
.L2397:
movq -.F2309-8(%rbp),%rbx
leave
ret
jmp .L2396
.L2395:
.L2396:
movq %rbx,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2309-8(%rbp),%rbx
leave
ret
.set .F2309,304
.type rt_push_utf8,@function
rt_push_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F2398,%rsp
subq $16,%rsp
movq %rbx,-.F2398-8(%rbp)
movq %r12,-.F2398-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq %rsi,%rbx
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
cmpq $128,%rbx
jae .L2399
movq %r12,%rdi
movq %rbx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt198
call rt_pushb
jmp .Lopt199
.Lopt198:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt199:
movabsq $0,%rax
movq -.F2398-8(%rbp),%rbx
movq -.F2398-16(%rbp),%r12
leave
ret
jmp .L2400
.L2399:
.L2400:
movabsq $2048,%rcx
cmpq $2048,%rbx
jae .L2401
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,%rcx
movabsq $192,%rax
addq %rcx,%rax
jnc .L2403
call rt_abort
.L2403:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt200
call rt_pushb
jmp .Lopt201
.Lopt200:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt201:
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2404:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2405
call rt_abort
.L2405:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt202
call rt_pushb
jmp .Lopt203
.Lopt202:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt203:
movabsq $0,%rax
movq -.F2398-8(%rbp),%rbx
movq -.F2398-16(%rbp),%r12
leave
ret
jmp .L2402
.L2401:
.L2402:
movabsq $65536,%rcx
cmpq $65536,%rbx
jae .L2406
movq %rbx,%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,%rcx
movabsq $224,%rax
addq %rcx,%rax
jnc .L2408
call rt_abort
.L2408:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt204
call rt_pushb
jmp .Lopt205
.Lopt204:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt205:
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,-24(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2409:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2410
call rt_abort
.L2410:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt206
call rt_pushb
jmp .Lopt207
.Lopt206:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt207:
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2411:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2412
call rt_abort
.L2412:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt208
call rt_pushb
jmp .Lopt209
.Lopt208:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt209:
movabsq $0,%rax
movq -.F2398-8(%rbp),%rbx
movq -.F2398-16(%rbp),%r12
leave
ret
jmp .L2407
.L2406:
.L2407:
movq %rbx,%rdi
movabsq $262144,%rsi
call rt_div
movq %rax,%rcx
movabsq $240,%rax
addq %rcx,%rax
jnc .L2413
call rt_abort
.L2413:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt210
call rt_pushb
jmp .Lopt211
.Lopt210:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt211:
movq %rbx,%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,-32(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2414:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2415
call rt_abort
.L2415:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt212
call rt_pushb
jmp .Lopt213
.Lopt212:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt213:
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,-40(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2416:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2417
call rt_abort
.L2417:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt214
call rt_pushb
jmp .Lopt215
.Lopt214:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt215:
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2418:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2419
call rt_abort
.L2419:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt216
call rt_pushb
jmp .Lopt217
.Lopt216:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt217:
movabsq $0,%rax
movq -.F2398-8(%rbp),%rbx
movq -.F2398-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2398-8(%rbp),%rbx
movq -.F2398-16(%rbp),%r12
leave
ret
.set .F2398,48
.type rt_seq_case,@function
rt_seq_case:
pushq %rbp
movq %rsp,%rbp
subq $.F2420,%rsp
subq $48,%rsp
movq %rbx,-.F2420-8(%rbp)
movq %r12,-.F2420-16(%rbp)
movq %r13,-.F2420-24(%rbp)
movq %r14,-.F2420-32(%rbp)
movq %r15,-.F2420-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
call rt_new
movq %rax,%r13
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq $0,%rbx
.L2421:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2422
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt218
call rt_abort
.Lopt218:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq %rax,-32(%rbp)
movabsq $128,%rcx
cmpq $128,%rax
jae .L2423
movq %r12,%rdi
movq %r15,%rsi
call rt_case_map
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt219
call rt_pushb
jmp .Lopt220
.Lopt219:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt220:
movq %rbx,%rax
addq $1,%rax
jnc .L2425
call rt_abort
.L2425:
movq %rax,%rbx
jmp .L2424
.L2423:
movq %r12,%rax
andq $224,%rax
movq %rax,-40(%rbp)
cmpq $192,%rax
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2426
call rt_abort
.L2426:
movq -24(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2427
movq %rbx,%rax
addq $1,%rax
jnc .L2429
call rt_abort
.L2429:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt221
call rt_abort
.Lopt221:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
andq $192,%rax
movq %rax,-72(%rbp)
cmpq $128,%rax
jne .L2430
movq %r12,%rax
andq $31,%rax
movq %rax,-80(%rbp)
movabsq $64,%rcx
mulq %rcx
jnc .L2432
call rt_abort
.L2432:
movq %rax,-88(%rbp)
movq -56(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2433
call rt_abort
.L2433:
movq %rax,-96(%rbp)
movq -96(%rbp),%rdi
movq %r15,%rsi
call rt_case_map
movq %r13,%rdi
movq %rax,%rsi
call rt_push_utf8
movq %rbx,%rax
addq $2,%rax
jnc .L2434
call rt_abort
.L2434:
movq %rax,%rbx
jmp .L2431
.L2430:
movq %r13,%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt222
call rt_pushb
jmp .Lopt223
.Lopt222:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt223:
movq %rbx,%rax
addq $1,%rax
jnc .L2435
call rt_abort
.L2435:
movq %rax,%rbx
.L2431:
jmp .L2428
.L2427:
movq %r13,%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt224
call rt_pushb
jmp .Lopt225
.Lopt224:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt225:
movq %rbx,%rax
addq $1,%rax
jnc .L2436
call rt_abort
.L2436:
movq %rax,%rbx
.L2428:
.L2424:
jmp .L2421
.L2422:
movq %r13,%rax
movq -.F2420-8(%rbp),%rbx
movq -.F2420-16(%rbp),%r12
movq -.F2420-24(%rbp),%r13
movq -.F2420-32(%rbp),%r14
movq -.F2420-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2420-8(%rbp),%rbx
movq -.F2420-16(%rbp),%r12
movq -.F2420-24(%rbp),%r13
movq -.F2420-32(%rbp),%r14
movq -.F2420-40(%rbp),%r15
leave
ret
.set .F2420,96
.type rt_seq_upper,@function
rt_seq_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2437,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $1,%rsi
call rt_seq_case
leave
ret
xorq %rax,%rax
leave
ret
.set .F2437,16
.type rt_seq_lower,@function
rt_seq_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2438,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
movabsq $0,%rsi
call rt_seq_case
leave
ret
xorq %rax,%rax
leave
ret
.set .F2438,16
.type rt_space,@function
rt_space:
pushq %rbp
movq %rsp,%rbp
subq $.F2439,%rsp
subq $16,%rsp
movq %rbx,-.F2439-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
cmpq $32,%rbx
sete %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
cmpq $9,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L2440
call rt_abort
.L2440:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $10,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2441
call rt_abort
.L2441:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $13,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2442
call rt_abort
.L2442:
movq -.F2439-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2439-8(%rbp),%rbx
leave
ret
.set .F2439,32
.type rt_seq_trim,@function
rt_seq_trim:
pushq %rbp
movq %rsp,%rbp
subq $.F2443,%rsp
subq $48,%rsp
movq %rbx,-.F2443-8(%rbp)
movq %r12,-.F2443-16(%rbp)
movq %r13,-.F2443-24(%rbp)
movq %r14,-.F2443-32(%rbp)
movq %r15,-.F2443-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,%r12
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%rbx
.L2444:
movq %rbx,%rcx
cmpq %rbx,%r12
jae .L2445
movq %r14,%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt226
call rt_abort
.Lopt226:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rdi
call rt_space
cmpq $0,%rax
jne .L2446
jmp .L2445
jmp .L2447
.L2446:
.L2447:
movq %r12,%rax
addq $1,%rax
jnc .L2448
call rt_abort
.L2448:
movq %rax,%r12
jmp .L2444
.L2445:
.L2449:
movq %rbx,%rcx
cmpq %rbx,%r12
jae .L2450
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2451
call rt_abort
.L2451:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt227
call rt_abort
.Lopt227:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rdi
call rt_space
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2452
jmp .L2450
jmp .L2453
.L2452:
.L2453:
movq %rbx,%rax
subq $1,%rax
jnc .L2454
call rt_abort
.L2454:
movq %rax,%rbx
jmp .L2449
.L2450:
call rt_new
movq %rax,-24(%rbp)
movq %r12,%r13
.L2455:
cmpq %rbx,%r13
jae .L2456
movq %r14,%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt228
call rt_abort
.Lopt228:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt229
call rt_pushb
jmp .Lopt230
.Lopt229:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt230:
movq %r13,%rax
addq $1,%rax
jnc .L2457
call rt_abort
.L2457:
movq %rax,%r13
jmp .L2455
.L2456:
movq -24(%rbp),%rax
movq -.F2443-8(%rbp),%rbx
movq -.F2443-16(%rbp),%r12
movq -.F2443-24(%rbp),%r13
movq -.F2443-32(%rbp),%r14
movq -.F2443-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2443-8(%rbp),%rbx
movq -.F2443-16(%rbp),%r12
movq -.F2443-24(%rbp),%r13
movq -.F2443-32(%rbp),%r14
movq -.F2443-40(%rbp),%r15
leave
ret
.set .F2443,32
.type rt_seq_replace,@function
rt_seq_replace:
pushq %rbp
movq %rsp,%rbp
subq $.F2458,%rsp
subq $48,%rsp
movq %rbx,-.F2458-8(%rbp)
movq %r12,-.F2458-16(%rbp)
movq %r13,-.F2458-24(%rbp)
movq %r14,-.F2458-32(%rbp)
movq %r15,-.F2458-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,%r14
movq %rcx,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
call rt_new
movq %rax,%r13
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-48(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%r15
movq $0,%r12
.L2459:
movq -40(%rbp),%rcx
cmpq %rcx,%r12
jae .L2460
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %r12,%rsi
movq %rax,%rdx
call rt_seq_match
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2461
movq $0,%rbx
.L2463:
cmpq %r15,%rbx
jae .L2464
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt231
call rt_abort
.Lopt231:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt232
call rt_pushb
jmp .Lopt233
.Lopt232:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt233:
movq %rbx,%rax
addq $1,%rax
jnc .L2465
call rt_abort
.L2465:
movq %rax,%rbx
jmp .L2463
.L2464:
movq %r12,%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L2466
call rt_abort
.L2466:
movq %rax,%r12
jmp .L2462
.L2461:
movq -8(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt234
call rt_abort
.Lopt234:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt235
call rt_pushb
jmp .Lopt236
.Lopt235:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt236:
movq %r12,%rax
addq $1,%rax
jnc .L2467
call rt_abort
.L2467:
movq %rax,%r12
.L2462:
jmp .L2459
.L2460:
movq -32(%rbp),%rax
testq %rax,%rax
jz .L2468
movq %r13,%rdi
call rt_utf8
jmp .L2469
.L2468:
.L2469:
movq %r13,%rax
movq -.F2458-8(%rbp),%rbx
movq -.F2458-16(%rbp),%r12
movq -.F2458-24(%rbp),%r13
movq -.F2458-32(%rbp),%r14
movq -.F2458-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2458-8(%rbp),%rbx
movq -.F2458-16(%rbp),%r12
movq -.F2458-24(%rbp),%r13
movq -.F2458-32(%rbp),%r14
movq -.F2458-40(%rbp),%r15
leave
ret
.set .F2458,64
.type rt_seq_repeat,@function
rt_seq_repeat:
pushq %rbp
movq %rsp,%rbp
subq $.F2470,%rsp
subq $48,%rsp
movq %rbx,-.F2470-8(%rbp)
movq %r12,-.F2470-16(%rbp)
movq %r13,-.F2470-24(%rbp)
movq %r14,-.F2470-32(%rbp)
movq %r15,-.F2470-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r12
movq %rsi,-16(%rbp)
call rt_new
movq %rax,%r13
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r14
movq $0,%r15
.L2471:
movq -16(%rbp),%rcx
cmpq %rcx,%r15
jae .L2472
movq $0,%rbx
.L2473:
cmpq %r14,%rbx
jae .L2474
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt237
call rt_abort
.Lopt237:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt238
call rt_pushb
jmp .Lopt239
.Lopt238:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt239:
movq %rbx,%rax
addq $1,%rax
jnc .L2475
call rt_abort
.L2475:
movq %rax,%rbx
jmp .L2473
.L2474:
movq %r15,%rax
addq $1,%rax
jnc .L2476
call rt_abort
.L2476:
movq %rax,%r15
jmp .L2471
.L2472:
movq %r13,%rax
movq -.F2470-8(%rbp),%rbx
movq -.F2470-16(%rbp),%r12
movq -.F2470-24(%rbp),%r13
movq -.F2470-32(%rbp),%r14
movq -.F2470-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2470-8(%rbp),%rbx
movq -.F2470-16(%rbp),%r12
movq -.F2470-24(%rbp),%r13
movq -.F2470-32(%rbp),%r14
movq -.F2470-40(%rbp),%r15
leave
ret
.set .F2470,16
.type rt_seq_split,@function
rt_seq_split:
pushq %rbp
movq %rsp,%rbp
subq $.F2477,%rsp
subq $48,%rsp
movq %rbx,-.F2477-8(%rbp)
movq %r12,-.F2477-16(%rbp)
movq %r13,-.F2477-24(%rbp)
movq %r14,-.F2477-32(%rbp)
movq %r15,-.F2477-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
call rt_new
movq %rax,%r14
call rt_new
movq %rax,%rbx
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq $0,%r12
.L2478:
movq -32(%rbp),%rcx
cmpq %rcx,%r12
jae .L2479
movq %r15,%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt240
call rt_abort
.Lopt240:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r13
movq -16(%rbp),%rcx
cmpq %rcx,%rax
jne .L2480
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2482
movq %rbx,%rdi
call rt_utf8
jmp .L2483
.L2482:
.L2483:
movq %r14,%rdi
movq %rbx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt241
call rt_push
jmp .Lopt242
.Lopt241:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt242:
call rt_new
movq %rax,%rbx
jmp .L2481
.L2480:
movq %rbx,%rdi
movq %r13,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt243
call rt_pushb
jmp .Lopt244
.Lopt243:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt244:
.L2481:
movq %r12,%rax
addq $1,%rax
jnc .L2484
call rt_abort
.L2484:
movq %rax,%r12
jmp .L2478
.L2479:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2485
movq %rbx,%rdi
call rt_utf8
jmp .L2486
.L2485:
.L2486:
movq %r14,%rdi
movq %rbx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt245
call rt_push
jmp .Lopt246
.Lopt245:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt246:
movq %r14,%rax
movq -.F2477-8(%rbp),%rbx
movq -.F2477-16(%rbp),%r12
movq -.F2477-24(%rbp),%r13
movq -.F2477-32(%rbp),%r14
movq -.F2477-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2477-8(%rbp),%rbx
movq -.F2477-16(%rbp),%r12
movq -.F2477-24(%rbp),%r13
movq -.F2477-32(%rbp),%r14
movq -.F2477-40(%rbp),%r15
leave
ret
.set .F2477,32
.type rt_load32,@function
rt_load32:
pushq %rbp
movq %rsp,%rbp
subq $.F2487,%rsp
subq $16,%rsp
movq %rbx,-.F2487-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %rbx,%rax
movzbq (%rax),%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2488
call rt_abort
.L2488:
movzbq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $8,%rax
jnc .L2489
call rt_abort
.L2489:
movabsq $8,%rcx
movq -24(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
orq %rcx,%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
addq $2,%rax
jnc .L2490
call rt_abort
.L2490:
movzbq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $16,%rax
jnc .L2491
call rt_abort
.L2491:
movabsq $16,%rcx
movq -40(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $3,%rax
jnc .L2492
call rt_abort
.L2492:
movzbq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $63,%rax
cmpq $24,%rax
jnc .L2493
call rt_abort
.L2493:
movabsq $24,%rcx
movq -56(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F2487-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2487-8(%rbp),%rbx
leave
ret
.set .F2487,64
.type rt_store32,@function
rt_store32:
pushq %rbp
movq %rsp,%rbp
subq $.F2494,%rsp
subq $16,%rsp
movq %rbx,-.F2494-8(%rbp)
movq %r12,-.F2494-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r12,%rax
andq $255,%rax
movq %rbx,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L2495
call rt_abort
.L2495:
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $8,%rax
jnc .L2496
call rt_abort
.L2496:
movabsq $8,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-32(%rbp)
andq $255,%rax
movq -24(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L2497
call rt_abort
.L2497:
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $16,%rax
jnc .L2498
call rt_abort
.L2498:
movabsq $16,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-48(%rbp)
andq $255,%rax
movq -40(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L2499
call rt_abort
.L2499:
movq %rax,-56(%rbp)
movabsq $63,%rax
cmpq $24,%rax
jnc .L2500
call rt_abort
.L2500:
movabsq $24,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-64(%rbp)
andq $255,%rax
movq -56(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F2494-8(%rbp),%rbx
movq -.F2494-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2494-8(%rbp),%rbx
movq -.F2494-16(%rbp),%r12
leave
ret
.set .F2494,64
.type rt_push4,@function
rt_push4:
pushq %rbp
movq %rsp,%rbp
subq $.F2501,%rsp
subq $32,%rsp
movq %rbx,-.F2501-8(%rbp)
movq %r12,-.F2501-16(%rbp)
movq %r13,-.F2501-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L2502
call rt_abort
.L2502:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L2503
call rt_abort
.L2503:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L2504
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L2506
call rt_abort
.L2506:
movq %rax,%r13
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L2507
movq $8,%r13
jmp .L2508
.L2507:
.L2508:
movq %r13,%rcx
movabsq $288230376151711744,%rax
cmpq %r13,%rax
jae .L2509
call rt_abort
jmp .L2510
.L2509:
.L2510:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2511
call rt_abort
.L2511:
movq %rax,-48(%rbp)
movabsq $4,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2512
call rt_abort
.L2512:
movq -40(%rbp),%rdi
movq -48(%rbp),%rsi
movq %rax,%rdx
call rt_grow
movq %rax,-56(%rbp)
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L2513
call rt_abort
.L2513:
movq %rax,-64(%rbp)
movq %r13,%rax
movq -64(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
jmp .L2505
.L2504:
.L2505:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2514
call rt_abort
.L2514:
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2515
call rt_abort
.L2515:
movq %rax,-80(%rbp)
movq -16(%rbp),%rax
movq -80(%rbp),%rdi
movq %rax,%rsi
call rt_store32
movq %rbx,%rax
addq $8,%rax
jnc .L2516
call rt_abort
.L2516:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L2517
call rt_abort
.L2517:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F2501-8(%rbp),%rbx
movq -.F2501-16(%rbp),%r12
movq -.F2501-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2501-8(%rbp),%rbx
movq -.F2501-16(%rbp),%r12
movq -.F2501-24(%rbp),%r13
leave
ret
.set .F2501,96
.type rt_fill4,@function
rt_fill4:
pushq %rbp
movq %rsp,%rbp
subq $.F2518,%rsp
subq $48,%rsp
movq %rbx,-.F2518-8(%rbp)
movq %r12,-.F2518-16(%rbp)
movq %r13,-.F2518-24(%rbp)
movq %r14,-.F2518-32(%rbp)
movq %r15,-.F2518-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,-16(%rbp)
movq %rdx,%r12
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %r12,%rcx
movabsq $288230376151711744,%rax
cmpq %r12,%rax
jae .L2519
call rt_abort
jmp .L2520
.L2519:
.L2520:
cmpq $0,%r12
je .L2521
movq %r13,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2523
call rt_abort
.L2523:
movq -32(%rbp),%rdi
movabsq $0,%rsi
movq %rax,%rdx
call rt_grow
movq %rax,-40(%rbp)
movq %r13,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $16,%rax
jnc .L2524
call rt_abort
.L2524:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L2522
.L2521:
.L2522:
movq $0,%rbx
.L2525:
cmpq %r12,%rbx
jae .L2526
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r14
movabsq $4,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2527
call rt_abort
.L2527:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2528
call rt_abort
.L2528:
movq %rax,%r15
movq -16(%rbp),%rax
movq %r15,%rdi
movq %rax,%rsi
call rt_store32
movq %rbx,%rax
addq $1,%rax
jnc .L2529
call rt_abort
.L2529:
movq %rax,%rbx
jmp .L2525
.L2526:
movq %r13,%rax
addq $8,%rax
jnc .L2530
call rt_abort
.L2530:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movabsq $0,%rax
movq -.F2518-8(%rbp),%rbx
movq -.F2518-16(%rbp),%r12
movq -.F2518-24(%rbp),%r13
movq -.F2518-32(%rbp),%r14
movq -.F2518-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2518-8(%rbp),%rbx
movq -.F2518-16(%rbp),%r12
movq -.F2518-24(%rbp),%r13
movq -.F2518-32(%rbp),%r14
movq -.F2518-40(%rbp),%r15
leave
ret
.set .F2518,64
.type rt_slot4u,@function
rt_slot4u:
pushq %rbp
movq %rsp,%rbp
subq $.F2531,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $4,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L2532
call rt_abort
.L2532:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2533
call rt_abort
.L2533:
leave
ret
xorq %rax,%rax
leave
ret
.set .F2531,32
.type rt_slot4,@function
rt_slot4:
pushq %rbp
movq %rsp,%rbp
subq $.F2534,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L2535
call rt_abort
.L2535:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L2536
call rt_abort
jmp .L2537
.L2536:
.L2537:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L2538
call rt_abort
.L2538:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2539
call rt_abort
.L2539:
leave
ret
xorq %rax,%rax
leave
ret
.set .F2534,32
.type rt_at4u,@function
rt_at4u:
pushq %rbp
movq %rsp,%rbp
subq $.F2540,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $4,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L2541
call rt_abort
.L2541:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2542
call rt_abort
.L2542:
movq %rax,%rdi
call rt_load32
leave
ret
xorq %rax,%rax
leave
ret
.set .F2540,32
.type rt_at4,@function
rt_at4:
pushq %rbp
movq %rsp,%rbp
subq $.F2543,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_slot4
movq %rax,%rdi
call rt_load32
leave
ret
xorq %rax,%rax
leave
ret
.set .F2543,16
.type rt_set4,@function
rt_set4:
pushq %rbp
movq %rsp,%rbp
subq $.F2544,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L2545
call rt_abort
.L2545:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2546
call rt_abort
.L2546:
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
movq -40(%rbp),%rdi
movq %rax,%rsi
call rt_store32
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2544,48
.type rt_pop4,@function
rt_pop4:
pushq %rbp
movq %rsp,%rbp
subq $.F2547,%rsp
subq $16,%rsp
movq %rbx,-.F2547-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L2548
call rt_abort
.L2548:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2549
call rt_abort
jmp .L2550
.L2549:
.L2550:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
subq $1,%rax
jnc .L2551
call rt_abort
.L2551:
movq %rax,-40(%rbp)
movabsq $4,%rcx
mulq %rcx
jnc .L2552
call rt_abort
.L2552:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2553
call rt_abort
.L2553:
movq %rax,%rdi
call rt_load32
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L2554
call rt_abort
.L2554:
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
subq $1,%rax
jnc .L2555
call rt_abort
.L2555:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
movq -.F2547-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2547-8(%rbp),%rbx
leave
ret
.set .F2547,64
.type rt_vec_copy4,@function
rt_vec_copy4:
pushq %rbp
movq %rsp,%rbp
subq $.F2556,%rsp
subq $48,%rsp
movq %rbx,-.F2556-8(%rbp)
movq %r12,-.F2556-16(%rbp)
movq %r13,-.F2556-24(%rbp)
movq %r14,-.F2556-32(%rbp)
movq %r15,-.F2556-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq $0,-16(%rbp)
call rt_new
movq %rax,%r14
movq %r13,%rax
addq $8,%rax
jnc .L2557
call rt_abort
.L2557:
movq (%rax),%rax
movq %rax,%r15
movq $0,%rbx
.L2558:
cmpq %r15,%rbx
jae .L2559
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r12
movabsq $4,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2560
call rt_abort
.L2560:
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L2561
call rt_abort
.L2561:
movq %rax,%rdi
call rt_load32
movq %r14,%rdi
movq %rax,%rsi
call rt_push4
movq %rbx,%rax
addq $1,%rax
jnc .L2562
call rt_abort
.L2562:
movq %rax,%rbx
jmp .L2558
.L2559:
movq %r14,%rax
movq -.F2556-8(%rbp),%rbx
movq -.F2556-16(%rbp),%r12
movq -.F2556-24(%rbp),%r13
movq -.F2556-32(%rbp),%r14
movq -.F2556-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2556-8(%rbp),%rbx
movq -.F2556-16(%rbp),%r12
movq -.F2556-24(%rbp),%r13
movq -.F2556-32(%rbp),%r14
movq -.F2556-40(%rbp),%r15
leave
ret
.set .F2556,16
.type rt_vec_insert4,@function
rt_vec_insert4:
pushq %rbp
movq %rsp,%rbp
subq $.F2563,%rsp
subq $32,%rsp
movq %rbx,-.F2563-8(%rbp)
movq %r12,-.F2563-16(%rbp)
movq %r13,-.F2563-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq %rsi,%r13
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %r13,%rcx
cmpq %r13,%rax
jae .L2564
call rt_abort
jmp .L2565
.L2564:
.L2565:
movq %r12,%rdi
movabsq $0,%rsi
call rt_push4
movq -32(%rbp),%rax
movq %rax,%rbx
.L2566:
movq %rbx,%rcx
cmpq %rbx,%r13
jae .L2567
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2568
call rt_abort
.L2568:
movq %r12,%rdi
movq %rax,%rsi
call rt_at4
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_set4
movq %rbx,%rax
subq $1,%rax
jnc .L2569
call rt_abort
.L2569:
movq %rax,%rbx
jmp .L2566
.L2567:
movq -24(%rbp),%rax
movq %r12,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_set4
movabsq $0,%rax
movq -.F2563-8(%rbp),%rbx
movq -.F2563-16(%rbp),%r12
movq -.F2563-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2563-8(%rbp),%rbx
movq -.F2563-16(%rbp),%r12
movq -.F2563-24(%rbp),%r13
leave
ret
.set .F2563,32
.type rt_vec_remove4,@function
rt_vec_remove4:
pushq %rbp
movq %rsp,%rbp
subq $.F2570,%rsp
subq $32,%rsp
movq %rbx,-.F2570-8(%rbp)
movq %r12,-.F2570-16(%rbp)
movq %r13,-.F2570-24(%rbp)
movq %r14,-.F2570-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq %r14,%rax
cmpq %r13,%r14
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2571
call rt_abort
jmp .L2572
.L2571:
.L2572:
movq %r12,%rdi
movq %r14,%rsi
call rt_at4
movq %rax,-32(%rbp)
movq %r14,%rbx
.L2573:
movq %rbx,%rax
addq $1,%rax
jnc .L2575
call rt_abort
.L2575:
movq %r13,%rcx
cmpq %r13,%rax
jae .L2574
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2576
call rt_abort
.L2576:
movq %r12,%rdi
movq %rax,%rsi
call rt_at4
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_set4
movq %rbx,%rax
addq $1,%rax
jnc .L2577
call rt_abort
.L2577:
movq %rax,%rbx
jmp .L2573
.L2574:
movq %r12,%rdi
call rt_pop4
movq -32(%rbp),%rax
movq -.F2570-8(%rbp),%rbx
movq -.F2570-16(%rbp),%r12
movq -.F2570-24(%rbp),%r13
movq -.F2570-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2570-8(%rbp),%rbx
movq -.F2570-16(%rbp),%r12
movq -.F2570-24(%rbp),%r13
movq -.F2570-32(%rbp),%r14
leave
ret
.set .F2570,32
.type rt_vec_swap4,@function
rt_vec_swap4:
pushq %rbp
movq %rsp,%rbp
subq $.F2578,%rsp
subq $32,%rsp
movq %rbx,-.F2578-8(%rbp)
movq %r12,-.F2578-16(%rbp)
movq %r13,-.F2578-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %r12,%rax
movq -32(%rbp),%rcx
cmpq %rcx,%r12
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %r13,%rax
cmpq %rcx,%r13
setb %al
movzbq %al,%rax
movq %rax,-56(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L2579
call rt_abort
.L2579:
testq %rax,%rax
jz .L2580
call rt_abort
jmp .L2581
.L2580:
.L2581:
movq %rbx,%rdi
movq %r12,%rsi
call rt_at4
movq %rax,-64(%rbp)
movq %rbx,%rdi
movq %r13,%rsi
call rt_at4
movq %rbx,%rdi
movq %r12,%rsi
movq %rax,%rdx
call rt_set4
movq -64(%rbp),%rax
movq %rbx,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_set4
movabsq $0,%rax
movq -.F2578-8(%rbp),%rbx
movq -.F2578-16(%rbp),%r12
movq -.F2578-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2578-8(%rbp),%rbx
movq -.F2578-16(%rbp),%r12
movq -.F2578-24(%rbp),%r13
leave
ret
.set .F2578,64
.type rt_vec_reverse4,@function
rt_vec_reverse4:
pushq %rbp
movq %rsp,%rbp
subq $.F2582,%rsp
subq $32,%rsp
movq %rbx,-.F2582-8(%rbp)
movq %r12,-.F2582-16(%rbp)
movq %r13,-.F2582-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
movq $0,%rbx
.L2583:
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2584
movq %r12,%rax
subq $1,%rax
jnc .L2585
call rt_abort
.L2585:
movq %rbx,%rcx
subq %rbx,%rax
jnc .L2586
call rt_abort
.L2586:
movq %r13,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_swap4
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2587
call rt_abort
.L2587:
movq %rax,%rbx
jmp .L2583
.L2584:
movabsq $0,%rax
movq -.F2582-8(%rbp),%rbx
movq -.F2582-16(%rbp),%r12
movq -.F2582-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2582-8(%rbp),%rbx
movq -.F2582-16(%rbp),%r12
movq -.F2582-24(%rbp),%r13
leave
ret
.set .F2582,16
.type rt_vec_truncate4,@function
rt_vec_truncate4:
pushq %rbp
movq %rsp,%rbp
subq $.F2588,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
jae .L2589
movq -8(%rbp),%rax
addq $8,%rax
jnc .L2591
call rt_abort
.L2591:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L2590
.L2589:
.L2590:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2588,32
.type rt_vec_contains4,@function
rt_vec_contains4:
pushq %rbp
movq %rsp,%rbp
subq $.F2592,%rsp
subq $32,%rsp
movq %rbx,-.F2592-8(%rbp)
movq %r12,-.F2592-16(%rbp)
movq %r13,-.F2592-24(%rbp)
movq %r14,-.F2592-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,-16(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movabsq $4294967295,%rcx
movq -16(%rbp),%rax
andq %rcx,%rax
movq %rax,%r14
movq $0,%rbx
.L2593:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L2594
movq %r12,%rdi
movq %rbx,%rsi
call rt_at4
cmpq %r14,%rax
jne .L2595
movabsq $1,%rax
movq -.F2592-8(%rbp),%rbx
movq -.F2592-16(%rbp),%r12
movq -.F2592-24(%rbp),%r13
movq -.F2592-32(%rbp),%r14
leave
ret
jmp .L2596
.L2595:
.L2596:
movq %rbx,%rax
addq $1,%rax
jnc .L2597
call rt_abort
.L2597:
movq %rax,%rbx
jmp .L2593
.L2594:
movabsq $0,%rax
movq -.F2592-8(%rbp),%rbx
movq -.F2592-16(%rbp),%r12
movq -.F2592-24(%rbp),%r13
movq -.F2592-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2592-8(%rbp),%rbx
movq -.F2592-16(%rbp),%r12
movq -.F2592-24(%rbp),%r13
movq -.F2592-32(%rbp),%r14
leave
ret
.set .F2592,16
.type rt_narrow_decode,@function
rt_narrow_decode:
pushq %rbp
movq %rsp,%rbp
subq $.F2598,%rsp
subq $16,%rsp
movq %rbx,-.F2598-8(%rbp)
movq %r12,-.F2598-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $7,%rcx
cmpq $7,%r12
jne .L2599
movq %rbx,%rdi
call rt_f32_from_bits
movq -.F2598-8(%rbp),%rbx
movq -.F2598-16(%rbp),%r12
leave
ret
jmp .L2600
.L2599:
.L2600:
movabsq $1023,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %r12,%rax
subq $1024,%rax
jnc .L2601
call rt_abort
.L2601:
movq %rax,-32(%rbp)
andq $256,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2602
movabsq $2147483648,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
je .L2604
movabsq $18446744069414584320,%rcx
movq %rbx,%rax
orq %rcx,%rax
movq -.F2598-8(%rbp),%rbx
movq -.F2598-16(%rbp),%r12
leave
ret
jmp .L2605
.L2604:
.L2605:
jmp .L2603
.L2602:
.L2603:
movq %rbx,%rax
movq -.F2598-8(%rbp),%rbx
movq -.F2598-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2598-8(%rbp),%rbx
movq -.F2598-16(%rbp),%r12
leave
ret
.set .F2598,48
.type rt_vec_feq,@function
rt_vec_feq:
pushq %rbp
movq %rsp,%rbp
subq $.F2606,%rsp
subq $48,%rsp
movq %rbx,-.F2606-8(%rbp)
movq %r12,-.F2606-16(%rbp)
movq %r13,-.F2606-24(%rbp)
movq %r14,-.F2606-32(%rbp)
movq %r15,-.F2606-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -40(%rbp),%rax
cmpq %rcx,%rax
je .L2607
movabsq $0,%rax
movq -.F2606-8(%rbp),%rbx
movq -.F2606-16(%rbp),%r12
movq -.F2606-24(%rbp),%r13
movq -.F2606-32(%rbp),%r14
movq -.F2606-40(%rbp),%r15
leave
ret
jmp .L2608
.L2607:
.L2608:
movq $0,%rbx
.L2609:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2610
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2611
movq %r14,%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%rdi
call rt_f32_from_bits
movq %rax,%r12
movq %r15,%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%rdi
call rt_f32_from_bits
movq %rax,%r13
jmp .L2612
.L2611:
movq %r14,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i98
call rt_abort
.Lopt15_i98:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i98
xorq %rax,%rax
jmp .Lret_i98
.Lret_i98:
movq %rax,%r12
movq %r15,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i99
call rt_abort
.Lopt15_i99:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i99
xorq %rax,%rax
jmp .Lret_i99
.Lret_i99:
movq %rax,%r13
.L2612:
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L2613
movabsq $0,%rax
movq -.F2606-8(%rbp),%rbx
movq -.F2606-16(%rbp),%r12
movq -.F2606-24(%rbp),%r13
movq -.F2606-32(%rbp),%r14
movq -.F2606-40(%rbp),%r15
leave
ret
jmp .L2614
.L2613:
.L2614:
movq %rbx,%rax
addq $1,%rax
jnc .L2615
call rt_abort
.L2615:
movq %rax,%rbx
jmp .L2609
.L2610:
movabsq $1,%rax
movq -.F2606-8(%rbp),%rbx
movq -.F2606-16(%rbp),%r12
movq -.F2606-24(%rbp),%r13
movq -.F2606-32(%rbp),%r14
movq -.F2606-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2606-8(%rbp),%rbx
movq -.F2606-16(%rbp),%r12
movq -.F2606-24(%rbp),%r13
movq -.F2606-32(%rbp),%r14
movq -.F2606-40(%rbp),%r15
leave
ret
.set .F2606,48
.type rt_vec_cmp4,@function
rt_vec_cmp4:
pushq %rbp
movq %rsp,%rbp
subq $.F2616,%rsp
subq $48,%rsp
movq %rbx,-.F2616-8(%rbp)
movq %r12,-.F2616-16(%rbp)
movq %r13,-.F2616-24(%rbp)
movq %r14,-.F2616-32(%rbp)
movq %r15,-.F2616-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq $0,%rbx
movq $1,%r12
.L2617:
movq %rbx,%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,%r15
movq %rbx,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq %r15,%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2618
movq -16(%rbp),%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%r14
cmpq %r14,%r13
je .L2619
cmpq %r14,%r13
jae .L2621
movq $0,%r12
jmp .L2622
.L2621:
movq $2,%r12
.L2622:
jmp .L2618
jmp .L2620
.L2619:
.L2620:
movq %rbx,%rax
addq $1,%rax
jnc .L2623
call rt_abort
.L2623:
movq %rax,%rbx
jmp .L2617
.L2618:
movabsq $1,%rcx
cmpq $1,%r12
jne .L2624
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2626
movq $0,%r12
jmp .L2627
.L2626:
.L2627:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2628
movq $2,%r12
jmp .L2629
.L2628:
.L2629:
jmp .L2625
.L2624:
.L2625:
movq -8(%rbp),%rdi
movq %r12,%rsi
call rt_order_result
movq -.F2616-8(%rbp),%rbx
movq -.F2616-16(%rbp),%r12
movq -.F2616-24(%rbp),%r13
movq -.F2616-32(%rbp),%r14
movq -.F2616-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2616-8(%rbp),%rbx
movq -.F2616-16(%rbp),%r12
movq -.F2616-24(%rbp),%r13
movq -.F2616-32(%rbp),%r14
movq -.F2616-40(%rbp),%r15
leave
ret
.set .F2616,48
.type rt_vec_set,@function
rt_vec_set:
pushq %rbp
movq %rsp,%rbp
subq $.F2630,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L2631
call rt_abort
.L2631:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2632
call rt_abort
.L2632:
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2630,48
.type rt_vec_insert,@function
rt_vec_insert:
pushq %rbp
movq %rsp,%rbp
subq $.F2633,%rsp
subq $32,%rsp
movq %rbx,-.F2633-8(%rbp)
movq %r12,-.F2633-16(%rbp)
movq %r13,-.F2633-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq %rsi,%r13
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %r13,%rcx
cmpq %r13,%rax
jae .L2634
call rt_abort
jmp .L2635
.L2634:
.L2635:
movq %r12,%rdi
movabsq $0,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt247
call rt_push
jmp .Lopt248
.Lopt247:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt248:
movq -32(%rbp),%rax
movq %rax,%rbx
.L2636:
movq %rbx,%rcx
cmpq %rbx,%r13
jae .L2637
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2638
call rt_abort
.L2638:
movq %r12,%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i100
call rt_abort
.Lopt15_i100:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i100
xorq %rax,%rax
jmp .Lret_i100
.Lret_i100:
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_set
movq %rbx,%rax
subq $1,%rax
jnc .L2639
call rt_abort
.L2639:
movq %rax,%rbx
jmp .L2636
.L2637:
movq -24(%rbp),%rax
movq %r12,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_vec_set
movabsq $0,%rax
movq -.F2633-8(%rbp),%rbx
movq -.F2633-16(%rbp),%r12
movq -.F2633-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2633-8(%rbp),%rbx
movq -.F2633-16(%rbp),%r12
movq -.F2633-24(%rbp),%r13
leave
ret
.set .F2633,32
.type rt_vec_remove,@function
rt_vec_remove:
pushq %rbp
movq %rsp,%rbp
subq $.F2640,%rsp
subq $32,%rsp
movq %rbx,-.F2640-8(%rbp)
movq %r12,-.F2640-16(%rbp)
movq %r13,-.F2640-24(%rbp)
movq %r14,-.F2640-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq %r14,%rax
cmpq %r13,%r14
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2641
call rt_abort
jmp .L2642
.L2641:
.L2642:
movq %r12,%rdi
movq %r14,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i101
call rt_abort
.Lopt15_i101:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i101
xorq %rax,%rax
jmp .Lret_i101
.Lret_i101:
movq %rax,-32(%rbp)
movq %r14,%rbx
.L2643:
movq %rbx,%rax
addq $1,%rax
jnc .L2645
call rt_abort
.L2645:
movq %r13,%rcx
cmpq %r13,%rax
jae .L2644
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2646
call rt_abort
.L2646:
movq %r12,%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i102
call rt_abort
.Lopt15_i102:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i102
xorq %rax,%rax
jmp .Lret_i102
.Lret_i102:
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_set
movq %rbx,%rax
addq $1,%rax
jnc .L2647
call rt_abort
.L2647:
movq %rax,%rbx
jmp .L2643
.L2644:
movq %r12,%rdi
call rt_pop
movq -32(%rbp),%rax
movq -.F2640-8(%rbp),%rbx
movq -.F2640-16(%rbp),%r12
movq -.F2640-24(%rbp),%r13
movq -.F2640-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2640-8(%rbp),%rbx
movq -.F2640-16(%rbp),%r12
movq -.F2640-24(%rbp),%r13
movq -.F2640-32(%rbp),%r14
leave
ret
.set .F2640,32
.type rt_vec_swap,@function
rt_vec_swap:
pushq %rbp
movq %rsp,%rbp
subq $.F2648,%rsp
subq $32,%rsp
movq %rbx,-.F2648-8(%rbp)
movq %r12,-.F2648-16(%rbp)
movq %r13,-.F2648-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq %r12,%rax
movq -32(%rbp),%rcx
cmpq %rcx,%r12
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %r13,%rax
cmpq %rcx,%r13
setb %al
movzbq %al,%rax
movq %rax,-56(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L2649
call rt_abort
.L2649:
testq %rax,%rax
jz .L2650
call rt_abort
jmp .L2651
.L2650:
.L2651:
movq %rbx,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i103
call rt_abort
.Lopt15_i103:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i103
xorq %rax,%rax
jmp .Lret_i103
.Lret_i103:
movq %rax,-64(%rbp)
movq %rbx,%rdi
movq %r13,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i104
call rt_abort
.Lopt15_i104:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i104
xorq %rax,%rax
jmp .Lret_i104
.Lret_i104:
movq %rbx,%rdi
movq %r12,%rsi
movq %rax,%rdx
call rt_vec_set
movq -64(%rbp),%rax
movq %rbx,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_vec_set
movabsq $0,%rax
movq -.F2648-8(%rbp),%rbx
movq -.F2648-16(%rbp),%r12
movq -.F2648-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2648-8(%rbp),%rbx
movq -.F2648-16(%rbp),%r12
movq -.F2648-24(%rbp),%r13
leave
ret
.set .F2648,64
.type rt_vec_reverse,@function
rt_vec_reverse:
pushq %rbp
movq %rsp,%rbp
subq $.F2652,%rsp
subq $32,%rsp
movq %rbx,-.F2652-8(%rbp)
movq %r12,-.F2652-16(%rbp)
movq %r13,-.F2652-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
movq $0,%rbx
.L2653:
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2654
movq %r12,%rax
subq $1,%rax
jnc .L2655
call rt_abort
.L2655:
movq %rbx,%rcx
subq %rbx,%rax
jnc .L2656
call rt_abort
.L2656:
movq %r13,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_swap
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2657
call rt_abort
.L2657:
movq %rax,%rbx
jmp .L2653
.L2654:
movabsq $0,%rax
movq -.F2652-8(%rbp),%rbx
movq -.F2652-16(%rbp),%r12
movq -.F2652-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2652-8(%rbp),%rbx
movq -.F2652-16(%rbp),%r12
movq -.F2652-24(%rbp),%r13
leave
ret
.set .F2652,16
.type rt_vec_truncate,@function
rt_vec_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F2658,%rsp
subq $32,%rsp
movq %rbx,-.F2658-8(%rbp)
movq %r12,-.F2658-16(%rbp)
movq %r13,-.F2658-24(%rbp)
movq %r14,-.F2658-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%rbx
movq %rsi,%r14
movq %rdx,%r12
movq $0,-32(%rbp)
.L2659:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
cmpq %rcx,%r14
jae .L2660
movq %rbx,%rdi
call rt_pop
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%r12
je .L2661
movq %r13,%rdi
movabsq $0,%rsi
movq %r12,%rax
call *%rax
jmp .L2662
.L2661:
.L2662:
jmp .L2659
.L2660:
movabsq $0,%rax
movq -.F2658-8(%rbp),%rbx
movq -.F2658-16(%rbp),%r12
movq -.F2658-24(%rbp),%r13
movq -.F2658-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2658-8(%rbp),%rbx
movq -.F2658-16(%rbp),%r12
movq -.F2658-24(%rbp),%r13
movq -.F2658-32(%rbp),%r14
leave
ret
.set .F2658,32
.type rt_vec_contains,@function
rt_vec_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F2663,%rsp
subq $32,%rsp
movq %rbx,-.F2663-8(%rbp)
movq %r12,-.F2663-16(%rbp)
movq %r13,-.F2663-24(%rbp)
movq %r14,-.F2663-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,%r13
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r14
movq $0,%rbx
.L2664:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L2665
movq %r12,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15_i105
call rt_abort
.Lopt15_i105:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i105
xorq %rax,%rax
jmp .Lret_i105
.Lret_i105:
cmpq %r13,%rax
jne .L2666
movabsq $1,%rax
movq -.F2663-8(%rbp),%rbx
movq -.F2663-16(%rbp),%r12
movq -.F2663-24(%rbp),%r13
movq -.F2663-32(%rbp),%r14
leave
ret
jmp .L2667
.L2666:
.L2667:
movq %rbx,%rax
addq $1,%rax
jnc .L2668
call rt_abort
.L2668:
movq %rax,%rbx
jmp .L2664
.L2665:
movabsq $0,%rax
movq -.F2663-8(%rbp),%rbx
movq -.F2663-16(%rbp),%r12
movq -.F2663-24(%rbp),%r13
movq -.F2663-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2663-8(%rbp),%rbx
movq -.F2663-16(%rbp),%r12
movq -.F2663-24(%rbp),%r13
movq -.F2663-32(%rbp),%r14
leave
ret
.set .F2663,16
.type rt_syscall,@function
rt_syscall:
pushq %rbp
movq %rsp,%rbp
subq $.F2669,%rsp
subq $32,%rsp
movq %rbx,-.F2669-8(%rbp)
movq %r12,-.F2669-16(%rbp)
movq %r13,-.F2669-24(%rbp)
movq %r14,-.F2669-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq %rcx,%r14
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $0,%rcx
movabsq $0,%rax
cmpq $0,%rax
jne .L2670
movq %rbx,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2671
.L2670:
.L2671:
movabsq $0,%rcx
cmpq $0,%rbx
jne .L2672
movabsq $63,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2673
.L2672:
.L2673:
movabsq $1,%rcx
cmpq $1,%rbx
jne .L2674
movabsq $64,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2675
.L2674:
.L2675:
cmpq $2,%rbx
jne .L2676
movabsq $100,%rcx
movabsq $0,%rax
subq $100,%rax
movq %rax,-40(%rbp)
movabsq $56,%rax
movq -40(%rbp),%rdi
movq %r12,%rsi
movq %r13,%rdx
movq %r14,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2677
.L2676:
.L2677:
movabsq $3,%rcx
cmpq $3,%rbx
jne .L2678
movabsq $57,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2679
.L2678:
.L2679:
movabsq $11,%rcx
cmpq $11,%rbx
jne .L2680
movabsq $215,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2681
.L2680:
.L2681:
movabsq $27,%rcx
cmpq $27,%rbx
jne .L2682
movabsq $232,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2683
.L2682:
.L2683:
movabsq $39,%rcx
cmpq $39,%rbx
jne .L2684
movabsq $172,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2685
.L2684:
.L2685:
movabsq $57,%rcx
cmpq $57,%rbx
jne .L2686
movabsq $220,%rax
movabsq $17,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2687
.L2686:
.L2687:
movabsq $202,%rcx
cmpq $202,%rbx
jne .L2688
movabsq $98,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2689
.L2688:
.L2689:
movabsq $10,%rcx
cmpq $10,%rbx
jne .L2690
movabsq $226,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2691
.L2690:
.L2691:
movabsq $204,%rcx
cmpq $204,%rbx
jne .L2692
movabsq $123,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2693
.L2692:
.L2693:
movabsq $231,%rcx
cmpq $231,%rbx
jne .L2694
movabsq $94,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2695
.L2694:
.L2695:
movabsq $291,%rcx
cmpq $291,%rbx
jne .L2696
movabsq $20,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2697
.L2696:
.L2697:
movabsq $283,%rcx
cmpq $283,%rbx
jne .L2698
movabsq $85,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2699
.L2698:
.L2699:
movabsq $293,%rcx
cmpq $293,%rbx
jne .L2700
movabsq $59,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2701
.L2700:
.L2701:
movabsq $271,%rcx
cmpq $271,%rbx
jne .L2702
movabsq $73,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2703
.L2702:
.L2703:
movabsq $228,%rcx
cmpq $228,%rbx
jne .L2704
movabsq $113,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2705
.L2704:
.L2705:
movabsq $35,%rcx
cmpq $35,%rbx
jne .L2706
movabsq $101,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2707
.L2706:
.L2707:
movabsq $290,%rcx
cmpq $290,%rbx
jne .L2708
movabsq $19,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2709
.L2708:
.L2709:
movabsq $263,%rcx
cmpq $263,%rbx
jne .L2710
movabsq $35,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2711
.L2710:
.L2711:
movabsq $217,%rcx
cmpq $217,%rbx
jne .L2712
movabsq $61,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2713
.L2712:
.L2713:
movabsq $41,%rcx
cmpq $41,%rbx
jne .L2714
movabsq $198,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2715
.L2714:
.L2715:
movabsq $49,%rcx
cmpq $49,%rbx
jne .L2716
movabsq $200,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2717
.L2716:
.L2717:
movabsq $50,%rcx
cmpq $50,%rbx
jne .L2718
movabsq $201,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2719
.L2718:
.L2719:
movabsq $42,%rcx
cmpq $42,%rbx
jne .L2720
movabsq $203,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2721
.L2720:
.L2721:
movabsq $51,%rcx
cmpq $51,%rbx
jne .L2722
movabsq $204,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2723
.L2722:
.L2723:
movabsq $258,%rcx
cmpq $258,%rbx
jne .L2724
movabsq $34,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2725
.L2724:
.L2725:
movabsq $59,%rcx
cmpq $59,%rbx
jne .L2726
movabsq $221,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2727
.L2726:
.L2727:
movabsq $60,%rcx
cmpq $60,%rbx
jne .L2728
movabsq $93,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2729
.L2728:
.L2729:
movabsq $61,%rcx
cmpq $61,%rbx
jne .L2730
movabsq $260,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2731
.L2730:
.L2731:
movabsq $62,%rcx
cmpq $62,%rbx
jne .L2732
movabsq $129,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
jmp .L2733
.L2732:
.L2733:
movabsq $0,%rax
subq $38,%rax
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2669-8(%rbp),%rbx
movq -.F2669-16(%rbp),%r12
movq -.F2669-24(%rbp),%r13
movq -.F2669-32(%rbp),%r14
leave
ret
.set .F2669,48
.type rt_syscall4,@function
rt_syscall4:
pushq %rbp
movq %rsp,%rbp
subq $.F2734,%rsp
subq $48,%rsp
movq %rbx,-.F2734-8(%rbp)
movq %r12,-.F2734-16(%rbp)
movq %r13,-.F2734-24(%rbp)
movq %r14,-.F2734-32(%rbp)
movq %r15,-.F2734-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq %rcx,%r14
movq %r8,%r15
movq $0,-48(%rbp)
movabsq $0,%rcx
movabsq $0,%rax
cmpq $0,%rax
jne .L2735
movq %rbx,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
jmp .L2736
.L2735:
.L2736:
movabsq $233,%rcx
cmpq $233,%rbx
jne .L2737
movabsq $21,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
jmp .L2738
.L2737:
.L2738:
movabsq $281,%rcx
cmpq $281,%rbx
jne .L2739
movabsq $22,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
jmp .L2740
.L2739:
.L2740:
movabsq $286,%rcx
cmpq $286,%rbx
jne .L2741
movabsq $86,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
jmp .L2742
.L2741:
.L2742:
movabsq $25,%rcx
cmpq $25,%rbx
jne .L2743
movabsq $216,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
jmp .L2744
.L2743:
.L2744:
movabsq $0,%rax
subq $38,%rax
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2734-8(%rbp),%rbx
movq -.F2734-16(%rbp),%r12
movq -.F2734-24(%rbp),%r13
movq -.F2734-32(%rbp),%r14
movq -.F2734-40(%rbp),%r15
leave
ret
.set .F2734,48
.type rt_readlinkat,@function
rt_readlinkat:
pushq %rbp
movq %rsp,%rbp
subq $.F2745,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $0,%rax
cmpq $0,%rax
jne .L2746
movabsq $100,%rcx
movabsq $0,%rax
subq $100,%rax
movq %rax,-32(%rbp)
movabsq $267,%rax
movq -32(%rbp),%rdi
movq -8(%rbp),%rsi
movq -16(%rbp),%rdx
movq -24(%rbp),%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
leave
ret
jmp .L2747
.L2746:
.L2747:
movabsq $100,%rcx
movabsq $0,%rax
subq $100,%rax
movq %rax,-40(%rbp)
movabsq $78,%rax
movq -40(%rbp),%rdi
movq -8(%rbp),%rsi
movq -16(%rbp),%rdx
movq -24(%rbp),%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
leave
ret
xorq %rax,%rax
leave
ret
.set .F2745,48
.type rt_faccessat,@function
rt_faccessat:
pushq %rbp
movq %rsp,%rbp
subq $.F2748,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $0,%rax
cmpq $0,%rax
jne .L2749
movabsq $100,%rcx
movabsq $0,%rax
subq $100,%rax
movq %rax,-16(%rbp)
movabsq $269,%rax
movq -16(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
leave
ret
jmp .L2750
.L2749:
.L2750:
movabsq $100,%rcx
movabsq $0,%rax
subq $100,%rax
movq %rax,-24(%rbp)
movabsq $48,%rax
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
leave
ret
xorq %rax,%rax
leave
ret
.set .F2748,32
.type rt_accept4,@function
rt_accept4:
pushq %rbp
movq %rsp,%rbp
subq $.F2751,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $0,%rcx
movabsq $0,%rax
cmpq $0,%rax
jne .L2752
movabsq $288,%rax
movq -8(%rbp),%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $526336,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
leave
ret
jmp .L2753
.L2752:
.L2753:
movabsq $242,%rax
movq -8(%rbp),%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $526336,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
leave
ret
xorq %rax,%rax
leave
ret
.set .F2751,16
.type rt_os_init,@function
rt_os_init:
pushq %rbp
movq %rsp,%rbp
subq $.F2754,%rsp
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2754,16
.D2:
testq %rdi,%rdi
jz .L2890
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_drop_seq
popq %r13
popq %r12
leave
.L2890:
ret
.D3:
testq %rdi,%rdi
jz .L2891
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_drop_seq
popq %r13
popq %r12
leave
.L2891:
ret
.D4:
testq %rdi,%rdi
jz .L2892
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L2892:
ret
.D5:
testq %rdi,%rdi
jz .L2893
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
xorq %r13,%r13
.L2894:
cmpq 8(%r12),%r13
jae .L2895
movq (%r12),%rax
movq (%rax,%r13,8),%rdi
call .D2
incq %r13
jmp .L2894
.L2895:
movq %r12,%rdi
call rt_drop_seq
popq %r13
popq %r12
leave
.L2893:
ret
.D6:
testq %rdi,%rdi
jz .L2896
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
movq %r12,%rdi
call rt_drop_seq
popq %r13
popq %r12
leave
.L2896:
ret
.D16:
testq %rdi,%rdi
jz .L2897
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
movq %r12,%rdi
call rt_free
popq %r13
popq %r12
leave
.L2897:
ret
.D17:
testq %rdi,%rdi
jz .L2898
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
xorq %r13,%r13
.L2899:
cmpq 8(%r12),%r13
jae .L2900
movq (%r12),%rax
movq (%rax,%r13,8),%rdi
call .D16
incq %r13
jmp .L2899
.L2900:
movq %r12,%rdi
call rt_drop_seq
popq %r13
popq %r12
leave
.L2898:
ret
.globl _start
_start:
movq (%rsp),%rdi
leaq 8(%rsp),%rsi
leaq 16(%rsp,%rdi,8),%rdx
movq %rdi,rt_state(%rip)
movq %rsi,rt_state+8(%rip)
movq %rdx,rt_state+16(%rip)
andq $-16,%rsp
movl $4099,%edi
leaq rt_host_tls(%rip),%rsi
movl $158,%eax
syscall
call rt_thread_init
movq rt_state(%rip),%rdi
call f_main_main
movq %rax,%r14
call rt_live
testq %rax,%rax
jz .L2901
call rt_abort
.L2901:
call rt_shutdown
movl $231,%eax
movq %r14,%rdi
syscall
ud2
.bss
.p2align 3
rt_state: .zero 4096
rt_host_tls: .zero 8
rt_grail_tls: .zero 8
.section .note.GNU-stack,"",@progbits
