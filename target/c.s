.text
.type f_main_find_in,@function
f_main_find_in:
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
movq %rdi,-8(%rbp)
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $1,%r13
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq $0,%r15
.L2:
movq -32(%rbp),%rcx
cmpq %rcx,%r15
jae .L4
movq -24(%rbp),%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt1
call rt_abort
.Lopt1:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq %rax,-40(%rbp)
movq (%rax),%rax
movq 0(%rax),%rax
movq %rax,-48(%rbp)
movabsq $258,%rdi
movq %rax,%rsi
movq %r14,%rdx
call rt_seq_cmp
testq %rax,%rax
jz .L5
movq -40(%rbp),%rax
movq (%rax),%rax
movq 8(%rax),%rax
movq %rax,%rdi
call f_core_some$0
movq %rax,%r12
movq $0,%rbx
cmpq $0,%rbx
je .L7
movq %r12,%rdi
call .D12
.L7:
cmpq $0,%r13
je .L8
movq %r14,%rdi
call .D11
.L8:
movq %r12,%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
movq -.F1-24(%rbp),%r13
movq -.F1-32(%rbp),%r14
movq -.F1-40(%rbp),%r15
leave
ret
cmpq $0,%rbx
je .L9
movq $0,%rbx
movq %r12,%rdi
call .D12
.L9:
cmpq $0,%rbx
je .L10
movq $0,%rbx
movq %r12,%rdi
call .D12
.L10:
jmp .L6
.L5:
.L6:
cmpq $0,%rbx
je .L11
movq $0,%rbx
movq %r12,%rdi
call .D12
.L11:
cmpq $0,%rbx
je .L12
movq $0,%rbx
movq %r12,%rdi
call .D12
.L12:
cmpq $0,%rbx
je .L13
movq $0,%rbx
movq %r12,%rdi
call .D12
.L13:
.L3:
incq %r15
jmp .L2
.L4:
cmpq $0,%rbx
je .L14
movq $0,%rbx
movq %r12,%rdi
call .D12
.L14:
cmpq $0,%r13
je .L15
movq $0,%r13
movq %r14,%rdi
call .D11
.L15:
cmpq $0,%rbx
je .L16
movq $0,%rbx
movq %r12,%rdi
call .D12
.L16:
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,-56(%rbp)
movq $1,-64(%rbp)
movq $0,-64(%rbp)
cmpq $0,-64(%rbp)
je .L17
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D12
.L17:
cmpq $0,%rbx
je .L18
movq %r12,%rdi
call .D12
.L18:
cmpq $0,%r13
je .L19
movq %r14,%rdi
call .D11
.L19:
movq -56(%rbp),%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
movq -.F1-24(%rbp),%r13
movq -.F1-32(%rbp),%r14
movq -.F1-40(%rbp),%r15
leave
ret
cmpq $0,%r13
je .L20
movq $0,%r13
movq %r14,%rdi
call .D11
.L20:
cmpq $0,-64(%rbp)
je .L21
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D12
.L21:
cmpq $0,-64(%rbp)
je .L22
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D12
.L22:
cmpq $0,%rbx
je .L23
movq $0,%rbx
movq %r12,%rdi
call .D12
.L23:
cmpq $0,-64(%rbp)
je .L24
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D12
.L24:
cmpq $0,%rbx
je .L25
movq %r12,%rdi
call .D12
.L25:
cmpq $0,%r13
je .L26
movq %r14,%rdi
call .D11
.L26:
xorq %rax,%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
movq -.F1-24(%rbp),%r13
movq -.F1-32(%rbp),%r14
movq -.F1-40(%rbp),%r15
leave
ret
.set .F1,64
.type f_main_copy_key,@function
f_main_copy_key:
pushq %rbp
movq %rsp,%rbp
subq $.F27,%rsp
subq $32,%rsp
movq %rbx,-.F27-8(%rbp)
movq %r12,-.F27-16(%rbp)
movq %r13,-.F27-24(%rbp)
movq %r14,-.F27-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r14
movq $0,-16(%rbp)
movq $1,%r13
movq %r14,%rdi
call rt_text
movq %rax,%r12
movq $0,%rbx
cmpq $0,%rbx
je .L28
movq %r12,%rdi
call .D3
.L28:
cmpq $0,%r13
je .L29
movq %r14,%rdi
call .D3
.L29:
movq %r12,%rax
movq -.F27-8(%rbp),%rbx
movq -.F27-16(%rbp),%r12
movq -.F27-24(%rbp),%r13
movq -.F27-32(%rbp),%r14
leave
ret
cmpq $0,%rbx
je .L30
movq $0,%rbx
movq %r12,%rdi
call .D3
.L30:
cmpq $0,%rbx
je .L31
movq $0,%rbx
movq %r12,%rdi
call .D3
.L31:
cmpq $0,%rbx
je .L32
movq %r12,%rdi
call .D3
.L32:
cmpq $0,%r13
je .L33
movq %r14,%rdi
call .D3
.L33:
xorq %rax,%rax
movq -.F27-8(%rbp),%rbx
movq -.F27-16(%rbp),%r12
movq -.F27-24(%rbp),%r13
movq -.F27-32(%rbp),%r14
leave
ret
.set .F27,16
.type f_main_main,@function
f_main_main:
pushq %rbp
movq %rsp,%rbp
subq $.F34,%rsp
subq $48,%rsp
movq %rbx,-.F34-8(%rbp)
movq %r12,-.F34-16(%rbp)
movq %r13,-.F34-24(%rbp)
movq %r14,-.F34-32(%rbp)
movq %r15,-.F34-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
leaq -.F34(%rbp),%rdi
movq $.F34/8-0,%rcx
xorl %eax,%eax
rep stosq
call rt_new
movq %rax,-8(%rbp)
movabsq $2,%rdi
call rt_rec
movq %rax,-16(%rbp)
.pushsection .rodata
.L35:
.byte 98
.byte 0
.popsection
leaq .L35(%rip),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_string_lit
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
movq $0,%r13
movq -16(%rbp),%rcx
movq %rax,0(%rcx)
movq $2,8(%rcx)
movq $0,%r14
movq $0,%r15
movq -8(%rbp),%rdi
movq %rcx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt2
call rt_push
jmp .Lopt3
.Lopt2:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt3:
movabsq $2,%rdi
call rt_rec
movq %rax,-48(%rbp)
.pushsection .rodata
.L36:
.byte 97
.byte 0
.popsection
leaq .L36(%rip),%rax
movq %rax,-56(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_string_lit
movq %rax,-64(%rbp)
movq $1,-72(%rbp)
movq %rax,-80(%rbp)
movq $0,-72(%rbp)
movq $1,-88(%rbp)
movq -48(%rbp),%rcx
movq %rax,0(%rcx)
movq $1,8(%rcx)
movq $1,-96(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq -8(%rbp),%rdi
movq %rcx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt4
call rt_push
jmp .Lopt5
.Lopt4:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt5:
movq -8(%rbp),%rax
movq %rax,-104(%rbp)
movq $0,%r12
movq $1,-112(%rbp)
cmpq $0,-96(%rbp)
je .L37
movq $0,-96(%rbp)
movq -48(%rbp),%rdi
call .D7
.L37:
cmpq $0,-88(%rbp)
je .L38
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D3
.L38:
cmpq $0,-72(%rbp)
je .L39
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D3
.L39:
cmpq $0,%r15
je .L40
movq $0,%r15
movq -16(%rbp),%rdi
call .D7
.L40:
cmpq $0,%r14
je .L41
movq $0,%r14
movq -40(%rbp),%rdi
call .D3
.L41:
cmpq $0,%r13
je .L42
movq $0,%r13
movq -32(%rbp),%rdi
call .D3
.L42:
cmpq $0,%r12
je .L43
movq $0,%r12
movq -8(%rbp),%rdi
call .D8
.L43:
.pushsection .rodata
.L44:
.byte 104
.byte 101
.byte 108
.byte 108
.byte 111
.byte 0
.popsection
leaq .L44(%rip),%rax
movq %rax,-120(%rbp)
movq %rax,%rdi
movabsq $5,%rsi
call rt_string_lit
movq %rax,-128(%rbp)
movq $1,-136(%rbp)
movq %rax,-144(%rbp)
movq $0,-136(%rbp)
movq $1,-152(%rbp)
movq $0,-152(%rbp)
movq %rax,%rdi
call f_main_copy_key
movq %rax,-160(%rbp)
movq $1,%rbx
movq %rax,%rdi
call rt_view
movq %rax,-168(%rbp)
movq $1,-176(%rbp)
movq $0,-176(%rbp)
movq %rax,%rdi
call f_host_print
cmpq $0,%rbx
je .L45
movq $0,%rbx
movq -160(%rbp),%rdi
call .D3
.L45:
cmpq $0,-176(%rbp)
je .L46
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L46:
cmpq $0,%rbx
je .L47
movq $0,%rbx
movq -160(%rbp),%rdi
call .D3
.L47:
cmpq $0,-152(%rbp)
je .L48
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D3
.L48:
cmpq $0,-136(%rbp)
je .L49
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D3
.L49:
leaq -104(%rbp),%rax
movq %rax,-184(%rbp)
.pushsection .rodata
.L50:
.byte 97
.byte 0
.popsection
leaq .L50(%rip),%rax
movq %rax,-192(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_string_lit
movq %rax,-200(%rbp)
movq $1,-208(%rbp)
movq %rax,-216(%rbp)
movq $0,-208(%rbp)
movq $1,-224(%rbp)
leaq -216(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,-232(%rbp)
movq $1,-240(%rbp)
movq %rax,-248(%rbp)
movq $0,-240(%rbp)
movq $1,-256(%rbp)
movq $0,-256(%rbp)
movq -184(%rbp),%rdi
movq %rax,%rsi
call f_main_find_in
movq %rax,-264(%rbp)
movq $1,-272(%rbp)
movq 0(%rax),%rax
movq %rax,-280(%rbp)
movq $0,-272(%rbp)
cmpq $1,%rax
jne .L52
movq -264(%rbp),%rax
movq 8(%rax),%rax
movq %rax,-288(%rbp)
movq -264(%rbp),%rdi
call rt_free
movq -288(%rbp),%rdi
movabsq $0,%rsi
call rt_print_number
jmp .L51
.L52:
movq -280(%rbp),%rax
cmpq $0,%rax
jne .L53
movq -264(%rbp),%rdi
call rt_free
movabsq $0,%rdi
movabsq $0,%rsi
call rt_print_number
jmp .L51
.L53:
call rt_abort
.L51:
cmpq $0,-272(%rbp)
je .L54
movq $0,-272(%rbp)
movq -264(%rbp),%rdi
call .D12
.L54:
cmpq $0,-256(%rbp)
je .L55
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D4
.L55:
cmpq $0,-240(%rbp)
je .L56
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D4
.L56:
cmpq $0,-208(%rbp)
je .L57
movq $0,-208(%rbp)
movq -200(%rbp),%rdi
call .D3
.L57:
movq $0,-296(%rbp)
cmpq $0,-272(%rbp)
je .L58
movq $0,-272(%rbp)
movq -264(%rbp),%rdi
call .D12
.L58:
cmpq $0,-256(%rbp)
je .L59
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D4
.L59:
cmpq $0,-240(%rbp)
je .L60
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D4
.L60:
cmpq $0,-224(%rbp)
je .L61
movq $0,-224(%rbp)
movq -216(%rbp),%rdi
call .D3
.L61:
cmpq $0,-208(%rbp)
je .L62
movq $0,-208(%rbp)
movq -200(%rbp),%rdi
call .D3
.L62:
cmpq $0,-176(%rbp)
je .L63
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L63:
cmpq $0,%rbx
je .L64
movq -160(%rbp),%rdi
call .D3
.L64:
cmpq $0,-152(%rbp)
je .L65
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D3
.L65:
cmpq $0,-136(%rbp)
je .L66
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D3
.L66:
cmpq $0,-112(%rbp)
je .L67
movq $0,-112(%rbp)
movq -104(%rbp),%rdi
call .D8
.L67:
cmpq $0,-96(%rbp)
je .L68
movq $0,-96(%rbp)
movq -48(%rbp),%rdi
call .D7
.L68:
cmpq $0,-88(%rbp)
je .L69
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D3
.L69:
cmpq $0,-72(%rbp)
je .L70
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D3
.L70:
cmpq $0,%r15
je .L71
movq -16(%rbp),%rdi
call .D7
.L71:
cmpq $0,%r14
je .L72
movq -40(%rbp),%rdi
call .D3
.L72:
cmpq $0,%r13
je .L73
movq -32(%rbp),%rdi
call .D3
.L73:
cmpq $0,%r12
je .L74
movq -8(%rbp),%rdi
call .D8
.L74:
movq -296(%rbp),%rax
movq -.F34-8(%rbp),%rbx
movq -.F34-16(%rbp),%r12
movq -.F34-24(%rbp),%r13
movq -.F34-32(%rbp),%r14
movq -.F34-40(%rbp),%r15
leave
ret
cmpq $0,-272(%rbp)
je .L75
movq $0,-272(%rbp)
movq -264(%rbp),%rdi
call .D12
.L75:
cmpq $0,-256(%rbp)
je .L76
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D4
.L76:
cmpq $0,-240(%rbp)
je .L77
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D4
.L77:
cmpq $0,-224(%rbp)
je .L78
movq $0,-224(%rbp)
movq -216(%rbp),%rdi
call .D3
.L78:
cmpq $0,-208(%rbp)
je .L79
movq $0,-208(%rbp)
movq -200(%rbp),%rdi
call .D3
.L79:
cmpq $0,-176(%rbp)
je .L80
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L80:
cmpq $0,%rbx
je .L81
movq $0,%rbx
movq -160(%rbp),%rdi
call .D3
.L81:
cmpq $0,-152(%rbp)
je .L82
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D3
.L82:
cmpq $0,-136(%rbp)
je .L83
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D3
.L83:
cmpq $0,-112(%rbp)
je .L84
movq $0,-112(%rbp)
movq -104(%rbp),%rdi
call .D8
.L84:
cmpq $0,-96(%rbp)
je .L85
movq $0,-96(%rbp)
movq -48(%rbp),%rdi
call .D7
.L85:
cmpq $0,-88(%rbp)
je .L86
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D3
.L86:
cmpq $0,-72(%rbp)
je .L87
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D3
.L87:
cmpq $0,%r15
je .L88
movq $0,%r15
movq -16(%rbp),%rdi
call .D7
.L88:
cmpq $0,%r14
je .L89
movq $0,%r14
movq -40(%rbp),%rdi
call .D3
.L89:
cmpq $0,%r13
je .L90
movq $0,%r13
movq -32(%rbp),%rdi
call .D3
.L90:
cmpq $0,%r12
je .L91
movq $0,%r12
movq -8(%rbp),%rdi
call .D8
.L91:
cmpq $0,-272(%rbp)
je .L92
movq $0,-272(%rbp)
movq -264(%rbp),%rdi
call .D12
.L92:
cmpq $0,-256(%rbp)
je .L93
movq $0,-256(%rbp)
movq -248(%rbp),%rdi
call .D4
.L93:
cmpq $0,-240(%rbp)
je .L94
movq $0,-240(%rbp)
movq -232(%rbp),%rdi
call .D4
.L94:
cmpq $0,-224(%rbp)
je .L95
movq $0,-224(%rbp)
movq -216(%rbp),%rdi
call .D3
.L95:
cmpq $0,-208(%rbp)
je .L96
movq $0,-208(%rbp)
movq -200(%rbp),%rdi
call .D3
.L96:
cmpq $0,-176(%rbp)
je .L97
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L97:
cmpq $0,%rbx
je .L98
movq -160(%rbp),%rdi
call .D3
.L98:
cmpq $0,-152(%rbp)
je .L99
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D3
.L99:
cmpq $0,-136(%rbp)
je .L100
movq $0,-136(%rbp)
movq -128(%rbp),%rdi
call .D3
.L100:
cmpq $0,-112(%rbp)
je .L101
movq $0,-112(%rbp)
movq -104(%rbp),%rdi
call .D8
.L101:
cmpq $0,-96(%rbp)
je .L102
movq $0,-96(%rbp)
movq -48(%rbp),%rdi
call .D7
.L102:
cmpq $0,-88(%rbp)
je .L103
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D3
.L103:
cmpq $0,-72(%rbp)
je .L104
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D3
.L104:
cmpq $0,%r15
je .L105
movq -16(%rbp),%rdi
call .D7
.L105:
cmpq $0,%r14
je .L106
movq -40(%rbp),%rdi
call .D3
.L106:
cmpq $0,%r13
je .L107
movq -32(%rbp),%rdi
call .D3
.L107:
cmpq $0,%r12
je .L108
movq -8(%rbp),%rdi
call .D8
.L108:
xorq %rax,%rax
movq -.F34-8(%rbp),%rbx
movq -.F34-16(%rbp),%r12
movq -.F34-24(%rbp),%r13
movq -.F34-32(%rbp),%r14
movq -.F34-40(%rbp),%r15
leave
ret
.set .F34,304
.type rt_abort,@function
rt_abort:
pushq %rbp
movq %rsp,%rbp
subq $.F109,%rsp
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
.set .F109,16
.type rt_error,@function
rt_error:
pushq %rbp
movq %rsp,%rbp
subq $.F110,%rsp
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
.set .F110,16
.type rt_div,@function
rt_div:
pushq %rbp
movq %rsp,%rbp
subq $.F111,%rsp
subq $48,%rsp
movq %rbx,-.F111-8(%rbp)
movq %r12,-.F111-16(%rbp)
movq %r13,-.F111-24(%rbp)
movq %r14,-.F111-32(%rbp)
movq %r15,-.F111-40(%rbp)
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
jne .L112
call rt_abort
jmp .L113
.L112:
.L113:
movq $0,-24(%rbp)
movq -8(%rbp),%rax
movq %rax,-32(%rbp)
.L114:
movq -32(%rbp),%rax
movq -16(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L115
movq -16(%rbp),%rax
movq %rax,%rbx
movq $1,%r12
.L116:
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
jz .L117
movq %rbx,%rax
addq %rbx,%rax
jnc .L118
call rt_abort
.L118:
movq %rax,%rbx
movq %r12,%rax
addq %r12,%rax
jnc .L119
call rt_abort
.L119:
movq %rax,%r12
jmp .L116
.L117:
movq -32(%rbp),%rax
subq %rbx,%rax
jnc .L120
call rt_abort
.L120:
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
addq %r12,%rax
jnc .L121
call rt_abort
.L121:
movq %rax,-24(%rbp)
jmp .L114
.L115:
movq -24(%rbp),%rax
movq -.F111-8(%rbp),%rbx
movq -.F111-16(%rbp),%r12
movq -.F111-24(%rbp),%r13
movq -.F111-32(%rbp),%r14
movq -.F111-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F111-8(%rbp),%rbx
movq -.F111-16(%rbp),%r12
movq -.F111-24(%rbp),%r13
movq -.F111-32(%rbp),%r14
movq -.F111-40(%rbp),%r15
leave
ret
.set .F111,48
.type rt_allocator_lock,@function
rt_allocator_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F122,%rsp
subq $16,%rsp
movq %rbx,-.F122-8(%rbp)
movq %r12,-.F122-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
addq $64,%rax
jnc .L123
call rt_abort
.L123:
movq %rax,%r12
.L124:
movq %r12,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%rbx
cmpq $0,%rax
je .L125
jmp .L124
.L125:
movabsq $0,%rax
movq -.F122-8(%rbp),%rbx
movq -.F122-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F122-8(%rbp),%rbx
movq -.F122-16(%rbp),%r12
leave
ret
.set .F122,16
.type rt_allocator_unlock,@function
rt_allocator_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F126,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $64,%rcx
movq -8(%rbp),%rax
addq $64,%rax
jnc .L127
call rt_abort
.L127:
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
.set .F126,16
.type rt_alloc,@function
rt_alloc:
pushq %rbp
movq %rsp,%rbp
subq $.F128,%rsp
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
.set .F128,16
.type rt_free,@function
rt_free:
pushq %rbp
movq %rsp,%rbp
subq $.F129,%rsp
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
.set .F129,16
.type rt_alloc_unlocked,@function
rt_alloc_unlocked:
pushq %rbp
movq %rsp,%rbp
subq $.F130,%rsp
subq $48,%rsp
movq %rbx,-.F130-8(%rbp)
movq %r12,-.F130-16(%rbp)
movq %r13,-.F130-24(%rbp)
movq %r14,-.F130-32(%rbp)
movq %r15,-.F130-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F130(%rbp),%rdi
movq $.F130/8-1,%rcx
xorl %eax,%eax
rep stosq
leaq rt_state(%rip),%rax
movq %rax,%r14
movq -8(%rbp),%rcx
movabsq $1152921504606846976,%rax
cmpq %rcx,%rax
jae .L131
call rt_abort
jmp .L132
.L131:
.L132:
movq $32,%rbx
movq $0,%r13
.L133:
movq -8(%rbp),%rax
addq $16,%rax
jnc .L135
call rt_abort
.L135:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L134
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L136
call rt_abort
.L136:
movq %rax,%rbx
movq %r13,%rax
addq $1,%rax
jnc .L137
call rt_abort
.L137:
movq %rax,%r13
jmp .L133
.L134:
movq %r14,%rax
addq $256,%rax
jnc .L138
call rt_abort
.L138:
movq %rax,-16(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L139
call rt_abort
.L139:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L140
call rt_abort
.L140:
movq %rax,-24(%rbp)
movq (%rax),%rax
movq %rax,%r15
movq $0,-32(%rbp)
cmpq $0,%rax
je .L141
movq %r15,%rax
addq $8,%rax
jnc .L143
call rt_abort
.L143:
movq (%rax),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $1,-32(%rbp)
jmp .L142
.L141:
movq %r14,%rax
addq $768,%rax
jnc .L144
call rt_abort
.L144:
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L145
call rt_abort
.L145:
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L146
call rt_abort
.L146:
movq %rax,-48(%rbp)
movq %r14,%rax
addq $1280,%rax
jnc .L147
call rt_abort
.L147:
movq %rax,-56(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L148
call rt_abort
.L148:
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L149
call rt_abort
.L149:
movq %rax,-64(%rbp)
movq (%rax),%rax
movq %rax,-72(%rbp)
cmpq $0,%rax
jne .L150
movq $1048576,-80(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L152
call rt_abort
.L152:
movq %rax,%rcx
movabsq $1048576,%rax
cmpq %rcx,%rax
jae .L153
movabsq $16,%rcx
movq %rbx,%rax
addq $16,%rax
jnc .L155
call rt_abort
.L155:
movq %rax,-80(%rbp)
jmp .L154
.L153:
.L154:
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
jmp .Lret_i1
xorq %rax,%rax
jmp .Lret_i1
.Lret_i1:
testq %rax,%rax
jz .L156
call rt_abort
jmp .L157
.L156:
.L157:
movq %r14,%rax
addq $32,%rax
jnc .L158
call rt_abort
.L158:
movq (%rax),%rax
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rcx,%rax
addq $8,%rax
jnc .L159
call rt_abort
.L159:
movq %rax,-96(%rbp)
movq -80(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r14,%rax
addq $32,%rax
jnc .L160
call rt_abort
.L160:
movq %rax,-104(%rbp)
movq -88(%rbp),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $16,%rax
jnc .L161
call rt_abort
.L161:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $16,%rcx
movq -80(%rbp),%rax
subq $16,%rax
jnc .L162
call rt_abort
.L162:
movq %rax,-112(%rbp)
movq -112(%rbp),%rdi
movq %rbx,%rsi
call rt_div
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L151
.L150:
.L151:
movq -48(%rbp),%rax
movq (%rax),%rax
movq %rax,%r15
addq %rbx,%rax
jnc .L163
call rt_abort
.L163:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -64(%rbp),%rax
movq (%rax),%rax
movq %rax,-120(%rbp)
subq $1,%rax
jnc .L164
call rt_abort
.L164:
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
movq %r15,%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
.L142:
movq %r15,%rax
addq $8,%rax
jnc .L165
call rt_abort
.L165:
movq %rax,-128(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %r15,%rax
addq $16,%rax
jnc .L166
call rt_abort
.L166:
movq %rax,-136(%rbp)
movq -32(%rbp),%rax
testq %rax,%rax
jz .L167
movq $0,%r12
.L169:
movq %rbx,%rax
subq $16,%rax
jnc .L171
call rt_abort
.L171:
movq %rax,%rcx
cmpq %rcx,%r12
jae .L170
movq -136(%rbp),%rax
addq %r12,%rax
jnc .L172
call rt_abort
.L172:
movq %rax,-144(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r12,%rax
addq $8,%rax
jnc .L173
call rt_abort
.L173:
movq %rax,%r12
jmp .L169
.L170:
jmp .L168
.L167:
.L168:
movq %r14,%rax
addq $24,%rax
jnc .L174
call rt_abort
.L174:
movq %rax,-152(%rbp)
movq %r14,%rax
addq $24,%rax
jnc .L175
call rt_abort
.L175:
movq (%rax),%rax
movq %rax,-160(%rbp)
addq $1,%rax
jnc .L176
call rt_abort
.L176:
movq -152(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -136(%rbp),%rax
movq -.F130-8(%rbp),%rbx
movq -.F130-16(%rbp),%r12
movq -.F130-24(%rbp),%r13
movq -.F130-32(%rbp),%r14
movq -.F130-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F130-8(%rbp),%rbx
movq -.F130-16(%rbp),%r12
movq -.F130-24(%rbp),%r13
movq -.F130-32(%rbp),%r14
movq -.F130-40(%rbp),%r15
leave
ret
.set .F130,160
.type rt_free_unlocked,@function
rt_free_unlocked:
pushq %rbp
movq %rsp,%rbp
subq $.F177,%rsp
subq $48,%rsp
movq %rbx,-.F177-8(%rbp)
movq %r12,-.F177-16(%rbp)
movq %r13,-.F177-24(%rbp)
movq %r14,-.F177-32(%rbp)
movq %r15,-.F177-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F177(%rbp),%rdi
movq $.F177/8-1,%rcx
xorl %eax,%eax
rep stosq
movq -8(%rbp),%rax
cmpq $0,%rax
jne .L178
movabsq $0,%rax
movq -.F177-8(%rbp),%rbx
movq -.F177-16(%rbp),%r12
movq -.F177-24(%rbp),%r13
movq -.F177-32(%rbp),%r14
movq -.F177-40(%rbp),%r15
leave
ret
jmp .L179
.L178:
.L179:
leaq rt_state(%rip),%rax
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
subq $16,%rax
jnc .L180
call rt_abort
.L180:
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
addq $8,%rax
jnc .L181
call rt_abort
.L181:
movq (%rax),%rax
movq %rax,-40(%rbp)
cmpq $2,%rax
jne .L182
movabsq $0,%rax
movq -.F177-8(%rbp),%rbx
movq -.F177-16(%rbp),%r12
movq -.F177-24(%rbp),%r13
movq -.F177-32(%rbp),%r14
movq -.F177-40(%rbp),%r15
leave
ret
jmp .L183
.L182:
.L183:
movq -24(%rbp),%rax
addq $8,%rax
jnc .L184
call rt_abort
.L184:
movq (%rax),%rax
movq %rax,-48(%rbp)
movabsq $1,%rcx
cmpq $1,%rax
je .L185
call rt_abort
jmp .L186
.L185:
.L186:
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
cmpq $524288,%rax
setb %al
movzbq %al,%rax
movq %rax,-72(%rbp)
cmpq $0,%rax
jne .L187
movq -8(%rbp),%rax
subq $32,%rax
jnc .L189
call rt_abort
.L189:
movq %rax,%r14
movq -16(%rbp),%rax
addq $32,%rax
jnc .L190
call rt_abort
.L190:
movq %rax,%rbx
.L191:
movq %rbx,%rax
movq (%rax),%rax
cmpq %r14,%rax
je .L192
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%r15
movq %rax,-80(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L193
call rt_abort
jmp .L194
.L193:
.L194:
movq %r15,%rbx
jmp .L191
.L192:
movq %r14,%rax
addq $8,%rax
jnc .L195
call rt_abort
.L195:
movq (%rax),%rax
movq %rax,-88(%rbp)
movq %r14,%rax
movq (%rax),%rax
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
addq $24,%rax
jnc .L196
call rt_abort
.L196:
movq %rax,-96(%rbp)
movq -16(%rbp),%rax
addq $24,%rax
jnc .L197
call rt_abort
.L197:
movq (%rax),%rax
movq %rax,-104(%rbp)
subq $1,%rax
jnc .L198
call rt_abort
.L198:
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
jmp .Lret_i2
xorq %rax,%rax
jmp .Lret_i2
.Lret_i2:
testq %rax,%rax
jz .L199
call rt_abort
jmp .L200
.L199:
.L200:
movabsq $0,%rax
movq -.F177-8(%rbp),%rbx
movq -.F177-16(%rbp),%r12
movq -.F177-24(%rbp),%r13
movq -.F177-32(%rbp),%r14
movq -.F177-40(%rbp),%r15
leave
ret
jmp .L188
.L187:
.L188:
movq $32,%r12
movq $0,%r13
.L201:
movq -56(%rbp),%rcx
cmpq %rcx,%r12
jae .L202
movabsq $2,%rcx
movq %r12,%rax
mulq %rcx
jnc .L203
call rt_abort
.L203:
movq %rax,%r12
movq %r13,%rax
addq $1,%rax
jnc .L204
call rt_abort
.L204:
movq %rax,%r13
jmp .L201
.L202:
movq -16(%rbp),%rax
addq $256,%rax
jnc .L205
call rt_abort
.L205:
movq %rax,-112(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L206
call rt_abort
.L206:
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L207
call rt_abort
.L207:
movq %rax,-120(%rbp)
movq -24(%rbp),%rax
addq $8,%rax
jnc .L208
call rt_abort
.L208:
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
jnc .L209
call rt_abort
.L209:
movq %rax,-136(%rbp)
movq -16(%rbp),%rax
addq $24,%rax
jnc .L210
call rt_abort
.L210:
movq (%rax),%rax
movq %rax,-144(%rbp)
subq $1,%rax
jnc .L211
call rt_abort
.L211:
movq -136(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F177-8(%rbp),%rbx
movq -.F177-16(%rbp),%r12
movq -.F177-24(%rbp),%r13
movq -.F177-32(%rbp),%r14
movq -.F177-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F177-8(%rbp),%rbx
movq -.F177-16(%rbp),%r12
movq -.F177-24(%rbp),%r13
movq -.F177-32(%rbp),%r14
movq -.F177-40(%rbp),%r15
leave
ret
.set .F177,144
.type rt_grow,@function
rt_grow:
pushq %rbp
movq %rsp,%rbp
subq $.F212,%rsp
subq $48,%rsp
movq %rbx,-.F212-8(%rbp)
movq %r12,-.F212-16(%rbp)
movq %r13,-.F212-24(%rbp)
movq %r14,-.F212-32(%rbp)
movq %r15,-.F212-40(%rbp)
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
jne .L213
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq -.F212-8(%rbp),%rbx
movq -.F212-16(%rbp),%r12
movq -.F212-24(%rbp),%r13
movq -.F212-32(%rbp),%r14
movq -.F212-40(%rbp),%r15
leave
ret
jmp .L214
.L213:
.L214:
movq %r15,%rax
subq $16,%rax
jnc .L215
call rt_abort
.L215:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
cmpq $524288,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L216
movq -32(%rbp),%rax
movq %rax,%rbx
.L218:
movq -24(%rbp),%rax
addq $16,%rax
jnc .L220
call rt_abort
.L220:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L219
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L221
call rt_abort
.L221:
movq %rax,%rbx
jmp .L218
.L219:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jne .L222
movq %r15,%rax
movq -.F212-8(%rbp),%rbx
movq -.F212-16(%rbp),%r12
movq -.F212-24(%rbp),%r13
movq -.F212-32(%rbp),%r14
movq -.F212-40(%rbp),%r15
leave
ret
jmp .L223
.L222:
.L223:
call rt_allocator_lock
leaq rt_state(%rip),%rax
movq %rax,-56(%rbp)
movq %r15,%rax
subq $32,%rax
jnc .L224
call rt_abort
.L224:
movq %rax,-64(%rbp)
movq -56(%rbp),%rax
addq $32,%rax
jnc .L225
call rt_abort
.L225:
movq %rax,%r12
.L226:
movq %r12,%rax
movq (%rax),%rax
movq -64(%rbp),%rcx
cmpq %rcx,%rax
je .L227
movq %r12,%rax
movq (%rax),%rax
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
jne .L228
call rt_abort
jmp .L229
.L228:
.L229:
movq %r13,%r12
jmp .L226
.L227:
movq -64(%rbp),%rax
addq $8,%rax
jnc .L230
call rt_abort
.L230:
movq (%rax),%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L231
call rt_abort
.L231:
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
jmp .Lret_i3
xorq %rax,%rax
jmp .Lret_i3
.Lret_i3:
testq %rax,%rax
jz .L232
call rt_abort
jmp .L233
.L232:
.L233:
movq -88(%rbp),%rax
movq %r12,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $8,%rax
jnc .L234
call rt_abort
.L234:
movq %rax,-96(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L235
call rt_abort
.L235:
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $16,%rax
jnc .L236
call rt_abort
.L236:
movq %rax,-104(%rbp)
movq %rbx,%rax
movq -104(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
call rt_allocator_unlock
movq -88(%rbp),%rax
addq $32,%rax
jnc .L237
call rt_abort
.L237:
movq -.F212-8(%rbp),%rbx
movq -.F212-16(%rbp),%r12
movq -.F212-24(%rbp),%r13
movq -.F212-32(%rbp),%r14
movq -.F212-40(%rbp),%r15
leave
ret
jmp .L217
.L216:
.L217:
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
movq -.F212-8(%rbp),%rbx
movq -.F212-16(%rbp),%r12
movq -.F212-24(%rbp),%r13
movq -.F212-32(%rbp),%r14
movq -.F212-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F212-8(%rbp),%rbx
movq -.F212-16(%rbp),%r12
movq -.F212-24(%rbp),%r13
movq -.F212-32(%rbp),%r14
movq -.F212-40(%rbp),%r15
leave
ret
.set .F212,128
.type rt_live,@function
rt_live:
pushq %rbp
movq %rsp,%rbp
subq $.F238,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
call rt_allocator_lock
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $24,%rcx
movq -8(%rbp),%rax
addq $24,%rax
jnc .L239
call rt_abort
.L239:
movq (%rax),%rax
movq %rax,-16(%rbp)
call rt_allocator_unlock
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F238,16
.type rt_shutdown,@function
rt_shutdown:
pushq %rbp
movq %rsp,%rbp
subq $.F240,%rsp
subq $32,%rsp
movq %rbx,-.F240-8(%rbp)
movq %r12,-.F240-16(%rbp)
movq %r13,-.F240-24(%rbp)
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
jnc .L241
call rt_abort
.L241:
movq (%rax),%rax
movq %rax,%rbx
.L242:
cmpq $0,%rbx
je .L243
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $8,%rax
jnc .L244
call rt_abort
.L244:
movq (%rax),%rax
movabsq $11,%rdi
movq %rbx,%rsi
movq %rax,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r12,%rbx
jmp .L242
.L243:
movq -8(%rbp),%rax
addq $32,%rax
jnc .L245
call rt_abort
.L245:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movabsq $0,%rax
movq -.F240-8(%rbp),%rbx
movq -.F240-16(%rbp),%r12
movq -.F240-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F240-8(%rbp),%rbx
movq -.F240-16(%rbp),%r12
movq -.F240-24(%rbp),%r13
leave
ret
.set .F240,32
.type rt_new,@function
rt_new:
pushq %rbp
movq %rsp,%rbp
subq $.F246,%rsp
movabsq $24,%rdi
call rt_alloc
leave
ret
xorq %rax,%rax
leave
ret
.set .F246,32
.type rt_push,@function
rt_push:
pushq %rbp
movq %rsp,%rbp
subq $.F247,%rsp
subq $32,%rsp
movq %rbx,-.F247-8(%rbp)
movq %r12,-.F247-16(%rbp)
movq %r13,-.F247-24(%rbp)
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
jnc .L248
call rt_abort
.L248:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L249
call rt_abort
.L249:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L250
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L252
call rt_abort
.L252:
movq %rax,%r13
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L253
movq $8,%r13
jmp .L254
.L253:
.L254:
movq %r13,%rcx
movabsq $144115188075855872,%rax
cmpq %r13,%rax
jae .L255
call rt_abort
jmp .L256
.L255:
.L256:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L257
call rt_abort
.L257:
movq %rax,-48(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L258
call rt_abort
.L258:
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
jnc .L259
call rt_abort
.L259:
movq %rax,-64(%rbp)
movq %r13,%rax
movq -64(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
jmp .L251
.L250:
.L251:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L260
call rt_abort
.L260:
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L261
call rt_abort
.L261:
movq %rax,-80(%rbp)
movq -16(%rbp),%rax
movq -80(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L262
call rt_abort
.L262:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L263
call rt_abort
.L263:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F247-8(%rbp),%rbx
movq -.F247-16(%rbp),%r12
movq -.F247-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F247-8(%rbp),%rbx
movq -.F247-16(%rbp),%r12
movq -.F247-24(%rbp),%r13
leave
ret
.set .F247,96
.type rt_fill,@function
rt_fill:
pushq %rbp
movq %rsp,%rbp
subq $.F264,%rsp
subq $48,%rsp
movq %rbx,-.F264-8(%rbp)
movq %r12,-.F264-16(%rbp)
movq %r13,-.F264-24(%rbp)
movq %r14,-.F264-32(%rbp)
movq %r15,-.F264-40(%rbp)
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
jae .L265
call rt_abort
jmp .L266
.L265:
.L266:
cmpq $0,%r12
je .L267
movq %r13,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L269
call rt_abort
.L269:
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
jnc .L270
call rt_abort
.L270:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L268
.L267:
.L268:
movq $0,%rbx
.L271:
cmpq %r12,%rbx
jae .L272
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r14
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L273
call rt_abort
.L273:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L274
call rt_abort
.L274:
movq %rax,%r15
movq -16(%rbp),%rax
movq %r15,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L275
call rt_abort
.L275:
movq %rax,%rbx
jmp .L271
.L272:
movq %r13,%rax
addq $8,%rax
jnc .L276
call rt_abort
.L276:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movabsq $0,%rax
movq -.F264-8(%rbp),%rbx
movq -.F264-16(%rbp),%r12
movq -.F264-24(%rbp),%r13
movq -.F264-32(%rbp),%r14
movq -.F264-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F264-8(%rbp),%rbx
movq -.F264-16(%rbp),%r12
movq -.F264-24(%rbp),%r13
movq -.F264-32(%rbp),%r14
movq -.F264-40(%rbp),%r15
leave
ret
.set .F264,64
.type rt_fillb,@function
rt_fillb:
pushq %rbp
movq %rsp,%rbp
subq $.F277,%rsp
subq $48,%rsp
movq %rbx,-.F277-8(%rbp)
movq %r12,-.F277-16(%rbp)
movq %r13,-.F277-24(%rbp)
movq %r14,-.F277-32(%rbp)
movq %r15,-.F277-40(%rbp)
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
jae .L278
call rt_abort
jmp .L279
.L278:
.L279:
movq %r13,%rdi
movq %r14,%rsi
call rt_reserveb
movq $0,%rbx
.L280:
cmpq %r14,%rbx
jae .L281
movq %r13,%rax
movq (%rax),%rax
addq %rbx,%rax
jnc .L282
call rt_abort
.L282:
movq %rax,%r12
movq %r15,%rax
movq %r12,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L283
call rt_abort
.L283:
movq %rax,%rbx
jmp .L280
.L281:
movq %r13,%rax
addq $8,%rax
jnc .L284
call rt_abort
.L284:
movq %rax,-32(%rbp)
movq %r14,%rax
movq -32(%rbp),%rcx
movq %r14,(%rcx)
xorq %r14,%rax
movabsq $0,%rax
movq -.F277-8(%rbp),%rbx
movq -.F277-16(%rbp),%r12
movq -.F277-24(%rbp),%r13
movq -.F277-32(%rbp),%r14
movq -.F277-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F277-8(%rbp),%rbx
movq -.F277-16(%rbp),%r12
movq -.F277-24(%rbp),%r13
movq -.F277-32(%rbp),%r14
movq -.F277-40(%rbp),%r15
leave
ret
.set .F277,32
.type rt_pushb,@function
rt_pushb:
pushq %rbp
movq %rsp,%rbp
subq $.F285,%rsp
subq $16,%rsp
movq %rbx,-.F285-8(%rbp)
movq %r12,-.F285-16(%rbp)
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
jnc .L286
call rt_abort
.L286:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L287
call rt_abort
.L287:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L288
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L290
call rt_abort
.L290:
movq %rbx,%rdi
movq %rax,%rsi
call rt_reserveb
jmp .L289
.L288:
.L289:
movq %rbx,%rax
movq (%rax),%rax
addq %r12,%rax
jnc .L291
call rt_abort
.L291:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
andq $255,%rax
movq -32(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L292
call rt_abort
.L292:
movq %rax,-40(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L293
call rt_abort
.L293:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F285-8(%rbp),%rbx
movq -.F285-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F285-8(%rbp),%rbx
movq -.F285-16(%rbp),%r12
leave
ret
.set .F285,48
.type rt_pushb_checked,@function
rt_pushb_checked:
pushq %rbp
movq %rsp,%rbp
subq $.F294,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rcx
movabsq $255,%rax
cmpq %rcx,%rax
jae .L295
call rt_abort
jmp .L296
.L295:
.L296:
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt6
call rt_pushb
jmp .Lopt7
.Lopt6:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt7:
leave
ret
xorq %rax,%rax
leave
ret
.set .F294,16
.type rt_reserveb,@function
rt_reserveb:
pushq %rbp
movq %rsp,%rbp
subq $.F297,%rsp
subq $32,%rsp
movq %rbx,-.F297-8(%rbp)
movq %r12,-.F297-16(%rbp)
movq %r13,-.F297-24(%rbp)
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
jnc .L298
call rt_abort
.L298:
movq (%rax),%rax
movq %rax,-24(%rbp)
addq $1,%rax
jnc .L299
call rt_abort
.L299:
movq %rax,%rcx
cmpq %rcx,%r13
jae .L300
movabsq $0,%rax
movq -.F297-8(%rbp),%rbx
movq -.F297-16(%rbp),%r12
movq -.F297-24(%rbp),%r13
leave
ret
jmp .L301
.L300:
.L301:
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L302
call rt_abort
.L302:
movq %rax,%rbx
movq %rax,-32(%rbp)
cmpq $16,%rax
jae .L303
movq $16,%rbx
jmp .L304
.L303:
.L304:
.L305:
cmpq %r13,%rbx
jae .L306
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L307
call rt_abort
.L307:
movq %rax,%rbx
jmp .L305
.L306:
movq %rbx,%rcx
movabsq $1152921504606846976,%rax
cmpq %rbx,%rax
jae .L308
call rt_abort
jmp .L309
.L308:
.L309:
movabsq $8,%rcx
movq %r12,%rax
addq $8,%rax
jnc .L310
call rt_abort
.L310:
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
jnc .L311
call rt_abort
.L311:
movq %rax,-64(%rbp)
movq %rbx,%rax
movq -64(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movabsq $0,%rax
movq -.F297-8(%rbp),%rbx
movq -.F297-16(%rbp),%r12
movq -.F297-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F297-8(%rbp),%rbx
movq -.F297-16(%rbp),%r12
movq -.F297-24(%rbp),%r13
leave
ret
.set .F297,64
.type rt_copy_bytes,@function
rt_copy_bytes:
pushq %rbp
movq %rsp,%rbp
subq $.F312,%rsp
subq $48,%rsp
movq %rbx,-.F312-8(%rbp)
movq %r12,-.F312-16(%rbp)
movq %r13,-.F312-24(%rbp)
movq %r14,-.F312-32(%rbp)
movq %r15,-.F312-40(%rbp)
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
.L313:
movq %rbx,%rax
addq $8,%rax
jnc .L315
call rt_abort
.L315:
movq %rax,%r15
movq %r14,%rax
addq $1,%rax
jnc .L316
call rt_abort
.L316:
movq %rax,%rcx
cmpq %rcx,%r15
jae .L314
movq %r12,%rax
addq %rbx,%rax
jnc .L317
call rt_abort
.L317:
movq %rax,-32(%rbp)
movq %r13,%rax
addq %rbx,%rax
jnc .L318
call rt_abort
.L318:
movq (%rax),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L319
call rt_abort
.L319:
movq %rax,%rbx
jmp .L313
.L314:
.L320:
cmpq %r14,%rbx
jae .L321
movq %r12,%rax
addq %rbx,%rax
jnc .L322
call rt_abort
.L322:
movq %rax,-40(%rbp)
movq %r13,%rax
addq %rbx,%rax
jnc .L323
call rt_abort
.L323:
movzbq (%rax),%rax
movq -40(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L324
call rt_abort
.L324:
movq %rax,%rbx
jmp .L320
.L321:
movabsq $0,%rax
movq -.F312-8(%rbp),%rbx
movq -.F312-16(%rbp),%r12
movq -.F312-24(%rbp),%r13
movq -.F312-32(%rbp),%r14
movq -.F312-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F312-8(%rbp),%rbx
movq -.F312-16(%rbp),%r12
movq -.F312-24(%rbp),%r13
movq -.F312-32(%rbp),%r14
movq -.F312-40(%rbp),%r15
leave
ret
.set .F312,48
.type rt_bytes_truncate,@function
rt_bytes_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F325,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L326
call rt_abort
.L326:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
jae .L327
movq -8(%rbp),%rax
addq $8,%rax
jnc .L329
call rt_abort
.L329:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L328
.L327:
.L328:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F325,32
.type rt_popb,@function
rt_popb:
pushq %rbp
movq %rsp,%rbp
subq $.F330,%rsp
subq $16,%rsp
movq %rbx,-.F330-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L331
call rt_abort
.L331:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L332
call rt_abort
jmp .L333
.L332:
.L333:
movq %rbx,%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L334
call rt_abort
.L334:
movq %rax,-32(%rbp)
subq $1,%rax
jnc .L335
call rt_abort
.L335:
movzbq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L336
call rt_abort
.L336:
movq %rax,-48(%rbp)
movq %rcx,%rax
subq $1,%rax
jnc .L337
call rt_abort
.L337:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F330-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F330-8(%rbp),%rbx
leave
ret
.set .F330,48
.type rt_random_seed,@function
rt_random_seed:
pushq %rbp
movq %rsp,%rbp
subq $.F338,%rsp
subq $48,%rsp
movq %rbx,-.F338-8(%rbp)
movq %r12,-.F338-16(%rbp)
movq %r13,-.F338-24(%rbp)
movq %r14,-.F338-32(%rbp)
movq %r15,-.F338-40(%rbp)
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
.L339:
movabsq $8,%rcx
cmpq $8,%rbx
jae .L340
movq $318,%r13
movabsq $0,%rax
cmpq $0,%rax
je .L341
movq $278,%r13
jmp .L342
.L341:
.L342:
movq -8(%rbp),%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L343
call rt_abort
.L343:
movq %rax,%r14
movabsq $8,%rax
subq %rbx,%rax
jnc .L344
call rt_abort
.L344:
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
jne .L345
jmp .L346
.L345:
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $8,%rax
subq %rbx,%rax
jnc .L347
call rt_abort
.L347:
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L348
call rt_abort
.L348:
testq %rax,%rax
jz .L349
call rt_abort
jmp .L350
.L349:
.L350:
movq %rbx,%rax
addq %r12,%rax
jnc .L351
call rt_abort
.L351:
movq %rax,%rbx
.L346:
jmp .L339
.L340:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F338-8(%rbp),%rbx
movq -.F338-16(%rbp),%r12
movq -.F338-24(%rbp),%r13
movq -.F338-32(%rbp),%r14
movq -.F338-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F338-8(%rbp),%rbx
movq -.F338-16(%rbp),%r12
movq -.F338-24(%rbp),%r13
movq -.F338-32(%rbp),%r14
movq -.F338-40(%rbp),%r15
leave
ret
.set .F338,32
.type rt_slotu,@function
rt_slotu:
pushq %rbp
movq %rsp,%rbp
subq $.F352,%rsp
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
jnc .L353
call rt_abort
.L353:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L354
call rt_abort
.L354:
leave
ret
xorq %rax,%rax
leave
ret
.set .F352,32
.type rt_slotb,@function
rt_slotb:
pushq %rbp
movq %rsp,%rbp
subq $.F355,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L356
call rt_abort
.L356:
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
jne .L357
call rt_abort
jmp .L358
.L357:
.L358:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L359
call rt_abort
.L359:
leave
ret
xorq %rax,%rax
leave
ret
.set .F355,32
.type rt_atbu,@function
rt_atbu:
pushq %rbp
movq %rsp,%rbp
subq $.F360,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L361
call rt_abort
.L361:
movzbq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F360,16
.type rt_atb,@function
rt_atb:
pushq %rbp
movq %rsp,%rbp
subq $.F362,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L363
call rt_abort
.L363:
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
jne .L364
call rt_abort
jmp .L365
.L364:
.L365:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L366
call rt_abort
.L366:
movzbq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F362,32
.type rt_pop,@function
rt_pop:
pushq %rbp
movq %rsp,%rbp
subq $.F367,%rsp
subq $16,%rsp
movq %rbx,-.F367-8(%rbp)
movq %r12,-.F367-16(%rbp)
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
jnc .L368
call rt_abort
.L368:
movq (%rax),%rax
movq %rax,%r12
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L369
call rt_abort
jmp .L370
.L369:
.L370:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L371
call rt_abort
.L371:
movq %rax,-32(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L372
call rt_abort
.L372:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L373
call rt_abort
.L373:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-48(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L374
call rt_abort
.L374:
movq %rax,-56(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L375
call rt_abort
.L375:
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L376
call rt_abort
.L376:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L377
call rt_abort
.L377:
movq %rax,-72(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L378
call rt_abort
.L378:
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F367-8(%rbp),%rbx
movq -.F367-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F367-8(%rbp),%rbx
movq -.F367-16(%rbp),%r12
leave
ret
.set .F367,80
.type rt_len,@function
rt_len:
pushq %rbp
movq %rsp,%rbp
subq $.F379,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L380
call rt_abort
.L380:
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F379,16
.type rt_slot,@function
rt_slot:
pushq %rbp
movq %rsp,%rbp
subq $.F381,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L382
call rt_abort
.L382:
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
jne .L383
call rt_abort
jmp .L384
.L383:
.L384:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L385
call rt_abort
.L385:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L386
call rt_abort
.L386:
leave
ret
xorq %rax,%rax
leave
ret
.set .F381,32
.type rt_take,@function
rt_take:
pushq %rbp
movq %rsp,%rbp
subq $.F387,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt8
call rt_abort
.Lopt8:
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
.set .F387,32
.type rt_at,@function
rt_at:
pushq %rbp
movq %rsp,%rbp
subq $.F388,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt10
call rt_abort
.Lopt10:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F388,16
.type rt_write,@function
rt_write:
pushq %rbp
movq %rsp,%rbp
subq $.F389,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L390
call rt_abort
.L390:
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
jnc .L391
call rt_abort
.L391:
testq %rax,%rax
jz .L392
call rt_abort
jmp .L393
.L392:
.L393:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L394
call rt_abort
.L394:
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
.set .F389,48
.type rt_slice,@function
rt_slice:
pushq %rbp
movq %rsp,%rbp
subq $.F395,%rsp
subq $16,%rsp
movq %rbx,-.F395-8(%rbp)
movq %r12,-.F395-16(%rbp)
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
jnc .L396
call rt_abort
.L396:
movq (%rax),%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L397
call rt_abort
.L397:
testq %rax,%rax
jz .L398
call rt_abort
jmp .L399
.L398:
.L399:
movabsq $24,%rdi
call rt_alloc
movq %rax,-40(%rbp)
movq %rax,-48(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
addq %rbx,%rax
jnc .L400
call rt_abort
.L400:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
addq $8,%rax
jnc .L401
call rt_abort
.L401:
movq %rax,-56(%rbp)
movq %r12,%rax
subq %rbx,%rax
jnc .L402
call rt_abort
.L402:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F395-8(%rbp),%rbx
movq -.F395-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F395-8(%rbp),%rbx
movq -.F395-16(%rbp),%r12
leave
ret
.set .F395,64
.type rt_vslice,@function
rt_vslice:
pushq %rbp
movq %rsp,%rbp
subq $.F403,%rsp
subq $16,%rsp
movq %rbx,-.F403-8(%rbp)
movq %r12,-.F403-16(%rbp)
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
jnc .L404
call rt_abort
.L404:
movq (%rax),%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L405
call rt_abort
.L405:
testq %rax,%rax
jz .L406
call rt_abort
jmp .L407
.L406:
.L407:
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
jnc .L408
call rt_abort
.L408:
movq %rax,%rcx
movq -64(%rbp),%rax
addq %rcx,%rax
jnc .L409
call rt_abort
.L409:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
addq $8,%rax
jnc .L410
call rt_abort
.L410:
movq %rax,-72(%rbp)
movq %r12,%rax
subq %rbx,%rax
jnc .L411
call rt_abort
.L411:
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
movq -.F403-8(%rbp),%rbx
movq -.F403-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F403-8(%rbp),%rbx
movq -.F403-16(%rbp),%r12
leave
ret
.set .F403,80
.type rt_view,@function
rt_view:
pushq %rbp
movq %rsp,%rbp
subq $.F412,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L413
call rt_abort
.L413:
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
.set .F412,16
.type rt_load_sized,@function
rt_load_sized:
pushq %rbp
movq %rsp,%rbp
subq $.F414,%rsp
subq $48,%rsp
movq %rbx,-.F414-8(%rbp)
movq %r12,-.F414-16(%rbp)
movq %r13,-.F414-24(%rbp)
movq %r14,-.F414-32(%rbp)
movq %r15,-.F414-40(%rbp)
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
.L415:
cmpq %r14,%rbx
jae .L416
movq %r15,%rax
addq %rbx,%rax
jnc .L417
call rt_abort
.L417:
movzbq (%rax),%rax
movq %r12,%rcx
mulq %rcx
jnc .L418
call rt_abort
.L418:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L419
call rt_abort
.L419:
movq %rax,%r13
movabsq $256,%rcx
movq %r12,%rax
mulq %rcx
jnc .L420
call rt_abort
.L420:
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L421
call rt_abort
.L421:
movq %rax,%rbx
jmp .L415
.L416:
movq %r14,%rax
cmpq $8,%r14
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L422
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L424:
movq %rax,%rcx
cmpq %rcx,%r13
jb .L425
movq %r13,%rax
subq %r12,%rax
movq %rax,%r13
jmp .L426
.L425:
.L426:
jmp .L423
.L422:
.L423:
movq %r13,%rax
movq -.F414-8(%rbp),%rbx
movq -.F414-16(%rbp),%r12
movq -.F414-24(%rbp),%r13
movq -.F414-32(%rbp),%r14
movq -.F414-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F414-8(%rbp),%rbx
movq -.F414-16(%rbp),%r12
movq -.F414-24(%rbp),%r13
movq -.F414-32(%rbp),%r14
movq -.F414-40(%rbp),%r15
leave
ret
.set .F414,32
.type rt_store_sized,@function
rt_store_sized:
pushq %rbp
movq %rsp,%rbp
subq $.F427,%rsp
subq $48,%rsp
movq %rbx,-.F427-8(%rbp)
movq %r12,-.F427-16(%rbp)
movq %r13,-.F427-24(%rbp)
movq %r14,-.F427-32(%rbp)
movq %r15,-.F427-40(%rbp)
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
.L428:
cmpq %r15,%rbx
jae .L429
movq %r14,%rax
addq %rbx,%rax
jnc .L430
call rt_abort
.L430:
movq %rax,%r13
movq %r12,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L431:
movq %r13,%rcx
movq %rdx,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L432:
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L433
call rt_abort
.L433:
movq %rax,%rbx
jmp .L428
.L429:
movabsq $0,%rax
movq -.F427-8(%rbp),%rbx
movq -.F427-16(%rbp),%r12
movq -.F427-24(%rbp),%r13
movq -.F427-32(%rbp),%r14
movq -.F427-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F427-8(%rbp),%rbx
movq -.F427-16(%rbp),%r12
movq -.F427-24(%rbp),%r13
movq -.F427-32(%rbp),%r14
movq -.F427-40(%rbp),%r15
leave
ret
.set .F427,32
.type rt_f32_bits,@function
rt_f32_bits:
pushq %rbp
movq %rsp,%rbp
subq $.F434,%rsp
subq $48,%rsp
movq %rbx,-.F434-8(%rbp)
movq %r12,-.F434-16(%rbp)
movq %r13,-.F434-24(%rbp)
movq %r14,-.F434-32(%rbp)
movq %r15,-.F434-40(%rbp)
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
jnc .L435
call rt_abort
.L435:
movabsq $63,%rcx
movq %r14,%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
movabsq $63,%rax
cmpq $31,%rax
jnc .L436
call rt_abort
.L436:
movabsq $31,%rcx
movq -16(%rbp),%rax
shlq %cl,%rax
movq %rax,%r12
movabsq $63,%rax
cmpq $52,%rax
jnc .L437
call rt_abort
.L437:
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
jne .L438
movabsq $63,%rax
cmpq $29,%rax
jnc .L440
call rt_abort
.L440:
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
jz .L441
movq $4194304,%r15
jmp .L442
.L441:
.L442:
movq %r12,%rax
orq $2139095040,%rax
orq %r15,%rax
movq -.F434-8(%rbp),%rbx
movq -.F434-16(%rbp),%r12
movq -.F434-24(%rbp),%r13
movq -.F434-32(%rbp),%r14
movq -.F434-40(%rbp),%r15
leave
ret
jmp .L439
.L438:
.L439:
cmpq $0,%rbx
jne .L443
movq %r12,%rax
movq -.F434-8(%rbp),%rbx
movq -.F434-16(%rbp),%r12
movq -.F434-24(%rbp),%r13
movq -.F434-32(%rbp),%r14
movq -.F434-40(%rbp),%r15
leave
ret
jmp .L444
.L443:
.L444:
movabsq $896,%rax
cmpq %rbx,%rax
jae .L445
movq %rbx,%rax
subq $896,%rax
jnc .L447
call rt_abort
.L447:
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $23,%rax
jnc .L448
call rt_abort
.L448:
movabsq $23,%rcx
movq -40(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L449
call rt_abort
.L449:
movabsq $29,%rcx
movq %r13,%rax
shrq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F434-8(%rbp),%rbx
movq -.F434-16(%rbp),%r12
movq -.F434-24(%rbp),%r13
movq -.F434-32(%rbp),%r14
movq -.F434-40(%rbp),%r15
leave
ret
jmp .L446
.L445:
.L446:
movabsq $897,%rax
subq %rbx,%rax
jnc .L450
call rt_abort
.L450:
movq %rax,-56(%rbp)
movabsq $4503599627370496,%rcx
movq %r13,%rax
orq %rcx,%rax
movq %rax,-64(%rbp)
movq -56(%rbp),%rcx
movabsq $29,%rax
addq %rcx,%rax
jnc .L451
call rt_abort
.L451:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L452
call rt_abort
.L452:
movq -64(%rbp),%rax
shrq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
orq %rcx,%rax
movq -.F434-8(%rbp),%rbx
movq -.F434-16(%rbp),%r12
movq -.F434-24(%rbp),%r13
movq -.F434-32(%rbp),%r14
movq -.F434-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F434-8(%rbp),%rbx
movq -.F434-16(%rbp),%r12
movq -.F434-24(%rbp),%r13
movq -.F434-32(%rbp),%r14
movq -.F434-40(%rbp),%r15
leave
ret
.set .F434,80
.type rt_f32_from_bits,@function
rt_f32_from_bits:
pushq %rbp
movq %rsp,%rbp
subq $.F453,%rsp
subq $48,%rsp
movq %rbx,-.F453-8(%rbp)
movq %r12,-.F453-16(%rbp)
movq %r13,-.F453-24(%rbp)
movq %r14,-.F453-32(%rbp)
movq %r15,-.F453-40(%rbp)
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
jnc .L454
call rt_abort
.L454:
movabsq $31,%rcx
movq -8(%rbp),%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
andq $1,%rax
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $63,%rax
jnc .L455
call rt_abort
.L455:
movabsq $63,%rcx
movq -24(%rbp),%rax
shlq %cl,%rax
movq %rax,%r15
movabsq $63,%rax
cmpq $23,%rax
jnc .L456
call rt_abort
.L456:
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
jne .L457
movabsq $9218868437227405312,%rcx
movq %r15,%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L459
call rt_abort
.L459:
movabsq $29,%rcx
movq %r12,%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F453-8(%rbp),%rbx
movq -.F453-16(%rbp),%r12
movq -.F453-24(%rbp),%r13
movq -.F453-32(%rbp),%r14
movq -.F453-40(%rbp),%r15
leave
ret
jmp .L458
.L457:
.L458:
movq -40(%rbp),%rax
cmpq $0,%rax
jne .L460
cmpq $0,%r12
jne .L462
movq %r15,%rax
movq -.F453-8(%rbp),%rbx
movq -.F453-16(%rbp),%r12
movq -.F453-24(%rbp),%r13
movq -.F453-32(%rbp),%r14
movq -.F453-40(%rbp),%r15
leave
ret
jmp .L463
.L462:
.L463:
movq $22,%rbx
.L464:
movq %rbx,%rcx
movabsq $63,%rax
cmpq %rbx,%rax
jnc .L466
call rt_abort
.L466:
movq %r12,%rax
shrq %cl,%rax
andq $1,%rax
cmpq $0,%rax
jne .L465
movq %rbx,%rax
subq $1,%rax
jnc .L467
call rt_abort
.L467:
movq %rax,%rbx
jmp .L464
.L465:
movq %rbx,%rcx
movabsq $63,%rax
cmpq %rbx,%rax
jnc .L468
call rt_abort
.L468:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
subq %rcx,%rax
jnc .L469
call rt_abort
.L469:
movq %rax,-56(%rbp)
movabsq $52,%rax
subq %rbx,%rax
jnc .L470
call rt_abort
.L470:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L471
call rt_abort
.L471:
movq -56(%rbp),%rax
shlq %cl,%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $874,%rax
jnc .L472
call rt_abort
.L472:
movq %rax,-80(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L473
call rt_abort
.L473:
movabsq $52,%rcx
movq -80(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r15,%rax
orq %rcx,%rax
movq -72(%rbp),%rcx
orq %rcx,%rax
movq -.F453-8(%rbp),%rbx
movq -.F453-16(%rbp),%r12
movq -.F453-24(%rbp),%r13
movq -.F453-32(%rbp),%r14
movq -.F453-40(%rbp),%r15
leave
ret
jmp .L461
.L460:
.L461:
movq -40(%rbp),%rax
addq $896,%rax
jnc .L474
call rt_abort
.L474:
movq %rax,-88(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L475
call rt_abort
.L475:
movabsq $52,%rcx
movq -88(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r15,%rax
orq %rcx,%rax
movq %rax,-96(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L476
call rt_abort
.L476:
movabsq $29,%rcx
movq %r12,%rax
shlq %cl,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
orq %rcx,%rax
movq -.F453-8(%rbp),%rbx
movq -.F453-16(%rbp),%r12
movq -.F453-24(%rbp),%r13
movq -.F453-32(%rbp),%r14
movq -.F453-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F453-8(%rbp),%rbx
movq -.F453-16(%rbp),%r12
movq -.F453-24(%rbp),%r13
movq -.F453-32(%rbp),%r14
movq -.F453-40(%rbp),%r15
leave
ret
.set .F453,96
.type rt_view_ptr,@function
rt_view_ptr:
pushq %rbp
movq %rsp,%rbp
subq $.F477,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F477,16
.type rt_cstr_view,@function
rt_cstr_view:
pushq %rbp
movq %rsp,%rbp
subq $.F478,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L479
call rt_abort
.L479:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L480
call rt_abort
jmp .L481
.L480:
.L481:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L482
call rt_abort
.L482:
movq %rax,-40(%rbp)
movq -40(%rbp),%rax
subq $1,%rax
jnc .L483
call rt_abort
.L483:
movzbq (%rax),%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
je .L484
call rt_abort
jmp .L485
.L484:
.L485:
movq -32(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F478,48
.type rt_append,@function
rt_append:
pushq %rbp
movq %rsp,%rbp
subq $.F486,%rsp
subq $32,%rsp
movq %rbx,-.F486-8(%rbp)
movq %r12,-.F486-16(%rbp)
movq %r13,-.F486-24(%rbp)
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
jnc .L487
call rt_abort
.L487:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $8,%rax
jnc .L488
call rt_abort
.L488:
movq (%rax),%rax
movq %rax,%r13
movq %r12,%rcx
addq %r12,%rax
jnc .L489
call rt_abort
.L489:
movq %rbx,%rdi
movq %rax,%rsi
call rt_reserveb
movq %rbx,%rax
movq (%rax),%rax
movq %r13,%rcx
addq %r13,%rax
jnc .L490
call rt_abort
.L490:
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
jnc .L491
call rt_abort
.L491:
movq %rax,-40(%rbp)
movq %r13,%rax
addq %r12,%rax
jnc .L492
call rt_abort
.L492:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F486-8(%rbp),%rbx
movq -.F486-16(%rbp),%r12
movq -.F486-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F486-8(%rbp),%rbx
movq -.F486-16(%rbp),%r12
movq -.F486-24(%rbp),%r13
leave
ret
.set .F486,48
.type rt_copy,@function
rt_copy:
pushq %rbp
movq %rsp,%rbp
subq $.F493,%rsp
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
.set .F493,32
.type rt_vec_copy,@function
rt_vec_copy:
pushq %rbp
movq %rsp,%rbp
subq $.F494,%rsp
subq $48,%rsp
movq %rbx,-.F494-8(%rbp)
movq %r12,-.F494-16(%rbp)
movq %r13,-.F494-24(%rbp)
movq %r14,-.F494-32(%rbp)
movq %r15,-.F494-40(%rbp)
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
jnc .L495
call rt_abort
.L495:
movq (%rax),%rax
movq %rax,%r15
movq $0,%rbx
.L496:
cmpq %r15,%rbx
jae .L497
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L498
call rt_abort
.L498:
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L499
call rt_abort
.L499:
movq (%rax),%rax
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt12
call rt_push
jmp .Lopt13
.Lopt12:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt13:
movq %rbx,%rax
addq $1,%rax
jnc .L500
call rt_abort
.L500:
movq %rax,%rbx
jmp .L496
.L497:
movq %r14,%rax
movq -.F494-8(%rbp),%rbx
movq -.F494-16(%rbp),%r12
movq -.F494-24(%rbp),%r13
movq -.F494-32(%rbp),%r14
movq -.F494-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F494-8(%rbp),%rbx
movq -.F494-16(%rbp),%r12
movq -.F494-24(%rbp),%r13
movq -.F494-32(%rbp),%r14
movq -.F494-40(%rbp),%r15
leave
ret
.set .F494,16
.type rt_lit,@function
rt_lit:
pushq %rbp
movq %rsp,%rbp
subq $.F501,%rsp
subq $16,%rsp
movq %rbx,-.F501-8(%rbp)
movq %r12,-.F501-16(%rbp)
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
jnc .L502
call rt_abort
.L502:
movq %rax,-40(%rbp)
movq %rbx,%rax
movq -40(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movq %r12,%rax
movq -.F501-8(%rbp),%rbx
movq -.F501-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F501-8(%rbp),%rbx
movq -.F501-16(%rbp),%r12
leave
ret
.set .F501,48
.type rt_rec,@function
rt_rec:
pushq %rbp
movq %rsp,%rbp
subq $.F503,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $144115188075855872,%rax
cmpq %rcx,%rax
jae .L504
call rt_abort
jmp .L505
.L504:
.L505:
movabsq $8,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L506
call rt_abort
.L506:
movq %rax,%rdi
call rt_alloc
leave
ret
xorq %rax,%rax
leave
ret
.set .F503,16
.type rt_enum,@function
rt_enum:
pushq %rbp
movq %rsp,%rbp
subq $.F507,%rsp
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
jnc .L508
call rt_abort
.L508:
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
.set .F507,48
.type rt_enum_retag,@function
rt_enum_retag:
pushq %rbp
movq %rsp,%rbp
subq $.F509,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L510
call rt_abort
.L510:
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
.set .F509,32
.type rt_xchg,@function
rt_xchg:
pushq %rbp
movq %rsp,%rbp
subq $.F511,%rsp
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
.set .F511,32
.type rt_drop_seq,@function
rt_drop_seq:
pushq %rbp
movq %rsp,%rbp
subq $.F512,%rsp
subq $16,%rsp
movq %rbx,-.F512-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rbx
je .L513
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_free
jmp .L514
.L513:
.L514:
movabsq $0,%rax
movq -.F512-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F512-8(%rbp),%rbx
leave
ret
.set .F512,16
.type rt_pack,@function
rt_pack:
pushq %rbp
movq %rsp,%rbp
subq $.F515,%rsp
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
jnc .L516
call rt_abort
.L516:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $1,%rcx
movq -24(%rbp),%rax
addq $1,%rax
jnc .L517
call rt_abort
.L517:
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
jnc .L518
call rt_abort
.L518:
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
.set .F515,64
.type rt_cstr,@function
rt_cstr:
pushq %rbp
movq %rsp,%rbp
subq $.F519,%rsp
subq $32,%rsp
movq %rbx,-.F519-8(%rbp)
movq %r12,-.F519-16(%rbp)
movq %r13,-.F519-24(%rbp)
movq %r14,-.F519-32(%rbp)
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
jnc .L520
call rt_abort
.L520:
movq (%rax),%rax
movq %rax,%r14
movq $0,%rbx
.L521:
cmpq %r14,%rbx
jae .L522
movq %r12,%rax
addq %rbx,%rax
jnc .L523
call rt_abort
.L523:
movzbq (%rax),%rax
movabsq $0,%rcx
cmpq $0,%rax
jne .L524
movq %r12,%rdi
call rt_free
movabsq $0,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
leave
ret
jmp .L525
.L524:
.L525:
movq %rbx,%rax
addq $1,%rax
jnc .L526
call rt_abort
.L526:
movq %rax,%rbx
jmp .L521
.L522:
movq %r12,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F519-8(%rbp),%rbx
movq -.F519-16(%rbp),%r12
movq -.F519-24(%rbp),%r13
movq -.F519-32(%rbp),%r14
leave
ret
.set .F519,16
.type f_host_target,@function
f_host_target:
pushq %rbp
movq %rsp,%rbp
subq $.F527,%rsp
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F527,16
.type f_host_argc,@function
f_host_argc:
pushq %rbp
movq %rsp,%rbp
subq $.F528,%rsp
leaq rt_state(%rip),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F528,32
.type f_host_arg,@function
f_host_arg:
pushq %rbp
movq %rsp,%rbp
subq $.F529,%rsp
subq $32,%rsp
movq %rbx,-.F529-8(%rbp)
movq %r12,-.F529-16(%rbp)
movq %r13,-.F529-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
leaq rt_state(%rip),%rax
movq (%rax),%rax
jmp .Lret_i4
xorq %rax,%rax
jmp .Lret_i4
.Lret_i4:
movq %rax,%rcx
movq -8(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L530
call rt_abort
jmp .L531
.L530:
.L531:
leaq rt_state(%rip),%rax
movq %rax,-24(%rbp)
addq $8,%rax
jnc .L532
call rt_abort
.L532:
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L533
call rt_abort
.L533:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L534
call rt_abort
.L534:
movq (%rax),%rax
movq %rax,%r13
movq $0,%rbx
.L535:
movq %r13,%rax
addq %rbx,%rax
jnc .L537
call rt_abort
.L537:
movzbq (%rax),%rax
movabsq $0,%rcx
cmpq $0,%rax
je .L536
movq %rbx,%rax
addq $1,%rax
jnc .L538
call rt_abort
.L538:
movq %rax,%rbx
jmp .L535
.L536:
movq %r13,%rdi
movq %rbx,%rsi
call rt_lit
movq -.F529-8(%rbp),%rbx
movq -.F529-16(%rbp),%r12
movq -.F529-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F529-8(%rbp),%rbx
movq -.F529-16(%rbp),%r12
movq -.F529-24(%rbp),%r13
leave
ret
.set .F529,32
.type f_host_read_file,@function
f_host_read_file:
pushq %rbp
movq %rsp,%rbp
subq $.F539,%rsp
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
jne .L933_i5
movabsq $0,%rax
jmp .Lret_i5
jmp .L934_i5
.L933_i5:
.L934_i5:
movq %r8,%rax
addq $16,%rax
jnc .L935_i5
call rt_abort
.L935_i5:
movq (%rax),%rax
jmp .Lret_i5
xorq %rax,%rax
jmp .Lret_i5
.Lret_i5:
movq %rax,-16(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
je .L540
leaq rt_read_file_blocking(%rip),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
call rt_offload
leave
ret
jmp .L541
.L540:
.L541:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_read_file_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F539,32
.type rt_read_file_blocking,@function
rt_read_file_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F542,%rsp
subq $48,%rsp
movq %rbx,-.F542-8(%rbp)
movq %r12,-.F542-16(%rbp)
movq %r13,-.F542-24(%rbp)
movq %r14,-.F542-32(%rbp)
movq %r15,-.F542-40(%rbp)
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
jne .L543
call rt_abort
jmp .L544
.L543:
.L544:
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
jmp .Lret_i6
xorq %rax,%rax
jmp .Lret_i6
.Lret_i6:
testq %rax,%rax
jz .L545
call rt_abort
jmp .L546
.L545:
.L546:
movabsq $4096,%rdi
call rt_alloc
movq %rax,%r13
call rt_new
movq %rax,-24(%rbp)
.L547:
movabsq $1,%rax
testq %rax,%rax
jz .L548
movabsq $0,%rdi
movq %r15,%rsi
movq %r13,%rdx
movabsq $4096,%rcx
call rt_syscall
movq %rax,%r12
cmpq $0,%rax
jne .L549
jmp .L548
jmp .L550
.L549:
.L550:
movabsq $0,%rax
subq $4,%rax
movq %rax,%rcx
cmpq %rcx,%r12
jne .L551
jmp .L547
jmp .L552
.L551:
.L552:
movq %r12,%rdi
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
jz .L553
call rt_abort
jmp .L554
.L553:
.L554:
movq $0,%rbx
.L555:
cmpq %r12,%rbx
jae .L556
movq %r13,%rax
addq %rbx,%rax
jnc .L557
call rt_abort
.L557:
movzbq (%rax),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt14
call rt_pushb
jmp .Lopt15
.Lopt14:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt15:
movq %rbx,%rax
addq $1,%rax
jnc .L558
call rt_abort
.L558:
movq %rax,%rbx
jmp .L555
.L556:
jmp .L547
.L548:
movabsq $3,%rdi
movq %r15,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r13,%rdi
call rt_free
movq -24(%rbp),%rax
movq -.F542-8(%rbp),%rbx
movq -.F542-16(%rbp),%r12
movq -.F542-24(%rbp),%r13
movq -.F542-32(%rbp),%r14
movq -.F542-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F542-8(%rbp),%rbx
movq -.F542-16(%rbp),%r12
movq -.F542-24(%rbp),%r13
movq -.F542-32(%rbp),%r14
movq -.F542-40(%rbp),%r15
leave
ret
.set .F542,32
.type rt_write_all,@function
rt_write_all:
pushq %rbp
movq %rsp,%rbp
subq $.F559,%rsp
subq $48,%rsp
movq %rbx,-.F559-8(%rbp)
movq %r12,-.F559-16(%rbp)
movq %r13,-.F559-24(%rbp)
movq %r14,-.F559-32(%rbp)
movq %r15,-.F559-40(%rbp)
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
.L560:
cmpq %r12,%rbx
jae .L561
movq -16(%rbp),%rax
addq %rbx,%rax
jnc .L562
call rt_abort
.L562:
movq %rax,%r13
movq %r12,%rax
subq %rbx,%rax
jnc .L563
call rt_abort
.L563:
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
jne .L564
jmp .L560
jmp .L565
.L564:
.L565:
movq %r14,%rdi
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
jz .L566
movabsq $0,%rax
subq %r14,%rax
movq -.F559-8(%rbp),%rbx
movq -.F559-16(%rbp),%r12
movq -.F559-24(%rbp),%r13
movq -.F559-32(%rbp),%r14
movq -.F559-40(%rbp),%r15
leave
ret
jmp .L567
.L566:
.L567:
cmpq $0,%r14
jne .L568
movabsq $5,%rax
movq -.F559-8(%rbp),%rbx
movq -.F559-16(%rbp),%r12
movq -.F559-24(%rbp),%r13
movq -.F559-32(%rbp),%r14
movq -.F559-40(%rbp),%r15
leave
ret
jmp .L569
.L568:
.L569:
movq %rbx,%rax
addq %r14,%rax
jnc .L570
call rt_abort
.L570:
movq %rax,%rbx
jmp .L560
.L561:
movabsq $0,%rax
movq -.F559-8(%rbp),%rbx
movq -.F559-16(%rbp),%r12
movq -.F559-24(%rbp),%r13
movq -.F559-32(%rbp),%r14
movq -.F559-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F559-8(%rbp),%rbx
movq -.F559-16(%rbp),%r12
movq -.F559-24(%rbp),%r13
movq -.F559-32(%rbp),%r14
movq -.F559-40(%rbp),%r15
leave
ret
.set .F559,32
.type f_host_write_file,@function
f_host_write_file:
pushq %rbp
movq %rsp,%rbp
subq $.F571,%rsp
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
jne .L933_i9
movabsq $0,%rax
jmp .Lret_i9
jmp .L934_i9
.L933_i9:
.L934_i9:
movq %r8,%rax
addq $16,%rax
jnc .L935_i9
call rt_abort
.L935_i9:
movq (%rax),%rax
jmp .Lret_i9
xorq %rax,%rax
jmp .Lret_i9
.Lret_i9:
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
je .L572
leaq rt_write_file_blocking(%rip),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rdi
movq -8(%rbp),%rsi
movq %rax,%rdx
call rt_offload
leave
ret
jmp .L573
.L572:
.L573:
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_write_file_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F571,32
.type rt_write_file_blocking,@function
rt_write_file_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F574,%rsp
subq $32,%rsp
movq %rbx,-.F574-8(%rbp)
movq %r12,-.F574-16(%rbp)
movq %r13,-.F574-24(%rbp)
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
jne .L575
movq %rbx,%rdi
call rt_free
movabsq $22,%rax
movq -.F574-8(%rbp),%rbx
movq -.F574-16(%rbp),%r12
movq -.F574-24(%rbp),%r13
leave
ret
jmp .L576
.L575:
.L576:
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
jmp .Lret_i10
xorq %rax,%rax
jmp .Lret_i10
.Lret_i10:
testq %rax,%rax
jz .L577
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
subq %r12,%rax
movq -.F574-8(%rbp),%rbx
movq -.F574-16(%rbp),%r12
movq -.F574-24(%rbp),%r13
leave
ret
jmp .L578
.L577:
.L578:
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
je .L579
movq -32(%rbp),%rax
movq -.F574-8(%rbp),%rbx
movq -.F574-16(%rbp),%r12
movq -.F574-24(%rbp),%r13
leave
ret
jmp .L580
.L579:
.L580:
movq -40(%rbp),%rax
movq %rax,%rdi
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
jz .L581
movq -40(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F574-8(%rbp),%rbx
movq -.F574-16(%rbp),%r12
movq -.F574-24(%rbp),%r13
leave
ret
jmp .L582
.L581:
.L582:
movabsq $0,%rax
movq -.F574-8(%rbp),%rbx
movq -.F574-16(%rbp),%r12
movq -.F574-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F574-8(%rbp),%rbx
movq -.F574-16(%rbp),%r12
movq -.F574-24(%rbp),%r13
leave
ret
.set .F574,48
.type f_host_print,@function
f_host_print:
pushq %rbp
movq %rsp,%rbp
subq $.F583,%rsp
subq $16,%rsp
movq %rbx,-.F583-8(%rbp)
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
je .L584
call rt_abort
jmp .L585
.L584:
.L585:
movabsq $0,%rax
movq -.F583-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F583-8(%rbp),%rbx
leave
ret
.set .F583,32
.type rt_pow,@function
rt_pow:
pushq %rbp
movq %rsp,%rbp
subq $.F586,%rsp
subq $32,%rsp
movq %rbx,-.F586-8(%rbp)
movq %r12,-.F586-16(%rbp)
movq %r13,-.F586-24(%rbp)
movq %r14,-.F586-32(%rbp)
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
.L587:
cmpq $0,%rbx
je .L588
movabsq $2,%rcx
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L589:
testq %rdx,%rdx
jz .L590
movq %r13,%rax
movq %r12,%rcx
mulq %rcx
jnc .L592
call rt_abort
.L592:
movq %rax,%r13
jmp .L591
.L590:
.L591:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
cmpq $0,%rax
je .L593
movq %r12,%rax
movq %r12,%rcx
mulq %rcx
jnc .L595
call rt_abort
.L595:
movq %rax,%r12
jmp .L594
.L593:
.L594:
jmp .L587
.L588:
movq %r13,%rax
movq -.F586-8(%rbp),%rbx
movq -.F586-16(%rbp),%r12
movq -.F586-24(%rbp),%r13
movq -.F586-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F586-8(%rbp),%rbx
movq -.F586-16(%rbp),%r12
movq -.F586-24(%rbp),%r13
movq -.F586-32(%rbp),%r14
leave
ret
.set .F586,16
.type rt_wrapping_pow,@function
rt_wrapping_pow:
pushq %rbp
movq %rsp,%rbp
subq $.F596,%rsp
subq $32,%rsp
movq %rbx,-.F596-8(%rbp)
movq %r12,-.F596-16(%rbp)
movq %r13,-.F596-24(%rbp)
movq %r14,-.F596-32(%rbp)
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
.L597:
cmpq $0,%rbx
je .L598
movabsq $2,%rcx
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L599:
testq %rdx,%rdx
jz .L600
movq %r13,%rax
movq %r12,%rcx
imulq %rcx,%rax
movq %rax,%r13
jmp .L601
.L600:
.L601:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
cmpq $0,%rax
je .L602
movq %r12,%rax
movq %r12,%rcx
imulq %rcx,%rax
movq %rax,%r12
jmp .L603
.L602:
.L603:
jmp .L597
.L598:
movq %r13,%rax
movq -.F596-8(%rbp),%rbx
movq -.F596-16(%rbp),%r12
movq -.F596-24(%rbp),%r13
movq -.F596-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F596-8(%rbp),%rbx
movq -.F596-16(%rbp),%r12
movq -.F596-24(%rbp),%r13
movq -.F596-32(%rbp),%r14
leave
ret
.set .F596,16
.type rt_print_number,@function
rt_print_number:
pushq %rbp
movq %rsp,%rbp
subq $.F604,%rsp
subq $48,%rsp
movq %rbx,-.F604-8(%rbp)
movq %r12,-.F604-16(%rbp)
movq %r13,-.F604-24(%rbp)
movq %r14,-.F604-32(%rbp)
movq %r15,-.F604-40(%rbp)
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
jz .L605
movq $30,%rbx
movq %r13,%rax
addq $31,%rax
jnc .L607
call rt_abort
.L607:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
jmp .L606
.L605:
.L606:
.L608:
movabsq $1,%rax
testq %rax,%rax
jz .L609
movq %r13,%rax
addq %rbx,%rax
jnc .L610
call rt_abort
.L610:
movq %rax,%r14
movabsq $10,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L611
call rt_abort
.L611:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L612
call rt_abort
.L612:
movq %r14,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
movq %rax,%r15
cmpq $0,%rax
jne .L613
jmp .L609
jmp .L614
.L613:
.L614:
movq %rbx,%rax
subq $1,%rax
jnc .L615
call rt_abort
.L615:
movq %rax,%rbx
jmp .L608
.L609:
movq %r13,%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L616
call rt_abort
.L616:
movq %rax,-32(%rbp)
movabsq $32,%rax
subq %rbx,%rax
jnc .L617
call rt_abort
.L617:
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
je .L618
call rt_abort
jmp .L619
.L618:
.L619:
movabsq $0,%rax
movq -.F604-8(%rbp),%rbx
movq -.F604-16(%rbp),%r12
movq -.F604-24(%rbp),%r13
movq -.F604-32(%rbp),%r14
movq -.F604-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F604-8(%rbp),%rbx
movq -.F604-16(%rbp),%r12
movq -.F604-24(%rbp),%r13
movq -.F604-32(%rbp),%r14
movq -.F604-40(%rbp),%r15
leave
ret
.set .F604,48
.type rt_print_num,@function
rt_print_num:
pushq %rbp
movq %rsp,%rbp
subq $.F620,%rsp
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
.set .F620,16
.type rt_print_newline,@function
rt_print_newline:
pushq %rbp
movq %rsp,%rbp
subq $.F621,%rsp
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
je .L622
call rt_abort
jmp .L623
.L622:
.L623:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F621,32
.type f_host_print_num,@function
f_host_print_num:
pushq %rbp
movq %rsp,%rbp
subq $.F624,%rsp
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
.set .F624,16
.type f_host_newline,@function
f_host_newline:
pushq %rbp
movq %rsp,%rbp
subq $.F625,%rsp
call rt_print_newline
leave
ret
xorq %rax,%rax
leave
ret
.set .F625,16
.type rt_exec_paths,@function
rt_exec_paths:
pushq %rbp
movq %rsp,%rbp
subq $.F626,%rsp
subq $48,%rsp
movq %rbx,-.F626-8(%rbp)
movq %r12,-.F626-16(%rbp)
movq %r13,-.F626-24(%rbp)
movq %r14,-.F626-32(%rbp)
movq %r15,-.F626-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F626(%rbp),%rdi
movq $.F626/8-1,%rcx
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
leaq rt_state(%rip),%rax
movq %rax,-32(%rbp)
addq $16,%rax
jnc .L627
call rt_abort
.L627:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
.L628:
movq -8(%rbp),%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L630
call rt_abort
.L630:
movzbq (%rax),%rax
movq %rax,-64(%rbp)
cmpq $0,%rax
je .L629
movq -8(%rbp),%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L631
call rt_abort
.L631:
movzbq (%rax),%rax
movq %rax,-72(%rbp)
cmpq $47,%rax
jne .L632
movq $1,-56(%rbp)
jmp .L633
.L632:
.L633:
movq -48(%rbp),%rax
addq $1,%rax
jnc .L634
call rt_abort
.L634:
movq %rax,-48(%rbp)
jmp .L628
.L629:
movq -56(%rbp),%rax
testq %rax,%rax
jz .L635
movq -16(%rbp),%rax
movq -.F626-8(%rbp),%rbx
movq -.F626-16(%rbp),%r12
movq -.F626-24(%rbp),%r13
movq -.F626-32(%rbp),%r14
movq -.F626-40(%rbp),%r15
leave
ret
jmp .L636
.L635:
.L636:
movq -40(%rbp),%rax
movq %rax,-80(%rbp)
movq $0,%r14
.L637:
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-88(%rbp)
cmpq $0,%rax
je .L638
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-96(%rbp)
movzbq (%rax),%rax
movq %rax,-104(%rbp)
cmpq $80,%rax
jne .L639
movq -96(%rbp),%rax
addq $1,%rax
jnc .L641
call rt_abort
.L641:
movzbq (%rax),%rax
movq %rax,-112(%rbp)
cmpq $65,%rax
jne .L642
movq -96(%rbp),%rax
addq $2,%rax
jnc .L644
call rt_abort
.L644:
movzbq (%rax),%rax
movq %rax,-120(%rbp)
cmpq $84,%rax
jne .L645
movq -96(%rbp),%rax
addq $3,%rax
jnc .L647
call rt_abort
.L647:
movzbq (%rax),%rax
movq %rax,-128(%rbp)
cmpq $72,%rax
jne .L648
movq -96(%rbp),%rax
addq $4,%rax
jnc .L650
call rt_abort
.L650:
movzbq (%rax),%rax
movq %rax,-136(%rbp)
cmpq $61,%rax
jne .L651
movq -96(%rbp),%rax
addq $5,%rax
jnc .L653
call rt_abort
.L653:
movq %rax,%r14
jmp .L638
jmp .L652
.L651:
.L652:
jmp .L649
.L648:
.L649:
jmp .L646
.L645:
.L646:
jmp .L643
.L642:
.L643:
jmp .L640
.L639:
.L640:
movq -80(%rbp),%rax
addq $8,%rax
jnc .L654
call rt_abort
.L654:
movq %rax,-80(%rbp)
jmp .L637
.L638:
movq $0,-144(%rbp)
movabsq $0,%rcx
cmpq $0,%r14
jne .L655
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
jnc .L657
call rt_abort
.L657:
movq %rax,-160(%rbp)
movq %rax,%rcx
movabsq $98,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $2,%rax
jnc .L658
call rt_abort
.L658:
movq %rax,-168(%rbp)
movq %rax,%rcx
movabsq $105,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $3,%rax
jnc .L659
call rt_abort
.L659:
movq %rax,-176(%rbp)
movq %rax,%rcx
movabsq $110,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $4,%rax
jnc .L660
call rt_abort
.L660:
movq %rax,-184(%rbp)
movq %rax,%rcx
movabsq $58,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $5,%rax
jnc .L661
call rt_abort
.L661:
movq %rax,-192(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $6,%rax
jnc .L662
call rt_abort
.L662:
movq %rax,-200(%rbp)
movq %rax,%rcx
movabsq $117,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $7,%rax
jnc .L663
call rt_abort
.L663:
movq %rax,-208(%rbp)
movq %rax,%rcx
movabsq $115,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $8,%rax
jnc .L664
call rt_abort
.L664:
movq %rax,-216(%rbp)
movq %rax,%rcx
movabsq $114,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $9,%rax
jnc .L665
call rt_abort
.L665:
movq %rax,-224(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $10,%rax
jnc .L666
call rt_abort
.L666:
movq %rax,-232(%rbp)
movq %rax,%rcx
movabsq $98,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $11,%rax
jnc .L667
call rt_abort
.L667:
movq %rax,-240(%rbp)
movq %rax,%rcx
movabsq $105,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $12,%rax
jnc .L668
call rt_abort
.L668:
movq %rax,-248(%rbp)
movq %rax,%rcx
movabsq $110,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
movq %rax,%r14
jmp .L656
.L655:
.L656:
movq $0,-256(%rbp)
.L669:
movabsq $1,%rax
testq %rax,%rax
jz .L670
movq -256(%rbp),%rax
movq %rax,%r12
.L671:
movq %r14,%rax
addq %r12,%rax
jnc .L673
call rt_abort
.L673:
movzbq (%rax),%rax
movq %rax,-264(%rbp)
cmpq $0,%rax
je .L672
movq %r14,%rax
addq %r12,%rax
jnc .L674
call rt_abort
.L674:
movzbq (%rax),%rax
movq %rax,-272(%rbp)
cmpq $58,%rax
jne .L675
jmp .L672
jmp .L676
.L675:
.L676:
movq %r12,%rax
addq $1,%rax
jnc .L677
call rt_abort
.L677:
movq %rax,%r12
jmp .L671
.L672:
movq %r12,%rax
movq -256(%rbp),%rcx
subq %rcx,%rax
jnc .L678
call rt_abort
.L678:
movq %rax,-280(%rbp)
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L679
call rt_abort
.L679:
movq %rax,-288(%rbp)
movabsq $2,%rcx
addq $2,%rax
jnc .L680
call rt_abort
.L680:
movq %rax,%rdi
call rt_alloc
movq %rax,%r15
movq $0,%rbx
.L681:
movq -280(%rbp),%rcx
cmpq %rcx,%rbx
jae .L682
movq %r15,%rax
addq %rbx,%rax
jnc .L683
call rt_abort
.L683:
movq %rax,-296(%rbp)
movq %r14,%rax
movq -256(%rbp),%rcx
addq %rcx,%rax
jnc .L684
call rt_abort
.L684:
addq %rbx,%rax
jnc .L685
call rt_abort
.L685:
movzbq (%rax),%rax
movq -296(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L686
call rt_abort
.L686:
movq %rax,%rbx
jmp .L681
.L682:
movq -280(%rbp),%rax
cmpq $0,%rax
je .L687
movq %r15,%rax
addq %rbx,%rax
jnc .L689
call rt_abort
.L689:
movq %rax,-304(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L690
call rt_abort
.L690:
movq %rax,%rbx
jmp .L688
.L687:
.L688:
movq $0,%r13
.L691:
movq -48(%rbp),%rcx
cmpq %rcx,%r13
jae .L692
movq %r15,%rax
addq %rbx,%rax
jnc .L693
call rt_abort
.L693:
addq %r13,%rax
jnc .L694
call rt_abort
.L694:
movq %rax,-312(%rbp)
movq -8(%rbp),%rax
addq %r13,%rax
jnc .L695
call rt_abort
.L695:
movzbq (%rax),%rax
movq -312(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $1,%rax
jnc .L696
call rt_abort
.L696:
movq %rax,%r13
jmp .L691
.L692:
movq -16(%rbp),%rdi
movq %r15,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt18
call rt_push
jmp .Lopt19
.Lopt18:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt19:
movq %r14,%rax
addq %r12,%rax
jnc .L697
call rt_abort
.L697:
movzbq (%rax),%rax
movq %rax,-320(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L698
jmp .L670
jmp .L699
.L698:
.L699:
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L700
call rt_abort
.L700:
movq %rax,-256(%rbp)
jmp .L669
.L670:
movq -144(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq -.F626-8(%rbp),%rbx
movq -.F626-16(%rbp),%r12
movq -.F626-24(%rbp),%r13
movq -.F626-32(%rbp),%r14
movq -.F626-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F626-8(%rbp),%rbx
movq -.F626-16(%rbp),%r12
movq -.F626-24(%rbp),%r13
movq -.F626-32(%rbp),%r14
movq -.F626-40(%rbp),%r15
leave
ret
.set .F626,320
.type rt_exec,@function
rt_exec:
pushq %rbp
movq %rsp,%rbp
subq $.F701,%rsp
subq $48,%rsp
movq %rbx,-.F701-8(%rbp)
movq %r12,-.F701-16(%rbp)
movq %r13,-.F701-24(%rbp)
movq %r14,-.F701-32(%rbp)
movq %r15,-.F701-40(%rbp)
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
jnc .L702
call rt_abort
.L702:
movq (%rax),%rax
movq %rax,%r15
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq $0,%rbx
.L703:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L704
movq %r13,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i12
call rt_abort
.Lopt11_i12:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i12
xorq %rax,%rax
jmp .Lret_i12
.Lret_i12:
movq %rax,%r12
movabsq $59,%rdi
movq %r12,%rsi
movq %r14,%rdx
movq %r15,%rcx
call rt_syscall
movq %rbx,%rax
addq $1,%rax
jnc .L705
call rt_abort
.L705:
movq %rax,%rbx
jmp .L703
.L704:
movabsq $0,%rax
movq -.F701-8(%rbp),%rbx
movq -.F701-16(%rbp),%r12
movq -.F701-24(%rbp),%r13
movq -.F701-32(%rbp),%r14
movq -.F701-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F701-8(%rbp),%rbx
movq -.F701-16(%rbp),%r12
movq -.F701-24(%rbp),%r13
movq -.F701-32(%rbp),%r14
movq -.F701-40(%rbp),%r15
leave
ret
.set .F701,32
.type rt_drop_exec_paths,@function
rt_drop_exec_paths:
pushq %rbp
movq %rsp,%rbp
subq $.F706,%rsp
subq $32,%rsp
movq %rbx,-.F706-8(%rbp)
movq %r12,-.F706-16(%rbp)
movq %r13,-.F706-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq $0,-16(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq $1,%rbx
.L707:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L708
movq %r12,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i13
call rt_abort
.Lopt11_i13:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i13
xorq %rax,%rax
jmp .Lret_i13
.Lret_i13:
movq %rax,%rdi
call rt_free
movq %rbx,%rax
addq $1,%rax
jnc .L709
call rt_abort
.L709:
movq %rax,%rbx
jmp .L707
.L708:
movq %r12,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F706-8(%rbp),%rbx
movq -.F706-16(%rbp),%r12
movq -.F706-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F706-8(%rbp),%rbx
movq -.F706-16(%rbp),%r12
movq -.F706-24(%rbp),%r13
leave
ret
.set .F706,16
.type f_host_command,@function
f_host_command:
pushq %rbp
movq %rsp,%rbp
subq $.F710,%rsp
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
jne .L933_i14
movabsq $0,%rax
jmp .Lret_i14
jmp .L934_i14
.L933_i14:
.L934_i14:
movq %r8,%rax
addq $16,%rax
jnc .L935_i14
call rt_abort
.L935_i14:
movq (%rax),%rax
jmp .Lret_i14
xorq %rax,%rax
jmp .Lret_i14
.Lret_i14:
movq %rax,-16(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
je .L711
leaq rt_command_blocking(%rip),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
call rt_offload
leave
ret
jmp .L712
.L711:
.L712:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_command_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F710,32
.type rt_command_blocking,@function
rt_command_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F713,%rsp
subq $48,%rsp
movq %rbx,-.F713-8(%rbp)
movq %r12,-.F713-16(%rbp)
movq %r13,-.F713-24(%rbp)
movq %r14,-.F713-32(%rbp)
movq %r15,-.F713-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
leaq -.F713(%rbp),%rdi
movq $.F713/8-1,%rcx
xorl %eax,%eax
rep stosq
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq $278,-16(%rbp)
movq $0,%r12
addq $1,%rax
jnc .L714
call rt_abort
.L714:
movq %rax,-24(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L715
call rt_abort
.L715:
movq %rax,%rdi
call rt_alloc
movq %rax,%r14
cmpq $0,%r13
je .L716
.L718:
movq %r13,%rcx
cmpq %r13,%r12
jae .L719
movq %r15,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i15
call rt_abort
.Lopt11_i15:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i15
xorq %rax,%rax
jmp .Lret_i15
.Lret_i15:
movq %rax,%rdi
call rt_cstr
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L720
jmp .L719
jmp .L721
.L720:
.L721:
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L722
call rt_abort
.L722:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L723
call rt_abort
.L723:
movq %rax,-48(%rbp)
movq -32(%rbp),%rax
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $1,%rax
jnc .L724
call rt_abort
.L724:
movq %rax,%r12
jmp .L718
.L719:
movq %r13,%rcx
cmpq %r13,%r12
jne .L725
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
jne .L727
movq -56(%rbp),%rdi
movq %r14,%rsi
call rt_exec
movabsq $60,%rdi
movabsq $127,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L728
.L727:
.L728:
movq -64(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movq %r8,%rcx
movabsq $18446744073709547520,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
jmp .Lret_i16
xorq %rax,%rax
jmp .Lret_i16
.Lret_i16:
testq %rax,%rax
jz .L729
movq -64(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%rcx
movabsq $256,%rax
addq %rcx,%rax
jnc .L731
call rt_abort
.L731:
movq %rax,-16(%rbp)
jmp .L730
.L729:
movabsq $8,%rdi
call rt_alloc
movq %rax,-80(%rbp)
movq $0,-88(%rbp)
.L732:
movabsq $1,%rax
testq %rax,%rax
jz .L733
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
je .L734
jmp .L733
jmp .L735
.L734:
.L735:
jmp .L732
.L733:
movq -88(%rbp),%rax
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
jz .L736
movq -88(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%rcx
movabsq $256,%rax
addq %rcx,%rax
jnc .L738
call rt_abort
.L738:
movq %rax,-16(%rbp)
jmp .L737
.L736:
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-104(%rbp)
movq %rax,-112(%rbp)
andq $127,%rax
movq %rax,-120(%rbp)
movq %rax,-128(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L739
movq -120(%rbp),%rcx
movabsq $128,%rax
addq %rcx,%rax
jnc .L741
call rt_abort
.L741:
movq %rax,-16(%rbp)
jmp .L740
.L739:
movq -104(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,-136(%rbp)
movabsq $255,%rcx
andq $255,%rax
movq %rax,-16(%rbp)
.L740:
.L737:
movq -80(%rbp),%rax
movq %rax,%rdi
call rt_free
.L730:
movq -56(%rbp),%rax
movq %rax,%rdi
call rt_drop_exec_paths
jmp .L726
.L725:
.L726:
jmp .L717
.L716:
.L717:
movq $0,%rbx
.L742:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L743
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L744
call rt_abort
.L744:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L745
call rt_abort
.L745:
movq (%rax),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rax
addq $1,%rax
jnc .L746
call rt_abort
.L746:
movq %rax,%rbx
jmp .L742
.L743:
movq %r14,%rdi
call rt_free
movq $0,%rbx
.L747:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L748
movq %r15,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i18
call rt_abort
.Lopt11_i18:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i18
xorq %rax,%rax
jmp .Lret_i18
.Lret_i18:
movq %rax,%rdi
call rt_drop_seq
movq %rbx,%rax
addq $1,%rax
jnc .L749
call rt_abort
.L749:
movq %rax,%rbx
jmp .L747
.L748:
movq %r15,%rdi
call rt_drop_seq
movq -16(%rbp),%rax
movq -.F713-8(%rbp),%rbx
movq -.F713-16(%rbp),%r12
movq -.F713-24(%rbp),%r13
movq -.F713-32(%rbp),%r14
movq -.F713-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F713-8(%rbp),%rbx
movq -.F713-16(%rbp),%r12
movq -.F713-24(%rbp),%r13
movq -.F713-32(%rbp),%r14
movq -.F713-40(%rbp),%r15
leave
ret
.set .F713,144
.type rt_utf8,@function
rt_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F750,%rsp
subq $48,%rsp
movq %rbx,-.F750-8(%rbp)
movq %r12,-.F750-16(%rbp)
movq %r13,-.F750-24(%rbp)
movq %r14,-.F750-32(%rbp)
movq %r15,-.F750-40(%rbp)
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
.L751:
movq -16(%rbp),%rcx
cmpq %rcx,%rbx
jae .L752
movq %r15,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt20
call rt_abort
.Lopt20:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq $0,%r14
cmpq $128,%rax
jae .L753
movq %rbx,%rax
addq $1,%rax
jnc .L755
call rt_abort
.L755:
movq %rax,%rbx
jmp .L751
jmp .L754
.L753:
.L754:
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
jz .L756
movq $2,%r14
jmp .L757
.L756:
.L757:
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
jz .L758
movq $3,%r14
jmp .L759
.L758:
.L759:
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
jz .L760
movq $4,%r14
jmp .L761
.L760:
.L761:
movq %r14,%rax
cmpq $0,%r14
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq %r14,%rax
jnc .L762
call rt_abort
.L762:
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L763
call rt_abort
.L763:
testq %rax,%rax
jz .L764
call rt_abort
jmp .L765
.L764:
.L765:
movq %rbx,%rax
addq $1,%rax
jnc .L766
call rt_abort
.L766:
movq %r15,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt21
call rt_abort
.Lopt21:
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
jnc .L767
call rt_abort
.L767:
testq %rax,%rax
jz .L768
call rt_abort
jmp .L769
.L768:
.L769:
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
jz .L770
call rt_abort
jmp .L771
.L770:
.L771:
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
jz .L772
call rt_abort
jmp .L773
.L772:
.L773:
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
jz .L774
call rt_abort
jmp .L775
.L774:
.L775:
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
jz .L776
call rt_abort
jmp .L777
.L776:
.L777:
movq $2,%r13
.L778:
cmpq %r14,%r13
jae .L779
movq %rbx,%rax
addq %r13,%rax
jnc .L780
call rt_abort
.L780:
movq %r15,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt22
call rt_abort
.Lopt22:
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
jnc .L781
call rt_abort
.L781:
testq %rax,%rax
jz .L782
call rt_abort
jmp .L783
.L782:
.L783:
movq %r13,%rax
addq $1,%rax
jnc .L784
call rt_abort
.L784:
movq %rax,%r13
jmp .L778
.L779:
movq %rbx,%rax
addq %r14,%rax
jnc .L785
call rt_abort
.L785:
movq %rax,%rbx
jmp .L751
.L752:
movabsq $0,%rax
movq -.F750-8(%rbp),%rbx
movq -.F750-16(%rbp),%r12
movq -.F750-24(%rbp),%r13
movq -.F750-32(%rbp),%r14
movq -.F750-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F750-8(%rbp),%rbx
movq -.F750-16(%rbp),%r12
movq -.F750-24(%rbp),%r13
movq -.F750-32(%rbp),%r14
movq -.F750-40(%rbp),%r15
leave
ret
.set .F750,128
.type rt_text,@function
rt_text:
pushq %rbp
movq %rsp,%rbp
subq $.F786,%rsp
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
.set .F786,16
.type rt_string_lit,@function
rt_string_lit:
pushq %rbp
movq %rsp,%rbp
subq $.F787,%rsp
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
.set .F787,32
.type rt_append_text,@function
rt_append_text:
pushq %rbp
movq %rsp,%rbp
subq $.F788,%rsp
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
.set .F788,16
.type rt_atomic_new,@function
rt_atomic_new:
pushq %rbp
movq %rsp,%rbp
subq $.F789,%rsp
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
.set .F789,32
.type rt_atomic_load,@function
rt_atomic_load:
pushq %rbp
movq %rsp,%rbp
subq $.F790,%rsp
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
.set .F790,16
.type rt_atomic_load_relaxed,@function
rt_atomic_load_relaxed:
pushq %rbp
movq %rsp,%rbp
subq $.F791,%rsp
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
.set .F791,16
.type rt_atomic_load_acquire,@function
rt_atomic_load_acquire:
pushq %rbp
movq %rsp,%rbp
subq $.F792,%rsp
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
.set .F792,16
.type rt_atomic_store,@function
rt_atomic_store:
pushq %rbp
movq %rsp,%rbp
subq $.F793,%rsp
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
.set .F793,16
.type rt_atomic_store_relaxed,@function
rt_atomic_store_relaxed:
pushq %rbp
movq %rsp,%rbp
subq $.F794,%rsp
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
.set .F794,16
.type rt_atomic_store_release,@function
rt_atomic_store_release:
pushq %rbp
movq %rsp,%rbp
subq $.F795,%rsp
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
.set .F795,16
.type rt_atomic_compare_exchange,@function
rt_atomic_compare_exchange:
pushq %rbp
movq %rsp,%rbp
subq $.F796,%rsp
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
.set .F796,32
.type rt_atomic_fetch_add,@function
rt_atomic_fetch_add:
pushq %rbp
movq %rsp,%rbp
subq $.F797,%rsp
subq $48,%rsp
movq %rbx,-.F797-8(%rbp)
movq %r12,-.F797-16(%rbp)
movq %r13,-.F797-24(%rbp)
movq %r14,-.F797-32(%rbp)
movq %r15,-.F797-40(%rbp)
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
.L798:
movabsq $1,%rax
testq %rax,%rax
jz .L799
movq %rbx,%rax
addq %r15,%rax
movq %rax,%r12
movq %r14,%rdi
movq %rbx,%rax
movq %r12,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
cmpq %rbx,%rax
jne .L800
movq %rbx,%rax
movq -.F797-8(%rbp),%rbx
movq -.F797-16(%rbp),%r12
movq -.F797-24(%rbp),%r13
movq -.F797-32(%rbp),%r14
movq -.F797-40(%rbp),%r15
leave
ret
jmp .L801
.L800:
.L801:
movq %r13,%rbx
jmp .L798
.L799:
movabsq $0,%rax
movq -.F797-8(%rbp),%rbx
movq -.F797-16(%rbp),%r12
movq -.F797-24(%rbp),%r13
movq -.F797-32(%rbp),%r14
movq -.F797-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F797-8(%rbp),%rbx
movq -.F797-16(%rbp),%r12
movq -.F797-24(%rbp),%r13
movq -.F797-32(%rbp),%r14
movq -.F797-40(%rbp),%r15
leave
ret
.set .F797,16
.type rt_atomic_fetch_sub,@function
rt_atomic_fetch_sub:
pushq %rbp
movq %rsp,%rbp
subq $.F802,%rsp
subq $48,%rsp
movq %rbx,-.F802-8(%rbp)
movq %r12,-.F802-16(%rbp)
movq %r13,-.F802-24(%rbp)
movq %r14,-.F802-32(%rbp)
movq %r15,-.F802-40(%rbp)
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
.L803:
movabsq $1,%rax
testq %rax,%rax
jz .L804
movq %rbx,%rax
subq %r15,%rax
movq %rax,%r12
movq %r14,%rdi
movq %rbx,%rax
movq %r12,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
cmpq %rbx,%rax
jne .L805
movq %rbx,%rax
movq -.F802-8(%rbp),%rbx
movq -.F802-16(%rbp),%r12
movq -.F802-24(%rbp),%r13
movq -.F802-32(%rbp),%r14
movq -.F802-40(%rbp),%r15
leave
ret
jmp .L806
.L805:
.L806:
movq %r13,%rbx
jmp .L803
.L804:
movabsq $0,%rax
movq -.F802-8(%rbp),%rbx
movq -.F802-16(%rbp),%r12
movq -.F802-24(%rbp),%r13
movq -.F802-32(%rbp),%r14
movq -.F802-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F802-8(%rbp),%rbx
movq -.F802-16(%rbp),%r12
movq -.F802-24(%rbp),%r13
movq -.F802-32(%rbp),%r14
movq -.F802-40(%rbp),%r15
leave
ret
.set .F802,16
.type rt_atomic_swap,@function
rt_atomic_swap:
pushq %rbp
movq %rsp,%rbp
subq $.F807,%rsp
subq $32,%rsp
movq %rbx,-.F807-8(%rbp)
movq %r12,-.F807-16(%rbp)
movq %r13,-.F807-24(%rbp)
movq %r14,-.F807-32(%rbp)
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
.L808:
movabsq $1,%rax
testq %rax,%rax
jz .L809
movq %r13,%rdi
movq %rbx,%rax
movq %r14,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r12
cmpq %rbx,%rax
jne .L810
movq %rbx,%rax
movq -.F807-8(%rbp),%rbx
movq -.F807-16(%rbp),%r12
movq -.F807-24(%rbp),%r13
movq -.F807-32(%rbp),%r14
leave
ret
jmp .L811
.L810:
.L811:
movq %r12,%rbx
jmp .L808
.L809:
movabsq $0,%rax
movq -.F807-8(%rbp),%rbx
movq -.F807-16(%rbp),%r12
movq -.F807-24(%rbp),%r13
movq -.F807-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F807-8(%rbp),%rbx
movq -.F807-16(%rbp),%r12
movq -.F807-24(%rbp),%r13
movq -.F807-32(%rbp),%r14
leave
ret
.set .F807,16
.type rt_mutex_new,@function
rt_mutex_new:
pushq %rbp
movq %rsp,%rbp
subq $.F812,%rsp
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
jnc .L813
call rt_abort
.L813:
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
.set .F812,32
.type rt_mutex_unlock,@function
rt_mutex_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F814,%rsp
subq $16,%rsp
movq %rbx,-.F814-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_sub
movq %rax,-16(%rbp)
movabsq $1,%rcx
cmpq $1,%rax
je .L815
movq %rbx,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $129,%rdx
movabsq $1,%rcx
call rt_syscall
jmp .L816
.L815:
.L816:
movabsq $0,%rax
movq -.F814-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F814-8(%rbp),%rbx
leave
ret
.set .F814,16
.type rt_cpus,@function
rt_cpus:
pushq %rbp
movq %rsp,%rbp
subq $.F817,%rsp
subq $32,%rsp
movq %rbx,-.F817-8(%rbp)
movq %r12,-.F817-16(%rbp)
movq %r13,-.F817-24(%rbp)
movq %r14,-.F817-32(%rbp)
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
jmp .Lret_i19
xorq %rax,%rax
jmp .Lret_i19
.Lret_i19:
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L818
movq $0,%r13
.L820:
movabsq $128,%rcx
cmpq $128,%r13
jae .L821
movq %r14,%rax
addq %r13,%rax
jnc .L822
call rt_abort
.L822:
movzbq (%rax),%rax
movq %rax,%rbx
.L823:
cmpq $0,%rbx
je .L824
movq %rbx,%rax
andq $1,%rax
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L825
call rt_abort
.L825:
movq %rax,%r12
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L826:
movq %rax,%rbx
jmp .L823
.L824:
movq %r13,%rax
addq $1,%rax
jnc .L827
call rt_abort
.L827:
movq %rax,%r13
jmp .L820
.L821:
jmp .L819
.L818:
.L819:
movq %r14,%rdi
call rt_free
cmpq $0,%r12
jne .L828
movq $1,%r12
jmp .L829
.L828:
.L829:
movq %r12,%rax
movq -.F817-8(%rbp),%rbx
movq -.F817-16(%rbp),%r12
movq -.F817-24(%rbp),%r13
movq -.F817-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F817-8(%rbp),%rbx
movq -.F817-16(%rbp),%r12
movq -.F817-24(%rbp),%r13
movq -.F817-32(%rbp),%r14
leave
ret
.set .F817,16
.type rt_thread_spawn,@function
rt_thread_spawn:
pushq %rbp
movq %rsp,%rbp
subq $.F830,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
leaq -.F830(%rbp),%rdi
movq $.F830/8-2,%rcx
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
jmp .Lret_i20
xorq %rax,%rax
jmp .Lret_i20
.Lret_i20:
movq %rax,-72(%rbp)
movq -72(%rbp),%rax
testq %rax,%rax
jz .L831
call rt_abort
movq %rax,-80(%rbp)
jmp .L832
.L831:
.L832:
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
jmp .Lret_i21
xorq %rax,%rax
jmp .Lret_i21
.Lret_i21:
movq %rax,-160(%rbp)
movq -160(%rbp),%rax
testq %rax,%rax
jz .L833
call rt_abort
movq %rax,-168(%rbp)
jmp .L834
.L833:
.L834:
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
jnc .L835
call rt_abort
.L835:
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
jnc .L836
call rt_abort
.L836:
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
jnc .L837
call rt_abort
.L837:
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
jnc .L838
call rt_abort
.L838:
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
jnc .L839
call rt_abort
.L839:
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
jnc .L840
call rt_abort
.L840:
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
jnc .L841
call rt_abort
.L841:
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
jnc .L842
call rt_abort
.L842:
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
jnc .L843
call rt_abort
.L843:
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
jnz .L844
xorl %ebp,%ebp
popq %rax
popq %rdi
call *%rax
movl $60,%eax
xorl %edi,%edi
syscall
ud2
.L844:
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
jmp .Lret_i22
xorq %rax,%rax
jmp .Lret_i22
.Lret_i22:
movq %rax,-640(%rbp)
movq -640(%rbp),%rax
testq %rax,%rax
jz .L845
call rt_abort
movq %rax,-648(%rbp)
jmp .L846
.L845:
.L846:
movq -200(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F830,656
.type rt_thread_spawn_detached,@function
rt_thread_spawn_detached:
pushq %rbp
movq %rsp,%rbp
subq $.F847,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
leaq -.F847(%rbp),%rdi
movq $.F847/8-2,%rcx
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
jmp .Lret_i23
xorq %rax,%rax
jmp .Lret_i23
.Lret_i23:
movq %rax,-72(%rbp)
movq -72(%rbp),%rax
testq %rax,%rax
jz .L848
call rt_abort
movq %rax,-80(%rbp)
jmp .L849
.L848:
.L849:
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
jmp .Lret_i24
xorq %rax,%rax
jmp .Lret_i24
.Lret_i24:
movq %rax,-160(%rbp)
movq -160(%rbp),%rax
testq %rax,%rax
jz .L850
call rt_abort
movq %rax,-168(%rbp)
jmp .L851
.L850:
.L851:
movq -56(%rbp),%rax
movq %rax,-176(%rbp)
movq -32(%rbp),%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L852
call rt_abort
.L852:
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
jnc .L853
call rt_abort
.L853:
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
jnc .L854
call rt_abort
.L854:
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
jnc .L855
call rt_abort
.L855:
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
jnc .L856
call rt_abort
.L856:
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
jnc .L857
call rt_abort
.L857:
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
jnc .L858
call rt_abort
.L858:
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
jnc .L859
call rt_abort
.L859:
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
jnz .L860
xorl %ebp,%ebp
popq %rax
popq %rdi
call *%rax
movl $60,%eax
xorl %edi,%edi
syscall
ud2
.L860:
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
jmp .Lret_i25
xorq %rax,%rax
jmp .Lret_i25
.Lret_i25:
movq %rax,-536(%rbp)
movq -536(%rbp),%rax
testq %rax,%rax
jz .L861
call rt_abort
movq %rax,-544(%rbp)
jmp .L862
.L861:
.L862:
movabsq $0,%rax
movq %rax,-552(%rbp)
movq -552(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F847,560
.type rt_thread_main,@function
rt_thread_main:
pushq %rbp
movq %rsp,%rbp
subq $.F863,%rsp
subq $16,%rsp
movq %rbx,-.F863-8(%rbp)
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
jnc .L864
call rt_abort
.L864:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L865
call rt_abort
.L865:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
movq -16(%rbp),%rax
call *%rax
movabsq $0,%rax
movq -.F863-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F863-8(%rbp),%rbx
leave
ret
.set .F863,32
.type rt_thread_join,@function
rt_thread_join:
pushq %rbp
movq %rsp,%rbp
subq $.F866,%rsp
subq $32,%rsp
movq %rbx,-.F866-8(%rbp)
movq %r12,-.F866-16(%rbp)
movq %r13,-.F866-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
.L867:
movabsq $1,%rax
testq %rax,%rax
jz .L868
movq %rbx,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movq %rax,%r13
cmpq $0,%rax
jne .L869
jmp .L868
jmp .L870
.L869:
.L870:
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $0,%rdx
movq %r12,%rcx
call rt_syscall
jmp .L867
.L868:
movq %rbx,%rax
addq $8,%rax
jnc .L871
call rt_abort
.L871:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L872
call rt_abort
.L872:
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
jmp .Lret_i26
xorq %rax,%rax
jmp .Lret_i26
.Lret_i26:
testq %rax,%rax
jz .L873
call rt_abort
jmp .L874
.L873:
.L874:
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
movq -.F866-8(%rbp),%rbx
movq -.F866-16(%rbp),%r12
movq -.F866-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F866-8(%rbp),%rbx
movq -.F866-16(%rbp),%r12
movq -.F866-24(%rbp),%r13
leave
ret
.set .F866,32
.type rt_parallel_worker,@function
rt_parallel_worker:
pushq %rbp
movq %rsp,%rbp
subq $.F875,%rsp
subq $48,%rsp
movq %rbx,-.F875-8(%rbp)
movq %r12,-.F875-16(%rbp)
movq %r13,-.F875-24(%rbp)
movq %r14,-.F875-32(%rbp)
movq %r15,-.F875-40(%rbp)
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
jnc .L876
call rt_abort
.L876:
movq (%rax),%rax
movq %rax,%r14
movq %r12,%rax
addq $16,%rax
jnc .L877
call rt_abort
.L877:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %r12,%rax
addq $24,%rax
jnc .L878
call rt_abort
.L878:
movq (%rax),%rax
movq %rax,%r15
movq %r12,%rax
addq $32,%rax
jnc .L879
call rt_abort
.L879:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %r12,%rax
addq $56,%rax
jnc .L880
call rt_abort
.L880:
movq (%rax),%rax
movq %rax,-32(%rbp)
.L881:
movabsq $1,%rax
testq %rax,%rax
jz .L882
movabsq $40,%rcx
movq %r12,%rax
addq $40,%rax
jnc .L883
call rt_abort
.L883:
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
jne .L884
jmp .L882
jmp .L885
.L884:
.L885:
movq -32(%rbp),%rax
cmpq $0,%rax
jne .L886
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L888
call rt_abort
.L888:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L889
call rt_abort
.L889:
movq %rax,-56(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L890
call rt_abort
.L890:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L891
call rt_abort
.L891:
movq (%rax),%rax
movq %rax,-64(%rbp)
movq -64(%rbp),%rdi
movq %r15,%rsi
movq %r13,%rax
call *%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L887
.L886:
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L892
call rt_abort
.L892:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L893
call rt_abort
.L893:
movq %rax,-72(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L894
call rt_abort
.L894:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L895
call rt_abort
.L895:
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
.L887:
jmp .L881
.L882:
movabsq $48,%rcx
movq %r12,%rax
addq $48,%rax
jnc .L896
call rt_abort
.L896:
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movabsq $0,%rax
movq -.F875-8(%rbp),%rbx
movq -.F875-16(%rbp),%r12
movq -.F875-24(%rbp),%r13
movq -.F875-32(%rbp),%r14
movq -.F875-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F875-8(%rbp),%rbx
movq -.F875-16(%rbp),%r12
movq -.F875-24(%rbp),%r13
movq -.F875-32(%rbp),%r14
movq -.F875-40(%rbp),%r15
leave
ret
.set .F875,96
.type rt_parallel_map,@function
rt_parallel_map:
pushq %rbp
movq %rsp,%rbp
subq $.F897,%rsp
subq $48,%rsp
movq %rbx,-.F897-8(%rbp)
movq %r12,-.F897-16(%rbp)
movq %r13,-.F897-24(%rbp)
movq %r14,-.F897-32(%rbp)
movq %r15,-.F897-40(%rbp)
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
.L898:
movq -40(%rbp),%rcx
cmpq %rcx,%r14
jae .L899
movq -48(%rbp),%rdi
movabsq $0,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt23
call rt_push
jmp .Lopt24
.Lopt23:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt24:
movq %r14,%rax
addq $1,%rax
jnc .L900
call rt_abort
.L900:
movq %rax,%r14
jmp .L898
.L899:
movabsq $64,%rdi
call rt_alloc
movq %rax,%r13
movq %rax,-56(%rbp)
addq $56,%rax
jnc .L901
call rt_abort
.L901:
movq %rax,-64(%rbp)
movq -32(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $40,%rax
jnc .L902
call rt_abort
.L902:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r13,%rax
addq $48,%rax
jnc .L903
call rt_abort
.L903:
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
jnc .L904
call rt_abort
.L904:
movq %rax,-88(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $16,%rax
jnc .L905
call rt_abort
.L905:
movq %rax,-96(%rbp)
movq -40(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $24,%rax
jnc .L906
call rt_abort
.L906:
movq %rax,-104(%rbp)
movq -16(%rbp),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $32,%rax
jnc .L907
call rt_abort
.L907:
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
jae .L908
movq $4,%r12
jmp .L909
.L908:
.L909:
movabsq $64,%rax
cmpq %r12,%rax
jae .L910
movq $64,%r12
jmp .L911
.L910:
.L911:
movq -40(%rbp),%rax
cmpq %r12,%rax
jae .L912
movq -40(%rbp),%rax
movq %rax,%r12
jmp .L913
.L912:
.L913:
cmpq $0,%r12
jne .L914
movq $1,%r12
jmp .L915
.L914:
.L915:
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L916
call rt_abort
.L916:
movq %rax,%rdi
call rt_alloc
movq %rax,%r15
movq $1,%rbx
.L917:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L918
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L919
call rt_abort
.L919:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L920
call rt_abort
.L920:
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
jnc .L921
call rt_abort
.L921:
movq %rax,%rbx
jmp .L917
.L918:
movq %r13,%rdi
call rt_parallel_worker
movq $1,%rbx
.L922:
cmpq %r12,%rbx
jae .L923
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L924
call rt_abort
.L924:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L925
call rt_abort
.L925:
movq (%rax),%rax
movq %rax,%rdi
call rt_thread_join
movq %rbx,%rax
addq $1,%rax
jnc .L926
call rt_abort
.L926:
movq %rax,%rbx
jmp .L922
.L923:
movabsq $48,%rcx
movq %r13,%rax
addq $48,%rax
jnc .L927
call rt_abort
.L927:
movq %rax,%rdi
call rt_atomic_load
movq %r12,%rcx
cmpq %r12,%rax
je .L928
call rt_abort
jmp .L929
.L928:
.L929:
movq %r15,%rdi
call rt_free
movq %r13,%rdi
call rt_free
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_drop_seq
movq -48(%rbp),%rax
movq -.F897-8(%rbp),%rbx
movq -.F897-16(%rbp),%r12
movq -.F897-24(%rbp),%r13
movq -.F897-32(%rbp),%r14
movq -.F897-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F897-8(%rbp),%rbx
movq -.F897-16(%rbp),%r12
movq -.F897-24(%rbp),%r13
movq -.F897-32(%rbp),%r14
movq -.F897-40(%rbp),%r15
leave
ret
.set .F897,144
.type rt_thread_init,@function
rt_thread_init:
pushq %rbp
movq %rsp,%rbp
subq $.F930,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movq -8(%rbp),%rax
addq $128,%rax
jnc .L931
call rt_abort
.L931:
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
jmp .Lret_i27
xorq %rax,%rax
jmp .Lret_i27
.Lret_i27:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F930,16
.type rt_current,@function
rt_current:
pushq %rbp
movq %rsp,%rbp
subq $.F932,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq %fs:0,%rax
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L933
movabsq $0,%rax
leave
ret
jmp .L934
.L933:
.L934:
movq -8(%rbp),%rax
addq $16,%rax
jnc .L935
call rt_abort
.L935:
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F932,16
.type rt_spin_lock,@function
rt_spin_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F936,%rsp
subq $16,%rsp
movq %rbx,-.F936-8(%rbp)
movq %r12,-.F936-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq $0,-16(%rbp)
.L937:
movq %r12,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%rbx
cmpq $0,%rax
je .L938
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L937
.L938:
movabsq $0,%rax
movq -.F936-8(%rbp),%rbx
movq -.F936-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F936-8(%rbp),%rbx
movq -.F936-16(%rbp),%r12
leave
ret
.set .F936,16
.type rt_spin_unlock,@function
rt_spin_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F939,%rsp
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
.set .F939,16
.type rt_sched,@function
rt_sched:
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
jnc .L941
call rt_abort
.L941:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
cmpq $0,%rax
je .L942
movq -16(%rbp),%rax
movq -.F940-8(%rbp),%rbx
movq -.F940-16(%rbp),%r12
movq -.F940-24(%rbp),%r13
movq -.F940-32(%rbp),%r14
movq -.F940-40(%rbp),%r15
leave
ret
jmp .L943
.L942:
.L943:
movq %r14,%rax
addq $80,%rax
jnc .L944
call rt_abort
.L944:
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L945
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
jmp .Lret_i28
xorq %rax,%rax
jmp .Lret_i28
.Lret_i28:
testq %rax,%rax
jz .L947
call rt_abort
jmp .L948
.L947:
.L948:
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
jmp .Lret_i29
xorq %rax,%rax
jmp .Lret_i29
.Lret_i29:
testq %rax,%rax
jz .L949
call rt_abort
jmp .L950
.L949:
.L950:
movq %r12,%rax
addq $40,%rax
jnc .L951
call rt_abort
.L951:
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
jmp .Lret_i30
xorq %rax,%rax
jmp .Lret_i30
.Lret_i30:
testq %rax,%rax
jz .L952
call rt_abort
jmp .L953
.L952:
.L953:
movq %r12,%rax
addq $48,%rax
jnc .L954
call rt_abort
.L954:
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
jmp .Lret_i31
xorq %rax,%rax
jmp .Lret_i31
.Lret_i31:
testq %rax,%rax
jz .L955
call rt_abort
jmp .L956
.L955:
.L956:
movabsq $11,%rdi
movq -80(%rbp),%rsi
movabsq $4096,%rdx
movabsq $0,%rcx
call rt_syscall
call rt_cpus
movq %rax,%r13
movq %rax,-96(%rbp)
cmpq $4,%rax
jae .L957
movq $4,%r13
jmp .L958
.L957:
.L958:
movabsq $64,%rax
cmpq %r13,%rax
jae .L959
movq $64,%r13
jmp .L960
.L959:
.L960:
movq %r12,%rax
addq $32,%rax
jnc .L961
call rt_abort
.L961:
movq %rax,-104(%rbp)
movq %r13,%rax
movq -104(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L962
call rt_abort
.L962:
movq %rax,-112(%rbp)
movq %r12,%rax
movq -112(%rbp),%rdi
xchgq %rax,(%rdi)
xorq %rax,%rax
movq $0,%rbx
.L963:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L964
leaq rt_worker_loop(%rip),%rax
movq %rax,%r15
movq %r15,%rdi
movq %r12,%rsi
call rt_thread_spawn_detached
movq %rbx,%rax
addq $1,%rax
jnc .L965
call rt_abort
.L965:
movq %rax,%rbx
jmp .L963
.L964:
leaq rt_reactor(%rip),%rax
movq %rax,-120(%rbp)
movq -120(%rbp),%rdi
movq %r12,%rsi
call rt_thread_spawn_detached
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
.L966:
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L968
call rt_abort
.L968:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,-128(%rbp)
cmpq $0,%rax
jne .L967
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L966
.L967:
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L969
call rt_abort
.L969:
movq %rax,%rdi
movq (%rdi),%rax
mfence
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
.set .F940,128
.type rt_enqueue,@function
rt_enqueue:
pushq %rbp
movq %rsp,%rbp
subq $.F970,%rsp
subq $16,%rsp
movq %rbx,-.F970-8(%rbp)
movq %r12,-.F970-16(%rbp)
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
jnc .L971
call rt_abort
.L971:
movq %rax,-16(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L972
call rt_abort
.L972:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L973
movq %rbx,%rax
addq $8,%rax
jnc .L975
call rt_abort
.L975:
movq %rax,-40(%rbp)
movq %r12,%rax
movq -40(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L974
.L973:
movq -24(%rbp),%rax
addq $32,%rax
jnc .L976
call rt_abort
.L976:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
.L974:
movq %rbx,%rax
addq $16,%rax
jnc .L977
call rt_abort
.L977:
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
jnc .L978
call rt_abort
.L978:
movq %rax,-64(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movq %rbx,%rax
addq $24,%rax
jnc .L979
call rt_abort
.L979:
movq %rax,-72(%rbp)
movabsq $202,%rdi
movq %rax,%rsi
movabsq $129,%rdx
movabsq $1,%rcx
call rt_syscall
movabsq $0,%rax
movq -.F970-8(%rbp),%rbx
movq -.F970-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F970-8(%rbp),%rbx
movq -.F970-16(%rbp),%r12
leave
ret
.set .F970,80
.type rt_dequeue,@function
rt_dequeue:
pushq %rbp
movq %rsp,%rbp
subq $.F980,%rsp
subq $48,%rsp
movq %rbx,-.F980-8(%rbp)
movq %r12,-.F980-16(%rbp)
movq %r13,-.F980-24(%rbp)
movq %r14,-.F980-32(%rbp)
movq %r15,-.F980-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
.L981:
movabsq $1,%rax
testq %rax,%rax
jz .L982
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L983
call rt_abort
.L983:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r14
movq %rbx,%rdi
call rt_spin_lock
movq %rbx,%rax
addq $8,%rax
jnc .L984
call rt_abort
.L984:
movq (%rax),%rax
movq %rax,%r12
movq %rax,%r15
movabsq $0,%rcx
cmpq $0,%rax
je .L985
movq %r12,%rax
addq $32,%rax
jnc .L987
call rt_abort
.L987:
movq (%rax),%rax
movq %rax,%r13
movq %rbx,%rax
addq $8,%rax
jnc .L988
call rt_abort
.L988:
movq %rax,-16(%rbp)
movq %r13,%rax
movq -16(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movabsq $0,%rcx
cmpq $0,%r13
jne .L989
movq %rbx,%rax
addq $16,%rax
jnc .L991
call rt_abort
.L991:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
jmp .L990
.L989:
.L990:
movq %rbx,%rdi
call rt_spin_unlock
movq %r12,%rax
movq -.F980-8(%rbp),%rbx
movq -.F980-16(%rbp),%r12
movq -.F980-24(%rbp),%r13
movq -.F980-32(%rbp),%r14
movq -.F980-40(%rbp),%r15
leave
ret
jmp .L986
.L985:
.L986:
movq %rbx,%rdi
call rt_spin_unlock
movq %rbx,%rax
addq $24,%rax
jnc .L992
call rt_abort
.L992:
movq %rax,-32(%rbp)
movabsq $202,%rdi
movq -32(%rbp),%rsi
movabsq $128,%rdx
movq %r14,%rcx
call rt_syscall
jmp .L981
.L982:
movabsq $0,%rax
movq -.F980-8(%rbp),%rbx
movq -.F980-16(%rbp),%r12
movq -.F980-24(%rbp),%r13
movq -.F980-32(%rbp),%r14
movq -.F980-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F980-8(%rbp),%rbx
movq -.F980-16(%rbp),%r12
movq -.F980-24(%rbp),%r13
movq -.F980-32(%rbp),%r14
movq -.F980-40(%rbp),%r15
leave
ret
.set .F980,32
.type rt_worker_loop,@function
rt_worker_loop:
pushq %rbp
movq %rsp,%rbp
subq $.F993,%rsp
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
.L994:
movabsq $1,%rax
testq %rax,%rax
jz .L995
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_dequeue
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
addq $16,%rax
jnc .L996
call rt_abort
.L996:
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $8,%rcx
movq -16(%rbp),%rax
addq $8,%rax
jnc .L997
call rt_abort
.L997:
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
movq (%rax),%rax
movq -40(%rbp),%rdi
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
movq -16(%rbp),%rax
addq $16,%rax
jnc .L999
call rt_abort
.L999:
movq %rax,-48(%rbp)
movq -48(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
addq $144,%rax
jnc .L1000
call rt_abort
.L1000:
movq (%rax),%rax
testq %rax,%rax
jz .L1001
movq -24(%rbp),%rax
addq $8,%rax
jnc .L1003
call rt_abort
.L1003:
movq (%rax),%rax
movq %rax,-56(%rbp)
movq -24(%rbp),%rax
addq $16,%rax
jnc .L1004
call rt_abort
.L1004:
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
jmp .Lret_i32
xorq %rax,%rax
jmp .Lret_i32
.Lret_i32:
testq %rax,%rax
jz .L1005
call rt_abort
jmp .L1006
.L1005:
.L1006:
movabsq $96,%rcx
movq -24(%rbp),%rax
addq $96,%rax
jnc .L1007
call rt_abort
.L1007:
movq %rax,-72(%rbp)
movq -72(%rbp),%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -24(%rbp),%rax
addq $96,%rax
jnc .L1008
call rt_abort
.L1008:
movq %rax,-80(%rbp)
movabsq $202,%rdi
movq -80(%rbp),%rsi
movabsq $129,%rdx
movabsq $2147483647,%rcx
call rt_syscall
movabsq $88,%rcx
movq -24(%rbp),%rax
addq $88,%rax
jnc .L1009
call rt_abort
.L1009:
movq %rax,-88(%rbp)
movq -88(%rbp),%rdi
movabsq $1,%rsi
call rt_atomic_swap
movq %rax,-96(%rbp)
movq -96(%rbp),%rcx
movabsq $1,%rax
cmpq %rcx,%rax
jae .L1010
movq -96(%rbp),%rax
movq %rax,%rdi
call rt_wake
jmp .L1011
.L1010:
.L1011:
jmp .L1002
.L1001:
movq -24(%rbp),%rax
addq $136,%rax
jnc .L1012
call rt_abort
.L1012:
movq (%rax),%rax
testq %rax,%rax
jz .L1013
movq -24(%rbp),%rax
addq $136,%rax
jnc .L1015
call rt_abort
.L1015:
movq %rax,-104(%rbp)
movq -104(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_enqueue
jmp .L1014
.L1013:
movq -24(%rbp),%rax
addq $24,%rax
jnc .L1016
call rt_abort
.L1016:
movq %rax,-112(%rbp)
movq -112(%rbp),%rdi
movabsq $1,%rax
movabsq $2,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-120(%rbp)
movabsq $1,%rcx
movq -120(%rbp),%rax
cmpq $1,%rax
je .L1017
movabsq $24,%rcx
movq -24(%rbp),%rax
addq $24,%rax
jnc .L1019
call rt_abort
.L1019:
movq %rax,-128(%rbp)
movq -128(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_enqueue
jmp .L1018
.L1017:
.L1018:
.L1014:
.L1002:
jmp .L994
.L995:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F993,128
.type rt_green_main,@function
rt_green_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1020,%rsp
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
jne .L933_i33
movabsq $0,%rax
jmp .Lret_i33
jmp .L934_i33
.L933_i33:
.L934_i33:
movq %r8,%rax
addq $16,%rax
jnc .L935_i33
call rt_abort
.L935_i33:
movq (%rax),%rax
jmp .Lret_i33
xorq %rax,%rax
jmp .Lret_i33
.Lret_i33:
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
addq $40,%rax
jnc .L1021
call rt_abort
.L1021:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
addq $48,%rax
jnc .L1022
call rt_abort
.L1022:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
addq $56,%rax
jnc .L1023
call rt_abort
.L1023:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $64,%rax
jnc .L1024
call rt_abort
.L1024:
movq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $3,%rcx
movq -56(%rbp),%rax
cmpq $3,%rax
jne .L1025
movabsq $72,%rcx
movq -8(%rbp),%rax
addq $72,%rax
jnc .L1027
call rt_abort
.L1027:
movq (%rax),%rax
movq -32(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
movq -24(%rbp),%rax
call *%rax
movq %rax,-48(%rbp)
jmp .L1026
.L1025:
movq -40(%rbp),%rax
movq -32(%rbp),%rdi
movq %rax,%rsi
movq -24(%rbp),%rax
call *%rax
movq %rax,-48(%rbp)
.L1026:
movq -8(%rbp),%rax
addq $80,%rax
jnc .L1028
call rt_abort
.L1028:
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -8(%rbp),%rax
addq $144,%rax
jnc .L1029
call rt_abort
.L1029:
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
jnc .L1030
call rt_abort
.L1030:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1031(%rip),%rax
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
.L1031:
xorl %eax,%eax
call rt_abort
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1020,80
.type rt_suspend,@function
rt_suspend:
pushq %rbp
movq %rsp,%rbp
subq $.F1032,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1033
call rt_abort
.L1033:
movq %rax,-16(%rbp)
movq -16(%rbp),%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
cmpq $0,%rax
je .L1034
movabsq $24,%rcx
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1036
call rt_abort
.L1036:
movq %rax,-32(%rbp)
movq -32(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
jmp .L1035
.L1034:
.L1035:
movq %fs:0,%rax
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq -40(%rbp),%rax
addq $8,%rax
jnc .L1037
call rt_abort
.L1037:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1038(%rip),%rax
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
.L1038:
xorl %eax,%eax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1032,48
.type rt_wake,@function
rt_wake:
pushq %rbp
movq %rsp,%rbp
subq $.F1039,%rsp
subq $48,%rsp
movq %rbx,-.F1039-8(%rbp)
movq %r12,-.F1039-16(%rbp)
movq %r13,-.F1039-24(%rbp)
movq %r14,-.F1039-32(%rbp)
movq %r15,-.F1039-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
.L1040:
movabsq $1,%rax
testq %rax,%rax
jz .L1041
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1042
call rt_abort
.L1042:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movq %rax,%r13
cmpq $2,%rax
jne .L1043
movq %rbx,%rax
addq $24,%rax
jnc .L1045
call rt_abort
.L1045:
movq %rax,%r14
movq %rax,%rdi
movabsq $2,%rax
movabsq $0,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r15
movabsq $2,%rcx
cmpq $2,%rax
jne .L1046
movq %rbx,%rdi
call rt_enqueue
movabsq $0,%rax
movq -.F1039-8(%rbp),%rbx
movq -.F1039-16(%rbp),%r12
movq -.F1039-24(%rbp),%r13
movq -.F1039-32(%rbp),%r14
movq -.F1039-40(%rbp),%r15
leave
ret
jmp .L1047
.L1046:
.L1047:
jmp .L1044
.L1043:
cmpq $3,%r12
jne .L1048
movabsq $0,%rax
movq -.F1039-8(%rbp),%rbx
movq -.F1039-16(%rbp),%r12
movq -.F1039-24(%rbp),%r13
movq -.F1039-32(%rbp),%r14
movq -.F1039-40(%rbp),%r15
leave
ret
jmp .L1049
.L1048:
.L1049:
movq %rbx,%rax
addq $24,%rax
jnc .L1050
call rt_abort
.L1050:
movq %rax,-16(%rbp)
movq %rax,%rdi
movq %r12,%rax
movabsq $3,%rcx
lock cmpxchgq %rcx,(%rdi)
cmpq %r12,%rax
jne .L1051
movabsq $0,%rax
movq -.F1039-8(%rbp),%rbx
movq -.F1039-16(%rbp),%r12
movq -.F1039-24(%rbp),%r13
movq -.F1039-32(%rbp),%r14
movq -.F1039-40(%rbp),%r15
leave
ret
jmp .L1052
.L1051:
.L1052:
.L1044:
jmp .L1040
.L1041:
movabsq $0,%rax
movq -.F1039-8(%rbp),%rbx
movq -.F1039-16(%rbp),%r12
movq -.F1039-24(%rbp),%r13
movq -.F1039-32(%rbp),%r14
movq -.F1039-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1039-8(%rbp),%rbx
movq -.F1039-16(%rbp),%r12
movq -.F1039-24(%rbp),%r13
movq -.F1039-32(%rbp),%r14
movq -.F1039-40(%rbp),%r15
leave
ret
.set .F1039,16
.type rt_yield,@function
rt_yield:
pushq %rbp
movq %rsp,%rbp
subq $.F1053,%rsp
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
jne .L933_i34
movabsq $0,%rax
jmp .Lret_i34
jmp .L934_i34
.L933_i34:
.L934_i34:
movq %r8,%rax
addq $16,%rax
jnc .L935_i34
call rt_abort
.L935_i34:
movq (%rax),%rax
jmp .Lret_i34
xorq %rax,%rax
jmp .Lret_i34
.Lret_i34:
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1054
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
leave
ret
jmp .L1055
.L1054:
.L1055:
movq -8(%rbp),%rax
addq $136,%rax
jnc .L1056
call rt_abort
.L1056:
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
jnc .L1057
call rt_abort
.L1057:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1058(%rip),%rax
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
.L1058:
xorl %eax,%eax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1053,32
.type rt_mutex_lock,@function
rt_mutex_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F1059,%rsp
subq $32,%rsp
movq %rbx,-.F1059-8(%rbp)
movq %r12,-.F1059-16(%rbp)
movq %r13,-.F1059-24(%rbp)
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
jne .L933_i35
movabsq $0,%rax
jmp .Lret_i35
jmp .L934_i35
.L933_i35:
.L934_i35:
movq %r8,%rax
addq $16,%rax
jnc .L935_i35
call rt_abort
.L935_i35:
movq (%rax),%rax
jmp .Lret_i35
xorq %rax,%rax
jmp .Lret_i35
.Lret_i35:
movq %rax,-16(%rbp)
cmpq $0,%rax
je .L1060
.L1062:
movq %rbx,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
je .L1063
call rt_yield
jmp .L1062
.L1063:
movabsq $0,%rax
movq -.F1059-8(%rbp),%rbx
movq -.F1059-16(%rbp),%r12
movq -.F1059-24(%rbp),%r13
leave
ret
jmp .L1061
.L1060:
.L1061:
movq %rbx,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r12
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1064
movabsq $0,%rax
movq -.F1059-8(%rbp),%rbx
movq -.F1059-16(%rbp),%r12
movq -.F1059-24(%rbp),%r13
leave
ret
jmp .L1065
.L1064:
.L1065:
movabsq $2,%rcx
cmpq $2,%r12
je .L1066
movq %rbx,%rdi
movabsq $2,%rsi
call rt_atomic_swap
movq %rax,%r12
jmp .L1067
.L1066:
.L1067:
.L1068:
cmpq $0,%r12
je .L1069
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $128,%rdx
movabsq $2,%rcx
call rt_syscall
movq %rbx,%rdi
movabsq $2,%rsi
call rt_atomic_swap
movq %rax,%r12
jmp .L1068
.L1069:
movabsq $0,%rax
movq -.F1059-8(%rbp),%rbx
movq -.F1059-16(%rbp),%r12
movq -.F1059-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1059-8(%rbp),%rbx
movq -.F1059-16(%rbp),%r12
movq -.F1059-24(%rbp),%r13
leave
ret
.set .F1059,32
.type rt_scope_begin,@function
rt_scope_begin:
pushq %rbp
movq %rsp,%rbp
subq $.F1070,%rsp
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
jnc .L1071
call rt_abort
.L1071:
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
.set .F1070,32
.type rt_scope_token,@function
rt_scope_token:
pushq %rbp
movq %rsp,%rbp
subq $.F1072,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L1073
call rt_abort
.L1073:
leave
ret
xorq %rax,%rax
leave
ret
.set .F1072,16
.type rt_cancelled,@function
rt_cancelled:
pushq %rbp
movq %rsp,%rbp
subq $.F1074,%rsp
subq $16,%rsp
movq %rbx,-.F1074-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rbx,%rcx
cmpq %rbx,%rax
jne .L1075
movabsq $8,%rcx
movq %rbx,%rax
addq $8,%rax
jnc .L1077
call rt_abort
.L1077:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq -.F1074-8(%rbp),%rbx
leave
ret
jmp .L1076
.L1075:
.L1076:
movq %rbx,%rdi
movq (%rdi),%rax
mfence
movq -.F1074-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1074-8(%rbp),%rbx
leave
ret
.set .F1074,16
.type rt_cancel,@function
rt_cancel:
pushq %rbp
movq %rsp,%rbp
subq $.F1078,%rsp
subq $16,%rsp
movq %rbx,-.F1078-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L1079
call rt_abort
.L1079:
movq %rax,-16(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1080
call rt_abort
.L1080:
movq (%rax),%rax
movq %rax,%rbx
.L1081:
cmpq $0,%rbx
je .L1082
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1083
call rt_abort
.L1083:
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1084
movq %rbx,%rdi
call rt_wake
jmp .L1085
.L1084:
.L1085:
movq %rbx,%rax
addq $120,%rax
jnc .L1086
call rt_abort
.L1086:
movq (%rax),%rax
movq %rax,%rbx
jmp .L1081
.L1082:
movabsq $0,%rax
movq -.F1078-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1078-8(%rbp),%rbx
leave
ret
.set .F1078,16
.type rt_task_spawn,@function
rt_task_spawn:
pushq %rbp
movq %rsp,%rbp
subq $.F1087,%rsp
subq $32,%rsp
movq %rbx,-.F1087-8(%rbp)
movq %r12,-.F1087-16(%rbp)
movq %r13,-.F1087-24(%rbp)
movq %r14,-.F1087-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq %r8,-40(%rbp)
leaq -.F1087(%rbp),%rdi
movq $.F1087/8-5,%rcx
xorl %eax,%eax
rep stosq
movabsq $152,%rdi
call rt_alloc
movq %rax,%rbx
movq %rax,-48(%rbp)
addq $40,%rax
jnc .L1088
call rt_abort
.L1088:
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $48,%rax
jnc .L1089
call rt_abort
.L1089:
movq %rax,-64(%rbp)
movq -24(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $56,%rax
jnc .L1090
call rt_abort
.L1090:
movq %rax,-72(%rbp)
movq %r12,%rax
addq $16,%rax
jnc .L1091
call rt_abort
.L1091:
movq (%rax),%rax
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $64,%rax
jnc .L1092
call rt_abort
.L1092:
movq %rax,-80(%rbp)
movq -32(%rbp),%rax
movq -80(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $72,%rax
jnc .L1093
call rt_abort
.L1093:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $8,%rax
jnc .L1094
call rt_abort
.L1094:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $112,%rax
jnc .L1095
call rt_abort
.L1095:
movq %rax,-96(%rbp)
movq -40(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $120,%rax
jnc .L1096
call rt_abort
.L1096:
movq %rax,-104(%rbp)
movq %r12,%rax
addq $24,%rax
jnc .L1097
call rt_abort
.L1097:
movq (%rax),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $24,%rax
jnc .L1098
call rt_abort
.L1098:
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
jmp .Lret_i36
xorq %rax,%rax
jmp .Lret_i36
.Lret_i36:
testq %rax,%rax
jz .L1099
call rt_abort
jmp .L1100
.L1099:
.L1100:
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
jmp .Lret_i37
xorq %rax,%rax
jmp .Lret_i37
.Lret_i37:
testq %rax,%rax
jz .L1101
call rt_abort
jmp .L1102
.L1101:
.L1102:
movq %rbx,%rax
addq $8,%rax
jnc .L1103
call rt_abort
.L1103:
movq %rax,-128(%rbp)
movq %r13,%rax
movq -128(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1104
call rt_abort
.L1104:
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
jne .L1105
movq $22,%r14
jmp .L1106
.L1105:
.L1106:
movq -144(%rbp),%rax
cmpq $2,%rax
jne .L1107
movq $26,%r14
movq $25,-152(%rbp)
jmp .L1108
.L1107:
.L1108:
movq %r13,%rax
movq -120(%rbp),%rcx
addq %rcx,%rax
jnc .L1109
call rt_abort
.L1109:
movq %rax,-160(%rbp)
movabsq $8,%rcx
movq %r14,%rax
mulq %rcx
jnc .L1110
call rt_abort
.L1110:
movq %rax,%rcx
movq -160(%rbp),%rax
subq %rcx,%rax
jnc .L1111
call rt_abort
.L1111:
movq %rax,-168(%rbp)
movq %rax,-176(%rbp)
movabsq $8,%rcx
movq -152(%rbp),%rax
mulq %rcx
jnc .L1112
call rt_abort
.L1112:
movq %rax,%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L1113
call rt_abort
.L1113:
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
movq -.F1087-8(%rbp),%rbx
movq -.F1087-16(%rbp),%r12
movq -.F1087-24(%rbp),%r13
movq -.F1087-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1087-8(%rbp),%rbx
movq -.F1087-16(%rbp),%r12
movq -.F1087-24(%rbp),%r13
movq -.F1087-32(%rbp),%r14
leave
ret
.set .F1087,192
.type rt_task_wait,@function
rt_task_wait:
pushq %rbp
movq %rsp,%rbp
subq $.F1114,%rsp
subq $48,%rsp
movq %rbx,-.F1114-8(%rbp)
movq %r12,-.F1114-16(%rbp)
movq %r13,-.F1114-24(%rbp)
movq %r14,-.F1114-32(%rbp)
movq %r15,-.F1114-40(%rbp)
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
jnc .L1115
call rt_abort
.L1115:
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1116
movabsq $0,%rax
movq -.F1114-8(%rbp),%rbx
movq -.F1114-16(%rbp),%r12
movq -.F1114-24(%rbp),%r13
movq -.F1114-32(%rbp),%r14
movq -.F1114-40(%rbp),%r15
leave
ret
jmp .L1117
.L1116:
.L1117:
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L933_i38
movabsq $0,%rax
jmp .Lret_i38
jmp .L934_i38
.L933_i38:
.L934_i38:
movq %r8,%rax
addq $16,%rax
jnc .L935_i38
call rt_abort
.L935_i38:
movq (%rax),%rax
jmp .Lret_i38
xorq %rax,%rax
jmp .Lret_i38
.Lret_i38:
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
cmpq $0,%rax
je .L1118
movq %rbx,%rax
addq $88,%rax
jnc .L1120
call rt_abort
.L1120:
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rax
movq -16(%rbp),%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L1121
.L1123:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1125
call rt_abort
.L1125:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $0,%rcx
cmpq $0,%rax
jne .L1124
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_suspend
jmp .L1123
.L1124:
jmp .L1122
.L1121:
.L1122:
.L1126:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1128
call rt_abort
.L1128:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
jne .L1127
call rt_yield
jmp .L1126
.L1127:
movabsq $0,%rax
movq -.F1114-8(%rbp),%rbx
movq -.F1114-16(%rbp),%r12
movq -.F1114-24(%rbp),%r13
movq -.F1114-32(%rbp),%r14
movq -.F1114-40(%rbp),%r15
leave
ret
jmp .L1119
.L1118:
.L1119:
.L1129:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1131
call rt_abort
.L1131:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r14
cmpq $0,%rax
jne .L1130
movq %rbx,%rax
addq $96,%rax
jnc .L1132
call rt_abort
.L1132:
movq %rax,%r15
movabsq $202,%rdi
movq %rax,%rsi
movabsq $128,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L1129
.L1130:
movabsq $0,%rax
movq -.F1114-8(%rbp),%rbx
movq -.F1114-16(%rbp),%r12
movq -.F1114-24(%rbp),%r13
movq -.F1114-32(%rbp),%r14
movq -.F1114-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1114-8(%rbp),%rbx
movq -.F1114-16(%rbp),%r12
movq -.F1114-24(%rbp),%r13
movq -.F1114-32(%rbp),%r14
movq -.F1114-40(%rbp),%r15
leave
ret
.set .F1114,48
.type rt_task_join,@function
rt_task_join:
pushq %rbp
movq %rsp,%rbp
subq $.F1133,%rsp
subq $16,%rsp
movq %rbx,-.F1133-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
addq $104,%rax
jnc .L1134
call rt_abort
.L1134:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1135
call rt_abort
jmp .L1136
.L1135:
.L1136:
movq %rbx,%rdi
call rt_task_wait
movq %rbx,%rax
addq $104,%rax
jnc .L1137
call rt_abort
.L1137:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %rbx,%rax
addq $80,%rax
jnc .L1138
call rt_abort
.L1138:
movq (%rax),%rax
movq -.F1133-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1133-8(%rbp),%rbx
leave
ret
.set .F1133,32
.type rt_task_abandon,@function
rt_task_abandon:
pushq %rbp
movq %rsp,%rbp
subq $.F1139,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $104,%rax
jnc .L1140
call rt_abort
.L1140:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1141
movq -8(%rbp),%rax
addq $104,%rax
jnc .L1143
call rt_abort
.L1143:
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
movabsq $2,%rax
movq $2,(%rcx)
xorq $2,%rax
jmp .L1142
.L1141:
.L1142:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1139,32
.type rt_reactor_fence,@function
rt_reactor_fence:
pushq %rbp
movq %rsp,%rbp
subq $.F1144,%rsp
subq $16,%rsp
movq %rbx,-.F1144-8(%rbp)
movq %r12,-.F1144-16(%rbp)
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
jnc .L1145
call rt_abort
.L1145:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%rbx
movq %rax,-16(%rbp)
cmpq $0,%rax
jne .L1146
movabsq $0,%rax
movq -.F1144-8(%rbp),%rbx
movq -.F1144-16(%rbp),%r12
leave
ret
jmp .L1147
.L1146:
.L1147:
movabsq $56,%rcx
movq %rbx,%rax
addq $56,%rax
jnc .L1148
call rt_abort
.L1148:
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
jnc .L1149
call rt_abort
.L1149:
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
.L1150:
movabsq $56,%rcx
movq %rbx,%rax
addq $56,%rax
jnc .L1152
call rt_abort
.L1152:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %r12,%rcx
cmpq %r12,%rax
jne .L1151
call rt_yield
jmp .L1150
.L1151:
movabsq $0,%rax
movq -.F1144-8(%rbp),%rbx
movq -.F1144-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1144-8(%rbp),%rbx
movq -.F1144-16(%rbp),%r12
leave
ret
.set .F1144,48
.type rt_scope_end,@function
rt_scope_end:
pushq %rbp
movq %rsp,%rbp
subq $.F1153,%rsp
subq $48,%rsp
movq %rbx,-.F1153-8(%rbp)
movq %r12,-.F1153-16(%rbp)
movq %r13,-.F1153-24(%rbp)
movq %r14,-.F1153-32(%rbp)
movq %r15,-.F1153-40(%rbp)
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
jnc .L1154
call rt_abort
.L1154:
movq (%rax),%rax
movq %rax,%rbx
movq %rax,%r12
.L1155:
movabsq $0,%rcx
cmpq $0,%r12
je .L1156
movq %r12,%rdi
call rt_task_wait
movq %r12,%rax
addq $120,%rax
jnc .L1157
call rt_abort
.L1157:
movq (%rax),%rax
movq %rax,%r12
jmp .L1155
.L1156:
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1158
call rt_abort
.L1158:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1159
call rt_reactor_fence
jmp .L1160
.L1159:
.L1160:
.L1161:
movabsq $0,%rcx
cmpq $0,%rbx
je .L1162
movq %rbx,%rdi
call rt_task_wait
movq %rbx,%rax
addq $104,%rax
jnc .L1163
call rt_abort
.L1163:
movq (%rax),%rax
movq %rax,%r14
movabsq $0,%rcx
cmpq $0,%rax
jne .L1164
call rt_abort
jmp .L1165
.L1164:
.L1165:
movq %rbx,%rax
addq $112,%rax
jnc .L1166
call rt_abort
.L1166:
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
jz .L1167
movabsq $80,%rcx
movq %rbx,%rax
addq $80,%rax
jnc .L1169
call rt_abort
.L1169:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
movq %r13,%rax
call *%rax
jmp .L1168
.L1167:
.L1168:
movabsq $120,%rcx
movq %rbx,%rax
addq $120,%rax
jnc .L1170
call rt_abort
.L1170:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rdi
call rt_free
movq -40(%rbp),%rax
movq %rax,%rbx
jmp .L1161
.L1162:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F1153-8(%rbp),%rbx
movq -.F1153-16(%rbp),%r12
movq -.F1153-24(%rbp),%r13
movq -.F1153-32(%rbp),%r14
movq -.F1153-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1153-8(%rbp),%rbx
movq -.F1153-16(%rbp),%r12
movq -.F1153-24(%rbp),%r13
movq -.F1153-32(%rbp),%r14
movq -.F1153-40(%rbp),%r15
leave
ret
.set .F1153,48
.type rt_reactor,@function
rt_reactor:
pushq %rbp
movq %rsp,%rbp
subq $.F1171,%rsp
subq $48,%rsp
movq %rbx,-.F1171-8(%rbp)
movq %r12,-.F1171-16(%rbp)
movq %r13,-.F1171-24(%rbp)
movq %r14,-.F1171-32(%rbp)
movq %r15,-.F1171-40(%rbp)
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
jnc .L1172
call rt_abort
.L1172:
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
addq $40,%rax
jnc .L1173
call rt_abort
.L1173:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq $16,%r14
movabsq $0,%rax
cmpq $0,%rax
jne .L1174
movq $12,%r14
jmp .L1175
.L1174:
.L1175:
.L1176:
movabsq $1,%rax
testq %rax,%rax
jz .L1177
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
jmp .Lret_i39
xorq %rax,%rax
jmp .Lret_i39
.Lret_i39:
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L1178
movq $0,%rbx
.L1180:
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
jae .L1181
movq %rbx,%rax
movq %r14,%rcx
mulq %rcx
jnc .L1182
call rt_abort
.L1182:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1183
call rt_abort
.L1183:
addq $8,%rax
jnc .L1184
call rt_abort
.L1184:
movq %rax,%r12
cmpq $12,%r14
jne .L1185
movabsq $12,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1187
call rt_abort
.L1187:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1188
call rt_abort
.L1188:
movq %rax,-56(%rbp)
addq $4,%rax
jnc .L1189
call rt_abort
.L1189:
movq %rax,%r12
jmp .L1186
.L1185:
.L1186:
movq %r12,%rax
movq (%rax),%rax
movq %rax,-64(%rbp)
movq %rax,-72(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1190
movq -8(%rbp),%rax
addq $48,%rax
jnc .L1192
call rt_abort
.L1192:
movq (%rax),%rax
movq %rax,-80(%rbp)
movabsq $0,%rdi
movq %rax,%rsi
movq -24(%rbp),%rdx
movabsq $8,%rcx
call rt_syscall
jmp .L1191
.L1190:
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_wake
.L1191:
movq %rbx,%rax
addq $1,%rax
jnc .L1193
call rt_abort
.L1193:
movq %rax,%rbx
jmp .L1180
.L1181:
jmp .L1179
.L1178:
.L1179:
movabsq $56,%rcx
movq -8(%rbp),%rax
addq $56,%rax
jnc .L1194
call rt_abort
.L1194:
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
jmp .L1176
.L1177:
movabsq $0,%rax
movq -.F1171-8(%rbp),%rbx
movq -.F1171-16(%rbp),%r12
movq -.F1171-24(%rbp),%r13
movq -.F1171-32(%rbp),%r14
movq -.F1171-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1171-8(%rbp),%rbx
movq -.F1171-16(%rbp),%r12
movq -.F1171-24(%rbp),%r13
movq -.F1171-32(%rbp),%r14
movq -.F1171-40(%rbp),%r15
leave
ret
.set .F1171,96
.type rt_wait_fd,@function
rt_wait_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1195,%rsp
subq $32,%rsp
movq %rbx,-.F1195-8(%rbp)
movq %r12,-.F1195-16(%rbp)
movq %r13,-.F1195-24(%rbp)
movq %r14,-.F1195-32(%rbp)
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
jne .L933_i40
movabsq $0,%rax
jmp .Lret_i40
jmp .L934_i40
.L933_i40:
.L934_i40:
movq %r8,%rax
addq $16,%rax
jnc .L935_i40
call rt_abort
.L935_i40:
movq (%rax),%rax
jmp .Lret_i40
xorq %rax,%rax
jmp .Lret_i40
.Lret_i40:
movq %rax,%rbx
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1196
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
jnc .L1198
call rt_abort
.L1198:
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L1199
call rt_abort
.L1199:
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
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
movq -.F1195-32(%rbp),%r14
leave
ret
jmp .L1197
.L1196:
.L1197:
movq %rbx,%rax
addq $72,%rax
jnc .L1200
call rt_abort
.L1200:
movq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1201
call rt_abort
.L1201:
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
jz .L1202
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1204
call rt_abort
.L1204:
movq %rax,-72(%rbp)
movq %rax,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
subq $125,%rax
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
movq -.F1195-32(%rbp),%r14
leave
ret
jmp .L1203
.L1202:
.L1203:
call rt_sched
movq %rax,-80(%rbp)
movabsq $40,%rcx
addq $40,%rax
jnc .L1205
call rt_abort
.L1205:
movq (%rax),%rax
movq %rax,%r14
movabsq $16,%rdi
call rt_alloc
movq %rax,%r12
movq %rax,-88(%rbp)
movq -16(%rbp),%rax
addq $1073741824,%rax
jnc .L1206
call rt_abort
.L1206:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
cmpq $0,%rax
jne .L1207
movq %r12,%rax
addq $4,%rax
jnc .L1209
call rt_abort
.L1209:
movq %rax,-96(%rbp)
movq %rbx,%rax
movq -96(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
jmp .L1208
.L1207:
movq %r12,%rax
addq $8,%rax
jnc .L1210
call rt_abort
.L1210:
movq %rax,-104(%rbp)
movq %rbx,%rax
movq -104(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
.L1208:
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
jne .L1211
movabsq $233,%rdi
movq %r14,%rsi
movabsq $3,%rdx
movq %r13,%rcx
movq %r12,%r8
call rt_syscall4
movq %rax,-112(%rbp)
jmp .L1212
.L1211:
.L1212:
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
jmp .Lret_i41
xorq %rax,%rax
jmp .Lret_i41
.Lret_i41:
testq %rax,%rax
jz .L1213
call rt_abort
jmp .L1214
.L1213:
.L1214:
movq %rbx,%rdi
call rt_suspend
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1215
call rt_abort
.L1215:
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
jz .L1216
movabsq $0,%rax
subq $125,%rax
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
movq -.F1195-32(%rbp),%r14
leave
ret
jmp .L1217
.L1216:
.L1217:
movabsq $0,%rax
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
movq -.F1195-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
movq -.F1195-32(%rbp),%r14
leave
ret
.set .F1195,128
.type f_host_sleep_ms,@function
f_host_sleep_ms:
pushq %rbp
movq %rsp,%rbp
subq $.F1218,%rsp
subq $48,%rsp
movq %rbx,-.F1218-8(%rbp)
movq %r12,-.F1218-16(%rbp)
movq %r13,-.F1218-24(%rbp)
movq %r14,-.F1218-32(%rbp)
movq %r15,-.F1218-40(%rbp)
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
jnc .L1219
call rt_abort
.L1219:
movq %rax,-24(%rbp)
movq -8(%rbp),%rdi
movabsq $1000,%rsi
call rt_div
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r14,%rax
addq $24,%rax
jnc .L1220
call rt_abort
.L1220:
movq %rax,-32(%rbp)
movabsq $1000,%rcx
movq -8(%rbp),%rax
testq %rcx,%rcx
jnz .L1221
call rt_abort
.L1221:
xorq %rdx,%rdx
divq %rcx
movabsq $1000000,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1222
call rt_abort
.L1222:
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
jne .L933_i42
movabsq $0,%rax
jmp .Lret_i42
jmp .L934_i42
.L933_i42:
.L934_i42:
movq %r8,%rax
addq $16,%rax
jnc .L935_i42
call rt_abort
.L935_i42:
movq (%rax),%rax
jmp .Lret_i42
xorq %rax,%rax
jmp .Lret_i42
.Lret_i42:
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L1223
movq %r14,%rax
addq $16,%rax
jnc .L1225
call rt_abort
.L1225:
movq %rax,-48(%rbp)
movabsq $35,%rdi
movq %rax,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r14,%rdi
call rt_free
movabsq $0,%rax
movq -.F1218-8(%rbp),%rbx
movq -.F1218-16(%rbp),%r12
movq -.F1218-24(%rbp),%r13
movq -.F1218-32(%rbp),%r14
movq -.F1218-40(%rbp),%r15
leave
ret
jmp .L1224
.L1223:
.L1224:
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
jmp .Lret_i43
xorq %rax,%rax
jmp .Lret_i43
.Lret_i43:
testq %rax,%rax
jz .L1226
call rt_abort
jmp .L1227
.L1226:
.L1227:
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
jmp .Lret_i44
xorq %rax,%rax
jmp .Lret_i44
.Lret_i44:
testq %rax,%rax
jz .L1228
call rt_abort
jmp .L1229
.L1228:
.L1229:
movabsq $8,%rdi
call rt_alloc
movq %rax,%r15
.L1230:
movabsq $0,%rdi
movq %rbx,%rsi
movq %r15,%rdx
movabsq $8,%rcx
call rt_syscall
movabsq $8,%rcx
cmpq $8,%rax
je .L1231
movq %rbx,%rdi
movabsq $1,%rsi
call rt_wait_fd
cmpq $0,%rax
je .L1232
jmp .L1231
jmp .L1233
.L1232:
.L1233:
jmp .L1230
.L1231:
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
movq -.F1218-8(%rbp),%rbx
movq -.F1218-16(%rbp),%r12
movq -.F1218-24(%rbp),%r13
movq -.F1218-32(%rbp),%r14
movq -.F1218-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1218-8(%rbp),%rbx
movq -.F1218-16(%rbp),%r12
movq -.F1218-24(%rbp),%r13
movq -.F1218-32(%rbp),%r14
movq -.F1218-40(%rbp),%r15
leave
ret
.set .F1218,48
.type f_host_now_ms,@function
f_host_now_ms:
pushq %rbp
movq %rsp,%rbp
subq $.F1234,%rsp
subq $16,%rsp
movq %rbx,-.F1234-8(%rbp)
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
jnc .L1235
call rt_abort
.L1235:
movq %rax,-16(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
addq $8,%rax
jnc .L1236
call rt_abort
.L1236:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $1000000,%rsi
call rt_div
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1237
call rt_abort
.L1237:
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F1234-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1234-8(%rbp),%rbx
leave
ret
.set .F1234,32
.type f_host_pipe,@function
f_host_pipe:
pushq %rbp
movq %rsp,%rbp
subq $.F1238,%rsp
subq $16,%rsp
movq %rbx,-.F1238-8(%rbp)
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
jmp .Lret_i45
xorq %rax,%rax
jmp .Lret_i45
.Lret_i45:
testq %rax,%rax
jz .L1239
call rt_abort
jmp .L1240
.L1239:
.L1240:
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
jb .Lopt25
call rt_push
jmp .Lopt26
.Lopt25:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt26:
movq -8(%rbp),%rdi
movabsq $4294967296,%rsi
call rt_div
movq -16(%rbp),%rdi
movq %rax,%rsi
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
movq -16(%rbp),%rax
movq -.F1238-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1238-8(%rbp),%rbx
leave
ret
.set .F1238,32
.type f_host_read_fd,@function
f_host_read_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1241,%rsp
subq $48,%rsp
movq %rbx,-.F1241-8(%rbp)
movq %r12,-.F1241-16(%rbp)
movq %r13,-.F1241-24(%rbp)
movq %r14,-.F1241-32(%rbp)
movq %r15,-.F1241-40(%rbp)
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
jne .L1242
movq %r14,%rax
movq -.F1241-8(%rbp),%rbx
movq -.F1241-16(%rbp),%r12
movq -.F1241-24(%rbp),%r13
movq -.F1241-32(%rbp),%r14
movq -.F1241-40(%rbp),%r15
leave
ret
jmp .L1243
.L1242:
.L1243:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq %rax,%r13
.L1244:
movabsq $1,%rax
testq %rax,%rax
jz .L1245
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
jne .L1246
movq %r15,%rdi
movabsq $1,%rsi
call rt_wait_fd
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1248
jmp .L1245
jmp .L1249
.L1248:
.L1249:
jmp .L1247
.L1246:
movq %r12,%rdi
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
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1250
movq $0,%rbx
.L1252:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L1253
movq %r13,%rax
addq %rbx,%rax
jnc .L1254
call rt_abort
.L1254:
movzbq (%rax),%rax
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt29
call rt_pushb
jmp .Lopt30
.Lopt29:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt30:
movq %rbx,%rax
addq $1,%rax
jnc .L1255
call rt_abort
.L1255:
movq %rax,%rbx
jmp .L1252
.L1253:
jmp .L1251
.L1250:
.L1251:
jmp .L1245
.L1247:
jmp .L1244
.L1245:
movq %r13,%rdi
call rt_free
movq %r14,%rax
movq -.F1241-8(%rbp),%rbx
movq -.F1241-16(%rbp),%r12
movq -.F1241-24(%rbp),%r13
movq -.F1241-32(%rbp),%r14
movq -.F1241-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1241-8(%rbp),%rbx
movq -.F1241-16(%rbp),%r12
movq -.F1241-24(%rbp),%r13
movq -.F1241-32(%rbp),%r14
movq -.F1241-40(%rbp),%r15
leave
ret
.set .F1241,48
.type f_host_write_fd,@function
f_host_write_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1256,%rsp
subq $48,%rsp
movq %rbx,-.F1256-8(%rbp)
movq %r12,-.F1256-16(%rbp)
movq %r13,-.F1256-24(%rbp)
movq %r14,-.F1256-32(%rbp)
movq %r15,-.F1256-40(%rbp)
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
.L1257:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L1258
movq -24(%rbp),%rax
addq %rbx,%rax
jnc .L1259
call rt_abort
.L1259:
movq %rax,%r15
movq %r14,%rax
subq %rbx,%rax
jnc .L1260
call rt_abort
.L1260:
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
jne .L1261
movq %r13,%rdi
movabsq $4,%rsi
call rt_wait_fd
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1263
jmp .L1258
jmp .L1264
.L1263:
.L1264:
jmp .L1262
.L1261:
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
testq %rax,%rax
jz .L1265
jmp .L1258
jmp .L1266
.L1265:
.L1266:
movq %rbx,%rax
addq %r12,%rax
jnc .L1267
call rt_abort
.L1267:
movq %rax,%rbx
.L1262:
jmp .L1257
.L1258:
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rax
movq -.F1256-8(%rbp),%rbx
movq -.F1256-16(%rbp),%r12
movq -.F1256-24(%rbp),%r13
movq -.F1256-32(%rbp),%r14
movq -.F1256-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1256-8(%rbp),%rbx
movq -.F1256-16(%rbp),%r12
movq -.F1256-24(%rbp),%r13
movq -.F1256-32(%rbp),%r14
movq -.F1256-40(%rbp),%r15
leave
ret
.set .F1256,48
.type f_host_close,@function
f_host_close:
pushq %rbp
movq %rsp,%rbp
subq $.F1268,%rsp
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
jmp .Lret_i48
xorq %rax,%rax
jmp .Lret_i48
.Lret_i48:
testq %rax,%rax
jz .L1269
movq -16(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
leave
ret
jmp .L1270
.L1269:
.L1270:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1268,16
.type rt_offload_main,@function
rt_offload_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1271,%rsp
subq $16,%rsp
movq %rbx,-.F1271-8(%rbp)
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
jnc .L1272
call rt_abort
.L1272:
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $16,%rcx
movq %rbx,%rax
addq $16,%rax
jnc .L1273
call rt_abort
.L1273:
movq (%rax),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq -16(%rbp),%rax
call *%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
addq $24,%rax
jnc .L1274
call rt_abort
.L1274:
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1275
call rt_abort
.L1275:
movq %rax,-48(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $40,%rcx
movq %rbx,%rax
addq $40,%rax
jnc .L1276
call rt_abort
.L1276:
movq (%rax),%rax
movq %rax,%rdi
call rt_wake
movabsq $0,%rax
movq -.F1271-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1271-8(%rbp),%rbx
leave
ret
.set .F1271,48
.type rt_offload,@function
rt_offload:
pushq %rbp
movq %rsp,%rbp
subq $.F1277,%rsp
subq $32,%rsp
movq %rbx,-.F1277-8(%rbp)
movq %r12,-.F1277-16(%rbp)
movq %r13,-.F1277-24(%rbp)
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
jne .L933_i49
movabsq $0,%rax
jmp .Lret_i49
jmp .L934_i49
.L933_i49:
.L934_i49:
movq %r8,%rax
addq $16,%rax
jnc .L935_i49
call rt_abort
.L935_i49:
movq (%rax),%rax
jmp .Lret_i49
xorq %rax,%rax
jmp .Lret_i49
.Lret_i49:
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
jnc .L1278
call rt_abort
.L1278:
movq %rax,-40(%rbp)
movq -16(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1279
call rt_abort
.L1279:
movq %rax,-48(%rbp)
movq -24(%rbp),%rax
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $40,%rax
jnc .L1280
call rt_abort
.L1280:
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
.L1281:
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1283
call rt_abort
.L1283:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $0,%rcx
cmpq $0,%rax
jne .L1282
movq %r13,%rdi
call rt_suspend
jmp .L1281
.L1282:
movq -72(%rbp),%rax
movq %rax,%rdi
call rt_thread_join
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1284
call rt_abort
.L1284:
movq (%rax),%rax
movq %rax,-80(%rbp)
movq %rbx,%rdi
call rt_free
movq -80(%rbp),%rax
movq -.F1277-8(%rbp),%rbx
movq -.F1277-16(%rbp),%r12
movq -.F1277-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1277-8(%rbp),%rbx
movq -.F1277-16(%rbp),%r12
movq -.F1277-24(%rbp),%r13
leave
ret
.set .F1277,80
.type rt_bytes_from,@function
rt_bytes_from:
pushq %rbp
movq %rsp,%rbp
subq $.F1285,%rsp
subq $32,%rsp
movq %rbx,-.F1285-8(%rbp)
movq %r12,-.F1285-16(%rbp)
movq %r13,-.F1285-24(%rbp)
movq %r14,-.F1285-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,%r14
call rt_new
movq %rax,%r12
movq $0,%rbx
.L1286:
cmpq %r14,%rbx
jae .L1287
movq %r13,%rax
addq %rbx,%rax
jnc .L1288
call rt_abort
.L1288:
movzbq (%rax),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt31
call rt_pushb
jmp .Lopt32
.Lopt31:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt32:
movq %rbx,%rax
addq $1,%rax
jnc .L1289
call rt_abort
.L1289:
movq %rax,%rbx
jmp .L1286
.L1287:
movq %r12,%rax
movq -.F1285-8(%rbp),%rbx
movq -.F1285-16(%rbp),%r12
movq -.F1285-24(%rbp),%r13
movq -.F1285-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1285-8(%rbp),%rbx
movq -.F1285-16(%rbp),%r12
movq -.F1285-24(%rbp),%r13
movq -.F1285-32(%rbp),%r14
leave
ret
.set .F1285,16
.type f_host_env,@function
f_host_env:
pushq %rbp
movq %rsp,%rbp
subq $.F1290,%rsp
subq $48,%rsp
movq %rbx,-.F1290-8(%rbp)
movq %r12,-.F1290-16(%rbp)
movq %r13,-.F1290-24(%rbp)
movq %r14,-.F1290-32(%rbp)
movq %r15,-.F1290-40(%rbp)
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
jnc .L1291
call rt_abort
.L1291:
movq (%rax),%rax
movq %rax,-24(%rbp)
.L1292:
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1293
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,%r13
movq $0,%rbx
movq $1,-40(%rbp)
.L1294:
cmpq %r14,%rbx
jae .L1295
movq %r13,%rax
addq %rbx,%rax
jnc .L1296
call rt_abort
.L1296:
movzbq (%rax),%rax
movq %rax,%r15
movq -8(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt33
call rt_abort
.Lopt33:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r15
je .L1297
movq $0,-40(%rbp)
jmp .L1295
jmp .L1298
.L1297:
.L1298:
movq %rbx,%rax
addq $1,%rax
jnc .L1299
call rt_abort
.L1299:
movq %rax,%rbx
jmp .L1294
.L1295:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L1300
movq %r13,%rax
addq %r14,%rax
jnc .L1302
call rt_abort
.L1302:
movzbq (%rax),%rax
movq %rax,-48(%rbp)
cmpq $61,%rax
jne .L1303
movq $0,%r12
.L1305:
movq %r13,%rax
addq %r14,%rax
jnc .L1307
call rt_abort
.L1307:
movq %rax,-56(%rbp)
addq $1,%rax
jnc .L1308
call rt_abort
.L1308:
addq %r12,%rax
jnc .L1309
call rt_abort
.L1309:
movzbq (%rax),%rax
movq %rax,-64(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1306
movq %r12,%rax
addq $1,%rax
jnc .L1310
call rt_abort
.L1310:
movq %rax,%r12
jmp .L1305
.L1306:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r13,%rax
addq %r14,%rax
jnc .L1311
call rt_abort
.L1311:
movq %rax,-72(%rbp)
movabsq $1,%rcx
addq $1,%rax
jnc .L1312
call rt_abort
.L1312:
movq %rax,-80(%rbp)
movq -80(%rbp),%rdi
movq %r12,%rsi
call rt_bytes_from
movq -.F1290-8(%rbp),%rbx
movq -.F1290-16(%rbp),%r12
movq -.F1290-24(%rbp),%r13
movq -.F1290-32(%rbp),%r14
movq -.F1290-40(%rbp),%r15
leave
ret
jmp .L1304
.L1303:
.L1304:
jmp .L1301
.L1300:
.L1301:
movq -24(%rbp),%rax
addq $8,%rax
jnc .L1313
call rt_abort
.L1313:
movq %rax,-24(%rbp)
jmp .L1292
.L1293:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
call rt_new
movq -.F1290-8(%rbp),%rbx
movq -.F1290-16(%rbp),%r12
movq -.F1290-24(%rbp),%r13
movq -.F1290-32(%rbp),%r14
movq -.F1290-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1290-8(%rbp),%rbx
movq -.F1290-16(%rbp),%r12
movq -.F1290-24(%rbp),%r13
movq -.F1290-32(%rbp),%r14
movq -.F1290-40(%rbp),%r15
leave
ret
.set .F1290,80
.type f_host_exe_path,@function
f_host_exe_path:
pushq %rbp
movq %rsp,%rbp
subq $.F1314,%rsp
subq $32,%rsp
movq %rbx,-.F1314-8(%rbp)
movq %r12,-.F1314-16(%rbp)
movq %r13,-.F1314-24(%rbp)
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
jnc .L1315
call rt_abort
.L1315:
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
jmp .Lret_i50
xorq %rax,%rax
jmp .Lret_i50
.Lret_i50:
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1316
movq %r13,%rdi
call rt_free
movq -24(%rbp),%rax
movq %r12,%rdi
movq %rax,%rsi
call rt_bytes_from
movq %rax,%r13
jmp .L1317
.L1316:
.L1317:
movq %r12,%rdi
call rt_free
movq %r13,%rax
movq -.F1314-8(%rbp),%rbx
movq -.F1314-16(%rbp),%r12
movq -.F1314-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1314-8(%rbp),%rbx
movq -.F1314-16(%rbp),%r12
movq -.F1314-24(%rbp),%r13
leave
ret
.set .F1314,32
.type f_host_exists,@function
f_host_exists:
pushq %rbp
movq %rsp,%rbp
subq $.F1318,%rsp
subq $16,%rsp
movq %rbx,-.F1318-8(%rbp)
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
jne .L1319
movabsq $0,%rax
movq -.F1318-8(%rbp),%rbx
leave
ret
jmp .L1320
.L1319:
.L1320:
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
jmp .Lret_i51
xorq %rax,%rax
jmp .Lret_i51
.Lret_i51:
movq %rax,-24(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1318-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1318-8(%rbp),%rbx
leave
ret
.set .F1318,32
.type f_host_mkdir,@function
f_host_mkdir:
pushq %rbp
movq %rsp,%rbp
subq $.F1321,%rsp
subq $16,%rsp
movq %rbx,-.F1321-8(%rbp)
movq %r12,-.F1321-16(%rbp)
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
jne .L1322
movabsq $22,%rax
movq -.F1321-8(%rbp),%rbx
movq -.F1321-16(%rbp),%r12
leave
ret
jmp .L1323
.L1322:
.L1323:
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
jne .L1324
movabsq $0,%rax
movq -.F1321-8(%rbp),%rbx
movq -.F1321-16(%rbp),%r12
leave
ret
jmp .L1325
.L1324:
.L1325:
movq %r12,%rdi
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
testq %rax,%rax
jz .L1326
movabsq $0,%rax
subq %r12,%rax
movq -.F1321-8(%rbp),%rbx
movq -.F1321-16(%rbp),%r12
leave
ret
jmp .L1327
.L1326:
.L1327:
movabsq $0,%rax
movq -.F1321-8(%rbp),%rbx
movq -.F1321-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1321-8(%rbp),%rbx
movq -.F1321-16(%rbp),%r12
leave
ret
.set .F1321,16
.type f_host_list_dir,@function
f_host_list_dir:
pushq %rbp
movq %rsp,%rbp
subq $.F1328,%rsp
subq $48,%rsp
movq %rbx,-.F1328-8(%rbp)
movq %r12,-.F1328-16(%rbp)
movq %r13,-.F1328-24(%rbp)
movq %r14,-.F1328-32(%rbp)
movq %r15,-.F1328-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F1328(%rbp),%rdi
movq $.F1328/8-1,%rcx
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
jne .L1329
movq -16(%rbp),%rax
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
movq -.F1328-24(%rbp),%r13
movq -.F1328-32(%rbp),%r14
movq -.F1328-40(%rbp),%r15
leave
ret
jmp .L1330
.L1329:
.L1330:
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
jmp .Lret_i53
xorq %rax,%rax
jmp .Lret_i53
.Lret_i53:
testq %rax,%rax
jz .L1331
movq -16(%rbp),%rax
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
movq -.F1328-24(%rbp),%r13
movq -.F1328-32(%rbp),%r14
movq -.F1328-40(%rbp),%r15
leave
ret
jmp .L1332
.L1331:
.L1332:
movabsq $8192,%rdi
call rt_alloc
movq %rax,-40(%rbp)
.L1333:
movabsq $1,%rax
testq %rax,%rax
jz .L1334
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
jmp .Lret_i54
xorq %rax,%rax
jmp .Lret_i54
.Lret_i54:
movq %rax,%rcx
movq -64(%rbp),%rax
addq %rcx,%rax
jnc .L1335
call rt_abort
.L1335:
testq %rax,%rax
jz .L1336
jmp .L1334
jmp .L1337
.L1336:
.L1337:
movq $0,%r14
.L1338:
movq -48(%rbp),%rcx
cmpq %rcx,%r14
jae .L1339
movq -40(%rbp),%rax
addq %r14,%rax
jnc .L1340
call rt_abort
.L1340:
movq %rax,%r12
movq %rax,-72(%rbp)
addq $16,%rax
jnc .L1341
call rt_abort
.L1341:
movzbq (%rax),%rax
movq %rax,-80(%rbp)
movq %r12,%rax
addq $17,%rax
jnc .L1342
call rt_abort
.L1342:
movzbq (%rax),%rax
movq %rax,-88(%rbp)
movabsq $256,%rcx
mulq %rcx
jnc .L1343
call rt_abort
.L1343:
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L1344
call rt_abort
.L1344:
movq %rax,-96(%rbp)
movq %r12,%rax
addq $18,%rax
jnc .L1345
call rt_abort
.L1345:
movzbq (%rax),%rax
movq %rax,-104(%rbp)
movq $0,%rbx
.L1346:
movq %r12,%rax
addq $19,%rax
jnc .L1348
call rt_abort
.L1348:
addq %rbx,%rax
jnc .L1349
call rt_abort
.L1349:
movzbq (%rax),%rax
cmpq $0,%rax
je .L1347
movq %rbx,%rax
addq $1,%rax
jnc .L1350
call rt_abort
.L1350:
movq %rax,%rbx
jmp .L1346
.L1347:
movq %r12,%rax
addq $19,%rax
jnc .L1351
call rt_abort
.L1351:
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
jnc .L1352
call rt_abort
.L1352:
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
jnc .L1353
call rt_abort
.L1353:
movq %rax,%rcx
movq -120(%rbp),%rax
andq %rcx,%rax
movq %rax,-152(%rbp)
cmpq $0,%rax
jne .L1354
movabsq $19,%rcx
movq %r12,%rax
addq $19,%rax
jnc .L1356
call rt_abort
.L1356:
movq %rax,-160(%rbp)
movq -160(%rbp),%rdi
movq %rbx,%rsi
call rt_bytes_from
movq %rax,%r15
movq -104(%rbp),%rax
cmpq $4,%rax
jne .L1357
movq %r15,%rdi
movabsq $47,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt34
call rt_pushb
jmp .Lopt35
.Lopt34:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt35:
jmp .L1358
.L1357:
.L1358:
movq -16(%rbp),%rdi
movq %r15,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt36
call rt_push
jmp .Lopt37
.Lopt36:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt37:
jmp .L1355
.L1354:
.L1355:
movq %r14,%rax
movq -96(%rbp),%rcx
addq %rcx,%rax
jnc .L1359
call rt_abort
.L1359:
movq %rax,%r14
jmp .L1338
.L1339:
jmp .L1333
.L1334:
movabsq $3,%rdi
movq -32(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
movq -.F1328-24(%rbp),%r13
movq -.F1328-32(%rbp),%r14
movq -.F1328-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1328-8(%rbp),%rbx
movq -.F1328-16(%rbp),%r12
movq -.F1328-24(%rbp),%r13
movq -.F1328-32(%rbp),%r14
movq -.F1328-40(%rbp),%r15
leave
ret
.set .F1328,160
.type rt_int_mask,@function
rt_int_mask:
pushq %rbp
movq %rsp,%rbp
subq $.F1360,%rsp
subq $32,%rsp
movq %rbx,-.F1360-8(%rbp)
movq %r12,-.F1360-16(%rbp)
movq %r13,-.F1360-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
cmpq $64,%r13
jne .L1361
movabsq $18446744073709551615,%rax
movq -.F1360-8(%rbp),%rbx
movq -.F1360-16(%rbp),%r12
movq -.F1360-24(%rbp),%r13
leave
ret
jmp .L1362
.L1361:
.L1362:
movq $1,%r12
movq $0,%rbx
.L1363:
cmpq %r13,%rbx
jae .L1364
movq %r12,%rax
addq %r12,%rax
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L1365
call rt_abort
.L1365:
movq %rax,%rbx
jmp .L1363
.L1364:
movq %r12,%rax
subq $1,%rax
jnc .L1366
call rt_abort
.L1366:
movq -.F1360-8(%rbp),%rbx
movq -.F1360-16(%rbp),%r12
movq -.F1360-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1360-8(%rbp),%rbx
movq -.F1360-16(%rbp),%r12
movq -.F1360-24(%rbp),%r13
leave
ret
.set .F1360,16
.type rt_int_neg,@function
rt_int_neg:
pushq %rbp
movq %rsp,%rbp
subq $.F1367,%rsp
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
.set .F1367,16
.type rt_int_fit,@function
rt_int_fit:
pushq %rbp
movq %rsp,%rbp
subq $.F1368,%rsp
subq $16,%rsp
movq %rbx,-.F1368-8(%rbp)
movq %r12,-.F1368-16(%rbp)
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
jne .L1369
movabsq $1,%rax
movq -.F1368-8(%rbp),%rbx
movq -.F1368-16(%rbp),%r12
leave
ret
jmp .L1370
.L1369:
.L1370:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_int_mask
movq %rax,%r12
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1371
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1373:
movq %rax,-32(%rbp)
addq $1,%rax
jnc .L1374
call rt_abort
.L1374:
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
jnc .L1375
call rt_abort
.L1375:
movq -.F1368-8(%rbp),%rbx
movq -.F1368-16(%rbp),%r12
leave
ret
jmp .L1372
.L1371:
.L1372:
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
jnc .L1376
call rt_abort
.L1376:
movq -.F1368-8(%rbp),%rbx
movq -.F1368-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1368-8(%rbp),%rbx
movq -.F1368-16(%rbp),%r12
leave
ret
.set .F1368,64
.type rt_int_truncate,@function
rt_int_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F1377,%rsp
subq $16,%rsp
movq %rbx,-.F1377-8(%rbp)
movq %r12,-.F1377-16(%rbp)
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
jne .L1378
movq -8(%rbp),%rax
movq -.F1377-8(%rbp),%rbx
movq -.F1377-16(%rbp),%r12
leave
ret
jmp .L1379
.L1378:
.L1379:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_int_mask
movq %rax,%rbx
movq -8(%rbp),%rax
andq %rbx,%rax
movq %rax,%r12
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1380
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1382:
movq %rax,-32(%rbp)
addq $1,%rax
jnc .L1383
call rt_abort
.L1383:
movq %rax,-40(%rbp)
movq %r12,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%r12
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L1384
movabsq $18446744073709551615,%rax
xorq %rbx,%rax
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L1386
call rt_abort
.L1386:
movq -.F1377-8(%rbp),%rbx
movq -.F1377-16(%rbp),%r12
leave
ret
jmp .L1385
.L1384:
.L1385:
jmp .L1381
.L1380:
.L1381:
movq %r12,%rax
movq -.F1377-8(%rbp),%rbx
movq -.F1377-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1377-8(%rbp),%rbx
movq -.F1377-16(%rbp),%r12
leave
ret
.set .F1377,48
.type rt_int_abs,@function
rt_int_abs:
pushq %rbp
movq %rsp,%rbp
subq $.F1387,%rsp
subq $16,%rsp
movq %rbx,-.F1387-8(%rbp)
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
jmp .Lret_i55
xorq %rax,%rax
jmp .Lret_i55
.Lret_i55:
testq %rax,%rax
jz .L1388
movabsq $0,%rax
subq %rbx,%rax
movq -.F1387-8(%rbp),%rbx
leave
ret
jmp .L1389
.L1388:
.L1389:
movq %rbx,%rax
movq -.F1387-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1387-8(%rbp),%rbx
leave
ret
.set .F1387,16
.type rt_int,@function
rt_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1390,%rsp
subq $48,%rsp
movq %rbx,-.F1390-8(%rbp)
movq %r12,-.F1390-16(%rbp)
movq %r13,-.F1390-24(%rbp)
movq %r14,-.F1390-32(%rbp)
movq %r15,-.F1390-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r12
movq %rdx,%rbx
movq %rcx,-32(%rbp)
leaq -.F1390(%rbp),%rdi
movq $.F1390/8-4,%rcx
xorl %eax,%eax
rep stosq
movq -32(%rbp),%rax
andq $255,%rax
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1391:
movq %rax,-48(%rbp)
andq $1,%rax
movq %rax,-56(%rbp)
movq -32(%rbp),%rax
movq %rax,%rdx
andq $511,%rdx
shrq $9,%rax
.L1392:
movq %rax,-64(%rbp)
andq $1,%rax
movq %rax,-72(%rbp)
movq $0,%r14
movq $0,%r15
cmpq $43,%r13
jne .L1393
movq %r12,%rax
addq %rbx,%rax
movq %rax,%r14
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1395
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1397
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
jmp .Lret_i56
xorq %rax,%rax
jmp .Lret_i56
.Lret_i56:
movq %rax,%r15
jmp .L1398
.L1397:
movq %r14,%rax
cmpq %r12,%r14
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1398:
jmp .L1396
.L1395:
.L1396:
jmp .L1394
.L1393:
.L1394:
cmpq $45,%r13
jne .L1399
movq %r12,%rax
subq %rbx,%rax
movq %rax,%r14
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1401
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1403
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
jmp .Lret_i57
xorq %rax,%rax
jmp .Lret_i57
.Lret_i57:
movq %rax,%r15
jmp .L1404
.L1403:
movq %r12,%rax
cmpq %rbx,%r12
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1404:
jmp .L1402
.L1401:
.L1402:
jmp .L1400
.L1399:
.L1400:
cmpq $42,%r13
jne .L1405
movq %r12,%rax
movq %rbx,%rcx
imulq %rcx,%rax
movq %rax,%r14
movabsq $64,%rcx
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1407
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
je .L1409
movq -96(%rbp),%rax
movq -112(%rbp),%rdi
movq %rax,%rsi
call rt_div
movq -104(%rbp),%rcx
cmpq %rcx,%rax
je .L1411
movq $1,%r15
jmp .L1412
.L1411:
.L1412:
jmp .L1410
.L1409:
.L1410:
movq %r15,%rax
cmpq $0,%r15
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1413
movq %r12,%rdi
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
movq %rax,-120(%rbp)
movq %rbx,%rdi
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
movq %rax,%rcx
movq -120(%rbp),%rax
xorq %rcx,%rax
testq %rax,%rax
jz .L1415
movq -112(%rbp),%rcx
movabsq $9223372036854775808,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r15
jmp .L1416
.L1415:
movq -112(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1416:
jmp .L1414
.L1413:
.L1414:
jmp .L1408
.L1407:
.L1408:
jmp .L1406
.L1405:
.L1406:
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
jnc .L1417
call rt_abort
.L1417:
testq %rax,%rax
jz .L1418
movabsq $0,%rcx
cmpq $0,%rbx
jne .L1420
call rt_abort
jmp .L1421
.L1420:
.L1421:
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1422
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
jnc .L1424
call rt_abort
.L1424:
movq %rax,%rcx
movq -152(%rbp),%rax
subq %rcx,%rax
jnc .L1425
call rt_abort
.L1425:
movq %rax,-160(%rbp)
movabsq $47,%rcx
cmpq $47,%r13
jne .L1426
movq %r12,%rdi
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
movq %rax,-168(%rbp)
movq %rbx,%rdi
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
movq %rax,%rcx
movq -168(%rbp),%rax
xorq %rcx,%rax
testq %rax,%rax
jz .L1428
movq -144(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%r14
jmp .L1429
.L1428:
movq -144(%rbp),%rax
movq %rax,%r14
.L1429:
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
jmp .Lret_i62
xorq %rax,%rax
jmp .Lret_i62
.Lret_i62:
movq %rax,-192(%rbp)
movq %rbx,%rdi
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
jz .L1430
movq $1,%r15
jmp .L1431
.L1430:
.L1431:
jmp .L1427
.L1426:
movq %r12,%rdi
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
testq %rax,%rax
jz .L1432
movq -160(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%r14
jmp .L1433
.L1432:
movq -160(%rbp),%rax
movq %rax,%r14
.L1433:
.L1427:
jmp .L1423
.L1422:
movq %r12,%rdi
movq %rbx,%rsi
call rt_div
movq %rax,-208(%rbp)
cmpq $47,%r13
jne .L1434
movq -208(%rbp),%rax
movq %rax,%r14
jmp .L1435
.L1434:
movq -208(%rbp),%rax
movq %rbx,%rcx
mulq %rcx
jnc .L1436
call rt_abort
.L1436:
movq %rax,%rcx
movq %r12,%rax
subq %rcx,%rax
jnc .L1437
call rt_abort
.L1437:
movq %rax,%r14
.L1435:
.L1423:
jmp .L1419
.L1418:
.L1419:
cmpq $38,%r13
jne .L1438
movq %r12,%rax
andq %rbx,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1439
.L1438:
.L1439:
cmpq $94,%r13
jne .L1440
movq %r12,%rax
xorq %rbx,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1441
.L1440:
.L1441:
cmpq $124,%r13
jne .L1442
movabsq $18446744073709551615,%rax
xorq %rbx,%rax
movq %rax,%rcx
movq %r12,%rax
andq %rcx,%rax
addq %rbx,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1443
.L1442:
.L1443:
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
jnc .L1444
call rt_abort
.L1444:
testq %rax,%rax
jz .L1445
movq %rbx,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,-224(%rbp)
cmpq $0,%rax
jne .L1447
movabsq $0,%rcx
movq -72(%rbp),%rax
cmpq $0,%rax
jne .L1449
call rt_abort
jmp .L1450
.L1449:
.L1450:
movabsq $0,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1448
.L1447:
.L1448:
movq $1,-232(%rbp)
movq $0,-240(%rbp)
.L1451:
movq -240(%rbp),%rax
cmpq %rbx,%rax
jae .L1452
movq -232(%rbp),%rax
addq %rax,%rax
movq %rax,-232(%rbp)
movq -240(%rbp),%rax
addq $1,%rax
jnc .L1453
call rt_abort
.L1453:
movq %rax,-240(%rbp)
jmp .L1451
.L1452:
movabsq $271,%rcx
cmpq $271,%r13
jne .L1454
movq %r12,%rax
movq -232(%rbp),%rcx
imulq %rcx,%rax
movq %rax,-248(%rbp)
movq -56(%rbp),%rax
movq -248(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1455
.L1454:
.L1455:
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
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1456
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
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1457
.L1456:
.L1457:
movq -232(%rbp),%rax
movq %r12,%rdi
movq %rax,%rsi
call rt_div
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1446
.L1445:
.L1446:
cmpq $258,%r13
jne .L1458
movq %r12,%rax
cmpq %rbx,%r12
sete %al
movzbq %al,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1459
.L1458:
.L1459:
cmpq $259,%r13
jne .L1460
movq %r12,%rax
cmpq %rbx,%r12
setne %al
movzbq %al,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1461
.L1460:
.L1461:
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
jnc .L1462
call rt_abort
.L1462:
movq %rax,-288(%rbp)
movq %r13,%rax
cmpq $269,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -288(%rbp),%rax
addq %rcx,%rax
jnc .L1463
call rt_abort
.L1463:
movq %rax,-296(%rbp)
movq %r13,%rax
cmpq $270,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -296(%rbp),%rax
addq %rcx,%rax
jnc .L1464
call rt_abort
.L1464:
testq %rax,%rax
jz .L1465
movq %r12,-304(%rbp)
movq %rbx,-312(%rbp)
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1467
movabsq $9223372036854775808,%rcx
movq %r12,%rax
xorq %rcx,%rax
movq %rax,-304(%rbp)
movabsq $9223372036854775808,%rcx
movq %rbx,%rax
xorq %rcx,%rax
movq %rax,-312(%rbp)
jmp .L1468
.L1467:
.L1468:
cmpq $60,%r13
jne .L1469
movq -304(%rbp),%rax
movq -312(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1470
.L1469:
.L1470:
cmpq $62,%r13
jne .L1471
movq -312(%rbp),%rax
movq -304(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1472
.L1471:
.L1472:
cmpq $269,%r13
jne .L1473
movq -312(%rbp),%rax
movq -304(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-320(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1474
.L1473:
.L1474:
movq -304(%rbp),%rax
movq -312(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-328(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1466
.L1465:
.L1466:
movabsq $267,%rcx
cmpq $267,%r13
jne .L1475
movq %rbx,%rdi
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
testq %rax,%rax
jz .L1477
call rt_abort
jmp .L1478
.L1477:
.L1478:
movq $1,-336(%rbp)
movq $0,-344(%rbp)
.L1479:
movq -344(%rbp),%rax
cmpq %rbx,%rax
jae .L1480
movq -32(%rbp),%rax
movabsq $42,%rdi
movq -336(%rbp),%rsi
movq %r12,%rdx
movq %rax,%rcx
call rt_int
movq %rax,-336(%rbp)
movq -344(%rbp),%rax
addq $1,%rax
jnc .L1481
call rt_abort
.L1481:
movq %rax,-344(%rbp)
jmp .L1479
.L1480:
movq -336(%rbp),%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1476
.L1475:
.L1476:
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
jz .L1482
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
jmp .L1483
.L1482:
.L1483:
testq %r15,%r15
jz .L1484
movabsq $0,%rcx
movq -72(%rbp),%rax
cmpq $0,%rax
jne .L1486
call rt_abort
jmp .L1487
.L1486:
.L1487:
movq -56(%rbp),%rax
movq %r14,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
jmp .L1485
.L1484:
.L1485:
movq %r14,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1390-8(%rbp),%rbx
movq -.F1390-16(%rbp),%r12
movq -.F1390-24(%rbp),%r13
movq -.F1390-32(%rbp),%r14
movq -.F1390-40(%rbp),%r15
leave
ret
.set .F1390,368
.type rt_int_cast,@function
rt_int_cast:
pushq %rbp
movq %rsp,%rbp
subq $.F1488,%rsp
subq $32,%rsp
movq %rbx,-.F1488-8(%rbp)
movq %r12,-.F1488-16(%rbp)
movq %r13,-.F1488-24(%rbp)
movq %r14,-.F1488-32(%rbp)
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
.L1489:
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
.L1490:
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
jmp .Lret_i67
xorq %rax,%rax
jmp .Lret_i67
.Lret_i67:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
movq %rax,-64(%rbp)
movq $1,%r13
movabsq $0,%rcx
movq -56(%rbp),%rax
cmpq $0,%rax
jne .L1491
movq -64(%rbp),%rax
testq %rax,%rax
jz .L1493
movq $0,%r13
jmp .L1494
.L1493:
movabsq $64,%rcx
cmpq $64,%r12
jae .L1495
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
jnc .L1497
call rt_abort
.L1497:
movq %rax,%r13
jmp .L1496
.L1495:
.L1496:
.L1494:
jmp .L1492
.L1491:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L1498
movabsq $64,%rcx
cmpq $64,%r12
jae .L1500
movq %rbx,%rdi
movq %r12,%rsi
movabsq $1,%rdx
call rt_int_fit
movq %rax,%r13
jmp .L1501
.L1500:
.L1501:
jmp .L1499
.L1498:
movq %r12,%rdi
call rt_int_mask
movq %rax,-80(%rbp)
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1502:
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
jnc .L1503
call rt_abort
.L1503:
movq %rax,%r13
.L1499:
.L1492:
cmpq $0,%r13
jne .L1504
movq %r14,%rax
movq %rax,%rdx
andq $511,%rdx
shrq $9,%rax
.L1506:
movq %rax,-104(%rbp)
movabsq $1,%rcx
andq $1,%rax
testq %rax,%rax
jz .L1507
movq -56(%rbp),%rax
movq %rbx,%rdi
movq %r12,%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1488-8(%rbp),%rbx
movq -.F1488-16(%rbp),%r12
movq -.F1488-24(%rbp),%r13
movq -.F1488-32(%rbp),%r14
leave
ret
jmp .L1508
.L1507:
.L1508:
call rt_abort
jmp .L1505
.L1504:
.L1505:
movq %rbx,%rax
movq -.F1488-8(%rbp),%rbx
movq -.F1488-16(%rbp),%r12
movq -.F1488-24(%rbp),%r13
movq -.F1488-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1488-8(%rbp),%rbx
movq -.F1488-16(%rbp),%r12
movq -.F1488-24(%rbp),%r13
movq -.F1488-32(%rbp),%r14
leave
ret
.set .F1488,112
.type rt_print_int,@function
rt_print_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1509,%rsp
subq $16,%rsp
movq %rbx,-.F1509-8(%rbp)
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
.L1510:
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
jmp .Lret_i68
xorq %rax,%rax
jmp .Lret_i68
.Lret_i68:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1511
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
je .L1513
call rt_abort
jmp .L1514
.L1513:
.L1514:
movq %rbx,%rcx
movabsq $0,%rax
subq %rbx,%rax
movq %rax,-72(%rbp)
movq -16(%rbp),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_print_number
movq -.F1509-8(%rbp),%rbx
leave
ret
jmp .L1512
.L1511:
.L1512:
movq -16(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_print_number
movq -.F1509-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1509-8(%rbp),%rbx
leave
ret
.set .F1509,80
.type rt_print_bool,@function
rt_print_bool:
pushq %rbp
movq %rsp,%rbp
subq $.F1515,%rsp
subq $16,%rsp
movq %rbx,-.F1515-8(%rbp)
movq %r12,-.F1515-16(%rbp)
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
jnc .L1516
call rt_abort
.L1516:
movq %rax,%r12
movabsq $8,%rdi
call rt_alloc
movq %rax,%rbx
movq -8(%rbp),%rax
testq %rax,%rax
jz .L1517
movq %rbx,%rcx
movabsq $116,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1519
call rt_abort
.L1519:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $114,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L1520
call rt_abort
.L1520:
movq %rax,-32(%rbp)
movq %rax,%rcx
movabsq $117,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L1521
call rt_abort
.L1521:
movq %rax,-40(%rbp)
movq %rax,%rcx
movabsq $101,%rax
movb %al,(%rcx)
xorq %rax,%rax
jmp .L1518
.L1517:
movq %rbx,%rcx
movabsq $102,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1522
call rt_abort
.L1522:
movq %rax,-48(%rbp)
movq %rax,%rcx
movabsq $97,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L1523
call rt_abort
.L1523:
movq %rax,-56(%rbp)
movq %rax,%rcx
movabsq $108,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L1524
call rt_abort
.L1524:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $115,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $4,%rax
jnc .L1525
call rt_abort
.L1525:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $101,%rax
movb %al,(%rcx)
xorq %rax,%rax
.L1518:
movq %r12,-80(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1526
movq %rbx,%rax
addq %r12,%rax
jnc .L1528
call rt_abort
.L1528:
movq %rax,-88(%rbp)
movq %rax,%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1529
call rt_abort
.L1529:
movq %rax,-80(%rbp)
jmp .L1527
.L1526:
.L1527:
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
je .L1530
call rt_abort
jmp .L1531
.L1530:
.L1531:
movabsq $0,%rax
movq -.F1515-8(%rbp),%rbx
movq -.F1515-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1515-8(%rbp),%rbx
movq -.F1515-16(%rbp),%r12
leave
ret
.set .F1515,96
.type rt_sockaddr,@function
rt_sockaddr:
pushq %rbp
movq %rsp,%rbp
subq $.F1532,%rsp
subq $16,%rsp
movq %rbx,-.F1532-8(%rbp)
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
.L1533:
movabsq $256,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1534
call rt_abort
.L1534:
movq %rax,-24(%rbp)
movq -16(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1535
call rt_abort
.L1535:
movq %rax,-32(%rbp)
movabsq $65536,%rcx
mulq %rcx
jnc .L1536
call rt_abort
.L1536:
movq %rax,%rcx
movabsq $2,%rax
addq %rcx,%rax
jnc .L1537
call rt_abort
.L1537:
movq %rax,-40(%rbp)
movabsq $4294967296,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L1538
call rt_abort
.L1538:
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L1539
call rt_abort
.L1539:
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L1540
call rt_abort
.L1540:
movq %rax,-48(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
movq -.F1532-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1532-8(%rbp),%rbx
leave
ret
.set .F1532,48
.type rt_tcp_socket,@function
rt_tcp_socket:
pushq %rbp
movq %rsp,%rbp
subq $.F1541,%rsp
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
jmp .Lret_i69
xorq %rax,%rax
jmp .Lret_i69
.Lret_i69:
testq %rax,%rax
jz .L1542
call rt_abort
jmp .L1543
.L1542:
.L1543:
movq -8(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1541,16
.type f_host_tcp_listen,@function
f_host_tcp_listen:
pushq %rbp
movq %rsp,%rbp
subq $.F1544,%rsp
subq $16,%rsp
movq %rbx,-.F1544-8(%rbp)
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
jmp .Lret_i70
xorq %rax,%rax
jmp .Lret_i70
.Lret_i70:
testq %rax,%rax
jz .L1545
call rt_abort
jmp .L1546
.L1545:
.L1546:
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
jmp .Lret_i71
xorq %rax,%rax
jmp .Lret_i71
.Lret_i71:
testq %rax,%rax
jz .L1547
call rt_abort
jmp .L1548
.L1547:
.L1548:
movq %rbx,%rax
movq -.F1544-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1544-8(%rbp),%rbx
leave
ret
.set .F1544,32
.type f_host_tcp_port,@function
f_host_tcp_port:
pushq %rbp
movq %rsp,%rbp
subq $.F1549,%rsp
subq $16,%rsp
movq %rbx,-.F1549-8(%rbp)
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
jnc .L1550
call rt_abort
.L1550:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $16,%rax
movq $16,(%rcx)
xorq $16,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1551
call rt_abort
.L1551:
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
jmp .Lret_i72
xorq %rax,%rax
jmp .Lret_i72
.Lret_i72:
testq %rax,%rax
jz .L1552
call rt_abort
jmp .L1553
.L1552:
.L1553:
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
.L1554:
movq %rdx,-48(%rbp)
movq %rbx,%rdi
call rt_free
movq -48(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1555:
movabsq $256,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1556
call rt_abort
.L1556:
movq %rax,-56(%rbp)
movq -48(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L1557
call rt_abort
.L1557:
movq -.F1549-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1549-8(%rbp),%rbx
leave
ret
.set .F1549,64
.type f_host_tcp_accept,@function
f_host_tcp_accept:
pushq %rbp
movq %rsp,%rbp
subq $.F1558,%rsp
subq $32,%rsp
movq %rbx,-.F1558-8(%rbp)
movq %r12,-.F1558-16(%rbp)
movq %r13,-.F1558-24(%rbp)
movq %r14,-.F1558-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq $0,-16(%rbp)
.L1559:
movabsq $1,%rax
testq %rax,%rax
jz .L1560
movq %r12,%rdi
call rt_accept4
movq %rax,%rbx
movq %rax,%r13
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
cmpq %rcx,%r13
jne .L1561
movq %r12,%rdi
movabsq $1,%rsi
call rt_wait_fd
movabsq $0,%rcx
cmpq $0,%rax
je .L1563
movabsq $0,%rax
subq $125,%rax
movq -.F1558-8(%rbp),%rbx
movq -.F1558-16(%rbp),%r12
movq -.F1558-24(%rbp),%r13
movq -.F1558-32(%rbp),%r14
leave
ret
jmp .L1564
.L1563:
.L1564:
jmp .L1562
.L1561:
movq %rbx,%rdi
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
jz .L1565
call rt_abort
jmp .L1566
.L1565:
.L1566:
movq %rbx,%rax
movq -.F1558-8(%rbp),%rbx
movq -.F1558-16(%rbp),%r12
movq -.F1558-24(%rbp),%r13
movq -.F1558-32(%rbp),%r14
leave
ret
.L1562:
jmp .L1559
.L1560:
movabsq $0,%rax
movq -.F1558-8(%rbp),%rbx
movq -.F1558-16(%rbp),%r12
movq -.F1558-24(%rbp),%r13
movq -.F1558-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1558-8(%rbp),%rbx
movq -.F1558-16(%rbp),%r12
movq -.F1558-24(%rbp),%r13
movq -.F1558-32(%rbp),%r14
leave
ret
.set .F1558,16
.type rt_ipv4,@function
rt_ipv4:
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
.L1568:
movq -16(%rbp),%rcx
cmpq %rcx,%r12
jae .L1569
movq -8(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt38
call rt_abort
.Lopt38:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r15
movq %rax,-24(%rbp)
cmpq $46,%rax
jne .L1570
movq %rbx,%rax
movq %r13,%rcx
mulq %rcx
jnc .L1572
call rt_abort
.L1572:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1573
call rt_abort
.L1573:
movq %rax,%r14
movabsq $256,%rcx
movq %r13,%rax
mulq %rcx
jnc .L1574
call rt_abort
.L1574:
movq %rax,%r13
movq $0,%rbx
jmp .L1571
.L1570:
movabsq $10,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1575
call rt_abort
.L1575:
addq %r15,%rax
jnc .L1576
call rt_abort
.L1576:
movq %rax,-32(%rbp)
subq $48,%rax
jnc .L1577
call rt_abort
.L1577:
movq %rax,%rbx
.L1571:
movq %r12,%rax
addq $1,%rax
jnc .L1578
call rt_abort
.L1578:
movq %rax,%r12
jmp .L1568
.L1569:
movq %rbx,%rax
movq %r13,%rcx
mulq %rcx
jnc .L1579
call rt_abort
.L1579:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1580
call rt_abort
.L1580:
movq %rax,%r14
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r14,%rax
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
.type f_host_tcp_connect,@function
f_host_tcp_connect:
pushq %rbp
movq %rsp,%rbp
subq $.F1581,%rsp
subq $48,%rsp
movq %rbx,-.F1581-8(%rbp)
movq %r12,-.F1581-16(%rbp)
movq %r13,-.F1581-24(%rbp)
movq %r14,-.F1581-32(%rbp)
movq %r15,-.F1581-40(%rbp)
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
.L1582:
movabsq $1,%rax
testq %rax,%rax
jz .L1583
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
jnc .L1584
call rt_abort
.L1584:
testq %rax,%rax
jz .L1585
movq %r13,%rdi
call rt_free
movq %r12,%rax
movq -.F1581-8(%rbp),%rbx
movq -.F1581-16(%rbp),%r12
movq -.F1581-24(%rbp),%r13
movq -.F1581-32(%rbp),%r14
movq -.F1581-40(%rbp),%r15
leave
ret
jmp .L1586
.L1585:
.L1586:
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
jnc .L1587
call rt_abort
.L1587:
testq %rax,%rax
jz .L1588
movq %r12,%rdi
movabsq $4,%rsi
call rt_wait_fd
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1590
movq %r13,%rdi
call rt_free
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
subq $125,%rax
movq -.F1581-8(%rbp),%rbx
movq -.F1581-16(%rbp),%r12
movq -.F1581-24(%rbp),%r13
movq -.F1581-32(%rbp),%r14
movq -.F1581-40(%rbp),%r15
leave
ret
jmp .L1591
.L1590:
.L1591:
jmp .L1589
.L1588:
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
cmpq %rcx,%rbx
jne .L1592
call rt_yield
jmp .L1593
.L1592:
movq %r13,%rdi
call rt_free
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rbx,%rax
movq -.F1581-8(%rbp),%rbx
movq -.F1581-16(%rbp),%r12
movq -.F1581-24(%rbp),%r13
movq -.F1581-32(%rbp),%r14
movq -.F1581-40(%rbp),%r15
leave
ret
.L1593:
.L1589:
jmp .L1582
.L1583:
movabsq $0,%rax
movq -.F1581-8(%rbp),%rbx
movq -.F1581-16(%rbp),%r12
movq -.F1581-24(%rbp),%r13
movq -.F1581-32(%rbp),%r14
movq -.F1581-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1581-8(%rbp),%rbx
movq -.F1581-16(%rbp),%r12
movq -.F1581-24(%rbp),%r13
movq -.F1581-32(%rbp),%r14
movq -.F1581-40(%rbp),%r15
leave
ret
.set .F1581,48
.type f_host_open,@function
f_host_open:
pushq %rbp
movq %rsp,%rbp
subq $.F1594,%rsp
subq $16,%rsp
movq %rbx,-.F1594-8(%rbp)
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
jne .L1595
movabsq $0,%rax
subq $22,%rax
movq -.F1594-8(%rbp),%rbx
leave
ret
jmp .L1596
.L1595:
.L1596:
movq $524288,-24(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1597
movq $524865,-24(%rbp)
jmp .L1598
.L1597:
.L1598:
movabsq $2,%rdi
movq %rbx,%rsi
movq -24(%rbp),%rdx
movabsq $438,%rcx
call rt_syscall
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F1594-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1594-8(%rbp),%rbx
leave
ret
.set .F1594,32
.type rt_print_raw,@function
rt_print_raw:
pushq %rbp
movq %rsp,%rbp
subq $.F1599,%rsp
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
je .L1600
call rt_abort
jmp .L1601
.L1600:
.L1601:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1599,32
.type rt_fmt_raw,@function
rt_fmt_raw:
pushq %rbp
movq %rsp,%rbp
subq $.F1602,%rsp
subq $32,%rsp
movq %rbx,-.F1602-8(%rbp)
movq %r12,-.F1602-16(%rbp)
movq %r13,-.F1602-24(%rbp)
movq %r14,-.F1602-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,%r13
movq %rdx,%r14
movq $0,-32(%rbp)
movq $0,%rbx
.L1603:
cmpq %r14,%rbx
jae .L1604
movq %r13,%rax
addq %rbx,%rax
jnc .L1605
call rt_abort
.L1605:
movzbq (%rax),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt39
call rt_pushb
jmp .Lopt40
.Lopt39:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt40:
movq %rbx,%rax
addq $1,%rax
jnc .L1606
call rt_abort
.L1606:
movq %rax,%rbx
jmp .L1603
.L1604:
movabsq $0,%rax
movq -.F1602-8(%rbp),%rbx
movq -.F1602-16(%rbp),%r12
movq -.F1602-24(%rbp),%r13
movq -.F1602-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1602-8(%rbp),%rbx
movq -.F1602-16(%rbp),%r12
movq -.F1602-24(%rbp),%r13
movq -.F1602-32(%rbp),%r14
leave
ret
.set .F1602,32
.type rt_fmt_num,@function
rt_fmt_num:
pushq %rbp
movq %rsp,%rbp
subq $.F1607,%rsp
subq $48,%rsp
movq %rbx,-.F1607-8(%rbp)
movq %r12,-.F1607-16(%rbp)
movq %r13,-.F1607-24(%rbp)
movq %r14,-.F1607-32(%rbp)
movq %r15,-.F1607-40(%rbp)
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
.L1608:
movabsq $1,%rax
testq %rax,%rax
jz .L1609
movq %rbx,%rax
subq $1,%rax
jnc .L1610
call rt_abort
.L1610:
movq %rax,%rbx
movq %r15,%rax
addq %rbx,%rax
jnc .L1611
call rt_abort
.L1611:
movq %rax,%r13
movabsq $10,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1612
call rt_abort
.L1612:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L1613
call rt_abort
.L1613:
movq %r13,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
movq %rax,%r14
cmpq $0,%rax
jne .L1614
jmp .L1609
jmp .L1615
.L1614:
.L1615:
jmp .L1608
.L1609:
movq %r15,%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L1616
call rt_abort
.L1616:
movq %rax,-24(%rbp)
movabsq $24,%rax
subq %rbx,%rax
jnc .L1617
call rt_abort
.L1617:
movq -8(%rbp),%rdi
movq -24(%rbp),%rsi
movq %rax,%rdx
call rt_fmt_raw
movq %r15,%rdi
call rt_free
movabsq $0,%rax
movq -.F1607-8(%rbp),%rbx
movq -.F1607-16(%rbp),%r12
movq -.F1607-24(%rbp),%r13
movq -.F1607-32(%rbp),%r14
movq -.F1607-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1607-8(%rbp),%rbx
movq -.F1607-16(%rbp),%r12
movq -.F1607-24(%rbp),%r13
movq -.F1607-32(%rbp),%r14
movq -.F1607-40(%rbp),%r15
leave
ret
.set .F1607,32
.type rt_fmt_int,@function
rt_fmt_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1618,%rsp
subq $16,%rsp
movq %rbx,-.F1618-8(%rbp)
movq %r12,-.F1618-16(%rbp)
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
.L1619:
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
jmp .Lret_i74
xorq %rax,%rax
jmp .Lret_i74
.Lret_i74:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1620
movq %rbx,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt41
call rt_pushb
jmp .Lopt42
.Lopt41:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt42:
movq %r12,%rcx
movabsq $0,%rax
subq %r12,%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_fmt_num
movq -.F1618-8(%rbp),%rbx
movq -.F1618-16(%rbp),%r12
leave
ret
jmp .L1621
.L1620:
.L1621:
movq %rbx,%rdi
movq %r12,%rsi
call rt_fmt_num
movq -.F1618-8(%rbp),%rbx
movq -.F1618-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1618-8(%rbp),%rbx
movq -.F1618-16(%rbp),%r12
leave
ret
.set .F1618,48
.type rt_fmt_bool,@function
rt_fmt_bool:
pushq %rbp
movq %rsp,%rbp
subq $.F1622,%rsp
subq $16,%rsp
movq %rbx,-.F1622-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L1623
movq %rbx,%rdi
movabsq $116,%rsi
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
movq %rbx,%rdi
movabsq $114,%rsi
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
movq %rbx,%rdi
movabsq $117,%rsi
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
movabsq $101,%rsi
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
jmp .L1624
.L1623:
movq %rbx,%rdi
movabsq $102,%rsi
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
movabsq $97,%rsi
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
movq %rbx,%rdi
movabsq $108,%rsi
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
movabsq $115,%rsi
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
movabsq $101,%rsi
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
.L1624:
movabsq $0,%rax
movq -.F1622-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1622-8(%rbp),%rbx
leave
ret
.set .F1622,16
.type rt_fmt_seq,@function
rt_fmt_seq:
pushq %rbp
movq %rsp,%rbp
subq $.F1625,%rsp
subq $32,%rsp
movq %rbx,-.F1625-8(%rbp)
movq %r12,-.F1625-16(%rbp)
movq %r13,-.F1625-24(%rbp)
movq %r14,-.F1625-32(%rbp)
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
.L1626:
cmpq %r14,%rbx
jae .L1627
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt61
call rt_abort
.Lopt61:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt62
call rt_pushb
jmp .Lopt63
.Lopt62:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt63:
movq %rbx,%rax
addq $1,%rax
jnc .L1628
call rt_abort
.L1628:
movq %rax,%rbx
jmp .L1626
.L1627:
movabsq $0,%rax
movq -.F1625-8(%rbp),%rbx
movq -.F1625-16(%rbp),%r12
movq -.F1625-24(%rbp),%r13
movq -.F1625-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1625-8(%rbp),%rbx
movq -.F1625-16(%rbp),%r12
movq -.F1625-24(%rbp),%r13
movq -.F1625-32(%rbp),%r14
leave
ret
.set .F1625,16
.type rt_fmt_finish,@function
rt_fmt_finish:
pushq %rbp
movq %rsp,%rbp
subq $.F1629,%rsp
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
.set .F1629,16
.type rt_f64_pow2,@function
rt_f64_pow2:
pushq %rbp
movq %rsp,%rbp
subq $.F1630,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631
call rt_abort
.L1631:
movq %rax,-16(%rbp)
movabsq $4503599627370496,%rcx
movq -16(%rbp),%rax
imulq %rcx,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1630,16
.type rt_f64_neg,@function
rt_f64_neg:
pushq %rbp
movq %rsp,%rbp
subq $.F1632,%rsp
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
.set .F1632,16
.type rt_f64_abs,@function
rt_f64_abs:
pushq %rbp
movq %rsp,%rbp
subq $.F1633,%rsp
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
.set .F1633,16
.type rt_f64_is_nan,@function
rt_f64_is_nan:
pushq %rbp
movq %rsp,%rbp
subq $.F1634,%rsp
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
.set .F1634,16
.type rt_f64_sqrt,@function
rt_f64_sqrt:
pushq %rbp
movq %rsp,%rbp
subq $.F1635,%rsp
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
.set .F1635,16
.type rt_f64_op,@function
rt_f64_op:
pushq %rbp
movq %rsp,%rbp
subq $.F1636,%rsp
subq $32,%rsp
movq %rbx,-.F1636-8(%rbp)
movq %r12,-.F1636-16(%rbp)
movq %r13,-.F1636-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq $0,-32(%rbp)
cmpq $43,%rbx
jne .L1637
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1636-8(%rbp),%rbx
movq -.F1636-16(%rbp),%r12
movq -.F1636-24(%rbp),%r13
leave
ret
jmp .L1638
.L1637:
.L1638:
cmpq $45,%rbx
jne .L1639
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1636-8(%rbp),%rbx
movq -.F1636-16(%rbp),%r12
movq -.F1636-24(%rbp),%r13
leave
ret
jmp .L1640
.L1639:
.L1640:
cmpq $42,%rbx
jne .L1641
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
mulsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1636-8(%rbp),%rbx
movq -.F1636-16(%rbp),%r12
movq -.F1636-24(%rbp),%r13
leave
ret
jmp .L1642
.L1641:
.L1642:
movabsq $47,%rcx
cmpq $47,%rbx
jne .L1643
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
divsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1636-8(%rbp),%rbx
movq -.F1636-16(%rbp),%r12
movq -.F1636-24(%rbp),%r13
leave
ret
jmp .L1644
.L1643:
.L1644:
call rt_abort
movabsq $0,%rax
movq -.F1636-8(%rbp),%rbx
movq -.F1636-16(%rbp),%r12
movq -.F1636-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1636-8(%rbp),%rbx
movq -.F1636-16(%rbp),%r12
movq -.F1636-24(%rbp),%r13
leave
ret
.set .F1636,32
.type rt_f64_cmp,@function
rt_f64_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F1645,%rsp
subq $32,%rsp
movq %rbx,-.F1645-8(%rbp)
movq %r12,-.F1645-16(%rbp)
movq %r13,-.F1645-24(%rbp)
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
jne .L1646
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
jmp .L1647
.L1646:
.L1647:
cmpq $62,%r13
jne .L1648
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
jmp .L1649
.L1648:
.L1649:
cmpq $269,%r13
jne .L1650
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
jnc .L1652
call rt_abort
.L1652:
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
jmp .L1651
.L1650:
.L1651:
cmpq $270,%r13
jne .L1653
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
jnc .L1655
call rt_abort
.L1655:
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
jmp .L1654
.L1653:
.L1654:
cmpq $258,%r13
jne .L1656
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
jmp .L1657
.L1656:
.L1657:
movabsq $259,%rcx
cmpq $259,%r13
jne .L1658
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
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
jmp .L1659
.L1658:
.L1659:
call rt_abort
movabsq $0,%rax
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1645-8(%rbp),%rbx
movq -.F1645-16(%rbp),%r12
movq -.F1645-24(%rbp),%r13
leave
ret
.set .F1645,48
.type rt_f64_from_int,@function
rt_f64_from_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1660,%rsp
subq $16,%rsp
movq %rbx,-.F1660-8(%rbp)
movq %r12,-.F1660-16(%rbp)
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
.L1661:
movq %rax,-24(%rbp)
movabsq $1,%rcx
andq $1,%rax
testq %rax,%rax
jz .L1662
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq -.F1660-8(%rbp),%rbx
movq -.F1660-16(%rbp),%r12
leave
ret
jmp .L1663
.L1662:
.L1663:
movabsq $9223372036854775808,%rcx
cmpq %rcx,%rbx
jae .L1664
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq -.F1660-8(%rbp),%rbx
movq -.F1660-16(%rbp),%r12
leave
ret
jmp .L1665
.L1664:
.L1665:
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
jz .L1666
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1668
call rt_abort
.L1668:
movq %rax,%r12
jmp .L1667
.L1666:
.L1667:
movq %r12,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq %rax,%rcx
movq %rax,%xmm0
movq %rax,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1660-8(%rbp),%rbx
movq -.F1660-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1660-8(%rbp),%rbx
movq -.F1660-16(%rbp),%r12
leave
ret
.set .F1660,48
.type rt_int_from_f64,@function
rt_int_from_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F1669,%rsp
subq $32,%rsp
movq %rbx,-.F1669-8(%rbp)
movq %r12,-.F1669-16(%rbp)
movq %r13,-.F1669-24(%rbp)
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
.L1670:
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
jne .L1671
call rt_abort
jmp .L1672
.L1671:
.L1672:
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i75
call rt_abort
.L1631_i75:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i75
xorq %rax,%rax
jmp .Lret_i75
.Lret_i75:
movq %rax,-48(%rbp)
movq -32(%rbp),%rax
testq %rax,%rax
jz .L1673
movabsq $1,%rcx
movq %r12,%rax
subq $1,%rax
jnc .L1675
call rt_abort
.L1675:
movq %rax,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i76
call rt_abort
.L1631_i76:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i76
xorq %rax,%rax
jmp .Lret_i76
.Lret_i76:
movq %rax,-56(%rbp)
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775808,%rcx
movq %r8,%rax
xorq %rcx,%rax
jmp .Lret_i77
xorq %rax,%rax
jmp .Lret_i77
.Lret_i77:
movq %rax,%r13
cmpq $64,%r12
jae .L1676
movq %r13,%rax
movq -48(%rbp),%rcx
movq %r13,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq %rax,%r13
jmp .L1677
.L1676:
.L1677:
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
jne .L1678
call rt_abort
jmp .L1679
.L1678:
.L1679:
cmpq $64,%r12
jae .L1680
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
jne .L1682
call rt_abort
jmp .L1683
.L1682:
.L1683:
jmp .L1681
.L1680:
movq %rbx,%rax
movq %r13,%rcx
movq %rbx,%xmm0
movq %r13,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1684
call rt_abort
jmp .L1685
.L1684:
.L1685:
.L1681:
movq %rbx,%rax
movq %rbx,%xmm0
cvttsd2si %xmm0,%rax
movq -.F1669-8(%rbp),%rbx
movq -.F1669-16(%rbp),%r12
movq -.F1669-24(%rbp),%r13
leave
ret
jmp .L1674
.L1673:
.L1674:
movq -48(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775808,%rcx
movq %r8,%rax
xorq %rcx,%rax
jmp .Lret_i78
xorq %rax,%rax
jmp .Lret_i78
.Lret_i78:
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
jne .L1686
call rt_abort
jmp .L1687
.L1686:
.L1687:
movq %r12,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i79
call rt_abort
.L1631_i79:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i79
xorq %rax,%rax
jmp .Lret_i79
.Lret_i79:
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
jne .L1688
call rt_abort
jmp .L1689
.L1688:
.L1689:
movabsq $63,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i80
call rt_abort
.L1631_i80:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i80
xorq %rax,%rax
jmp .Lret_i80
.Lret_i80:
movq %rax,-112(%rbp)
movq %rbx,%rax
movq -112(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1690
movq %rbx,%rax
movq %rbx,%xmm0
cvttsd2si %xmm0,%rax
movq -.F1669-8(%rbp),%rbx
movq -.F1669-16(%rbp),%r12
movq -.F1669-24(%rbp),%r13
leave
ret
jmp .L1691
.L1690:
.L1691:
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
movq -.F1669-8(%rbp),%rbx
movq -.F1669-16(%rbp),%r12
movq -.F1669-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1669-8(%rbp),%rbx
movq -.F1669-16(%rbp),%r12
movq -.F1669-24(%rbp),%r13
leave
ret
.set .F1669,128
.type rt_f64_trunc,@function
rt_f64_trunc:
pushq %rbp
movq %rsp,%rbp
subq $.F1692,%rsp
subq $16,%rsp
movq %rbx,-.F1692-8(%rbp)
movq %r12,-.F1692-16(%rbp)
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
jnc .L1693
call rt_abort
.L1693:
movabsq $52,%rcx
movq %rbx,%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
andq $2047,%rax
movq %rax,%r12
movq %rax,%rcx
movabsq $1074,%rax
cmpq %rcx,%rax
jae .L1694
movq %rbx,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
leave
ret
jmp .L1695
.L1694:
.L1695:
cmpq $1023,%r12
jae .L1696
movabsq $9223372036854775808,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
leave
ret
jmp .L1697
.L1696:
.L1697:
movabsq $1075,%rax
subq %r12,%rax
jnc .L1698
call rt_abort
.L1698:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1699
call rt_abort
.L1699:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,-32(%rbp)
subq $1,%rax
jnc .L1700
call rt_abort
.L1700:
movq %rax,-40(%rbp)
movq %rax,%rcx
movabsq $18446744073709551615,%rax
subq %rcx,%rax
jnc .L1701
call rt_abort
.L1701:
movq %rax,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1692-8(%rbp),%rbx
movq -.F1692-16(%rbp),%r12
leave
ret
.set .F1692,48
.type rt_f64_floor,@function
rt_f64_floor:
pushq %rbp
movq %rsp,%rbp
subq $.F1702,%rsp
subq $16,%rsp
movq %rbx,-.F1702-8(%rbp)
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
jz .L1703
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i81
call rt_abort
.L1631_i81:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i81
xorq %rax,%rax
jmp .Lret_i81
.Lret_i81:
movq %rax,-16(%rbp)
movq %rbx,%rax
movq -16(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1702-8(%rbp),%rbx
leave
ret
jmp .L1704
.L1703:
.L1704:
movq %rbx,%rax
movq -.F1702-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1702-8(%rbp),%rbx
leave
ret
.set .F1702,16
.type rt_f64_ceil,@function
rt_f64_ceil:
pushq %rbp
movq %rsp,%rbp
subq $.F1705,%rsp
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
jz .L1706
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i82
call rt_abort
.L1631_i82:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i82
xorq %rax,%rax
jmp .Lret_i82
.Lret_i82:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,%xmm0
movq %rcx,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
leave
ret
jmp .L1707
.L1706:
.L1707:
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1705,32
.type rt_f64_round,@function
rt_f64_round:
pushq %rbp
movq %rsp,%rbp
subq $.F1708,%rsp
subq $16,%rsp
movq %rbx,-.F1708-8(%rbp)
movq %r12,-.F1708-16(%rbp)
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
jmp .Lret_i83
xorq %rax,%rax
jmp .Lret_i83
.Lret_i83:
movq %rax,-16(%rbp)
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i84
call rt_abort
.L1631_i84:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i84
xorq %rax,%rax
jmp .Lret_i84
.Lret_i84:
movq %rax,-24(%rbp)
movabsq $4503599627370496,%rcx
subq %rcx,%rax
jnc .L1709
call rt_abort
.L1709:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1710
movq %rbx,%rax
movq -.F1708-8(%rbp),%rbx
movq -.F1708-16(%rbp),%r12
leave
ret
jmp .L1711
.L1710:
.L1711:
movabsq $63,%rax
cmpq $63,%rax
jnc .L1712
call rt_abort
.L1712:
movabsq $63,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1713
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i85
call rt_abort
.L1631_i85:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i85
xorq %rax,%rax
jmp .Lret_i85
.Lret_i85:
movq %rax,-48(%rbp)
movq %rbx,%rax
movq -48(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1708-8(%rbp),%rbx
movq -.F1708-16(%rbp),%r12
leave
ret
jmp .L1714
.L1713:
.L1714:
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L1631_i86
call rt_abort
.L1631_i86:
movq %rax,%r9
movabsq $4503599627370496,%rcx
movq %r9,%rax
imulq %rcx,%rax
jmp .Lret_i86
xorq %rax,%rax
jmp .Lret_i86
.Lret_i86:
movq %rax,-56(%rbp)
movq %rbx,%rax
movq -56(%rbp),%rcx
movq %rbx,%xmm0
movq %rcx,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F1708-8(%rbp),%rbx
movq -.F1708-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1708-8(%rbp),%rbx
movq -.F1708-16(%rbp),%r12
leave
ret
.set .F1708,64
.type rt_f64_min,@function
rt_f64_min:
pushq %rbp
movq %rsp,%rbp
subq $.F1715,%rsp
subq $16,%rsp
movq %rbx,-.F1715-8(%rbp)
movq %r12,-.F1715-16(%rbp)
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
jne .L1716
movq %r12,%rax
movq -.F1715-8(%rbp),%rbx
movq -.F1715-16(%rbp),%r12
leave
ret
jmp .L1717
.L1716:
.L1717:
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
jne .L1718
movq %rbx,%rax
movq -.F1715-8(%rbp),%rbx
movq -.F1715-16(%rbp),%r12
leave
ret
jmp .L1719
.L1718:
.L1719:
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1720
movq %r12,%rax
movq -.F1715-8(%rbp),%rbx
movq -.F1715-16(%rbp),%r12
leave
ret
jmp .L1721
.L1720:
.L1721:
movq %rbx,%rax
movq -.F1715-8(%rbp),%rbx
movq -.F1715-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1715-8(%rbp),%rbx
movq -.F1715-16(%rbp),%r12
leave
ret
.set .F1715,32
.type rt_f64_max,@function
rt_f64_max:
pushq %rbp
movq %rsp,%rbp
subq $.F1722,%rsp
subq $16,%rsp
movq %rbx,-.F1722-8(%rbp)
movq %r12,-.F1722-16(%rbp)
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
jne .L1723
movq %r12,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
leave
ret
jmp .L1724
.L1723:
.L1724:
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
jne .L1725
movq %rbx,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
leave
ret
jmp .L1726
.L1725:
.L1726:
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L1727
movq %r12,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
leave
ret
jmp .L1728
.L1727:
.L1728:
movq %rbx,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1722-8(%rbp),%rbx
movq -.F1722-16(%rbp),%r12
leave
ret
.set .F1722,32
.type rt_f64_is_finite,@function
rt_f64_is_finite:
pushq %rbp
movq %rsp,%rbp
subq $.F1729,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L1730
call rt_abort
.L1730:
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
.set .F1729,32
.type rt_f64_is_infinite,@function
rt_f64_is_infinite:
pushq %rbp
movq %rsp,%rbp
subq $.F1731,%rsp
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
.set .F1731,16
.type rt_float_step,@function
rt_float_step:
pushq %rbp
movq %rsp,%rbp
subq $.F1732,%rsp
subq $32,%rsp
movq %rbx,-.F1732-8(%rbp)
movq %r12,-.F1732-16(%rbp)
movq %r13,-.F1732-24(%rbp)
movq %r14,-.F1732-32(%rbp)
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
jne .L1733
movq %r13,%rax
movq -.F1732-8(%rbp),%rbx
movq -.F1732-16(%rbp),%r12
movq -.F1732-24(%rbp),%r13
movq -.F1732-32(%rbp),%r14
leave
ret
jmp .L1734
.L1733:
.L1734:
movq %r13,%rbx
movabsq $9223372036854775808,%rax
movq %rax,%r14
movabsq $9218868437227405312,%rax
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1735
movq %r13,%rdi
call rt_f32_bits
movq %rax,%rbx
movabsq $2147483648,%r14
movq $2139095040,-40(%rbp)
jmp .L1736
.L1735:
.L1736:
movq %r14,%rax
subq $1,%rax
jnc .L1737
call rt_abort
.L1737:
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
jne .L1738
movq $1,%r12
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1740
movabsq $1,%rcx
movq %r14,%rax
orq $1,%rax
movq %rax,%r12
jmp .L1741
.L1740:
.L1741:
jmp .L1739
.L1738:
movq -16(%rbp),%rax
movq -64(%rbp),%rcx
cmpq %rcx,%rax
je .L1742
movq -48(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
je .L1744
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L1746
call rt_abort
.L1746:
movq %rax,%r12
jmp .L1745
.L1744:
.L1745:
jmp .L1743
.L1742:
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L1747
call rt_abort
.L1747:
movq %rax,%r12
.L1743:
.L1739:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1748
movq %r12,%rdi
call rt_f32_from_bits
movq -.F1732-8(%rbp),%rbx
movq -.F1732-16(%rbp),%r12
movq -.F1732-24(%rbp),%r13
movq -.F1732-32(%rbp),%r14
leave
ret
jmp .L1749
.L1748:
.L1749:
movq %r12,%rax
movq -.F1732-8(%rbp),%rbx
movq -.F1732-16(%rbp),%r12
movq -.F1732-24(%rbp),%r13
movq -.F1732-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1732-8(%rbp),%rbx
movq -.F1732-16(%rbp),%r12
movq -.F1732-24(%rbp),%r13
movq -.F1732-32(%rbp),%r14
leave
ret
.set .F1732,64
.type rt_big,@function
rt_big:
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
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $384,%rdi
call rt_alloc
movq %rax,%r13
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
movq %r13,%rax
addq %rcx,%rax
jnc .L1754
call rt_abort
.L1754:
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1755
call rt_abort
.L1755:
movq %rax,%rbx
jmp .L1751
.L1752:
movq -8(%rbp),%rax
movq %rax,%r12
movq $0,%rbx
.L1756:
cmpq $0,%r12
je .L1757
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1758
call rt_abort
.L1758:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1759
call rt_abort
.L1759:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1760
call rt_abort
.L1760:
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
jnc .L1761
call rt_abort
.L1761:
movq %rax,%rbx
jmp .L1756
.L1757:
movq %r13,%rax
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
.set .F1750,16
.type rt_big_mul,@function
rt_big_mul:
pushq %rbp
movq %rsp,%rbp
subq $.F1762,%rsp
subq $48,%rsp
movq %rbx,-.F1762-8(%rbp)
movq %r12,-.F1762-16(%rbp)
movq %r13,-.F1762-24(%rbp)
movq %r14,-.F1762-32(%rbp)
movq %r15,-.F1762-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,-16(%rbp)
movq $0,%r13
movq $0,%rbx
.L1763:
cmpq $48,%rbx
jae .L1764
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1765
call rt_abort
.L1765:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1766
call rt_abort
.L1766:
movq (%rax),%rax
movq -16(%rbp),%rcx
mulq %rcx
jnc .L1767
call rt_abort
.L1767:
addq %r13,%rax
jnc .L1768
call rt_abort
.L1768:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1769
call rt_abort
.L1769:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1770
call rt_abort
.L1770:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1771
call rt_abort
.L1771:
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
jnc .L1772
call rt_abort
.L1772:
movq %rax,%rbx
jmp .L1763
.L1764:
movabsq $0,%rcx
cmpq $0,%r13
je .L1773
call rt_abort
jmp .L1774
.L1773:
.L1774:
movabsq $0,%rax
movq -.F1762-8(%rbp),%rbx
movq -.F1762-16(%rbp),%r12
movq -.F1762-24(%rbp),%r13
movq -.F1762-32(%rbp),%r14
movq -.F1762-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1762-8(%rbp),%rbx
movq -.F1762-16(%rbp),%r12
movq -.F1762-24(%rbp),%r13
movq -.F1762-32(%rbp),%r14
movq -.F1762-40(%rbp),%r15
leave
ret
.set .F1762,16
.type rt_big_add,@function
rt_big_add:
pushq %rbp
movq %rsp,%rbp
subq $.F1775,%rsp
subq $48,%rsp
movq %rbx,-.F1775-8(%rbp)
movq %r12,-.F1775-16(%rbp)
movq %r13,-.F1775-24(%rbp)
movq %r14,-.F1775-32(%rbp)
movq %r15,-.F1775-40(%rbp)
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
.L1776:
cmpq $48,%rbx
jae .L1777
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1778
call rt_abort
.L1778:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1779
call rt_abort
.L1779:
movq (%rax),%rax
movq %rax,%r14
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1780
call rt_abort
.L1780:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1781
call rt_abort
.L1781:
movq (%rax),%rax
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1782
call rt_abort
.L1782:
addq %r13,%rax
jnc .L1783
call rt_abort
.L1783:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1784
call rt_abort
.L1784:
movq %rax,%rcx
movq -8(%rbp),%rax
addq %rcx,%rax
jnc .L1785
call rt_abort
.L1785:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1786
call rt_abort
.L1786:
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
jnc .L1787
call rt_abort
.L1787:
movq %rax,%rbx
jmp .L1776
.L1777:
movabsq $0,%rcx
cmpq $0,%r13
je .L1788
call rt_abort
jmp .L1789
.L1788:
.L1789:
movabsq $0,%rax
movq -.F1775-8(%rbp),%rbx
movq -.F1775-16(%rbp),%r12
movq -.F1775-24(%rbp),%r13
movq -.F1775-32(%rbp),%r14
movq -.F1775-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1775-8(%rbp),%rbx
movq -.F1775-16(%rbp),%r12
movq -.F1775-24(%rbp),%r13
movq -.F1775-32(%rbp),%r14
movq -.F1775-40(%rbp),%r15
leave
ret
.set .F1775,32
.type rt_big_sub,@function
rt_big_sub:
pushq %rbp
movq %rsp,%rbp
subq $.F1790,%rsp
subq $48,%rsp
movq %rbx,-.F1790-8(%rbp)
movq %r12,-.F1790-16(%rbp)
movq %r13,-.F1790-24(%rbp)
movq %r14,-.F1790-32(%rbp)
movq %r15,-.F1790-40(%rbp)
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
.L1791:
cmpq $48,%rbx
jae .L1792
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1793
call rt_abort
.L1793:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1794
call rt_abort
.L1794:
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1795
call rt_abort
.L1795:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1796
call rt_abort
.L1796:
movq (%rax),%rax
addq %r15,%rax
jnc .L1797
call rt_abort
.L1797:
movq %rax,%r13
cmpq %r13,%r12
jae .L1798
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1800
call rt_abort
.L1800:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1801
call rt_abort
.L1801:
movq %rax,-24(%rbp)
movq %r12,%rax
addq $1000000000,%rax
jnc .L1802
call rt_abort
.L1802:
subq %r13,%rax
jnc .L1803
call rt_abort
.L1803:
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $1,%r15
jmp .L1799
.L1798:
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1804
call rt_abort
.L1804:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1805
call rt_abort
.L1805:
movq %rax,-32(%rbp)
movq %r12,%rax
subq %r13,%rax
jnc .L1806
call rt_abort
.L1806:
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $0,%r15
.L1799:
movq %rbx,%rax
addq $1,%rax
jnc .L1807
call rt_abort
.L1807:
movq %rax,%rbx
jmp .L1791
.L1792:
movabsq $0,%rax
movq -.F1790-8(%rbp),%rbx
movq -.F1790-16(%rbp),%r12
movq -.F1790-24(%rbp),%r13
movq -.F1790-32(%rbp),%r14
movq -.F1790-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1790-8(%rbp),%rbx
movq -.F1790-16(%rbp),%r12
movq -.F1790-24(%rbp),%r13
movq -.F1790-32(%rbp),%r14
movq -.F1790-40(%rbp),%r15
leave
ret
.set .F1790,32
.type rt_big_cmp,@function
rt_big_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F1808,%rsp
subq $48,%rsp
movq %rbx,-.F1808-8(%rbp)
movq %r12,-.F1808-16(%rbp)
movq %r13,-.F1808-24(%rbp)
movq %r14,-.F1808-32(%rbp)
movq %r15,-.F1808-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq $48,%rbx
.L1809:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L1810
movq %rbx,%rax
subq $1,%rax
jnc .L1811
call rt_abort
.L1811:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L1812
call rt_abort
.L1812:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1813
call rt_abort
.L1813:
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1814
call rt_abort
.L1814:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1815
call rt_abort
.L1815:
movq (%rax),%rax
movq %rax,%r13
cmpq %r13,%r12
jae .L1816
movabsq $0,%rax
movq -.F1808-8(%rbp),%rbx
movq -.F1808-16(%rbp),%r12
movq -.F1808-24(%rbp),%r13
movq -.F1808-32(%rbp),%r14
movq -.F1808-40(%rbp),%r15
leave
ret
jmp .L1817
.L1816:
.L1817:
cmpq %r12,%r13
jae .L1818
movabsq $2,%rax
movq -.F1808-8(%rbp),%rbx
movq -.F1808-16(%rbp),%r12
movq -.F1808-24(%rbp),%r13
movq -.F1808-32(%rbp),%r14
movq -.F1808-40(%rbp),%r15
leave
ret
jmp .L1819
.L1818:
.L1819:
jmp .L1809
.L1810:
movabsq $1,%rax
movq -.F1808-8(%rbp),%rbx
movq -.F1808-16(%rbp),%r12
movq -.F1808-24(%rbp),%r13
movq -.F1808-32(%rbp),%r14
movq -.F1808-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1808-8(%rbp),%rbx
movq -.F1808-16(%rbp),%r12
movq -.F1808-24(%rbp),%r13
movq -.F1808-32(%rbp),%r14
movq -.F1808-40(%rbp),%r15
leave
ret
.set .F1808,16
.type rt_big_shift,@function
rt_big_shift:
pushq %rbp
movq %rsp,%rbp
subq $.F1820,%rsp
subq $32,%rsp
movq %rbx,-.F1820-8(%rbp)
movq %r12,-.F1820-16(%rbp)
movq %r13,-.F1820-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq %rsi,%r13
movq $0,%rbx
.L1821:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L1822
movq %r12,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %rbx,%rax
addq $1,%rax
jnc .L1823
call rt_abort
.L1823:
movq %rax,%rbx
jmp .L1821
.L1822:
movabsq $0,%rax
movq -.F1820-8(%rbp),%rbx
movq -.F1820-16(%rbp),%r12
movq -.F1820-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1820-8(%rbp),%rbx
movq -.F1820-16(%rbp),%r12
movq -.F1820-24(%rbp),%r13
leave
ret
.set .F1820,16
.type rt_push_text,@function
rt_push_text:
pushq %rbp
movq %rsp,%rbp
subq $.F1824,%rsp
subq $16,%rsp
movq %rbx,-.F1824-8(%rbp)
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
jb .Lopt64
call rt_pushb
jmp .Lopt65
.Lopt64:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt65:
movq -24(%rbp),%rax
cmpq $0,%rax
je .L1825
movq -24(%rbp),%rax
movq %rbx,%rdi
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
jmp .L1826
.L1825:
.L1826:
movq -32(%rbp),%rax
cmpq $0,%rax
je .L1827
movq -32(%rbp),%rax
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
jmp .L1828
.L1827:
.L1828:
movabsq $0,%rax
movq -.F1824-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1824-8(%rbp),%rbx
leave
ret
.set .F1824,32
.type rt_fmt_f64,@function
rt_fmt_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F1829,%rsp
subq $48,%rsp
movq %rbx,-.F1829-8(%rbp)
movq %r12,-.F1829-16(%rbp)
movq %r13,-.F1829-24(%rbp)
movq %r14,-.F1829-32(%rbp)
movq %r15,-.F1829-40(%rbp)
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
jne .L1830
movq %r12,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F1829-8(%rbp),%rbx
movq -.F1829-16(%rbp),%r12
movq -.F1829-24(%rbp),%r13
movq -.F1829-32(%rbp),%r14
movq -.F1829-40(%rbp),%r15
leave
ret
jmp .L1831
.L1830:
.L1831:
movq %r13,%rcx
movabsq $9223372036854775807,%rax
cmpq %r13,%rax
jae .L1832
movq %r12,%rdi
movabsq $45,%rsi
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
jmp .L1833
.L1832:
.L1833:
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
jne .L1834
movq %r12,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F1829-8(%rbp),%rbx
movq -.F1829-16(%rbp),%r12
movq -.F1829-24(%rbp),%r13
movq -.F1829-32(%rbp),%r14
movq -.F1829-40(%rbp),%r15
leave
ret
jmp .L1835
.L1834:
.L1835:
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
jz .L1836
movq %r12,%rdi
movabsq $48,%rsi
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
movabsq $0,%rax
movq -.F1829-8(%rbp),%rbx
movq -.F1829-16(%rbp),%r12
movq -.F1829-24(%rbp),%r13
movq -.F1829-32(%rbp),%r14
movq -.F1829-40(%rbp),%r15
leave
ret
jmp .L1837
.L1836:
.L1837:
movq %r14,-48(%rbp)
movq $0,-56(%rbp)
cmpq $0,%rbx
jne .L1838
movq $1074,%r15
movq $1,-56(%rbp)
jmp .L1839
.L1838:
movabsq $4503599627370496,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1840
call rt_abort
.L1840:
movq %rax,-48(%rbp)
cmpq $1075,%rbx
jae .L1841
movabsq $1075,%rax
subq %rbx,%rax
jnc .L1843
call rt_abort
.L1843:
movq %rax,%r15
movq $1,-56(%rbp)
jmp .L1842
.L1841:
movq %rbx,%rax
subq $1075,%rax
jnc .L1844
call rt_abort
.L1844:
movq %rax,%r15
.L1842:
.L1839:
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
movq -.F1829-8(%rbp),%rbx
movq -.F1829-16(%rbp),%r12
movq -.F1829-24(%rbp),%r13
movq -.F1829-32(%rbp),%r14
movq -.F1829-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1829-8(%rbp),%rbx
movq -.F1829-16(%rbp),%r12
movq -.F1829-24(%rbp),%r13
movq -.F1829-32(%rbp),%r14
movq -.F1829-40(%rbp),%r15
leave
ret
.set .F1829,64
.type rt_fmt_shortest,@function
rt_fmt_shortest:
pushq %rbp
movq %rsp,%rbp
subq $.F1845,%rsp
subq $48,%rsp
movq %rbx,-.F1845-8(%rbp)
movq %r12,-.F1845-16(%rbp)
movq %r13,-.F1845-24(%rbp)
movq %r14,-.F1845-32(%rbp)
movq %r15,-.F1845-40(%rbp)
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
leaq -.F1845(%rbp),%rdi
movq $.F1845/8-5,%rcx
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
jne .L1846
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
jmp .L1847
.L1846:
movq -24(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_big_shift
.L1847:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %r13,%rdi
movabsq $2,%rsi
call rt_big_mul
movq -40(%rbp),%rax
testq %rax,%rax
jz .L1848
movq %rbx,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %r13,%rdi
movabsq $2,%rsi
call rt_big_mul
movq -64(%rbp),%rdi
movabsq $2,%rsi
call rt_big_mul
jmp .L1849
.L1848:
.L1849:
movabsq $0,%rdi
call rt_big
movq %rax,%r15
movq $0,-80(%rbp)
movq $0,-88(%rbp)
.L1850:
movabsq $1,%rax
testq %rax,%rax
jz .L1851
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
jnc .L1852
call rt_abort
.L1852:
testq %rax,%rax
jz .L1853
movq %r13,%rdi
movabsq $10,%rsi
call rt_big_mul
movq -88(%rbp),%rax
testq %rax,%rax
jz .L1855
movq -80(%rbp),%rax
cmpq $1,%rax
jne .L1857
movq $0,-88(%rbp)
jmp .L1858
.L1857:
.L1858:
movabsq $1,%rcx
movq -80(%rbp),%rax
subq $1,%rax
jnc .L1859
call rt_abort
.L1859:
movq %rax,-80(%rbp)
jmp .L1856
.L1855:
movabsq $1,%rcx
movq -80(%rbp),%rax
addq $1,%rax
jnc .L1860
call rt_abort
.L1860:
movq %rax,-80(%rbp)
.L1856:
jmp .L1854
.L1853:
jmp .L1851
.L1854:
jmp .L1850
.L1851:
.L1861:
movabsq $1,%rax
testq %rax,%rax
jz .L1862
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
jnc .L1863
call rt_abort
.L1863:
testq %rax,%rax
jz .L1864
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
jz .L1866
movabsq $1,%rcx
movq -80(%rbp),%rax
addq $1,%rax
jnc .L1868
call rt_abort
.L1868:
movq %rax,-80(%rbp)
jmp .L1867
.L1866:
movabsq $0,%rcx
movq -80(%rbp),%rax
cmpq $0,%rax
jne .L1869
movq $1,-88(%rbp)
movq $1,-80(%rbp)
jmp .L1870
.L1869:
movabsq $1,%rcx
movq -80(%rbp),%rax
subq $1,%rax
jnc .L1871
call rt_abort
.L1871:
movq %rax,-80(%rbp)
.L1870:
.L1867:
jmp .L1865
.L1864:
jmp .L1862
.L1865:
jmp .L1861
.L1862:
call rt_new
movq %rax,-152(%rbp)
.L1872:
movabsq $1,%rax
testq %rax,%rax
jz .L1873
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
.L1874:
movq %rbx,%rdi
movq %r13,%rsi
call rt_big_cmp
movabsq $0,%rcx
cmpq $0,%rax
je .L1875
movq %rbx,%rdi
movq %r13,%rsi
call rt_big_sub
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1876
call rt_abort
.L1876:
movq %rax,%r12
jmp .L1874
.L1875:
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
jnc .L1877
call rt_abort
.L1877:
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
jnc .L1878
call rt_abort
.L1878:
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
jz .L1879
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt74
call rt_push
jmp .Lopt75
.Lopt74:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt75:
jmp .L1872
jmp .L1880
.L1879:
.L1880:
movq -216(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -184(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1881
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt76
call rt_push
jmp .Lopt77
.Lopt76:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt77:
jmp .L1873
jmp .L1882
.L1881:
.L1882:
movq -184(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -216(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1883
movq %r12,%rax
addq $1,%rax
jnc .L1885
call rt_abort
.L1885:
movq -152(%rbp),%rdi
movq %rax,%rsi
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
jmp .L1873
jmp .L1884
.L1883:
.L1884:
movq %r15,%rdi
movq %rbx,%rsi
movq %rbx,%rdx
call rt_big_add
movq %r15,%rdi
movq %r13,%rsi
call rt_big_cmp
movq %rax,-232(%rbp)
cmpq $0,%rax
jne .L1886
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
jmp .L1887
.L1886:
movq %r12,%rax
addq $1,%rax
jnc .L1888
call rt_abort
.L1888:
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
.L1887:
jmp .L1873
jmp .L1872
.L1873:
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
jnc .L1889
call rt_abort
.L1889:
testq %rax,%rax
jz .L1890
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt84
call rt_pushb
jmp .Lopt85
.Lopt84:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt85:
movq -8(%rbp),%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt86
call rt_pushb
jmp .Lopt87
.Lopt86:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt87:
movq $0,-248(%rbp)
movq -88(%rbp),%rax
testq %rax,%rax
jz .L1892
movq -80(%rbp),%rax
movq %rax,-248(%rbp)
jmp .L1893
.L1892:
.L1893:
movq $0,-256(%rbp)
.L1894:
movq -256(%rbp),%rax
movq -248(%rbp),%rcx
cmpq %rcx,%rax
jae .L1895
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
movq -256(%rbp),%rax
addq $1,%rax
jnc .L1896
call rt_abort
.L1896:
movq %rax,-256(%rbp)
jmp .L1894
.L1895:
movq $0,-256(%rbp)
.L1897:
movq -256(%rbp),%rax
movq -240(%rbp),%rcx
cmpq %rcx,%rax
jae .L1898
movq -256(%rbp),%rax
movq -152(%rbp),%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i87
call rt_abort
.Lopt11_i87:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i87
xorq %rax,%rax
jmp .Lret_i87
.Lret_i87:
movq %rax,%rcx
movabsq $48,%rax
addq %rcx,%rax
jnc .L1899
call rt_abort
.L1899:
movq -8(%rbp),%rdi
movq %rax,%rsi
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
movq -256(%rbp),%rax
addq $1,%rax
jnc .L1900
call rt_abort
.L1900:
movq %rax,-256(%rbp)
jmp .L1897
.L1898:
jmp .L1891
.L1890:
movq $0,-264(%rbp)
.L1901:
movq -264(%rbp),%rax
movq -240(%rbp),%rcx
cmpq %rcx,%rax
jae .L1902
movq -264(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jne .L1903
movq -8(%rbp),%rdi
movabsq $46,%rsi
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
jmp .L1904
.L1903:
.L1904:
movq -264(%rbp),%rax
movq -152(%rbp),%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i88
call rt_abort
.Lopt11_i88:
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
jnc .L1905
call rt_abort
.L1905:
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
movq -264(%rbp),%rax
addq $1,%rax
jnc .L1906
call rt_abort
.L1906:
movq %rax,-264(%rbp)
jmp .L1901
.L1902:
.L1907:
movq -264(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jae .L1908
movq -8(%rbp),%rdi
movabsq $48,%rsi
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
movq -264(%rbp),%rax
addq $1,%rax
jnc .L1909
call rt_abort
.L1909:
movq %rax,-264(%rbp)
jmp .L1907
.L1908:
.L1891:
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
movq -.F1845-8(%rbp),%rbx
movq -.F1845-16(%rbp),%r12
movq -.F1845-24(%rbp),%r13
movq -.F1845-32(%rbp),%r14
movq -.F1845-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1845-8(%rbp),%rbx
movq -.F1845-16(%rbp),%r12
movq -.F1845-24(%rbp),%r13
movq -.F1845-32(%rbp),%r14
movq -.F1845-40(%rbp),%r15
leave
ret
.set .F1845,272
.type rt_print_f64,@function
rt_print_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F1910,%rsp
subq $16,%rsp
movq %rbx,-.F1910-8(%rbp)
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
jz .L1911
movq %rbx,%rdi
movabsq $10,%rsi
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
jmp .L1912
.L1911:
.L1912:
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
je .L1913
call rt_abort
jmp .L1914
.L1913:
.L1914:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1910-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1910-8(%rbp),%rbx
leave
ret
.set .F1910,48
.type rt_f32_round,@function
rt_f32_round:
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
movq %rdi,-8(%rbp)
leaq -.F1915(%rbp),%rdi
movq $.F1915/8-1,%rcx
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
jne .L1916
movq -8(%rbp),%rax
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
jmp .L1917
.L1916:
.L1917:
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L1918
movq %r15,%rax
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
jmp .L1919
.L1918:
.L1919:
movabsq $4503599627370495,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
movq %rax,-40(%rbp)
movabsq $4503599627370496,%rcx
addq %rcx,%rax
jnc .L1920
call rt_abort
.L1920:
movq %rax,-48(%rbp)
movq $29,-56(%rbp)
movq -24(%rbp),%rax
cmpq $897,%rax
jae .L1921
movq -24(%rbp),%rcx
movabsq $926,%rax
subq %rcx,%rax
jnc .L1923
call rt_abort
.L1923:
movq %rax,-56(%rbp)
jmp .L1922
.L1921:
.L1922:
movq -56(%rbp),%rcx
movabsq $53,%rax
cmpq %rcx,%rax
jae .L1924
movq %r15,%rax
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
jmp .L1925
.L1924:
.L1925:
movq -56(%rbp),%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1926
call rt_abort
.L1926:
movq -48(%rbp),%rax
shrq %cl,%rax
movq %rax,-64(%rbp)
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1927
call rt_abort
.L1927:
movq -64(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
subq %rcx,%rax
jnc .L1928
call rt_abort
.L1928:
movq %rax,-72(%rbp)
movq -56(%rbp),%rax
subq $1,%rax
jnc .L1929
call rt_abort
.L1929:
movq %rax,-80(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1930
call rt_abort
.L1930:
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
jnc .L1931
call rt_abort
.L1931:
testq %rax,%rax
jz .L1932
movq %r12,%rax
addq $1,%rax
jnc .L1934
call rt_abort
.L1934:
movq %rax,%r12
jmp .L1933
.L1932:
.L1933:
cmpq $0,%r12
jne .L1935
movq %r15,%rax
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
jmp .L1936
.L1935:
.L1936:
movq $0,%rbx
.L1937:
movq %rbx,%rax
addq $1,%rax
jnc .L1939
call rt_abort
.L1939:
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1940
call rt_abort
.L1940:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,%r14
movq %r12,%rax
addq $1,%rax
jnc .L1941
call rt_abort
.L1941:
movq %rax,%rcx
cmpq %rcx,%r14
jae .L1938
movq %rbx,%rax
addq $1,%rax
jnc .L1942
call rt_abort
.L1942:
movq %rax,%rbx
jmp .L1937
.L1938:
movq -24(%rbp),%rax
subq $52,%rax
jnc .L1943
call rt_abort
.L1943:
movq -56(%rbp),%rcx
addq %rcx,%rax
jnc .L1944
call rt_abort
.L1944:
addq %rbx,%rax
jnc .L1945
call rt_abort
.L1945:
movq %rax,-120(%rbp)
movq %rax,%rcx
movabsq $1150,%rax
cmpq %rcx,%rax
jae .L1946
movabsq $9218868437227405312,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1948
call rt_abort
.L1948:
movq -.F1915-8(%rbp),%rbx
movq -.F1915-16(%rbp),%r12
movq -.F1915-24(%rbp),%r13
movq -.F1915-32(%rbp),%r14
movq -.F1915-40(%rbp),%r15
leave
ret
jmp .L1947
.L1946:
.L1947:
movabsq $4503599627370496,%rcx
movq -120(%rbp),%rax
mulq %rcx
jnc .L1949
call rt_abort
.L1949:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1950
call rt_abort
.L1950:
movq %rax,-128(%rbp)
movabsq $52,%rax
subq %rbx,%rax
jnc .L1951
call rt_abort
.L1951:
movq %rax,-136(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1952
call rt_abort
.L1952:
movq %r12,%rax
shlq %cl,%rax
movq %rax,-144(%rbp)
movabsq $4503599627370496,%rcx
subq %rcx,%rax
jnc .L1953
call rt_abort
.L1953:
movq %rax,%rcx
movq -128(%rbp),%rax
addq %rcx,%rax
jnc .L1954
call rt_abort
.L1954:
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
.set .F1915,144
.type rt_f32_from_int,@function
rt_f32_from_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1955,%rsp
subq $48,%rsp
movq %rbx,-.F1955-8(%rbp)
movq %r12,-.F1955-16(%rbp)
movq %r13,-.F1955-24(%rbp)
movq %r14,-.F1955-32(%rbp)
movq %r15,-.F1955-40(%rbp)
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
.L1956:
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
jmp .Lret_i89
xorq %rax,%rax
jmp .Lret_i89
.Lret_i89:
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1957
movq $1,-24(%rbp)
movabsq $0,%rax
subq %r14,%rax
movq %rax,%rbx
jmp .L1958
.L1957:
.L1958:
movq $0,%r12
.L1959:
movq %rbx,%rcx
movabsq $9007199254740991,%rax
cmpq %rbx,%rax
jae .L1960
movabsq $1,%rcx
movq %rbx,%rax
andq $1,%rax
movq %rax,%r13
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
testq %r13,%r13
jz .L1961
movq %rbx,%rax
orq $1,%rax
movq %rax,%rbx
jmp .L1962
.L1961:
.L1962:
movq %r12,%rax
addq $1,%rax
jnc .L1963
call rt_abort
.L1963:
movq %rax,%r12
jmp .L1959
.L1960:
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
jz .L1964
movabsq $4503599627370496,%rcx
movq %r12,%rax
mulq %rcx
jnc .L1966
call rt_abort
.L1966:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1967
call rt_abort
.L1967:
movq %rax,%r15
jmp .L1965
.L1964:
.L1965:
movq %r15,%rdi
call rt_f32_round
movq %rax,-56(%rbp)
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1968
movq -56(%rbp),%rax
movq %rax,%rdi
movq %rdi,%r8
movabsq $9223372036854775808,%rcx
movq %r8,%rax
xorq %rcx,%rax
jmp .Lret_i90
xorq %rax,%rax
jmp .Lret_i90
.Lret_i90:
movq -.F1955-8(%rbp),%rbx
movq -.F1955-16(%rbp),%r12
movq -.F1955-24(%rbp),%r13
movq -.F1955-32(%rbp),%r14
movq -.F1955-40(%rbp),%r15
leave
ret
jmp .L1969
.L1968:
.L1969:
movq -56(%rbp),%rax
movq -.F1955-8(%rbp),%rbx
movq -.F1955-16(%rbp),%r12
movq -.F1955-24(%rbp),%r13
movq -.F1955-32(%rbp),%r14
movq -.F1955-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1955-8(%rbp),%rbx
movq -.F1955-16(%rbp),%r12
movq -.F1955-24(%rbp),%r13
movq -.F1955-32(%rbp),%r14
movq -.F1955-40(%rbp),%r15
leave
ret
.set .F1955,64
.type rt_fmt_f32,@function
rt_fmt_f32:
pushq %rbp
movq %rsp,%rbp
subq $.F1970,%rsp
subq $48,%rsp
movq %rbx,-.F1970-8(%rbp)
movq %r12,-.F1970-16(%rbp)
movq %r13,-.F1970-24(%rbp)
movq %r14,-.F1970-32(%rbp)
movq %r15,-.F1970-40(%rbp)
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
jne .L1971
movq %rbx,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
jmp .L1972
.L1971:
.L1972:
movq %r13,%rcx
movabsq $9223372036854775807,%rax
cmpq %r13,%rax
jae .L1973
movq %rbx,%rdi
movabsq $45,%rsi
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
jmp .L1974
.L1973:
.L1974:
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
jne .L1975
movq %rbx,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
jmp .L1976
.L1975:
.L1976:
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
jz .L1977
movq %rbx,%rdi
movabsq $48,%rsi
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
movabsq $0,%rax
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
jmp .L1978
.L1977:
.L1978:
movabsq $896,%rax
cmpq %r12,%rax
jae .L1979
movabsq $896,%rcx
movq %r12,%rax
subq $896,%rax
jnc .L1981
call rt_abort
.L1981:
movq %rax,%r14
movq %r15,%rdi
movabsq $536870912,%rsi
call rt_div
movq %rax,-48(%rbp)
movq %rax,-56(%rbp)
addq $8388608,%rax
jnc .L1982
call rt_abort
.L1982:
movq %rax,-64(%rbp)
cmpq $150,%r14
jae .L1983
movabsq $150,%rax
subq %r14,%rax
jnc .L1985
call rt_abort
.L1985:
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
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
jmp .L1984
.L1983:
.L1984:
movq %r14,%rax
subq $150,%rax
jnc .L1986
call rt_abort
.L1986:
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
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
jmp .L1980
.L1979:
.L1980:
movabsq $4503599627370496,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1987
call rt_abort
.L1987:
movq %rax,-96(%rbp)
movabsq $926,%rax
subq %r12,%rax
jnc .L1988
call rt_abort
.L1988:
movq %rax,-104(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L1989
call rt_abort
.L1989:
movq -96(%rbp),%rax
shrq %cl,%rax
movq %rax,-112(%rbp)
movq %rbx,%rdi
movq %rax,%rsi
movabsq $149,%rdx
movabsq $1,%rcx
movabsq $0,%r8
call rt_fmt_shortest
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1970-8(%rbp),%rbx
movq -.F1970-16(%rbp),%r12
movq -.F1970-24(%rbp),%r13
movq -.F1970-32(%rbp),%r14
movq -.F1970-40(%rbp),%r15
leave
ret
.set .F1970,112
.type rt_print_f32,@function
rt_print_f32:
pushq %rbp
movq %rsp,%rbp
subq $.F1990,%rsp
subq $16,%rsp
movq %rbx,-.F1990-8(%rbp)
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
jz .L1991
movq %rbx,%rdi
movabsq $10,%rsi
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
jmp .L1992
.L1991:
.L1992:
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
je .L1993
call rt_abort
jmp .L1994
.L1993:
.L1994:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1990-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1990-8(%rbp),%rbx
leave
ret
.set .F1990,48
.type rt_char_from,@function
rt_char_from:
pushq %rbp
movq %rsp,%rbp
subq $.F1995,%rsp
subq $16,%rsp
movq %rbx,-.F1995-8(%rbp)
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
jnc .L1996
call rt_abort
.L1996:
testq %rax,%rax
jz .L1997
call rt_abort
jmp .L1998
.L1997:
.L1998:
movq %rbx,%rax
movq -.F1995-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1995-8(%rbp),%rbx
leave
ret
.set .F1995,32
.type rt_print_char,@function
rt_print_char:
pushq %rbp
movq %rsp,%rbp
subq $.F1999,%rsp
subq $16,%rsp
movq %rbx,-.F1999-8(%rbp)
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
jz .L2000
movq %rbx,%rdi
movabsq $10,%rsi
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
jmp .L2001
.L2000:
.L2001:
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
je .L2002
call rt_abort
jmp .L2003
.L2002:
.L2003:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1999-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1999-8(%rbp),%rbx
leave
ret
.set .F1999,48
.type rt_char_upper,@function
rt_char_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2004,%rsp
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
.set .F2004,16
.type rt_char_lower,@function
rt_char_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2005,%rsp
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
.set .F2005,16
.type rt_char_is_upper,@function
rt_char_is_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2006,%rsp
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
.set .F2006,16
.type rt_char_is_lower,@function
rt_char_is_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2007,%rsp
subq $16,%rsp
movq %rbx,-.F2007-8(%rbp)
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
jnc .L2008
call rt_abort
.L2008:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $312,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2009
call rt_abort
.L2009:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $329,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2010
call rt_abort
.L2010:
movq -.F2007-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2007-8(%rbp),%rbx
leave
ret
.set .F2007,32
.type rt_char_is_alpha,@function
rt_char_is_alpha:
pushq %rbp
movq %rsp,%rbp
subq $.F2011,%rsp
subq $16,%rsp
movq %rbx,-.F2011-8(%rbp)
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
jnc .L2012
call rt_abort
.L2012:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $170,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2013
call rt_abort
.L2013:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $186,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2014
call rt_abort
.L2014:
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
jnc .L2015
call rt_abort
.L2015:
movq -.F2011-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2011-8(%rbp),%rbx
leave
ret
.set .F2011,48
.type rt_char_is_digit,@function
rt_char_is_digit:
pushq %rbp
movq %rsp,%rbp
subq $.F2016,%rsp
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
.set .F2016,16
.type rt_char_is_alnum,@function
rt_char_is_alnum:
pushq %rbp
movq %rsp,%rbp
subq $.F2017,%rsp
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
jmp .Lret_i91
xorq %rax,%rax
jmp .Lret_i91
.Lret_i91:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L2018
call rt_abort
.L2018:
leave
ret
xorq %rax,%rax
leave
ret
.set .F2017,16
.type rt_char_is_space,@function
rt_char_is_space:
pushq %rbp
movq %rsp,%rbp
subq $.F2019,%rsp
subq $16,%rsp
movq %rbx,-.F2019-8(%rbp)
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
jnc .L2020
call rt_abort
.L2020:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $133,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2021
call rt_abort
.L2021:
movq %rax,-40(%rbp)
movq %rbx,%rax
cmpq $160,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L2022
call rt_abort
.L2022:
movq %rax,-48(%rbp)
movq %rbx,%rax
cmpq $5760,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L2023
call rt_abort
.L2023:
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
jnc .L2024
call rt_abort
.L2024:
movq %rax,-72(%rbp)
movq %rbx,%rax
cmpq $8232,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2025
call rt_abort
.L2025:
movq %rax,-80(%rbp)
movq %rbx,%rax
cmpq $8233,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L2026
call rt_abort
.L2026:
movq %rax,-88(%rbp)
movq %rbx,%rax
cmpq $8239,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2027
call rt_abort
.L2027:
movq %rax,-96(%rbp)
movq %rbx,%rax
cmpq $8287,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
addq %rcx,%rax
jnc .L2028
call rt_abort
.L2028:
movq %rax,-104(%rbp)
movq %rbx,%rax
cmpq $12288,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
addq %rcx,%rax
jnc .L2029
call rt_abort
.L2029:
movq -.F2019-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2019-8(%rbp),%rbx
leave
ret
.set .F2019,112
.type rt_char_is_ascii,@function
rt_char_is_ascii:
pushq %rbp
movq %rsp,%rbp
subq $.F2030,%rsp
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
.set .F2030,16
.type rt_char_len_utf8,@function
rt_char_len_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F2031,%rsp
subq $16,%rsp
movq %rbx,-.F2031-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
cmpq $128,%rbx
jae .L2032
movabsq $1,%rax
movq -.F2031-8(%rbp),%rbx
leave
ret
jmp .L2033
.L2032:
.L2033:
cmpq $2048,%rbx
jae .L2034
movabsq $2,%rax
movq -.F2031-8(%rbp),%rbx
leave
ret
jmp .L2035
.L2034:
.L2035:
cmpq $65536,%rbx
jae .L2036
movabsq $3,%rax
movq -.F2031-8(%rbp),%rbx
leave
ret
jmp .L2037
.L2036:
.L2037:
movabsq $4,%rax
movq -.F2031-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2031-8(%rbp),%rbx
leave
ret
.set .F2031,16
.type rt_seq_chars,@function
rt_seq_chars:
pushq %rbp
movq %rsp,%rbp
subq $.F2038,%rsp
subq $48,%rsp
movq %rbx,-.F2038-8(%rbp)
movq %r12,-.F2038-16(%rbp)
movq %r13,-.F2038-24(%rbp)
movq %r14,-.F2038-32(%rbp)
movq %r15,-.F2038-40(%rbp)
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
.L2039:
movq -24(%rbp),%rcx
cmpq %rcx,%r14
jae .L2040
movq -8(%rbp),%rdi
movq %r14,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt108
call rt_abort
.Lopt108:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rbx
movq %rax,%r13
movq $0,-32(%rbp)
cmpq $128,%rax
jae .L2041
movq $0,%r12
jmp .L2042
.L2041:
movq %rbx,%rax
andq $224,%rax
movq %rax,-40(%rbp)
cmpq $192,%rax
jne .L2043
movq $1,%r12
movq %rbx,%rax
andq $31,%rax
movq %rax,%r13
movq $128,-32(%rbp)
jmp .L2044
.L2043:
movq %rbx,%rax
andq $240,%rax
movq %rax,-48(%rbp)
cmpq $224,%rax
jne .L2045
movq $2,%r12
movq %rbx,%rax
andq $15,%rax
movq %rax,%r13
movq $2048,-32(%rbp)
jmp .L2046
.L2045:
movq %rbx,%rax
andq $248,%rax
movq %rax,-56(%rbp)
cmpq $240,%rax
jne .L2047
movq $3,%r12
movq %rbx,%rax
andq $7,%rax
movq %rax,%r13
movq $65536,-32(%rbp)
jmp .L2048
.L2047:
movq $99,%r12
.L2048:
.L2046:
.L2044:
.L2042:
cmpq $99,%r12
jne .L2049
movq -16(%rbp),%rdi
movabsq $65533,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt109
call rt_push
jmp .Lopt110
.Lopt109:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt110:
movq %r14,%rax
addq $1,%rax
jnc .L2051
call rt_abort
.L2051:
movq %rax,%r14
jmp .L2039
jmp .L2050
.L2049:
.L2050:
movq $1,-64(%rbp)
movq $1,%r15
.L2052:
movq %r12,%rax
addq $1,%rax
jnc .L2054
call rt_abort
.L2054:
movq %rax,%rcx
cmpq %rcx,%r15
jae .L2053
movq %r14,%rax
addq %r15,%rax
jnc .L2055
call rt_abort
.L2055:
movq %rax,-72(%rbp)
addq $1,%rax
jnc .L2056
call rt_abort
.L2056:
movq %rax,%rcx
movq -24(%rbp),%rax
cmpq %rcx,%rax
jae .L2057
movq $0,-64(%rbp)
jmp .L2053
jmp .L2058
.L2057:
.L2058:
movq %r14,%rax
addq %r15,%rax
jnc .L2059
call rt_abort
.L2059:
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt111
call rt_abort
.Lopt111:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-80(%rbp)
movq %rax,-88(%rbp)
andq $192,%rax
movq %rax,-96(%rbp)
cmpq $128,%rax
je .L2060
movq $0,-64(%rbp)
jmp .L2053
jmp .L2061
.L2060:
.L2061:
movabsq $64,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2062
call rt_abort
.L2062:
movq %rax,-104(%rbp)
movq -80(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
addq %rcx,%rax
jnc .L2063
call rt_abort
.L2063:
movq %rax,%r13
movq %r15,%rax
addq $1,%rax
jnc .L2064
call rt_abort
.L2064:
movq %rax,%r15
jmp .L2052
.L2053:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L2065
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
jnc .L2067
call rt_abort
.L2067:
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
jnc .L2068
call rt_abort
.L2068:
testq %rax,%rax
jz .L2069
movq $0,-64(%rbp)
jmp .L2070
.L2069:
.L2070:
jmp .L2066
.L2065:
.L2066:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L2071
movq -16(%rbp),%rdi
movq %r13,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt112
call rt_push
jmp .Lopt113
.Lopt112:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt113:
movq %r12,%rax
addq $1,%rax
jnc .L2073
call rt_abort
.L2073:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2074
call rt_abort
.L2074:
movq %rax,%r14
jmp .L2072
.L2071:
movq -16(%rbp),%rdi
movabsq $65533,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt114
call rt_push
jmp .Lopt115
.Lopt114:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt115:
movq %r14,%rax
addq $1,%rax
jnc .L2075
call rt_abort
.L2075:
movq %rax,%r14
.L2072:
jmp .L2039
.L2040:
movq -16(%rbp),%rax
movq -.F2038-8(%rbp),%rbx
movq -.F2038-16(%rbp),%r12
movq -.F2038-24(%rbp),%r13
movq -.F2038-32(%rbp),%r14
movq -.F2038-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2038-8(%rbp),%rbx
movq -.F2038-16(%rbp),%r12
movq -.F2038-24(%rbp),%r13
movq -.F2038-32(%rbp),%r14
movq -.F2038-40(%rbp),%r15
leave
ret
.set .F2038,128
.type rt_big_half,@function
rt_big_half:
pushq %rbp
movq %rsp,%rbp
subq $.F2076,%rsp
subq $48,%rsp
movq %rbx,-.F2076-8(%rbp)
movq %r12,-.F2076-16(%rbp)
movq %r13,-.F2076-24(%rbp)
movq %r14,-.F2076-32(%rbp)
movq %r15,-.F2076-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq $0,-16(%rbp)
movq $0,%r13
movq $48,%rbx
.L2077:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2078
movq %rbx,%rax
subq $1,%rax
jnc .L2079
call rt_abort
.L2079:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2080
call rt_abort
.L2080:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2081
call rt_abort
.L2081:
movq (%rax),%rax
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2082
call rt_abort
.L2082:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2083
call rt_abort
.L2083:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2084
call rt_abort
.L2084:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2085
call rt_abort
.L2085:
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
.L2086:
movq %rdx,%r13
jmp .L2077
.L2078:
movq %r13,%rax
movq -.F2076-8(%rbp),%rbx
movq -.F2076-16(%rbp),%r12
movq -.F2076-24(%rbp),%r13
movq -.F2076-32(%rbp),%r14
movq -.F2076-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2076-8(%rbp),%rbx
movq -.F2076-16(%rbp),%r12
movq -.F2076-24(%rbp),%r13
movq -.F2076-32(%rbp),%r14
movq -.F2076-40(%rbp),%r15
leave
ret
.set .F2076,16
.type rt_big_is_zero,@function
rt_big_is_zero:
pushq %rbp
movq %rsp,%rbp
subq $.F2087,%rsp
subq $32,%rsp
movq %rbx,-.F2087-8(%rbp)
movq %r12,-.F2087-16(%rbp)
movq %r13,-.F2087-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq $0,%rbx
.L2088:
cmpq $48,%rbx
jae .L2089
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2090
call rt_abort
.L2090:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L2091
call rt_abort
.L2091:
movq (%rax),%rax
cmpq $0,%rax
je .L2092
movabsq $0,%rax
movq -.F2087-8(%rbp),%rbx
movq -.F2087-16(%rbp),%r12
movq -.F2087-24(%rbp),%r13
leave
ret
jmp .L2093
.L2092:
.L2093:
movq %rbx,%rax
addq $1,%rax
jnc .L2094
call rt_abort
.L2094:
movq %rax,%rbx
jmp .L2088
.L2089:
movabsq $1,%rax
movq -.F2087-8(%rbp),%rbx
movq -.F2087-16(%rbp),%r12
movq -.F2087-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2087-8(%rbp),%rbx
movq -.F2087-16(%rbp),%r12
movq -.F2087-24(%rbp),%r13
leave
ret
.set .F2087,16
.type rt_fmt_f64_fixed,@function
rt_fmt_f64_fixed:
pushq %rbp
movq %rsp,%rbp
subq $.F2095,%rsp
subq $48,%rsp
movq %rbx,-.F2095-8(%rbp)
movq %r12,-.F2095-16(%rbp)
movq %r13,-.F2095-24(%rbp)
movq %r14,-.F2095-32(%rbp)
movq %r15,-.F2095-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
leaq -.F2095(%rbp),%rdi
movq $.F2095/8-3,%rcx
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
jne .L2096
movq %r15,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F2095-8(%rbp),%rbx
movq -.F2095-16(%rbp),%r12
movq -.F2095-24(%rbp),%r13
movq -.F2095-32(%rbp),%r14
movq -.F2095-40(%rbp),%r15
leave
ret
jmp .L2097
.L2096:
.L2097:
movq -16(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
jae .L2098
movq %r15,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt116
call rt_pushb
jmp .Lopt117
.Lopt116:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt117:
jmp .L2099
.L2098:
.L2099:
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
jne .L2100
movq %r15,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F2095-8(%rbp),%rbx
movq -.F2095-16(%rbp),%r12
movq -.F2095-24(%rbp),%r13
movq -.F2095-32(%rbp),%r14
movq -.F2095-40(%rbp),%r15
leave
ret
jmp .L2101
.L2100:
.L2101:
movq -56(%rbp),%rax
movq %rax,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
jne .L2102
movq $1074,-72(%rbp)
movq $1,-80(%rbp)
jmp .L2103
.L2102:
movabsq $4503599627370496,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L2104
call rt_abort
.L2104:
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
cmpq $1075,%rax
jae .L2105
movq -48(%rbp),%rcx
movabsq $1075,%rax
subq %rcx,%rax
jnc .L2107
call rt_abort
.L2107:
movq %rax,-72(%rbp)
movq $1,-80(%rbp)
jmp .L2106
.L2105:
movabsq $1075,%rcx
movq -48(%rbp),%rax
subq $1075,%rax
jnc .L2108
call rt_abort
.L2108:
movq %rax,-72(%rbp)
.L2106:
.L2103:
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_big
movq %rax,-88(%rbp)
movq $0,%rbx
.L2109:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2110
movq -88(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq %rbx,%rax
addq $1,%rax
jnc .L2111
call rt_abort
.L2111:
movq %rax,%rbx
jmp .L2109
.L2110:
movabsq $0,%rcx
movq -80(%rbp),%rax
cmpq $0,%rax
jne .L2112
movq -72(%rbp),%rax
movq -88(%rbp),%rdi
movq %rax,%rsi
call rt_big_shift
jmp .L2113
.L2112:
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,%rbx
.L2114:
movq -72(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2115
movq -96(%rbp),%rax
testq %rax,%rax
jz .L2116
movq $1,-104(%rbp)
jmp .L2117
.L2116:
.L2117:
movq -88(%rbp),%rax
movq %rax,%rdi
call rt_big_half
movq %rax,-96(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2118
call rt_abort
.L2118:
movq %rax,%rbx
jmp .L2114
.L2115:
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
jnc .L2119
call rt_abort
.L2119:
movq %rax,-128(%rbp)
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2120
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
jmp .L2121
.L2120:
.L2121:
.L2113:
call rt_new
movq %rax,%r14
movq $47,-144(%rbp)
.L2122:
movq -144(%rbp),%rcx
movabsq $0,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-152(%rbp)
movabsq $8,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L2124
call rt_abort
.L2124:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2125
call rt_abort
.L2125:
movq (%rax),%rax
movq %rax,-160(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2123
movq -144(%rbp),%rax
subq $1,%rax
jnc .L2126
call rt_abort
.L2126:
movq %rax,-144(%rbp)
jmp .L2122
.L2123:
movabsq $8,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L2127
call rt_abort
.L2127:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2128
call rt_abort
.L2128:
movq (%rax),%rax
movq %rax,-168(%rbp)
movq %r14,%rdi
movq %rax,%rsi
call rt_fmt_num
movq -144(%rbp),%rax
movq %rax,%rbx
.L2129:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2130
movq %rbx,%rax
subq $1,%rax
jnc .L2131
call rt_abort
.L2131:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2132
call rt_abort
.L2132:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2133
call rt_abort
.L2133:
movq (%rax),%rax
movq %rax,-176(%rbp)
movq $100000000,%r12
.L2134:
movq %r12,%rcx
movabsq $0,%rax
cmpq %r12,%rax
jae .L2135
movq -176(%rbp),%rdi
movq %r12,%rsi
call rt_div
movabsq $10,%rcx
testq %rcx,%rcx
jnz .L2136
call rt_abort
.L2136:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L2137
call rt_abort
.L2137:
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt118
call rt_pushb
jmp .Lopt119
.Lopt118:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt119:
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
jmp .L2134
.L2135:
jmp .L2129
.L2130:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-184(%rbp)
movq %rax,-192(%rbp)
movq -24(%rbp),%rax
addq $1,%rax
jnc .L2138
call rt_abort
.L2138:
movq %rax,%rcx
movq -192(%rbp),%rax
cmpq %rcx,%rax
jae .L2139
movq -24(%rbp),%rax
addq $1,%rax
jnc .L2141
call rt_abort
.L2141:
movq -184(%rbp),%rcx
subq %rcx,%rax
jnc .L2142
call rt_abort
.L2142:
movq %rax,-200(%rbp)
movq %r15,%rdi
movabsq $48,%rsi
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
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2143
movq %r15,%rdi
movabsq $46,%rsi
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
jmp .L2144
.L2143:
.L2144:
movq -200(%rbp),%rax
subq $1,%rax
jnc .L2145
call rt_abort
.L2145:
movq %rax,-200(%rbp)
.L2146:
movq -200(%rbp),%rcx
movabsq $0,%rax
cmpq %rcx,%rax
jae .L2147
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
movq -200(%rbp),%rax
subq $1,%rax
jnc .L2148
call rt_abort
.L2148:
movq %rax,-200(%rbp)
jmp .L2146
.L2147:
movq $0,%rbx
.L2149:
movq -184(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2150
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt126
call rt_abort
.Lopt126:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r15,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt127
call rt_pushb
jmp .Lopt128
.Lopt127:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt128:
movq %rbx,%rax
addq $1,%rax
jnc .L2151
call rt_abort
.L2151:
movq %rax,%rbx
jmp .L2149
.L2150:
jmp .L2140
.L2139:
movq $0,%rbx
.L2152:
movq -184(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2153
movq -184(%rbp),%rax
movq -24(%rbp),%rcx
subq %rcx,%rax
jnc .L2154
call rt_abort
.L2154:
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
jz .L2155
movq %r15,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt129
call rt_pushb
jmp .Lopt130
.Lopt129:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt130:
jmp .L2156
.L2155:
.L2156:
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt131
call rt_abort
.Lopt131:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r15,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt132
call rt_pushb
jmp .Lopt133
.Lopt132:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt133:
movq %rbx,%rax
addq $1,%rax
jnc .L2157
call rt_abort
.L2157:
movq %rax,%rbx
jmp .L2152
.L2153:
.L2140:
movq %r14,%rdi
call rt_drop_seq
movq -88(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F2095-8(%rbp),%rbx
movq -.F2095-16(%rbp),%r12
movq -.F2095-24(%rbp),%r13
movq -.F2095-32(%rbp),%r14
movq -.F2095-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2095-8(%rbp),%rbx
movq -.F2095-16(%rbp),%r12
movq -.F2095-24(%rbp),%r13
movq -.F2095-32(%rbp),%r14
movq -.F2095-40(%rbp),%r15
leave
ret
.set .F2095,208
.type rt_print_acc,@function
rt_print_acc:
pushq %rbp
movq %rsp,%rbp
subq $.F2158,%rsp
subq $16,%rsp
movq %rbx,-.F2158-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2159
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt134
call rt_pushb
jmp .Lopt135
.Lopt134:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt135:
jmp .L2160
.L2159:
.L2160:
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
je .L2161
call rt_abort
jmp .L2162
.L2161:
.L2162:
movq -32(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2158-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2158-8(%rbp),%rbx
leave
ret
.set .F2158,48
.type f_host_exit,@function
f_host_exit:
pushq %rbp
movq %rsp,%rbp
subq $.F2163,%rsp
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
.set .F2163,16
.type rt_fmt_value,@function
rt_fmt_value:
pushq %rbp
movq %rsp,%rbp
subq $.F2164,%rsp
subq $48,%rsp
movq %rbx,-.F2164-8(%rbp)
movq %r12,-.F2164-16(%rbp)
movq %r13,-.F2164-24(%rbp)
movq %r14,-.F2164-32(%rbp)
movq %r15,-.F2164-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq %rsi,%r14
movq %rdx,-24(%rbp)
leaq -.F2164(%rbp),%rdi
movq $.F2164/8-3,%rcx
xorl %eax,%eax
rep stosq
movabsq $1,%rcx
movq -24(%rbp),%rax
cmpq $1,%rax
jne .L2165
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_num
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2166
.L2165:
.L2166:
movabsq $2,%rcx
movq -24(%rbp),%rax
cmpq $2,%rax
jne .L2167
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_bool
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2168
.L2167:
.L2168:
movabsq $3,%rcx
movq -24(%rbp),%rax
cmpq $3,%rax
jne .L2169
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
.L2171:
movq -48(%rbp),%rcx
cmpq %rcx,%r15
jae .L2172
movq %rbx,%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt136
call rt_abort
.Lopt136:
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
jnc .L2173
call rt_abort
.L2173:
movq %rax,-80(%rbp)
movq -56(%rbp),%rax
cmpq $110,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L2174
call rt_abort
.L2174:
movq %rax,-88(%rbp)
movq -56(%rbp),%rax
cmpq $78,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2175
call rt_abort
.L2175:
testq %rax,%rax
jz .L2176
movq $0,-40(%rbp)
jmp .L2177
.L2176:
.L2177:
movq %r15,%rax
addq $1,%rax
jnc .L2178
call rt_abort
.L2178:
movq %rax,%r15
jmp .L2171
.L2172:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2179
movq %rbx,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt137
call rt_pushb
jmp .Lopt138
.Lopt137:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt138:
movq %rbx,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt139
call rt_pushb
jmp .Lopt140
.Lopt139:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt140:
jmp .L2180
.L2179:
.L2180:
movabsq $0,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2170
.L2169:
.L2170:
movq -24(%rbp),%rax
cmpq $4,%rax
jne .L2181
movq %rbx,%rdi
movabsq $34,%rsi
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
movq %r14,%rsi
call rt_fmt_seq
movq %rbx,%rdi
movabsq $34,%rsi
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
movabsq $0,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2182
.L2181:
.L2182:
movq -24(%rbp),%rax
cmpq $6,%rax
jne .L2183
movq %rbx,%rdi
movabsq $39,%rsi
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
call rt_push_utf8
movq %rbx,%rdi
movabsq $39,%rsi
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
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2184
.L2183:
.L2184:
movabsq $7,%rcx
movq -24(%rbp),%rax
cmpq $7,%rax
jne .L2185
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
.L2187:
movq -112(%rbp),%rax
movq -120(%rbp),%rcx
cmpq %rcx,%rax
jae .L2188
movq -112(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt149
call rt_abort
.Lopt149:
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
jnc .L2189
call rt_abort
.L2189:
movq %rax,-152(%rbp)
movq -128(%rbp),%rax
cmpq $110,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
addq %rcx,%rax
jnc .L2190
call rt_abort
.L2190:
movq %rax,-160(%rbp)
movq -128(%rbp),%rax
cmpq $78,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -160(%rbp),%rax
addq %rcx,%rax
jnc .L2191
call rt_abort
.L2191:
testq %rax,%rax
jz .L2192
movq $0,-104(%rbp)
jmp .L2193
.L2192:
.L2193:
movq -112(%rbp),%rax
addq $1,%rax
jnc .L2194
call rt_abort
.L2194:
movq %rax,-112(%rbp)
jmp .L2187
.L2188:
movq -104(%rbp),%rax
testq %rax,%rax
jz .L2195
movq %rbx,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt150
call rt_pushb
jmp .Lopt151
.Lopt150:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt151:
movq %rbx,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt152
call rt_pushb
jmp .Lopt153
.Lopt152:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt153:
jmp .L2196
.L2195:
.L2196:
movabsq $0,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2186
.L2185:
.L2186:
movq -24(%rbp),%rax
andq $4095,%rax
movq %rax,-168(%rbp)
movabsq $5,%rcx
cmpq $5,%rax
jne .L2197
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
movq $0,%r12
.L2199:
movq -184(%rbp),%rcx
cmpq %rcx,%r12
jae .L2200
movabsq $0,%rcx
cmpq $0,%r12
je .L2201
movq %rbx,%rdi
movabsq $44,%rsi
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
movq %rbx,%rdi
movabsq $32,%rsi
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
jmp .L2202
.L2201:
.L2202:
movq %r14,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i92
call rt_abort
.Lopt11_i92:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i92
xorq %rax,%rax
jmp .Lret_i92
.Lret_i92:
movq %rax,-192(%rbp)
movq -176(%rbp),%rax
movq %rbx,%rdi
movq -192(%rbp),%rsi
movq %rax,%rdx
call rt_fmt_value
movq %r12,%rax
addq $1,%rax
jnc .L2203
call rt_abort
.L2203:
movq %rax,%r12
jmp .L2199
.L2200:
movq %rbx,%rdi
movabsq $93,%rsi
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
movabsq $0,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2198
.L2197:
.L2198:
movq -24(%rbp),%rax
andq $4095,%rax
movq %rax,-200(%rbp)
movabsq $8,%rcx
cmpq $8,%rax
jne .L2204
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
movq $0,%r13
.L2206:
movq -216(%rbp),%rcx
cmpq %rcx,%r13
jae .L2207
movabsq $0,%rcx
cmpq $0,%r13
je .L2208
movq %rbx,%rdi
movabsq $44,%rsi
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
movq %rbx,%rdi
movabsq $32,%rsi
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
jmp .L2209
.L2208:
.L2209:
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
jnc .L2210
call rt_abort
.L2210:
movq %rax,%r13
jmp .L2206
.L2207:
movq %rbx,%rdi
movabsq $93,%rsi
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
movabsq $0,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2205
.L2204:
.L2205:
movq -24(%rbp),%rcx
movabsq $1023,%rax
cmpq %rcx,%rax
jae .L2211
movabsq $1024,%rcx
movq -24(%rbp),%rax
subq $1024,%rax
jnc .L2213
call rt_abort
.L2213:
movq %rbx,%rdi
movq %r14,%rsi
movq %rax,%rdx
call rt_fmt_int
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
jmp .L2212
.L2211:
.L2212:
call rt_abort
movabsq $0,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2164-8(%rbp),%rbx
movq -.F2164-16(%rbp),%r12
movq -.F2164-24(%rbp),%r13
movq -.F2164-32(%rbp),%r14
movq -.F2164-40(%rbp),%r15
leave
ret
.set .F2164,240
.type f_host_remove,@function
f_host_remove:
pushq %rbp
movq %rsp,%rbp
subq $.F2214,%rsp
subq $16,%rsp
movq %rbx,-.F2214-8(%rbp)
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
jne .L2215
movabsq $22,%rax
movq -.F2214-8(%rbp),%rbx
leave
ret
jmp .L2216
.L2215:
.L2216:
movq $0,-24(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2217
movq $512,-24(%rbp)
jmp .L2218
.L2217:
.L2218:
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
jmp .Lret_i93
xorq %rax,%rax
jmp .Lret_i93
.Lret_i93:
testq %rax,%rax
jz .L2219
movq -40(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F2214-8(%rbp),%rbx
leave
ret
jmp .L2220
.L2219:
.L2220:
movabsq $0,%rax
movq -.F2214-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2214-8(%rbp),%rbx
leave
ret
.set .F2214,48
.type f_host_create_dir,@function
f_host_create_dir:
pushq %rbp
movq %rsp,%rbp
subq $.F2221,%rsp
subq $16,%rsp
movq %rbx,-.F2221-8(%rbp)
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
jne .L2222
movabsq $22,%rax
movq -.F2221-8(%rbp),%rbx
leave
ret
jmp .L2223
.L2222:
.L2223:
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
jmp .Lret_i94
xorq %rax,%rax
jmp .Lret_i94
.Lret_i94:
testq %rax,%rax
jz .L2224
movq -24(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F2221-8(%rbp),%rbx
leave
ret
jmp .L2225
.L2224:
.L2225:
movabsq $0,%rax
movq -.F2221-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2221-8(%rbp),%rbx
leave
ret
.set .F2221,32
.type rt_fmt_pad,@function
rt_fmt_pad:
pushq %rbp
movq %rsp,%rbp
subq $.F2226,%rsp
subq $48,%rsp
movq %rbx,-.F2226-8(%rbp)
movq %r12,-.F2226-16(%rbp)
movq %r13,-.F2226-24(%rbp)
movq %r14,-.F2226-32(%rbp)
movq %r15,-.F2226-40(%rbp)
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
.L2227:
cmpq %r15,%rbx
jae .L2228
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt170
call rt_abort
.Lopt170:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-64(%rbp)
andq $192,%rax
movq %rax,-72(%rbp)
cmpq $128,%rax
je .L2229
movq -56(%rbp),%rax
addq $1,%rax
jnc .L2231
call rt_abort
.L2231:
movq %rax,-56(%rbp)
jmp .L2230
.L2229:
.L2230:
movq %rbx,%rax
addq $1,%rax
jnc .L2232
call rt_abort
.L2232:
movq %rax,%rbx
jmp .L2227
.L2228:
movq $0,-80(%rbp)
movq -56(%rbp),%rax
movq -24(%rbp),%rcx
cmpq %rcx,%rax
jae .L2233
movq -24(%rbp),%rax
movq -56(%rbp),%rcx
subq %rcx,%rax
jnc .L2235
call rt_abort
.L2235:
movq %rax,-80(%rbp)
jmp .L2234
.L2233:
.L2234:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2236
movq $0,%rbx
cmpq $0,%r15
je .L2238
movq %r14,%rdi
movabsq $0,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt171
call rt_abort
.Lopt171:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-88(%rbp)
cmpq $45,%rax
jne .L2240
movq %r13,%rdi
movabsq $45,%rsi
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
movq $1,%rbx
jmp .L2241
.L2240:
.L2241:
jmp .L2239
.L2238:
.L2239:
movq $0,-96(%rbp)
.L2242:
movq -96(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jae .L2243
movq %r13,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt174
call rt_pushb
jmp .Lopt175
.Lopt174:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt175:
movq -96(%rbp),%rax
addq $1,%rax
jnc .L2244
call rt_abort
.L2244:
movq %rax,-96(%rbp)
jmp .L2242
.L2243:
.L2245:
movq %r15,%rcx
cmpq %r15,%rbx
jae .L2246
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt176
call rt_abort
.Lopt176:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt177
call rt_pushb
jmp .Lopt178
.Lopt177:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt178:
movq %rbx,%rax
addq $1,%rax
jnc .L2247
call rt_abort
.L2247:
movq %rax,%rbx
jmp .L2245
.L2246:
movq %r14,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2226-8(%rbp),%rbx
movq -.F2226-16(%rbp),%r12
movq -.F2226-24(%rbp),%r13
movq -.F2226-32(%rbp),%r14
movq -.F2226-40(%rbp),%r15
leave
ret
jmp .L2237
.L2236:
.L2237:
movq $0,-104(%rbp)
movq -32(%rbp),%rax
cmpq $2,%rax
jne .L2248
movq -80(%rbp),%rax
movq %rax,-104(%rbp)
jmp .L2249
.L2248:
.L2249:
movabsq $3,%rcx
movq -32(%rbp),%rax
cmpq $3,%rax
jne .L2250
movq -80(%rbp),%rdi
movabsq $2,%rsi
call rt_div
movq %rax,-104(%rbp)
jmp .L2251
.L2250:
.L2251:
movq -80(%rbp),%rax
movq -104(%rbp),%rcx
subq %rcx,%rax
jnc .L2252
call rt_abort
.L2252:
movq %rax,-112(%rbp)
movq $0,%r12
.L2253:
movq -104(%rbp),%rcx
cmpq %rcx,%r12
jae .L2254
movq -48(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_push_char
movq %r12,%rax
addq $1,%rax
jnc .L2255
call rt_abort
.L2255:
movq %rax,%r12
jmp .L2253
.L2254:
movq $0,%rbx
.L2256:
cmpq %r15,%rbx
jae .L2257
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt179
call rt_abort
.Lopt179:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt180
call rt_pushb
jmp .Lopt181
.Lopt180:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt181:
movq %rbx,%rax
addq $1,%rax
jnc .L2258
call rt_abort
.L2258:
movq %rax,%rbx
jmp .L2256
.L2257:
movq $0,%r12
.L2259:
movq -112(%rbp),%rcx
cmpq %rcx,%r12
jae .L2260
movq -48(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_push_char
movq %r12,%rax
addq $1,%rax
jnc .L2261
call rt_abort
.L2261:
movq %rax,%r12
jmp .L2259
.L2260:
movq %r14,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2226-8(%rbp),%rbx
movq -.F2226-16(%rbp),%r12
movq -.F2226-24(%rbp),%r13
movq -.F2226-32(%rbp),%r14
movq -.F2226-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2226-8(%rbp),%rbx
movq -.F2226-16(%rbp),%r12
movq -.F2226-24(%rbp),%r13
movq -.F2226-32(%rbp),%r14
movq -.F2226-40(%rbp),%r15
leave
ret
.set .F2226,112
.type rt_push_char,@function
rt_push_char:
pushq %rbp
movq %rsp,%rbp
subq $.F2262,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt182
call rt_pushb
jmp .Lopt183
.Lopt182:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt183:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2262,16
.type rt_seq_cmp,@function
rt_seq_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2263,%rsp
subq $48,%rsp
movq %rbx,-.F2263-8(%rbp)
movq %r12,-.F2263-16(%rbp)
movq %r13,-.F2263-24(%rbp)
movq %r14,-.F2263-32(%rbp)
movq %r15,-.F2263-40(%rbp)
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
.L2264:
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
jz .L2265
movq -16(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt184
call rt_abort
.Lopt184:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt185
call rt_abort
.Lopt185:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r14
cmpq %r14,%r13
je .L2266
cmpq %r14,%r13
jae .L2268
movq $0,%r12
jmp .L2269
.L2268:
movq $2,%r12
.L2269:
jmp .L2265
jmp .L2267
.L2266:
.L2267:
movq %rbx,%rax
addq $1,%rax
jnc .L2270
call rt_abort
.L2270:
movq %rax,%rbx
jmp .L2264
.L2265:
cmpq $1,%r12
jne .L2271
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2273
movq $0,%r12
jmp .L2274
.L2273:
.L2274:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2275
movq $2,%r12
jmp .L2276
.L2275:
.L2276:
jmp .L2272
.L2271:
.L2272:
movq -8(%rbp),%rax
cmpq $258,%rax
jne .L2277
movq %r12,%rax
cmpq $1,%r12
sete %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
jmp .L2278
.L2277:
.L2278:
movq -8(%rbp),%rax
cmpq $259,%rax
jne .L2279
movq %r12,%rax
cmpq $1,%r12
setne %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
jmp .L2280
.L2279:
.L2280:
movq -8(%rbp),%rax
cmpq $60,%rax
jne .L2281
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
jmp .L2282
.L2281:
.L2282:
movq -8(%rbp),%rax
cmpq $62,%rax
jne .L2283
movq %r12,%rax
cmpq $2,%r12
sete %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
jmp .L2284
.L2283:
.L2284:
movq -8(%rbp),%rax
cmpq $269,%rax
jne .L2285
movq %r12,%rax
cmpq $2,%r12
setne %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
jmp .L2286
.L2285:
.L2286:
movabsq $270,%rcx
movq -8(%rbp),%rax
cmpq $270,%rax
jne .L2287
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
jmp .L2288
.L2287:
.L2288:
call rt_abort
movabsq $0,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2263-8(%rbp),%rbx
movq -.F2263-16(%rbp),%r12
movq -.F2263-24(%rbp),%r13
movq -.F2263-32(%rbp),%r14
movq -.F2263-40(%rbp),%r15
leave
ret
.set .F2263,48
.type rt_vec_cmp,@function
rt_vec_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2289,%rsp
subq $48,%rsp
movq %rbx,-.F2289-8(%rbp)
movq %r12,-.F2289-16(%rbp)
movq %r13,-.F2289-24(%rbp)
movq %r14,-.F2289-32(%rbp)
movq %r15,-.F2289-40(%rbp)
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
.L2290:
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
jz .L2291
movq -16(%rbp),%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i95
call rt_abort
.Lopt11_i95:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i95
xorq %rax,%rax
jmp .Lret_i95
.Lret_i95:
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i96
call rt_abort
.Lopt11_i96:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i96
xorq %rax,%rax
jmp .Lret_i96
.Lret_i96:
movq %rax,%r14
cmpq %r14,%r13
je .L2292
cmpq %r14,%r13
jae .L2294
movq $0,%r12
jmp .L2295
.L2294:
movq $2,%r12
.L2295:
jmp .L2291
jmp .L2293
.L2292:
.L2293:
movq %rbx,%rax
addq $1,%rax
jnc .L2296
call rt_abort
.L2296:
movq %rax,%rbx
jmp .L2290
.L2291:
movabsq $1,%rcx
cmpq $1,%r12
jne .L2297
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2299
movq $0,%r12
jmp .L2300
.L2299:
.L2300:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2301
movq $2,%r12
jmp .L2302
.L2301:
.L2302:
jmp .L2298
.L2297:
.L2298:
movq -8(%rbp),%rdi
movq %r12,%rsi
call rt_order_result
movq -.F2289-8(%rbp),%rbx
movq -.F2289-16(%rbp),%r12
movq -.F2289-24(%rbp),%r13
movq -.F2289-32(%rbp),%r14
movq -.F2289-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2289-8(%rbp),%rbx
movq -.F2289-16(%rbp),%r12
movq -.F2289-24(%rbp),%r13
movq -.F2289-32(%rbp),%r14
movq -.F2289-40(%rbp),%r15
leave
ret
.set .F2289,48
.type rt_order_result,@function
rt_order_result:
pushq %rbp
movq %rsp,%rbp
subq $.F2303,%rsp
subq $16,%rsp
movq %rbx,-.F2303-8(%rbp)
movq %r12,-.F2303-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
cmpq $258,%rbx
jne .L2304
movq %r12,%rax
cmpq $1,%r12
sete %al
movzbq %al,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
jmp .L2305
.L2304:
.L2305:
cmpq $259,%rbx
jne .L2306
movq %r12,%rax
cmpq $1,%r12
setne %al
movzbq %al,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
jmp .L2307
.L2306:
.L2307:
cmpq $60,%rbx
jne .L2308
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
jmp .L2309
.L2308:
.L2309:
cmpq $62,%rbx
jne .L2310
movq %r12,%rax
cmpq $2,%r12
sete %al
movzbq %al,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
jmp .L2311
.L2310:
.L2311:
cmpq $269,%rbx
jne .L2312
movq %r12,%rax
cmpq $2,%r12
setne %al
movzbq %al,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
jmp .L2313
.L2312:
.L2313:
movabsq $270,%rcx
cmpq $270,%rbx
jne .L2314
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
jmp .L2315
.L2314:
.L2315:
call rt_abort
movabsq $0,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2303-8(%rbp),%rbx
movq -.F2303-16(%rbp),%r12
leave
ret
.set .F2303,16
.type rt_concat,@function
rt_concat:
pushq %rbp
movq %rsp,%rbp
subq $.F2316,%rsp
subq $48,%rsp
movq %rbx,-.F2316-8(%rbp)
movq %r12,-.F2316-16(%rbp)
movq %r13,-.F2316-24(%rbp)
movq %r14,-.F2316-32(%rbp)
movq %r15,-.F2316-40(%rbp)
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
.L2317:
cmpq %r15,%rbx
jae .L2318
movq %r13,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt186
call rt_abort
.Lopt186:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt187
call rt_pushb
jmp .Lopt188
.Lopt187:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt188:
movq %rbx,%rax
addq $1,%rax
jnc .L2319
call rt_abort
.L2319:
movq %rax,%rbx
jmp .L2317
.L2318:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq $0,%rbx
.L2320:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2321
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt189
call rt_abort
.Lopt189:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt190
call rt_pushb
jmp .Lopt191
.Lopt190:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt191:
movq %rbx,%rax
addq $1,%rax
jnc .L2322
call rt_abort
.L2322:
movq %rax,%rbx
jmp .L2320
.L2321:
movq %r12,%rax
movq -.F2316-8(%rbp),%rbx
movq -.F2316-16(%rbp),%r12
movq -.F2316-24(%rbp),%r13
movq -.F2316-32(%rbp),%r14
movq -.F2316-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2316-8(%rbp),%rbx
movq -.F2316-16(%rbp),%r12
movq -.F2316-24(%rbp),%r13
movq -.F2316-32(%rbp),%r14
movq -.F2316-40(%rbp),%r15
leave
ret
.set .F2316,32
.type rt_concat_text,@function
rt_concat_text:
pushq %rbp
movq %rsp,%rbp
subq $.F2323,%rsp
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
.set .F2323,32
.type rt_seq_match,@function
rt_seq_match:
pushq %rbp
movq %rsp,%rbp
subq $.F2324,%rsp
subq $48,%rsp
movq %rbx,-.F2324-8(%rbp)
movq %r12,-.F2324-16(%rbp)
movq %r13,-.F2324-24(%rbp)
movq %r14,-.F2324-32(%rbp)
movq %r15,-.F2324-40(%rbp)
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
jnc .L2325
call rt_abort
.L2325:
movq %rax,%rcx
movq -40(%rbp),%rax
cmpq %rcx,%rax
jae .L2326
movabsq $0,%rax
movq -.F2324-8(%rbp),%rbx
movq -.F2324-16(%rbp),%r12
movq -.F2324-24(%rbp),%r13
movq -.F2324-32(%rbp),%r14
movq -.F2324-40(%rbp),%r15
leave
ret
jmp .L2327
.L2326:
.L2327:
movq $0,%rbx
.L2328:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2329
movq %r14,%rax
addq %rbx,%rax
jnc .L2330
call rt_abort
.L2330:
movq %r13,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt192
call rt_abort
.Lopt192:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq %r15,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt193
call rt_abort
.Lopt193:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r12
je .L2331
movabsq $0,%rax
movq -.F2324-8(%rbp),%rbx
movq -.F2324-16(%rbp),%r12
movq -.F2324-24(%rbp),%r13
movq -.F2324-32(%rbp),%r14
movq -.F2324-40(%rbp),%r15
leave
ret
jmp .L2332
.L2331:
.L2332:
movq %rbx,%rax
addq $1,%rax
jnc .L2333
call rt_abort
.L2333:
movq %rax,%rbx
jmp .L2328
.L2329:
movabsq $1,%rax
movq -.F2324-8(%rbp),%rbx
movq -.F2324-16(%rbp),%r12
movq -.F2324-24(%rbp),%r13
movq -.F2324-32(%rbp),%r14
movq -.F2324-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2324-8(%rbp),%rbx
movq -.F2324-16(%rbp),%r12
movq -.F2324-24(%rbp),%r13
movq -.F2324-32(%rbp),%r14
movq -.F2324-40(%rbp),%r15
leave
ret
.set .F2324,48
.type rt_seq_contains,@function
rt_seq_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F2334,%rsp
subq $48,%rsp
movq %rbx,-.F2334-8(%rbp)
movq %r12,-.F2334-16(%rbp)
movq %r13,-.F2334-24(%rbp)
movq %r14,-.F2334-32(%rbp)
movq %r15,-.F2334-40(%rbp)
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
jae .L2335
movabsq $0,%rax
movq -.F2334-8(%rbp),%rbx
movq -.F2334-16(%rbp),%r12
movq -.F2334-24(%rbp),%r13
movq -.F2334-32(%rbp),%r14
movq -.F2334-40(%rbp),%r15
leave
ret
jmp .L2336
.L2335:
.L2336:
movq $0,%rbx
.L2337:
movq %r15,%rax
movq -24(%rbp),%rcx
subq %rcx,%rax
jnc .L2339
call rt_abort
.L2339:
addq $1,%rax
jnc .L2340
call rt_abort
.L2340:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2338
movq %r13,%rdi
movq %rbx,%rsi
movq %r14,%rdx
call rt_seq_match
testq %rax,%rax
jz .L2341
movabsq $1,%rax
movq -.F2334-8(%rbp),%rbx
movq -.F2334-16(%rbp),%r12
movq -.F2334-24(%rbp),%r13
movq -.F2334-32(%rbp),%r14
movq -.F2334-40(%rbp),%r15
leave
ret
jmp .L2342
.L2341:
.L2342:
movq %rbx,%rax
addq $1,%rax
jnc .L2343
call rt_abort
.L2343:
movq %rax,%rbx
jmp .L2337
.L2338:
movabsq $0,%rax
movq -.F2334-8(%rbp),%rbx
movq -.F2334-16(%rbp),%r12
movq -.F2334-24(%rbp),%r13
movq -.F2334-32(%rbp),%r14
movq -.F2334-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2334-8(%rbp),%rbx
movq -.F2334-16(%rbp),%r12
movq -.F2334-24(%rbp),%r13
movq -.F2334-32(%rbp),%r14
movq -.F2334-40(%rbp),%r15
leave
ret
.set .F2334,32
.type rt_seq_starts,@function
rt_seq_starts:
pushq %rbp
movq %rsp,%rbp
subq $.F2344,%rsp
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
.set .F2344,16
.type rt_seq_ends,@function
rt_seq_ends:
pushq %rbp
movq %rsp,%rbp
subq $.F2345,%rsp
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
jae .L2346
movabsq $0,%rax
leave
ret
jmp .L2347
.L2346:
.L2347:
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
subq %rcx,%rax
jnc .L2348
call rt_abort
.L2348:
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
.set .F2345,48
.type rt_case_map,@function
rt_case_map:
pushq %rbp
movq %rsp,%rbp
subq $.F2349,%rsp
subq $16,%rsp
movq %rbx,-.F2349-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
leaq -.F2349(%rbp),%rdi
movq $.F2349/8-2,%rcx
xorl %eax,%eax
rep stosq
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2350
cmpq $940,%rbx
jne .L2352
movabsq $902,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2353
.L2352:
.L2353:
cmpq $941,%rbx
jne .L2354
movabsq $904,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2355
.L2354:
.L2355:
cmpq $942,%rbx
jne .L2356
movabsq $905,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2357
.L2356:
.L2357:
cmpq $943,%rbx
jne .L2358
movabsq $906,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2359
.L2358:
.L2359:
cmpq $972,%rbx
jne .L2360
movabsq $908,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2361
.L2360:
.L2361:
cmpq $973,%rbx
jne .L2362
movabsq $910,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2363
.L2362:
.L2363:
cmpq $974,%rbx
jne .L2364
movabsq $911,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2365
.L2364:
.L2365:
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
jz .L2366
movq %rbx,%rax
subq $32,%rax
jnc .L2368
call rt_abort
.L2368:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2367
.L2366:
.L2367:
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
jz .L2369
movq %rbx,%rax
subq $32,%rax
jnc .L2371
call rt_abort
.L2371:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2370
.L2369:
.L2370:
cmpq $255,%rbx
jne .L2372
movabsq $376,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2373
.L2372:
.L2373:
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
jz .L2374
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
jnc .L2376
call rt_abort
.L2376:
movq %rax,-72(%rbp)
movabsq $329,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2377
call rt_abort
.L2377:
testq %rax,%rax
jz .L2378
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
jnc .L2380
call rt_abort
.L2380:
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
jz .L2381
movq %rbx,%rax
subq $1,%rax
jnc .L2383
call rt_abort
.L2383:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2382
.L2381:
.L2382:
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
jz .L2384
movq %rbx,%rax
subq $1,%rax
jnc .L2386
call rt_abort
.L2386:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2385
.L2384:
.L2385:
jmp .L2379
.L2378:
.L2379:
jmp .L2375
.L2374:
.L2375:
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
jz .L2387
movq %rbx,%rax
subq $32,%rax
jnc .L2389
call rt_abort
.L2389:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2388
.L2387:
.L2388:
cmpq $962,%rbx
jne .L2390
movabsq $931,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2391
.L2390:
.L2391:
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
jz .L2392
movq %rbx,%rax
subq $32,%rax
jnc .L2394
call rt_abort
.L2394:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2393
.L2392:
.L2393:
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
jz .L2395
movq %rbx,%rax
subq $80,%rax
jnc .L2397
call rt_abort
.L2397:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2396
.L2395:
.L2396:
movq %rbx,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2351
.L2350:
.L2351:
cmpq $902,%rbx
jne .L2398
movabsq $940,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2399
.L2398:
.L2399:
cmpq $904,%rbx
jne .L2400
movabsq $941,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2401
.L2400:
.L2401:
cmpq $905,%rbx
jne .L2402
movabsq $942,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2403
.L2402:
.L2403:
cmpq $906,%rbx
jne .L2404
movabsq $943,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2405
.L2404:
.L2405:
cmpq $908,%rbx
jne .L2406
movabsq $972,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2407
.L2406:
.L2407:
cmpq $910,%rbx
jne .L2408
movabsq $973,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2409
.L2408:
.L2409:
cmpq $911,%rbx
jne .L2410
movabsq $974,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2411
.L2410:
.L2411:
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
jz .L2412
movq %rbx,%rax
addq $32,%rax
jnc .L2414
call rt_abort
.L2414:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2413
.L2412:
.L2413:
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
jz .L2415
movq %rbx,%rax
addq $32,%rax
jnc .L2417
call rt_abort
.L2417:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2416
.L2415:
.L2416:
cmpq $376,%rbx
jne .L2418
movabsq $255,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2419
.L2418:
.L2419:
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
jz .L2420
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
jnc .L2422
call rt_abort
.L2422:
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
jz .L2423
movq %rbx,%rax
addq $1,%rax
jnc .L2425
call rt_abort
.L2425:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2424
.L2423:
.L2424:
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
jz .L2426
movq %rbx,%rax
addq $1,%rax
jnc .L2428
call rt_abort
.L2428:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2427
.L2426:
.L2427:
jmp .L2421
.L2420:
.L2421:
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
jz .L2429
movq %rbx,%rax
addq $32,%rax
jnc .L2431
call rt_abort
.L2431:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2430
.L2429:
.L2430:
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
jz .L2432
movq %rbx,%rax
addq $32,%rax
jnc .L2434
call rt_abort
.L2434:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2433
.L2432:
.L2433:
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
jz .L2435
movq %rbx,%rax
addq $80,%rax
jnc .L2437
call rt_abort
.L2437:
movq -.F2349-8(%rbp),%rbx
leave
ret
jmp .L2436
.L2435:
.L2436:
movq %rbx,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2349-8(%rbp),%rbx
leave
ret
.set .F2349,304
.type rt_push_utf8,@function
rt_push_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F2438,%rsp
subq $16,%rsp
movq %rbx,-.F2438-8(%rbp)
movq %r12,-.F2438-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq %rsi,%rbx
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
cmpq $128,%rbx
jae .L2439
movq %r12,%rdi
movq %rbx,%rsi
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
movabsq $0,%rax
movq -.F2438-8(%rbp),%rbx
movq -.F2438-16(%rbp),%r12
leave
ret
jmp .L2440
.L2439:
.L2440:
movabsq $2048,%rcx
cmpq $2048,%rbx
jae .L2441
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,%rcx
movabsq $192,%rax
addq %rcx,%rax
jnc .L2443
call rt_abort
.L2443:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt196
call rt_pushb
jmp .Lopt197
.Lopt196:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt197:
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2444:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2445
call rt_abort
.L2445:
movq %r12,%rdi
movq %rax,%rsi
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
movq -.F2438-8(%rbp),%rbx
movq -.F2438-16(%rbp),%r12
leave
ret
jmp .L2442
.L2441:
.L2442:
movabsq $65536,%rcx
cmpq $65536,%rbx
jae .L2446
movq %rbx,%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,%rcx
movabsq $224,%rax
addq %rcx,%rax
jnc .L2448
call rt_abort
.L2448:
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
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,-24(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2449:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2450
call rt_abort
.L2450:
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
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2451:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2452
call rt_abort
.L2452:
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
movabsq $0,%rax
movq -.F2438-8(%rbp),%rbx
movq -.F2438-16(%rbp),%r12
leave
ret
jmp .L2447
.L2446:
.L2447:
movq %rbx,%rdi
movabsq $262144,%rsi
call rt_div
movq %rax,%rcx
movabsq $240,%rax
addq %rcx,%rax
jnc .L2453
call rt_abort
.L2453:
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
movq %rbx,%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,-32(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2454:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2455
call rt_abort
.L2455:
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
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,-40(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2456:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2457
call rt_abort
.L2457:
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
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2458:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2459
call rt_abort
.L2459:
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
movabsq $0,%rax
movq -.F2438-8(%rbp),%rbx
movq -.F2438-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2438-8(%rbp),%rbx
movq -.F2438-16(%rbp),%r12
leave
ret
.set .F2438,48
.type rt_seq_case,@function
rt_seq_case:
pushq %rbp
movq %rsp,%rbp
subq $.F2460,%rsp
subq $48,%rsp
movq %rbx,-.F2460-8(%rbp)
movq %r12,-.F2460-16(%rbp)
movq %r13,-.F2460-24(%rbp)
movq %r14,-.F2460-32(%rbp)
movq %r15,-.F2460-40(%rbp)
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
.L2461:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2462
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt214
call rt_abort
.Lopt214:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq %rax,-32(%rbp)
movabsq $128,%rcx
cmpq $128,%rax
jae .L2463
movq %r12,%rdi
movq %r15,%rsi
call rt_case_map
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt215
call rt_pushb
jmp .Lopt216
.Lopt215:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt216:
movq %rbx,%rax
addq $1,%rax
jnc .L2465
call rt_abort
.L2465:
movq %rax,%rbx
jmp .L2464
.L2463:
movq %r12,%rax
andq $224,%rax
movq %rax,-40(%rbp)
cmpq $192,%rax
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2466
call rt_abort
.L2466:
movq -24(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2467
movq %rbx,%rax
addq $1,%rax
jnc .L2469
call rt_abort
.L2469:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt217
call rt_abort
.Lopt217:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
andq $192,%rax
movq %rax,-72(%rbp)
cmpq $128,%rax
jne .L2470
movq %r12,%rax
andq $31,%rax
movq %rax,-80(%rbp)
movabsq $64,%rcx
mulq %rcx
jnc .L2472
call rt_abort
.L2472:
movq %rax,-88(%rbp)
movq -56(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2473
call rt_abort
.L2473:
movq %rax,-96(%rbp)
movq -96(%rbp),%rdi
movq %r15,%rsi
call rt_case_map
movq %r13,%rdi
movq %rax,%rsi
call rt_push_utf8
movq %rbx,%rax
addq $2,%rax
jnc .L2474
call rt_abort
.L2474:
movq %rax,%rbx
jmp .L2471
.L2470:
movq %r13,%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt218
call rt_pushb
jmp .Lopt219
.Lopt218:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt219:
movq %rbx,%rax
addq $1,%rax
jnc .L2475
call rt_abort
.L2475:
movq %rax,%rbx
.L2471:
jmp .L2468
.L2467:
movq %r13,%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt220
call rt_pushb
jmp .Lopt221
.Lopt220:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt221:
movq %rbx,%rax
addq $1,%rax
jnc .L2476
call rt_abort
.L2476:
movq %rax,%rbx
.L2468:
.L2464:
jmp .L2461
.L2462:
movq %r13,%rax
movq -.F2460-8(%rbp),%rbx
movq -.F2460-16(%rbp),%r12
movq -.F2460-24(%rbp),%r13
movq -.F2460-32(%rbp),%r14
movq -.F2460-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2460-8(%rbp),%rbx
movq -.F2460-16(%rbp),%r12
movq -.F2460-24(%rbp),%r13
movq -.F2460-32(%rbp),%r14
movq -.F2460-40(%rbp),%r15
leave
ret
.set .F2460,96
.type rt_seq_upper,@function
rt_seq_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2477,%rsp
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
.set .F2477,16
.type rt_seq_lower,@function
rt_seq_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2478,%rsp
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
.set .F2478,16
.type rt_space,@function
rt_space:
pushq %rbp
movq %rsp,%rbp
subq $.F2479,%rsp
subq $16,%rsp
movq %rbx,-.F2479-8(%rbp)
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
jnc .L2480
call rt_abort
.L2480:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $10,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2481
call rt_abort
.L2481:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $13,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2482
call rt_abort
.L2482:
movq -.F2479-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2479-8(%rbp),%rbx
leave
ret
.set .F2479,32
.type rt_seq_trim,@function
rt_seq_trim:
pushq %rbp
movq %rsp,%rbp
subq $.F2483,%rsp
subq $48,%rsp
movq %rbx,-.F2483-8(%rbp)
movq %r12,-.F2483-16(%rbp)
movq %r13,-.F2483-24(%rbp)
movq %r14,-.F2483-32(%rbp)
movq %r15,-.F2483-40(%rbp)
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
.L2484:
movq %rbx,%rcx
cmpq %rbx,%r12
jae .L2485
movq %r14,%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt222
call rt_abort
.Lopt222:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rdi
call rt_space
cmpq $0,%rax
jne .L2486
jmp .L2485
jmp .L2487
.L2486:
.L2487:
movq %r12,%rax
addq $1,%rax
jnc .L2488
call rt_abort
.L2488:
movq %rax,%r12
jmp .L2484
.L2485:
.L2489:
movq %rbx,%rcx
cmpq %rbx,%r12
jae .L2490
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2491
call rt_abort
.L2491:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt223
call rt_abort
.Lopt223:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rdi
call rt_space
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2492
jmp .L2490
jmp .L2493
.L2492:
.L2493:
movq %rbx,%rax
subq $1,%rax
jnc .L2494
call rt_abort
.L2494:
movq %rax,%rbx
jmp .L2489
.L2490:
call rt_new
movq %rax,-24(%rbp)
movq %r12,%r13
.L2495:
cmpq %rbx,%r13
jae .L2496
movq %r14,%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt224
call rt_abort
.Lopt224:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt225
call rt_pushb
jmp .Lopt226
.Lopt225:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt226:
movq %r13,%rax
addq $1,%rax
jnc .L2497
call rt_abort
.L2497:
movq %rax,%r13
jmp .L2495
.L2496:
movq -24(%rbp),%rax
movq -.F2483-8(%rbp),%rbx
movq -.F2483-16(%rbp),%r12
movq -.F2483-24(%rbp),%r13
movq -.F2483-32(%rbp),%r14
movq -.F2483-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2483-8(%rbp),%rbx
movq -.F2483-16(%rbp),%r12
movq -.F2483-24(%rbp),%r13
movq -.F2483-32(%rbp),%r14
movq -.F2483-40(%rbp),%r15
leave
ret
.set .F2483,32
.type rt_seq_replace,@function
rt_seq_replace:
pushq %rbp
movq %rsp,%rbp
subq $.F2498,%rsp
subq $48,%rsp
movq %rbx,-.F2498-8(%rbp)
movq %r12,-.F2498-16(%rbp)
movq %r13,-.F2498-24(%rbp)
movq %r14,-.F2498-32(%rbp)
movq %r15,-.F2498-40(%rbp)
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
.L2499:
movq -40(%rbp),%rcx
cmpq %rcx,%r12
jae .L2500
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
jz .L2501
movq $0,%rbx
.L2503:
cmpq %r15,%rbx
jae .L2504
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt227
call rt_abort
.Lopt227:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt228
call rt_pushb
jmp .Lopt229
.Lopt228:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt229:
movq %rbx,%rax
addq $1,%rax
jnc .L2505
call rt_abort
.L2505:
movq %rax,%rbx
jmp .L2503
.L2504:
movq %r12,%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L2506
call rt_abort
.L2506:
movq %rax,%r12
jmp .L2502
.L2501:
movq -8(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt230
call rt_abort
.Lopt230:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt231
call rt_pushb
jmp .Lopt232
.Lopt231:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt232:
movq %r12,%rax
addq $1,%rax
jnc .L2507
call rt_abort
.L2507:
movq %rax,%r12
.L2502:
jmp .L2499
.L2500:
movq -32(%rbp),%rax
testq %rax,%rax
jz .L2508
movq %r13,%rdi
call rt_utf8
jmp .L2509
.L2508:
.L2509:
movq %r13,%rax
movq -.F2498-8(%rbp),%rbx
movq -.F2498-16(%rbp),%r12
movq -.F2498-24(%rbp),%r13
movq -.F2498-32(%rbp),%r14
movq -.F2498-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2498-8(%rbp),%rbx
movq -.F2498-16(%rbp),%r12
movq -.F2498-24(%rbp),%r13
movq -.F2498-32(%rbp),%r14
movq -.F2498-40(%rbp),%r15
leave
ret
.set .F2498,64
.type rt_seq_repeat,@function
rt_seq_repeat:
pushq %rbp
movq %rsp,%rbp
subq $.F2510,%rsp
subq $48,%rsp
movq %rbx,-.F2510-8(%rbp)
movq %r12,-.F2510-16(%rbp)
movq %r13,-.F2510-24(%rbp)
movq %r14,-.F2510-32(%rbp)
movq %r15,-.F2510-40(%rbp)
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
.L2511:
movq -16(%rbp),%rcx
cmpq %rcx,%r15
jae .L2512
movq $0,%rbx
.L2513:
cmpq %r14,%rbx
jae .L2514
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt233
call rt_abort
.Lopt233:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt234
call rt_pushb
jmp .Lopt235
.Lopt234:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt235:
movq %rbx,%rax
addq $1,%rax
jnc .L2515
call rt_abort
.L2515:
movq %rax,%rbx
jmp .L2513
.L2514:
movq %r15,%rax
addq $1,%rax
jnc .L2516
call rt_abort
.L2516:
movq %rax,%r15
jmp .L2511
.L2512:
movq %r13,%rax
movq -.F2510-8(%rbp),%rbx
movq -.F2510-16(%rbp),%r12
movq -.F2510-24(%rbp),%r13
movq -.F2510-32(%rbp),%r14
movq -.F2510-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2510-8(%rbp),%rbx
movq -.F2510-16(%rbp),%r12
movq -.F2510-24(%rbp),%r13
movq -.F2510-32(%rbp),%r14
movq -.F2510-40(%rbp),%r15
leave
ret
.set .F2510,16
.type rt_seq_split,@function
rt_seq_split:
pushq %rbp
movq %rsp,%rbp
subq $.F2517,%rsp
subq $48,%rsp
movq %rbx,-.F2517-8(%rbp)
movq %r12,-.F2517-16(%rbp)
movq %r13,-.F2517-24(%rbp)
movq %r14,-.F2517-32(%rbp)
movq %r15,-.F2517-40(%rbp)
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
.L2518:
movq -32(%rbp),%rcx
cmpq %rcx,%r12
jae .L2519
movq %r15,%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt236
call rt_abort
.Lopt236:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r13
movq -16(%rbp),%rcx
cmpq %rcx,%rax
jne .L2520
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2522
movq %rbx,%rdi
call rt_utf8
jmp .L2523
.L2522:
.L2523:
movq %r14,%rdi
movq %rbx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt237
call rt_push
jmp .Lopt238
.Lopt237:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt238:
call rt_new
movq %rax,%rbx
jmp .L2521
.L2520:
movq %rbx,%rdi
movq %r13,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt239
call rt_pushb
jmp .Lopt240
.Lopt239:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt240:
.L2521:
movq %r12,%rax
addq $1,%rax
jnc .L2524
call rt_abort
.L2524:
movq %rax,%r12
jmp .L2518
.L2519:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2525
movq %rbx,%rdi
call rt_utf8
jmp .L2526
.L2525:
.L2526:
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
movq %r14,%rax
movq -.F2517-8(%rbp),%rbx
movq -.F2517-16(%rbp),%r12
movq -.F2517-24(%rbp),%r13
movq -.F2517-32(%rbp),%r14
movq -.F2517-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2517-8(%rbp),%rbx
movq -.F2517-16(%rbp),%r12
movq -.F2517-24(%rbp),%r13
movq -.F2517-32(%rbp),%r14
movq -.F2517-40(%rbp),%r15
leave
ret
.set .F2517,32
.type rt_load32,@function
rt_load32:
pushq %rbp
movq %rsp,%rbp
subq $.F2527,%rsp
subq $16,%rsp
movq %rbx,-.F2527-8(%rbp)
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
jnc .L2528
call rt_abort
.L2528:
movzbq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $8,%rax
jnc .L2529
call rt_abort
.L2529:
movabsq $8,%rcx
movq -24(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
orq %rcx,%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
addq $2,%rax
jnc .L2530
call rt_abort
.L2530:
movzbq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $16,%rax
jnc .L2531
call rt_abort
.L2531:
movabsq $16,%rcx
movq -40(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $3,%rax
jnc .L2532
call rt_abort
.L2532:
movzbq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $63,%rax
cmpq $24,%rax
jnc .L2533
call rt_abort
.L2533:
movabsq $24,%rcx
movq -56(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F2527-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2527-8(%rbp),%rbx
leave
ret
.set .F2527,64
.type rt_store32,@function
rt_store32:
pushq %rbp
movq %rsp,%rbp
subq $.F2534,%rsp
subq $16,%rsp
movq %rbx,-.F2534-8(%rbp)
movq %r12,-.F2534-16(%rbp)
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
jnc .L2535
call rt_abort
.L2535:
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $8,%rax
jnc .L2536
call rt_abort
.L2536:
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
jnc .L2537
call rt_abort
.L2537:
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $16,%rax
jnc .L2538
call rt_abort
.L2538:
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
jnc .L2539
call rt_abort
.L2539:
movq %rax,-56(%rbp)
movabsq $63,%rax
cmpq $24,%rax
jnc .L2540
call rt_abort
.L2540:
movabsq $24,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-64(%rbp)
andq $255,%rax
movq -56(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F2534-8(%rbp),%rbx
movq -.F2534-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2534-8(%rbp),%rbx
movq -.F2534-16(%rbp),%r12
leave
ret
.set .F2534,64
.type rt_push4,@function
rt_push4:
pushq %rbp
movq %rsp,%rbp
subq $.F2541,%rsp
subq $32,%rsp
movq %rbx,-.F2541-8(%rbp)
movq %r12,-.F2541-16(%rbp)
movq %r13,-.F2541-24(%rbp)
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
jnc .L2542
call rt_abort
.L2542:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L2543
call rt_abort
.L2543:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L2544
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L2546
call rt_abort
.L2546:
movq %rax,%r13
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L2547
movq $8,%r13
jmp .L2548
.L2547:
.L2548:
movq %r13,%rcx
movabsq $288230376151711744,%rax
cmpq %r13,%rax
jae .L2549
call rt_abort
jmp .L2550
.L2549:
.L2550:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2551
call rt_abort
.L2551:
movq %rax,-48(%rbp)
movabsq $4,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2552
call rt_abort
.L2552:
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
jnc .L2553
call rt_abort
.L2553:
movq %rax,-64(%rbp)
movq %r13,%rax
movq -64(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
jmp .L2545
.L2544:
.L2545:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2554
call rt_abort
.L2554:
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2555
call rt_abort
.L2555:
movq %rax,-80(%rbp)
movq -16(%rbp),%rax
movq -80(%rbp),%rdi
movq %rax,%rsi
call rt_store32
movq %rbx,%rax
addq $8,%rax
jnc .L2556
call rt_abort
.L2556:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L2557
call rt_abort
.L2557:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F2541-8(%rbp),%rbx
movq -.F2541-16(%rbp),%r12
movq -.F2541-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2541-8(%rbp),%rbx
movq -.F2541-16(%rbp),%r12
movq -.F2541-24(%rbp),%r13
leave
ret
.set .F2541,96
.type rt_fill4,@function
rt_fill4:
pushq %rbp
movq %rsp,%rbp
subq $.F2558,%rsp
subq $48,%rsp
movq %rbx,-.F2558-8(%rbp)
movq %r12,-.F2558-16(%rbp)
movq %r13,-.F2558-24(%rbp)
movq %r14,-.F2558-32(%rbp)
movq %r15,-.F2558-40(%rbp)
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
jae .L2559
call rt_abort
jmp .L2560
.L2559:
.L2560:
cmpq $0,%r12
je .L2561
movq %r13,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2563
call rt_abort
.L2563:
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
jnc .L2564
call rt_abort
.L2564:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L2562
.L2561:
.L2562:
movq $0,%rbx
.L2565:
cmpq %r12,%rbx
jae .L2566
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r14
movabsq $4,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2567
call rt_abort
.L2567:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2568
call rt_abort
.L2568:
movq %rax,%r15
movq -16(%rbp),%rax
movq %r15,%rdi
movq %rax,%rsi
call rt_store32
movq %rbx,%rax
addq $1,%rax
jnc .L2569
call rt_abort
.L2569:
movq %rax,%rbx
jmp .L2565
.L2566:
movq %r13,%rax
addq $8,%rax
jnc .L2570
call rt_abort
.L2570:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movabsq $0,%rax
movq -.F2558-8(%rbp),%rbx
movq -.F2558-16(%rbp),%r12
movq -.F2558-24(%rbp),%r13
movq -.F2558-32(%rbp),%r14
movq -.F2558-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2558-8(%rbp),%rbx
movq -.F2558-16(%rbp),%r12
movq -.F2558-24(%rbp),%r13
movq -.F2558-32(%rbp),%r14
movq -.F2558-40(%rbp),%r15
leave
ret
.set .F2558,64
.type rt_slot4u,@function
rt_slot4u:
pushq %rbp
movq %rsp,%rbp
subq $.F2571,%rsp
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
jnc .L2572
call rt_abort
.L2572:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2573
call rt_abort
.L2573:
leave
ret
xorq %rax,%rax
leave
ret
.set .F2571,32
.type rt_slot4,@function
rt_slot4:
pushq %rbp
movq %rsp,%rbp
subq $.F2574,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L2575
call rt_abort
.L2575:
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
jne .L2576
call rt_abort
jmp .L2577
.L2576:
.L2577:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L2578
call rt_abort
.L2578:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2579
call rt_abort
.L2579:
leave
ret
xorq %rax,%rax
leave
ret
.set .F2574,32
.type rt_at4u,@function
rt_at4u:
pushq %rbp
movq %rsp,%rbp
subq $.F2580,%rsp
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
jnc .L2581
call rt_abort
.L2581:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2582
call rt_abort
.L2582:
movq %rax,%rdi
call rt_load32
leave
ret
xorq %rax,%rax
leave
ret
.set .F2580,32
.type rt_at4,@function
rt_at4:
pushq %rbp
movq %rsp,%rbp
subq $.F2583,%rsp
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
.set .F2583,16
.type rt_set4,@function
rt_set4:
pushq %rbp
movq %rsp,%rbp
subq $.F2584,%rsp
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
jnc .L2585
call rt_abort
.L2585:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2586
call rt_abort
.L2586:
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
.set .F2584,48
.type rt_pop4,@function
rt_pop4:
pushq %rbp
movq %rsp,%rbp
subq $.F2587,%rsp
subq $16,%rsp
movq %rbx,-.F2587-8(%rbp)
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
jnc .L2588
call rt_abort
.L2588:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2589
call rt_abort
jmp .L2590
.L2589:
.L2590:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
subq $1,%rax
jnc .L2591
call rt_abort
.L2591:
movq %rax,-40(%rbp)
movabsq $4,%rcx
mulq %rcx
jnc .L2592
call rt_abort
.L2592:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2593
call rt_abort
.L2593:
movq %rax,%rdi
call rt_load32
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L2594
call rt_abort
.L2594:
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
subq $1,%rax
jnc .L2595
call rt_abort
.L2595:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
movq -.F2587-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2587-8(%rbp),%rbx
leave
ret
.set .F2587,64
.type rt_vec_copy4,@function
rt_vec_copy4:
pushq %rbp
movq %rsp,%rbp
subq $.F2596,%rsp
subq $48,%rsp
movq %rbx,-.F2596-8(%rbp)
movq %r12,-.F2596-16(%rbp)
movq %r13,-.F2596-24(%rbp)
movq %r14,-.F2596-32(%rbp)
movq %r15,-.F2596-40(%rbp)
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
jnc .L2597
call rt_abort
.L2597:
movq (%rax),%rax
movq %rax,%r15
movq $0,%rbx
.L2598:
cmpq %r15,%rbx
jae .L2599
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r12
movabsq $4,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2600
call rt_abort
.L2600:
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L2601
call rt_abort
.L2601:
movq %rax,%rdi
call rt_load32
movq %r14,%rdi
movq %rax,%rsi
call rt_push4
movq %rbx,%rax
addq $1,%rax
jnc .L2602
call rt_abort
.L2602:
movq %rax,%rbx
jmp .L2598
.L2599:
movq %r14,%rax
movq -.F2596-8(%rbp),%rbx
movq -.F2596-16(%rbp),%r12
movq -.F2596-24(%rbp),%r13
movq -.F2596-32(%rbp),%r14
movq -.F2596-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2596-8(%rbp),%rbx
movq -.F2596-16(%rbp),%r12
movq -.F2596-24(%rbp),%r13
movq -.F2596-32(%rbp),%r14
movq -.F2596-40(%rbp),%r15
leave
ret
.set .F2596,16
.type rt_vec_insert4,@function
rt_vec_insert4:
pushq %rbp
movq %rsp,%rbp
subq $.F2603,%rsp
subq $32,%rsp
movq %rbx,-.F2603-8(%rbp)
movq %r12,-.F2603-16(%rbp)
movq %r13,-.F2603-24(%rbp)
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
jae .L2604
call rt_abort
jmp .L2605
.L2604:
.L2605:
movq %r12,%rdi
movabsq $0,%rsi
call rt_push4
movq -32(%rbp),%rax
movq %rax,%rbx
.L2606:
movq %rbx,%rcx
cmpq %rbx,%r13
jae .L2607
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2608
call rt_abort
.L2608:
movq %r12,%rdi
movq %rax,%rsi
call rt_at4
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_set4
movq %rbx,%rax
subq $1,%rax
jnc .L2609
call rt_abort
.L2609:
movq %rax,%rbx
jmp .L2606
.L2607:
movq -24(%rbp),%rax
movq %r12,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_set4
movabsq $0,%rax
movq -.F2603-8(%rbp),%rbx
movq -.F2603-16(%rbp),%r12
movq -.F2603-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2603-8(%rbp),%rbx
movq -.F2603-16(%rbp),%r12
movq -.F2603-24(%rbp),%r13
leave
ret
.set .F2603,32
.type rt_vec_remove4,@function
rt_vec_remove4:
pushq %rbp
movq %rsp,%rbp
subq $.F2610,%rsp
subq $32,%rsp
movq %rbx,-.F2610-8(%rbp)
movq %r12,-.F2610-16(%rbp)
movq %r13,-.F2610-24(%rbp)
movq %r14,-.F2610-32(%rbp)
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
jne .L2611
call rt_abort
jmp .L2612
.L2611:
.L2612:
movq %r12,%rdi
movq %r14,%rsi
call rt_at4
movq %rax,-32(%rbp)
movq %r14,%rbx
.L2613:
movq %rbx,%rax
addq $1,%rax
jnc .L2615
call rt_abort
.L2615:
movq %r13,%rcx
cmpq %r13,%rax
jae .L2614
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2616
call rt_abort
.L2616:
movq %r12,%rdi
movq %rax,%rsi
call rt_at4
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_set4
movq %rbx,%rax
addq $1,%rax
jnc .L2617
call rt_abort
.L2617:
movq %rax,%rbx
jmp .L2613
.L2614:
movq %r12,%rdi
call rt_pop4
movq -32(%rbp),%rax
movq -.F2610-8(%rbp),%rbx
movq -.F2610-16(%rbp),%r12
movq -.F2610-24(%rbp),%r13
movq -.F2610-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2610-8(%rbp),%rbx
movq -.F2610-16(%rbp),%r12
movq -.F2610-24(%rbp),%r13
movq -.F2610-32(%rbp),%r14
leave
ret
.set .F2610,32
.type rt_vec_swap4,@function
rt_vec_swap4:
pushq %rbp
movq %rsp,%rbp
subq $.F2618,%rsp
subq $32,%rsp
movq %rbx,-.F2618-8(%rbp)
movq %r12,-.F2618-16(%rbp)
movq %r13,-.F2618-24(%rbp)
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
jnc .L2619
call rt_abort
.L2619:
testq %rax,%rax
jz .L2620
call rt_abort
jmp .L2621
.L2620:
.L2621:
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
movq -.F2618-8(%rbp),%rbx
movq -.F2618-16(%rbp),%r12
movq -.F2618-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2618-8(%rbp),%rbx
movq -.F2618-16(%rbp),%r12
movq -.F2618-24(%rbp),%r13
leave
ret
.set .F2618,64
.type rt_vec_reverse4,@function
rt_vec_reverse4:
pushq %rbp
movq %rsp,%rbp
subq $.F2622,%rsp
subq $32,%rsp
movq %rbx,-.F2622-8(%rbp)
movq %r12,-.F2622-16(%rbp)
movq %r13,-.F2622-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
movq $0,%rbx
.L2623:
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2624
movq %r12,%rax
subq $1,%rax
jnc .L2625
call rt_abort
.L2625:
movq %rbx,%rcx
subq %rbx,%rax
jnc .L2626
call rt_abort
.L2626:
movq %r13,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_swap4
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2627
call rt_abort
.L2627:
movq %rax,%rbx
jmp .L2623
.L2624:
movabsq $0,%rax
movq -.F2622-8(%rbp),%rbx
movq -.F2622-16(%rbp),%r12
movq -.F2622-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2622-8(%rbp),%rbx
movq -.F2622-16(%rbp),%r12
movq -.F2622-24(%rbp),%r13
leave
ret
.set .F2622,16
.type rt_vec_truncate4,@function
rt_vec_truncate4:
pushq %rbp
movq %rsp,%rbp
subq $.F2628,%rsp
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
jae .L2629
movq -8(%rbp),%rax
addq $8,%rax
jnc .L2631
call rt_abort
.L2631:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L2630
.L2629:
.L2630:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2628,32
.type rt_vec_contains4,@function
rt_vec_contains4:
pushq %rbp
movq %rsp,%rbp
subq $.F2632,%rsp
subq $32,%rsp
movq %rbx,-.F2632-8(%rbp)
movq %r12,-.F2632-16(%rbp)
movq %r13,-.F2632-24(%rbp)
movq %r14,-.F2632-32(%rbp)
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
.L2633:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L2634
movq %r12,%rdi
movq %rbx,%rsi
call rt_at4
cmpq %r14,%rax
jne .L2635
movabsq $1,%rax
movq -.F2632-8(%rbp),%rbx
movq -.F2632-16(%rbp),%r12
movq -.F2632-24(%rbp),%r13
movq -.F2632-32(%rbp),%r14
leave
ret
jmp .L2636
.L2635:
.L2636:
movq %rbx,%rax
addq $1,%rax
jnc .L2637
call rt_abort
.L2637:
movq %rax,%rbx
jmp .L2633
.L2634:
movabsq $0,%rax
movq -.F2632-8(%rbp),%rbx
movq -.F2632-16(%rbp),%r12
movq -.F2632-24(%rbp),%r13
movq -.F2632-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2632-8(%rbp),%rbx
movq -.F2632-16(%rbp),%r12
movq -.F2632-24(%rbp),%r13
movq -.F2632-32(%rbp),%r14
leave
ret
.set .F2632,16
.type rt_narrow_decode,@function
rt_narrow_decode:
pushq %rbp
movq %rsp,%rbp
subq $.F2638,%rsp
subq $16,%rsp
movq %rbx,-.F2638-8(%rbp)
movq %r12,-.F2638-16(%rbp)
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
jne .L2639
movq %rbx,%rdi
call rt_f32_from_bits
movq -.F2638-8(%rbp),%rbx
movq -.F2638-16(%rbp),%r12
leave
ret
jmp .L2640
.L2639:
.L2640:
movabsq $1023,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %r12,%rax
subq $1024,%rax
jnc .L2641
call rt_abort
.L2641:
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
jz .L2642
movabsq $2147483648,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
je .L2644
movabsq $18446744069414584320,%rcx
movq %rbx,%rax
orq %rcx,%rax
movq -.F2638-8(%rbp),%rbx
movq -.F2638-16(%rbp),%r12
leave
ret
jmp .L2645
.L2644:
.L2645:
jmp .L2643
.L2642:
.L2643:
movq %rbx,%rax
movq -.F2638-8(%rbp),%rbx
movq -.F2638-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2638-8(%rbp),%rbx
movq -.F2638-16(%rbp),%r12
leave
ret
.set .F2638,48
.type rt_vec_feq,@function
rt_vec_feq:
pushq %rbp
movq %rsp,%rbp
subq $.F2646,%rsp
subq $48,%rsp
movq %rbx,-.F2646-8(%rbp)
movq %r12,-.F2646-16(%rbp)
movq %r13,-.F2646-24(%rbp)
movq %r14,-.F2646-32(%rbp)
movq %r15,-.F2646-40(%rbp)
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
je .L2647
movabsq $0,%rax
movq -.F2646-8(%rbp),%rbx
movq -.F2646-16(%rbp),%r12
movq -.F2646-24(%rbp),%r13
movq -.F2646-32(%rbp),%r14
movq -.F2646-40(%rbp),%r15
leave
ret
jmp .L2648
.L2647:
.L2648:
movq $0,%rbx
.L2649:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2650
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2651
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
jmp .L2652
.L2651:
movq %r14,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i97
call rt_abort
.Lopt11_i97:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i97
xorq %rax,%rax
jmp .Lret_i97
.Lret_i97:
movq %rax,%r12
movq %r15,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i98
call rt_abort
.Lopt11_i98:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i98
xorq %rax,%rax
jmp .Lret_i98
.Lret_i98:
movq %rax,%r13
.L2652:
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
jne .L2653
movabsq $0,%rax
movq -.F2646-8(%rbp),%rbx
movq -.F2646-16(%rbp),%r12
movq -.F2646-24(%rbp),%r13
movq -.F2646-32(%rbp),%r14
movq -.F2646-40(%rbp),%r15
leave
ret
jmp .L2654
.L2653:
.L2654:
movq %rbx,%rax
addq $1,%rax
jnc .L2655
call rt_abort
.L2655:
movq %rax,%rbx
jmp .L2649
.L2650:
movabsq $1,%rax
movq -.F2646-8(%rbp),%rbx
movq -.F2646-16(%rbp),%r12
movq -.F2646-24(%rbp),%r13
movq -.F2646-32(%rbp),%r14
movq -.F2646-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2646-8(%rbp),%rbx
movq -.F2646-16(%rbp),%r12
movq -.F2646-24(%rbp),%r13
movq -.F2646-32(%rbp),%r14
movq -.F2646-40(%rbp),%r15
leave
ret
.set .F2646,48
.type rt_vec_cmp4,@function
rt_vec_cmp4:
pushq %rbp
movq %rsp,%rbp
subq $.F2656,%rsp
subq $48,%rsp
movq %rbx,-.F2656-8(%rbp)
movq %r12,-.F2656-16(%rbp)
movq %r13,-.F2656-24(%rbp)
movq %r14,-.F2656-32(%rbp)
movq %r15,-.F2656-40(%rbp)
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
.L2657:
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
jz .L2658
movq -16(%rbp),%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%r14
cmpq %r14,%r13
je .L2659
cmpq %r14,%r13
jae .L2661
movq $0,%r12
jmp .L2662
.L2661:
movq $2,%r12
.L2662:
jmp .L2658
jmp .L2660
.L2659:
.L2660:
movq %rbx,%rax
addq $1,%rax
jnc .L2663
call rt_abort
.L2663:
movq %rax,%rbx
jmp .L2657
.L2658:
movabsq $1,%rcx
cmpq $1,%r12
jne .L2664
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2666
movq $0,%r12
jmp .L2667
.L2666:
.L2667:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2668
movq $2,%r12
jmp .L2669
.L2668:
.L2669:
jmp .L2665
.L2664:
.L2665:
movq -8(%rbp),%rdi
movq %r12,%rsi
call rt_order_result
movq -.F2656-8(%rbp),%rbx
movq -.F2656-16(%rbp),%r12
movq -.F2656-24(%rbp),%r13
movq -.F2656-32(%rbp),%r14
movq -.F2656-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2656-8(%rbp),%rbx
movq -.F2656-16(%rbp),%r12
movq -.F2656-24(%rbp),%r13
movq -.F2656-32(%rbp),%r14
movq -.F2656-40(%rbp),%r15
leave
ret
.set .F2656,48
.type rt_vec_set,@function
rt_vec_set:
pushq %rbp
movq %rsp,%rbp
subq $.F2670,%rsp
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
jnc .L2671
call rt_abort
.L2671:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2672
call rt_abort
.L2672:
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
.set .F2670,48
.type rt_vec_insert,@function
rt_vec_insert:
pushq %rbp
movq %rsp,%rbp
subq $.F2673,%rsp
subq $32,%rsp
movq %rbx,-.F2673-8(%rbp)
movq %r12,-.F2673-16(%rbp)
movq %r13,-.F2673-24(%rbp)
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
jae .L2674
call rt_abort
jmp .L2675
.L2674:
.L2675:
movq %r12,%rdi
movabsq $0,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt243
call rt_push
jmp .Lopt244
.Lopt243:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt244:
movq -32(%rbp),%rax
movq %rax,%rbx
.L2676:
movq %rbx,%rcx
cmpq %rbx,%r13
jae .L2677
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2678
call rt_abort
.L2678:
movq %r12,%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i99
call rt_abort
.Lopt11_i99:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i99
xorq %rax,%rax
jmp .Lret_i99
.Lret_i99:
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_set
movq %rbx,%rax
subq $1,%rax
jnc .L2679
call rt_abort
.L2679:
movq %rax,%rbx
jmp .L2676
.L2677:
movq -24(%rbp),%rax
movq %r12,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_vec_set
movabsq $0,%rax
movq -.F2673-8(%rbp),%rbx
movq -.F2673-16(%rbp),%r12
movq -.F2673-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2673-8(%rbp),%rbx
movq -.F2673-16(%rbp),%r12
movq -.F2673-24(%rbp),%r13
leave
ret
.set .F2673,32
.type rt_vec_remove,@function
rt_vec_remove:
pushq %rbp
movq %rsp,%rbp
subq $.F2680,%rsp
subq $32,%rsp
movq %rbx,-.F2680-8(%rbp)
movq %r12,-.F2680-16(%rbp)
movq %r13,-.F2680-24(%rbp)
movq %r14,-.F2680-32(%rbp)
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
jne .L2681
call rt_abort
jmp .L2682
.L2681:
.L2682:
movq %r12,%rdi
movq %r14,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i100
call rt_abort
.Lopt11_i100:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i100
xorq %rax,%rax
jmp .Lret_i100
.Lret_i100:
movq %rax,-32(%rbp)
movq %r14,%rbx
.L2683:
movq %rbx,%rax
addq $1,%rax
jnc .L2685
call rt_abort
.L2685:
movq %r13,%rcx
cmpq %r13,%rax
jae .L2684
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2686
call rt_abort
.L2686:
movq %r12,%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i101
call rt_abort
.Lopt11_i101:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i101
xorq %rax,%rax
jmp .Lret_i101
.Lret_i101:
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_set
movq %rbx,%rax
addq $1,%rax
jnc .L2687
call rt_abort
.L2687:
movq %rax,%rbx
jmp .L2683
.L2684:
movq %r12,%rdi
call rt_pop
movq -32(%rbp),%rax
movq -.F2680-8(%rbp),%rbx
movq -.F2680-16(%rbp),%r12
movq -.F2680-24(%rbp),%r13
movq -.F2680-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2680-8(%rbp),%rbx
movq -.F2680-16(%rbp),%r12
movq -.F2680-24(%rbp),%r13
movq -.F2680-32(%rbp),%r14
leave
ret
.set .F2680,32
.type rt_vec_swap,@function
rt_vec_swap:
pushq %rbp
movq %rsp,%rbp
subq $.F2688,%rsp
subq $32,%rsp
movq %rbx,-.F2688-8(%rbp)
movq %r12,-.F2688-16(%rbp)
movq %r13,-.F2688-24(%rbp)
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
jnc .L2689
call rt_abort
.L2689:
testq %rax,%rax
jz .L2690
call rt_abort
jmp .L2691
.L2690:
.L2691:
movq %rbx,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i102
call rt_abort
.Lopt11_i102:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i102
xorq %rax,%rax
jmp .Lret_i102
.Lret_i102:
movq %rax,-64(%rbp)
movq %rbx,%rdi
movq %r13,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i103
call rt_abort
.Lopt11_i103:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i103
xorq %rax,%rax
jmp .Lret_i103
.Lret_i103:
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
movq -.F2688-8(%rbp),%rbx
movq -.F2688-16(%rbp),%r12
movq -.F2688-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2688-8(%rbp),%rbx
movq -.F2688-16(%rbp),%r12
movq -.F2688-24(%rbp),%r13
leave
ret
.set .F2688,64
.type rt_vec_reverse,@function
rt_vec_reverse:
pushq %rbp
movq %rsp,%rbp
subq $.F2692,%rsp
subq $32,%rsp
movq %rbx,-.F2692-8(%rbp)
movq %r12,-.F2692-16(%rbp)
movq %r13,-.F2692-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
movq $0,%rbx
.L2693:
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2694
movq %r12,%rax
subq $1,%rax
jnc .L2695
call rt_abort
.L2695:
movq %rbx,%rcx
subq %rbx,%rax
jnc .L2696
call rt_abort
.L2696:
movq %r13,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_swap
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2697
call rt_abort
.L2697:
movq %rax,%rbx
jmp .L2693
.L2694:
movabsq $0,%rax
movq -.F2692-8(%rbp),%rbx
movq -.F2692-16(%rbp),%r12
movq -.F2692-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2692-8(%rbp),%rbx
movq -.F2692-16(%rbp),%r12
movq -.F2692-24(%rbp),%r13
leave
ret
.set .F2692,16
.type rt_vec_truncate,@function
rt_vec_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F2698,%rsp
subq $32,%rsp
movq %rbx,-.F2698-8(%rbp)
movq %r12,-.F2698-16(%rbp)
movq %r13,-.F2698-24(%rbp)
movq %r14,-.F2698-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%rbx
movq %rsi,%r14
movq %rdx,%r12
movq $0,-32(%rbp)
.L2699:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
cmpq %rcx,%r14
jae .L2700
movq %rbx,%rdi
call rt_pop
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%r12
je .L2701
movq %r13,%rdi
movabsq $0,%rsi
movq %r12,%rax
call *%rax
jmp .L2702
.L2701:
.L2702:
jmp .L2699
.L2700:
movabsq $0,%rax
movq -.F2698-8(%rbp),%rbx
movq -.F2698-16(%rbp),%r12
movq -.F2698-24(%rbp),%r13
movq -.F2698-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2698-8(%rbp),%rbx
movq -.F2698-16(%rbp),%r12
movq -.F2698-24(%rbp),%r13
movq -.F2698-32(%rbp),%r14
leave
ret
.set .F2698,32
.type rt_vec_contains,@function
rt_vec_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F2703,%rsp
subq $32,%rsp
movq %rbx,-.F2703-8(%rbp)
movq %r12,-.F2703-16(%rbp)
movq %r13,-.F2703-24(%rbp)
movq %r14,-.F2703-32(%rbp)
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
.L2704:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L2705
movq %r12,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11_i104
call rt_abort
.Lopt11_i104:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i104
xorq %rax,%rax
jmp .Lret_i104
.Lret_i104:
cmpq %r13,%rax
jne .L2706
movabsq $1,%rax
movq -.F2703-8(%rbp),%rbx
movq -.F2703-16(%rbp),%r12
movq -.F2703-24(%rbp),%r13
movq -.F2703-32(%rbp),%r14
leave
ret
jmp .L2707
.L2706:
.L2707:
movq %rbx,%rax
addq $1,%rax
jnc .L2708
call rt_abort
.L2708:
movq %rax,%rbx
jmp .L2704
.L2705:
movabsq $0,%rax
movq -.F2703-8(%rbp),%rbx
movq -.F2703-16(%rbp),%r12
movq -.F2703-24(%rbp),%r13
movq -.F2703-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2703-8(%rbp),%rbx
movq -.F2703-16(%rbp),%r12
movq -.F2703-24(%rbp),%r13
movq -.F2703-32(%rbp),%r14
leave
ret
.set .F2703,16
.type rt_syscall,@function
rt_syscall:
pushq %rbp
movq %rsp,%rbp
subq $.F2709,%rsp
subq $32,%rsp
movq %rbx,-.F2709-8(%rbp)
movq %r12,-.F2709-16(%rbp)
movq %r13,-.F2709-24(%rbp)
movq %r14,-.F2709-32(%rbp)
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
jne .L2710
movq %rbx,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2711
.L2710:
.L2711:
movabsq $0,%rcx
cmpq $0,%rbx
jne .L2712
movabsq $63,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2713
.L2712:
.L2713:
movabsq $1,%rcx
cmpq $1,%rbx
jne .L2714
movabsq $64,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2715
.L2714:
.L2715:
cmpq $2,%rbx
jne .L2716
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
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2717
.L2716:
.L2717:
movabsq $3,%rcx
cmpq $3,%rbx
jne .L2718
movabsq $57,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2719
.L2718:
.L2719:
movabsq $11,%rcx
cmpq $11,%rbx
jne .L2720
movabsq $215,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2721
.L2720:
.L2721:
movabsq $27,%rcx
cmpq $27,%rbx
jne .L2722
movabsq $232,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2723
.L2722:
.L2723:
movabsq $39,%rcx
cmpq $39,%rbx
jne .L2724
movabsq $172,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2725
.L2724:
.L2725:
movabsq $57,%rcx
cmpq $57,%rbx
jne .L2726
movabsq $220,%rax
movabsq $17,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2727
.L2726:
.L2727:
movabsq $202,%rcx
cmpq $202,%rbx
jne .L2728
movabsq $98,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2729
.L2728:
.L2729:
movabsq $10,%rcx
cmpq $10,%rbx
jne .L2730
movabsq $226,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2731
.L2730:
.L2731:
movabsq $204,%rcx
cmpq $204,%rbx
jne .L2732
movabsq $123,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2733
.L2732:
.L2733:
movabsq $231,%rcx
cmpq $231,%rbx
jne .L2734
movabsq $94,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2735
.L2734:
.L2735:
movabsq $291,%rcx
cmpq $291,%rbx
jne .L2736
movabsq $20,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2737
.L2736:
.L2737:
movabsq $283,%rcx
cmpq $283,%rbx
jne .L2738
movabsq $85,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2739
.L2738:
.L2739:
movabsq $293,%rcx
cmpq $293,%rbx
jne .L2740
movabsq $59,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2741
.L2740:
.L2741:
movabsq $271,%rcx
cmpq $271,%rbx
jne .L2742
movabsq $73,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2743
.L2742:
.L2743:
movabsq $228,%rcx
cmpq $228,%rbx
jne .L2744
movabsq $113,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2745
.L2744:
.L2745:
movabsq $35,%rcx
cmpq $35,%rbx
jne .L2746
movabsq $101,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2747
.L2746:
.L2747:
movabsq $290,%rcx
cmpq $290,%rbx
jne .L2748
movabsq $19,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2749
.L2748:
.L2749:
movabsq $263,%rcx
cmpq $263,%rbx
jne .L2750
movabsq $35,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2751
.L2750:
.L2751:
movabsq $217,%rcx
cmpq $217,%rbx
jne .L2752
movabsq $61,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2753
.L2752:
.L2753:
movabsq $41,%rcx
cmpq $41,%rbx
jne .L2754
movabsq $198,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2755
.L2754:
.L2755:
movabsq $49,%rcx
cmpq $49,%rbx
jne .L2756
movabsq $200,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2757
.L2756:
.L2757:
movabsq $50,%rcx
cmpq $50,%rbx
jne .L2758
movabsq $201,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2759
.L2758:
.L2759:
movabsq $42,%rcx
cmpq $42,%rbx
jne .L2760
movabsq $203,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2761
.L2760:
.L2761:
movabsq $51,%rcx
cmpq $51,%rbx
jne .L2762
movabsq $204,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2763
.L2762:
.L2763:
movabsq $258,%rcx
cmpq $258,%rbx
jne .L2764
movabsq $34,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2765
.L2764:
.L2765:
movabsq $59,%rcx
cmpq $59,%rbx
jne .L2766
movabsq $221,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2767
.L2766:
.L2767:
movabsq $60,%rcx
cmpq $60,%rbx
jne .L2768
movabsq $93,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2769
.L2768:
.L2769:
movabsq $61,%rcx
cmpq $61,%rbx
jne .L2770
movabsq $260,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2771
.L2770:
.L2771:
movabsq $62,%rcx
cmpq $62,%rbx
jne .L2772
movabsq $129,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
jmp .L2773
.L2772:
.L2773:
movabsq $0,%rax
subq $38,%rax
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2709-8(%rbp),%rbx
movq -.F2709-16(%rbp),%r12
movq -.F2709-24(%rbp),%r13
movq -.F2709-32(%rbp),%r14
leave
ret
.set .F2709,48
.type rt_syscall4,@function
rt_syscall4:
pushq %rbp
movq %rsp,%rbp
subq $.F2774,%rsp
subq $48,%rsp
movq %rbx,-.F2774-8(%rbp)
movq %r12,-.F2774-16(%rbp)
movq %r13,-.F2774-24(%rbp)
movq %r14,-.F2774-32(%rbp)
movq %r15,-.F2774-40(%rbp)
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
jne .L2775
movq %rbx,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
jmp .L2776
.L2775:
.L2776:
movabsq $233,%rcx
cmpq $233,%rbx
jne .L2777
movabsq $21,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
jmp .L2778
.L2777:
.L2778:
movabsq $281,%rcx
cmpq $281,%rbx
jne .L2779
movabsq $22,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
jmp .L2780
.L2779:
.L2780:
movabsq $286,%rcx
cmpq $286,%rbx
jne .L2781
movabsq $86,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
jmp .L2782
.L2781:
.L2782:
movabsq $25,%rcx
cmpq $25,%rbx
jne .L2783
movabsq $216,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
jmp .L2784
.L2783:
.L2784:
movabsq $0,%rax
subq $38,%rax
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2774-8(%rbp),%rbx
movq -.F2774-16(%rbp),%r12
movq -.F2774-24(%rbp),%r13
movq -.F2774-32(%rbp),%r14
movq -.F2774-40(%rbp),%r15
leave
ret
.set .F2774,48
.type rt_readlinkat,@function
rt_readlinkat:
pushq %rbp
movq %rsp,%rbp
subq $.F2785,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $0,%rax
cmpq $0,%rax
jne .L2786
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
jmp .L2787
.L2786:
.L2787:
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
.set .F2785,48
.type rt_faccessat,@function
rt_faccessat:
pushq %rbp
movq %rsp,%rbp
subq $.F2788,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $0,%rax
cmpq $0,%rax
jne .L2789
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
jmp .L2790
.L2789:
.L2790:
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
.set .F2788,32
.type rt_accept4,@function
rt_accept4:
pushq %rbp
movq %rsp,%rbp
subq $.F2791,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $0,%rcx
movabsq $0,%rax
cmpq $0,%rax
jne .L2792
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
jmp .L2793
.L2792:
.L2793:
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
.set .F2791,16
.type rt_os_init,@function
rt_os_init:
pushq %rbp
movq %rsp,%rbp
subq $.F2794,%rsp
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2794,16
.type f_core_some$0,@function
f_core_some$0:
pushq %rbp
movq %rsp,%rbp
subq $.F2930,%rsp
subq $32,%rsp
movq %rbx,-.F2930-8(%rbp)
movq %r12,-.F2930-16(%rbp)
movq %r13,-.F2930-24(%rbp)
movq %r14,-.F2930-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r14
movq $0,-16(%rbp)
movq $0,%r12
movabsq $1,%rdi
movq %r14,%rsi
call rt_enum
movq %rax,%r13
movq $0,%rbx
cmpq $0,%rbx
je .L2931
movq %r13,%rdi
call .D30
.L2931:
cmpq $0,%r12
je .L2932
movq %r14,%rdi
call .D29
.L2932:
movq %r13,%rax
movq -.F2930-8(%rbp),%rbx
movq -.F2930-16(%rbp),%r12
movq -.F2930-24(%rbp),%r13
movq -.F2930-32(%rbp),%r14
leave
ret
cmpq $0,%rbx
je .L2933
movq $0,%rbx
movq %r13,%rdi
call .D30
.L2933:
cmpq $0,%rbx
je .L2934
movq $0,%rbx
movq %r13,%rdi
call .D30
.L2934:
cmpq $0,%rbx
je .L2935
movq %r13,%rdi
call .D30
.L2935:
cmpq $0,%r12
je .L2936
movq %r14,%rdi
call .D29
.L2936:
xorq %rax,%rax
movq -.F2930-8(%rbp),%rbx
movq -.F2930-16(%rbp),%r12
movq -.F2930-24(%rbp),%r13
movq -.F2930-32(%rbp),%r14
leave
ret
.set .F2930,16
.D2:
testq %rdi,%rdi
jz .L2937
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_drop_seq
popq %r13
popq %r12
leave
.L2937:
ret
.D3:
testq %rdi,%rdi
jz .L2938
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_drop_seq
popq %r13
popq %r12
leave
.L2938:
ret
.D4:
testq %rdi,%rdi
jz .L2939
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L2939:
ret
.D5:
testq %rdi,%rdi
jz .L2940
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
xorq %r13,%r13
.L2941:
cmpq 8(%r12),%r13
jae .L2942
movq (%r12),%rax
movq (%rax,%r13,8),%rdi
call .D2
incq %r13
jmp .L2941
.L2942:
movq %r12,%rdi
call rt_drop_seq
popq %r13
popq %r12
leave
.L2940:
ret
.D6:
testq %rdi,%rdi
jz .L2943
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
.L2943:
ret
.D7:
testq %rdi,%rdi
jz .L2944
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
movq 0(%r12),%rdi
call .D3
movq %r12,%rdi
call rt_free
popq %r13
popq %r12
leave
.L2944:
ret
.D8:
testq %rdi,%rdi
jz .L2945
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
xorq %r13,%r13
.L2946:
cmpq 8(%r12),%r13
jae .L2947
movq (%r12),%rax
movq (%rax,%r13,8),%rdi
call .D7
incq %r13
jmp .L2946
.L2947:
movq %r12,%rdi
call rt_drop_seq
popq %r13
popq %r12
leave
.L2945:
ret
.D11:
testq %rdi,%rdi
jz .L2948
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L2948:
ret
.D12:
testq %rdi,%rdi
jz .L2949
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
.L2949:
ret
.D29:
testq %rdi,%rdi
jz .L2950
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
popq %r13
popq %r12
leave
.L2950:
ret
.D30:
testq %rdi,%rdi
jz .L2951
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
cmpq $1,(%r12)
jne .L2952
movq 8(%r12),%rdi
call .D29
.L2952:
movq %r12,%rdi
call rt_free
popq %r13
popq %r12
leave
.L2951:
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
jz .L2953
call rt_abort
.L2953:
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
