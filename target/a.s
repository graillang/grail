.text
.type f_main_takes,@function
f_main_takes:
pushq %rbp
movq %rsp,%rbp
subq $.F1,%rsp
subq $16,%rsp
movq %rbx,-.F1-8(%rbp)
movq %r12,-.F1-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq $0,-16(%rbp)
movq $1,%rbx
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,-16(%rbp)
cmpq $0,%rbx
je .L2
movq %r12,%rdi
call .D8
.L2:
movq -16(%rbp),%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
leave
ret
cmpq $0,%rbx
je .L3
movq $0,%rbx
movq %r12,%rdi
call .D8
.L3:
cmpq $0,%rbx
je .L4
movq %r12,%rdi
call .D8
.L4:
xorq %rax,%rax
movq -.F1-8(%rbp),%rbx
movq -.F1-16(%rbp),%r12
leave
ret
.set .F1,16
.type f_main_main,@function
f_main_main:
pushq %rbp
movq %rsp,%rbp
subq $.F5,%rsp
subq $48,%rsp
movq %rbx,-.F5-8(%rbp)
movq %r12,-.F5-16(%rbp)
movq %r13,-.F5-24(%rbp)
movq %r14,-.F5-32(%rbp)
movq %r15,-.F5-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
leaq -.F5(%rbp),%rdi
movq $.F5/8-0,%rcx
xorl %eax,%eax
rep stosq
.pushsection .rodata
.L6:
.byte 104
.byte 101
.byte 108
.byte 108
.byte 111
.byte 0
.popsection
leaq .L6(%rip),%rax
movq %rax,-8(%rbp)
movq %rax,%rdi
movabsq $5,%rsi
call rt_string_lit
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movq $0,%r13
movq $1,-32(%rbp)
cmpq $0,%r13
je .L7
movq $0,%r13
movq -16(%rbp),%rdi
call .D3
.L7:
leaq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,-40(%rbp)
movq %rax,-48(%rbp)
movq $0,%r14
movq $0,%r15
movq %rax,%rdi
call f_main_takes
movq %rax,-56(%rbp)
cmpq $0,%r15
je .L8
movq $0,%r15
movq -48(%rbp),%rdi
call .D4
.L8:
cmpq $0,%r14
je .L9
movq $0,%r14
movq -40(%rbp),%rdi
call .D4
.L9:
movq -56(%rbp),%rdi
movabsq $0,%rsi
call rt_print_number
call rt_new
movq %rax,-64(%rbp)
movq $1,-72(%rbp)
movq %rax,%rdi
movabsq $3,%rsi
movabsq $2,%rdx
call rt_fill
movq -64(%rbp),%rax
movq %rax,-80(%rbp)
movq $0,-72(%rbp)
movq $1,-88(%rbp)
cmpq $0,-72(%rbp)
je .L10
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D6
.L10:
leaq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-96(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-104(%rbp)
movq $0,%rbx
.L11:
movq -104(%rbp),%rcx
cmpq %rcx,%rbx
jae .L13
movq -96(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt1
call rt_abort
.Lopt1:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
movq %rax,-112(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.L12:
incq %rbx
jmp .L11
.L13:
.pushsection .rodata
.balign 8
.L14:
.quad 4612811918334230528
.popsection
leaq .L14(%rip),%rax
movq (%rax),%rax
movq %rax,-120(%rbp)
movq %rax,%rdi
call rt_f64_round
movq %rax,-128(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_f64
movq -120(%rbp),%rdi
movq $0,%r9
movq $0,%r10
movq %rdi,%r8
movabsq $63,%rax
cmpq $52,%rax
jnc .L2219_i1
call rt_abort
.L2219_i1:
movabsq $52,%rcx
movq %r8,%rax
shrq %cl,%rax
movq %rax,%r9
movq %r9,%rax
andq $2047,%rax
movq %rax,%r10
movq %r10,%rax
cmpq $2047,%rax
setne %al
movzbq %al,%rax
jmp .Lret_i1
xorq %rax,%rax
jmp .Lret_i1
.Lret_i1:
movq %rax,-136(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_bool
call rt_new
movq %rax,-144(%rbp)
movq %rax,%rdi
movq -56(%rbp),%rsi
call rt_fmt_num
.pushsection .rodata
.L15:
.byte 32
.popsection
leaq .L15(%rip),%rax
movq %rax,-152(%rbp)
movq -144(%rbp),%rdi
movq %rax,%rsi
movabsq $1,%rdx
call rt_fmt_raw
movq -144(%rbp),%rdi
movq -120(%rbp),%rsi
call rt_fmt_f64
movq -144(%rbp),%rdi
call rt_fmt_finish
movq %rax,-160(%rbp)
movq $1,%r12
movq %rax,%rdi
call rt_view
movq %rax,-168(%rbp)
movq $1,-176(%rbp)
movq $0,-176(%rbp)
movq %rax,%rdi
call f_host_print
cmpq $0,%r12
je .L16
movq $0,%r12
movq -160(%rbp),%rdi
call .D3
.L16:
cmpq $0,-176(%rbp)
je .L17
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L17:
cmpq $0,%r12
je .L18
movq $0,%r12
movq -160(%rbp),%rdi
call .D3
.L18:
.pushsection .rodata
.L19:
.byte 97
.byte 44
.byte 98
.byte 0
.popsection
leaq .L19(%rip),%rax
movq %rax,-184(%rbp)
movq %rax,%rdi
movabsq $3,%rsi
call rt_string_lit
movq %rax,-192(%rbp)
movq $1,-200(%rbp)
movq %rax,-208(%rbp)
movq $0,-200(%rbp)
movq $1,-216(%rbp)
leaq -208(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,-224(%rbp)
movq $1,-232(%rbp)
movq %rax,-240(%rbp)
movq $0,-232(%rbp)
movq $1,-248(%rbp)
movq $0,-248(%rbp)
movq %rax,%rdi
movabsq $44,%rsi
call f_strings_split
movq %rax,-256(%rbp)
movq $1,-264(%rbp)
movq %rax,-272(%rbp)
movq $0,-264(%rbp)
movq $1,-280(%rbp)
cmpq $0,-264(%rbp)
je .L20
movq $0,-264(%rbp)
movq -256(%rbp),%rdi
call .D5
.L20:
cmpq $0,-248(%rbp)
je .L21
movq $0,-248(%rbp)
movq -240(%rbp),%rdi
call .D4
.L21:
cmpq $0,-232(%rbp)
je .L22
movq $0,-232(%rbp)
movq -224(%rbp),%rdi
call .D4
.L22:
cmpq $0,-200(%rbp)
je .L23
movq $0,-200(%rbp)
movq -192(%rbp),%rdi
call .D3
.L23:
movq -272(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-288(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
call rt_print_number
.pushsection .rodata
.L24:
.byte 52
.byte 50
.byte 0
.popsection
leaq .L24(%rip),%rax
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
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,-336(%rbp)
movq $1,-344(%rbp)
movq %rax,-352(%rbp)
movq $0,-344(%rbp)
movq $1,-360(%rbp)
movq $0,-360(%rbp)
movq %rax,%rdi
call f_strings_parse_num
movq %rax,-368(%rbp)
movq $1,-376(%rbp)
movq 0(%rax),%rax
movq %rax,-384(%rbp)
movq $0,-376(%rbp)
cmpq $1,%rax
jne .L26
movq -368(%rbp),%rax
movq 8(%rax),%rax
movq %rax,-392(%rbp)
movq -368(%rbp),%rdi
call rt_free
movq -392(%rbp),%rdi
movabsq $0,%rsi
call rt_print_number
jmp .L25
.L26:
movq -384(%rbp),%rax
cmpq $0,%rax
jne .L27
movq -368(%rbp),%rdi
call rt_free
movabsq $0,%rdi
movabsq $0,%rsi
call rt_print_number
jmp .L25
.L27:
call rt_abort
.L25:
cmpq $0,-376(%rbp)
je .L28
movq $0,-376(%rbp)
movq -368(%rbp),%rdi
call .D19
.L28:
cmpq $0,-360(%rbp)
je .L29
movq $0,-360(%rbp)
movq -352(%rbp),%rdi
call .D4
.L29:
cmpq $0,-344(%rbp)
je .L30
movq $0,-344(%rbp)
movq -336(%rbp),%rdi
call .D4
.L30:
cmpq $0,-312(%rbp)
je .L31
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L31:
movq $0,-400(%rbp)
cmpq $0,-376(%rbp)
je .L32
movq $0,-376(%rbp)
movq -368(%rbp),%rdi
call .D19
.L32:
cmpq $0,-360(%rbp)
je .L33
movq $0,-360(%rbp)
movq -352(%rbp),%rdi
call .D4
.L33:
cmpq $0,-344(%rbp)
je .L34
movq $0,-344(%rbp)
movq -336(%rbp),%rdi
call .D4
.L34:
cmpq $0,-328(%rbp)
je .L35
movq $0,-328(%rbp)
movq -320(%rbp),%rdi
call .D3
.L35:
cmpq $0,-312(%rbp)
je .L36
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L36:
cmpq $0,-280(%rbp)
je .L37
movq $0,-280(%rbp)
movq -272(%rbp),%rdi
call .D5
.L37:
cmpq $0,-264(%rbp)
je .L38
movq $0,-264(%rbp)
movq -256(%rbp),%rdi
call .D5
.L38:
cmpq $0,-248(%rbp)
je .L39
movq $0,-248(%rbp)
movq -240(%rbp),%rdi
call .D4
.L39:
cmpq $0,-232(%rbp)
je .L40
movq $0,-232(%rbp)
movq -224(%rbp),%rdi
call .D4
.L40:
cmpq $0,-216(%rbp)
je .L41
movq $0,-216(%rbp)
movq -208(%rbp),%rdi
call .D3
.L41:
cmpq $0,-200(%rbp)
je .L42
movq $0,-200(%rbp)
movq -192(%rbp),%rdi
call .D3
.L42:
cmpq $0,-176(%rbp)
je .L43
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L43:
cmpq $0,%r12
je .L44
movq -160(%rbp),%rdi
call .D3
.L44:
cmpq $0,-88(%rbp)
je .L45
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D6
.L45:
cmpq $0,-72(%rbp)
je .L46
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D6
.L46:
cmpq $0,%r15
je .L47
movq -48(%rbp),%rdi
call .D4
.L47:
cmpq $0,%r14
je .L48
movq -40(%rbp),%rdi
call .D4
.L48:
cmpq $0,-32(%rbp)
je .L49
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D3
.L49:
cmpq $0,%r13
je .L50
movq -16(%rbp),%rdi
call .D3
.L50:
movq -400(%rbp),%rax
movq -.F5-8(%rbp),%rbx
movq -.F5-16(%rbp),%r12
movq -.F5-24(%rbp),%r13
movq -.F5-32(%rbp),%r14
movq -.F5-40(%rbp),%r15
leave
ret
cmpq $0,-376(%rbp)
je .L51
movq $0,-376(%rbp)
movq -368(%rbp),%rdi
call .D19
.L51:
cmpq $0,-360(%rbp)
je .L52
movq $0,-360(%rbp)
movq -352(%rbp),%rdi
call .D4
.L52:
cmpq $0,-344(%rbp)
je .L53
movq $0,-344(%rbp)
movq -336(%rbp),%rdi
call .D4
.L53:
cmpq $0,-328(%rbp)
je .L54
movq $0,-328(%rbp)
movq -320(%rbp),%rdi
call .D3
.L54:
cmpq $0,-312(%rbp)
je .L55
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L55:
cmpq $0,-280(%rbp)
je .L56
movq $0,-280(%rbp)
movq -272(%rbp),%rdi
call .D5
.L56:
cmpq $0,-264(%rbp)
je .L57
movq $0,-264(%rbp)
movq -256(%rbp),%rdi
call .D5
.L57:
cmpq $0,-248(%rbp)
je .L58
movq $0,-248(%rbp)
movq -240(%rbp),%rdi
call .D4
.L58:
cmpq $0,-232(%rbp)
je .L59
movq $0,-232(%rbp)
movq -224(%rbp),%rdi
call .D4
.L59:
cmpq $0,-216(%rbp)
je .L60
movq $0,-216(%rbp)
movq -208(%rbp),%rdi
call .D3
.L60:
cmpq $0,-200(%rbp)
je .L61
movq $0,-200(%rbp)
movq -192(%rbp),%rdi
call .D3
.L61:
cmpq $0,-176(%rbp)
je .L62
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L62:
cmpq $0,%r12
je .L63
movq $0,%r12
movq -160(%rbp),%rdi
call .D3
.L63:
cmpq $0,-88(%rbp)
je .L64
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D6
.L64:
cmpq $0,-72(%rbp)
je .L65
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D6
.L65:
cmpq $0,%r15
je .L66
movq $0,%r15
movq -48(%rbp),%rdi
call .D4
.L66:
cmpq $0,%r14
je .L67
movq $0,%r14
movq -40(%rbp),%rdi
call .D4
.L67:
cmpq $0,-32(%rbp)
je .L68
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D3
.L68:
cmpq $0,%r13
je .L69
movq $0,%r13
movq -16(%rbp),%rdi
call .D3
.L69:
cmpq $0,-376(%rbp)
je .L70
movq $0,-376(%rbp)
movq -368(%rbp),%rdi
call .D19
.L70:
cmpq $0,-360(%rbp)
je .L71
movq $0,-360(%rbp)
movq -352(%rbp),%rdi
call .D4
.L71:
cmpq $0,-344(%rbp)
je .L72
movq $0,-344(%rbp)
movq -336(%rbp),%rdi
call .D4
.L72:
cmpq $0,-328(%rbp)
je .L73
movq $0,-328(%rbp)
movq -320(%rbp),%rdi
call .D3
.L73:
cmpq $0,-312(%rbp)
je .L74
movq $0,-312(%rbp)
movq -304(%rbp),%rdi
call .D3
.L74:
cmpq $0,-280(%rbp)
je .L75
movq $0,-280(%rbp)
movq -272(%rbp),%rdi
call .D5
.L75:
cmpq $0,-264(%rbp)
je .L76
movq $0,-264(%rbp)
movq -256(%rbp),%rdi
call .D5
.L76:
cmpq $0,-248(%rbp)
je .L77
movq $0,-248(%rbp)
movq -240(%rbp),%rdi
call .D4
.L77:
cmpq $0,-232(%rbp)
je .L78
movq $0,-232(%rbp)
movq -224(%rbp),%rdi
call .D4
.L78:
cmpq $0,-216(%rbp)
je .L79
movq $0,-216(%rbp)
movq -208(%rbp),%rdi
call .D3
.L79:
cmpq $0,-200(%rbp)
je .L80
movq $0,-200(%rbp)
movq -192(%rbp),%rdi
call .D3
.L80:
cmpq $0,-176(%rbp)
je .L81
movq $0,-176(%rbp)
movq -168(%rbp),%rdi
call .D4
.L81:
cmpq $0,%r12
je .L82
movq -160(%rbp),%rdi
call .D3
.L82:
cmpq $0,-88(%rbp)
je .L83
movq $0,-88(%rbp)
movq -80(%rbp),%rdi
call .D6
.L83:
cmpq $0,-72(%rbp)
je .L84
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D6
.L84:
cmpq $0,%r15
je .L85
movq -48(%rbp),%rdi
call .D4
.L85:
cmpq $0,%r14
je .L86
movq -40(%rbp),%rdi
call .D4
.L86:
cmpq $0,-32(%rbp)
je .L87
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D3
.L87:
cmpq $0,%r13
je .L88
movq -16(%rbp),%rdi
call .D3
.L88:
xorq %rax,%rax
movq -.F5-8(%rbp),%rbx
movq -.F5-16(%rbp),%r12
movq -.F5-24(%rbp),%r13
movq -.F5-32(%rbp),%r14
movq -.F5-40(%rbp),%r15
leave
ret
.set .F5,400
.type f_strings_starts_with,@function
f_strings_starts_with:
pushq %rbp
movq %rsp,%rbp
subq $.F89,%rsp
subq $48,%rsp
movq %rbx,-.F89-8(%rbp)
movq %r12,-.F89-16(%rbp)
movq %r13,-.F89-24(%rbp)
movq %r14,-.F89-32(%rbp)
movq %r15,-.F89-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r13
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $1,%rbx
movq $1,%r12
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -24(%rbp),%rax
cmpq %rcx,%rax
jae .L90
movq $0,-32(%rbp)
cmpq $0,%r12
je .L92
movq %r13,%rdi
call .D18
.L92:
cmpq $0,%rbx
je .L93
movq %r14,%rdi
call .D8
.L93:
movq -32(%rbp),%rax
movq -.F89-8(%rbp),%rbx
movq -.F89-16(%rbp),%r12
movq -.F89-24(%rbp),%r13
movq -.F89-32(%rbp),%r14
movq -.F89-40(%rbp),%r15
leave
ret
jmp .L91
.L90:
.L91:
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq $0,%r15
.L94:
movq -40(%rbp),%rcx
cmpq %rcx,%r15
jae .L96
movq %r14,%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt2
call rt_abort
.Lopt2:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-48(%rbp)
movq %r13,%rdi
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
movq -48(%rbp),%rax
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
testq %rax,%rax
jz .L97
movq $0,-56(%rbp)
cmpq $0,%r12
je .L99
movq %r13,%rdi
call .D18
.L99:
cmpq $0,%rbx
je .L100
movq %r14,%rdi
call .D8
.L100:
movq -56(%rbp),%rax
movq -.F89-8(%rbp),%rbx
movq -.F89-16(%rbp),%r12
movq -.F89-24(%rbp),%r13
movq -.F89-32(%rbp),%r14
movq -.F89-40(%rbp),%r15
leave
ret
jmp .L98
.L97:
.L98:
.L95:
incq %r15
jmp .L94
.L96:
cmpq $0,%rbx
je .L101
movq $0,%rbx
movq %r14,%rdi
call .D8
.L101:
cmpq $0,%r12
je .L102
movq $0,%r12
movq %r13,%rdi
call .D18
.L102:
movq $1,-64(%rbp)
cmpq $0,%r12
je .L103
movq %r13,%rdi
call .D18
.L103:
cmpq $0,%rbx
je .L104
movq %r14,%rdi
call .D8
.L104:
movq -64(%rbp),%rax
movq -.F89-8(%rbp),%rbx
movq -.F89-16(%rbp),%r12
movq -.F89-24(%rbp),%r13
movq -.F89-32(%rbp),%r14
movq -.F89-40(%rbp),%r15
leave
ret
cmpq $0,%rbx
je .L105
movq $0,%rbx
movq %r14,%rdi
call .D8
.L105:
cmpq $0,%r12
je .L106
movq $0,%r12
movq %r13,%rdi
call .D18
.L106:
cmpq $0,%r12
je .L107
movq %r13,%rdi
call .D18
.L107:
cmpq $0,%rbx
je .L108
movq %r14,%rdi
call .D8
.L108:
xorq %rax,%rax
movq -.F89-8(%rbp),%rbx
movq -.F89-16(%rbp),%r12
movq -.F89-24(%rbp),%r13
movq -.F89-32(%rbp),%r14
movq -.F89-40(%rbp),%r15
leave
ret
.set .F89,64
.type f_strings_ends_with,@function
f_strings_ends_with:
pushq %rbp
movq %rsp,%rbp
subq $.F109,%rsp
subq $48,%rsp
movq %rbx,-.F109-8(%rbp)
movq %r12,-.F109-16(%rbp)
movq %r13,-.F109-24(%rbp)
movq %r14,-.F109-32(%rbp)
movq %r15,-.F109-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r14
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $1,%rbx
movq $1,%r12
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -24(%rbp),%rax
cmpq %rcx,%rax
jae .L110
movq $0,-32(%rbp)
cmpq $0,%r12
je .L112
movq %r14,%rdi
call .D18
.L112:
cmpq $0,%rbx
je .L113
movq %r13,%rdi
call .D8
.L113:
movq -32(%rbp),%rax
movq -.F109-8(%rbp),%rbx
movq -.F109-16(%rbp),%r12
movq -.F109-24(%rbp),%r13
movq -.F109-32(%rbp),%r14
movq -.F109-40(%rbp),%r15
leave
ret
jmp .L111
.L110:
.L111:
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -40(%rbp),%rax
subq %rcx,%rax
jnc .L114
call rt_abort
.L114:
movq %rax,-48(%rbp)
movq 8(%rdi),%rax
movq %rax,-56(%rbp)
movq $0,%r15
.L115:
movq -56(%rbp),%rcx
cmpq %rcx,%r15
jae .L117
movq -48(%rbp),%rax
addq %r15,%rax
jnc .L118
call rt_abort
.L118:
movq %r13,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt3
call rt_abort
.Lopt3:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-64(%rbp)
movq %r14,%rdi
movq %r15,%rsi
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
movq -64(%rbp),%rax
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
testq %rax,%rax
jz .L119
movq $0,-72(%rbp)
cmpq $0,%r12
je .L121
movq %r14,%rdi
call .D18
.L121:
cmpq $0,%rbx
je .L122
movq %r13,%rdi
call .D8
.L122:
movq -72(%rbp),%rax
movq -.F109-8(%rbp),%rbx
movq -.F109-16(%rbp),%r12
movq -.F109-24(%rbp),%r13
movq -.F109-32(%rbp),%r14
movq -.F109-40(%rbp),%r15
leave
ret
jmp .L120
.L119:
.L120:
.L116:
incq %r15
jmp .L115
.L117:
cmpq $0,%rbx
je .L123
movq $0,%rbx
movq %r13,%rdi
call .D8
.L123:
cmpq $0,%r12
je .L124
movq $0,%r12
movq %r14,%rdi
call .D18
.L124:
movq $1,-80(%rbp)
cmpq $0,%r12
je .L125
movq %r14,%rdi
call .D18
.L125:
cmpq $0,%rbx
je .L126
movq %r13,%rdi
call .D8
.L126:
movq -80(%rbp),%rax
movq -.F109-8(%rbp),%rbx
movq -.F109-16(%rbp),%r12
movq -.F109-24(%rbp),%r13
movq -.F109-32(%rbp),%r14
movq -.F109-40(%rbp),%r15
leave
ret
cmpq $0,%rbx
je .L127
movq $0,%rbx
movq %r13,%rdi
call .D8
.L127:
cmpq $0,%r12
je .L128
movq $0,%r12
movq %r14,%rdi
call .D18
.L128:
cmpq $0,%r12
je .L129
movq %r14,%rdi
call .D18
.L129:
cmpq $0,%rbx
je .L130
movq %r13,%rdi
call .D8
.L130:
xorq %rax,%rax
movq -.F109-8(%rbp),%rbx
movq -.F109-16(%rbp),%r12
movq -.F109-24(%rbp),%r13
movq -.F109-32(%rbp),%r14
movq -.F109-40(%rbp),%r15
leave
ret
.set .F109,80
.type f_strings_find,@function
f_strings_find:
pushq %rbp
movq %rsp,%rbp
subq $.F131,%rsp
subq $48,%rsp
movq %rbx,-.F131-8(%rbp)
movq %r12,-.F131-16(%rbp)
movq %r13,-.F131-24(%rbp)
movq %r14,-.F131-32(%rbp)
movq %r15,-.F131-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
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
movq $0,-120(%rbp)
movq $0,-128(%rbp)
movq $0,-136(%rbp)
movq $0,-144(%rbp)
movq $1,-24(%rbp)
movq $1,-32(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L132
movabsq $0,%rdi
call f_core_some$0
movq %rax,-48(%rbp)
movq $1,-56(%rbp)
movq $0,-56(%rbp)
cmpq $0,-56(%rbp)
je .L134
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L134:
cmpq $0,-32(%rbp)
je .L135
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L135:
cmpq $0,-24(%rbp)
je .L136
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L136:
movq -48(%rbp),%rax
movq -.F131-8(%rbp),%rbx
movq -.F131-16(%rbp),%r12
movq -.F131-24(%rbp),%r13
movq -.F131-32(%rbp),%r14
movq -.F131-40(%rbp),%r15
leave
ret
cmpq $0,-56(%rbp)
je .L137
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L137:
cmpq $0,-56(%rbp)
je .L138
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L138:
jmp .L133
.L132:
.L133:
cmpq $0,-56(%rbp)
je .L139
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L139:
movq -8(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-64(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -64(%rbp),%rax
cmpq %rcx,%rax
jae .L140
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,-72(%rbp)
movq $1,-80(%rbp)
movq $0,-80(%rbp)
cmpq $0,-80(%rbp)
je .L142
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L142:
cmpq $0,-56(%rbp)
je .L143
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L143:
cmpq $0,-32(%rbp)
je .L144
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L144:
cmpq $0,-24(%rbp)
je .L145
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L145:
movq -72(%rbp),%rax
movq -.F131-8(%rbp),%rbx
movq -.F131-16(%rbp),%r12
movq -.F131-24(%rbp),%r13
movq -.F131-32(%rbp),%r14
movq -.F131-40(%rbp),%r15
leave
ret
cmpq $0,-80(%rbp)
je .L146
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L146:
cmpq $0,-80(%rbp)
je .L147
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L147:
jmp .L141
.L140:
.L141:
cmpq $0,-80(%rbp)
je .L148
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L148:
movq -8(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-88(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq -88(%rbp),%rax
subq %rcx,%rax
jnc .L149
call rt_abort
.L149:
movq %rax,-96(%rbp)
addq $1,%rax
jnc .L150
call rt_abort
.L150:
movq %rax,-104(%rbp)
movq $0,-112(%rbp)
.L151:
movq -104(%rbp),%rcx
movq -112(%rbp),%rax
cmpq %rcx,%rax
jae .L153
movq $1,-120(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-128(%rbp)
movq $0,%r12
.L154:
movq -128(%rbp),%rcx
cmpq %rcx,%r12
jae .L156
movq -112(%rbp),%rax
addq %r12,%rax
jnc .L157
call rt_abort
.L157:
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt4
call rt_abort
.Lopt4:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r15
movq %r13,%rdi
movq %r12,%rsi
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r15
je .L158
movq $0,-120(%rbp)
jmp .L156
jmp .L159
.L158:
.L159:
.L155:
incq %r12
jmp .L154
.L156:
movq -120(%rbp),%rax
testq %rax,%rax
jz .L160
movq -112(%rbp),%rax
movq %rax,%rdi
call f_core_some$0
movq %rax,%r14
movq $0,%rbx
cmpq $0,%rbx
je .L162
movq %r14,%rdi
call .D19
.L162:
cmpq $0,-80(%rbp)
je .L163
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L163:
cmpq $0,-56(%rbp)
je .L164
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L164:
cmpq $0,-32(%rbp)
je .L165
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L165:
cmpq $0,-24(%rbp)
je .L166
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L166:
movq %r14,%rax
movq -.F131-8(%rbp),%rbx
movq -.F131-16(%rbp),%r12
movq -.F131-24(%rbp),%r13
movq -.F131-32(%rbp),%r14
movq -.F131-40(%rbp),%r15
leave
ret
cmpq $0,%rbx
je .L167
movq $0,%rbx
movq %r14,%rdi
call .D19
.L167:
cmpq $0,%rbx
je .L168
movq $0,%rbx
movq %r14,%rdi
call .D19
.L168:
jmp .L161
.L160:
.L161:
cmpq $0,%rbx
je .L169
movq $0,%rbx
movq %r14,%rdi
call .D19
.L169:
cmpq $0,%rbx
je .L170
movq $0,%rbx
movq %r14,%rdi
call .D19
.L170:
.L152:
incq -112(%rbp)
jmp .L151
.L153:
cmpq $0,%rbx
je .L171
movq $0,%rbx
movq %r14,%rdi
call .D19
.L171:
cmpq $0,-24(%rbp)
je .L172
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L172:
cmpq $0,-32(%rbp)
je .L173
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L173:
cmpq $0,%rbx
je .L174
movq $0,%rbx
movq %r14,%rdi
call .D19
.L174:
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,-136(%rbp)
movq $1,-144(%rbp)
movq $0,-144(%rbp)
cmpq $0,-144(%rbp)
je .L175
movq $0,-144(%rbp)
movq -136(%rbp),%rdi
call .D19
.L175:
cmpq $0,%rbx
je .L176
movq %r14,%rdi
call .D19
.L176:
cmpq $0,-80(%rbp)
je .L177
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L177:
cmpq $0,-56(%rbp)
je .L178
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L178:
cmpq $0,-32(%rbp)
je .L179
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L179:
cmpq $0,-24(%rbp)
je .L180
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L180:
movq -136(%rbp),%rax
movq -.F131-8(%rbp),%rbx
movq -.F131-16(%rbp),%r12
movq -.F131-24(%rbp),%r13
movq -.F131-32(%rbp),%r14
movq -.F131-40(%rbp),%r15
leave
ret
cmpq $0,-24(%rbp)
je .L181
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L181:
cmpq $0,-32(%rbp)
je .L182
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L182:
cmpq $0,-144(%rbp)
je .L183
movq $0,-144(%rbp)
movq -136(%rbp),%rdi
call .D19
.L183:
cmpq $0,-144(%rbp)
je .L184
movq $0,-144(%rbp)
movq -136(%rbp),%rdi
call .D19
.L184:
cmpq $0,%rbx
je .L185
movq $0,%rbx
movq %r14,%rdi
call .D19
.L185:
cmpq $0,-80(%rbp)
je .L186
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L186:
cmpq $0,-56(%rbp)
je .L187
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L187:
cmpq $0,-144(%rbp)
je .L188
movq $0,-144(%rbp)
movq -136(%rbp),%rdi
call .D19
.L188:
cmpq $0,%rbx
je .L189
movq %r14,%rdi
call .D19
.L189:
cmpq $0,-80(%rbp)
je .L190
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D19
.L190:
cmpq $0,-56(%rbp)
je .L191
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D19
.L191:
cmpq $0,-32(%rbp)
je .L192
movq $0,-32(%rbp)
movq %r13,%rdi
call .D18
.L192:
cmpq $0,-24(%rbp)
je .L193
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L193:
xorq %rax,%rax
movq -.F131-8(%rbp),%rbx
movq -.F131-16(%rbp),%r12
movq -.F131-24(%rbp),%r13
movq -.F131-32(%rbp),%r14
movq -.F131-40(%rbp),%r15
leave
ret
.set .F131,144
.type f_strings_contains,@function
f_strings_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F194,%rsp
subq $48,%rsp
movq %rbx,-.F194-8(%rbp)
movq %r12,-.F194-16(%rbp)
movq %r13,-.F194-24(%rbp)
movq %r14,-.F194-32(%rbp)
movq %r15,-.F194-40(%rbp)
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
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $1,-24(%rbp)
movq $1,-32(%rbp)
leaq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,-40(%rbp)
movq %rax,-48(%rbp)
movq $0,%rbx
leaq -16(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
movq $0,%r13
movq $0,%r12
movq $0,%r14
movq -40(%rbp),%rdi
movq %rax,%rsi
call f_strings_find
movq %rax,-72(%rbp)
movq 0(%rax),%rax
movq $0,%r15
cmpq $1,%rax
jne .L195
movq -72(%rbp),%rdi
call rt_free
movq $1,-80(%rbp)
cmpq $0,%r15
je .L197
movq -72(%rbp),%rdi
call .D19
.L197:
cmpq $0,%r14
je .L198
movq -64(%rbp),%rdi
call .D4
.L198:
cmpq $0,%r13
je .L199
movq -56(%rbp),%rdi
call .D4
.L199:
cmpq $0,%r12
je .L200
movq -48(%rbp),%rdi
call .D4
.L200:
cmpq $0,%rbx
je .L201
movq -40(%rbp),%rdi
call .D4
.L201:
cmpq $0,-32(%rbp)
je .L202
movq $0,-32(%rbp)
movq -16(%rbp),%rdi
call .D18
.L202:
cmpq $0,-24(%rbp)
je .L203
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L203:
movq -80(%rbp),%rax
movq -.F194-8(%rbp),%rbx
movq -.F194-16(%rbp),%r12
movq -.F194-24(%rbp),%r13
movq -.F194-32(%rbp),%r14
movq -.F194-40(%rbp),%r15
leave
ret
cmpq $0,-24(%rbp)
je .L204
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L204:
cmpq $0,-32(%rbp)
je .L205
movq $0,-32(%rbp)
movq -16(%rbp),%rdi
call .D18
.L205:
jmp .L196
.L195:
movq -72(%rbp),%rdi
call .D19
.L196:
cmpq $0,%r15
je .L206
movq $0,%r15
movq -72(%rbp),%rdi
call .D19
.L206:
cmpq $0,%r14
je .L207
movq $0,%r14
movq -64(%rbp),%rdi
call .D4
.L207:
cmpq $0,%r13
je .L208
movq $0,%r13
movq -56(%rbp),%rdi
call .D4
.L208:
cmpq $0,%r12
je .L209
movq $0,%r12
movq -48(%rbp),%rdi
call .D4
.L209:
cmpq $0,%rbx
je .L210
movq $0,%rbx
movq -40(%rbp),%rdi
call .D4
.L210:
movq $0,-88(%rbp)
cmpq $0,%r15
je .L211
movq -72(%rbp),%rdi
call .D19
.L211:
cmpq $0,%r14
je .L212
movq -64(%rbp),%rdi
call .D4
.L212:
cmpq $0,%r13
je .L213
movq -56(%rbp),%rdi
call .D4
.L213:
cmpq $0,%r12
je .L214
movq -48(%rbp),%rdi
call .D4
.L214:
cmpq $0,%rbx
je .L215
movq -40(%rbp),%rdi
call .D4
.L215:
cmpq $0,-32(%rbp)
je .L216
movq $0,-32(%rbp)
movq -16(%rbp),%rdi
call .D18
.L216:
cmpq $0,-24(%rbp)
je .L217
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L217:
movq -88(%rbp),%rax
movq -.F194-8(%rbp),%rbx
movq -.F194-16(%rbp),%r12
movq -.F194-24(%rbp),%r13
movq -.F194-32(%rbp),%r14
movq -.F194-40(%rbp),%r15
leave
ret
cmpq $0,-24(%rbp)
je .L218
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L218:
cmpq $0,-32(%rbp)
je .L219
movq $0,-32(%rbp)
movq -16(%rbp),%rdi
call .D18
.L219:
cmpq $0,%r15
je .L220
movq $0,%r15
movq -72(%rbp),%rdi
call .D19
.L220:
cmpq $0,%r14
je .L221
movq $0,%r14
movq -64(%rbp),%rdi
call .D4
.L221:
cmpq $0,%r13
je .L222
movq $0,%r13
movq -56(%rbp),%rdi
call .D4
.L222:
cmpq $0,%r12
je .L223
movq $0,%r12
movq -48(%rbp),%rdi
call .D4
.L223:
cmpq $0,%rbx
je .L224
movq $0,%rbx
movq -40(%rbp),%rdi
call .D4
.L224:
cmpq $0,%r15
je .L225
movq -72(%rbp),%rdi
call .D19
.L225:
cmpq $0,%r14
je .L226
movq -64(%rbp),%rdi
call .D4
.L226:
cmpq $0,%r13
je .L227
movq -56(%rbp),%rdi
call .D4
.L227:
cmpq $0,%r12
je .L228
movq -48(%rbp),%rdi
call .D4
.L228:
cmpq $0,%rbx
je .L229
movq -40(%rbp),%rdi
call .D4
.L229:
cmpq $0,-32(%rbp)
je .L230
movq $0,-32(%rbp)
movq -16(%rbp),%rdi
call .D18
.L230:
cmpq $0,-24(%rbp)
je .L231
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L231:
xorq %rax,%rax
movq -.F194-8(%rbp),%rbx
movq -.F194-16(%rbp),%r12
movq -.F194-24(%rbp),%r13
movq -.F194-32(%rbp),%r14
movq -.F194-40(%rbp),%r15
leave
ret
.set .F194,96
.type f_strings_split,@function
f_strings_split:
pushq %rbp
movq %rsp,%rbp
subq $.F232,%rsp
subq $48,%rsp
movq %rbx,-.F232-8(%rbp)
movq %r12,-.F232-16(%rbp)
movq %r13,-.F232-24(%rbp)
movq %r14,-.F232-32(%rbp)
movq %r15,-.F232-40(%rbp)
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
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $0,-88(%rbp)
movq $0,-96(%rbp)
movq $1,-24(%rbp)
call rt_new
movq %rax,-32(%rbp)
movq $1,-40(%rbp)
movq %rax,-48(%rbp)
movq $0,-40(%rbp)
movq $1,-56(%rbp)
cmpq $0,-40(%rbp)
je .L233
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D5
.L233:
call rt_new
movq %rax,-64(%rbp)
movq $1,-72(%rbp)
movq %rax,%r14
movq $0,-72(%rbp)
cmpq $0,-72(%rbp)
je .L234
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D2
.L234:
movq -8(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-80(%rbp)
movq $0,%r15
.L235:
movq -80(%rbp),%rcx
cmpq %rcx,%r15
jae .L237
movq -8(%rbp),%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt5
call rt_abort
.Lopt5:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-88(%rbp)
movq -16(%rbp),%rcx
cmpq %rcx,%rax
jne .L238
movq $0,%r13
movq -48(%rbp),%rdi
movq %r14,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt6
call rt_push
jmp .Lopt7
.Lopt6:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt7:
call rt_new
movq %rax,%r12
cmpq $0,%r13
je .L240
movq %r14,%rdi
call .D2
.L240:
movq %r12,%r14
movq $0,%rbx
cmpq $0,%rbx
je .L241
movq $0,%rbx
movq %r12,%rdi
call .D2
.L241:
cmpq $0,%rbx
je .L242
movq $0,%rbx
movq %r12,%rdi
call .D2
.L242:
jmp .L239
.L238:
movq %r14,%rdi
movq -88(%rbp),%rsi
call rt_pushb_checked
.L239:
cmpq $0,%rbx
je .L243
movq $0,%rbx
movq %r12,%rdi
call .D2
.L243:
cmpq $0,%rbx
je .L244
movq $0,%rbx
movq %r12,%rdi
call .D2
.L244:
.L236:
incq %r15
jmp .L235
.L237:
cmpq $0,%rbx
je .L245
movq $0,%rbx
movq %r12,%rdi
call .D2
.L245:
cmpq $0,-24(%rbp)
je .L246
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L246:
cmpq $0,%rbx
je .L247
movq $0,%rbx
movq %r12,%rdi
call .D2
.L247:
movq $0,%r13
movq -48(%rbp),%rdi
movq %r14,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt8
call rt_push
jmp .Lopt9
.Lopt8:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt9:
cmpq $0,-24(%rbp)
je .L248
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L248:
movq $0,-56(%rbp)
cmpq $0,%rbx
je .L249
movq %r12,%rdi
call .D2
.L249:
cmpq $0,%r13
je .L250
movq %r14,%rdi
call .D2
.L250:
cmpq $0,-72(%rbp)
je .L251
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D2
.L251:
cmpq $0,-56(%rbp)
je .L252
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D5
.L252:
cmpq $0,-40(%rbp)
je .L253
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D5
.L253:
cmpq $0,-24(%rbp)
je .L254
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L254:
movq -48(%rbp),%rax
movq -.F232-8(%rbp),%rbx
movq -.F232-16(%rbp),%r12
movq -.F232-24(%rbp),%r13
movq -.F232-32(%rbp),%r14
movq -.F232-40(%rbp),%r15
leave
ret
cmpq $0,-24(%rbp)
je .L255
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L255:
cmpq $0,%rbx
je .L256
movq $0,%rbx
movq %r12,%rdi
call .D2
.L256:
cmpq $0,%r13
je .L257
movq $0,%r13
movq %r14,%rdi
call .D2
.L257:
cmpq $0,-72(%rbp)
je .L258
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D2
.L258:
cmpq $0,-56(%rbp)
je .L259
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D5
.L259:
cmpq $0,-40(%rbp)
je .L260
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D5
.L260:
cmpq $0,%rbx
je .L261
movq %r12,%rdi
call .D2
.L261:
cmpq $0,%r13
je .L262
movq %r14,%rdi
call .D2
.L262:
cmpq $0,-72(%rbp)
je .L263
movq $0,-72(%rbp)
movq -64(%rbp),%rdi
call .D2
.L263:
cmpq $0,-56(%rbp)
je .L264
movq $0,-56(%rbp)
movq -48(%rbp),%rdi
call .D5
.L264:
cmpq $0,-40(%rbp)
je .L265
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D5
.L265:
cmpq $0,-24(%rbp)
je .L266
movq $0,-24(%rbp)
movq -8(%rbp),%rdi
call .D8
.L266:
xorq %rax,%rax
movq -.F232-8(%rbp),%rbx
movq -.F232-16(%rbp),%r12
movq -.F232-24(%rbp),%r13
movq -.F232-32(%rbp),%r14
movq -.F232-40(%rbp),%r15
leave
ret
.set .F232,96
.type f_strings_trim,@function
f_strings_trim:
pushq %rbp
movq %rsp,%rbp
subq $.F267,%rsp
subq $48,%rsp
movq %rbx,-.F267-8(%rbp)
movq %r12,-.F267-16(%rbp)
movq %r13,-.F267-24(%rbp)
movq %r14,-.F267-32(%rbp)
movq %r15,-.F267-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
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
movq $1,-16(%rbp)
movq $0,%rbx
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
.L268:
cmpq %r12,%rbx
jae .L269
movq %r13,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt10
call rt_abort
.Lopt10:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r14
movq %rax,-24(%rbp)
cmpq $32,%rax
setne %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq %r14,%rax
cmpq $9,%r14
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
andq %rcx,%rax
movq %rax,-40(%rbp)
movq %r14,%rax
cmpq $10,%r14
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
andq %rcx,%rax
movq %rax,-48(%rbp)
movq %r14,%rax
cmpq $13,%r14
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L270
jmp .L269
jmp .L271
.L270:
.L271:
movq %rbx,%rax
addq $1,%rax
jnc .L272
call rt_abort
.L272:
movq %rax,%rbx
jmp .L268
.L269:
.L273:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L274
movq %r12,%rax
subq $1,%rax
jnc .L275
call rt_abort
.L275:
movq %r13,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt11
call rt_abort
.Lopt11:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r15
movq %rax,-56(%rbp)
cmpq $32,%rax
setne %al
movzbq %al,%rax
movq %rax,-64(%rbp)
movq %r15,%rax
cmpq $9,%r15
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -64(%rbp),%rax
andq %rcx,%rax
movq %rax,-72(%rbp)
movq %r15,%rax
cmpq $10,%r15
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
andq %rcx,%rax
movq %rax,-80(%rbp)
movq %r15,%rax
cmpq $13,%r15
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L276
jmp .L274
jmp .L277
.L276:
.L277:
movq %r12,%rax
subq $1,%rax
jnc .L278
call rt_abort
.L278:
movq %rax,%r12
jmp .L273
.L274:
call rt_new
movq %rax,-88(%rbp)
movq $1,-96(%rbp)
movq %rax,-104(%rbp)
movq $0,-96(%rbp)
movq $1,-112(%rbp)
cmpq $0,-96(%rbp)
je .L279
movq $0,-96(%rbp)
movq -88(%rbp),%rdi
call .D2
.L279:
movq %rbx,-120(%rbp)
movq %r12,-128(%rbp)
.L280:
movq -128(%rbp),%rcx
movq -120(%rbp),%rax
cmpq %rcx,%rax
jae .L282
movq %r13,%rdi
movq -120(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt12
call rt_abort
.Lopt12:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -104(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
.L281:
incq -120(%rbp)
jmp .L280
.L282:
cmpq $0,-16(%rbp)
je .L283
movq $0,-16(%rbp)
movq %r13,%rdi
call .D8
.L283:
movq $0,-112(%rbp)
cmpq $0,-112(%rbp)
je .L284
movq $0,-112(%rbp)
movq -104(%rbp),%rdi
call .D2
.L284:
cmpq $0,-96(%rbp)
je .L285
movq $0,-96(%rbp)
movq -88(%rbp),%rdi
call .D2
.L285:
cmpq $0,-16(%rbp)
je .L286
movq $0,-16(%rbp)
movq %r13,%rdi
call .D8
.L286:
movq -104(%rbp),%rax
movq -.F267-8(%rbp),%rbx
movq -.F267-16(%rbp),%r12
movq -.F267-24(%rbp),%r13
movq -.F267-32(%rbp),%r14
movq -.F267-40(%rbp),%r15
leave
ret
cmpq $0,-16(%rbp)
je .L287
movq $0,-16(%rbp)
movq %r13,%rdi
call .D8
.L287:
cmpq $0,-112(%rbp)
je .L288
movq $0,-112(%rbp)
movq -104(%rbp),%rdi
call .D2
.L288:
cmpq $0,-96(%rbp)
je .L289
movq $0,-96(%rbp)
movq -88(%rbp),%rdi
call .D2
.L289:
cmpq $0,-112(%rbp)
je .L290
movq $0,-112(%rbp)
movq -104(%rbp),%rdi
call .D2
.L290:
cmpq $0,-96(%rbp)
je .L291
movq $0,-96(%rbp)
movq -88(%rbp),%rdi
call .D2
.L291:
cmpq $0,-16(%rbp)
je .L292
movq $0,-16(%rbp)
movq %r13,%rdi
call .D8
.L292:
xorq %rax,%rax
movq -.F267-8(%rbp),%rbx
movq -.F267-16(%rbp),%r12
movq -.F267-24(%rbp),%r13
movq -.F267-32(%rbp),%r14
movq -.F267-40(%rbp),%r15
leave
ret
.set .F267,128
.type f_strings_join_with,@function
f_strings_join_with:
pushq %rbp
movq %rsp,%rbp
subq $.F293,%rsp
subq $48,%rsp
movq %rbx,-.F293-8(%rbp)
movq %r12,-.F293-16(%rbp)
movq %r13,-.F293-24(%rbp)
movq %r14,-.F293-32(%rbp)
movq %r15,-.F293-40(%rbp)
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
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movq $1,-24(%rbp)
call rt_new
movq %rax,-32(%rbp)
movq $1,-40(%rbp)
movq %rax,%r13
movq $0,-40(%rbp)
movq $1,-48(%rbp)
cmpq $0,-40(%rbp)
je .L294
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D2
.L294:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-56(%rbp)
movq $0,-64(%rbp)
.L295:
movq -56(%rbp),%rcx
movq -64(%rbp),%rax
cmpq %rcx,%rax
jae .L297
movq -64(%rbp),%rax
movq %rax,%rcx
movabsq $0,%rax
cmpq %rcx,%rax
jae .L298
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%r15
movq $0,%rbx
.L300:
movq %r15,%rcx
cmpq %r15,%rbx
jae .L302
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt13
call rt_abort
.Lopt13:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_pushb_checked
.L301:
incq %rbx
jmp .L300
.L302:
jmp .L299
.L298:
.L299:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
movq -64(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt14
call rt_abort
.Lopt14:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movq %rax,%rdi
movq 8(%rdi),%rax
movq %rax,-80(%rbp)
movq $0,%r12
.L303:
movq -80(%rbp),%rcx
cmpq %rcx,%r12
jae .L305
movq -72(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt15
call rt_abort
.Lopt15:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_pushb_checked
.L304:
incq %r12
jmp .L303
.L305:
.L296:
incq -64(%rbp)
jmp .L295
.L297:
cmpq $0,-24(%rbp)
je .L306
movq $0,-24(%rbp)
movq %r14,%rdi
call .D18
.L306:
movq $0,-48(%rbp)
cmpq $0,-48(%rbp)
je .L307
movq $0,-48(%rbp)
movq %r13,%rdi
call .D2
.L307:
cmpq $0,-40(%rbp)
je .L308
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D2
.L308:
cmpq $0,-24(%rbp)
je .L309
movq $0,-24(%rbp)
movq %r14,%rdi
call .D18
.L309:
movq %r13,%rax
movq -.F293-8(%rbp),%rbx
movq -.F293-16(%rbp),%r12
movq -.F293-24(%rbp),%r13
movq -.F293-32(%rbp),%r14
movq -.F293-40(%rbp),%r15
leave
ret
cmpq $0,-24(%rbp)
je .L310
movq $0,-24(%rbp)
movq %r14,%rdi
call .D18
.L310:
cmpq $0,-48(%rbp)
je .L311
movq $0,-48(%rbp)
movq %r13,%rdi
call .D2
.L311:
cmpq $0,-40(%rbp)
je .L312
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D2
.L312:
cmpq $0,-48(%rbp)
je .L313
movq $0,-48(%rbp)
movq %r13,%rdi
call .D2
.L313:
cmpq $0,-40(%rbp)
je .L314
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D2
.L314:
cmpq $0,-24(%rbp)
je .L315
movq $0,-24(%rbp)
movq %r14,%rdi
call .D18
.L315:
xorq %rax,%rax
movq -.F293-8(%rbp),%rbx
movq -.F293-16(%rbp),%r12
movq -.F293-24(%rbp),%r13
movq -.F293-32(%rbp),%r14
movq -.F293-40(%rbp),%r15
leave
ret
.set .F293,80
.type f_strings_to_upper,@function
f_strings_to_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F316,%rsp
subq $48,%rsp
movq %rbx,-.F316-8(%rbp)
movq %r12,-.F316-16(%rbp)
movq %r13,-.F316-24(%rbp)
movq %r14,-.F316-32(%rbp)
movq %r15,-.F316-40(%rbp)
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
movq $1,-16(%rbp)
call rt_new
movq %rax,-24(%rbp)
movq %rax,%r12
movq $0,%r15
movq $1,-32(%rbp)
cmpq $0,%r15
je .L317
movq $0,%r15
movq -24(%rbp),%rdi
call .D2
.L317:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq $0,%r13
.L318:
movq -40(%rbp),%rcx
cmpq %rcx,%r13
jae .L320
movq %r14,%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt16
call rt_abort
.Lopt16:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rbx
movq %rax,-48(%rbp)
cmpq $97,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-56(%rbp)
movabsq $122,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L321
movabsq $32,%rcx
movq %rbx,%rax
subq $32,%rax
jnc .L323
call rt_abort
.L323:
movq %r12,%rdi
movq %rax,%rsi
call rt_pushb_checked
jmp .L322
.L321:
movq %r12,%rdi
movq %rbx,%rsi
call rt_pushb_checked
.L322:
.L319:
incq %r13
jmp .L318
.L320:
cmpq $0,-16(%rbp)
je .L324
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L324:
movq $0,-32(%rbp)
cmpq $0,-32(%rbp)
je .L325
movq $0,-32(%rbp)
movq %r12,%rdi
call .D2
.L325:
cmpq $0,%r15
je .L326
movq -24(%rbp),%rdi
call .D2
.L326:
cmpq $0,-16(%rbp)
je .L327
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L327:
movq %r12,%rax
movq -.F316-8(%rbp),%rbx
movq -.F316-16(%rbp),%r12
movq -.F316-24(%rbp),%r13
movq -.F316-32(%rbp),%r14
movq -.F316-40(%rbp),%r15
leave
ret
cmpq $0,-16(%rbp)
je .L328
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L328:
cmpq $0,-32(%rbp)
je .L329
movq $0,-32(%rbp)
movq %r12,%rdi
call .D2
.L329:
cmpq $0,%r15
je .L330
movq $0,%r15
movq -24(%rbp),%rdi
call .D2
.L330:
cmpq $0,-32(%rbp)
je .L331
movq $0,-32(%rbp)
movq %r12,%rdi
call .D2
.L331:
cmpq $0,%r15
je .L332
movq -24(%rbp),%rdi
call .D2
.L332:
cmpq $0,-16(%rbp)
je .L333
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L333:
xorq %rax,%rax
movq -.F316-8(%rbp),%rbx
movq -.F316-16(%rbp),%r12
movq -.F316-24(%rbp),%r13
movq -.F316-32(%rbp),%r14
movq -.F316-40(%rbp),%r15
leave
ret
.set .F316,64
.type f_strings_to_lower,@function
f_strings_to_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F334,%rsp
subq $48,%rsp
movq %rbx,-.F334-8(%rbp)
movq %r12,-.F334-16(%rbp)
movq %r13,-.F334-24(%rbp)
movq %r14,-.F334-32(%rbp)
movq %r15,-.F334-40(%rbp)
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
movq $1,-16(%rbp)
call rt_new
movq %rax,-24(%rbp)
movq %rax,%r12
movq $0,%r15
movq $1,-32(%rbp)
cmpq $0,%r15
je .L335
movq $0,%r15
movq -24(%rbp),%rdi
call .D2
.L335:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-40(%rbp)
movq $0,%r13
.L336:
movq -40(%rbp),%rcx
cmpq %rcx,%r13
jae .L338
movq %r14,%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt17
call rt_abort
.Lopt17:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rbx
movq %rax,-48(%rbp)
cmpq $65,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-56(%rbp)
movabsq $90,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L339
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L341
call rt_abort
.L341:
movq %r12,%rdi
movq %rax,%rsi
call rt_pushb_checked
jmp .L340
.L339:
movq %r12,%rdi
movq %rbx,%rsi
call rt_pushb_checked
.L340:
.L337:
incq %r13
jmp .L336
.L338:
cmpq $0,-16(%rbp)
je .L342
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L342:
movq $0,-32(%rbp)
cmpq $0,-32(%rbp)
je .L343
movq $0,-32(%rbp)
movq %r12,%rdi
call .D2
.L343:
cmpq $0,%r15
je .L344
movq -24(%rbp),%rdi
call .D2
.L344:
cmpq $0,-16(%rbp)
je .L345
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L345:
movq %r12,%rax
movq -.F334-8(%rbp),%rbx
movq -.F334-16(%rbp),%r12
movq -.F334-24(%rbp),%r13
movq -.F334-32(%rbp),%r14
movq -.F334-40(%rbp),%r15
leave
ret
cmpq $0,-16(%rbp)
je .L346
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L346:
cmpq $0,-32(%rbp)
je .L347
movq $0,-32(%rbp)
movq %r12,%rdi
call .D2
.L347:
cmpq $0,%r15
je .L348
movq $0,%r15
movq -24(%rbp),%rdi
call .D2
.L348:
cmpq $0,-32(%rbp)
je .L349
movq $0,-32(%rbp)
movq %r12,%rdi
call .D2
.L349:
cmpq $0,%r15
je .L350
movq -24(%rbp),%rdi
call .D2
.L350:
cmpq $0,-16(%rbp)
je .L351
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L351:
xorq %rax,%rax
movq -.F334-8(%rbp),%rbx
movq -.F334-16(%rbp),%r12
movq -.F334-24(%rbp),%r13
movq -.F334-32(%rbp),%r14
movq -.F334-40(%rbp),%r15
leave
ret
.set .F334,64
.type f_strings_parse_num,@function
f_strings_parse_num:
pushq %rbp
movq %rsp,%rbp
subq $.F352,%rsp
subq $48,%rsp
movq %rbx,-.F352-8(%rbp)
movq %r12,-.F352-16(%rbp)
movq %r13,-.F352-24(%rbp)
movq %r14,-.F352-32(%rbp)
movq %r15,-.F352-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F352(%rbp),%rdi
movq $.F352/8-1,%rcx
xorl %eax,%eax
rep stosq
movq $1,-16(%rbp)
movq -8(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L353
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,-32(%rbp)
movq $0,%r15
cmpq $0,%r15
je .L355
movq -32(%rbp),%rdi
call .D19
.L355:
cmpq $0,-16(%rbp)
je .L356
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L356:
movq -32(%rbp),%rax
movq -.F352-8(%rbp),%rbx
movq -.F352-16(%rbp),%r12
movq -.F352-24(%rbp),%r13
movq -.F352-32(%rbp),%r14
movq -.F352-40(%rbp),%r15
leave
ret
cmpq $0,%r15
je .L357
movq $0,%r15
movq -32(%rbp),%rdi
call .D19
.L357:
cmpq $0,%r15
je .L358
movq $0,%r15
movq -32(%rbp),%rdi
call .D19
.L358:
jmp .L354
.L353:
.L354:
cmpq $0,%r15
je .L359
movq $0,%r15
movq -32(%rbp),%rdi
call .D19
.L359:
movq $0,-40(%rbp)
movq -8(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-48(%rbp)
movq $0,-56(%rbp)
.L360:
movq -48(%rbp),%rcx
movq -56(%rbp),%rax
cmpq %rcx,%rax
jae .L362
movq -8(%rbp),%rdi
movq -56(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt18
call rt_abort
.Lopt18:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-64(%rbp)
movq %rax,-72(%rbp)
cmpq $48,%rax
setb %al
movzbq %al,%rax
movq %rax,-80(%rbp)
movq $1,-88(%rbp)
movq $0,-96(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L363
movq -64(%rbp),%rax
movq %rax,%rcx
movabsq $57,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -96(%rbp),%rcx
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
movq %rax,-88(%rbp)
.L363:
movq -88(%rbp),%rax
testq %rax,%rax
jz .L364
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,%r14
movq $0,%rbx
cmpq $0,%rbx
je .L366
movq %r14,%rdi
call .D19
.L366:
cmpq $0,%r15
je .L367
movq -32(%rbp),%rdi
call .D19
.L367:
cmpq $0,-16(%rbp)
je .L368
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L368:
movq %r14,%rax
movq -.F352-8(%rbp),%rbx
movq -.F352-16(%rbp),%r12
movq -.F352-24(%rbp),%r13
movq -.F352-32(%rbp),%r14
movq -.F352-40(%rbp),%r15
leave
ret
cmpq $0,%rbx
je .L369
movq $0,%rbx
movq %r14,%rdi
call .D19
.L369:
cmpq $0,%rbx
je .L370
movq $0,%rbx
movq %r14,%rdi
call .D19
.L370:
jmp .L365
.L364:
.L365:
cmpq $0,%rbx
je .L371
movq $0,%rbx
movq %r14,%rdi
call .D19
.L371:
movq -40(%rbp),%rax
movq %rax,%rcx
movabsq $1844674407370955161,%rax
cmpq %rcx,%rax
jae .L372
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,-104(%rbp)
movq $0,%r12
cmpq $0,%r12
je .L374
movq -104(%rbp),%rdi
call .D19
.L374:
cmpq $0,%rbx
je .L375
movq %r14,%rdi
call .D19
.L375:
cmpq $0,%r15
je .L376
movq -32(%rbp),%rdi
call .D19
.L376:
cmpq $0,-16(%rbp)
je .L377
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L377:
movq -104(%rbp),%rax
movq -.F352-8(%rbp),%rbx
movq -.F352-16(%rbp),%r12
movq -.F352-24(%rbp),%r13
movq -.F352-32(%rbp),%r14
movq -.F352-40(%rbp),%r15
leave
ret
cmpq $0,%r12
je .L378
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L378:
cmpq $0,%r12
je .L379
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L379:
jmp .L373
.L372:
.L373:
cmpq $0,%r12
je .L380
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L380:
movabsq $10,%rcx
movq -40(%rbp),%rax
mulq %rcx
jnc .L381
call rt_abort
.L381:
movq %rax,-112(%rbp)
movq %rax,-120(%rbp)
movq -64(%rbp),%rax
subq $48,%rax
jnc .L382
call rt_abort
.L382:
movq %rax,%rcx
movabsq $18446744073709551615,%rax
subq %rcx,%rax
jnc .L383
call rt_abort
.L383:
movq %rax,-128(%rbp)
movq -120(%rbp),%rax
movq %rax,%rcx
movq -128(%rbp),%rax
cmpq %rcx,%rax
jae .L384
movabsq $0,%rdi
movabsq $0,%rsi
call rt_enum
movq %rax,-136(%rbp)
movq $0,%r13
cmpq $0,%r13
je .L386
movq -136(%rbp),%rdi
call .D19
.L386:
cmpq $0,%r12
je .L387
movq -104(%rbp),%rdi
call .D19
.L387:
cmpq $0,%rbx
je .L388
movq %r14,%rdi
call .D19
.L388:
cmpq $0,%r15
je .L389
movq -32(%rbp),%rdi
call .D19
.L389:
cmpq $0,-16(%rbp)
je .L390
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L390:
movq -136(%rbp),%rax
movq -.F352-8(%rbp),%rbx
movq -.F352-16(%rbp),%r12
movq -.F352-24(%rbp),%r13
movq -.F352-32(%rbp),%r14
movq -.F352-40(%rbp),%r15
leave
ret
cmpq $0,%r13
je .L391
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L391:
cmpq $0,%r13
je .L392
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L392:
jmp .L385
.L384:
.L385:
cmpq $0,%r13
je .L393
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L393:
movq -64(%rbp),%rax
subq $48,%rax
jnc .L394
call rt_abort
.L394:
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L395
call rt_abort
.L395:
movq %rax,-40(%rbp)
cmpq $0,%r13
je .L396
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L396:
cmpq $0,%r12
je .L397
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L397:
cmpq $0,%rbx
je .L398
movq $0,%rbx
movq %r14,%rdi
call .D19
.L398:
.L361:
incq -56(%rbp)
jmp .L360
.L362:
cmpq $0,%r13
je .L399
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L399:
cmpq $0,%r12
je .L400
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L400:
cmpq $0,%rbx
je .L401
movq $0,%rbx
movq %r14,%rdi
call .D19
.L401:
cmpq $0,-16(%rbp)
je .L402
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L402:
cmpq $0,%r13
je .L403
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L403:
cmpq $0,%r12
je .L404
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L404:
cmpq $0,%rbx
je .L405
movq $0,%rbx
movq %r14,%rdi
call .D19
.L405:
movq -40(%rbp),%rax
movq %rax,%rdi
call f_core_some$0
movq %rax,-144(%rbp)
movq $1,-152(%rbp)
movq $0,-152(%rbp)
cmpq $0,-152(%rbp)
je .L406
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D19
.L406:
cmpq $0,%r13
je .L407
movq -136(%rbp),%rdi
call .D19
.L407:
cmpq $0,%r12
je .L408
movq -104(%rbp),%rdi
call .D19
.L408:
cmpq $0,%rbx
je .L409
movq %r14,%rdi
call .D19
.L409:
cmpq $0,%r15
je .L410
movq -32(%rbp),%rdi
call .D19
.L410:
cmpq $0,-16(%rbp)
je .L411
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L411:
movq -144(%rbp),%rax
movq -.F352-8(%rbp),%rbx
movq -.F352-16(%rbp),%r12
movq -.F352-24(%rbp),%r13
movq -.F352-32(%rbp),%r14
movq -.F352-40(%rbp),%r15
leave
ret
cmpq $0,-16(%rbp)
je .L412
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L412:
cmpq $0,-152(%rbp)
je .L413
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D19
.L413:
cmpq $0,-152(%rbp)
je .L414
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D19
.L414:
cmpq $0,%r13
je .L415
movq $0,%r13
movq -136(%rbp),%rdi
call .D19
.L415:
cmpq $0,%r12
je .L416
movq $0,%r12
movq -104(%rbp),%rdi
call .D19
.L416:
cmpq $0,%rbx
je .L417
movq $0,%rbx
movq %r14,%rdi
call .D19
.L417:
cmpq $0,%r15
je .L418
movq $0,%r15
movq -32(%rbp),%rdi
call .D19
.L418:
cmpq $0,-152(%rbp)
je .L419
movq $0,-152(%rbp)
movq -144(%rbp),%rdi
call .D19
.L419:
cmpq $0,%r13
je .L420
movq -136(%rbp),%rdi
call .D19
.L420:
cmpq $0,%r12
je .L421
movq -104(%rbp),%rdi
call .D19
.L421:
cmpq $0,%rbx
je .L422
movq %r14,%rdi
call .D19
.L422:
cmpq $0,%r15
je .L423
movq -32(%rbp),%rdi
call .D19
.L423:
cmpq $0,-16(%rbp)
je .L424
movq $0,-16(%rbp)
movq -8(%rbp),%rdi
call .D8
.L424:
xorq %rax,%rax
movq -.F352-8(%rbp),%rbx
movq -.F352-16(%rbp),%r12
movq -.F352-24(%rbp),%r13
movq -.F352-32(%rbp),%r14
movq -.F352-40(%rbp),%r15
leave
ret
.set .F352,160
.type f_strings_chars,@function
f_strings_chars:
pushq %rbp
movq %rsp,%rbp
subq $.F425,%rsp
subq $48,%rsp
movq %rbx,-.F425-8(%rbp)
movq %r12,-.F425-16(%rbp)
movq %r13,-.F425-24(%rbp)
movq %r14,-.F425-32(%rbp)
movq %r15,-.F425-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
leaq -.F425(%rbp),%rdi
movq $.F425/8-1,%rcx
xorl %eax,%eax
rep stosq
movq $1,-16(%rbp)
call rt_new
movq %rax,-24(%rbp)
movq $1,-32(%rbp)
movq %rax,-40(%rbp)
movq $0,-32(%rbp)
movq $1,-48(%rbp)
cmpq $0,-32(%rbp)
je .L426
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D22
.L426:
movq $0,%rbx
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-56(%rbp)
.L427:
movq %rbx,%rax
movq -56(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
testq %rax,%rax
jz .L428
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt19
call rt_abort
.Lopt19:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq $65533,%r13
movq $1,%r15
movabsq $128,%rcx
cmpq $128,%rax
jae .L429
movq %r12,%rdi
movabsq $64,%rsi
movabsq $32,%rdx
call rt_int_cast
movq %rax,%r13
jmp .L430
.L429:
movq %r12,%rax
cmpq $194,%r12
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-64(%rbp)
movabsq $223,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,%rcx
movq -64(%rbp),%rax
andq %rcx,%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L431
call rt_abort
.L431:
movq -56(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L432
movq %rbx,%rax
addq $1,%rax
jnc .L434
call rt_abort
.L434:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt20
call rt_abort
.Lopt20:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-80(%rbp)
movq %rax,-88(%rbp)
andq $192,%rax
movq %rax,-96(%rbp)
movabsq $128,%rcx
cmpq $128,%rax
jne .L435
movq %r12,%rax
andq $31,%rax
movq %rax,-104(%rbp)
movabsq $64,%rcx
mulq %rcx
jnc .L437
call rt_abort
.L437:
movq %rax,-112(%rbp)
movq -80(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L438
call rt_abort
.L438:
movq %rax,-120(%rbp)
movq %rax,%rdi
movabsq $64,%rsi
movabsq $32,%rdx
call rt_int_cast
movq %rax,%r13
movq $2,%r15
jmp .L436
.L435:
.L436:
jmp .L433
.L432:
movq %r12,%rax
cmpq $224,%r12
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-128(%rbp)
movabsq $239,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,%rcx
movq -128(%rbp),%rax
andq %rcx,%rax
movq %rax,-136(%rbp)
movq %rbx,%rax
addq $2,%rax
jnc .L439
call rt_abort
.L439:
movq -56(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -136(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L440
movq %rbx,%rax
addq $1,%rax
jnc .L442
call rt_abort
.L442:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt21
call rt_abort
.Lopt21:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-144(%rbp)
movq %rbx,%rax
addq $2,%rax
jnc .L443
call rt_abort
.L443:
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt22
call rt_abort
.Lopt22:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-152(%rbp)
movq -144(%rbp),%rax
andq $192,%rax
movq %rax,-160(%rbp)
cmpq $128,%rax
sete %al
movzbq %al,%rax
movq %rax,-168(%rbp)
movq -152(%rbp),%rax
andq $192,%rax
movq %rax,-176(%rbp)
cmpq $128,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -168(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L444
movq %r12,%rax
andq $15,%rax
movq %rax,-184(%rbp)
movabsq $4096,%rcx
mulq %rcx
jnc .L446
call rt_abort
.L446:
movq %rax,-192(%rbp)
movq -144(%rbp),%rax
andq $63,%rax
movq %rax,-200(%rbp)
movabsq $64,%rcx
mulq %rcx
jnc .L447
call rt_abort
.L447:
movq %rax,%rcx
movq -192(%rbp),%rax
addq %rcx,%rax
jnc .L448
call rt_abort
.L448:
movq %rax,-208(%rbp)
movq -152(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -208(%rbp),%rax
addq %rcx,%rax
jnc .L449
call rt_abort
.L449:
movq %rax,-216(%rbp)
movq %rax,-224(%rbp)
cmpq $2048,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-232(%rbp)
movq $0,-240(%rbp)
movq $0,-248(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L450
movq -216(%rbp),%rax
cmpq $55296,%rax
setb %al
movzbq %al,%rax
movq %rax,-256(%rbp)
movq $1,-264(%rbp)
movq $0,-272(%rbp)
cmpq $0,%rax
jne .L451
movq -216(%rbp),%rax
movq %rax,%rcx
movabsq $57343,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -272(%rbp),%rcx
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
movq %rax,-264(%rbp)
.L451:
movq -248(%rbp),%rcx
movq -264(%rbp),%rax
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
movq %rax,-240(%rbp)
.L450:
movq -240(%rbp),%rax
testq %rax,%rax
jz .L452
movq -216(%rbp),%rdi
movabsq $64,%rsi
movabsq $32,%rdx
call rt_int_cast
movq %rax,%r13
movq $3,%r15
jmp .L453
.L452:
.L453:
jmp .L445
.L444:
.L445:
jmp .L441
.L440:
movq %r12,%rax
cmpq $240,%r12
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-280(%rbp)
movabsq $244,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,%rcx
movq -280(%rbp),%rax
andq %rcx,%rax
movq %rax,-288(%rbp)
movq %rbx,%rax
addq $3,%rax
jnc .L454
call rt_abort
.L454:
movq -56(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -288(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L455
movq %rbx,%rax
addq $1,%rax
jnc .L457
call rt_abort
.L457:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt23
call rt_abort
.Lopt23:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-296(%rbp)
movq %rbx,%rax
addq $2,%rax
jnc .L458
call rt_abort
.L458:
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt24
call rt_abort
.Lopt24:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-304(%rbp)
movq %rbx,%rax
addq $3,%rax
jnc .L459
call rt_abort
.L459:
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt25
call rt_abort
.Lopt25:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-312(%rbp)
movq -296(%rbp),%rax
andq $192,%rax
movq %rax,-320(%rbp)
cmpq $128,%rax
sete %al
movzbq %al,%rax
movq %rax,-328(%rbp)
movq -304(%rbp),%rax
andq $192,%rax
movq %rax,-336(%rbp)
cmpq $128,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -328(%rbp),%rax
andq %rcx,%rax
movq %rax,-344(%rbp)
movq -312(%rbp),%rax
andq $192,%rax
movq %rax,-352(%rbp)
cmpq $128,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -344(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L460
movq %r12,%rax
andq $7,%rax
movq %rax,-360(%rbp)
movabsq $262144,%rcx
mulq %rcx
jnc .L462
call rt_abort
.L462:
movq %rax,-368(%rbp)
movq -296(%rbp),%rax
andq $63,%rax
movq %rax,-376(%rbp)
movabsq $4096,%rcx
mulq %rcx
jnc .L463
call rt_abort
.L463:
movq %rax,%rcx
movq -368(%rbp),%rax
addq %rcx,%rax
jnc .L464
call rt_abort
.L464:
movq %rax,-384(%rbp)
movq -304(%rbp),%rax
andq $63,%rax
movq %rax,-392(%rbp)
movabsq $64,%rcx
mulq %rcx
jnc .L465
call rt_abort
.L465:
movq %rax,%rcx
movq -384(%rbp),%rax
addq %rcx,%rax
jnc .L466
call rt_abort
.L466:
movq %rax,-400(%rbp)
movq -312(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -400(%rbp),%rax
addq %rcx,%rax
jnc .L467
call rt_abort
.L467:
movq %rax,-408(%rbp)
movq %rax,-416(%rbp)
cmpq $65536,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-424(%rbp)
movq -408(%rbp),%rax
movq %rax,%rcx
movabsq $1114111,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,%rcx
movq -424(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L468
movq -408(%rbp),%rdi
movabsq $64,%rsi
movabsq $32,%rdx
call rt_int_cast
movq %rax,%r13
movq $4,%r15
jmp .L469
.L468:
.L469:
jmp .L461
.L460:
.L461:
jmp .L456
.L455:
.L456:
.L441:
.L433:
.L430:
movq -40(%rbp),%rdi
movq %r13,%rsi
call rt_push4
movq %rbx,%rax
addq %r15,%rax
jnc .L470
call rt_abort
.L470:
movq %rax,%rbx
jmp .L427
.L428:
cmpq $0,-16(%rbp)
je .L471
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L471:
movq $0,-48(%rbp)
cmpq $0,-48(%rbp)
je .L472
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D22
.L472:
cmpq $0,-32(%rbp)
je .L473
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D22
.L473:
cmpq $0,-16(%rbp)
je .L474
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L474:
movq -40(%rbp),%rax
movq -.F425-8(%rbp),%rbx
movq -.F425-16(%rbp),%r12
movq -.F425-24(%rbp),%r13
movq -.F425-32(%rbp),%r14
movq -.F425-40(%rbp),%r15
leave
ret
cmpq $0,-16(%rbp)
je .L475
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L475:
cmpq $0,-48(%rbp)
je .L476
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D22
.L476:
cmpq $0,-32(%rbp)
je .L477
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D22
.L477:
cmpq $0,-48(%rbp)
je .L478
movq $0,-48(%rbp)
movq -40(%rbp),%rdi
call .D22
.L478:
cmpq $0,-32(%rbp)
je .L479
movq $0,-32(%rbp)
movq -24(%rbp),%rdi
call .D22
.L479:
cmpq $0,-16(%rbp)
je .L480
movq $0,-16(%rbp)
movq %r14,%rdi
call .D8
.L480:
xorq %rax,%rax
movq -.F425-8(%rbp),%rbx
movq -.F425-16(%rbp),%r12
movq -.F425-24(%rbp),%r13
movq -.F425-32(%rbp),%r14
movq -.F425-40(%rbp),%r15
leave
ret
.set .F425,432
.type f_strings_char_count,@function
f_strings_char_count:
pushq %rbp
movq %rsp,%rbp
subq $.F481,%rsp
subq $48,%rsp
movq %rbx,-.F481-8(%rbp)
movq %r12,-.F481-16(%rbp)
movq %r13,-.F481-24(%rbp)
movq %r14,-.F481-32(%rbp)
movq %r15,-.F481-40(%rbp)
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
movq $1,%r14
leaq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_view
movq %rax,%r15
movq %rax,-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rax,%rdi
call f_strings_chars
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
movq $0,%r13
movq $1,-40(%rbp)
cmpq $0,%r13
je .L482
movq $0,%r13
movq -24(%rbp),%rdi
call .D22
.L482:
cmpq $0,%r12
je .L483
movq $0,%r12
movq -16(%rbp),%rdi
call .D4
.L483:
cmpq $0,%rbx
je .L484
movq $0,%rbx
movq %r15,%rdi
call .D4
.L484:
movq -32(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-48(%rbp)
cmpq $0,-40(%rbp)
je .L485
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D22
.L485:
cmpq $0,%r13
je .L486
movq -24(%rbp),%rdi
call .D22
.L486:
cmpq $0,%r12
je .L487
movq -16(%rbp),%rdi
call .D4
.L487:
cmpq $0,%rbx
je .L488
movq %r15,%rdi
call .D4
.L488:
cmpq $0,%r14
je .L489
movq -8(%rbp),%rdi
call .D8
.L489:
movq -48(%rbp),%rax
movq -.F481-8(%rbp),%rbx
movq -.F481-16(%rbp),%r12
movq -.F481-24(%rbp),%r13
movq -.F481-32(%rbp),%r14
movq -.F481-40(%rbp),%r15
leave
ret
cmpq $0,%r14
je .L490
movq $0,%r14
movq -8(%rbp),%rdi
call .D8
.L490:
cmpq $0,-40(%rbp)
je .L491
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D22
.L491:
cmpq $0,%r13
je .L492
movq $0,%r13
movq -24(%rbp),%rdi
call .D22
.L492:
cmpq $0,%r12
je .L493
movq $0,%r12
movq -16(%rbp),%rdi
call .D4
.L493:
cmpq $0,%rbx
je .L494
movq $0,%rbx
movq %r15,%rdi
call .D4
.L494:
cmpq $0,-40(%rbp)
je .L495
movq $0,-40(%rbp)
movq -32(%rbp),%rdi
call .D22
.L495:
cmpq $0,%r13
je .L496
movq -24(%rbp),%rdi
call .D22
.L496:
cmpq $0,%r12
je .L497
movq -16(%rbp),%rdi
call .D4
.L497:
cmpq $0,%rbx
je .L498
movq %r15,%rdi
call .D4
.L498:
cmpq $0,%r14
je .L499
movq -8(%rbp),%rdi
call .D8
.L499:
xorq %rax,%rax
movq -.F481-8(%rbp),%rbx
movq -.F481-16(%rbp),%r12
movq -.F481-24(%rbp),%r13
movq -.F481-32(%rbp),%r14
movq -.F481-40(%rbp),%r15
leave
ret
.set .F481,48
.type f_strings_push_char,@function
f_strings_push_char:
pushq %rbp
movq %rsp,%rbp
subq $.F500,%rsp
subq $16,%rsp
movq %rbx,-.F500-8(%rbp)
movq %r12,-.F500-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq %rsi,-16(%rbp)
leaq -.F500(%rbp),%rdi
movq $.F500/8-2,%rcx
xorl %eax,%eax
rep stosq
movq -16(%rbp),%rdi
movabsq $32,%rsi
movabsq $64,%rdx
call rt_int_cast
movq %rax,%rbx
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $1114111,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-32(%rbp)
movq $1,-40(%rbp)
movq $0,-48(%rbp)
cmpq $0,%rax
jne .L501
movq %rbx,%rax
cmpq $55296,%rbx
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-56(%rbp)
movq $0,-64(%rbp)
movq $0,-72(%rbp)
cmpq $0,%rax
je .L502
movabsq $57343,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq -72(%rbp),%rcx
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
movq %rax,-64(%rbp)
.L502:
movq -48(%rbp),%rcx
movq -64(%rbp),%rax
cmpq %rcx,%rax
setne %al
movzbq %al,%rax
movq %rax,-40(%rbp)
.L501:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L503
movq $65533,%rbx
jmp .L504
.L503:
.L504:
movabsq $128,%rcx
cmpq $128,%rbx
jae .L505
movq %r12,%rax
movq (%rax),%rax
movq %rax,%rdi
movq %rbx,%rsi
call rt_pushb_checked
movabsq $0,%rax
movq -.F500-8(%rbp),%rbx
movq -.F500-16(%rbp),%r12
leave
ret
jmp .L506
.L505:
.L506:
cmpq $2048,%rbx
jae .L507
movq %r12,%rax
movq (%rax),%rax
movq %rax,-80(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L509:
movq %rax,%rcx
movabsq $192,%rax
addq %rcx,%rax
jnc .L510
call rt_abort
.L510:
movq -80(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r12,%rax
movq (%rax),%rax
movq %rax,-88(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L511:
movq %rdx,%rcx
movabsq $128,%rax
addq %rdx,%rax
jnc .L512
call rt_abort
.L512:
movq -88(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movabsq $0,%rax
movq -.F500-8(%rbp),%rbx
movq -.F500-16(%rbp),%r12
leave
ret
jmp .L508
.L507:
.L508:
cmpq $65536,%rbx
jae .L513
movq %r12,%rax
movq (%rax),%rax
movq %rax,-96(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $4095,%rdx
shrq $12,%rax
.L515:
movq %rax,%rcx
movabsq $224,%rax
addq %rcx,%rax
jnc .L516
call rt_abort
.L516:
movq -96(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r12,%rax
movq (%rax),%rax
movq %rax,-104(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L517:
movq %rax,-112(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L518:
movq %rdx,%rcx
movabsq $128,%rax
addq %rdx,%rax
jnc .L519
call rt_abort
.L519:
movq -104(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r12,%rax
movq (%rax),%rax
movq %rax,-120(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L520:
movq %rdx,%rcx
movabsq $128,%rax
addq %rdx,%rax
jnc .L521
call rt_abort
.L521:
movq -120(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movabsq $0,%rax
movq -.F500-8(%rbp),%rbx
movq -.F500-16(%rbp),%r12
leave
ret
jmp .L514
.L513:
.L514:
movq %r12,%rax
movq (%rax),%rax
movq %rax,-128(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $262143,%rdx
shrq $18,%rax
.L522:
movq %rax,%rcx
movabsq $240,%rax
addq %rcx,%rax
jnc .L523
call rt_abort
.L523:
movq -128(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r12,%rax
movq (%rax),%rax
movq %rax,-136(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $4095,%rdx
shrq $12,%rax
.L524:
movq %rax,-144(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L525:
movq %rdx,%rcx
movabsq $128,%rax
addq %rdx,%rax
jnc .L526
call rt_abort
.L526:
movq -136(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r12,%rax
movq (%rax),%rax
movq %rax,-152(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L527:
movq %rax,-160(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L528:
movq %rdx,%rcx
movabsq $128,%rax
addq %rdx,%rax
jnc .L529
call rt_abort
.L529:
movq -152(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r12,%rax
movq (%rax),%rax
movq %rax,-168(%rbp)
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L530:
movq %rdx,%rcx
movabsq $128,%rax
addq %rdx,%rax
jnc .L531
call rt_abort
.L531:
movq -168(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movabsq $0,%rax
xorq $0,%rax
movq -.F500-8(%rbp),%rbx
movq -.F500-16(%rbp),%r12
leave
ret
.set .F500,176
.type f_strings_replace,@function
f_strings_replace:
pushq %rbp
movq %rsp,%rbp
subq $.F532,%rsp
subq $48,%rsp
movq %rbx,-.F532-8(%rbp)
movq %r12,-.F532-16(%rbp)
movq %r13,-.F532-24(%rbp)
movq %r14,-.F532-32(%rbp)
movq %r15,-.F532-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq %rdx,-24(%rbp)
leaq -.F532(%rbp),%rdi
movq $.F532/8-3,%rcx
xorl %eax,%eax
rep stosq
movq $1,-32(%rbp)
movq $1,-40(%rbp)
movq $1,-48(%rbp)
call rt_new
movq %rax,-56(%rbp)
movq $1,-64(%rbp)
movq %rax,-72(%rbp)
movq $0,-64(%rbp)
movq $1,-80(%rbp)
cmpq $0,-64(%rbp)
je .L533
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D2
.L533:
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,-88(%rbp)
cmpq $0,%rax
jne .L534
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-96(%rbp)
movq $0,-104(%rbp)
.L536:
movq -96(%rbp),%rcx
movq -104(%rbp),%rax
cmpq %rcx,%rax
jae .L538
movq %r14,%rdi
movq -104(%rbp),%rsi
cmpq 8(%rdi),%rsi
jb .Lopt26
call rt_abort
.Lopt26:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
.L537:
incq -104(%rbp)
jmp .L536
.L538:
movq $0,-80(%rbp)
cmpq $0,-80(%rbp)
je .L539
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D2
.L539:
cmpq $0,-64(%rbp)
je .L540
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D2
.L540:
cmpq $0,-48(%rbp)
je .L541
movq $0,-48(%rbp)
movq -24(%rbp),%rdi
call .D24
.L541:
cmpq $0,-40(%rbp)
je .L542
movq $0,-40(%rbp)
movq %r15,%rdi
call .D18
.L542:
cmpq $0,-32(%rbp)
je .L543
movq $0,-32(%rbp)
movq %r14,%rdi
call .D8
.L543:
movq -72(%rbp),%rax
movq -.F532-8(%rbp),%rbx
movq -.F532-16(%rbp),%r12
movq -.F532-24(%rbp),%r13
movq -.F532-32(%rbp),%r14
movq -.F532-40(%rbp),%r15
leave
ret
jmp .L535
.L534:
.L535:
movq $0,%r13
.L544:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq %r13,%rax
cmpq %rcx,%r13
setb %al
movzbq %al,%rax
testq %rax,%rax
jz .L545
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L546
call rt_abort
.L546:
movq %rax,-112(%rbp)
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-120(%rbp)
movq -112(%rbp),%rax
movq %rax,%rcx
movq -120(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
xorq $1,%rax
movq %rax,-128(%rbp)
testq %rax,%rax
jz .L547
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,-136(%rbp)
movq $0,%rbx
.L549:
movq -136(%rbp),%rcx
cmpq %rcx,%rbx
jae .L551
movq %r13,%rax
addq %rbx,%rax
jnc .L552
call rt_abort
.L552:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt27
call rt_abort
.Lopt27:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-144(%rbp)
movq %r15,%rdi
movq %rbx,%rsi
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
movq -144(%rbp),%rax
cmpq %rcx,%rax
je .L553
movq $0,-128(%rbp)
jmp .L551
jmp .L554
.L553:
.L554:
.L550:
incq %rbx
jmp .L549
.L551:
jmp .L548
.L547:
.L548:
movq -128(%rbp),%rax
testq %rax,%rax
jz .L555
movq -24(%rbp),%rdi
movq 8(%rdi),%rax
movq %rax,-152(%rbp)
movq $0,%r12
.L557:
movq -152(%rbp),%rcx
cmpq %rcx,%r12
jae .L559
movq -24(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt28
call rt_abort
.Lopt28:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
.L558:
incq %r12
jmp .L557
.L559:
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,-160(%rbp)
movq %r13,%rax
movq -160(%rbp),%rcx
addq %rcx,%rax
jnc .L560
call rt_abort
.L560:
movq %rax,%r13
jmp .L556
.L555:
movq %r14,%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt29
call rt_abort
.Lopt29:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_pushb_checked
movq %r13,%rax
addq $1,%rax
jnc .L561
call rt_abort
.L561:
movq %rax,%r13
.L556:
jmp .L544
.L545:
cmpq $0,-32(%rbp)
je .L562
movq $0,-32(%rbp)
movq %r14,%rdi
call .D8
.L562:
cmpq $0,-40(%rbp)
je .L563
movq $0,-40(%rbp)
movq %r15,%rdi
call .D18
.L563:
cmpq $0,-48(%rbp)
je .L564
movq $0,-48(%rbp)
movq -24(%rbp),%rdi
call .D24
.L564:
movq $0,-80(%rbp)
cmpq $0,-80(%rbp)
je .L565
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D2
.L565:
cmpq $0,-64(%rbp)
je .L566
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D2
.L566:
cmpq $0,-48(%rbp)
je .L567
movq $0,-48(%rbp)
movq -24(%rbp),%rdi
call .D24
.L567:
cmpq $0,-40(%rbp)
je .L568
movq $0,-40(%rbp)
movq %r15,%rdi
call .D18
.L568:
cmpq $0,-32(%rbp)
je .L569
movq $0,-32(%rbp)
movq %r14,%rdi
call .D8
.L569:
movq -72(%rbp),%rax
movq -.F532-8(%rbp),%rbx
movq -.F532-16(%rbp),%r12
movq -.F532-24(%rbp),%r13
movq -.F532-32(%rbp),%r14
movq -.F532-40(%rbp),%r15
leave
ret
cmpq $0,-32(%rbp)
je .L570
movq $0,-32(%rbp)
movq %r14,%rdi
call .D8
.L570:
cmpq $0,-40(%rbp)
je .L571
movq $0,-40(%rbp)
movq %r15,%rdi
call .D18
.L571:
cmpq $0,-48(%rbp)
je .L572
movq $0,-48(%rbp)
movq -24(%rbp),%rdi
call .D24
.L572:
cmpq $0,-80(%rbp)
je .L573
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D2
.L573:
cmpq $0,-64(%rbp)
je .L574
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D2
.L574:
cmpq $0,-80(%rbp)
je .L575
movq $0,-80(%rbp)
movq -72(%rbp),%rdi
call .D2
.L575:
cmpq $0,-64(%rbp)
je .L576
movq $0,-64(%rbp)
movq -56(%rbp),%rdi
call .D2
.L576:
cmpq $0,-48(%rbp)
je .L577
movq $0,-48(%rbp)
movq -24(%rbp),%rdi
call .D24
.L577:
cmpq $0,-40(%rbp)
je .L578
movq $0,-40(%rbp)
movq %r15,%rdi
call .D18
.L578:
cmpq $0,-32(%rbp)
je .L579
movq $0,-32(%rbp)
movq %r14,%rdi
call .D8
.L579:
xorq %rax,%rax
movq -.F532-8(%rbp),%rbx
movq -.F532-16(%rbp),%r12
movq -.F532-24(%rbp),%r13
movq -.F532-32(%rbp),%r14
movq -.F532-40(%rbp),%r15
leave
ret
.set .F532,160
.type f_strings_repeat,@function
f_strings_repeat:
pushq %rbp
movq %rsp,%rbp
subq $.F580,%rsp
subq $48,%rsp
movq %rbx,-.F580-8(%rbp)
movq %r12,-.F580-16(%rbp)
movq %r13,-.F580-24(%rbp)
movq %r14,-.F580-32(%rbp)
movq %r15,-.F580-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r12
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
movq $0,-64(%rbp)
movq $1,-24(%rbp)
call rt_new
movq %rax,-32(%rbp)
movq %rax,%r13
movq $0,%r15
movq $1,-40(%rbp)
cmpq $0,%r15
je .L581
movq $0,%r15
movq -32(%rbp),%rdi
call .D2
.L581:
movq -16(%rbp),%rax
movq %rax,-48(%rbp)
movq $0,-56(%rbp)
.L582:
movq -48(%rbp),%rcx
movq -56(%rbp),%rax
cmpq %rcx,%rax
jae .L584
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r14
movq $0,%rbx
.L585:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L587
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt30
call rt_abort
.Lopt30:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_pushb_checked
.L586:
incq %rbx
jmp .L585
.L587:
.L583:
incq -56(%rbp)
jmp .L582
.L584:
cmpq $0,-24(%rbp)
je .L588
movq $0,-24(%rbp)
movq %r12,%rdi
call .D8
.L588:
movq $0,-40(%rbp)
cmpq $0,-40(%rbp)
je .L589
movq $0,-40(%rbp)
movq %r13,%rdi
call .D2
.L589:
cmpq $0,%r15
je .L590
movq -32(%rbp),%rdi
call .D2
.L590:
cmpq $0,-24(%rbp)
je .L591
movq $0,-24(%rbp)
movq %r12,%rdi
call .D8
.L591:
movq %r13,%rax
movq -.F580-8(%rbp),%rbx
movq -.F580-16(%rbp),%r12
movq -.F580-24(%rbp),%r13
movq -.F580-32(%rbp),%r14
movq -.F580-40(%rbp),%r15
leave
ret
cmpq $0,-24(%rbp)
je .L592
movq $0,-24(%rbp)
movq %r12,%rdi
call .D8
.L592:
cmpq $0,-40(%rbp)
je .L593
movq $0,-40(%rbp)
movq %r13,%rdi
call .D2
.L593:
cmpq $0,%r15
je .L594
movq $0,%r15
movq -32(%rbp),%rdi
call .D2
.L594:
cmpq $0,-40(%rbp)
je .L595
movq $0,-40(%rbp)
movq %r13,%rdi
call .D2
.L595:
cmpq $0,%r15
je .L596
movq -32(%rbp),%rdi
call .D2
.L596:
cmpq $0,-24(%rbp)
je .L597
movq $0,-24(%rbp)
movq %r12,%rdi
call .D8
.L597:
xorq %rax,%rax
movq -.F580-8(%rbp),%rbx
movq -.F580-16(%rbp),%r12
movq -.F580-24(%rbp),%r13
movq -.F580-32(%rbp),%r14
movq -.F580-40(%rbp),%r15
leave
ret
.set .F580,64
.type rt_abort,@function
rt_abort:
pushq %rbp
movq %rsp,%rbp
subq $.F598,%rsp
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
.set .F598,16
.type rt_error,@function
rt_error:
pushq %rbp
movq %rsp,%rbp
subq $.F599,%rsp
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
.set .F599,16
.type rt_div,@function
rt_div:
pushq %rbp
movq %rsp,%rbp
subq $.F600,%rsp
subq $48,%rsp
movq %rbx,-.F600-8(%rbp)
movq %r12,-.F600-16(%rbp)
movq %r13,-.F600-24(%rbp)
movq %r14,-.F600-32(%rbp)
movq %r15,-.F600-40(%rbp)
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
jne .L601
call rt_abort
jmp .L602
.L601:
.L602:
movq $0,-24(%rbp)
movq -8(%rbp),%rax
movq %rax,-32(%rbp)
.L603:
movq -32(%rbp),%rax
movq -16(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L604
movq -16(%rbp),%rax
movq %rax,%rbx
movq $1,%r12
.L605:
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
jz .L606
movq %rbx,%rax
addq %rbx,%rax
jnc .L607
call rt_abort
.L607:
movq %rax,%rbx
movq %r12,%rax
addq %r12,%rax
jnc .L608
call rt_abort
.L608:
movq %rax,%r12
jmp .L605
.L606:
movq -32(%rbp),%rax
subq %rbx,%rax
jnc .L609
call rt_abort
.L609:
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
addq %r12,%rax
jnc .L610
call rt_abort
.L610:
movq %rax,-24(%rbp)
jmp .L603
.L604:
movq -24(%rbp),%rax
movq -.F600-8(%rbp),%rbx
movq -.F600-16(%rbp),%r12
movq -.F600-24(%rbp),%r13
movq -.F600-32(%rbp),%r14
movq -.F600-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F600-8(%rbp),%rbx
movq -.F600-16(%rbp),%r12
movq -.F600-24(%rbp),%r13
movq -.F600-32(%rbp),%r14
movq -.F600-40(%rbp),%r15
leave
ret
.set .F600,48
.type rt_allocator_lock,@function
rt_allocator_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F611,%rsp
subq $16,%rsp
movq %rbx,-.F611-8(%rbp)
movq %r12,-.F611-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
addq $64,%rax
jnc .L612
call rt_abort
.L612:
movq %rax,%r12
.L613:
movq %r12,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%rbx
cmpq $0,%rax
je .L614
jmp .L613
.L614:
movabsq $0,%rax
movq -.F611-8(%rbp),%rbx
movq -.F611-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F611-8(%rbp),%rbx
movq -.F611-16(%rbp),%r12
leave
ret
.set .F611,16
.type rt_allocator_unlock,@function
rt_allocator_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F615,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $64,%rcx
movq -8(%rbp),%rax
addq $64,%rax
jnc .L616
call rt_abort
.L616:
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
.set .F615,16
.type rt_alloc,@function
rt_alloc:
pushq %rbp
movq %rsp,%rbp
subq $.F617,%rsp
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
.set .F617,16
.type rt_free,@function
rt_free:
pushq %rbp
movq %rsp,%rbp
subq $.F618,%rsp
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
.set .F618,16
.type rt_alloc_unlocked,@function
rt_alloc_unlocked:
pushq %rbp
movq %rsp,%rbp
subq $.F619,%rsp
subq $48,%rsp
movq %rbx,-.F619-8(%rbp)
movq %r12,-.F619-16(%rbp)
movq %r13,-.F619-24(%rbp)
movq %r14,-.F619-32(%rbp)
movq %r15,-.F619-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F619(%rbp),%rdi
movq $.F619/8-1,%rcx
xorl %eax,%eax
rep stosq
leaq rt_state(%rip),%rax
movq %rax,%r14
movq -8(%rbp),%rcx
movabsq $1152921504606846976,%rax
cmpq %rcx,%rax
jae .L620
call rt_abort
jmp .L621
.L620:
.L621:
movq $32,%rbx
movq $0,%r13
.L622:
movq -8(%rbp),%rax
addq $16,%rax
jnc .L624
call rt_abort
.L624:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L623
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L625
call rt_abort
.L625:
movq %rax,%rbx
movq %r13,%rax
addq $1,%rax
jnc .L626
call rt_abort
.L626:
movq %rax,%r13
jmp .L622
.L623:
movq %r14,%rax
addq $256,%rax
jnc .L627
call rt_abort
.L627:
movq %rax,-16(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L628
call rt_abort
.L628:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L629
call rt_abort
.L629:
movq %rax,-24(%rbp)
movq (%rax),%rax
movq %rax,%r15
movq $0,-32(%rbp)
cmpq $0,%rax
je .L630
movq %r15,%rax
addq $8,%rax
jnc .L632
call rt_abort
.L632:
movq (%rax),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $1,-32(%rbp)
jmp .L631
.L630:
movq %r14,%rax
addq $768,%rax
jnc .L633
call rt_abort
.L633:
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L634
call rt_abort
.L634:
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L635
call rt_abort
.L635:
movq %rax,-48(%rbp)
movq %r14,%rax
addq $1280,%rax
jnc .L636
call rt_abort
.L636:
movq %rax,-56(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L637
call rt_abort
.L637:
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L638
call rt_abort
.L638:
movq %rax,-64(%rbp)
movq (%rax),%rax
movq %rax,-72(%rbp)
cmpq $0,%rax
jne .L639
movq $1048576,-80(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L641
call rt_abort
.L641:
movq %rax,%rcx
movabsq $1048576,%rax
cmpq %rcx,%rax
jae .L642
movabsq $16,%rcx
movq %rbx,%rax
addq $16,%rax
jnc .L644
call rt_abort
.L644:
movq %rax,-80(%rbp)
jmp .L643
.L642:
.L643:
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
jz .L645
call rt_abort
jmp .L646
.L645:
.L646:
movq %r14,%rax
addq $32,%rax
jnc .L647
call rt_abort
.L647:
movq (%rax),%rax
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rcx,%rax
addq $8,%rax
jnc .L648
call rt_abort
.L648:
movq %rax,-96(%rbp)
movq -80(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r14,%rax
addq $32,%rax
jnc .L649
call rt_abort
.L649:
movq %rax,-104(%rbp)
movq -88(%rbp),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $16,%rax
jnc .L650
call rt_abort
.L650:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $16,%rcx
movq -80(%rbp),%rax
subq $16,%rax
jnc .L651
call rt_abort
.L651:
movq %rax,-112(%rbp)
movq -112(%rbp),%rdi
movq %rbx,%rsi
call rt_div
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L640
.L639:
.L640:
movq -48(%rbp),%rax
movq (%rax),%rax
movq %rax,%r15
addq %rbx,%rax
jnc .L652
call rt_abort
.L652:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -64(%rbp),%rax
movq (%rax),%rax
movq %rax,-120(%rbp)
subq $1,%rax
jnc .L653
call rt_abort
.L653:
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
movq %r15,%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
.L631:
movq %r15,%rax
addq $8,%rax
jnc .L654
call rt_abort
.L654:
movq %rax,-128(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %r15,%rax
addq $16,%rax
jnc .L655
call rt_abort
.L655:
movq %rax,-136(%rbp)
movq -32(%rbp),%rax
testq %rax,%rax
jz .L656
movq $0,%r12
.L658:
movq %rbx,%rax
subq $16,%rax
jnc .L660
call rt_abort
.L660:
movq %rax,%rcx
cmpq %rcx,%r12
jae .L659
movq -136(%rbp),%rax
addq %r12,%rax
jnc .L661
call rt_abort
.L661:
movq %rax,-144(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r12,%rax
addq $8,%rax
jnc .L662
call rt_abort
.L662:
movq %rax,%r12
jmp .L658
.L659:
jmp .L657
.L656:
.L657:
movq %r14,%rax
addq $24,%rax
jnc .L663
call rt_abort
.L663:
movq %rax,-152(%rbp)
movq %r14,%rax
addq $24,%rax
jnc .L664
call rt_abort
.L664:
movq (%rax),%rax
movq %rax,-160(%rbp)
addq $1,%rax
jnc .L665
call rt_abort
.L665:
movq -152(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -136(%rbp),%rax
movq -.F619-8(%rbp),%rbx
movq -.F619-16(%rbp),%r12
movq -.F619-24(%rbp),%r13
movq -.F619-32(%rbp),%r14
movq -.F619-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F619-8(%rbp),%rbx
movq -.F619-16(%rbp),%r12
movq -.F619-24(%rbp),%r13
movq -.F619-32(%rbp),%r14
movq -.F619-40(%rbp),%r15
leave
ret
.set .F619,160
.type rt_free_unlocked,@function
rt_free_unlocked:
pushq %rbp
movq %rsp,%rbp
subq $.F666,%rsp
subq $48,%rsp
movq %rbx,-.F666-8(%rbp)
movq %r12,-.F666-16(%rbp)
movq %r13,-.F666-24(%rbp)
movq %r14,-.F666-32(%rbp)
movq %r15,-.F666-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F666(%rbp),%rdi
movq $.F666/8-1,%rcx
xorl %eax,%eax
rep stosq
movq -8(%rbp),%rax
cmpq $0,%rax
jne .L667
movabsq $0,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
movq -.F666-32(%rbp),%r14
movq -.F666-40(%rbp),%r15
leave
ret
jmp .L668
.L667:
.L668:
leaq rt_state(%rip),%rax
movq %rax,-16(%rbp)
movq -8(%rbp),%rax
subq $16,%rax
jnc .L669
call rt_abort
.L669:
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
addq $8,%rax
jnc .L670
call rt_abort
.L670:
movq (%rax),%rax
movq %rax,-40(%rbp)
cmpq $2,%rax
jne .L671
movabsq $0,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
movq -.F666-32(%rbp),%r14
movq -.F666-40(%rbp),%r15
leave
ret
jmp .L672
.L671:
.L672:
movq -24(%rbp),%rax
addq $8,%rax
jnc .L673
call rt_abort
.L673:
movq (%rax),%rax
movq %rax,-48(%rbp)
movabsq $1,%rcx
cmpq $1,%rax
je .L674
call rt_abort
jmp .L675
.L674:
.L675:
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
cmpq $524288,%rax
setb %al
movzbq %al,%rax
movq %rax,-72(%rbp)
cmpq $0,%rax
jne .L676
movq -8(%rbp),%rax
subq $32,%rax
jnc .L678
call rt_abort
.L678:
movq %rax,%r14
movq -16(%rbp),%rax
addq $32,%rax
jnc .L679
call rt_abort
.L679:
movq %rax,%rbx
.L680:
movq %rbx,%rax
movq (%rax),%rax
cmpq %r14,%rax
je .L681
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%r15
movq %rax,-80(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L682
call rt_abort
jmp .L683
.L682:
.L683:
movq %r15,%rbx
jmp .L680
.L681:
movq %r14,%rax
addq $8,%rax
jnc .L684
call rt_abort
.L684:
movq (%rax),%rax
movq %rax,-88(%rbp)
movq %r14,%rax
movq (%rax),%rax
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -16(%rbp),%rax
addq $24,%rax
jnc .L685
call rt_abort
.L685:
movq %rax,-96(%rbp)
movq -16(%rbp),%rax
addq $24,%rax
jnc .L686
call rt_abort
.L686:
movq (%rax),%rax
movq %rax,-104(%rbp)
subq $1,%rax
jnc .L687
call rt_abort
.L687:
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
jz .L688
call rt_abort
jmp .L689
.L688:
.L689:
movabsq $0,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
movq -.F666-32(%rbp),%r14
movq -.F666-40(%rbp),%r15
leave
ret
jmp .L677
.L676:
.L677:
movq $32,%r12
movq $0,%r13
.L690:
movq -56(%rbp),%rcx
cmpq %rcx,%r12
jae .L691
movabsq $2,%rcx
movq %r12,%rax
mulq %rcx
jnc .L692
call rt_abort
.L692:
movq %rax,%r12
movq %r13,%rax
addq $1,%rax
jnc .L693
call rt_abort
.L693:
movq %rax,%r13
jmp .L690
.L691:
movq -16(%rbp),%rax
addq $256,%rax
jnc .L694
call rt_abort
.L694:
movq %rax,-112(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L695
call rt_abort
.L695:
movq %rax,%rcx
movq -112(%rbp),%rax
addq %rcx,%rax
jnc .L696
call rt_abort
.L696:
movq %rax,-120(%rbp)
movq -24(%rbp),%rax
addq $8,%rax
jnc .L697
call rt_abort
.L697:
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
jnc .L698
call rt_abort
.L698:
movq %rax,-136(%rbp)
movq -16(%rbp),%rax
addq $24,%rax
jnc .L699
call rt_abort
.L699:
movq (%rax),%rax
movq %rax,-144(%rbp)
subq $1,%rax
jnc .L700
call rt_abort
.L700:
movq -136(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
movq -.F666-32(%rbp),%r14
movq -.F666-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F666-8(%rbp),%rbx
movq -.F666-16(%rbp),%r12
movq -.F666-24(%rbp),%r13
movq -.F666-32(%rbp),%r14
movq -.F666-40(%rbp),%r15
leave
ret
.set .F666,144
.type rt_grow,@function
rt_grow:
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
jne .L702
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq -.F701-8(%rbp),%rbx
movq -.F701-16(%rbp),%r12
movq -.F701-24(%rbp),%r13
movq -.F701-32(%rbp),%r14
movq -.F701-40(%rbp),%r15
leave
ret
jmp .L703
.L702:
.L703:
movq %r15,%rax
subq $16,%rax
jnc .L704
call rt_abort
.L704:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,-40(%rbp)
cmpq $524288,%rax
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L705
movq -32(%rbp),%rax
movq %rax,%rbx
.L707:
movq -24(%rbp),%rax
addq $16,%rax
jnc .L709
call rt_abort
.L709:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L708
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L710
call rt_abort
.L710:
movq %rax,%rbx
jmp .L707
.L708:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jne .L711
movq %r15,%rax
movq -.F701-8(%rbp),%rbx
movq -.F701-16(%rbp),%r12
movq -.F701-24(%rbp),%r13
movq -.F701-32(%rbp),%r14
movq -.F701-40(%rbp),%r15
leave
ret
jmp .L712
.L711:
.L712:
call rt_allocator_lock
leaq rt_state(%rip),%rax
movq %rax,-56(%rbp)
movq %r15,%rax
subq $32,%rax
jnc .L713
call rt_abort
.L713:
movq %rax,-64(%rbp)
movq -56(%rbp),%rax
addq $32,%rax
jnc .L714
call rt_abort
.L714:
movq %rax,%r12
.L715:
movq %r12,%rax
movq (%rax),%rax
movq -64(%rbp),%rcx
cmpq %rcx,%rax
je .L716
movq %r12,%rax
movq (%rax),%rax
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
jne .L717
call rt_abort
jmp .L718
.L717:
.L718:
movq %r13,%r12
jmp .L715
.L716:
movq -64(%rbp),%rax
addq $8,%rax
jnc .L719
call rt_abort
.L719:
movq (%rax),%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L720
call rt_abort
.L720:
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
jz .L721
call rt_abort
jmp .L722
.L721:
.L722:
movq -88(%rbp),%rax
movq %r12,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $8,%rax
jnc .L723
call rt_abort
.L723:
movq %rax,-96(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L724
call rt_abort
.L724:
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -88(%rbp),%rax
addq $16,%rax
jnc .L725
call rt_abort
.L725:
movq %rax,-104(%rbp)
movq %rbx,%rax
movq -104(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
call rt_allocator_unlock
movq -88(%rbp),%rax
addq $32,%rax
jnc .L726
call rt_abort
.L726:
movq -.F701-8(%rbp),%rbx
movq -.F701-16(%rbp),%r12
movq -.F701-24(%rbp),%r13
movq -.F701-32(%rbp),%r14
movq -.F701-40(%rbp),%r15
leave
ret
jmp .L706
.L705:
.L706:
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
.set .F701,128
.type rt_live,@function
rt_live:
pushq %rbp
movq %rsp,%rbp
subq $.F727,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
call rt_allocator_lock
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movabsq $24,%rcx
movq -8(%rbp),%rax
addq $24,%rax
jnc .L728
call rt_abort
.L728:
movq (%rax),%rax
movq %rax,-16(%rbp)
call rt_allocator_unlock
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F727,16
.type rt_shutdown,@function
rt_shutdown:
pushq %rbp
movq %rsp,%rbp
subq $.F729,%rsp
subq $32,%rsp
movq %rbx,-.F729-8(%rbp)
movq %r12,-.F729-16(%rbp)
movq %r13,-.F729-24(%rbp)
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
jnc .L730
call rt_abort
.L730:
movq (%rax),%rax
movq %rax,%rbx
.L731:
cmpq $0,%rbx
je .L732
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $8,%rax
jnc .L733
call rt_abort
.L733:
movq (%rax),%rax
movabsq $11,%rdi
movq %rbx,%rsi
movq %rax,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r12,%rbx
jmp .L731
.L732:
movq -8(%rbp),%rax
addq $32,%rax
jnc .L734
call rt_abort
.L734:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movabsq $0,%rax
movq -.F729-8(%rbp),%rbx
movq -.F729-16(%rbp),%r12
movq -.F729-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F729-8(%rbp),%rbx
movq -.F729-16(%rbp),%r12
movq -.F729-24(%rbp),%r13
leave
ret
.set .F729,32
.type rt_new,@function
rt_new:
pushq %rbp
movq %rsp,%rbp
subq $.F735,%rsp
movabsq $24,%rdi
call rt_alloc
leave
ret
xorq %rax,%rax
leave
ret
.set .F735,32
.type rt_push,@function
rt_push:
pushq %rbp
movq %rsp,%rbp
subq $.F736,%rsp
subq $32,%rsp
movq %rbx,-.F736-8(%rbp)
movq %r12,-.F736-16(%rbp)
movq %r13,-.F736-24(%rbp)
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
jnc .L737
call rt_abort
.L737:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L738
call rt_abort
.L738:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L739
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L741
call rt_abort
.L741:
movq %rax,%r13
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L742
movq $8,%r13
jmp .L743
.L742:
.L743:
movq %r13,%rcx
movabsq $144115188075855872,%rax
cmpq %r13,%rax
jae .L744
call rt_abort
jmp .L745
.L744:
.L745:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L746
call rt_abort
.L746:
movq %rax,-48(%rbp)
movabsq $8,%rcx
movq %r13,%rax
mulq %rcx
jnc .L747
call rt_abort
.L747:
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
jnc .L748
call rt_abort
.L748:
movq %rax,-64(%rbp)
movq %r13,%rax
movq -64(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
jmp .L740
.L739:
.L740:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L749
call rt_abort
.L749:
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L750
call rt_abort
.L750:
movq %rax,-80(%rbp)
movq -16(%rbp),%rax
movq -80(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L751
call rt_abort
.L751:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L752
call rt_abort
.L752:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F736-8(%rbp),%rbx
movq -.F736-16(%rbp),%r12
movq -.F736-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F736-8(%rbp),%rbx
movq -.F736-16(%rbp),%r12
movq -.F736-24(%rbp),%r13
leave
ret
.set .F736,96
.type rt_fill,@function
rt_fill:
pushq %rbp
movq %rsp,%rbp
subq $.F753,%rsp
subq $48,%rsp
movq %rbx,-.F753-8(%rbp)
movq %r12,-.F753-16(%rbp)
movq %r13,-.F753-24(%rbp)
movq %r14,-.F753-32(%rbp)
movq %r15,-.F753-40(%rbp)
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
jae .L754
call rt_abort
jmp .L755
.L754:
.L755:
cmpq $0,%r12
je .L756
movq %r13,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L758
call rt_abort
.L758:
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
jnc .L759
call rt_abort
.L759:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L757
.L756:
.L757:
movq $0,%rbx
.L760:
cmpq %r12,%rbx
jae .L761
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r14
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L762
call rt_abort
.L762:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L763
call rt_abort
.L763:
movq %rax,%r15
movq -16(%rbp),%rax
movq %r15,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L764
call rt_abort
.L764:
movq %rax,%rbx
jmp .L760
.L761:
movq %r13,%rax
addq $8,%rax
jnc .L765
call rt_abort
.L765:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movabsq $0,%rax
movq -.F753-8(%rbp),%rbx
movq -.F753-16(%rbp),%r12
movq -.F753-24(%rbp),%r13
movq -.F753-32(%rbp),%r14
movq -.F753-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F753-8(%rbp),%rbx
movq -.F753-16(%rbp),%r12
movq -.F753-24(%rbp),%r13
movq -.F753-32(%rbp),%r14
movq -.F753-40(%rbp),%r15
leave
ret
.set .F753,64
.type rt_fillb,@function
rt_fillb:
pushq %rbp
movq %rsp,%rbp
subq $.F766,%rsp
subq $48,%rsp
movq %rbx,-.F766-8(%rbp)
movq %r12,-.F766-16(%rbp)
movq %r13,-.F766-24(%rbp)
movq %r14,-.F766-32(%rbp)
movq %r15,-.F766-40(%rbp)
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
jae .L767
call rt_abort
jmp .L768
.L767:
.L768:
movq %r13,%rdi
movq %r14,%rsi
call rt_reserveb
movq $0,%rbx
.L769:
cmpq %r14,%rbx
jae .L770
movq %r13,%rax
movq (%rax),%rax
addq %rbx,%rax
jnc .L771
call rt_abort
.L771:
movq %rax,%r12
movq %r15,%rax
movq %r12,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L772
call rt_abort
.L772:
movq %rax,%rbx
jmp .L769
.L770:
movq %r13,%rax
addq $8,%rax
jnc .L773
call rt_abort
.L773:
movq %rax,-32(%rbp)
movq %r14,%rax
movq -32(%rbp),%rcx
movq %r14,(%rcx)
xorq %r14,%rax
movabsq $0,%rax
movq -.F766-8(%rbp),%rbx
movq -.F766-16(%rbp),%r12
movq -.F766-24(%rbp),%r13
movq -.F766-32(%rbp),%r14
movq -.F766-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F766-8(%rbp),%rbx
movq -.F766-16(%rbp),%r12
movq -.F766-24(%rbp),%r13
movq -.F766-32(%rbp),%r14
movq -.F766-40(%rbp),%r15
leave
ret
.set .F766,32
.type rt_pushb,@function
rt_pushb:
pushq %rbp
movq %rsp,%rbp
subq $.F774,%rsp
subq $16,%rsp
movq %rbx,-.F774-8(%rbp)
movq %r12,-.F774-16(%rbp)
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
jnc .L775
call rt_abort
.L775:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L776
call rt_abort
.L776:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L777
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L779
call rt_abort
.L779:
movq %rbx,%rdi
movq %rax,%rsi
call rt_reserveb
jmp .L778
.L777:
.L778:
movq %rbx,%rax
movq (%rax),%rax
addq %r12,%rax
jnc .L780
call rt_abort
.L780:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
andq $255,%rax
movq -32(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L781
call rt_abort
.L781:
movq %rax,-40(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L782
call rt_abort
.L782:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F774-8(%rbp),%rbx
movq -.F774-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F774-8(%rbp),%rbx
movq -.F774-16(%rbp),%r12
leave
ret
.set .F774,48
.type rt_pushb_checked,@function
rt_pushb_checked:
pushq %rbp
movq %rsp,%rbp
subq $.F783,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rcx
movabsq $255,%rax
cmpq %rcx,%rax
jae .L784
call rt_abort
jmp .L785
.L784:
.L785:
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
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
leave
ret
xorq %rax,%rax
leave
ret
.set .F783,16
.type rt_reserveb,@function
rt_reserveb:
pushq %rbp
movq %rsp,%rbp
subq $.F786,%rsp
subq $32,%rsp
movq %rbx,-.F786-8(%rbp)
movq %r12,-.F786-16(%rbp)
movq %r13,-.F786-24(%rbp)
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
jnc .L787
call rt_abort
.L787:
movq (%rax),%rax
movq %rax,-24(%rbp)
addq $1,%rax
jnc .L788
call rt_abort
.L788:
movq %rax,%rcx
cmpq %rcx,%r13
jae .L789
movabsq $0,%rax
movq -.F786-8(%rbp),%rbx
movq -.F786-16(%rbp),%r12
movq -.F786-24(%rbp),%r13
leave
ret
jmp .L790
.L789:
.L790:
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L791
call rt_abort
.L791:
movq %rax,%rbx
movq %rax,-32(%rbp)
cmpq $16,%rax
jae .L792
movq $16,%rbx
jmp .L793
.L792:
.L793:
.L794:
cmpq %r13,%rbx
jae .L795
movabsq $2,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L796
call rt_abort
.L796:
movq %rax,%rbx
jmp .L794
.L795:
movq %rbx,%rcx
movabsq $1152921504606846976,%rax
cmpq %rbx,%rax
jae .L797
call rt_abort
jmp .L798
.L797:
.L798:
movabsq $8,%rcx
movq %r12,%rax
addq $8,%rax
jnc .L799
call rt_abort
.L799:
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
jnc .L800
call rt_abort
.L800:
movq %rax,-64(%rbp)
movq %rbx,%rax
movq -64(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movabsq $0,%rax
movq -.F786-8(%rbp),%rbx
movq -.F786-16(%rbp),%r12
movq -.F786-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F786-8(%rbp),%rbx
movq -.F786-16(%rbp),%r12
movq -.F786-24(%rbp),%r13
leave
ret
.set .F786,64
.type rt_copy_bytes,@function
rt_copy_bytes:
pushq %rbp
movq %rsp,%rbp
subq $.F801,%rsp
subq $48,%rsp
movq %rbx,-.F801-8(%rbp)
movq %r12,-.F801-16(%rbp)
movq %r13,-.F801-24(%rbp)
movq %r14,-.F801-32(%rbp)
movq %r15,-.F801-40(%rbp)
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
.L802:
movq %rbx,%rax
addq $8,%rax
jnc .L804
call rt_abort
.L804:
movq %rax,%r15
movq %r14,%rax
addq $1,%rax
jnc .L805
call rt_abort
.L805:
movq %rax,%rcx
cmpq %rcx,%r15
jae .L803
movq %r12,%rax
addq %rbx,%rax
jnc .L806
call rt_abort
.L806:
movq %rax,-32(%rbp)
movq %r13,%rax
addq %rbx,%rax
jnc .L807
call rt_abort
.L807:
movq (%rax),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L808
call rt_abort
.L808:
movq %rax,%rbx
jmp .L802
.L803:
.L809:
cmpq %r14,%rbx
jae .L810
movq %r12,%rax
addq %rbx,%rax
jnc .L811
call rt_abort
.L811:
movq %rax,-40(%rbp)
movq %r13,%rax
addq %rbx,%rax
jnc .L812
call rt_abort
.L812:
movzbq (%rax),%rax
movq -40(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L813
call rt_abort
.L813:
movq %rax,%rbx
jmp .L809
.L810:
movabsq $0,%rax
movq -.F801-8(%rbp),%rbx
movq -.F801-16(%rbp),%r12
movq -.F801-24(%rbp),%r13
movq -.F801-32(%rbp),%r14
movq -.F801-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F801-8(%rbp),%rbx
movq -.F801-16(%rbp),%r12
movq -.F801-24(%rbp),%r13
movq -.F801-32(%rbp),%r14
movq -.F801-40(%rbp),%r15
leave
ret
.set .F801,48
.type rt_bytes_truncate,@function
rt_bytes_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F814,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L815
call rt_abort
.L815:
movq (%rax),%rax
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
jae .L816
movq -8(%rbp),%rax
addq $8,%rax
jnc .L818
call rt_abort
.L818:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L817
.L816:
.L817:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F814,32
.type rt_popb,@function
rt_popb:
pushq %rbp
movq %rsp,%rbp
subq $.F819,%rsp
subq $16,%rsp
movq %rbx,-.F819-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L820
call rt_abort
.L820:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L821
call rt_abort
jmp .L822
.L821:
.L822:
movq %rbx,%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L823
call rt_abort
.L823:
movq %rax,-32(%rbp)
subq $1,%rax
jnc .L824
call rt_abort
.L824:
movzbq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L825
call rt_abort
.L825:
movq %rax,-48(%rbp)
movq %rcx,%rax
subq $1,%rax
jnc .L826
call rt_abort
.L826:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F819-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F819-8(%rbp),%rbx
leave
ret
.set .F819,48
.type rt_random_seed,@function
rt_random_seed:
pushq %rbp
movq %rsp,%rbp
subq $.F827,%rsp
subq $48,%rsp
movq %rbx,-.F827-8(%rbp)
movq %r12,-.F827-16(%rbp)
movq %r13,-.F827-24(%rbp)
movq %r14,-.F827-32(%rbp)
movq %r15,-.F827-40(%rbp)
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
.L828:
movabsq $8,%rcx
cmpq $8,%rbx
jae .L829
movq $318,%r13
movabsq $0,%rax
cmpq $0,%rax
je .L830
movq $278,%r13
jmp .L831
.L830:
.L831:
movq -8(%rbp),%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L832
call rt_abort
.L832:
movq %rax,%r14
movabsq $8,%rax
subq %rbx,%rax
jnc .L833
call rt_abort
.L833:
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
jne .L834
jmp .L835
.L834:
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movabsq $8,%rax
subq %rbx,%rax
jnc .L836
call rt_abort
.L836:
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L837
call rt_abort
.L837:
testq %rax,%rax
jz .L838
call rt_abort
jmp .L839
.L838:
.L839:
movq %rbx,%rax
addq %r12,%rax
jnc .L840
call rt_abort
.L840:
movq %rax,%rbx
.L835:
jmp .L828
.L829:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F827-8(%rbp),%rbx
movq -.F827-16(%rbp),%r12
movq -.F827-24(%rbp),%r13
movq -.F827-32(%rbp),%r14
movq -.F827-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F827-8(%rbp),%rbx
movq -.F827-16(%rbp),%r12
movq -.F827-24(%rbp),%r13
movq -.F827-32(%rbp),%r14
movq -.F827-40(%rbp),%r15
leave
ret
.set .F827,32
.type rt_slotu,@function
rt_slotu:
pushq %rbp
movq %rsp,%rbp
subq $.F841,%rsp
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
jnc .L842
call rt_abort
.L842:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L843
call rt_abort
.L843:
leave
ret
xorq %rax,%rax
leave
ret
.set .F841,32
.type rt_slotb,@function
rt_slotb:
pushq %rbp
movq %rsp,%rbp
subq $.F844,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L845
call rt_abort
.L845:
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
jne .L846
call rt_abort
jmp .L847
.L846:
.L847:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L848
call rt_abort
.L848:
leave
ret
xorq %rax,%rax
leave
ret
.set .F844,32
.type rt_atbu,@function
rt_atbu:
pushq %rbp
movq %rsp,%rbp
subq $.F849,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L850
call rt_abort
.L850:
movzbq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F849,16
.type rt_atb,@function
rt_atb:
pushq %rbp
movq %rsp,%rbp
subq $.F851,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L852
call rt_abort
.L852:
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
jne .L853
call rt_abort
jmp .L854
.L853:
.L854:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L855
call rt_abort
.L855:
movzbq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F851,32
.type rt_pop,@function
rt_pop:
pushq %rbp
movq %rsp,%rbp
subq $.F856,%rsp
subq $16,%rsp
movq %rbx,-.F856-8(%rbp)
movq %r12,-.F856-16(%rbp)
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
jnc .L857
call rt_abort
.L857:
movq (%rax),%rax
movq %rax,%r12
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L858
call rt_abort
jmp .L859
.L858:
.L859:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L860
call rt_abort
.L860:
movq %rax,-32(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L861
call rt_abort
.L861:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L862
call rt_abort
.L862:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-48(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L863
call rt_abort
.L863:
movq %rax,-56(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L864
call rt_abort
.L864:
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L865
call rt_abort
.L865:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L866
call rt_abort
.L866:
movq %rax,-72(%rbp)
movq %r12,%rax
subq $1,%rax
jnc .L867
call rt_abort
.L867:
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F856-8(%rbp),%rbx
movq -.F856-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F856-8(%rbp),%rbx
movq -.F856-16(%rbp),%r12
leave
ret
.set .F856,80
.type rt_len,@function
rt_len:
pushq %rbp
movq %rsp,%rbp
subq $.F868,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L869
call rt_abort
.L869:
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F868,16
.type rt_slot,@function
rt_slot:
pushq %rbp
movq %rsp,%rbp
subq $.F870,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L871
call rt_abort
.L871:
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
jne .L872
call rt_abort
jmp .L873
.L872:
.L873:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L874
call rt_abort
.L874:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L875
call rt_abort
.L875:
leave
ret
xorq %rax,%rax
leave
ret
.set .F870,32
.type rt_take,@function
rt_take:
pushq %rbp
movq %rsp,%rbp
subq $.F876,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt33
call rt_abort
.Lopt33:
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
.set .F876,32
.type rt_at,@function
rt_at:
pushq %rbp
movq %rsp,%rbp
subq $.F877,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt35
call rt_abort
.Lopt35:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F877,16
.type rt_write,@function
rt_write:
pushq %rbp
movq %rsp,%rbp
subq $.F878,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L879
call rt_abort
.L879:
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
jnc .L880
call rt_abort
.L880:
testq %rax,%rax
jz .L881
call rt_abort
jmp .L882
.L881:
.L882:
movq -8(%rbp),%rax
movq (%rax),%rax
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L883
call rt_abort
.L883:
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
.set .F878,48
.type rt_slice,@function
rt_slice:
pushq %rbp
movq %rsp,%rbp
subq $.F884,%rsp
subq $16,%rsp
movq %rbx,-.F884-8(%rbp)
movq %r12,-.F884-16(%rbp)
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
jnc .L885
call rt_abort
.L885:
movq (%rax),%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L886
call rt_abort
.L886:
testq %rax,%rax
jz .L887
call rt_abort
jmp .L888
.L887:
.L888:
movabsq $24,%rdi
call rt_alloc
movq %rax,-40(%rbp)
movq %rax,-48(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
addq %rbx,%rax
jnc .L889
call rt_abort
.L889:
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
addq $8,%rax
jnc .L890
call rt_abort
.L890:
movq %rax,-56(%rbp)
movq %r12,%rax
subq %rbx,%rax
jnc .L891
call rt_abort
.L891:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -40(%rbp),%rax
movq -.F884-8(%rbp),%rbx
movq -.F884-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F884-8(%rbp),%rbx
movq -.F884-16(%rbp),%r12
leave
ret
.set .F884,64
.type rt_vslice,@function
rt_vslice:
pushq %rbp
movq %rsp,%rbp
subq $.F892,%rsp
subq $16,%rsp
movq %rbx,-.F892-8(%rbp)
movq %r12,-.F892-16(%rbp)
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
jnc .L893
call rt_abort
.L893:
movq (%rax),%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L894
call rt_abort
.L894:
testq %rax,%rax
jz .L895
call rt_abort
jmp .L896
.L895:
.L896:
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
jnc .L897
call rt_abort
.L897:
movq %rax,%rcx
movq -64(%rbp),%rax
addq %rcx,%rax
jnc .L898
call rt_abort
.L898:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
addq $8,%rax
jnc .L899
call rt_abort
.L899:
movq %rax,-72(%rbp)
movq %r12,%rax
subq %rbx,%rax
jnc .L900
call rt_abort
.L900:
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
movq -.F892-8(%rbp),%rbx
movq -.F892-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F892-8(%rbp),%rbx
movq -.F892-16(%rbp),%r12
leave
ret
.set .F892,80
.type rt_view,@function
rt_view:
pushq %rbp
movq %rsp,%rbp
subq $.F901,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L902
call rt_abort
.L902:
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
.set .F901,16
.type rt_load_sized,@function
rt_load_sized:
pushq %rbp
movq %rsp,%rbp
subq $.F903,%rsp
subq $48,%rsp
movq %rbx,-.F903-8(%rbp)
movq %r12,-.F903-16(%rbp)
movq %r13,-.F903-24(%rbp)
movq %r14,-.F903-32(%rbp)
movq %r15,-.F903-40(%rbp)
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
.L904:
cmpq %r14,%rbx
jae .L905
movq %r15,%rax
addq %rbx,%rax
jnc .L906
call rt_abort
.L906:
movzbq (%rax),%rax
movq %r12,%rcx
mulq %rcx
jnc .L907
call rt_abort
.L907:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L908
call rt_abort
.L908:
movq %rax,%r13
movabsq $256,%rcx
movq %r12,%rax
mulq %rcx
jnc .L909
call rt_abort
.L909:
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L910
call rt_abort
.L910:
movq %rax,%rbx
jmp .L904
.L905:
movq %r14,%rax
cmpq $8,%r14
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L911
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L913:
movq %rax,%rcx
cmpq %rcx,%r13
jb .L914
movq %r13,%rax
subq %r12,%rax
movq %rax,%r13
jmp .L915
.L914:
.L915:
jmp .L912
.L911:
.L912:
movq %r13,%rax
movq -.F903-8(%rbp),%rbx
movq -.F903-16(%rbp),%r12
movq -.F903-24(%rbp),%r13
movq -.F903-32(%rbp),%r14
movq -.F903-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F903-8(%rbp),%rbx
movq -.F903-16(%rbp),%r12
movq -.F903-24(%rbp),%r13
movq -.F903-32(%rbp),%r14
movq -.F903-40(%rbp),%r15
leave
ret
.set .F903,32
.type rt_store_sized,@function
rt_store_sized:
pushq %rbp
movq %rsp,%rbp
subq $.F916,%rsp
subq $48,%rsp
movq %rbx,-.F916-8(%rbp)
movq %r12,-.F916-16(%rbp)
movq %r13,-.F916-24(%rbp)
movq %r14,-.F916-32(%rbp)
movq %r15,-.F916-40(%rbp)
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
.L917:
cmpq %r15,%rbx
jae .L918
movq %r14,%rax
addq %rbx,%rax
jnc .L919
call rt_abort
.L919:
movq %rax,%r13
movq %r12,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L920:
movq %r13,%rcx
movq %rdx,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L921:
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L922
call rt_abort
.L922:
movq %rax,%rbx
jmp .L917
.L918:
movabsq $0,%rax
movq -.F916-8(%rbp),%rbx
movq -.F916-16(%rbp),%r12
movq -.F916-24(%rbp),%r13
movq -.F916-32(%rbp),%r14
movq -.F916-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F916-8(%rbp),%rbx
movq -.F916-16(%rbp),%r12
movq -.F916-24(%rbp),%r13
movq -.F916-32(%rbp),%r14
movq -.F916-40(%rbp),%r15
leave
ret
.set .F916,32
.type rt_f32_bits,@function
rt_f32_bits:
pushq %rbp
movq %rsp,%rbp
subq $.F923,%rsp
subq $48,%rsp
movq %rbx,-.F923-8(%rbp)
movq %r12,-.F923-16(%rbp)
movq %r13,-.F923-24(%rbp)
movq %r14,-.F923-32(%rbp)
movq %r15,-.F923-40(%rbp)
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
jnc .L924
call rt_abort
.L924:
movabsq $63,%rcx
movq %r14,%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
movabsq $63,%rax
cmpq $31,%rax
jnc .L925
call rt_abort
.L925:
movabsq $31,%rcx
movq -16(%rbp),%rax
shlq %cl,%rax
movq %rax,%r12
movabsq $63,%rax
cmpq $52,%rax
jnc .L926
call rt_abort
.L926:
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
jne .L927
movabsq $63,%rax
cmpq $29,%rax
jnc .L929
call rt_abort
.L929:
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
jz .L930
movq $4194304,%r15
jmp .L931
.L930:
.L931:
movq %r12,%rax
orq $2139095040,%rax
orq %r15,%rax
movq -.F923-8(%rbp),%rbx
movq -.F923-16(%rbp),%r12
movq -.F923-24(%rbp),%r13
movq -.F923-32(%rbp),%r14
movq -.F923-40(%rbp),%r15
leave
ret
jmp .L928
.L927:
.L928:
cmpq $0,%rbx
jne .L932
movq %r12,%rax
movq -.F923-8(%rbp),%rbx
movq -.F923-16(%rbp),%r12
movq -.F923-24(%rbp),%r13
movq -.F923-32(%rbp),%r14
movq -.F923-40(%rbp),%r15
leave
ret
jmp .L933
.L932:
.L933:
movabsq $896,%rax
cmpq %rbx,%rax
jae .L934
movq %rbx,%rax
subq $896,%rax
jnc .L936
call rt_abort
.L936:
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $23,%rax
jnc .L937
call rt_abort
.L937:
movabsq $23,%rcx
movq -40(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L938
call rt_abort
.L938:
movabsq $29,%rcx
movq %r13,%rax
shrq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F923-8(%rbp),%rbx
movq -.F923-16(%rbp),%r12
movq -.F923-24(%rbp),%r13
movq -.F923-32(%rbp),%r14
movq -.F923-40(%rbp),%r15
leave
ret
jmp .L935
.L934:
.L935:
movabsq $897,%rax
subq %rbx,%rax
jnc .L939
call rt_abort
.L939:
movq %rax,-56(%rbp)
movabsq $4503599627370496,%rcx
movq %r13,%rax
orq %rcx,%rax
movq %rax,-64(%rbp)
movq -56(%rbp),%rcx
movabsq $29,%rax
addq %rcx,%rax
jnc .L940
call rt_abort
.L940:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L941
call rt_abort
.L941:
movq -64(%rbp),%rax
shrq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
orq %rcx,%rax
movq -.F923-8(%rbp),%rbx
movq -.F923-16(%rbp),%r12
movq -.F923-24(%rbp),%r13
movq -.F923-32(%rbp),%r14
movq -.F923-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F923-8(%rbp),%rbx
movq -.F923-16(%rbp),%r12
movq -.F923-24(%rbp),%r13
movq -.F923-32(%rbp),%r14
movq -.F923-40(%rbp),%r15
leave
ret
.set .F923,80
.type rt_f32_from_bits,@function
rt_f32_from_bits:
pushq %rbp
movq %rsp,%rbp
subq $.F942,%rsp
subq $48,%rsp
movq %rbx,-.F942-8(%rbp)
movq %r12,-.F942-16(%rbp)
movq %r13,-.F942-24(%rbp)
movq %r14,-.F942-32(%rbp)
movq %r15,-.F942-40(%rbp)
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
jnc .L943
call rt_abort
.L943:
movabsq $31,%rcx
movq -8(%rbp),%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
andq $1,%rax
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $63,%rax
jnc .L944
call rt_abort
.L944:
movabsq $63,%rcx
movq -24(%rbp),%rax
shlq %cl,%rax
movq %rax,%r15
movabsq $63,%rax
cmpq $23,%rax
jnc .L945
call rt_abort
.L945:
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
jne .L946
movabsq $9218868437227405312,%rcx
movq %r15,%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L948
call rt_abort
.L948:
movabsq $29,%rcx
movq %r12,%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F942-8(%rbp),%rbx
movq -.F942-16(%rbp),%r12
movq -.F942-24(%rbp),%r13
movq -.F942-32(%rbp),%r14
movq -.F942-40(%rbp),%r15
leave
ret
jmp .L947
.L946:
.L947:
movq -40(%rbp),%rax
cmpq $0,%rax
jne .L949
cmpq $0,%r12
jne .L951
movq %r15,%rax
movq -.F942-8(%rbp),%rbx
movq -.F942-16(%rbp),%r12
movq -.F942-24(%rbp),%r13
movq -.F942-32(%rbp),%r14
movq -.F942-40(%rbp),%r15
leave
ret
jmp .L952
.L951:
.L952:
movq $22,%rbx
.L953:
movq %rbx,%rcx
movabsq $63,%rax
cmpq %rbx,%rax
jnc .L955
call rt_abort
.L955:
movq %r12,%rax
shrq %cl,%rax
andq $1,%rax
cmpq $0,%rax
jne .L954
movq %rbx,%rax
subq $1,%rax
jnc .L956
call rt_abort
.L956:
movq %rax,%rbx
jmp .L953
.L954:
movq %rbx,%rcx
movabsq $63,%rax
cmpq %rbx,%rax
jnc .L957
call rt_abort
.L957:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r12,%rax
subq %rcx,%rax
jnc .L958
call rt_abort
.L958:
movq %rax,-56(%rbp)
movabsq $52,%rax
subq %rbx,%rax
jnc .L959
call rt_abort
.L959:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L960
call rt_abort
.L960:
movq -56(%rbp),%rax
shlq %cl,%rax
movq %rax,-72(%rbp)
movq %rbx,%rax
addq $874,%rax
jnc .L961
call rt_abort
.L961:
movq %rax,-80(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L962
call rt_abort
.L962:
movabsq $52,%rcx
movq -80(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r15,%rax
orq %rcx,%rax
movq -72(%rbp),%rcx
orq %rcx,%rax
movq -.F942-8(%rbp),%rbx
movq -.F942-16(%rbp),%r12
movq -.F942-24(%rbp),%r13
movq -.F942-32(%rbp),%r14
movq -.F942-40(%rbp),%r15
leave
ret
jmp .L950
.L949:
.L950:
movq -40(%rbp),%rax
addq $896,%rax
jnc .L963
call rt_abort
.L963:
movq %rax,-88(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L964
call rt_abort
.L964:
movabsq $52,%rcx
movq -88(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq %r15,%rax
orq %rcx,%rax
movq %rax,-96(%rbp)
movabsq $63,%rax
cmpq $29,%rax
jnc .L965
call rt_abort
.L965:
movabsq $29,%rcx
movq %r12,%rax
shlq %cl,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
orq %rcx,%rax
movq -.F942-8(%rbp),%rbx
movq -.F942-16(%rbp),%r12
movq -.F942-24(%rbp),%r13
movq -.F942-32(%rbp),%r14
movq -.F942-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F942-8(%rbp),%rbx
movq -.F942-16(%rbp),%r12
movq -.F942-24(%rbp),%r13
movq -.F942-32(%rbp),%r14
movq -.F942-40(%rbp),%r15
leave
ret
.set .F942,96
.type rt_view_ptr,@function
rt_view_ptr:
pushq %rbp
movq %rsp,%rbp
subq $.F966,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F966,16
.type rt_cstr_view,@function
rt_cstr_view:
pushq %rbp
movq %rsp,%rbp
subq $.F967,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L968
call rt_abort
.L968:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L969
call rt_abort
jmp .L970
.L969:
.L970:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rcx
addq %rcx,%rax
jnc .L971
call rt_abort
.L971:
movq %rax,-40(%rbp)
movq -40(%rbp),%rax
subq $1,%rax
jnc .L972
call rt_abort
.L972:
movzbq (%rax),%rax
movq %rax,-48(%rbp)
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
je .L973
call rt_abort
jmp .L974
.L973:
.L974:
movq -32(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F967,48
.type rt_append,@function
rt_append:
pushq %rbp
movq %rsp,%rbp
subq $.F975,%rsp
subq $32,%rsp
movq %rbx,-.F975-8(%rbp)
movq %r12,-.F975-16(%rbp)
movq %r13,-.F975-24(%rbp)
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
jnc .L976
call rt_abort
.L976:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $8,%rax
jnc .L977
call rt_abort
.L977:
movq (%rax),%rax
movq %rax,%r13
movq %r12,%rcx
addq %r12,%rax
jnc .L978
call rt_abort
.L978:
movq %rbx,%rdi
movq %rax,%rsi
call rt_reserveb
movq %rbx,%rax
movq (%rax),%rax
movq %r13,%rcx
addq %r13,%rax
jnc .L979
call rt_abort
.L979:
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
jnc .L980
call rt_abort
.L980:
movq %rax,-40(%rbp)
movq %r13,%rax
addq %r12,%rax
jnc .L981
call rt_abort
.L981:
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F975-8(%rbp),%rbx
movq -.F975-16(%rbp),%r12
movq -.F975-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F975-8(%rbp),%rbx
movq -.F975-16(%rbp),%r12
movq -.F975-24(%rbp),%r13
leave
ret
.set .F975,48
.type rt_copy,@function
rt_copy:
pushq %rbp
movq %rsp,%rbp
subq $.F982,%rsp
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
.set .F982,32
.type rt_vec_copy,@function
rt_vec_copy:
pushq %rbp
movq %rsp,%rbp
subq $.F983,%rsp
subq $48,%rsp
movq %rbx,-.F983-8(%rbp)
movq %r12,-.F983-16(%rbp)
movq %r13,-.F983-24(%rbp)
movq %r14,-.F983-32(%rbp)
movq %r15,-.F983-40(%rbp)
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
jnc .L984
call rt_abort
.L984:
movq (%rax),%rax
movq %rax,%r15
movq $0,%rbx
.L985:
cmpq %r15,%rbx
jae .L986
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L987
call rt_abort
.L987:
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L988
call rt_abort
.L988:
movq (%rax),%rax
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt37
call rt_push
jmp .Lopt38
.Lopt37:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt38:
movq %rbx,%rax
addq $1,%rax
jnc .L989
call rt_abort
.L989:
movq %rax,%rbx
jmp .L985
.L986:
movq %r14,%rax
movq -.F983-8(%rbp),%rbx
movq -.F983-16(%rbp),%r12
movq -.F983-24(%rbp),%r13
movq -.F983-32(%rbp),%r14
movq -.F983-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F983-8(%rbp),%rbx
movq -.F983-16(%rbp),%r12
movq -.F983-24(%rbp),%r13
movq -.F983-32(%rbp),%r14
movq -.F983-40(%rbp),%r15
leave
ret
.set .F983,16
.type rt_lit,@function
rt_lit:
pushq %rbp
movq %rsp,%rbp
subq $.F990,%rsp
subq $16,%rsp
movq %rbx,-.F990-8(%rbp)
movq %r12,-.F990-16(%rbp)
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
jnc .L991
call rt_abort
.L991:
movq %rax,-40(%rbp)
movq %rbx,%rax
movq -40(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
movq %r12,%rax
movq -.F990-8(%rbp),%rbx
movq -.F990-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F990-8(%rbp),%rbx
movq -.F990-16(%rbp),%r12
leave
ret
.set .F990,48
.type rt_rec,@function
rt_rec:
pushq %rbp
movq %rsp,%rbp
subq $.F992,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $144115188075855872,%rax
cmpq %rcx,%rax
jae .L993
call rt_abort
jmp .L994
.L993:
.L994:
movabsq $8,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L995
call rt_abort
.L995:
movq %rax,%rdi
call rt_alloc
leave
ret
xorq %rax,%rax
leave
ret
.set .F992,16
.type rt_enum,@function
rt_enum:
pushq %rbp
movq %rsp,%rbp
subq $.F996,%rsp
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
jnc .L997
call rt_abort
.L997:
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
.set .F996,48
.type rt_enum_retag,@function
rt_enum_retag:
pushq %rbp
movq %rsp,%rbp
subq $.F998,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L999
call rt_abort
.L999:
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
.set .F998,32
.type rt_xchg,@function
rt_xchg:
pushq %rbp
movq %rsp,%rbp
subq $.F1000,%rsp
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
.set .F1000,32
.type rt_drop_seq,@function
rt_drop_seq:
pushq %rbp
movq %rsp,%rbp
subq $.F1001,%rsp
subq $16,%rsp
movq %rbx,-.F1001-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rbx
je .L1002
movq %rbx,%rax
movq (%rax),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_free
jmp .L1003
.L1002:
.L1003:
movabsq $0,%rax
movq -.F1001-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1001-8(%rbp),%rbx
leave
ret
.set .F1001,16
.type rt_pack,@function
rt_pack:
pushq %rbp
movq %rsp,%rbp
subq $.F1004,%rsp
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
jnc .L1005
call rt_abort
.L1005:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $1,%rcx
movq -24(%rbp),%rax
addq $1,%rax
jnc .L1006
call rt_abort
.L1006:
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
jnc .L1007
call rt_abort
.L1007:
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
.set .F1004,64
.type rt_cstr,@function
rt_cstr:
pushq %rbp
movq %rsp,%rbp
subq $.F1008,%rsp
subq $32,%rsp
movq %rbx,-.F1008-8(%rbp)
movq %r12,-.F1008-16(%rbp)
movq %r13,-.F1008-24(%rbp)
movq %r14,-.F1008-32(%rbp)
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
jnc .L1009
call rt_abort
.L1009:
movq (%rax),%rax
movq %rax,%r14
movq $0,%rbx
.L1010:
cmpq %r14,%rbx
jae .L1011
movq %r12,%rax
addq %rbx,%rax
jnc .L1012
call rt_abort
.L1012:
movzbq (%rax),%rax
movabsq $0,%rcx
cmpq $0,%rax
jne .L1013
movq %r12,%rdi
call rt_free
movabsq $0,%rax
movq -.F1008-8(%rbp),%rbx
movq -.F1008-16(%rbp),%r12
movq -.F1008-24(%rbp),%r13
movq -.F1008-32(%rbp),%r14
leave
ret
jmp .L1014
.L1013:
.L1014:
movq %rbx,%rax
addq $1,%rax
jnc .L1015
call rt_abort
.L1015:
movq %rax,%rbx
jmp .L1010
.L1011:
movq %r12,%rax
movq -.F1008-8(%rbp),%rbx
movq -.F1008-16(%rbp),%r12
movq -.F1008-24(%rbp),%r13
movq -.F1008-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1008-8(%rbp),%rbx
movq -.F1008-16(%rbp),%r12
movq -.F1008-24(%rbp),%r13
movq -.F1008-32(%rbp),%r14
leave
ret
.set .F1008,16
.type f_host_target,@function
f_host_target:
pushq %rbp
movq %rsp,%rbp
subq $.F1016,%rsp
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1016,16
.type f_host_argc,@function
f_host_argc:
pushq %rbp
movq %rsp,%rbp
subq $.F1017,%rsp
leaq rt_state(%rip),%rax
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1017,32
.type f_host_arg,@function
f_host_arg:
pushq %rbp
movq %rsp,%rbp
subq $.F1018,%rsp
subq $32,%rsp
movq %rbx,-.F1018-8(%rbp)
movq %r12,-.F1018-16(%rbp)
movq %r13,-.F1018-24(%rbp)
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
jne .L1019
call rt_abort
jmp .L1020
.L1019:
.L1020:
leaq rt_state(%rip),%rax
movq %rax,-24(%rbp)
addq $8,%rax
jnc .L1021
call rt_abort
.L1021:
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L1022
call rt_abort
.L1022:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L1023
call rt_abort
.L1023:
movq (%rax),%rax
movq %rax,%r13
movq $0,%rbx
.L1024:
movq %r13,%rax
addq %rbx,%rax
jnc .L1026
call rt_abort
.L1026:
movzbq (%rax),%rax
movabsq $0,%rcx
cmpq $0,%rax
je .L1025
movq %rbx,%rax
addq $1,%rax
jnc .L1027
call rt_abort
.L1027:
movq %rax,%rbx
jmp .L1024
.L1025:
movq %r13,%rdi
movq %rbx,%rsi
call rt_lit
movq -.F1018-8(%rbp),%rbx
movq -.F1018-16(%rbp),%r12
movq -.F1018-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1018-8(%rbp),%rbx
movq -.F1018-16(%rbp),%r12
movq -.F1018-24(%rbp),%r13
leave
ret
.set .F1018,32
.type f_host_read_file,@function
f_host_read_file:
pushq %rbp
movq %rsp,%rbp
subq $.F1028,%rsp
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
jne .L1422_i6
movabsq $0,%rax
jmp .Lret_i6
jmp .L1423_i6
.L1422_i6:
.L1423_i6:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i6
call rt_abort
.L1424_i6:
movq (%rax),%rax
jmp .Lret_i6
xorq %rax,%rax
jmp .Lret_i6
.Lret_i6:
movq %rax,-16(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
je .L1029
leaq rt_read_file_blocking(%rip),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
call rt_offload
leave
ret
jmp .L1030
.L1029:
.L1030:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_read_file_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F1028,32
.type rt_read_file_blocking,@function
rt_read_file_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F1031,%rsp
subq $48,%rsp
movq %rbx,-.F1031-8(%rbp)
movq %r12,-.F1031-16(%rbp)
movq %r13,-.F1031-24(%rbp)
movq %r14,-.F1031-32(%rbp)
movq %r15,-.F1031-40(%rbp)
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
jne .L1032
call rt_abort
jmp .L1033
.L1032:
.L1033:
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
jz .L1034
call rt_abort
jmp .L1035
.L1034:
.L1035:
movabsq $4096,%rdi
call rt_alloc
movq %rax,%r13
call rt_new
movq %rax,-24(%rbp)
.L1036:
movabsq $1,%rax
testq %rax,%rax
jz .L1037
movabsq $0,%rdi
movq %r15,%rsi
movq %r13,%rdx
movabsq $4096,%rcx
call rt_syscall
movq %rax,%r12
cmpq $0,%rax
jne .L1038
jmp .L1037
jmp .L1039
.L1038:
.L1039:
movabsq $0,%rax
subq $4,%rax
movq %rax,%rcx
cmpq %rcx,%r12
jne .L1040
jmp .L1036
jmp .L1041
.L1040:
.L1041:
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
jz .L1042
call rt_abort
jmp .L1043
.L1042:
.L1043:
movq $0,%rbx
.L1044:
cmpq %r12,%rbx
jae .L1045
movq %r13,%rax
addq %rbx,%rax
jnc .L1046
call rt_abort
.L1046:
movzbq (%rax),%rax
movq -24(%rbp),%rdi
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
jnc .L1047
call rt_abort
.L1047:
movq %rax,%rbx
jmp .L1044
.L1045:
jmp .L1036
.L1037:
movabsq $3,%rdi
movq %r15,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r13,%rdi
call rt_free
movq -24(%rbp),%rax
movq -.F1031-8(%rbp),%rbx
movq -.F1031-16(%rbp),%r12
movq -.F1031-24(%rbp),%r13
movq -.F1031-32(%rbp),%r14
movq -.F1031-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1031-8(%rbp),%rbx
movq -.F1031-16(%rbp),%r12
movq -.F1031-24(%rbp),%r13
movq -.F1031-32(%rbp),%r14
movq -.F1031-40(%rbp),%r15
leave
ret
.set .F1031,32
.type rt_write_all,@function
rt_write_all:
pushq %rbp
movq %rsp,%rbp
subq $.F1048,%rsp
subq $48,%rsp
movq %rbx,-.F1048-8(%rbp)
movq %r12,-.F1048-16(%rbp)
movq %r13,-.F1048-24(%rbp)
movq %r14,-.F1048-32(%rbp)
movq %r15,-.F1048-40(%rbp)
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
.L1049:
cmpq %r12,%rbx
jae .L1050
movq -16(%rbp),%rax
addq %rbx,%rax
jnc .L1051
call rt_abort
.L1051:
movq %rax,%r13
movq %r12,%rax
subq %rbx,%rax
jnc .L1052
call rt_abort
.L1052:
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
jne .L1053
jmp .L1049
jmp .L1054
.L1053:
.L1054:
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
jz .L1055
movabsq $0,%rax
subq %r14,%rax
movq -.F1048-8(%rbp),%rbx
movq -.F1048-16(%rbp),%r12
movq -.F1048-24(%rbp),%r13
movq -.F1048-32(%rbp),%r14
movq -.F1048-40(%rbp),%r15
leave
ret
jmp .L1056
.L1055:
.L1056:
cmpq $0,%r14
jne .L1057
movabsq $5,%rax
movq -.F1048-8(%rbp),%rbx
movq -.F1048-16(%rbp),%r12
movq -.F1048-24(%rbp),%r13
movq -.F1048-32(%rbp),%r14
movq -.F1048-40(%rbp),%r15
leave
ret
jmp .L1058
.L1057:
.L1058:
movq %rbx,%rax
addq %r14,%rax
jnc .L1059
call rt_abort
.L1059:
movq %rax,%rbx
jmp .L1049
.L1050:
movabsq $0,%rax
movq -.F1048-8(%rbp),%rbx
movq -.F1048-16(%rbp),%r12
movq -.F1048-24(%rbp),%r13
movq -.F1048-32(%rbp),%r14
movq -.F1048-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1048-8(%rbp),%rbx
movq -.F1048-16(%rbp),%r12
movq -.F1048-24(%rbp),%r13
movq -.F1048-32(%rbp),%r14
movq -.F1048-40(%rbp),%r15
leave
ret
.set .F1048,32
.type f_host_write_file,@function
f_host_write_file:
pushq %rbp
movq %rsp,%rbp
subq $.F1060,%rsp
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
jne .L1422_i10
movabsq $0,%rax
jmp .Lret_i10
jmp .L1423_i10
.L1422_i10:
.L1423_i10:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i10
call rt_abort
.L1424_i10:
movq (%rax),%rax
jmp .Lret_i10
xorq %rax,%rax
jmp .Lret_i10
.Lret_i10:
movq %rax,-24(%rbp)
movabsq $0,%rcx
movq -24(%rbp),%rax
cmpq $0,%rax
je .L1061
leaq rt_write_file_blocking(%rip),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rdi
movq -8(%rbp),%rsi
movq %rax,%rdx
call rt_offload
leave
ret
jmp .L1062
.L1061:
.L1062:
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
call rt_write_file_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F1060,32
.type rt_write_file_blocking,@function
rt_write_file_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F1063,%rsp
subq $32,%rsp
movq %rbx,-.F1063-8(%rbp)
movq %r12,-.F1063-16(%rbp)
movq %r13,-.F1063-24(%rbp)
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
jne .L1064
movq %rbx,%rdi
call rt_free
movabsq $22,%rax
movq -.F1063-8(%rbp),%rbx
movq -.F1063-16(%rbp),%r12
movq -.F1063-24(%rbp),%r13
leave
ret
jmp .L1065
.L1064:
.L1065:
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
jz .L1066
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
subq %r12,%rax
movq -.F1063-8(%rbp),%rbx
movq -.F1063-16(%rbp),%r12
movq -.F1063-24(%rbp),%r13
leave
ret
jmp .L1067
.L1066:
.L1067:
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
je .L1068
movq -32(%rbp),%rax
movq -.F1063-8(%rbp),%rbx
movq -.F1063-16(%rbp),%r12
movq -.F1063-24(%rbp),%r13
leave
ret
jmp .L1069
.L1068:
.L1069:
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
jz .L1070
movq -40(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F1063-8(%rbp),%rbx
movq -.F1063-16(%rbp),%r12
movq -.F1063-24(%rbp),%r13
leave
ret
jmp .L1071
.L1070:
.L1071:
movabsq $0,%rax
movq -.F1063-8(%rbp),%rbx
movq -.F1063-16(%rbp),%r12
movq -.F1063-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1063-8(%rbp),%rbx
movq -.F1063-16(%rbp),%r12
movq -.F1063-24(%rbp),%r13
leave
ret
.set .F1063,48
.type f_host_print,@function
f_host_print:
pushq %rbp
movq %rsp,%rbp
subq $.F1072,%rsp
subq $16,%rsp
movq %rbx,-.F1072-8(%rbp)
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
je .L1073
call rt_abort
jmp .L1074
.L1073:
.L1074:
movabsq $0,%rax
movq -.F1072-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1072-8(%rbp),%rbx
leave
ret
.set .F1072,32
.type rt_pow,@function
rt_pow:
pushq %rbp
movq %rsp,%rbp
subq $.F1075,%rsp
subq $32,%rsp
movq %rbx,-.F1075-8(%rbp)
movq %r12,-.F1075-16(%rbp)
movq %r13,-.F1075-24(%rbp)
movq %r14,-.F1075-32(%rbp)
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
.L1076:
cmpq $0,%rbx
je .L1077
movabsq $2,%rcx
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1078:
testq %rdx,%rdx
jz .L1079
movq %r13,%rax
movq %r12,%rcx
mulq %rcx
jnc .L1081
call rt_abort
.L1081:
movq %rax,%r13
jmp .L1080
.L1079:
.L1080:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
cmpq $0,%rax
je .L1082
movq %r12,%rax
movq %r12,%rcx
mulq %rcx
jnc .L1084
call rt_abort
.L1084:
movq %rax,%r12
jmp .L1083
.L1082:
.L1083:
jmp .L1076
.L1077:
movq %r13,%rax
movq -.F1075-8(%rbp),%rbx
movq -.F1075-16(%rbp),%r12
movq -.F1075-24(%rbp),%r13
movq -.F1075-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1075-8(%rbp),%rbx
movq -.F1075-16(%rbp),%r12
movq -.F1075-24(%rbp),%r13
movq -.F1075-32(%rbp),%r14
leave
ret
.set .F1075,16
.type rt_wrapping_pow,@function
rt_wrapping_pow:
pushq %rbp
movq %rsp,%rbp
subq $.F1085,%rsp
subq $32,%rsp
movq %rbx,-.F1085-8(%rbp)
movq %r12,-.F1085-16(%rbp)
movq %r13,-.F1085-24(%rbp)
movq %r14,-.F1085-32(%rbp)
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
.L1086:
cmpq $0,%rbx
je .L1087
movabsq $2,%rcx
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1088:
testq %rdx,%rdx
jz .L1089
movq %r13,%rax
movq %r12,%rcx
imulq %rcx,%rax
movq %rax,%r13
jmp .L1090
.L1089:
.L1090:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
cmpq $0,%rax
je .L1091
movq %r12,%rax
movq %r12,%rcx
imulq %rcx,%rax
movq %rax,%r12
jmp .L1092
.L1091:
.L1092:
jmp .L1086
.L1087:
movq %r13,%rax
movq -.F1085-8(%rbp),%rbx
movq -.F1085-16(%rbp),%r12
movq -.F1085-24(%rbp),%r13
movq -.F1085-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1085-8(%rbp),%rbx
movq -.F1085-16(%rbp),%r12
movq -.F1085-24(%rbp),%r13
movq -.F1085-32(%rbp),%r14
leave
ret
.set .F1085,16
.type rt_print_number,@function
rt_print_number:
pushq %rbp
movq %rsp,%rbp
subq $.F1093,%rsp
subq $48,%rsp
movq %rbx,-.F1093-8(%rbp)
movq %r12,-.F1093-16(%rbp)
movq %r13,-.F1093-24(%rbp)
movq %r14,-.F1093-32(%rbp)
movq %r15,-.F1093-40(%rbp)
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
jz .L1094
movq $30,%rbx
movq %r13,%rax
addq $31,%rax
jnc .L1096
call rt_abort
.L1096:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
jmp .L1095
.L1094:
.L1095:
.L1097:
movabsq $1,%rax
testq %rax,%rax
jz .L1098
movq %r13,%rax
addq %rbx,%rax
jnc .L1099
call rt_abort
.L1099:
movq %rax,%r14
movabsq $10,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L1100
call rt_abort
.L1100:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L1101
call rt_abort
.L1101:
movq %r14,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
movq %rax,%r15
cmpq $0,%rax
jne .L1102
jmp .L1098
jmp .L1103
.L1102:
.L1103:
movq %rbx,%rax
subq $1,%rax
jnc .L1104
call rt_abort
.L1104:
movq %rax,%rbx
jmp .L1097
.L1098:
movq %r13,%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L1105
call rt_abort
.L1105:
movq %rax,-32(%rbp)
movabsq $32,%rax
subq %rbx,%rax
jnc .L1106
call rt_abort
.L1106:
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
je .L1107
call rt_abort
jmp .L1108
.L1107:
.L1108:
movabsq $0,%rax
movq -.F1093-8(%rbp),%rbx
movq -.F1093-16(%rbp),%r12
movq -.F1093-24(%rbp),%r13
movq -.F1093-32(%rbp),%r14
movq -.F1093-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1093-8(%rbp),%rbx
movq -.F1093-16(%rbp),%r12
movq -.F1093-24(%rbp),%r13
movq -.F1093-32(%rbp),%r14
movq -.F1093-40(%rbp),%r15
leave
ret
.set .F1093,48
.type rt_print_num,@function
rt_print_num:
pushq %rbp
movq %rsp,%rbp
subq $.F1109,%rsp
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
.set .F1109,16
.type rt_print_newline,@function
rt_print_newline:
pushq %rbp
movq %rsp,%rbp
subq $.F1110,%rsp
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
je .L1111
call rt_abort
jmp .L1112
.L1111:
.L1112:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1110,32
.type f_host_print_num,@function
f_host_print_num:
pushq %rbp
movq %rsp,%rbp
subq $.F1113,%rsp
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
.set .F1113,16
.type f_host_newline,@function
f_host_newline:
pushq %rbp
movq %rsp,%rbp
subq $.F1114,%rsp
call rt_print_newline
leave
ret
xorq %rax,%rax
leave
ret
.set .F1114,16
.type rt_exec_paths,@function
rt_exec_paths:
pushq %rbp
movq %rsp,%rbp
subq $.F1115,%rsp
subq $48,%rsp
movq %rbx,-.F1115-8(%rbp)
movq %r12,-.F1115-16(%rbp)
movq %r13,-.F1115-24(%rbp)
movq %r14,-.F1115-32(%rbp)
movq %r15,-.F1115-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F1115(%rbp),%rdi
movq $.F1115/8-1,%rcx
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
jb .Lopt41
call rt_push
jmp .Lopt42
.Lopt41:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt42:
leaq rt_state(%rip),%rax
movq %rax,-32(%rbp)
addq $16,%rax
jnc .L1116
call rt_abort
.L1116:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq $0,-48(%rbp)
movq $0,-56(%rbp)
.L1117:
movq -8(%rbp),%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L1119
call rt_abort
.L1119:
movzbq (%rax),%rax
movq %rax,-64(%rbp)
cmpq $0,%rax
je .L1118
movq -8(%rbp),%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L1120
call rt_abort
.L1120:
movzbq (%rax),%rax
movq %rax,-72(%rbp)
cmpq $47,%rax
jne .L1121
movq $1,-56(%rbp)
jmp .L1122
.L1121:
.L1122:
movq -48(%rbp),%rax
addq $1,%rax
jnc .L1123
call rt_abort
.L1123:
movq %rax,-48(%rbp)
jmp .L1117
.L1118:
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1124
movq -16(%rbp),%rax
movq -.F1115-8(%rbp),%rbx
movq -.F1115-16(%rbp),%r12
movq -.F1115-24(%rbp),%r13
movq -.F1115-32(%rbp),%r14
movq -.F1115-40(%rbp),%r15
leave
ret
jmp .L1125
.L1124:
.L1125:
movq -40(%rbp),%rax
movq %rax,-80(%rbp)
movq $0,%r14
.L1126:
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-88(%rbp)
cmpq $0,%rax
je .L1127
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-96(%rbp)
movzbq (%rax),%rax
movq %rax,-104(%rbp)
cmpq $80,%rax
jne .L1128
movq -96(%rbp),%rax
addq $1,%rax
jnc .L1130
call rt_abort
.L1130:
movzbq (%rax),%rax
movq %rax,-112(%rbp)
cmpq $65,%rax
jne .L1131
movq -96(%rbp),%rax
addq $2,%rax
jnc .L1133
call rt_abort
.L1133:
movzbq (%rax),%rax
movq %rax,-120(%rbp)
cmpq $84,%rax
jne .L1134
movq -96(%rbp),%rax
addq $3,%rax
jnc .L1136
call rt_abort
.L1136:
movzbq (%rax),%rax
movq %rax,-128(%rbp)
cmpq $72,%rax
jne .L1137
movq -96(%rbp),%rax
addq $4,%rax
jnc .L1139
call rt_abort
.L1139:
movzbq (%rax),%rax
movq %rax,-136(%rbp)
cmpq $61,%rax
jne .L1140
movq -96(%rbp),%rax
addq $5,%rax
jnc .L1142
call rt_abort
.L1142:
movq %rax,%r14
jmp .L1127
jmp .L1141
.L1140:
.L1141:
jmp .L1138
.L1137:
.L1138:
jmp .L1135
.L1134:
.L1135:
jmp .L1132
.L1131:
.L1132:
jmp .L1129
.L1128:
.L1129:
movq -80(%rbp),%rax
addq $8,%rax
jnc .L1143
call rt_abort
.L1143:
movq %rax,-80(%rbp)
jmp .L1126
.L1127:
movq $0,-144(%rbp)
movabsq $0,%rcx
cmpq $0,%r14
jne .L1144
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
jnc .L1146
call rt_abort
.L1146:
movq %rax,-160(%rbp)
movq %rax,%rcx
movabsq $98,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $2,%rax
jnc .L1147
call rt_abort
.L1147:
movq %rax,-168(%rbp)
movq %rax,%rcx
movabsq $105,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $3,%rax
jnc .L1148
call rt_abort
.L1148:
movq %rax,-176(%rbp)
movq %rax,%rcx
movabsq $110,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $4,%rax
jnc .L1149
call rt_abort
.L1149:
movq %rax,-184(%rbp)
movq %rax,%rcx
movabsq $58,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $5,%rax
jnc .L1150
call rt_abort
.L1150:
movq %rax,-192(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $6,%rax
jnc .L1151
call rt_abort
.L1151:
movq %rax,-200(%rbp)
movq %rax,%rcx
movabsq $117,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $7,%rax
jnc .L1152
call rt_abort
.L1152:
movq %rax,-208(%rbp)
movq %rax,%rcx
movabsq $115,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $8,%rax
jnc .L1153
call rt_abort
.L1153:
movq %rax,-216(%rbp)
movq %rax,%rcx
movabsq $114,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $9,%rax
jnc .L1154
call rt_abort
.L1154:
movq %rax,-224(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $10,%rax
jnc .L1155
call rt_abort
.L1155:
movq %rax,-232(%rbp)
movq %rax,%rcx
movabsq $98,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $11,%rax
jnc .L1156
call rt_abort
.L1156:
movq %rax,-240(%rbp)
movq %rax,%rcx
movabsq $105,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
addq $12,%rax
jnc .L1157
call rt_abort
.L1157:
movq %rax,-248(%rbp)
movq %rax,%rcx
movabsq $110,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq -144(%rbp),%rax
movq %rax,%r14
jmp .L1145
.L1144:
.L1145:
movq $0,-256(%rbp)
.L1158:
movabsq $1,%rax
testq %rax,%rax
jz .L1159
movq -256(%rbp),%rax
movq %rax,%r12
.L1160:
movq %r14,%rax
addq %r12,%rax
jnc .L1162
call rt_abort
.L1162:
movzbq (%rax),%rax
movq %rax,-264(%rbp)
cmpq $0,%rax
je .L1161
movq %r14,%rax
addq %r12,%rax
jnc .L1163
call rt_abort
.L1163:
movzbq (%rax),%rax
movq %rax,-272(%rbp)
cmpq $58,%rax
jne .L1164
jmp .L1161
jmp .L1165
.L1164:
.L1165:
movq %r12,%rax
addq $1,%rax
jnc .L1166
call rt_abort
.L1166:
movq %rax,%r12
jmp .L1160
.L1161:
movq %r12,%rax
movq -256(%rbp),%rcx
subq %rcx,%rax
jnc .L1167
call rt_abort
.L1167:
movq %rax,-280(%rbp)
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L1168
call rt_abort
.L1168:
movq %rax,-288(%rbp)
movabsq $2,%rcx
addq $2,%rax
jnc .L1169
call rt_abort
.L1169:
movq %rax,%rdi
call rt_alloc
movq %rax,%r15
movq $0,%rbx
.L1170:
movq -280(%rbp),%rcx
cmpq %rcx,%rbx
jae .L1171
movq %r15,%rax
addq %rbx,%rax
jnc .L1172
call rt_abort
.L1172:
movq %rax,-296(%rbp)
movq %r14,%rax
movq -256(%rbp),%rcx
addq %rcx,%rax
jnc .L1173
call rt_abort
.L1173:
addq %rbx,%rax
jnc .L1174
call rt_abort
.L1174:
movzbq (%rax),%rax
movq -296(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1175
call rt_abort
.L1175:
movq %rax,%rbx
jmp .L1170
.L1171:
movq -280(%rbp),%rax
cmpq $0,%rax
je .L1176
movq %r15,%rax
addq %rbx,%rax
jnc .L1178
call rt_abort
.L1178:
movq %rax,-304(%rbp)
movq %rax,%rcx
movabsq $47,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L1179
call rt_abort
.L1179:
movq %rax,%rbx
jmp .L1177
.L1176:
.L1177:
movq $0,%r13
.L1180:
movq -48(%rbp),%rcx
cmpq %rcx,%r13
jae .L1181
movq %r15,%rax
addq %rbx,%rax
jnc .L1182
call rt_abort
.L1182:
addq %r13,%rax
jnc .L1183
call rt_abort
.L1183:
movq %rax,-312(%rbp)
movq -8(%rbp),%rax
addq %r13,%rax
jnc .L1184
call rt_abort
.L1184:
movzbq (%rax),%rax
movq -312(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $1,%rax
jnc .L1185
call rt_abort
.L1185:
movq %rax,%r13
jmp .L1180
.L1181:
movq -16(%rbp),%rdi
movq %r15,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt43
call rt_push
jmp .Lopt44
.Lopt43:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt44:
movq %r14,%rax
addq %r12,%rax
jnc .L1186
call rt_abort
.L1186:
movzbq (%rax),%rax
movq %rax,-320(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1187
jmp .L1159
jmp .L1188
.L1187:
.L1188:
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L1189
call rt_abort
.L1189:
movq %rax,-256(%rbp)
jmp .L1158
.L1159:
movq -144(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq -.F1115-8(%rbp),%rbx
movq -.F1115-16(%rbp),%r12
movq -.F1115-24(%rbp),%r13
movq -.F1115-32(%rbp),%r14
movq -.F1115-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1115-8(%rbp),%rbx
movq -.F1115-16(%rbp),%r12
movq -.F1115-24(%rbp),%r13
movq -.F1115-32(%rbp),%r14
movq -.F1115-40(%rbp),%r15
leave
ret
.set .F1115,320
.type rt_exec,@function
rt_exec:
pushq %rbp
movq %rsp,%rbp
subq $.F1190,%rsp
subq $48,%rsp
movq %rbx,-.F1190-8(%rbp)
movq %r12,-.F1190-16(%rbp)
movq %r13,-.F1190-24(%rbp)
movq %r14,-.F1190-32(%rbp)
movq %r15,-.F1190-40(%rbp)
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
jnc .L1191
call rt_abort
.L1191:
movq (%rax),%rax
movq %rax,%r15
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,-32(%rbp)
movq $0,%rbx
.L1192:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L1193
movq %r13,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i13
call rt_abort
.Lopt36_i13:
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
jnc .L1194
call rt_abort
.L1194:
movq %rax,%rbx
jmp .L1192
.L1193:
movabsq $0,%rax
movq -.F1190-8(%rbp),%rbx
movq -.F1190-16(%rbp),%r12
movq -.F1190-24(%rbp),%r13
movq -.F1190-32(%rbp),%r14
movq -.F1190-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1190-8(%rbp),%rbx
movq -.F1190-16(%rbp),%r12
movq -.F1190-24(%rbp),%r13
movq -.F1190-32(%rbp),%r14
movq -.F1190-40(%rbp),%r15
leave
ret
.set .F1190,32
.type rt_drop_exec_paths,@function
rt_drop_exec_paths:
pushq %rbp
movq %rsp,%rbp
subq $.F1195,%rsp
subq $32,%rsp
movq %rbx,-.F1195-8(%rbp)
movq %r12,-.F1195-16(%rbp)
movq %r13,-.F1195-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq $0,-16(%rbp)
movq %r12,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq $1,%rbx
.L1196:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L1197
movq %r12,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i14
call rt_abort
.Lopt36_i14:
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
jnc .L1198
call rt_abort
.L1198:
movq %rax,%rbx
jmp .L1196
.L1197:
movq %r12,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1195-8(%rbp),%rbx
movq -.F1195-16(%rbp),%r12
movq -.F1195-24(%rbp),%r13
leave
ret
.set .F1195,16
.type f_host_command,@function
f_host_command:
pushq %rbp
movq %rsp,%rbp
subq $.F1199,%rsp
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
jne .L1422_i15
movabsq $0,%rax
jmp .Lret_i15
jmp .L1423_i15
.L1422_i15:
.L1423_i15:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i15
call rt_abort
.L1424_i15:
movq (%rax),%rax
jmp .Lret_i15
xorq %rax,%rax
jmp .Lret_i15
.Lret_i15:
movq %rax,-16(%rbp)
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
je .L1200
leaq rt_command_blocking(%rip),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rdi
movq -8(%rbp),%rsi
movabsq $0,%rdx
call rt_offload
leave
ret
jmp .L1201
.L1200:
.L1201:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_command_blocking
leave
ret
xorq %rax,%rax
leave
ret
.set .F1199,32
.type rt_command_blocking,@function
rt_command_blocking:
pushq %rbp
movq %rsp,%rbp
subq $.F1202,%rsp
subq $48,%rsp
movq %rbx,-.F1202-8(%rbp)
movq %r12,-.F1202-16(%rbp)
movq %r13,-.F1202-24(%rbp)
movq %r14,-.F1202-32(%rbp)
movq %r15,-.F1202-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
leaq -.F1202(%rbp),%rdi
movq $.F1202/8-1,%rcx
xorl %eax,%eax
rep stosq
movq %r15,%rdi
movq 8(%rdi),%rax
movq %rax,%r13
movq $278,-16(%rbp)
movq $0,%r12
addq $1,%rax
jnc .L1203
call rt_abort
.L1203:
movq %rax,-24(%rbp)
movabsq $8,%rcx
mulq %rcx
jnc .L1204
call rt_abort
.L1204:
movq %rax,%rdi
call rt_alloc
movq %rax,%r14
cmpq $0,%r13
je .L1205
.L1207:
movq %r13,%rcx
cmpq %r13,%r12
jae .L1208
movq %r15,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i16
call rt_abort
.Lopt36_i16:
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
jne .L1209
jmp .L1208
jmp .L1210
.L1209:
.L1210:
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L1211
call rt_abort
.L1211:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1212
call rt_abort
.L1212:
movq %rax,-48(%rbp)
movq -32(%rbp),%rax
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $1,%rax
jnc .L1213
call rt_abort
.L1213:
movq %rax,%r12
jmp .L1207
.L1208:
movq %r13,%rcx
cmpq %r13,%r12
jne .L1214
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
jne .L1216
movq -56(%rbp),%rdi
movq %r14,%rsi
call rt_exec
movabsq $60,%rdi
movabsq $127,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L1217
.L1216:
.L1217:
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
jz .L1218
movq -64(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%rcx
movabsq $256,%rax
addq %rcx,%rax
jnc .L1220
call rt_abort
.L1220:
movq %rax,-16(%rbp)
jmp .L1219
.L1218:
movabsq $8,%rdi
call rt_alloc
movq %rax,-80(%rbp)
movq $0,-88(%rbp)
.L1221:
movabsq $1,%rax
testq %rax,%rax
jz .L1222
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
je .L1223
jmp .L1222
jmp .L1224
.L1223:
.L1224:
jmp .L1221
.L1222:
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
jz .L1225
movq -88(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%rcx
movabsq $256,%rax
addq %rcx,%rax
jnc .L1227
call rt_abort
.L1227:
movq %rax,-16(%rbp)
jmp .L1226
.L1225:
movq -80(%rbp),%rax
movq (%rax),%rax
movq %rax,-104(%rbp)
movq %rax,-112(%rbp)
andq $127,%rax
movq %rax,-120(%rbp)
movq %rax,-128(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1228
movq -120(%rbp),%rcx
movabsq $128,%rax
addq %rcx,%rax
jnc .L1230
call rt_abort
.L1230:
movq %rax,-16(%rbp)
jmp .L1229
.L1228:
movq -104(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,-136(%rbp)
movabsq $255,%rcx
andq $255,%rax
movq %rax,-16(%rbp)
.L1229:
.L1226:
movq -80(%rbp),%rax
movq %rax,%rdi
call rt_free
.L1219:
movq -56(%rbp),%rax
movq %rax,%rdi
call rt_drop_exec_paths
jmp .L1215
.L1214:
.L1215:
jmp .L1206
.L1205:
.L1206:
movq $0,%rbx
.L1231:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L1232
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1233
call rt_abort
.L1233:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1234
call rt_abort
.L1234:
movq (%rax),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rax
addq $1,%rax
jnc .L1235
call rt_abort
.L1235:
movq %rax,%rbx
jmp .L1231
.L1232:
movq %r14,%rdi
call rt_free
movq $0,%rbx
.L1236:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L1237
movq %r15,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i19
call rt_abort
.Lopt36_i19:
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
jnc .L1238
call rt_abort
.L1238:
movq %rax,%rbx
jmp .L1236
.L1237:
movq %r15,%rdi
call rt_drop_seq
movq -16(%rbp),%rax
movq -.F1202-8(%rbp),%rbx
movq -.F1202-16(%rbp),%r12
movq -.F1202-24(%rbp),%r13
movq -.F1202-32(%rbp),%r14
movq -.F1202-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1202-8(%rbp),%rbx
movq -.F1202-16(%rbp),%r12
movq -.F1202-24(%rbp),%r13
movq -.F1202-32(%rbp),%r14
movq -.F1202-40(%rbp),%r15
leave
ret
.set .F1202,144
.type rt_utf8,@function
rt_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F1239,%rsp
subq $48,%rsp
movq %rbx,-.F1239-8(%rbp)
movq %r12,-.F1239-16(%rbp)
movq %r13,-.F1239-24(%rbp)
movq %r14,-.F1239-32(%rbp)
movq %r15,-.F1239-40(%rbp)
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
.L1240:
movq -16(%rbp),%rcx
cmpq %rcx,%rbx
jae .L1241
movq %r15,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt45
call rt_abort
.Lopt45:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq $0,%r14
cmpq $128,%rax
jae .L1242
movq %rbx,%rax
addq $1,%rax
jnc .L1244
call rt_abort
.L1244:
movq %rax,%rbx
jmp .L1240
jmp .L1243
.L1242:
.L1243:
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
jz .L1245
movq $2,%r14
jmp .L1246
.L1245:
.L1246:
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
jz .L1247
movq $3,%r14
jmp .L1248
.L1247:
.L1248:
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
jz .L1249
movq $4,%r14
jmp .L1250
.L1249:
.L1250:
movq %r14,%rax
cmpq $0,%r14
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq %r14,%rax
jnc .L1251
call rt_abort
.L1251:
movq %rax,%rcx
movq -16(%rbp),%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L1252
call rt_abort
.L1252:
testq %rax,%rax
jz .L1253
call rt_abort
jmp .L1254
.L1253:
.L1254:
movq %rbx,%rax
addq $1,%rax
jnc .L1255
call rt_abort
.L1255:
movq %r15,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt46
call rt_abort
.Lopt46:
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
jnc .L1256
call rt_abort
.L1256:
testq %rax,%rax
jz .L1257
call rt_abort
jmp .L1258
.L1257:
.L1258:
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
jz .L1259
call rt_abort
jmp .L1260
.L1259:
.L1260:
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
jz .L1261
call rt_abort
jmp .L1262
.L1261:
.L1262:
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
jz .L1263
call rt_abort
jmp .L1264
.L1263:
.L1264:
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
jz .L1265
call rt_abort
jmp .L1266
.L1265:
.L1266:
movq $2,%r13
.L1267:
cmpq %r14,%r13
jae .L1268
movq %rbx,%rax
addq %r13,%rax
jnc .L1269
call rt_abort
.L1269:
movq %r15,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt47
call rt_abort
.Lopt47:
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
jnc .L1270
call rt_abort
.L1270:
testq %rax,%rax
jz .L1271
call rt_abort
jmp .L1272
.L1271:
.L1272:
movq %r13,%rax
addq $1,%rax
jnc .L1273
call rt_abort
.L1273:
movq %rax,%r13
jmp .L1267
.L1268:
movq %rbx,%rax
addq %r14,%rax
jnc .L1274
call rt_abort
.L1274:
movq %rax,%rbx
jmp .L1240
.L1241:
movabsq $0,%rax
movq -.F1239-8(%rbp),%rbx
movq -.F1239-16(%rbp),%r12
movq -.F1239-24(%rbp),%r13
movq -.F1239-32(%rbp),%r14
movq -.F1239-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1239-8(%rbp),%rbx
movq -.F1239-16(%rbp),%r12
movq -.F1239-24(%rbp),%r13
movq -.F1239-32(%rbp),%r14
movq -.F1239-40(%rbp),%r15
leave
ret
.set .F1239,128
.type rt_text,@function
rt_text:
pushq %rbp
movq %rsp,%rbp
subq $.F1275,%rsp
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
.set .F1275,16
.type rt_string_lit,@function
rt_string_lit:
pushq %rbp
movq %rsp,%rbp
subq $.F1276,%rsp
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
.set .F1276,32
.type rt_append_text,@function
rt_append_text:
pushq %rbp
movq %rsp,%rbp
subq $.F1277,%rsp
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
.set .F1277,16
.type rt_atomic_new,@function
rt_atomic_new:
pushq %rbp
movq %rsp,%rbp
subq $.F1278,%rsp
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
.set .F1278,32
.type rt_atomic_load,@function
rt_atomic_load:
pushq %rbp
movq %rsp,%rbp
subq $.F1279,%rsp
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
.set .F1279,16
.type rt_atomic_load_relaxed,@function
rt_atomic_load_relaxed:
pushq %rbp
movq %rsp,%rbp
subq $.F1280,%rsp
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
.set .F1280,16
.type rt_atomic_load_acquire,@function
rt_atomic_load_acquire:
pushq %rbp
movq %rsp,%rbp
subq $.F1281,%rsp
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
.set .F1281,16
.type rt_atomic_store,@function
rt_atomic_store:
pushq %rbp
movq %rsp,%rbp
subq $.F1282,%rsp
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
.set .F1282,16
.type rt_atomic_store_relaxed,@function
rt_atomic_store_relaxed:
pushq %rbp
movq %rsp,%rbp
subq $.F1283,%rsp
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
.set .F1283,16
.type rt_atomic_store_release,@function
rt_atomic_store_release:
pushq %rbp
movq %rsp,%rbp
subq $.F1284,%rsp
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
.set .F1284,16
.type rt_atomic_compare_exchange,@function
rt_atomic_compare_exchange:
pushq %rbp
movq %rsp,%rbp
subq $.F1285,%rsp
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
.set .F1285,32
.type rt_atomic_fetch_add,@function
rt_atomic_fetch_add:
pushq %rbp
movq %rsp,%rbp
subq $.F1286,%rsp
subq $48,%rsp
movq %rbx,-.F1286-8(%rbp)
movq %r12,-.F1286-16(%rbp)
movq %r13,-.F1286-24(%rbp)
movq %r14,-.F1286-32(%rbp)
movq %r15,-.F1286-40(%rbp)
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
.L1287:
movabsq $1,%rax
testq %rax,%rax
jz .L1288
movq %rbx,%rax
addq %r15,%rax
movq %rax,%r12
movq %r14,%rdi
movq %rbx,%rax
movq %r12,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
cmpq %rbx,%rax
jne .L1289
movq %rbx,%rax
movq -.F1286-8(%rbp),%rbx
movq -.F1286-16(%rbp),%r12
movq -.F1286-24(%rbp),%r13
movq -.F1286-32(%rbp),%r14
movq -.F1286-40(%rbp),%r15
leave
ret
jmp .L1290
.L1289:
.L1290:
movq %r13,%rbx
jmp .L1287
.L1288:
movabsq $0,%rax
movq -.F1286-8(%rbp),%rbx
movq -.F1286-16(%rbp),%r12
movq -.F1286-24(%rbp),%r13
movq -.F1286-32(%rbp),%r14
movq -.F1286-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1286-8(%rbp),%rbx
movq -.F1286-16(%rbp),%r12
movq -.F1286-24(%rbp),%r13
movq -.F1286-32(%rbp),%r14
movq -.F1286-40(%rbp),%r15
leave
ret
.set .F1286,16
.type rt_atomic_fetch_sub,@function
rt_atomic_fetch_sub:
pushq %rbp
movq %rsp,%rbp
subq $.F1291,%rsp
subq $48,%rsp
movq %rbx,-.F1291-8(%rbp)
movq %r12,-.F1291-16(%rbp)
movq %r13,-.F1291-24(%rbp)
movq %r14,-.F1291-32(%rbp)
movq %r15,-.F1291-40(%rbp)
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
.L1292:
movabsq $1,%rax
testq %rax,%rax
jz .L1293
movq %rbx,%rax
subq %r15,%rax
movq %rax,%r12
movq %r14,%rdi
movq %rbx,%rax
movq %r12,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
cmpq %rbx,%rax
jne .L1294
movq %rbx,%rax
movq -.F1291-8(%rbp),%rbx
movq -.F1291-16(%rbp),%r12
movq -.F1291-24(%rbp),%r13
movq -.F1291-32(%rbp),%r14
movq -.F1291-40(%rbp),%r15
leave
ret
jmp .L1295
.L1294:
.L1295:
movq %r13,%rbx
jmp .L1292
.L1293:
movabsq $0,%rax
movq -.F1291-8(%rbp),%rbx
movq -.F1291-16(%rbp),%r12
movq -.F1291-24(%rbp),%r13
movq -.F1291-32(%rbp),%r14
movq -.F1291-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1291-8(%rbp),%rbx
movq -.F1291-16(%rbp),%r12
movq -.F1291-24(%rbp),%r13
movq -.F1291-32(%rbp),%r14
movq -.F1291-40(%rbp),%r15
leave
ret
.set .F1291,16
.type rt_atomic_swap,@function
rt_atomic_swap:
pushq %rbp
movq %rsp,%rbp
subq $.F1296,%rsp
subq $32,%rsp
movq %rbx,-.F1296-8(%rbp)
movq %r12,-.F1296-16(%rbp)
movq %r13,-.F1296-24(%rbp)
movq %r14,-.F1296-32(%rbp)
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
.L1297:
movabsq $1,%rax
testq %rax,%rax
jz .L1298
movq %r13,%rdi
movq %rbx,%rax
movq %r14,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r12
cmpq %rbx,%rax
jne .L1299
movq %rbx,%rax
movq -.F1296-8(%rbp),%rbx
movq -.F1296-16(%rbp),%r12
movq -.F1296-24(%rbp),%r13
movq -.F1296-32(%rbp),%r14
leave
ret
jmp .L1300
.L1299:
.L1300:
movq %r12,%rbx
jmp .L1297
.L1298:
movabsq $0,%rax
movq -.F1296-8(%rbp),%rbx
movq -.F1296-16(%rbp),%r12
movq -.F1296-24(%rbp),%r13
movq -.F1296-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1296-8(%rbp),%rbx
movq -.F1296-16(%rbp),%r12
movq -.F1296-24(%rbp),%r13
movq -.F1296-32(%rbp),%r14
leave
ret
.set .F1296,16
.type rt_mutex_new,@function
rt_mutex_new:
pushq %rbp
movq %rsp,%rbp
subq $.F1301,%rsp
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
jnc .L1302
call rt_abort
.L1302:
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
.set .F1301,32
.type rt_mutex_unlock,@function
rt_mutex_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F1303,%rsp
subq $16,%rsp
movq %rbx,-.F1303-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_sub
movq %rax,-16(%rbp)
movabsq $1,%rcx
cmpq $1,%rax
je .L1304
movq %rbx,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $129,%rdx
movabsq $1,%rcx
call rt_syscall
jmp .L1305
.L1304:
.L1305:
movabsq $0,%rax
movq -.F1303-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1303-8(%rbp),%rbx
leave
ret
.set .F1303,16
.type rt_cpus,@function
rt_cpus:
pushq %rbp
movq %rsp,%rbp
subq $.F1306,%rsp
subq $32,%rsp
movq %rbx,-.F1306-8(%rbp)
movq %r12,-.F1306-16(%rbp)
movq %r13,-.F1306-24(%rbp)
movq %r14,-.F1306-32(%rbp)
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
jne .L1307
movq $0,%r13
.L1309:
movabsq $128,%rcx
cmpq $128,%r13
jae .L1310
movq %r14,%rax
addq %r13,%rax
jnc .L1311
call rt_abort
.L1311:
movzbq (%rax),%rax
movq %rax,%rbx
.L1312:
cmpq $0,%rbx
je .L1313
movq %rbx,%rax
andq $1,%rax
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L1314
call rt_abort
.L1314:
movq %rax,%r12
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1315:
movq %rax,%rbx
jmp .L1312
.L1313:
movq %r13,%rax
addq $1,%rax
jnc .L1316
call rt_abort
.L1316:
movq %rax,%r13
jmp .L1309
.L1310:
jmp .L1308
.L1307:
.L1308:
movq %r14,%rdi
call rt_free
cmpq $0,%r12
jne .L1317
movq $1,%r12
jmp .L1318
.L1317:
.L1318:
movq %r12,%rax
movq -.F1306-8(%rbp),%rbx
movq -.F1306-16(%rbp),%r12
movq -.F1306-24(%rbp),%r13
movq -.F1306-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1306-8(%rbp),%rbx
movq -.F1306-16(%rbp),%r12
movq -.F1306-24(%rbp),%r13
movq -.F1306-32(%rbp),%r14
leave
ret
.set .F1306,16
.type rt_thread_spawn,@function
rt_thread_spawn:
pushq %rbp
movq %rsp,%rbp
subq $.F1319,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
leaq -.F1319(%rbp),%rdi
movq $.F1319/8-2,%rcx
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
jz .L1320
call rt_abort
movq %rax,-80(%rbp)
jmp .L1321
.L1320:
.L1321:
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
jz .L1322
call rt_abort
movq %rax,-168(%rbp)
jmp .L1323
.L1322:
.L1323:
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
jnc .L1324
call rt_abort
.L1324:
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
jnc .L1325
call rt_abort
.L1325:
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
jnc .L1326
call rt_abort
.L1326:
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
jnc .L1327
call rt_abort
.L1327:
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
jnc .L1328
call rt_abort
.L1328:
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
jnc .L1329
call rt_abort
.L1329:
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
jnc .L1330
call rt_abort
.L1330:
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
jnc .L1331
call rt_abort
.L1331:
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
jnc .L1332
call rt_abort
.L1332:
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
jnz .L1333
xorl %ebp,%ebp
popq %rax
popq %rdi
call *%rax
movl $60,%eax
xorl %edi,%edi
syscall
ud2
.L1333:
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
jz .L1334
call rt_abort
movq %rax,-648(%rbp)
jmp .L1335
.L1334:
.L1335:
movq -200(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1319,656
.type rt_thread_spawn_detached,@function
rt_thread_spawn_detached:
pushq %rbp
movq %rsp,%rbp
subq $.F1336,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
leaq -.F1336(%rbp),%rdi
movq $.F1336/8-2,%rcx
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
jz .L1337
call rt_abort
movq %rax,-80(%rbp)
jmp .L1338
.L1337:
.L1338:
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
jz .L1339
call rt_abort
movq %rax,-168(%rbp)
jmp .L1340
.L1339:
.L1340:
movq -56(%rbp),%rax
movq %rax,-176(%rbp)
movq -32(%rbp),%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L1341
call rt_abort
.L1341:
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
jnc .L1342
call rt_abort
.L1342:
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
jnc .L1343
call rt_abort
.L1343:
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
jnc .L1344
call rt_abort
.L1344:
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
jnc .L1345
call rt_abort
.L1345:
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
jnc .L1346
call rt_abort
.L1346:
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
jnc .L1347
call rt_abort
.L1347:
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
jnc .L1348
call rt_abort
.L1348:
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
jnz .L1349
xorl %ebp,%ebp
popq %rax
popq %rdi
call *%rax
movl $60,%eax
xorl %edi,%edi
syscall
ud2
.L1349:
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
jz .L1350
call rt_abort
movq %rax,-544(%rbp)
jmp .L1351
.L1350:
.L1351:
movabsq $0,%rax
movq %rax,-552(%rbp)
movq -552(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1336,560
.type rt_thread_main,@function
rt_thread_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1352,%rsp
subq $16,%rsp
movq %rbx,-.F1352-8(%rbp)
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
jnc .L1353
call rt_abort
.L1353:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1354
call rt_abort
.L1354:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
movq -16(%rbp),%rax
call *%rax
movabsq $0,%rax
movq -.F1352-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1352-8(%rbp),%rbx
leave
ret
.set .F1352,32
.type rt_thread_join,@function
rt_thread_join:
pushq %rbp
movq %rsp,%rbp
subq $.F1355,%rsp
subq $32,%rsp
movq %rbx,-.F1355-8(%rbp)
movq %r12,-.F1355-16(%rbp)
movq %r13,-.F1355-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
.L1356:
movabsq $1,%rax
testq %rax,%rax
jz .L1357
movq %rbx,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movq %rax,%r13
cmpq $0,%rax
jne .L1358
jmp .L1357
jmp .L1359
.L1358:
.L1359:
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $0,%rdx
movq %r12,%rcx
call rt_syscall
jmp .L1356
.L1357:
movq %rbx,%rax
addq $8,%rax
jnc .L1360
call rt_abort
.L1360:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rbx,%rax
addq $16,%rax
jnc .L1361
call rt_abort
.L1361:
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
jz .L1362
call rt_abort
jmp .L1363
.L1362:
.L1363:
movq %rbx,%rdi
call rt_free
movabsq $0,%rax
movq -.F1355-8(%rbp),%rbx
movq -.F1355-16(%rbp),%r12
movq -.F1355-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1355-8(%rbp),%rbx
movq -.F1355-16(%rbp),%r12
movq -.F1355-24(%rbp),%r13
leave
ret
.set .F1355,32
.type rt_parallel_worker,@function
rt_parallel_worker:
pushq %rbp
movq %rsp,%rbp
subq $.F1364,%rsp
subq $48,%rsp
movq %rbx,-.F1364-8(%rbp)
movq %r12,-.F1364-16(%rbp)
movq %r13,-.F1364-24(%rbp)
movq %r14,-.F1364-32(%rbp)
movq %r15,-.F1364-40(%rbp)
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
jnc .L1365
call rt_abort
.L1365:
movq (%rax),%rax
movq %rax,%r14
movq %r12,%rax
addq $16,%rax
jnc .L1366
call rt_abort
.L1366:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %r12,%rax
addq $24,%rax
jnc .L1367
call rt_abort
.L1367:
movq (%rax),%rax
movq %rax,%r15
movq %r12,%rax
addq $32,%rax
jnc .L1368
call rt_abort
.L1368:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %r12,%rax
addq $56,%rax
jnc .L1369
call rt_abort
.L1369:
movq (%rax),%rax
movq %rax,-32(%rbp)
.L1370:
movabsq $1,%rax
testq %rax,%rax
jz .L1371
movabsq $40,%rcx
movq %r12,%rax
addq $40,%rax
jnc .L1372
call rt_abort
.L1372:
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
jne .L1373
jmp .L1371
jmp .L1374
.L1373:
.L1374:
movq -32(%rbp),%rax
cmpq $0,%rax
jne .L1375
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1377
call rt_abort
.L1377:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1378
call rt_abort
.L1378:
movq %rax,-56(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1379
call rt_abort
.L1379:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1380
call rt_abort
.L1380:
movq (%rax),%rax
movq %rax,-64(%rbp)
movq -64(%rbp),%rdi
movq %r15,%rsi
movq %r13,%rax
call *%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L1376
.L1375:
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1381
call rt_abort
.L1381:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L1382
call rt_abort
.L1382:
movq %rax,-72(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1383
call rt_abort
.L1383:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L1384
call rt_abort
.L1384:
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
.L1376:
jmp .L1370
.L1371:
movabsq $48,%rcx
movq %r12,%rax
addq $48,%rax
jnc .L1385
call rt_abort
.L1385:
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movabsq $0,%rax
movq -.F1364-8(%rbp),%rbx
movq -.F1364-16(%rbp),%r12
movq -.F1364-24(%rbp),%r13
movq -.F1364-32(%rbp),%r14
movq -.F1364-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1364-8(%rbp),%rbx
movq -.F1364-16(%rbp),%r12
movq -.F1364-24(%rbp),%r13
movq -.F1364-32(%rbp),%r14
movq -.F1364-40(%rbp),%r15
leave
ret
.set .F1364,96
.type rt_parallel_map,@function
rt_parallel_map:
pushq %rbp
movq %rsp,%rbp
subq $.F1386,%rsp
subq $48,%rsp
movq %rbx,-.F1386-8(%rbp)
movq %r12,-.F1386-16(%rbp)
movq %r13,-.F1386-24(%rbp)
movq %r14,-.F1386-32(%rbp)
movq %r15,-.F1386-40(%rbp)
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
.L1387:
movq -40(%rbp),%rcx
cmpq %rcx,%r14
jae .L1388
movq -48(%rbp),%rdi
movabsq $0,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt48
call rt_push
jmp .Lopt49
.Lopt48:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt49:
movq %r14,%rax
addq $1,%rax
jnc .L1389
call rt_abort
.L1389:
movq %rax,%r14
jmp .L1387
.L1388:
movabsq $64,%rdi
call rt_alloc
movq %rax,%r13
movq %rax,-56(%rbp)
addq $56,%rax
jnc .L1390
call rt_abort
.L1390:
movq %rax,-64(%rbp)
movq -32(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $40,%rax
jnc .L1391
call rt_abort
.L1391:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %r13,%rax
addq $48,%rax
jnc .L1392
call rt_abort
.L1392:
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
jnc .L1393
call rt_abort
.L1393:
movq %rax,-88(%rbp)
movq -8(%rbp),%rax
movq (%rax),%rax
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $16,%rax
jnc .L1394
call rt_abort
.L1394:
movq %rax,-96(%rbp)
movq -40(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $24,%rax
jnc .L1395
call rt_abort
.L1395:
movq %rax,-104(%rbp)
movq -16(%rbp),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r13,%rax
addq $32,%rax
jnc .L1396
call rt_abort
.L1396:
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
jae .L1397
movq $4,%r12
jmp .L1398
.L1397:
.L1398:
movabsq $64,%rax
cmpq %r12,%rax
jae .L1399
movq $64,%r12
jmp .L1400
.L1399:
.L1400:
movq -40(%rbp),%rax
cmpq %r12,%rax
jae .L1401
movq -40(%rbp),%rax
movq %rax,%r12
jmp .L1402
.L1401:
.L1402:
cmpq $0,%r12
jne .L1403
movq $1,%r12
jmp .L1404
.L1403:
.L1404:
movabsq $8,%rcx
movq %r12,%rax
mulq %rcx
jnc .L1405
call rt_abort
.L1405:
movq %rax,%rdi
call rt_alloc
movq %rax,%r15
movq $1,%rbx
.L1406:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L1407
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1408
call rt_abort
.L1408:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1409
call rt_abort
.L1409:
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
jnc .L1410
call rt_abort
.L1410:
movq %rax,%rbx
jmp .L1406
.L1407:
movq %r13,%rdi
call rt_parallel_worker
movq $1,%rbx
.L1411:
cmpq %r12,%rbx
jae .L1412
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1413
call rt_abort
.L1413:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L1414
call rt_abort
.L1414:
movq (%rax),%rax
movq %rax,%rdi
call rt_thread_join
movq %rbx,%rax
addq $1,%rax
jnc .L1415
call rt_abort
.L1415:
movq %rax,%rbx
jmp .L1411
.L1412:
movabsq $48,%rcx
movq %r13,%rax
addq $48,%rax
jnc .L1416
call rt_abort
.L1416:
movq %rax,%rdi
call rt_atomic_load
movq %r12,%rcx
cmpq %r12,%rax
je .L1417
call rt_abort
jmp .L1418
.L1417:
.L1418:
movq %r15,%rdi
call rt_free
movq %r13,%rdi
call rt_free
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_drop_seq
movq -48(%rbp),%rax
movq -.F1386-8(%rbp),%rbx
movq -.F1386-16(%rbp),%r12
movq -.F1386-24(%rbp),%r13
movq -.F1386-32(%rbp),%r14
movq -.F1386-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1386-8(%rbp),%rbx
movq -.F1386-16(%rbp),%r12
movq -.F1386-24(%rbp),%r13
movq -.F1386-32(%rbp),%r14
movq -.F1386-40(%rbp),%r15
leave
ret
.set .F1386,144
.type rt_thread_init,@function
rt_thread_init:
pushq %rbp
movq %rsp,%rbp
subq $.F1419,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
leaq rt_state(%rip),%rax
movq %rax,-8(%rbp)
movq -8(%rbp),%rax
addq $128,%rax
jnc .L1420
call rt_abort
.L1420:
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
.set .F1419,16
.type rt_current,@function
rt_current:
pushq %rbp
movq %rsp,%rbp
subq $.F1421,%rsp
movq $0,-8(%rbp)
movq $0,-16(%rbp)
movq %fs:0,%rax
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1422
movabsq $0,%rax
leave
ret
jmp .L1423
.L1422:
.L1423:
movq -8(%rbp),%rax
addq $16,%rax
jnc .L1424
call rt_abort
.L1424:
movq (%rax),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1421,16
.type rt_spin_lock,@function
rt_spin_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F1425,%rsp
subq $16,%rsp
movq %rbx,-.F1425-8(%rbp)
movq %r12,-.F1425-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq $0,-16(%rbp)
.L1426:
movq %r12,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%rbx
cmpq $0,%rax
je .L1427
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L1426
.L1427:
movabsq $0,%rax
movq -.F1425-8(%rbp),%rbx
movq -.F1425-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1425-8(%rbp),%rbx
movq -.F1425-16(%rbp),%r12
leave
ret
.set .F1425,16
.type rt_spin_unlock,@function
rt_spin_unlock:
pushq %rbp
movq %rsp,%rbp
subq $.F1428,%rsp
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
.set .F1428,16
.type rt_sched,@function
rt_sched:
pushq %rbp
movq %rsp,%rbp
subq $.F1429,%rsp
subq $48,%rsp
movq %rbx,-.F1429-8(%rbp)
movq %r12,-.F1429-16(%rbp)
movq %r13,-.F1429-24(%rbp)
movq %r14,-.F1429-32(%rbp)
movq %r15,-.F1429-40(%rbp)
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
jnc .L1430
call rt_abort
.L1430:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
cmpq $0,%rax
je .L1431
movq -16(%rbp),%rax
movq -.F1429-8(%rbp),%rbx
movq -.F1429-16(%rbp),%r12
movq -.F1429-24(%rbp),%r13
movq -.F1429-32(%rbp),%r14
movq -.F1429-40(%rbp),%r15
leave
ret
jmp .L1432
.L1431:
.L1432:
movq %r14,%rax
addq $80,%rax
jnc .L1433
call rt_abort
.L1433:
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1434
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
jz .L1436
call rt_abort
jmp .L1437
.L1436:
.L1437:
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
jz .L1438
call rt_abort
jmp .L1439
.L1438:
.L1439:
movq %r12,%rax
addq $40,%rax
jnc .L1440
call rt_abort
.L1440:
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
jz .L1441
call rt_abort
jmp .L1442
.L1441:
.L1442:
movq %r12,%rax
addq $48,%rax
jnc .L1443
call rt_abort
.L1443:
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
jz .L1444
call rt_abort
jmp .L1445
.L1444:
.L1445:
movabsq $11,%rdi
movq -80(%rbp),%rsi
movabsq $4096,%rdx
movabsq $0,%rcx
call rt_syscall
call rt_cpus
movq %rax,%r13
movq %rax,-96(%rbp)
cmpq $4,%rax
jae .L1446
movq $4,%r13
jmp .L1447
.L1446:
.L1447:
movabsq $64,%rax
cmpq %r13,%rax
jae .L1448
movq $64,%r13
jmp .L1449
.L1448:
.L1449:
movq %r12,%rax
addq $32,%rax
jnc .L1450
call rt_abort
.L1450:
movq %rax,-104(%rbp)
movq %r13,%rax
movq -104(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L1451
call rt_abort
.L1451:
movq %rax,-112(%rbp)
movq %r12,%rax
movq -112(%rbp),%rdi
xchgq %rax,(%rdi)
xorq %rax,%rax
movq $0,%rbx
.L1452:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L1453
leaq rt_worker_loop(%rip),%rax
movq %rax,%r15
movq %r15,%rdi
movq %r12,%rsi
call rt_thread_spawn_detached
movq %rbx,%rax
addq $1,%rax
jnc .L1454
call rt_abort
.L1454:
movq %rax,%rbx
jmp .L1452
.L1453:
leaq rt_reactor(%rip),%rax
movq %rax,-120(%rbp)
movq -120(%rbp),%rdi
movq %r12,%rsi
call rt_thread_spawn_detached
movq %r12,%rax
movq -.F1429-8(%rbp),%rbx
movq -.F1429-16(%rbp),%r12
movq -.F1429-24(%rbp),%r13
movq -.F1429-32(%rbp),%r14
movq -.F1429-40(%rbp),%r15
leave
ret
jmp .L1435
.L1434:
.L1435:
.L1455:
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L1457
call rt_abort
.L1457:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,-128(%rbp)
cmpq $0,%rax
jne .L1456
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L1455
.L1456:
movabsq $72,%rcx
movq %r14,%rax
addq $72,%rax
jnc .L1458
call rt_abort
.L1458:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq -.F1429-8(%rbp),%rbx
movq -.F1429-16(%rbp),%r12
movq -.F1429-24(%rbp),%r13
movq -.F1429-32(%rbp),%r14
movq -.F1429-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1429-8(%rbp),%rbx
movq -.F1429-16(%rbp),%r12
movq -.F1429-24(%rbp),%r13
movq -.F1429-32(%rbp),%r14
movq -.F1429-40(%rbp),%r15
leave
ret
.set .F1429,128
.type rt_enqueue,@function
rt_enqueue:
pushq %rbp
movq %rsp,%rbp
subq $.F1459,%rsp
subq $16,%rsp
movq %rbx,-.F1459-8(%rbp)
movq %r12,-.F1459-16(%rbp)
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
jnc .L1460
call rt_abort
.L1460:
movq %rax,-16(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1461
call rt_abort
.L1461:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L1462
movq %rbx,%rax
addq $8,%rax
jnc .L1464
call rt_abort
.L1464:
movq %rax,-40(%rbp)
movq %r12,%rax
movq -40(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L1463
.L1462:
movq -24(%rbp),%rax
addq $32,%rax
jnc .L1465
call rt_abort
.L1465:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
.L1463:
movq %rbx,%rax
addq $16,%rax
jnc .L1466
call rt_abort
.L1466:
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
jnc .L1467
call rt_abort
.L1467:
movq %rax,-64(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
movq %rbx,%rax
addq $24,%rax
jnc .L1468
call rt_abort
.L1468:
movq %rax,-72(%rbp)
movabsq $202,%rdi
movq %rax,%rsi
movabsq $129,%rdx
movabsq $1,%rcx
call rt_syscall
movabsq $0,%rax
movq -.F1459-8(%rbp),%rbx
movq -.F1459-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1459-8(%rbp),%rbx
movq -.F1459-16(%rbp),%r12
leave
ret
.set .F1459,80
.type rt_dequeue,@function
rt_dequeue:
pushq %rbp
movq %rsp,%rbp
subq $.F1469,%rsp
subq $48,%rsp
movq %rbx,-.F1469-8(%rbp)
movq %r12,-.F1469-16(%rbp)
movq %r13,-.F1469-24(%rbp)
movq %r14,-.F1469-32(%rbp)
movq %r15,-.F1469-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
.L1470:
movabsq $1,%rax
testq %rax,%rax
jz .L1471
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1472
call rt_abort
.L1472:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r14
movq %rbx,%rdi
call rt_spin_lock
movq %rbx,%rax
addq $8,%rax
jnc .L1473
call rt_abort
.L1473:
movq (%rax),%rax
movq %rax,%r12
movq %rax,%r15
movabsq $0,%rcx
cmpq $0,%rax
je .L1474
movq %r12,%rax
addq $32,%rax
jnc .L1476
call rt_abort
.L1476:
movq (%rax),%rax
movq %rax,%r13
movq %rbx,%rax
addq $8,%rax
jnc .L1477
call rt_abort
.L1477:
movq %rax,-16(%rbp)
movq %r13,%rax
movq -16(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movabsq $0,%rcx
cmpq $0,%r13
jne .L1478
movq %rbx,%rax
addq $16,%rax
jnc .L1480
call rt_abort
.L1480:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
jmp .L1479
.L1478:
.L1479:
movq %rbx,%rdi
call rt_spin_unlock
movq %r12,%rax
movq -.F1469-8(%rbp),%rbx
movq -.F1469-16(%rbp),%r12
movq -.F1469-24(%rbp),%r13
movq -.F1469-32(%rbp),%r14
movq -.F1469-40(%rbp),%r15
leave
ret
jmp .L1475
.L1474:
.L1475:
movq %rbx,%rdi
call rt_spin_unlock
movq %rbx,%rax
addq $24,%rax
jnc .L1481
call rt_abort
.L1481:
movq %rax,-32(%rbp)
movabsq $202,%rdi
movq -32(%rbp),%rsi
movabsq $128,%rdx
movq %r14,%rcx
call rt_syscall
jmp .L1470
.L1471:
movabsq $0,%rax
movq -.F1469-8(%rbp),%rbx
movq -.F1469-16(%rbp),%r12
movq -.F1469-24(%rbp),%r13
movq -.F1469-32(%rbp),%r14
movq -.F1469-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1469-8(%rbp),%rbx
movq -.F1469-16(%rbp),%r12
movq -.F1469-24(%rbp),%r13
movq -.F1469-32(%rbp),%r14
movq -.F1469-40(%rbp),%r15
leave
ret
.set .F1469,32
.type rt_worker_loop,@function
rt_worker_loop:
pushq %rbp
movq %rsp,%rbp
subq $.F1482,%rsp
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
.L1483:
movabsq $1,%rax
testq %rax,%rax
jz .L1484
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_dequeue
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
addq $16,%rax
jnc .L1485
call rt_abort
.L1485:
movq %rax,-32(%rbp)
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $8,%rcx
movq -16(%rbp),%rax
addq $8,%rax
jnc .L1486
call rt_abort
.L1486:
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
movq (%rax),%rax
movq -40(%rbp),%rdi
movq %rax,%rsi
leaq .L1487(%rip),%rax
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
.L1487:
xorl %eax,%eax
movq -16(%rbp),%rax
addq $16,%rax
jnc .L1488
call rt_abort
.L1488:
movq %rax,-48(%rbp)
movq -48(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
addq $144,%rax
jnc .L1489
call rt_abort
.L1489:
movq (%rax),%rax
testq %rax,%rax
jz .L1490
movq -24(%rbp),%rax
addq $8,%rax
jnc .L1492
call rt_abort
.L1492:
movq (%rax),%rax
movq %rax,-56(%rbp)
movq -24(%rbp),%rax
addq $16,%rax
jnc .L1493
call rt_abort
.L1493:
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
jz .L1494
call rt_abort
jmp .L1495
.L1494:
.L1495:
movabsq $96,%rcx
movq -24(%rbp),%rax
addq $96,%rax
jnc .L1496
call rt_abort
.L1496:
movq %rax,-72(%rbp)
movq -72(%rbp),%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -24(%rbp),%rax
addq $96,%rax
jnc .L1497
call rt_abort
.L1497:
movq %rax,-80(%rbp)
movabsq $202,%rdi
movq -80(%rbp),%rsi
movabsq $129,%rdx
movabsq $2147483647,%rcx
call rt_syscall
movabsq $88,%rcx
movq -24(%rbp),%rax
addq $88,%rax
jnc .L1498
call rt_abort
.L1498:
movq %rax,-88(%rbp)
movq -88(%rbp),%rdi
movabsq $1,%rsi
call rt_atomic_swap
movq %rax,-96(%rbp)
movq -96(%rbp),%rcx
movabsq $1,%rax
cmpq %rcx,%rax
jae .L1499
movq -96(%rbp),%rax
movq %rax,%rdi
call rt_wake
jmp .L1500
.L1499:
.L1500:
jmp .L1491
.L1490:
movq -24(%rbp),%rax
addq $136,%rax
jnc .L1501
call rt_abort
.L1501:
movq (%rax),%rax
testq %rax,%rax
jz .L1502
movq -24(%rbp),%rax
addq $136,%rax
jnc .L1504
call rt_abort
.L1504:
movq %rax,-104(%rbp)
movq -104(%rbp),%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_enqueue
jmp .L1503
.L1502:
movq -24(%rbp),%rax
addq $24,%rax
jnc .L1505
call rt_abort
.L1505:
movq %rax,-112(%rbp)
movq -112(%rbp),%rdi
movabsq $1,%rax
movabsq $2,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-120(%rbp)
movabsq $1,%rcx
movq -120(%rbp),%rax
cmpq $1,%rax
je .L1506
movabsq $24,%rcx
movq -24(%rbp),%rax
addq $24,%rax
jnc .L1508
call rt_abort
.L1508:
movq %rax,-128(%rbp)
movq -128(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_enqueue
jmp .L1507
.L1506:
.L1507:
.L1503:
.L1491:
jmp .L1483
.L1484:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1482,128
.type rt_green_main,@function
rt_green_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1509,%rsp
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
jne .L1422_i34
movabsq $0,%rax
jmp .Lret_i34
jmp .L1423_i34
.L1422_i34:
.L1423_i34:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i34
call rt_abort
.L1424_i34:
movq (%rax),%rax
jmp .Lret_i34
xorq %rax,%rax
jmp .Lret_i34
.Lret_i34:
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
addq $40,%rax
jnc .L1510
call rt_abort
.L1510:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
addq $48,%rax
jnc .L1511
call rt_abort
.L1511:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -8(%rbp),%rax
addq $56,%rax
jnc .L1512
call rt_abort
.L1512:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $64,%rax
jnc .L1513
call rt_abort
.L1513:
movq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $3,%rcx
movq -56(%rbp),%rax
cmpq $3,%rax
jne .L1514
movabsq $72,%rcx
movq -8(%rbp),%rax
addq $72,%rax
jnc .L1516
call rt_abort
.L1516:
movq (%rax),%rax
movq -32(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
movq -24(%rbp),%rax
call *%rax
movq %rax,-48(%rbp)
jmp .L1515
.L1514:
movq -40(%rbp),%rax
movq -32(%rbp),%rdi
movq %rax,%rsi
movq -24(%rbp),%rax
call *%rax
movq %rax,-48(%rbp)
.L1515:
movq -8(%rbp),%rax
addq $80,%rax
jnc .L1517
call rt_abort
.L1517:
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -8(%rbp),%rax
addq $144,%rax
jnc .L1518
call rt_abort
.L1518:
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
jnc .L1519
call rt_abort
.L1519:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1520(%rip),%rax
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
.L1520:
xorl %eax,%eax
call rt_abort
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1509,80
.type rt_suspend,@function
rt_suspend:
pushq %rbp
movq %rsp,%rbp
subq $.F1521,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1522
call rt_abort
.L1522:
movq %rax,-16(%rbp)
movq -16(%rbp),%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-24(%rbp)
movq -24(%rbp),%rax
cmpq $0,%rax
je .L1523
movabsq $24,%rcx
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1525
call rt_abort
.L1525:
movq %rax,-32(%rbp)
movq -32(%rbp),%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
leave
ret
jmp .L1524
.L1523:
.L1524:
movq %fs:0,%rax
movq %rax,-40(%rbp)
movabsq $8,%rcx
movq -40(%rbp),%rax
addq $8,%rax
jnc .L1526
call rt_abort
.L1526:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1527(%rip),%rax
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
.L1527:
xorl %eax,%eax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1521,48
.type rt_wake,@function
rt_wake:
pushq %rbp
movq %rsp,%rbp
subq $.F1528,%rsp
subq $48,%rsp
movq %rbx,-.F1528-8(%rbp)
movq %r12,-.F1528-16(%rbp)
movq %r13,-.F1528-24(%rbp)
movq %r14,-.F1528-32(%rbp)
movq %r15,-.F1528-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq $0,-16(%rbp)
.L1529:
movabsq $1,%rax
testq %rax,%rax
jz .L1530
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1531
call rt_abort
.L1531:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movq %rax,%r13
cmpq $2,%rax
jne .L1532
movq %rbx,%rax
addq $24,%rax
jnc .L1534
call rt_abort
.L1534:
movq %rax,%r14
movq %rax,%rdi
movabsq $2,%rax
movabsq $0,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r15
movabsq $2,%rcx
cmpq $2,%rax
jne .L1535
movq %rbx,%rdi
call rt_enqueue
movabsq $0,%rax
movq -.F1528-8(%rbp),%rbx
movq -.F1528-16(%rbp),%r12
movq -.F1528-24(%rbp),%r13
movq -.F1528-32(%rbp),%r14
movq -.F1528-40(%rbp),%r15
leave
ret
jmp .L1536
.L1535:
.L1536:
jmp .L1533
.L1532:
cmpq $3,%r12
jne .L1537
movabsq $0,%rax
movq -.F1528-8(%rbp),%rbx
movq -.F1528-16(%rbp),%r12
movq -.F1528-24(%rbp),%r13
movq -.F1528-32(%rbp),%r14
movq -.F1528-40(%rbp),%r15
leave
ret
jmp .L1538
.L1537:
.L1538:
movq %rbx,%rax
addq $24,%rax
jnc .L1539
call rt_abort
.L1539:
movq %rax,-16(%rbp)
movq %rax,%rdi
movq %r12,%rax
movabsq $3,%rcx
lock cmpxchgq %rcx,(%rdi)
cmpq %r12,%rax
jne .L1540
movabsq $0,%rax
movq -.F1528-8(%rbp),%rbx
movq -.F1528-16(%rbp),%r12
movq -.F1528-24(%rbp),%r13
movq -.F1528-32(%rbp),%r14
movq -.F1528-40(%rbp),%r15
leave
ret
jmp .L1541
.L1540:
.L1541:
.L1533:
jmp .L1529
.L1530:
movabsq $0,%rax
movq -.F1528-8(%rbp),%rbx
movq -.F1528-16(%rbp),%r12
movq -.F1528-24(%rbp),%r13
movq -.F1528-32(%rbp),%r14
movq -.F1528-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1528-8(%rbp),%rbx
movq -.F1528-16(%rbp),%r12
movq -.F1528-24(%rbp),%r13
movq -.F1528-32(%rbp),%r14
movq -.F1528-40(%rbp),%r15
leave
ret
.set .F1528,16
.type rt_yield,@function
rt_yield:
pushq %rbp
movq %rsp,%rbp
subq $.F1542,%rsp
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
jne .L1422_i35
movabsq $0,%rax
jmp .Lret_i35
jmp .L1423_i35
.L1422_i35:
.L1423_i35:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i35
call rt_abort
.L1424_i35:
movq (%rax),%rax
jmp .Lret_i35
xorq %rax,%rax
jmp .Lret_i35
.Lret_i35:
movq %rax,-8(%rbp)
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1543
movabsq $24,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
leave
ret
jmp .L1544
.L1543:
.L1544:
movq -8(%rbp),%rax
addq $136,%rax
jnc .L1545
call rt_abort
.L1545:
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
jnc .L1546
call rt_abort
.L1546:
movq (%rax),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
leaq .L1547(%rip),%rax
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
.L1547:
xorl %eax,%eax
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1542,32
.type rt_mutex_lock,@function
rt_mutex_lock:
pushq %rbp
movq %rsp,%rbp
subq $.F1548,%rsp
subq $32,%rsp
movq %rbx,-.F1548-8(%rbp)
movq %r12,-.F1548-16(%rbp)
movq %r13,-.F1548-24(%rbp)
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
jne .L1422_i36
movabsq $0,%rax
jmp .Lret_i36
jmp .L1423_i36
.L1422_i36:
.L1423_i36:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i36
call rt_abort
.L1424_i36:
movq (%rax),%rax
jmp .Lret_i36
xorq %rax,%rax
jmp .Lret_i36
.Lret_i36:
movq %rax,-16(%rbp)
cmpq $0,%rax
je .L1549
.L1551:
movq %rbx,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
je .L1552
call rt_yield
jmp .L1551
.L1552:
movabsq $0,%rax
movq -.F1548-8(%rbp),%rbx
movq -.F1548-16(%rbp),%r12
movq -.F1548-24(%rbp),%r13
leave
ret
jmp .L1550
.L1549:
.L1550:
movq %rbx,%rdi
movabsq $0,%rax
movabsq $1,%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,%r12
movq %rax,-24(%rbp)
cmpq $0,%rax
jne .L1553
movabsq $0,%rax
movq -.F1548-8(%rbp),%rbx
movq -.F1548-16(%rbp),%r12
movq -.F1548-24(%rbp),%r13
leave
ret
jmp .L1554
.L1553:
.L1554:
movabsq $2,%rcx
cmpq $2,%r12
je .L1555
movq %rbx,%rdi
movabsq $2,%rsi
call rt_atomic_swap
movq %rax,%r12
jmp .L1556
.L1555:
.L1556:
.L1557:
cmpq $0,%r12
je .L1558
movabsq $202,%rdi
movq %rbx,%rsi
movabsq $128,%rdx
movabsq $2,%rcx
call rt_syscall
movq %rbx,%rdi
movabsq $2,%rsi
call rt_atomic_swap
movq %rax,%r12
jmp .L1557
.L1558:
movabsq $0,%rax
movq -.F1548-8(%rbp),%rbx
movq -.F1548-16(%rbp),%r12
movq -.F1548-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1548-8(%rbp),%rbx
movq -.F1548-16(%rbp),%r12
movq -.F1548-24(%rbp),%r13
leave
ret
.set .F1548,32
.type rt_scope_begin,@function
rt_scope_begin:
pushq %rbp
movq %rsp,%rbp
subq $.F1559,%rsp
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
jnc .L1560
call rt_abort
.L1560:
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
.set .F1559,32
.type rt_scope_token,@function
rt_scope_token:
pushq %rbp
movq %rsp,%rbp
subq $.F1561,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L1562
call rt_abort
.L1562:
leave
ret
xorq %rax,%rax
leave
ret
.set .F1561,16
.type rt_cancelled,@function
rt_cancelled:
pushq %rbp
movq %rsp,%rbp
subq $.F1563,%rsp
subq $16,%rsp
movq %rbx,-.F1563-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq %rbx,%rax
movq (%rax),%rax
movq %rbx,%rcx
cmpq %rbx,%rax
jne .L1564
movabsq $8,%rcx
movq %rbx,%rax
addq $8,%rax
jnc .L1566
call rt_abort
.L1566:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq -.F1563-8(%rbp),%rbx
leave
ret
jmp .L1565
.L1564:
.L1565:
movq %rbx,%rdi
movq (%rdi),%rax
mfence
movq -.F1563-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1563-8(%rbp),%rbx
leave
ret
.set .F1563,16
.type rt_cancel,@function
rt_cancel:
pushq %rbp
movq %rsp,%rbp
subq $.F1567,%rsp
subq $16,%rsp
movq %rbx,-.F1567-8(%rbp)
movq $0,%rbx
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $8,%rcx
movq -8(%rbp),%rax
addq $8,%rax
jnc .L1568
call rt_abort
.L1568:
movq %rax,-16(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1569
call rt_abort
.L1569:
movq (%rax),%rax
movq %rax,%rbx
.L1570:
cmpq $0,%rbx
je .L1571
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1572
call rt_abort
.L1572:
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1573
movq %rbx,%rdi
call rt_wake
jmp .L1574
.L1573:
.L1574:
movq %rbx,%rax
addq $120,%rax
jnc .L1575
call rt_abort
.L1575:
movq (%rax),%rax
movq %rax,%rbx
jmp .L1570
.L1571:
movabsq $0,%rax
movq -.F1567-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1567-8(%rbp),%rbx
leave
ret
.set .F1567,16
.type rt_task_spawn,@function
rt_task_spawn:
pushq %rbp
movq %rsp,%rbp
subq $.F1576,%rsp
subq $32,%rsp
movq %rbx,-.F1576-8(%rbp)
movq %r12,-.F1576-16(%rbp)
movq %r13,-.F1576-24(%rbp)
movq %r14,-.F1576-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq %r8,-40(%rbp)
leaq -.F1576(%rbp),%rdi
movq $.F1576/8-5,%rcx
xorl %eax,%eax
rep stosq
movabsq $152,%rdi
call rt_alloc
movq %rax,%rbx
movq %rax,-48(%rbp)
addq $40,%rax
jnc .L1577
call rt_abort
.L1577:
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $48,%rax
jnc .L1578
call rt_abort
.L1578:
movq %rax,-64(%rbp)
movq -24(%rbp),%rax
movq -64(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $56,%rax
jnc .L1579
call rt_abort
.L1579:
movq %rax,-72(%rbp)
movq %r12,%rax
addq $16,%rax
jnc .L1580
call rt_abort
.L1580:
movq (%rax),%rax
movq -72(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $64,%rax
jnc .L1581
call rt_abort
.L1581:
movq %rax,-80(%rbp)
movq -32(%rbp),%rax
movq -80(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $72,%rax
jnc .L1582
call rt_abort
.L1582:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $8,%rax
jnc .L1583
call rt_abort
.L1583:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $112,%rax
jnc .L1584
call rt_abort
.L1584:
movq %rax,-96(%rbp)
movq -40(%rbp),%rax
movq -96(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $120,%rax
jnc .L1585
call rt_abort
.L1585:
movq %rax,-104(%rbp)
movq %r12,%rax
addq $24,%rax
jnc .L1586
call rt_abort
.L1586:
movq (%rax),%rax
movq -104(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r12,%rax
addq $24,%rax
jnc .L1587
call rt_abort
.L1587:
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
jz .L1588
call rt_abort
jmp .L1589
.L1588:
.L1589:
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
jz .L1590
call rt_abort
jmp .L1591
.L1590:
.L1591:
movq %rbx,%rax
addq $8,%rax
jnc .L1592
call rt_abort
.L1592:
movq %rax,-128(%rbp)
movq %r13,%rax
movq -128(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1593
call rt_abort
.L1593:
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
jne .L1594
movq $22,%r14
jmp .L1595
.L1594:
.L1595:
movq -144(%rbp),%rax
cmpq $2,%rax
jne .L1596
movq $26,%r14
movq $25,-152(%rbp)
jmp .L1597
.L1596:
.L1597:
movq %r13,%rax
movq -120(%rbp),%rcx
addq %rcx,%rax
jnc .L1598
call rt_abort
.L1598:
movq %rax,-160(%rbp)
movabsq $8,%rcx
movq %r14,%rax
mulq %rcx
jnc .L1599
call rt_abort
.L1599:
movq %rax,%rcx
movq -160(%rbp),%rax
subq %rcx,%rax
jnc .L1600
call rt_abort
.L1600:
movq %rax,-168(%rbp)
movq %rax,-176(%rbp)
movabsq $8,%rcx
movq -152(%rbp),%rax
mulq %rcx
jnc .L1601
call rt_abort
.L1601:
movq %rax,%rcx
movq -176(%rbp),%rax
addq %rcx,%rax
jnc .L1602
call rt_abort
.L1602:
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
movq -.F1576-8(%rbp),%rbx
movq -.F1576-16(%rbp),%r12
movq -.F1576-24(%rbp),%r13
movq -.F1576-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1576-8(%rbp),%rbx
movq -.F1576-16(%rbp),%r12
movq -.F1576-24(%rbp),%r13
movq -.F1576-32(%rbp),%r14
leave
ret
.set .F1576,192
.type rt_task_wait,@function
rt_task_wait:
pushq %rbp
movq %rsp,%rbp
subq $.F1603,%rsp
subq $48,%rsp
movq %rbx,-.F1603-8(%rbp)
movq %r12,-.F1603-16(%rbp)
movq %r13,-.F1603-24(%rbp)
movq %r14,-.F1603-32(%rbp)
movq %r15,-.F1603-40(%rbp)
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
jnc .L1604
call rt_abort
.L1604:
movq %rax,%rdi
movq (%rdi),%rax
mfence
testq %rax,%rax
jz .L1605
movabsq $0,%rax
movq -.F1603-8(%rbp),%rbx
movq -.F1603-16(%rbp),%r12
movq -.F1603-24(%rbp),%r13
movq -.F1603-32(%rbp),%r14
movq -.F1603-40(%rbp),%r15
leave
ret
jmp .L1606
.L1605:
.L1606:
movq $0,%r8
movq $0,%r9
movq %fs:0,%rax
movq %rax,%r8
movq %rax,%r9
movq %r9,%rax
cmpq $0,%rax
jne .L1422_i39
movabsq $0,%rax
jmp .Lret_i39
jmp .L1423_i39
.L1422_i39:
.L1423_i39:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i39
call rt_abort
.L1424_i39:
movq (%rax),%rax
jmp .Lret_i39
xorq %rax,%rax
jmp .Lret_i39
.Lret_i39:
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
cmpq $0,%rax
je .L1607
movq %rbx,%rax
addq $88,%rax
jnc .L1609
call rt_abort
.L1609:
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rax
movq -16(%rbp),%rcx
lock cmpxchgq %rcx,(%rdi)
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L1610
.L1612:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1614
call rt_abort
.L1614:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $0,%rcx
cmpq $0,%rax
jne .L1613
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_suspend
jmp .L1612
.L1613:
jmp .L1611
.L1610:
.L1611:
.L1615:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1617
call rt_abort
.L1617:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%rax
jne .L1616
call rt_yield
jmp .L1615
.L1616:
movabsq $0,%rax
movq -.F1603-8(%rbp),%rbx
movq -.F1603-16(%rbp),%r12
movq -.F1603-24(%rbp),%r13
movq -.F1603-32(%rbp),%r14
movq -.F1603-40(%rbp),%r15
leave
ret
jmp .L1608
.L1607:
.L1608:
.L1618:
movabsq $96,%rcx
movq %rbx,%rax
addq $96,%rax
jnc .L1620
call rt_abort
.L1620:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r14
cmpq $0,%rax
jne .L1619
movq %rbx,%rax
addq $96,%rax
jnc .L1621
call rt_abort
.L1621:
movq %rax,%r15
movabsq $202,%rdi
movq %rax,%rsi
movabsq $128,%rdx
movabsq $0,%rcx
call rt_syscall
jmp .L1618
.L1619:
movabsq $0,%rax
movq -.F1603-8(%rbp),%rbx
movq -.F1603-16(%rbp),%r12
movq -.F1603-24(%rbp),%r13
movq -.F1603-32(%rbp),%r14
movq -.F1603-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1603-8(%rbp),%rbx
movq -.F1603-16(%rbp),%r12
movq -.F1603-24(%rbp),%r13
movq -.F1603-32(%rbp),%r14
movq -.F1603-40(%rbp),%r15
leave
ret
.set .F1603,48
.type rt_task_join,@function
rt_task_join:
pushq %rbp
movq %rsp,%rbp
subq $.F1622,%rsp
subq $16,%rsp
movq %rbx,-.F1622-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq %rbx,%rax
addq $104,%rax
jnc .L1623
call rt_abort
.L1623:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1624
call rt_abort
jmp .L1625
.L1624:
.L1625:
movq %rbx,%rdi
call rt_task_wait
movq %rbx,%rax
addq $104,%rax
jnc .L1626
call rt_abort
.L1626:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $1,%rax
movq $1,(%rcx)
xorq $1,%rax
movq %rbx,%rax
addq $80,%rax
jnc .L1627
call rt_abort
.L1627:
movq (%rax),%rax
movq -.F1622-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1622-8(%rbp),%rbx
leave
ret
.set .F1622,32
.type rt_task_abandon,@function
rt_task_abandon:
pushq %rbp
movq %rsp,%rbp
subq $.F1628,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $104,%rax
jnc .L1629
call rt_abort
.L1629:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L1630
movq -8(%rbp),%rax
addq $104,%rax
jnc .L1632
call rt_abort
.L1632:
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
movabsq $2,%rax
movq $2,(%rcx)
xorq $2,%rax
jmp .L1631
.L1630:
.L1631:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1628,32
.type rt_reactor_fence,@function
rt_reactor_fence:
pushq %rbp
movq %rsp,%rbp
subq $.F1633,%rsp
subq $16,%rsp
movq %rbx,-.F1633-8(%rbp)
movq %r12,-.F1633-16(%rbp)
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
jnc .L1634
call rt_abort
.L1634:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%rbx
movq %rax,-16(%rbp)
cmpq $0,%rax
jne .L1635
movabsq $0,%rax
movq -.F1633-8(%rbp),%rbx
movq -.F1633-16(%rbp),%r12
leave
ret
jmp .L1636
.L1635:
.L1636:
movabsq $56,%rcx
movq %rbx,%rax
addq $56,%rax
jnc .L1637
call rt_abort
.L1637:
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
jnc .L1638
call rt_abort
.L1638:
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
.L1639:
movabsq $56,%rcx
movq %rbx,%rax
addq $56,%rax
jnc .L1641
call rt_abort
.L1641:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %r12,%rcx
cmpq %r12,%rax
jne .L1640
call rt_yield
jmp .L1639
.L1640:
movabsq $0,%rax
movq -.F1633-8(%rbp),%rbx
movq -.F1633-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1633-8(%rbp),%rbx
movq -.F1633-16(%rbp),%r12
leave
ret
.set .F1633,48
.type rt_scope_end,@function
rt_scope_end:
pushq %rbp
movq %rsp,%rbp
subq $.F1642,%rsp
subq $48,%rsp
movq %rbx,-.F1642-8(%rbp)
movq %r12,-.F1642-16(%rbp)
movq %r13,-.F1642-24(%rbp)
movq %r14,-.F1642-32(%rbp)
movq %r15,-.F1642-40(%rbp)
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
jnc .L1643
call rt_abort
.L1643:
movq (%rax),%rax
movq %rax,%rbx
movq %rax,%r12
.L1644:
movabsq $0,%rcx
cmpq $0,%r12
je .L1645
movq %r12,%rdi
call rt_task_wait
movq %r12,%rax
addq $120,%rax
jnc .L1646
call rt_abort
.L1646:
movq (%rax),%rax
movq %rax,%r12
jmp .L1644
.L1645:
movq -8(%rbp),%rax
addq $24,%rax
jnc .L1647
call rt_abort
.L1647:
movq (%rax),%rax
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1648
call rt_reactor_fence
jmp .L1649
.L1648:
.L1649:
.L1650:
movabsq $0,%rcx
cmpq $0,%rbx
je .L1651
movq %rbx,%rdi
call rt_task_wait
movq %rbx,%rax
addq $104,%rax
jnc .L1652
call rt_abort
.L1652:
movq (%rax),%rax
movq %rax,%r14
movabsq $0,%rcx
cmpq $0,%rax
jne .L1653
call rt_abort
jmp .L1654
.L1653:
.L1654:
movq %rbx,%rax
addq $112,%rax
jnc .L1655
call rt_abort
.L1655:
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
jz .L1656
movabsq $80,%rcx
movq %rbx,%rax
addq $80,%rax
jnc .L1658
call rt_abort
.L1658:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq %rax,%rdi
movabsq $0,%rsi
movq %r13,%rax
call *%rax
jmp .L1657
.L1656:
.L1657:
movabsq $120,%rcx
movq %rbx,%rax
addq $120,%rax
jnc .L1659
call rt_abort
.L1659:
movq (%rax),%rax
movq %rax,-40(%rbp)
movq %rbx,%rdi
call rt_free
movq -40(%rbp),%rax
movq %rax,%rbx
jmp .L1650
.L1651:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F1642-8(%rbp),%rbx
movq -.F1642-16(%rbp),%r12
movq -.F1642-24(%rbp),%r13
movq -.F1642-32(%rbp),%r14
movq -.F1642-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1642-8(%rbp),%rbx
movq -.F1642-16(%rbp),%r12
movq -.F1642-24(%rbp),%r13
movq -.F1642-32(%rbp),%r14
movq -.F1642-40(%rbp),%r15
leave
ret
.set .F1642,48
.type rt_reactor,@function
rt_reactor:
pushq %rbp
movq %rsp,%rbp
subq $.F1660,%rsp
subq $48,%rsp
movq %rbx,-.F1660-8(%rbp)
movq %r12,-.F1660-16(%rbp)
movq %r13,-.F1660-24(%rbp)
movq %r14,-.F1660-32(%rbp)
movq %r15,-.F1660-40(%rbp)
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
jnc .L1661
call rt_abort
.L1661:
movq %rax,-24(%rbp)
movq -8(%rbp),%rax
addq $40,%rax
jnc .L1662
call rt_abort
.L1662:
movq (%rax),%rax
movq %rax,-32(%rbp)
movq $16,%r14
movabsq $0,%rax
cmpq $0,%rax
jne .L1663
movq $12,%r14
jmp .L1664
.L1663:
.L1664:
.L1665:
movabsq $1,%rax
testq %rax,%rax
jz .L1666
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
jne .L1667
movq $0,%rbx
.L1669:
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
jae .L1670
movq %rbx,%rax
movq %r14,%rcx
mulq %rcx
jnc .L1671
call rt_abort
.L1671:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1672
call rt_abort
.L1672:
addq $8,%rax
jnc .L1673
call rt_abort
.L1673:
movq %rax,%r12
cmpq $12,%r14
jne .L1674
movabsq $12,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L1676
call rt_abort
.L1676:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L1677
call rt_abort
.L1677:
movq %rax,-56(%rbp)
addq $4,%rax
jnc .L1678
call rt_abort
.L1678:
movq %rax,%r12
jmp .L1675
.L1674:
.L1675:
movq %r12,%rax
movq (%rax),%rax
movq %rax,-64(%rbp)
movq %rax,-72(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1679
movq -8(%rbp),%rax
addq $48,%rax
jnc .L1681
call rt_abort
.L1681:
movq (%rax),%rax
movq %rax,-80(%rbp)
movabsq $0,%rdi
movq %rax,%rsi
movq -24(%rbp),%rdx
movabsq $8,%rcx
call rt_syscall
jmp .L1680
.L1679:
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_wake
.L1680:
movq %rbx,%rax
addq $1,%rax
jnc .L1682
call rt_abort
.L1682:
movq %rax,%rbx
jmp .L1669
.L1670:
jmp .L1668
.L1667:
.L1668:
movabsq $56,%rcx
movq -8(%rbp),%rax
addq $56,%rax
jnc .L1683
call rt_abort
.L1683:
movq %rax,-88(%rbp)
movq %rax,%rdi
movabsq $1,%rsi
call rt_atomic_fetch_add
jmp .L1665
.L1666:
movabsq $0,%rax
movq -.F1660-8(%rbp),%rbx
movq -.F1660-16(%rbp),%r12
movq -.F1660-24(%rbp),%r13
movq -.F1660-32(%rbp),%r14
movq -.F1660-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1660-8(%rbp),%rbx
movq -.F1660-16(%rbp),%r12
movq -.F1660-24(%rbp),%r13
movq -.F1660-32(%rbp),%r14
movq -.F1660-40(%rbp),%r15
leave
ret
.set .F1660,96
.type rt_wait_fd,@function
rt_wait_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1684,%rsp
subq $32,%rsp
movq %rbx,-.F1684-8(%rbp)
movq %r12,-.F1684-16(%rbp)
movq %r13,-.F1684-24(%rbp)
movq %r14,-.F1684-32(%rbp)
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
jne .L1422_i41
movabsq $0,%rax
jmp .Lret_i41
jmp .L1423_i41
.L1422_i41:
.L1423_i41:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i41
call rt_abort
.L1424_i41:
movq (%rax),%rax
jmp .Lret_i41
xorq %rax,%rax
jmp .Lret_i41
.Lret_i41:
movq %rax,%rbx
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L1685
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
jnc .L1687
call rt_abort
.L1687:
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L1688
call rt_abort
.L1688:
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
movq -.F1684-8(%rbp),%rbx
movq -.F1684-16(%rbp),%r12
movq -.F1684-24(%rbp),%r13
movq -.F1684-32(%rbp),%r14
leave
ret
jmp .L1686
.L1685:
.L1686:
movq %rbx,%rax
addq $72,%rax
jnc .L1689
call rt_abort
.L1689:
movq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1690
call rt_abort
.L1690:
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
jz .L1691
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1693
call rt_abort
.L1693:
movq %rax,-72(%rbp)
movq %rax,%rdi
movabsq $0,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $0,%rax
subq $125,%rax
movq -.F1684-8(%rbp),%rbx
movq -.F1684-16(%rbp),%r12
movq -.F1684-24(%rbp),%r13
movq -.F1684-32(%rbp),%r14
leave
ret
jmp .L1692
.L1691:
.L1692:
call rt_sched
movq %rax,-80(%rbp)
movabsq $40,%rcx
addq $40,%rax
jnc .L1694
call rt_abort
.L1694:
movq (%rax),%rax
movq %rax,%r14
movabsq $16,%rdi
call rt_alloc
movq %rax,%r12
movq %rax,-88(%rbp)
movq -16(%rbp),%rax
addq $1073741824,%rax
jnc .L1695
call rt_abort
.L1695:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
cmpq $0,%rax
jne .L1696
movq %r12,%rax
addq $4,%rax
jnc .L1698
call rt_abort
.L1698:
movq %rax,-96(%rbp)
movq %rbx,%rax
movq -96(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
jmp .L1697
.L1696:
movq %r12,%rax
addq $8,%rax
jnc .L1699
call rt_abort
.L1699:
movq %rax,-104(%rbp)
movq %rbx,%rax
movq -104(%rbp),%rcx
movq %rbx,(%rcx)
xorq %rbx,%rax
.L1697:
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
jne .L1700
movabsq $233,%rdi
movq %r14,%rsi
movabsq $3,%rdx
movq %r13,%rcx
movq %r12,%r8
call rt_syscall4
movq %rax,-112(%rbp)
jmp .L1701
.L1700:
.L1701:
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
jz .L1702
call rt_abort
jmp .L1703
.L1702:
.L1703:
movq %rbx,%rdi
call rt_suspend
movabsq $128,%rcx
movq %rbx,%rax
addq $128,%rax
jnc .L1704
call rt_abort
.L1704:
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
jz .L1705
movabsq $0,%rax
subq $125,%rax
movq -.F1684-8(%rbp),%rbx
movq -.F1684-16(%rbp),%r12
movq -.F1684-24(%rbp),%r13
movq -.F1684-32(%rbp),%r14
leave
ret
jmp .L1706
.L1705:
.L1706:
movabsq $0,%rax
movq -.F1684-8(%rbp),%rbx
movq -.F1684-16(%rbp),%r12
movq -.F1684-24(%rbp),%r13
movq -.F1684-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1684-8(%rbp),%rbx
movq -.F1684-16(%rbp),%r12
movq -.F1684-24(%rbp),%r13
movq -.F1684-32(%rbp),%r14
leave
ret
.set .F1684,128
.type f_host_sleep_ms,@function
f_host_sleep_ms:
pushq %rbp
movq %rsp,%rbp
subq $.F1707,%rsp
subq $48,%rsp
movq %rbx,-.F1707-8(%rbp)
movq %r12,-.F1707-16(%rbp)
movq %r13,-.F1707-24(%rbp)
movq %r14,-.F1707-32(%rbp)
movq %r15,-.F1707-40(%rbp)
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
jnc .L1708
call rt_abort
.L1708:
movq %rax,-24(%rbp)
movq -8(%rbp),%rdi
movabsq $1000,%rsi
call rt_div
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %r14,%rax
addq $24,%rax
jnc .L1709
call rt_abort
.L1709:
movq %rax,-32(%rbp)
movabsq $1000,%rcx
movq -8(%rbp),%rax
testq %rcx,%rcx
jnz .L1710
call rt_abort
.L1710:
xorq %rdx,%rdx
divq %rcx
movabsq $1000000,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L1711
call rt_abort
.L1711:
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
jne .L1422_i43
movabsq $0,%rax
jmp .Lret_i43
jmp .L1423_i43
.L1422_i43:
.L1423_i43:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i43
call rt_abort
.L1424_i43:
movq (%rax),%rax
jmp .Lret_i43
xorq %rax,%rax
jmp .Lret_i43
.Lret_i43:
movq %rax,-40(%rbp)
cmpq $0,%rax
jne .L1712
movq %r14,%rax
addq $16,%rax
jnc .L1714
call rt_abort
.L1714:
movq %rax,-48(%rbp)
movabsq $35,%rdi
movq %rax,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %r14,%rdi
call rt_free
movabsq $0,%rax
movq -.F1707-8(%rbp),%rbx
movq -.F1707-16(%rbp),%r12
movq -.F1707-24(%rbp),%r13
movq -.F1707-32(%rbp),%r14
movq -.F1707-40(%rbp),%r15
leave
ret
jmp .L1713
.L1712:
.L1713:
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
jz .L1715
call rt_abort
jmp .L1716
.L1715:
.L1716:
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
jz .L1717
call rt_abort
jmp .L1718
.L1717:
.L1718:
movabsq $8,%rdi
call rt_alloc
movq %rax,%r15
.L1719:
movabsq $0,%rdi
movq %rbx,%rsi
movq %r15,%rdx
movabsq $8,%rcx
call rt_syscall
movabsq $8,%rcx
cmpq $8,%rax
je .L1720
movq %rbx,%rdi
movabsq $1,%rsi
call rt_wait_fd
cmpq $0,%rax
je .L1721
jmp .L1720
jmp .L1722
.L1721:
.L1722:
jmp .L1719
.L1720:
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
movq -.F1707-8(%rbp),%rbx
movq -.F1707-16(%rbp),%r12
movq -.F1707-24(%rbp),%r13
movq -.F1707-32(%rbp),%r14
movq -.F1707-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1707-8(%rbp),%rbx
movq -.F1707-16(%rbp),%r12
movq -.F1707-24(%rbp),%r13
movq -.F1707-32(%rbp),%r14
movq -.F1707-40(%rbp),%r15
leave
ret
.set .F1707,48
.type f_host_now_ms,@function
f_host_now_ms:
pushq %rbp
movq %rsp,%rbp
subq $.F1723,%rsp
subq $16,%rsp
movq %rbx,-.F1723-8(%rbp)
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
jnc .L1724
call rt_abort
.L1724:
movq %rax,-16(%rbp)
movabsq $8,%rcx
movq %rbx,%rax
addq $8,%rax
jnc .L1725
call rt_abort
.L1725:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq %rax,%rdi
movabsq $1000000,%rsi
call rt_div
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L1726
call rt_abort
.L1726:
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F1723-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1723-8(%rbp),%rbx
leave
ret
.set .F1723,32
.type f_host_pipe,@function
f_host_pipe:
pushq %rbp
movq %rsp,%rbp
subq $.F1727,%rsp
subq $16,%rsp
movq %rbx,-.F1727-8(%rbp)
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
jz .L1728
call rt_abort
jmp .L1729
.L1728:
.L1729:
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
jb .Lopt50
call rt_push
jmp .Lopt51
.Lopt50:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt51:
movq -8(%rbp),%rdi
movabsq $4294967296,%rsi
call rt_div
movq -16(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt52
call rt_push
jmp .Lopt53
.Lopt52:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt53:
movq -16(%rbp),%rax
movq -.F1727-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1727-8(%rbp),%rbx
leave
ret
.set .F1727,32
.type f_host_read_fd,@function
f_host_read_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1730,%rsp
subq $48,%rsp
movq %rbx,-.F1730-8(%rbp)
movq %r12,-.F1730-16(%rbp)
movq %r13,-.F1730-24(%rbp)
movq %r14,-.F1730-32(%rbp)
movq %r15,-.F1730-40(%rbp)
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
jne .L1731
movq %r14,%rax
movq -.F1730-8(%rbp),%rbx
movq -.F1730-16(%rbp),%r12
movq -.F1730-24(%rbp),%r13
movq -.F1730-32(%rbp),%r14
movq -.F1730-40(%rbp),%r15
leave
ret
jmp .L1732
.L1731:
.L1732:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_alloc
movq %rax,%r13
.L1733:
movabsq $1,%rax
testq %rax,%rax
jz .L1734
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
jne .L1735
movq %r15,%rdi
movabsq $1,%rsi
call rt_wait_fd
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1737
jmp .L1734
jmp .L1738
.L1737:
.L1738:
jmp .L1736
.L1735:
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
jne .L1739
movq $0,%rbx
.L1741:
movq %r12,%rcx
cmpq %r12,%rbx
jae .L1742
movq %r13,%rax
addq %rbx,%rax
jnc .L1743
call rt_abort
.L1743:
movzbq (%rax),%rax
movq %r14,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt54
call rt_pushb
jmp .Lopt55
.Lopt54:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt55:
movq %rbx,%rax
addq $1,%rax
jnc .L1744
call rt_abort
.L1744:
movq %rax,%rbx
jmp .L1741
.L1742:
jmp .L1740
.L1739:
.L1740:
jmp .L1734
.L1736:
jmp .L1733
.L1734:
movq %r13,%rdi
call rt_free
movq %r14,%rax
movq -.F1730-8(%rbp),%rbx
movq -.F1730-16(%rbp),%r12
movq -.F1730-24(%rbp),%r13
movq -.F1730-32(%rbp),%r14
movq -.F1730-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1730-8(%rbp),%rbx
movq -.F1730-16(%rbp),%r12
movq -.F1730-24(%rbp),%r13
movq -.F1730-32(%rbp),%r14
movq -.F1730-40(%rbp),%r15
leave
ret
.set .F1730,48
.type f_host_write_fd,@function
f_host_write_fd:
pushq %rbp
movq %rsp,%rbp
subq $.F1745,%rsp
subq $48,%rsp
movq %rbx,-.F1745-8(%rbp)
movq %r12,-.F1745-16(%rbp)
movq %r13,-.F1745-24(%rbp)
movq %r14,-.F1745-32(%rbp)
movq %r15,-.F1745-40(%rbp)
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
.L1746:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L1747
movq -24(%rbp),%rax
addq %rbx,%rax
jnc .L1748
call rt_abort
.L1748:
movq %rax,%r15
movq %r14,%rax
subq %rbx,%rax
jnc .L1749
call rt_abort
.L1749:
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
jne .L1750
movq %r13,%rdi
movabsq $4,%rsi
call rt_wait_fd
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1752
jmp .L1747
jmp .L1753
.L1752:
.L1753:
jmp .L1751
.L1750:
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
jz .L1754
jmp .L1747
jmp .L1755
.L1754:
.L1755:
movq %rbx,%rax
addq %r12,%rax
jnc .L1756
call rt_abort
.L1756:
movq %rax,%rbx
.L1751:
jmp .L1746
.L1747:
movq -24(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rax
movq -.F1745-8(%rbp),%rbx
movq -.F1745-16(%rbp),%r12
movq -.F1745-24(%rbp),%r13
movq -.F1745-32(%rbp),%r14
movq -.F1745-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1745-8(%rbp),%rbx
movq -.F1745-16(%rbp),%r12
movq -.F1745-24(%rbp),%r13
movq -.F1745-32(%rbp),%r14
movq -.F1745-40(%rbp),%r15
leave
ret
.set .F1745,48
.type f_host_close,@function
f_host_close:
pushq %rbp
movq %rsp,%rbp
subq $.F1757,%rsp
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
jz .L1758
movq -16(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
leave
ret
jmp .L1759
.L1758:
.L1759:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F1757,16
.type rt_offload_main,@function
rt_offload_main:
pushq %rbp
movq %rsp,%rbp
subq $.F1760,%rsp
subq $16,%rsp
movq %rbx,-.F1760-8(%rbp)
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
jnc .L1761
call rt_abort
.L1761:
movq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $16,%rcx
movq %rbx,%rax
addq $16,%rax
jnc .L1762
call rt_abort
.L1762:
movq (%rax),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq -16(%rbp),%rax
call *%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
addq $24,%rax
jnc .L1763
call rt_abort
.L1763:
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1764
call rt_abort
.L1764:
movq %rax,-48(%rbp)
movq %rax,%rdi
movabsq $1,%rax
xchgq %rax,(%rdi)
xorq %rax,%rax
movabsq $40,%rcx
movq %rbx,%rax
addq $40,%rax
jnc .L1765
call rt_abort
.L1765:
movq (%rax),%rax
movq %rax,%rdi
call rt_wake
movabsq $0,%rax
movq -.F1760-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1760-8(%rbp),%rbx
leave
ret
.set .F1760,48
.type rt_offload,@function
rt_offload:
pushq %rbp
movq %rsp,%rbp
subq $.F1766,%rsp
subq $32,%rsp
movq %rbx,-.F1766-8(%rbp)
movq %r12,-.F1766-16(%rbp)
movq %r13,-.F1766-24(%rbp)
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
jne .L1422_i50
movabsq $0,%rax
jmp .Lret_i50
jmp .L1423_i50
.L1422_i50:
.L1423_i50:
movq %r8,%rax
addq $16,%rax
jnc .L1424_i50
call rt_abort
.L1424_i50:
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
jnc .L1767
call rt_abort
.L1767:
movq %rax,-40(%rbp)
movq -16(%rbp),%rax
movq -40(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L1768
call rt_abort
.L1768:
movq %rax,-48(%rbp)
movq -24(%rbp),%rax
movq -48(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $40,%rax
jnc .L1769
call rt_abort
.L1769:
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
.L1770:
movabsq $32,%rcx
movq %rbx,%rax
addq $32,%rax
jnc .L1772
call rt_abort
.L1772:
movq %rax,%rdi
movq (%rdi),%rax
mfence
movq %rax,%r12
movabsq $0,%rcx
cmpq $0,%rax
jne .L1771
movq %r13,%rdi
call rt_suspend
jmp .L1770
.L1771:
movq -72(%rbp),%rax
movq %rax,%rdi
call rt_thread_join
movabsq $24,%rcx
movq %rbx,%rax
addq $24,%rax
jnc .L1773
call rt_abort
.L1773:
movq (%rax),%rax
movq %rax,-80(%rbp)
movq %rbx,%rdi
call rt_free
movq -80(%rbp),%rax
movq -.F1766-8(%rbp),%rbx
movq -.F1766-16(%rbp),%r12
movq -.F1766-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1766-8(%rbp),%rbx
movq -.F1766-16(%rbp),%r12
movq -.F1766-24(%rbp),%r13
leave
ret
.set .F1766,80
.type rt_bytes_from,@function
rt_bytes_from:
pushq %rbp
movq %rsp,%rbp
subq $.F1774,%rsp
subq $32,%rsp
movq %rbx,-.F1774-8(%rbp)
movq %r12,-.F1774-16(%rbp)
movq %r13,-.F1774-24(%rbp)
movq %r14,-.F1774-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r13
movq %rsi,%r14
call rt_new
movq %rax,%r12
movq $0,%rbx
.L1775:
cmpq %r14,%rbx
jae .L1776
movq %r13,%rax
addq %rbx,%rax
jnc .L1777
call rt_abort
.L1777:
movzbq (%rax),%rax
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt56
call rt_pushb
jmp .Lopt57
.Lopt56:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt57:
movq %rbx,%rax
addq $1,%rax
jnc .L1778
call rt_abort
.L1778:
movq %rax,%rbx
jmp .L1775
.L1776:
movq %r12,%rax
movq -.F1774-8(%rbp),%rbx
movq -.F1774-16(%rbp),%r12
movq -.F1774-24(%rbp),%r13
movq -.F1774-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1774-8(%rbp),%rbx
movq -.F1774-16(%rbp),%r12
movq -.F1774-24(%rbp),%r13
movq -.F1774-32(%rbp),%r14
leave
ret
.set .F1774,16
.type f_host_env,@function
f_host_env:
pushq %rbp
movq %rsp,%rbp
subq $.F1779,%rsp
subq $48,%rsp
movq %rbx,-.F1779-8(%rbp)
movq %r12,-.F1779-16(%rbp)
movq %r13,-.F1779-24(%rbp)
movq %r14,-.F1779-32(%rbp)
movq %r15,-.F1779-40(%rbp)
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
jnc .L1780
call rt_abort
.L1780:
movq (%rax),%rax
movq %rax,-24(%rbp)
.L1781:
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1782
movq -24(%rbp),%rax
movq (%rax),%rax
movq %rax,%r13
movq $0,%rbx
movq $1,-40(%rbp)
.L1783:
cmpq %r14,%rbx
jae .L1784
movq %r13,%rax
addq %rbx,%rax
jnc .L1785
call rt_abort
.L1785:
movzbq (%rax),%rax
movq %rax,%r15
movq -8(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt58
call rt_abort
.Lopt58:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r15
je .L1786
movq $0,-40(%rbp)
jmp .L1784
jmp .L1787
.L1786:
.L1787:
movq %rbx,%rax
addq $1,%rax
jnc .L1788
call rt_abort
.L1788:
movq %rax,%rbx
jmp .L1783
.L1784:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L1789
movq %r13,%rax
addq %r14,%rax
jnc .L1791
call rt_abort
.L1791:
movzbq (%rax),%rax
movq %rax,-48(%rbp)
cmpq $61,%rax
jne .L1792
movq $0,%r12
.L1794:
movq %r13,%rax
addq %r14,%rax
jnc .L1796
call rt_abort
.L1796:
movq %rax,-56(%rbp)
addq $1,%rax
jnc .L1797
call rt_abort
.L1797:
addq %r12,%rax
jnc .L1798
call rt_abort
.L1798:
movzbq (%rax),%rax
movq %rax,-64(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L1795
movq %r12,%rax
addq $1,%rax
jnc .L1799
call rt_abort
.L1799:
movq %rax,%r12
jmp .L1794
.L1795:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r13,%rax
addq %r14,%rax
jnc .L1800
call rt_abort
.L1800:
movq %rax,-72(%rbp)
movabsq $1,%rcx
addq $1,%rax
jnc .L1801
call rt_abort
.L1801:
movq %rax,-80(%rbp)
movq -80(%rbp),%rdi
movq %r12,%rsi
call rt_bytes_from
movq -.F1779-8(%rbp),%rbx
movq -.F1779-16(%rbp),%r12
movq -.F1779-24(%rbp),%r13
movq -.F1779-32(%rbp),%r14
movq -.F1779-40(%rbp),%r15
leave
ret
jmp .L1793
.L1792:
.L1793:
jmp .L1790
.L1789:
.L1790:
movq -24(%rbp),%rax
addq $8,%rax
jnc .L1802
call rt_abort
.L1802:
movq %rax,-24(%rbp)
jmp .L1781
.L1782:
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
call rt_new
movq -.F1779-8(%rbp),%rbx
movq -.F1779-16(%rbp),%r12
movq -.F1779-24(%rbp),%r13
movq -.F1779-32(%rbp),%r14
movq -.F1779-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1779-8(%rbp),%rbx
movq -.F1779-16(%rbp),%r12
movq -.F1779-24(%rbp),%r13
movq -.F1779-32(%rbp),%r14
movq -.F1779-40(%rbp),%r15
leave
ret
.set .F1779,80
.type f_host_exe_path,@function
f_host_exe_path:
pushq %rbp
movq %rsp,%rbp
subq $.F1803,%rsp
subq $32,%rsp
movq %rbx,-.F1803-8(%rbp)
movq %r12,-.F1803-16(%rbp)
movq %r13,-.F1803-24(%rbp)
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
jnc .L1804
call rt_abort
.L1804:
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
jne .L1805
movq %r13,%rdi
call rt_free
movq -24(%rbp),%rax
movq %r12,%rdi
movq %rax,%rsi
call rt_bytes_from
movq %rax,%r13
jmp .L1806
.L1805:
.L1806:
movq %r12,%rdi
call rt_free
movq %r13,%rax
movq -.F1803-8(%rbp),%rbx
movq -.F1803-16(%rbp),%r12
movq -.F1803-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1803-8(%rbp),%rbx
movq -.F1803-16(%rbp),%r12
movq -.F1803-24(%rbp),%r13
leave
ret
.set .F1803,32
.type f_host_exists,@function
f_host_exists:
pushq %rbp
movq %rsp,%rbp
subq $.F1807,%rsp
subq $16,%rsp
movq %rbx,-.F1807-8(%rbp)
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
jne .L1808
movabsq $0,%rax
movq -.F1807-8(%rbp),%rbx
leave
ret
jmp .L1809
.L1808:
.L1809:
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
movq -.F1807-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1807-8(%rbp),%rbx
leave
ret
.set .F1807,32
.type f_host_mkdir,@function
f_host_mkdir:
pushq %rbp
movq %rsp,%rbp
subq $.F1810,%rsp
subq $16,%rsp
movq %rbx,-.F1810-8(%rbp)
movq %r12,-.F1810-16(%rbp)
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
jne .L1811
movabsq $22,%rax
movq -.F1810-8(%rbp),%rbx
movq -.F1810-16(%rbp),%r12
leave
ret
jmp .L1812
.L1811:
.L1812:
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
jne .L1813
movabsq $0,%rax
movq -.F1810-8(%rbp),%rbx
movq -.F1810-16(%rbp),%r12
leave
ret
jmp .L1814
.L1813:
.L1814:
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
jz .L1815
movabsq $0,%rax
subq %r12,%rax
movq -.F1810-8(%rbp),%rbx
movq -.F1810-16(%rbp),%r12
leave
ret
jmp .L1816
.L1815:
.L1816:
movabsq $0,%rax
movq -.F1810-8(%rbp),%rbx
movq -.F1810-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1810-8(%rbp),%rbx
movq -.F1810-16(%rbp),%r12
leave
ret
.set .F1810,16
.type f_host_list_dir,@function
f_host_list_dir:
pushq %rbp
movq %rsp,%rbp
subq $.F1817,%rsp
subq $48,%rsp
movq %rbx,-.F1817-8(%rbp)
movq %r12,-.F1817-16(%rbp)
movq %r13,-.F1817-24(%rbp)
movq %r14,-.F1817-32(%rbp)
movq %r15,-.F1817-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F1817(%rbp),%rdi
movq $.F1817/8-1,%rcx
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
jne .L1818
movq -16(%rbp),%rax
movq -.F1817-8(%rbp),%rbx
movq -.F1817-16(%rbp),%r12
movq -.F1817-24(%rbp),%r13
movq -.F1817-32(%rbp),%r14
movq -.F1817-40(%rbp),%r15
leave
ret
jmp .L1819
.L1818:
.L1819:
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
jz .L1820
movq -16(%rbp),%rax
movq -.F1817-8(%rbp),%rbx
movq -.F1817-16(%rbp),%r12
movq -.F1817-24(%rbp),%r13
movq -.F1817-32(%rbp),%r14
movq -.F1817-40(%rbp),%r15
leave
ret
jmp .L1821
.L1820:
.L1821:
movabsq $8192,%rdi
call rt_alloc
movq %rax,-40(%rbp)
.L1822:
movabsq $1,%rax
testq %rax,%rax
jz .L1823
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
jnc .L1824
call rt_abort
.L1824:
testq %rax,%rax
jz .L1825
jmp .L1823
jmp .L1826
.L1825:
.L1826:
movq $0,%r14
.L1827:
movq -48(%rbp),%rcx
cmpq %rcx,%r14
jae .L1828
movq -40(%rbp),%rax
addq %r14,%rax
jnc .L1829
call rt_abort
.L1829:
movq %rax,%r12
movq %rax,-72(%rbp)
addq $16,%rax
jnc .L1830
call rt_abort
.L1830:
movzbq (%rax),%rax
movq %rax,-80(%rbp)
movq %r12,%rax
addq $17,%rax
jnc .L1831
call rt_abort
.L1831:
movzbq (%rax),%rax
movq %rax,-88(%rbp)
movabsq $256,%rcx
mulq %rcx
jnc .L1832
call rt_abort
.L1832:
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L1833
call rt_abort
.L1833:
movq %rax,-96(%rbp)
movq %r12,%rax
addq $18,%rax
jnc .L1834
call rt_abort
.L1834:
movzbq (%rax),%rax
movq %rax,-104(%rbp)
movq $0,%rbx
.L1835:
movq %r12,%rax
addq $19,%rax
jnc .L1837
call rt_abort
.L1837:
addq %rbx,%rax
jnc .L1838
call rt_abort
.L1838:
movzbq (%rax),%rax
cmpq $0,%rax
je .L1836
movq %rbx,%rax
addq $1,%rax
jnc .L1839
call rt_abort
.L1839:
movq %rax,%rbx
jmp .L1835
.L1836:
movq %r12,%rax
addq $19,%rax
jnc .L1840
call rt_abort
.L1840:
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
jnc .L1841
call rt_abort
.L1841:
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
jnc .L1842
call rt_abort
.L1842:
movq %rax,%rcx
movq -120(%rbp),%rax
andq %rcx,%rax
movq %rax,-152(%rbp)
cmpq $0,%rax
jne .L1843
movabsq $19,%rcx
movq %r12,%rax
addq $19,%rax
jnc .L1845
call rt_abort
.L1845:
movq %rax,-160(%rbp)
movq -160(%rbp),%rdi
movq %rbx,%rsi
call rt_bytes_from
movq %rax,%r15
movq -104(%rbp),%rax
cmpq $4,%rax
jne .L1846
movq %r15,%rdi
movabsq $47,%rsi
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
jmp .L1847
.L1846:
.L1847:
movq -16(%rbp),%rdi
movq %r15,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt61
call rt_push
jmp .Lopt62
.Lopt61:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt62:
jmp .L1844
.L1843:
.L1844:
movq %r14,%rax
movq -96(%rbp),%rcx
addq %rcx,%rax
jnc .L1848
call rt_abort
.L1848:
movq %rax,%r14
jmp .L1827
.L1828:
jmp .L1822
.L1823:
movabsq $3,%rdi
movq -32(%rbp),%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq -16(%rbp),%rax
movq -.F1817-8(%rbp),%rbx
movq -.F1817-16(%rbp),%r12
movq -.F1817-24(%rbp),%r13
movq -.F1817-32(%rbp),%r14
movq -.F1817-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1817-8(%rbp),%rbx
movq -.F1817-16(%rbp),%r12
movq -.F1817-24(%rbp),%r13
movq -.F1817-32(%rbp),%r14
movq -.F1817-40(%rbp),%r15
leave
ret
.set .F1817,160
.type rt_int_mask,@function
rt_int_mask:
pushq %rbp
movq %rsp,%rbp
subq $.F1849,%rsp
subq $32,%rsp
movq %rbx,-.F1849-8(%rbp)
movq %r12,-.F1849-16(%rbp)
movq %r13,-.F1849-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
cmpq $64,%r13
jne .L1850
movabsq $18446744073709551615,%rax
movq -.F1849-8(%rbp),%rbx
movq -.F1849-16(%rbp),%r12
movq -.F1849-24(%rbp),%r13
leave
ret
jmp .L1851
.L1850:
.L1851:
movq $1,%r12
movq $0,%rbx
.L1852:
cmpq %r13,%rbx
jae .L1853
movq %r12,%rax
addq %r12,%rax
movq %rax,%r12
movq %rbx,%rax
addq $1,%rax
jnc .L1854
call rt_abort
.L1854:
movq %rax,%rbx
jmp .L1852
.L1853:
movq %r12,%rax
subq $1,%rax
jnc .L1855
call rt_abort
.L1855:
movq -.F1849-8(%rbp),%rbx
movq -.F1849-16(%rbp),%r12
movq -.F1849-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F1849-8(%rbp),%rbx
movq -.F1849-16(%rbp),%r12
movq -.F1849-24(%rbp),%r13
leave
ret
.set .F1849,16
.type rt_int_neg,@function
rt_int_neg:
pushq %rbp
movq %rsp,%rbp
subq $.F1856,%rsp
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
.set .F1856,16
.type rt_int_fit,@function
rt_int_fit:
pushq %rbp
movq %rsp,%rbp
subq $.F1857,%rsp
subq $16,%rsp
movq %rbx,-.F1857-8(%rbp)
movq %r12,-.F1857-16(%rbp)
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
jne .L1858
movabsq $1,%rax
movq -.F1857-8(%rbp),%rbx
movq -.F1857-16(%rbp),%r12
leave
ret
jmp .L1859
.L1858:
.L1859:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_int_mask
movq %rax,%r12
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1860
movq %r12,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1862:
movq %rax,-32(%rbp)
addq $1,%rax
jnc .L1863
call rt_abort
.L1863:
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
jnc .L1864
call rt_abort
.L1864:
movq -.F1857-8(%rbp),%rbx
movq -.F1857-16(%rbp),%r12
leave
ret
jmp .L1861
.L1860:
.L1861:
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
jnc .L1865
call rt_abort
.L1865:
movq -.F1857-8(%rbp),%rbx
movq -.F1857-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1857-8(%rbp),%rbx
movq -.F1857-16(%rbp),%r12
leave
ret
.set .F1857,64
.type rt_int_truncate,@function
rt_int_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F1866,%rsp
subq $16,%rsp
movq %rbx,-.F1866-8(%rbp)
movq %r12,-.F1866-16(%rbp)
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
jne .L1867
movq -8(%rbp),%rax
movq -.F1866-8(%rbp),%rbx
movq -.F1866-16(%rbp),%r12
leave
ret
jmp .L1868
.L1867:
.L1868:
movq -16(%rbp),%rax
movq %rax,%rdi
call rt_int_mask
movq %rax,%rbx
movq -8(%rbp),%rax
andq %rbx,%rax
movq %rax,%r12
movq -24(%rbp),%rax
testq %rax,%rax
jz .L1869
movq %rbx,%rax
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1871:
movq %rax,-32(%rbp)
addq $1,%rax
jnc .L1872
call rt_abort
.L1872:
movq %rax,-40(%rbp)
movq %r12,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%r12
setb %al
movzbq %al,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
jne .L1873
movabsq $18446744073709551615,%rax
xorq %rbx,%rax
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L1875
call rt_abort
.L1875:
movq -.F1866-8(%rbp),%rbx
movq -.F1866-16(%rbp),%r12
leave
ret
jmp .L1874
.L1873:
.L1874:
jmp .L1870
.L1869:
.L1870:
movq %r12,%rax
movq -.F1866-8(%rbp),%rbx
movq -.F1866-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F1866-8(%rbp),%rbx
movq -.F1866-16(%rbp),%r12
leave
ret
.set .F1866,48
.type rt_int_abs,@function
rt_int_abs:
pushq %rbp
movq %rsp,%rbp
subq $.F1876,%rsp
subq $16,%rsp
movq %rbx,-.F1876-8(%rbp)
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
jz .L1877
movabsq $0,%rax
subq %rbx,%rax
movq -.F1876-8(%rbp),%rbx
leave
ret
jmp .L1878
.L1877:
.L1878:
movq %rbx,%rax
movq -.F1876-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1876-8(%rbp),%rbx
leave
ret
.set .F1876,16
.type rt_int,@function
rt_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1879,%rsp
subq $48,%rsp
movq %rbx,-.F1879-8(%rbp)
movq %r12,-.F1879-16(%rbp)
movq %r13,-.F1879-24(%rbp)
movq %r14,-.F1879-32(%rbp)
movq %r15,-.F1879-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r13
movq %rsi,%r12
movq %rdx,%rbx
movq %rcx,-32(%rbp)
leaq -.F1879(%rbp),%rdi
movq $.F1879/8-4,%rcx
xorl %eax,%eax
rep stosq
movq -32(%rbp),%rax
andq $255,%rax
movq %rax,-40(%rbp)
movq -32(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L1880:
movq %rax,-48(%rbp)
andq $1,%rax
movq %rax,-56(%rbp)
movq -32(%rbp),%rax
movq %rax,%rdx
andq $511,%rdx
shrq $9,%rax
.L1881:
movq %rax,-64(%rbp)
andq $1,%rax
movq %rax,-72(%rbp)
movq $0,%r14
movq $0,%r15
cmpq $43,%r13
jne .L1882
movq %r12,%rax
addq %rbx,%rax
movq %rax,%r14
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1884
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1886
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
jmp .L1887
.L1886:
movq %r14,%rax
cmpq %r12,%r14
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1887:
jmp .L1885
.L1884:
.L1885:
jmp .L1883
.L1882:
.L1883:
cmpq $45,%r13
jne .L1888
movq %r12,%rax
subq %rbx,%rax
movq %rax,%r14
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1890
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1892
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
jmp .L1893
.L1892:
movq %r12,%rax
cmpq %rbx,%r12
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1893:
jmp .L1891
.L1890:
.L1891:
jmp .L1889
.L1888:
.L1889:
cmpq $42,%r13
jne .L1894
movq %r12,%rax
movq %rbx,%rcx
imulq %rcx,%rax
movq %rax,%r14
movabsq $64,%rcx
movq -40(%rbp),%rax
cmpq $64,%rax
jne .L1896
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
je .L1898
movq -96(%rbp),%rax
movq -112(%rbp),%rdi
movq %rax,%rsi
call rt_div
movq -104(%rbp),%rcx
cmpq %rcx,%rax
je .L1900
movq $1,%r15
jmp .L1901
.L1900:
.L1901:
jmp .L1899
.L1898:
.L1899:
movq %r15,%rax
cmpq $0,%r15
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -56(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L1902
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
jz .L1904
movq -112(%rbp),%rcx
movabsq $9223372036854775808,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r15
jmp .L1905
.L1904:
movq -112(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%r15
.L1905:
jmp .L1903
.L1902:
.L1903:
jmp .L1897
.L1896:
.L1897:
jmp .L1895
.L1894:
.L1895:
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
jnc .L1906
call rt_abort
.L1906:
testq %rax,%rax
jz .L1907
movabsq $0,%rcx
cmpq $0,%rbx
jne .L1909
call rt_abort
jmp .L1910
.L1909:
.L1910:
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1911
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
jnc .L1913
call rt_abort
.L1913:
movq %rax,%rcx
movq -152(%rbp),%rax
subq %rcx,%rax
jnc .L1914
call rt_abort
.L1914:
movq %rax,-160(%rbp)
movabsq $47,%rcx
cmpq $47,%r13
jne .L1915
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
jz .L1917
movq -144(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%r14
jmp .L1918
.L1917:
movq -144(%rbp),%rax
movq %rax,%r14
.L1918:
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
jz .L1919
movq $1,%r15
jmp .L1920
.L1919:
.L1920:
jmp .L1916
.L1915:
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
jz .L1921
movq -160(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq %rax,%r14
jmp .L1922
.L1921:
movq -160(%rbp),%rax
movq %rax,%r14
.L1922:
.L1916:
jmp .L1912
.L1911:
movq %r12,%rdi
movq %rbx,%rsi
call rt_div
movq %rax,-208(%rbp)
cmpq $47,%r13
jne .L1923
movq -208(%rbp),%rax
movq %rax,%r14
jmp .L1924
.L1923:
movq -208(%rbp),%rax
movq %rbx,%rcx
mulq %rcx
jnc .L1925
call rt_abort
.L1925:
movq %rax,%rcx
movq %r12,%rax
subq %rcx,%rax
jnc .L1926
call rt_abort
.L1926:
movq %rax,%r14
.L1924:
.L1912:
jmp .L1908
.L1907:
.L1908:
cmpq $38,%r13
jne .L1927
movq %r12,%rax
andq %rbx,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1928
.L1927:
.L1928:
cmpq $94,%r13
jne .L1929
movq %r12,%rax
xorq %rbx,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1930
.L1929:
.L1930:
cmpq $124,%r13
jne .L1931
movabsq $18446744073709551615,%rax
xorq %rbx,%rax
movq %rax,%rcx
movq %r12,%rax
andq %rcx,%rax
addq %rbx,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1932
.L1931:
.L1932:
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
jnc .L1933
call rt_abort
.L1933:
testq %rax,%rax
jz .L1934
movq %rbx,%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rbx
setb %al
movzbq %al,%rax
movq %rax,-224(%rbp)
cmpq $0,%rax
jne .L1936
movabsq $0,%rcx
movq -72(%rbp),%rax
cmpq $0,%rax
jne .L1938
call rt_abort
jmp .L1939
.L1938:
.L1939:
movabsq $0,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1937
.L1936:
.L1937:
movq $1,-232(%rbp)
movq $0,-240(%rbp)
.L1940:
movq -240(%rbp),%rax
cmpq %rbx,%rax
jae .L1941
movq -232(%rbp),%rax
addq %rax,%rax
movq %rax,-232(%rbp)
movq -240(%rbp),%rax
addq $1,%rax
jnc .L1942
call rt_abort
.L1942:
movq %rax,-240(%rbp)
jmp .L1940
.L1941:
movabsq $271,%rcx
cmpq $271,%r13
jne .L1943
movq %r12,%rax
movq -232(%rbp),%rcx
imulq %rcx,%rax
movq %rax,-248(%rbp)
movq -56(%rbp),%rax
movq -248(%rbp),%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1944
.L1943:
.L1944:
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
jz .L1945
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
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1946
.L1945:
.L1946:
movq -232(%rbp),%rax
movq %r12,%rdi
movq %rax,%rsi
call rt_div
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1935
.L1934:
.L1935:
cmpq $258,%r13
jne .L1947
movq %r12,%rax
cmpq %rbx,%r12
sete %al
movzbq %al,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1948
.L1947:
.L1948:
cmpq $259,%r13
jne .L1949
movq %r12,%rax
cmpq %rbx,%r12
setne %al
movzbq %al,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1950
.L1949:
.L1950:
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
jnc .L1951
call rt_abort
.L1951:
movq %rax,-288(%rbp)
movq %r13,%rax
cmpq $269,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -288(%rbp),%rax
addq %rcx,%rax
jnc .L1952
call rt_abort
.L1952:
movq %rax,-296(%rbp)
movq %r13,%rax
cmpq $270,%r13
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -296(%rbp),%rax
addq %rcx,%rax
jnc .L1953
call rt_abort
.L1953:
testq %rax,%rax
jz .L1954
movq %r12,-304(%rbp)
movq %rbx,-312(%rbp)
movq -56(%rbp),%rax
testq %rax,%rax
jz .L1956
movabsq $9223372036854775808,%rcx
movq %r12,%rax
xorq %rcx,%rax
movq %rax,-304(%rbp)
movabsq $9223372036854775808,%rcx
movq %rbx,%rax
xorq %rcx,%rax
movq %rax,-312(%rbp)
jmp .L1957
.L1956:
.L1957:
cmpq $60,%r13
jne .L1958
movq -304(%rbp),%rax
movq -312(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1959
.L1958:
.L1959:
cmpq $62,%r13
jne .L1960
movq -312(%rbp),%rax
movq -304(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1961
.L1960:
.L1961:
cmpq $269,%r13
jne .L1962
movq -312(%rbp),%rax
movq -304(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-320(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1963
.L1962:
.L1963:
movq -304(%rbp),%rax
movq -312(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-328(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1955
.L1954:
.L1955:
movabsq $267,%rcx
cmpq $267,%r13
jne .L1964
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
jz .L1966
call rt_abort
jmp .L1967
.L1966:
.L1967:
movq $1,-336(%rbp)
movq $0,-344(%rbp)
.L1968:
movq -344(%rbp),%rax
cmpq %rbx,%rax
jae .L1969
movq -32(%rbp),%rax
movabsq $42,%rdi
movq -336(%rbp),%rsi
movq %r12,%rdx
movq %rax,%rcx
call rt_int
movq %rax,-336(%rbp)
movq -344(%rbp),%rax
addq $1,%rax
jnc .L1970
call rt_abort
.L1970:
movq %rax,-344(%rbp)
jmp .L1968
.L1969:
movq -336(%rbp),%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1965
.L1964:
.L1965:
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
jz .L1971
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
jmp .L1972
.L1971:
.L1972:
testq %r15,%r15
jz .L1973
movabsq $0,%rcx
movq -72(%rbp),%rax
cmpq $0,%rax
jne .L1975
call rt_abort
jmp .L1976
.L1975:
.L1976:
movq -56(%rbp),%rax
movq %r14,%rdi
movq -40(%rbp),%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
jmp .L1974
.L1973:
.L1974:
movq %r14,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F1879-8(%rbp),%rbx
movq -.F1879-16(%rbp),%r12
movq -.F1879-24(%rbp),%r13
movq -.F1879-32(%rbp),%r14
movq -.F1879-40(%rbp),%r15
leave
ret
.set .F1879,368
.type rt_int_cast,@function
rt_int_cast:
pushq %rbp
movq %rsp,%rbp
subq $.F1977,%rsp
subq $32,%rsp
movq %rbx,-.F1977-8(%rbp)
movq %r12,-.F1977-16(%rbp)
movq %r13,-.F1977-24(%rbp)
movq %r14,-.F1977-32(%rbp)
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
.L1978:
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
.L1979:
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
jne .L1980
movq -64(%rbp),%rax
testq %rax,%rax
jz .L1982
movq $0,%r13
jmp .L1983
.L1982:
movabsq $64,%rcx
cmpq $64,%r12
jae .L1984
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
jnc .L1986
call rt_abort
.L1986:
movq %rax,%r13
jmp .L1985
.L1984:
.L1985:
.L1983:
jmp .L1981
.L1980:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L1987
movabsq $64,%rcx
cmpq $64,%r12
jae .L1989
movq %rbx,%rdi
movq %r12,%rsi
movabsq $1,%rdx
call rt_int_fit
movq %rax,%r13
jmp .L1990
.L1989:
.L1990:
jmp .L1988
.L1987:
movq %r12,%rdi
call rt_int_mask
movq %rax,-80(%rbp)
movq %rax,%rdx
andq $1,%rdx
shrq $1,%rax
.L1991:
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
jnc .L1992
call rt_abort
.L1992:
movq %rax,%r13
.L1988:
.L1981:
cmpq $0,%r13
jne .L1993
movq %r14,%rax
movq %rax,%rdx
andq $511,%rdx
shrq $9,%rax
.L1995:
movq %rax,-104(%rbp)
movabsq $1,%rcx
andq $1,%rax
testq %rax,%rax
jz .L1996
movq -56(%rbp),%rax
movq %rbx,%rdi
movq %r12,%rsi
movq %rax,%rdx
call rt_int_truncate
movq -.F1977-8(%rbp),%rbx
movq -.F1977-16(%rbp),%r12
movq -.F1977-24(%rbp),%r13
movq -.F1977-32(%rbp),%r14
leave
ret
jmp .L1997
.L1996:
.L1997:
call rt_abort
jmp .L1994
.L1993:
.L1994:
movq %rbx,%rax
movq -.F1977-8(%rbp),%rbx
movq -.F1977-16(%rbp),%r12
movq -.F1977-24(%rbp),%r13
movq -.F1977-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F1977-8(%rbp),%rbx
movq -.F1977-16(%rbp),%r12
movq -.F1977-24(%rbp),%r13
movq -.F1977-32(%rbp),%r14
leave
ret
.set .F1977,112
.type rt_print_int,@function
rt_print_int:
pushq %rbp
movq %rsp,%rbp
subq $.F1998,%rsp
subq $16,%rsp
movq %rbx,-.F1998-8(%rbp)
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
.L1999:
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
jz .L2000
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
je .L2002
call rt_abort
jmp .L2003
.L2002:
.L2003:
movq %rbx,%rcx
movabsq $0,%rax
subq %rbx,%rax
movq %rax,-72(%rbp)
movq -16(%rbp),%rax
movq -72(%rbp),%rdi
movq %rax,%rsi
call rt_print_number
movq -.F1998-8(%rbp),%rbx
leave
ret
jmp .L2001
.L2000:
.L2001:
movq -16(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_print_number
movq -.F1998-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F1998-8(%rbp),%rbx
leave
ret
.set .F1998,80
.type rt_print_bool,@function
rt_print_bool:
pushq %rbp
movq %rsp,%rbp
subq $.F2004,%rsp
subq $16,%rsp
movq %rbx,-.F2004-8(%rbp)
movq %r12,-.F2004-16(%rbp)
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
jnc .L2005
call rt_abort
.L2005:
movq %rax,%r12
movabsq $8,%rdi
call rt_alloc
movq %rax,%rbx
movq -8(%rbp),%rax
testq %rax,%rax
jz .L2006
movq %rbx,%rcx
movabsq $116,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L2008
call rt_abort
.L2008:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $114,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L2009
call rt_abort
.L2009:
movq %rax,-32(%rbp)
movq %rax,%rcx
movabsq $117,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L2010
call rt_abort
.L2010:
movq %rax,-40(%rbp)
movq %rax,%rcx
movabsq $101,%rax
movb %al,(%rcx)
xorq %rax,%rax
jmp .L2007
.L2006:
movq %rbx,%rcx
movabsq $102,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L2011
call rt_abort
.L2011:
movq %rax,-48(%rbp)
movq %rax,%rcx
movabsq $97,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $2,%rax
jnc .L2012
call rt_abort
.L2012:
movq %rax,-56(%rbp)
movq %rax,%rcx
movabsq $108,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $3,%rax
jnc .L2013
call rt_abort
.L2013:
movq %rax,-64(%rbp)
movq %rax,%rcx
movabsq $115,%rax
movb %al,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $4,%rax
jnc .L2014
call rt_abort
.L2014:
movq %rax,-72(%rbp)
movq %rax,%rcx
movabsq $101,%rax
movb %al,(%rcx)
xorq %rax,%rax
.L2007:
movq %r12,-80(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2015
movq %rbx,%rax
addq %r12,%rax
jnc .L2017
call rt_abort
.L2017:
movq %rax,-88(%rbp)
movq %rax,%rcx
movabsq $10,%rax
movb %al,(%rcx)
xorq %rax,%rax
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L2018
call rt_abort
.L2018:
movq %rax,-80(%rbp)
jmp .L2016
.L2015:
.L2016:
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
je .L2019
call rt_abort
jmp .L2020
.L2019:
.L2020:
movabsq $0,%rax
movq -.F2004-8(%rbp),%rbx
movq -.F2004-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2004-8(%rbp),%rbx
movq -.F2004-16(%rbp),%r12
leave
ret
.set .F2004,96
.type rt_sockaddr,@function
rt_sockaddr:
pushq %rbp
movq %rsp,%rbp
subq $.F2021,%rsp
subq $16,%rsp
movq %rbx,-.F2021-8(%rbp)
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
.L2022:
movabsq $256,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L2023
call rt_abort
.L2023:
movq %rax,-24(%rbp)
movq -16(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2024
call rt_abort
.L2024:
movq %rax,-32(%rbp)
movabsq $65536,%rcx
mulq %rcx
jnc .L2025
call rt_abort
.L2025:
movq %rax,%rcx
movabsq $2,%rax
addq %rcx,%rax
jnc .L2026
call rt_abort
.L2026:
movq %rax,-40(%rbp)
movabsq $4294967296,%rcx
movq -8(%rbp),%rax
mulq %rcx
jnc .L2027
call rt_abort
.L2027:
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L2028
call rt_abort
.L2028:
movq %rbx,%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq %rbx,%rax
addq $8,%rax
jnc .L2029
call rt_abort
.L2029:
movq %rax,-48(%rbp)
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
movq -.F2021-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2021-8(%rbp),%rbx
leave
ret
.set .F2021,48
.type rt_tcp_socket,@function
rt_tcp_socket:
pushq %rbp
movq %rsp,%rbp
subq $.F2030,%rsp
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
jz .L2031
call rt_abort
jmp .L2032
.L2031:
.L2032:
movq -8(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2030,16
.type f_host_tcp_listen,@function
f_host_tcp_listen:
pushq %rbp
movq %rsp,%rbp
subq $.F2033,%rsp
subq $16,%rsp
movq %rbx,-.F2033-8(%rbp)
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
jz .L2034
call rt_abort
jmp .L2035
.L2034:
.L2035:
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
jz .L2036
call rt_abort
jmp .L2037
.L2036:
.L2037:
movq %rbx,%rax
movq -.F2033-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2033-8(%rbp),%rbx
leave
ret
.set .F2033,32
.type f_host_tcp_port,@function
f_host_tcp_port:
pushq %rbp
movq %rsp,%rbp
subq $.F2038,%rsp
subq $16,%rsp
movq %rbx,-.F2038-8(%rbp)
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
jnc .L2039
call rt_abort
.L2039:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $16,%rax
movq $16,(%rcx)
xorq $16,%rax
movq %rbx,%rax
addq $16,%rax
jnc .L2040
call rt_abort
.L2040:
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
jz .L2041
call rt_abort
jmp .L2042
.L2041:
.L2042:
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
.L2043:
movq %rdx,-48(%rbp)
movq %rbx,%rdi
call rt_free
movq -48(%rbp),%rax
movq %rax,%rdx
andq $255,%rdx
shrq $8,%rax
.L2044:
movabsq $256,%rcx
movq %rdx,%rax
mulq %rcx
jnc .L2045
call rt_abort
.L2045:
movq %rax,-56(%rbp)
movq -48(%rbp),%rdi
movabsq $256,%rsi
call rt_div
movq %rax,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L2046
call rt_abort
.L2046:
movq -.F2038-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2038-8(%rbp),%rbx
leave
ret
.set .F2038,64
.type f_host_tcp_accept,@function
f_host_tcp_accept:
pushq %rbp
movq %rsp,%rbp
subq $.F2047,%rsp
subq $32,%rsp
movq %rbx,-.F2047-8(%rbp)
movq %r12,-.F2047-16(%rbp)
movq %r13,-.F2047-24(%rbp)
movq %r14,-.F2047-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq $0,-16(%rbp)
.L2048:
movabsq $1,%rax
testq %rax,%rax
jz .L2049
movq %r12,%rdi
call rt_accept4
movq %rax,%rbx
movq %rax,%r13
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
cmpq %rcx,%r13
jne .L2050
movq %r12,%rdi
movabsq $1,%rsi
call rt_wait_fd
movabsq $0,%rcx
cmpq $0,%rax
je .L2052
movabsq $0,%rax
subq $125,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
movq -.F2047-32(%rbp),%r14
leave
ret
jmp .L2053
.L2052:
.L2053:
jmp .L2051
.L2050:
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
jz .L2054
call rt_abort
jmp .L2055
.L2054:
.L2055:
movq %rbx,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
movq -.F2047-32(%rbp),%r14
leave
ret
.L2051:
jmp .L2048
.L2049:
movabsq $0,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
movq -.F2047-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2047-8(%rbp),%rbx
movq -.F2047-16(%rbp),%r12
movq -.F2047-24(%rbp),%r13
movq -.F2047-32(%rbp),%r14
leave
ret
.set .F2047,16
.type rt_ipv4,@function
rt_ipv4:
pushq %rbp
movq %rsp,%rbp
subq $.F2056,%rsp
subq $48,%rsp
movq %rbx,-.F2056-8(%rbp)
movq %r12,-.F2056-16(%rbp)
movq %r13,-.F2056-24(%rbp)
movq %r14,-.F2056-32(%rbp)
movq %r15,-.F2056-40(%rbp)
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
.L2057:
movq -16(%rbp),%rcx
cmpq %rcx,%r12
jae .L2058
movq -8(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt63
call rt_abort
.Lopt63:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r15
movq %rax,-24(%rbp)
cmpq $46,%rax
jne .L2059
movq %rbx,%rax
movq %r13,%rcx
mulq %rcx
jnc .L2061
call rt_abort
.L2061:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2062
call rt_abort
.L2062:
movq %rax,%r14
movabsq $256,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2063
call rt_abort
.L2063:
movq %rax,%r13
movq $0,%rbx
jmp .L2060
.L2059:
movabsq $10,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2064
call rt_abort
.L2064:
addq %r15,%rax
jnc .L2065
call rt_abort
.L2065:
movq %rax,-32(%rbp)
subq $48,%rax
jnc .L2066
call rt_abort
.L2066:
movq %rax,%rbx
.L2060:
movq %r12,%rax
addq $1,%rax
jnc .L2067
call rt_abort
.L2067:
movq %rax,%r12
jmp .L2057
.L2058:
movq %rbx,%rax
movq %r13,%rcx
mulq %rcx
jnc .L2068
call rt_abort
.L2068:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2069
call rt_abort
.L2069:
movq %rax,%r14
movq -8(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %r14,%rax
movq -.F2056-8(%rbp),%rbx
movq -.F2056-16(%rbp),%r12
movq -.F2056-24(%rbp),%r13
movq -.F2056-32(%rbp),%r14
movq -.F2056-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2056-8(%rbp),%rbx
movq -.F2056-16(%rbp),%r12
movq -.F2056-24(%rbp),%r13
movq -.F2056-32(%rbp),%r14
movq -.F2056-40(%rbp),%r15
leave
ret
.set .F2056,32
.type f_host_tcp_connect,@function
f_host_tcp_connect:
pushq %rbp
movq %rsp,%rbp
subq $.F2070,%rsp
subq $48,%rsp
movq %rbx,-.F2070-8(%rbp)
movq %r12,-.F2070-16(%rbp)
movq %r13,-.F2070-24(%rbp)
movq %r14,-.F2070-32(%rbp)
movq %r15,-.F2070-40(%rbp)
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
.L2071:
movabsq $1,%rax
testq %rax,%rax
jz .L2072
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
jnc .L2073
call rt_abort
.L2073:
testq %rax,%rax
jz .L2074
movq %r13,%rdi
call rt_free
movq %r12,%rax
movq -.F2070-8(%rbp),%rbx
movq -.F2070-16(%rbp),%r12
movq -.F2070-24(%rbp),%r13
movq -.F2070-32(%rbp),%r14
movq -.F2070-40(%rbp),%r15
leave
ret
jmp .L2075
.L2074:
.L2075:
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
jnc .L2076
call rt_abort
.L2076:
testq %rax,%rax
jz .L2077
movq %r12,%rdi
movabsq $4,%rsi
call rt_wait_fd
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L2079
movq %r13,%rdi
call rt_free
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movabsq $0,%rax
subq $125,%rax
movq -.F2070-8(%rbp),%rbx
movq -.F2070-16(%rbp),%r12
movq -.F2070-24(%rbp),%r13
movq -.F2070-32(%rbp),%r14
movq -.F2070-40(%rbp),%r15
leave
ret
jmp .L2080
.L2079:
.L2080:
jmp .L2078
.L2077:
movabsq $0,%rax
subq $11,%rax
movq %rax,%rcx
cmpq %rcx,%rbx
jne .L2081
call rt_yield
jmp .L2082
.L2081:
movq %r13,%rdi
call rt_free
movabsq $3,%rdi
movq %r12,%rsi
movabsq $0,%rdx
movabsq $0,%rcx
call rt_syscall
movq %rbx,%rax
movq -.F2070-8(%rbp),%rbx
movq -.F2070-16(%rbp),%r12
movq -.F2070-24(%rbp),%r13
movq -.F2070-32(%rbp),%r14
movq -.F2070-40(%rbp),%r15
leave
ret
.L2082:
.L2078:
jmp .L2071
.L2072:
movabsq $0,%rax
movq -.F2070-8(%rbp),%rbx
movq -.F2070-16(%rbp),%r12
movq -.F2070-24(%rbp),%r13
movq -.F2070-32(%rbp),%r14
movq -.F2070-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2070-8(%rbp),%rbx
movq -.F2070-16(%rbp),%r12
movq -.F2070-24(%rbp),%r13
movq -.F2070-32(%rbp),%r14
movq -.F2070-40(%rbp),%r15
leave
ret
.set .F2070,48
.type f_host_open,@function
f_host_open:
pushq %rbp
movq %rsp,%rbp
subq $.F2083,%rsp
subq $16,%rsp
movq %rbx,-.F2083-8(%rbp)
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
jne .L2084
movabsq $0,%rax
subq $22,%rax
movq -.F2083-8(%rbp),%rbx
leave
ret
jmp .L2085
.L2084:
.L2085:
movq $524288,-24(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2086
movq $524865,-24(%rbp)
jmp .L2087
.L2086:
.L2087:
movabsq $2,%rdi
movq %rbx,%rsi
movq -24(%rbp),%rdx
movabsq $438,%rcx
call rt_syscall
movq %rax,-32(%rbp)
movq %rbx,%rdi
call rt_free
movq -32(%rbp),%rax
movq -.F2083-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2083-8(%rbp),%rbx
leave
ret
.set .F2083,32
.type rt_print_raw,@function
rt_print_raw:
pushq %rbp
movq %rsp,%rbp
subq $.F2088,%rsp
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
je .L2089
call rt_abort
jmp .L2090
.L2089:
.L2090:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2088,32
.type rt_fmt_raw,@function
rt_fmt_raw:
pushq %rbp
movq %rsp,%rbp
subq $.F2091,%rsp
subq $32,%rsp
movq %rbx,-.F2091-8(%rbp)
movq %r12,-.F2091-16(%rbp)
movq %r13,-.F2091-24(%rbp)
movq %r14,-.F2091-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%r12
movq %rsi,%r13
movq %rdx,%r14
movq $0,-32(%rbp)
movq $0,%rbx
.L2092:
cmpq %r14,%rbx
jae .L2093
movq %r13,%rax
addq %rbx,%rax
jnc .L2094
call rt_abort
.L2094:
movzbq (%rax),%rax
movq %r12,%rdi
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
movq %rbx,%rax
addq $1,%rax
jnc .L2095
call rt_abort
.L2095:
movq %rax,%rbx
jmp .L2092
.L2093:
movabsq $0,%rax
movq -.F2091-8(%rbp),%rbx
movq -.F2091-16(%rbp),%r12
movq -.F2091-24(%rbp),%r13
movq -.F2091-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2091-8(%rbp),%rbx
movq -.F2091-16(%rbp),%r12
movq -.F2091-24(%rbp),%r13
movq -.F2091-32(%rbp),%r14
leave
ret
.set .F2091,32
.type rt_fmt_num,@function
rt_fmt_num:
pushq %rbp
movq %rsp,%rbp
subq $.F2096,%rsp
subq $48,%rsp
movq %rbx,-.F2096-8(%rbp)
movq %r12,-.F2096-16(%rbp)
movq %r13,-.F2096-24(%rbp)
movq %r14,-.F2096-32(%rbp)
movq %r15,-.F2096-40(%rbp)
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
.L2097:
movabsq $1,%rax
testq %rax,%rax
jz .L2098
movq %rbx,%rax
subq $1,%rax
jnc .L2099
call rt_abort
.L2099:
movq %rax,%rbx
movq %r15,%rax
addq %rbx,%rax
jnc .L2100
call rt_abort
.L2100:
movq %rax,%r13
movabsq $10,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L2101
call rt_abort
.L2101:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L2102
call rt_abort
.L2102:
movq %r13,%rcx
movb %al,(%rcx)
xorq %rax,%rax
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
movq %rax,%r14
cmpq $0,%rax
jne .L2103
jmp .L2098
jmp .L2104
.L2103:
.L2104:
jmp .L2097
.L2098:
movq %r15,%rax
movq %rbx,%rcx
addq %rbx,%rax
jnc .L2105
call rt_abort
.L2105:
movq %rax,-24(%rbp)
movabsq $24,%rax
subq %rbx,%rax
jnc .L2106
call rt_abort
.L2106:
movq -8(%rbp),%rdi
movq -24(%rbp),%rsi
movq %rax,%rdx
call rt_fmt_raw
movq %r15,%rdi
call rt_free
movabsq $0,%rax
movq -.F2096-8(%rbp),%rbx
movq -.F2096-16(%rbp),%r12
movq -.F2096-24(%rbp),%r13
movq -.F2096-32(%rbp),%r14
movq -.F2096-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2096-8(%rbp),%rbx
movq -.F2096-16(%rbp),%r12
movq -.F2096-24(%rbp),%r13
movq -.F2096-32(%rbp),%r14
movq -.F2096-40(%rbp),%r15
leave
ret
.set .F2096,32
.type rt_fmt_int,@function
rt_fmt_int:
pushq %rbp
movq %rsp,%rbp
subq $.F2107,%rsp
subq $16,%rsp
movq %rbx,-.F2107-8(%rbp)
movq %r12,-.F2107-16(%rbp)
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
.L2108:
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
jz .L2109
movq %rbx,%rdi
movabsq $45,%rsi
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
movq %r12,%rcx
movabsq $0,%rax
subq %r12,%rax
movq %rbx,%rdi
movq %rax,%rsi
call rt_fmt_num
movq -.F2107-8(%rbp),%rbx
movq -.F2107-16(%rbp),%r12
leave
ret
jmp .L2110
.L2109:
.L2110:
movq %rbx,%rdi
movq %r12,%rsi
call rt_fmt_num
movq -.F2107-8(%rbp),%rbx
movq -.F2107-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2107-8(%rbp),%rbx
movq -.F2107-16(%rbp),%r12
leave
ret
.set .F2107,48
.type rt_fmt_bool,@function
rt_fmt_bool:
pushq %rbp
movq %rsp,%rbp
subq $.F2111,%rsp
subq $16,%rsp
movq %rbx,-.F2111-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2112
movq %rbx,%rdi
movabsq $116,%rsi
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
movq %rbx,%rdi
movabsq $114,%rsi
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
movq %rbx,%rdi
movabsq $117,%rsi
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
movq %rbx,%rdi
movabsq $101,%rsi
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
jmp .L2113
.L2112:
movq %rbx,%rdi
movabsq $102,%rsi
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
movq %rbx,%rdi
movabsq $97,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt78
call rt_pushb
jmp .Lopt79
.Lopt78:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt79:
movq %rbx,%rdi
movabsq $108,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt80
call rt_pushb
jmp .Lopt81
.Lopt80:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt81:
movq %rbx,%rdi
movabsq $115,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt82
call rt_pushb
jmp .Lopt83
.Lopt82:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt83:
movq %rbx,%rdi
movabsq $101,%rsi
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
.L2113:
movabsq $0,%rax
movq -.F2111-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2111-8(%rbp),%rbx
leave
ret
.set .F2111,16
.type rt_fmt_seq,@function
rt_fmt_seq:
pushq %rbp
movq %rsp,%rbp
subq $.F2114,%rsp
subq $32,%rsp
movq %rbx,-.F2114-8(%rbp)
movq %r12,-.F2114-16(%rbp)
movq %r13,-.F2114-24(%rbp)
movq %r14,-.F2114-32(%rbp)
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
.L2115:
cmpq %r14,%rbx
jae .L2116
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt86
call rt_abort
.Lopt86:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt87
call rt_pushb
jmp .Lopt88
.Lopt87:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt88:
movq %rbx,%rax
addq $1,%rax
jnc .L2117
call rt_abort
.L2117:
movq %rax,%rbx
jmp .L2115
.L2116:
movabsq $0,%rax
movq -.F2114-8(%rbp),%rbx
movq -.F2114-16(%rbp),%r12
movq -.F2114-24(%rbp),%r13
movq -.F2114-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2114-8(%rbp),%rbx
movq -.F2114-16(%rbp),%r12
movq -.F2114-24(%rbp),%r13
movq -.F2114-32(%rbp),%r14
leave
ret
.set .F2114,16
.type rt_fmt_finish,@function
rt_fmt_finish:
pushq %rbp
movq %rsp,%rbp
subq $.F2118,%rsp
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
.set .F2118,16
.type rt_f64_pow2,@function
rt_f64_pow2:
pushq %rbp
movq %rsp,%rbp
subq $.F2119,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq -8(%rbp),%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120
call rt_abort
.L2120:
movq %rax,-16(%rbp)
movabsq $4503599627370496,%rcx
movq -16(%rbp),%rax
imulq %rcx,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2119,16
.type rt_f64_neg,@function
rt_f64_neg:
pushq %rbp
movq %rsp,%rbp
subq $.F2121,%rsp
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
.set .F2121,16
.type rt_f64_abs,@function
rt_f64_abs:
pushq %rbp
movq %rsp,%rbp
subq $.F2122,%rsp
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
.set .F2122,16
.type rt_f64_is_nan,@function
rt_f64_is_nan:
pushq %rbp
movq %rsp,%rbp
subq $.F2123,%rsp
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
.set .F2123,16
.type rt_f64_sqrt,@function
rt_f64_sqrt:
pushq %rbp
movq %rsp,%rbp
subq $.F2124,%rsp
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
.set .F2124,16
.type rt_f64_op,@function
rt_f64_op:
pushq %rbp
movq %rsp,%rbp
subq $.F2125,%rsp
subq $32,%rsp
movq %rbx,-.F2125-8(%rbp)
movq %r12,-.F2125-16(%rbp)
movq %r13,-.F2125-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%rbx
movq %rsi,%r12
movq %rdx,%r13
movq $0,-32(%rbp)
cmpq $43,%rbx
jne .L2126
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F2125-8(%rbp),%rbx
movq -.F2125-16(%rbp),%r12
movq -.F2125-24(%rbp),%r13
leave
ret
jmp .L2127
.L2126:
.L2127:
cmpq $45,%rbx
jne .L2128
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F2125-8(%rbp),%rbx
movq -.F2125-16(%rbp),%r12
movq -.F2125-24(%rbp),%r13
leave
ret
jmp .L2129
.L2128:
.L2129:
cmpq $42,%rbx
jne .L2130
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
mulsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F2125-8(%rbp),%rbx
movq -.F2125-16(%rbp),%r12
movq -.F2125-24(%rbp),%r13
leave
ret
jmp .L2131
.L2130:
.L2131:
movabsq $47,%rcx
cmpq $47,%rbx
jne .L2132
movq %r12,%rax
movq %r13,%rcx
movq %r12,%xmm0
movq %r13,%xmm1
divsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F2125-8(%rbp),%rbx
movq -.F2125-16(%rbp),%r12
movq -.F2125-24(%rbp),%r13
leave
ret
jmp .L2133
.L2132:
.L2133:
call rt_abort
movabsq $0,%rax
movq -.F2125-8(%rbp),%rbx
movq -.F2125-16(%rbp),%r12
movq -.F2125-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2125-8(%rbp),%rbx
movq -.F2125-16(%rbp),%r12
movq -.F2125-24(%rbp),%r13
leave
ret
.set .F2125,32
.type rt_f64_cmp,@function
rt_f64_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2134,%rsp
subq $32,%rsp
movq %rbx,-.F2134-8(%rbp)
movq %r12,-.F2134-16(%rbp)
movq %r13,-.F2134-24(%rbp)
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
jne .L2135
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
jmp .L2136
.L2135:
.L2136:
cmpq $62,%r13
jne .L2137
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
jmp .L2138
.L2137:
.L2138:
cmpq $269,%r13
jne .L2139
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
jnc .L2141
call rt_abort
.L2141:
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
jmp .L2140
.L2139:
.L2140:
cmpq $270,%r13
jne .L2142
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
jnc .L2144
call rt_abort
.L2144:
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
jmp .L2143
.L2142:
.L2143:
cmpq $258,%r13
jne .L2145
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm1,%xmm0
sete %al
setnp %cl
andb %cl,%al
movzbq %al,%rax
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
jmp .L2146
.L2145:
.L2146:
movabsq $259,%rcx
cmpq $259,%r13
jne .L2147
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
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
jmp .L2148
.L2147:
.L2148:
call rt_abort
movabsq $0,%rax
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2134-8(%rbp),%rbx
movq -.F2134-16(%rbp),%r12
movq -.F2134-24(%rbp),%r13
leave
ret
.set .F2134,48
.type rt_f64_from_int,@function
rt_f64_from_int:
pushq %rbp
movq %rsp,%rbp
subq $.F2149,%rsp
subq $16,%rsp
movq %rbx,-.F2149-8(%rbp)
movq %r12,-.F2149-16(%rbp)
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
.L2150:
movq %rax,-24(%rbp)
movabsq $1,%rcx
andq $1,%rax
testq %rax,%rax
jz .L2151
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq -.F2149-8(%rbp),%rbx
movq -.F2149-16(%rbp),%r12
leave
ret
jmp .L2152
.L2151:
.L2152:
movabsq $9223372036854775808,%rcx
cmpq %rcx,%rbx
jae .L2153
movq %rbx,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq -.F2149-8(%rbp),%rbx
movq -.F2149-16(%rbp),%r12
leave
ret
jmp .L2154
.L2153:
.L2154:
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
jz .L2155
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L2157
call rt_abort
.L2157:
movq %rax,%r12
jmp .L2156
.L2155:
.L2156:
movq %r12,%rax
cvtsi2sdq %rax,%xmm0
movq %xmm0,%rax
movq %rax,%rcx
movq %rax,%xmm0
movq %rax,%xmm1
addsd %xmm1,%xmm0
movq %xmm0,%rax
movq -.F2149-8(%rbp),%rbx
movq -.F2149-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2149-8(%rbp),%rbx
movq -.F2149-16(%rbp),%r12
leave
ret
.set .F2149,48
.type rt_int_from_f64,@function
rt_int_from_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F2158,%rsp
subq $32,%rsp
movq %rbx,-.F2158-8(%rbp)
movq %r12,-.F2158-16(%rbp)
movq %r13,-.F2158-24(%rbp)
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
.L2159:
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
jne .L2160
call rt_abort
jmp .L2161
.L2160:
.L2161:
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i76
call rt_abort
.L2120_i76:
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
jz .L2162
movabsq $1,%rcx
movq %r12,%rax
subq $1,%rax
jnc .L2164
call rt_abort
.L2164:
movq %rax,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i77
call rt_abort
.L2120_i77:
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
jae .L2165
movq %r13,%rax
movq -48(%rbp),%rcx
movq %r13,%xmm0
movq %rcx,%xmm1
subsd %xmm1,%xmm0
movq %xmm0,%rax
movq %rax,%r13
jmp .L2166
.L2165:
.L2166:
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
jne .L2167
call rt_abort
jmp .L2168
.L2167:
.L2168:
cmpq $64,%r12
jae .L2169
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
jne .L2171
call rt_abort
jmp .L2172
.L2171:
.L2172:
jmp .L2170
.L2169:
movq %rbx,%rax
movq %r13,%rcx
movq %rbx,%xmm0
movq %r13,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L2173
call rt_abort
jmp .L2174
.L2173:
.L2174:
.L2170:
movq %rbx,%rax
movq %rbx,%xmm0
cvttsd2si %xmm0,%rax
movq -.F2158-8(%rbp),%rbx
movq -.F2158-16(%rbp),%r12
movq -.F2158-24(%rbp),%r13
leave
ret
jmp .L2163
.L2162:
.L2163:
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
jne .L2175
call rt_abort
jmp .L2176
.L2175:
.L2176:
movq %r12,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i80
call rt_abort
.L2120_i80:
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
jne .L2177
call rt_abort
jmp .L2178
.L2177:
.L2178:
movabsq $63,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i81
call rt_abort
.L2120_i81:
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
jz .L2179
movq %rbx,%rax
movq %rbx,%xmm0
cvttsd2si %xmm0,%rax
movq -.F2158-8(%rbp),%rbx
movq -.F2158-16(%rbp),%r12
movq -.F2158-24(%rbp),%r13
leave
ret
jmp .L2180
.L2179:
.L2180:
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
movq -.F2158-8(%rbp),%rbx
movq -.F2158-16(%rbp),%r12
movq -.F2158-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2158-8(%rbp),%rbx
movq -.F2158-16(%rbp),%r12
movq -.F2158-24(%rbp),%r13
leave
ret
.set .F2158,128
.type rt_f64_trunc,@function
rt_f64_trunc:
pushq %rbp
movq %rsp,%rbp
subq $.F2181,%rsp
subq $16,%rsp
movq %rbx,-.F2181-8(%rbp)
movq %r12,-.F2181-16(%rbp)
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
jnc .L2182
call rt_abort
.L2182:
movabsq $52,%rcx
movq %rbx,%rax
shrq %cl,%rax
movq %rax,-16(%rbp)
andq $2047,%rax
movq %rax,%r12
movq %rax,%rcx
movabsq $1074,%rax
cmpq %rcx,%rax
jae .L2183
movq %rbx,%rax
movq -.F2181-8(%rbp),%rbx
movq -.F2181-16(%rbp),%r12
leave
ret
jmp .L2184
.L2183:
.L2184:
cmpq $1023,%r12
jae .L2185
movabsq $9223372036854775808,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq -.F2181-8(%rbp),%rbx
movq -.F2181-16(%rbp),%r12
leave
ret
jmp .L2186
.L2185:
.L2186:
movabsq $1075,%rax
subq %r12,%rax
jnc .L2187
call rt_abort
.L2187:
movq %rax,-24(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2188
call rt_abort
.L2188:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,-32(%rbp)
subq $1,%rax
jnc .L2189
call rt_abort
.L2189:
movq %rax,-40(%rbp)
movq %rax,%rcx
movabsq $18446744073709551615,%rax
subq %rcx,%rax
jnc .L2190
call rt_abort
.L2190:
movq %rax,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq -.F2181-8(%rbp),%rbx
movq -.F2181-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2181-8(%rbp),%rbx
movq -.F2181-16(%rbp),%r12
leave
ret
.set .F2181,48
.type rt_f64_floor,@function
rt_f64_floor:
pushq %rbp
movq %rsp,%rbp
subq $.F2191,%rsp
subq $16,%rsp
movq %rbx,-.F2191-8(%rbp)
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
jz .L2192
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i82
call rt_abort
.L2120_i82:
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
movq -.F2191-8(%rbp),%rbx
leave
ret
jmp .L2193
.L2192:
.L2193:
movq %rbx,%rax
movq -.F2191-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2191-8(%rbp),%rbx
leave
ret
.set .F2191,16
.type rt_f64_ceil,@function
rt_f64_ceil:
pushq %rbp
movq %rsp,%rbp
subq $.F2194,%rsp
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
jz .L2195
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i83
call rt_abort
.L2120_i83:
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
jmp .L2196
.L2195:
.L2196:
movq -16(%rbp),%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2194,32
.type rt_f64_round,@function
rt_f64_round:
pushq %rbp
movq %rsp,%rbp
subq $.F2197,%rsp
subq $16,%rsp
movq %rbx,-.F2197-8(%rbp)
movq %r12,-.F2197-16(%rbp)
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
jnc .L2120_i85
call rt_abort
.L2120_i85:
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
jnc .L2198
call rt_abort
.L2198:
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
movq -32(%rbp),%rcx
movq %rax,%xmm0
movq %rcx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L2199
movq %rbx,%rax
movq -.F2197-8(%rbp),%rbx
movq -.F2197-16(%rbp),%r12
leave
ret
jmp .L2200
.L2199:
.L2200:
movabsq $63,%rax
cmpq $63,%rax
jnc .L2201
call rt_abort
.L2201:
movabsq $63,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-40(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
je .L2202
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i86
call rt_abort
.L2120_i86:
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
movq -.F2197-8(%rbp),%rbx
movq -.F2197-16(%rbp),%r12
leave
ret
jmp .L2203
.L2202:
.L2203:
movabsq $0,%rdi
movq $0,%r9
movq %rdi,%r8
movq %r8,%rcx
movabsq $1023,%rax
addq %rcx,%rax
jnc .L2120_i87
call rt_abort
.L2120_i87:
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
movq -.F2197-8(%rbp),%rbx
movq -.F2197-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2197-8(%rbp),%rbx
movq -.F2197-16(%rbp),%r12
leave
ret
.set .F2197,64
.type rt_f64_min,@function
rt_f64_min:
pushq %rbp
movq %rsp,%rbp
subq $.F2204,%rsp
subq $16,%rsp
movq %rbx,-.F2204-8(%rbp)
movq %r12,-.F2204-16(%rbp)
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
jne .L2205
movq %r12,%rax
movq -.F2204-8(%rbp),%rbx
movq -.F2204-16(%rbp),%r12
leave
ret
jmp .L2206
.L2205:
.L2206:
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
jne .L2207
movq %rbx,%rax
movq -.F2204-8(%rbp),%rbx
movq -.F2204-16(%rbp),%r12
leave
ret
jmp .L2208
.L2207:
.L2208:
movq %r12,%rax
movq %rbx,%rcx
movq %r12,%xmm0
movq %rbx,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L2209
movq %r12,%rax
movq -.F2204-8(%rbp),%rbx
movq -.F2204-16(%rbp),%r12
leave
ret
jmp .L2210
.L2209:
.L2210:
movq %rbx,%rax
movq -.F2204-8(%rbp),%rbx
movq -.F2204-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2204-8(%rbp),%rbx
movq -.F2204-16(%rbp),%r12
leave
ret
.set .F2204,32
.type rt_f64_max,@function
rt_f64_max:
pushq %rbp
movq %rsp,%rbp
subq $.F2211,%rsp
subq $16,%rsp
movq %rbx,-.F2211-8(%rbp)
movq %r12,-.F2211-16(%rbp)
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
jne .L2212
movq %r12,%rax
movq -.F2211-8(%rbp),%rbx
movq -.F2211-16(%rbp),%r12
leave
ret
jmp .L2213
.L2212:
.L2213:
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
jne .L2214
movq %rbx,%rax
movq -.F2211-8(%rbp),%rbx
movq -.F2211-16(%rbp),%r12
leave
ret
jmp .L2215
.L2214:
.L2215:
movq %rbx,%rax
movq %r12,%rcx
movq %rbx,%xmm0
movq %r12,%xmm1
ucomisd %xmm0,%xmm1
seta %al
movzbq %al,%rax
testq %rax,%rax
jz .L2216
movq %r12,%rax
movq -.F2211-8(%rbp),%rbx
movq -.F2211-16(%rbp),%r12
leave
ret
jmp .L2217
.L2216:
.L2217:
movq %rbx,%rax
movq -.F2211-8(%rbp),%rbx
movq -.F2211-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2211-8(%rbp),%rbx
movq -.F2211-16(%rbp),%r12
leave
ret
.set .F2211,32
.type rt_f64_is_finite,@function
rt_f64_is_finite:
pushq %rbp
movq %rsp,%rbp
subq $.F2218,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $63,%rax
cmpq $52,%rax
jnc .L2219
call rt_abort
.L2219:
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
.set .F2218,32
.type rt_f64_is_infinite,@function
rt_f64_is_infinite:
pushq %rbp
movq %rsp,%rbp
subq $.F2220,%rsp
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
.set .F2220,16
.type rt_float_step,@function
rt_float_step:
pushq %rbp
movq %rsp,%rbp
subq $.F2221,%rsp
subq $32,%rsp
movq %rbx,-.F2221-8(%rbp)
movq %r12,-.F2221-16(%rbp)
movq %r13,-.F2221-24(%rbp)
movq %r14,-.F2221-32(%rbp)
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
jne .L2222
movq %r13,%rax
movq -.F2221-8(%rbp),%rbx
movq -.F2221-16(%rbp),%r12
movq -.F2221-24(%rbp),%r13
movq -.F2221-32(%rbp),%r14
leave
ret
jmp .L2223
.L2222:
.L2223:
movq %r13,%rbx
movabsq $9223372036854775808,%rax
movq %rax,%r14
movabsq $9218868437227405312,%rax
movq %rax,-40(%rbp)
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2224
movq %r13,%rdi
call rt_f32_bits
movq %rax,%rbx
movabsq $2147483648,%r14
movq $2139095040,-40(%rbp)
jmp .L2225
.L2224:
.L2225:
movq %r14,%rax
subq $1,%rax
jnc .L2226
call rt_abort
.L2226:
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
jne .L2227
movq $1,%r12
movabsq $0,%rcx
movq -16(%rbp),%rax
cmpq $0,%rax
jne .L2229
movabsq $1,%rcx
movq %r14,%rax
orq $1,%rax
movq %rax,%r12
jmp .L2230
.L2229:
.L2230:
jmp .L2228
.L2227:
movq -16(%rbp),%rax
movq -64(%rbp),%rcx
cmpq %rcx,%rax
je .L2231
movq -48(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
je .L2233
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L2235
call rt_abort
.L2235:
movq %rax,%r12
jmp .L2234
.L2233:
.L2234:
jmp .L2232
.L2231:
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2236
call rt_abort
.L2236:
movq %rax,%r12
.L2232:
.L2228:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2237
movq %r12,%rdi
call rt_f32_from_bits
movq -.F2221-8(%rbp),%rbx
movq -.F2221-16(%rbp),%r12
movq -.F2221-24(%rbp),%r13
movq -.F2221-32(%rbp),%r14
leave
ret
jmp .L2238
.L2237:
.L2238:
movq %r12,%rax
movq -.F2221-8(%rbp),%rbx
movq -.F2221-16(%rbp),%r12
movq -.F2221-24(%rbp),%r13
movq -.F2221-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F2221-8(%rbp),%rbx
movq -.F2221-16(%rbp),%r12
movq -.F2221-24(%rbp),%r13
movq -.F2221-32(%rbp),%r14
leave
ret
.set .F2221,64
.type rt_big,@function
rt_big:
pushq %rbp
movq %rsp,%rbp
subq $.F2239,%rsp
subq $48,%rsp
movq %rbx,-.F2239-8(%rbp)
movq %r12,-.F2239-16(%rbp)
movq %r13,-.F2239-24(%rbp)
movq %r14,-.F2239-32(%rbp)
movq %r15,-.F2239-40(%rbp)
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
.L2240:
cmpq $48,%rbx
jae .L2241
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2242
call rt_abort
.L2242:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L2243
call rt_abort
.L2243:
movq %rax,%rcx
movabsq $0,%rax
movq $0,(%rcx)
xorq $0,%rax
movq %rbx,%rax
addq $1,%rax
jnc .L2244
call rt_abort
.L2244:
movq %rax,%rbx
jmp .L2240
.L2241:
movq -8(%rbp),%rax
movq %rax,%r12
movq $0,%rbx
.L2245:
cmpq $0,%r12
je .L2246
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2247
call rt_abort
.L2247:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L2248
call rt_abort
.L2248:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L2249
call rt_abort
.L2249:
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
jnc .L2250
call rt_abort
.L2250:
movq %rax,%rbx
jmp .L2245
.L2246:
movq %r13,%rax
movq -.F2239-8(%rbp),%rbx
movq -.F2239-16(%rbp),%r12
movq -.F2239-24(%rbp),%r13
movq -.F2239-32(%rbp),%r14
movq -.F2239-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2239-8(%rbp),%rbx
movq -.F2239-16(%rbp),%r12
movq -.F2239-24(%rbp),%r13
movq -.F2239-32(%rbp),%r14
movq -.F2239-40(%rbp),%r15
leave
ret
.set .F2239,16
.type rt_big_mul,@function
rt_big_mul:
pushq %rbp
movq %rsp,%rbp
subq $.F2251,%rsp
subq $48,%rsp
movq %rbx,-.F2251-8(%rbp)
movq %r12,-.F2251-16(%rbp)
movq %r13,-.F2251-24(%rbp)
movq %r14,-.F2251-32(%rbp)
movq %r15,-.F2251-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,-16(%rbp)
movq $0,%r13
movq $0,%rbx
.L2252:
cmpq $48,%rbx
jae .L2253
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2254
call rt_abort
.L2254:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2255
call rt_abort
.L2255:
movq (%rax),%rax
movq -16(%rbp),%rcx
mulq %rcx
jnc .L2256
call rt_abort
.L2256:
addq %r13,%rax
jnc .L2257
call rt_abort
.L2257:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2258
call rt_abort
.L2258:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2259
call rt_abort
.L2259:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L2260
call rt_abort
.L2260:
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
jnc .L2261
call rt_abort
.L2261:
movq %rax,%rbx
jmp .L2252
.L2253:
movabsq $0,%rcx
cmpq $0,%r13
je .L2262
call rt_abort
jmp .L2263
.L2262:
.L2263:
movabsq $0,%rax
movq -.F2251-8(%rbp),%rbx
movq -.F2251-16(%rbp),%r12
movq -.F2251-24(%rbp),%r13
movq -.F2251-32(%rbp),%r14
movq -.F2251-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2251-8(%rbp),%rbx
movq -.F2251-16(%rbp),%r12
movq -.F2251-24(%rbp),%r13
movq -.F2251-32(%rbp),%r14
movq -.F2251-40(%rbp),%r15
leave
ret
.set .F2251,16
.type rt_big_add,@function
rt_big_add:
pushq %rbp
movq %rsp,%rbp
subq $.F2264,%rsp
subq $48,%rsp
movq %rbx,-.F2264-8(%rbp)
movq %r12,-.F2264-16(%rbp)
movq %r13,-.F2264-24(%rbp)
movq %r14,-.F2264-32(%rbp)
movq %r15,-.F2264-40(%rbp)
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
.L2265:
cmpq $48,%rbx
jae .L2266
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2267
call rt_abort
.L2267:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L2268
call rt_abort
.L2268:
movq (%rax),%rax
movq %rax,%r14
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2269
call rt_abort
.L2269:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2270
call rt_abort
.L2270:
movq (%rax),%rax
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2271
call rt_abort
.L2271:
addq %r13,%rax
jnc .L2272
call rt_abort
.L2272:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2273
call rt_abort
.L2273:
movq %rax,%rcx
movq -8(%rbp),%rax
addq %rcx,%rax
jnc .L2274
call rt_abort
.L2274:
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r12,%rax
testq %rcx,%rcx
jnz .L2275
call rt_abort
.L2275:
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
jnc .L2276
call rt_abort
.L2276:
movq %rax,%rbx
jmp .L2265
.L2266:
movabsq $0,%rcx
cmpq $0,%r13
je .L2277
call rt_abort
jmp .L2278
.L2277:
.L2278:
movabsq $0,%rax
movq -.F2264-8(%rbp),%rbx
movq -.F2264-16(%rbp),%r12
movq -.F2264-24(%rbp),%r13
movq -.F2264-32(%rbp),%r14
movq -.F2264-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2264-8(%rbp),%rbx
movq -.F2264-16(%rbp),%r12
movq -.F2264-24(%rbp),%r13
movq -.F2264-32(%rbp),%r14
movq -.F2264-40(%rbp),%r15
leave
ret
.set .F2264,32
.type rt_big_sub,@function
rt_big_sub:
pushq %rbp
movq %rsp,%rbp
subq $.F2279,%rsp
subq $48,%rsp
movq %rbx,-.F2279-8(%rbp)
movq %r12,-.F2279-16(%rbp)
movq %r13,-.F2279-24(%rbp)
movq %r14,-.F2279-32(%rbp)
movq %r15,-.F2279-40(%rbp)
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
.L2280:
cmpq $48,%rbx
jae .L2281
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2282
call rt_abort
.L2282:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2283
call rt_abort
.L2283:
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2284
call rt_abort
.L2284:
movq %rax,%rcx
movq -16(%rbp),%rax
addq %rcx,%rax
jnc .L2285
call rt_abort
.L2285:
movq (%rax),%rax
addq %r15,%rax
jnc .L2286
call rt_abort
.L2286:
movq %rax,%r13
cmpq %r13,%r12
jae .L2287
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2289
call rt_abort
.L2289:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2290
call rt_abort
.L2290:
movq %rax,-24(%rbp)
movq %r12,%rax
addq $1000000000,%rax
jnc .L2291
call rt_abort
.L2291:
subq %r13,%rax
jnc .L2292
call rt_abort
.L2292:
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $1,%r15
jmp .L2288
.L2287:
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2293
call rt_abort
.L2293:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2294
call rt_abort
.L2294:
movq %rax,-32(%rbp)
movq %r12,%rax
subq %r13,%rax
jnc .L2295
call rt_abort
.L2295:
movq -32(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq $0,%r15
.L2288:
movq %rbx,%rax
addq $1,%rax
jnc .L2296
call rt_abort
.L2296:
movq %rax,%rbx
jmp .L2280
.L2281:
movabsq $0,%rax
movq -.F2279-8(%rbp),%rbx
movq -.F2279-16(%rbp),%r12
movq -.F2279-24(%rbp),%r13
movq -.F2279-32(%rbp),%r14
movq -.F2279-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2279-8(%rbp),%rbx
movq -.F2279-16(%rbp),%r12
movq -.F2279-24(%rbp),%r13
movq -.F2279-32(%rbp),%r14
movq -.F2279-40(%rbp),%r15
leave
ret
.set .F2279,32
.type rt_big_cmp,@function
rt_big_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2297,%rsp
subq $48,%rsp
movq %rbx,-.F2297-8(%rbp)
movq %r12,-.F2297-16(%rbp)
movq %r13,-.F2297-24(%rbp)
movq %r14,-.F2297-32(%rbp)
movq %r15,-.F2297-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq %rsi,%r15
movq $48,%rbx
.L2298:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2299
movq %rbx,%rax
subq $1,%rax
jnc .L2300
call rt_abort
.L2300:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2301
call rt_abort
.L2301:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2302
call rt_abort
.L2302:
movq (%rax),%rax
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2303
call rt_abort
.L2303:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2304
call rt_abort
.L2304:
movq (%rax),%rax
movq %rax,%r13
cmpq %r13,%r12
jae .L2305
movabsq $0,%rax
movq -.F2297-8(%rbp),%rbx
movq -.F2297-16(%rbp),%r12
movq -.F2297-24(%rbp),%r13
movq -.F2297-32(%rbp),%r14
movq -.F2297-40(%rbp),%r15
leave
ret
jmp .L2306
.L2305:
.L2306:
cmpq %r12,%r13
jae .L2307
movabsq $2,%rax
movq -.F2297-8(%rbp),%rbx
movq -.F2297-16(%rbp),%r12
movq -.F2297-24(%rbp),%r13
movq -.F2297-32(%rbp),%r14
movq -.F2297-40(%rbp),%r15
leave
ret
jmp .L2308
.L2307:
.L2308:
jmp .L2298
.L2299:
movabsq $1,%rax
movq -.F2297-8(%rbp),%rbx
movq -.F2297-16(%rbp),%r12
movq -.F2297-24(%rbp),%r13
movq -.F2297-32(%rbp),%r14
movq -.F2297-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2297-8(%rbp),%rbx
movq -.F2297-16(%rbp),%r12
movq -.F2297-24(%rbp),%r13
movq -.F2297-32(%rbp),%r14
movq -.F2297-40(%rbp),%r15
leave
ret
.set .F2297,16
.type rt_big_shift,@function
rt_big_shift:
pushq %rbp
movq %rsp,%rbp
subq $.F2309,%rsp
subq $32,%rsp
movq %rbx,-.F2309-8(%rbp)
movq %r12,-.F2309-16(%rbp)
movq %r13,-.F2309-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r12
movq %rsi,%r13
movq $0,%rbx
.L2310:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L2311
movq %r12,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %rbx,%rax
addq $1,%rax
jnc .L2312
call rt_abort
.L2312:
movq %rax,%rbx
jmp .L2310
.L2311:
movabsq $0,%rax
movq -.F2309-8(%rbp),%rbx
movq -.F2309-16(%rbp),%r12
movq -.F2309-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2309-8(%rbp),%rbx
movq -.F2309-16(%rbp),%r12
movq -.F2309-24(%rbp),%r13
leave
ret
.set .F2309,16
.type rt_push_text,@function
rt_push_text:
pushq %rbp
movq %rsp,%rbp
subq $.F2313,%rsp
subq $16,%rsp
movq %rbx,-.F2313-8(%rbp)
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
jb .Lopt89
call rt_pushb
jmp .Lopt90
.Lopt89:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt90:
movq -24(%rbp),%rax
cmpq $0,%rax
je .L2314
movq -24(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt91
call rt_pushb
jmp .Lopt92
.Lopt91:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt92:
jmp .L2315
.L2314:
.L2315:
movq -32(%rbp),%rax
cmpq $0,%rax
je .L2316
movq -32(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt93
call rt_pushb
jmp .Lopt94
.Lopt93:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt94:
jmp .L2317
.L2316:
.L2317:
movabsq $0,%rax
movq -.F2313-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2313-8(%rbp),%rbx
leave
ret
.set .F2313,32
.type rt_fmt_f64,@function
rt_fmt_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F2318,%rsp
subq $48,%rsp
movq %rbx,-.F2318-8(%rbp)
movq %r12,-.F2318-16(%rbp)
movq %r13,-.F2318-24(%rbp)
movq %r14,-.F2318-32(%rbp)
movq %r15,-.F2318-40(%rbp)
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
jne .L2319
movq %r12,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F2318-8(%rbp),%rbx
movq -.F2318-16(%rbp),%r12
movq -.F2318-24(%rbp),%r13
movq -.F2318-32(%rbp),%r14
movq -.F2318-40(%rbp),%r15
leave
ret
jmp .L2320
.L2319:
.L2320:
movq %r13,%rcx
movabsq $9223372036854775807,%rax
cmpq %r13,%rax
jae .L2321
movq %r12,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt95
call rt_pushb
jmp .Lopt96
.Lopt95:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt96:
jmp .L2322
.L2321:
.L2322:
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
jne .L2323
movq %r12,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F2318-8(%rbp),%rbx
movq -.F2318-16(%rbp),%r12
movq -.F2318-24(%rbp),%r13
movq -.F2318-32(%rbp),%r14
movq -.F2318-40(%rbp),%r15
leave
ret
jmp .L2324
.L2323:
.L2324:
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
jz .L2325
movq %r12,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt97
call rt_pushb
jmp .Lopt98
.Lopt97:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt98:
movabsq $0,%rax
movq -.F2318-8(%rbp),%rbx
movq -.F2318-16(%rbp),%r12
movq -.F2318-24(%rbp),%r13
movq -.F2318-32(%rbp),%r14
movq -.F2318-40(%rbp),%r15
leave
ret
jmp .L2326
.L2325:
.L2326:
movq %r14,-48(%rbp)
movq $0,-56(%rbp)
cmpq $0,%rbx
jne .L2327
movq $1074,%r15
movq $1,-56(%rbp)
jmp .L2328
.L2327:
movabsq $4503599627370496,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2329
call rt_abort
.L2329:
movq %rax,-48(%rbp)
cmpq $1075,%rbx
jae .L2330
movabsq $1075,%rax
subq %rbx,%rax
jnc .L2332
call rt_abort
.L2332:
movq %rax,%r15
movq $1,-56(%rbp)
jmp .L2331
.L2330:
movq %rbx,%rax
subq $1075,%rax
jnc .L2333
call rt_abort
.L2333:
movq %rax,%r15
.L2331:
.L2328:
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
movq -.F2318-8(%rbp),%rbx
movq -.F2318-16(%rbp),%r12
movq -.F2318-24(%rbp),%r13
movq -.F2318-32(%rbp),%r14
movq -.F2318-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2318-8(%rbp),%rbx
movq -.F2318-16(%rbp),%r12
movq -.F2318-24(%rbp),%r13
movq -.F2318-32(%rbp),%r14
movq -.F2318-40(%rbp),%r15
leave
ret
.set .F2318,64
.type rt_fmt_shortest,@function
rt_fmt_shortest:
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
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq %rcx,-32(%rbp)
movq %r8,-40(%rbp)
leaq -.F2334(%rbp),%rdi
movq $.F2334/8-5,%rcx
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
jne .L2335
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
jmp .L2336
.L2335:
movq -24(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_big_shift
.L2336:
movq %rbx,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %r13,%rdi
movabsq $2,%rsi
call rt_big_mul
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2337
movq %rbx,%rdi
movabsq $2,%rsi
call rt_big_mul
movq %r13,%rdi
movabsq $2,%rsi
call rt_big_mul
movq -64(%rbp),%rdi
movabsq $2,%rsi
call rt_big_mul
jmp .L2338
.L2337:
.L2338:
movabsq $0,%rdi
call rt_big
movq %rax,%r15
movq $0,-80(%rbp)
movq $0,-88(%rbp)
.L2339:
movabsq $1,%rax
testq %rax,%rax
jz .L2340
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
jnc .L2341
call rt_abort
.L2341:
testq %rax,%rax
jz .L2342
movq %r13,%rdi
movabsq $10,%rsi
call rt_big_mul
movq -88(%rbp),%rax
testq %rax,%rax
jz .L2344
movq -80(%rbp),%rax
cmpq $1,%rax
jne .L2346
movq $0,-88(%rbp)
jmp .L2347
.L2346:
.L2347:
movabsq $1,%rcx
movq -80(%rbp),%rax
subq $1,%rax
jnc .L2348
call rt_abort
.L2348:
movq %rax,-80(%rbp)
jmp .L2345
.L2344:
movabsq $1,%rcx
movq -80(%rbp),%rax
addq $1,%rax
jnc .L2349
call rt_abort
.L2349:
movq %rax,-80(%rbp)
.L2345:
jmp .L2343
.L2342:
jmp .L2340
.L2343:
jmp .L2339
.L2340:
.L2350:
movabsq $1,%rax
testq %rax,%rax
jz .L2351
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
jnc .L2352
call rt_abort
.L2352:
testq %rax,%rax
jz .L2353
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
jz .L2355
movabsq $1,%rcx
movq -80(%rbp),%rax
addq $1,%rax
jnc .L2357
call rt_abort
.L2357:
movq %rax,-80(%rbp)
jmp .L2356
.L2355:
movabsq $0,%rcx
movq -80(%rbp),%rax
cmpq $0,%rax
jne .L2358
movq $1,-88(%rbp)
movq $1,-80(%rbp)
jmp .L2359
.L2358:
movabsq $1,%rcx
movq -80(%rbp),%rax
subq $1,%rax
jnc .L2360
call rt_abort
.L2360:
movq %rax,-80(%rbp)
.L2359:
.L2356:
jmp .L2354
.L2353:
jmp .L2351
.L2354:
jmp .L2350
.L2351:
call rt_new
movq %rax,-152(%rbp)
.L2361:
movabsq $1,%rax
testq %rax,%rax
jz .L2362
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
.L2363:
movq %rbx,%rdi
movq %r13,%rsi
call rt_big_cmp
movabsq $0,%rcx
cmpq $0,%rax
je .L2364
movq %rbx,%rdi
movq %r13,%rsi
call rt_big_sub
movabsq $1,%rcx
movq %r12,%rax
addq $1,%rax
jnc .L2365
call rt_abort
.L2365:
movq %rax,%r12
jmp .L2363
.L2364:
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
jnc .L2366
call rt_abort
.L2366:
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
jnc .L2367
call rt_abort
.L2367:
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
jz .L2368
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt99
call rt_push
jmp .Lopt100
.Lopt99:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt100:
jmp .L2361
jmp .L2369
.L2368:
.L2369:
movq -216(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -184(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2370
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt101
call rt_push
jmp .Lopt102
.Lopt101:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt102:
jmp .L2362
jmp .L2371
.L2370:
.L2371:
movq -184(%rbp),%rax
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -216(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2372
movq %r12,%rax
addq $1,%rax
jnc .L2374
call rt_abort
.L2374:
movq -152(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt103
call rt_push
jmp .Lopt104
.Lopt103:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt104:
jmp .L2362
jmp .L2373
.L2372:
.L2373:
movq %r15,%rdi
movq %rbx,%rsi
movq %rbx,%rdx
call rt_big_add
movq %r15,%rdi
movq %r13,%rsi
call rt_big_cmp
movq %rax,-232(%rbp)
cmpq $0,%rax
jne .L2375
movq -152(%rbp),%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt105
call rt_push
jmp .Lopt106
.Lopt105:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt106:
jmp .L2376
.L2375:
movq %r12,%rax
addq $1,%rax
jnc .L2377
call rt_abort
.L2377:
movq -152(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt107
call rt_push
jmp .Lopt108
.Lopt107:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt108:
.L2376:
jmp .L2362
jmp .L2361
.L2362:
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
jnc .L2378
call rt_abort
.L2378:
testq %rax,%rax
jz .L2379
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt109
call rt_pushb
jmp .Lopt110
.Lopt109:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt110:
movq -8(%rbp),%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt111
call rt_pushb
jmp .Lopt112
.Lopt111:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt112:
movq $0,-248(%rbp)
movq -88(%rbp),%rax
testq %rax,%rax
jz .L2381
movq -80(%rbp),%rax
movq %rax,-248(%rbp)
jmp .L2382
.L2381:
.L2382:
movq $0,-256(%rbp)
.L2383:
movq -256(%rbp),%rax
movq -248(%rbp),%rcx
cmpq %rcx,%rax
jae .L2384
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt113
call rt_pushb
jmp .Lopt114
.Lopt113:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt114:
movq -256(%rbp),%rax
addq $1,%rax
jnc .L2385
call rt_abort
.L2385:
movq %rax,-256(%rbp)
jmp .L2383
.L2384:
movq $0,-256(%rbp)
.L2386:
movq -256(%rbp),%rax
movq -240(%rbp),%rcx
cmpq %rcx,%rax
jae .L2387
movq -256(%rbp),%rax
movq -152(%rbp),%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i88
call rt_abort
.Lopt36_i88:
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
jnc .L2388
call rt_abort
.L2388:
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt115
call rt_pushb
jmp .Lopt116
.Lopt115:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt116:
movq -256(%rbp),%rax
addq $1,%rax
jnc .L2389
call rt_abort
.L2389:
movq %rax,-256(%rbp)
jmp .L2386
.L2387:
jmp .L2380
.L2379:
movq $0,-264(%rbp)
.L2390:
movq -264(%rbp),%rax
movq -240(%rbp),%rcx
cmpq %rcx,%rax
jae .L2391
movq -264(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jne .L2392
movq -8(%rbp),%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt117
call rt_pushb
jmp .Lopt118
.Lopt117:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt118:
jmp .L2393
.L2392:
.L2393:
movq -264(%rbp),%rax
movq -152(%rbp),%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i89
call rt_abort
.Lopt36_i89:
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
jnc .L2394
call rt_abort
.L2394:
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt119
call rt_pushb
jmp .Lopt120
.Lopt119:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt120:
movq -264(%rbp),%rax
addq $1,%rax
jnc .L2395
call rt_abort
.L2395:
movq %rax,-264(%rbp)
jmp .L2390
.L2391:
.L2396:
movq -264(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jae .L2397
movq -8(%rbp),%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt121
call rt_pushb
jmp .Lopt122
.Lopt121:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt122:
movq -264(%rbp),%rax
addq $1,%rax
jnc .L2398
call rt_abort
.L2398:
movq %rax,-264(%rbp)
jmp .L2396
.L2397:
.L2380:
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
.set .F2334,272
.type rt_print_f64,@function
rt_print_f64:
pushq %rbp
movq %rsp,%rbp
subq $.F2399,%rsp
subq $16,%rsp
movq %rbx,-.F2399-8(%rbp)
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
jz .L2400
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt123
call rt_pushb
jmp .Lopt124
.Lopt123:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt124:
jmp .L2401
.L2400:
.L2401:
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
je .L2402
call rt_abort
jmp .L2403
.L2402:
.L2403:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2399-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2399-8(%rbp),%rbx
leave
ret
.set .F2399,48
.type rt_f32_round,@function
rt_f32_round:
pushq %rbp
movq %rsp,%rbp
subq $.F2404,%rsp
subq $48,%rsp
movq %rbx,-.F2404-8(%rbp)
movq %r12,-.F2404-16(%rbp)
movq %r13,-.F2404-24(%rbp)
movq %r14,-.F2404-32(%rbp)
movq %r15,-.F2404-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,-8(%rbp)
leaq -.F2404(%rbp),%rdi
movq $.F2404/8-1,%rcx
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
jne .L2405
movq -8(%rbp),%rax
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
jmp .L2406
.L2405:
.L2406:
movq -24(%rbp),%rax
cmpq $0,%rax
jne .L2407
movq %r15,%rax
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
jmp .L2408
.L2407:
.L2408:
movabsq $4503599627370495,%rcx
movq -8(%rbp),%rax
andq %rcx,%rax
movq %rax,-40(%rbp)
movabsq $4503599627370496,%rcx
addq %rcx,%rax
jnc .L2409
call rt_abort
.L2409:
movq %rax,-48(%rbp)
movq $29,-56(%rbp)
movq -24(%rbp),%rax
cmpq $897,%rax
jae .L2410
movq -24(%rbp),%rcx
movabsq $926,%rax
subq %rcx,%rax
jnc .L2412
call rt_abort
.L2412:
movq %rax,-56(%rbp)
jmp .L2411
.L2410:
.L2411:
movq -56(%rbp),%rcx
movabsq $53,%rax
cmpq %rcx,%rax
jae .L2413
movq %r15,%rax
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
jmp .L2414
.L2413:
.L2414:
movq -56(%rbp),%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2415
call rt_abort
.L2415:
movq -48(%rbp),%rax
shrq %cl,%rax
movq %rax,-64(%rbp)
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2416
call rt_abort
.L2416:
movq -64(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
subq %rcx,%rax
jnc .L2417
call rt_abort
.L2417:
movq %rax,-72(%rbp)
movq -56(%rbp),%rax
subq $1,%rax
jnc .L2418
call rt_abort
.L2418:
movq %rax,-80(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2419
call rt_abort
.L2419:
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
jnc .L2420
call rt_abort
.L2420:
testq %rax,%rax
jz .L2421
movq %r12,%rax
addq $1,%rax
jnc .L2423
call rt_abort
.L2423:
movq %rax,%r12
jmp .L2422
.L2421:
.L2422:
cmpq $0,%r12
jne .L2424
movq %r15,%rax
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
jmp .L2425
.L2424:
.L2425:
movq $0,%rbx
.L2426:
movq %rbx,%rax
addq $1,%rax
jnc .L2428
call rt_abort
.L2428:
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2429
call rt_abort
.L2429:
movabsq $1,%rax
shlq %cl,%rax
movq %rax,%r14
movq %r12,%rax
addq $1,%rax
jnc .L2430
call rt_abort
.L2430:
movq %rax,%rcx
cmpq %rcx,%r14
jae .L2427
movq %rbx,%rax
addq $1,%rax
jnc .L2431
call rt_abort
.L2431:
movq %rax,%rbx
jmp .L2426
.L2427:
movq -24(%rbp),%rax
subq $52,%rax
jnc .L2432
call rt_abort
.L2432:
movq -56(%rbp),%rcx
addq %rcx,%rax
jnc .L2433
call rt_abort
.L2433:
addq %rbx,%rax
jnc .L2434
call rt_abort
.L2434:
movq %rax,-120(%rbp)
movq %rax,%rcx
movabsq $1150,%rax
cmpq %rcx,%rax
jae .L2435
movabsq $9218868437227405312,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2437
call rt_abort
.L2437:
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
jmp .L2436
.L2435:
.L2436:
movabsq $4503599627370496,%rcx
movq -120(%rbp),%rax
mulq %rcx
jnc .L2438
call rt_abort
.L2438:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2439
call rt_abort
.L2439:
movq %rax,-128(%rbp)
movabsq $52,%rax
subq %rbx,%rax
jnc .L2440
call rt_abort
.L2440:
movq %rax,-136(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2441
call rt_abort
.L2441:
movq %r12,%rax
shlq %cl,%rax
movq %rax,-144(%rbp)
movabsq $4503599627370496,%rcx
subq %rcx,%rax
jnc .L2442
call rt_abort
.L2442:
movq %rax,%rcx
movq -128(%rbp),%rax
addq %rcx,%rax
jnc .L2443
call rt_abort
.L2443:
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2404-8(%rbp),%rbx
movq -.F2404-16(%rbp),%r12
movq -.F2404-24(%rbp),%r13
movq -.F2404-32(%rbp),%r14
movq -.F2404-40(%rbp),%r15
leave
ret
.set .F2404,144
.type rt_f32_from_int,@function
rt_f32_from_int:
pushq %rbp
movq %rsp,%rbp
subq $.F2444,%rsp
subq $48,%rsp
movq %rbx,-.F2444-8(%rbp)
movq %r12,-.F2444-16(%rbp)
movq %r13,-.F2444-24(%rbp)
movq %r14,-.F2444-32(%rbp)
movq %r15,-.F2444-40(%rbp)
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
.L2445:
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
jz .L2446
movq $1,-24(%rbp)
movabsq $0,%rax
subq %r14,%rax
movq %rax,%rbx
jmp .L2447
.L2446:
.L2447:
movq $0,%r12
.L2448:
movq %rbx,%rcx
movabsq $9007199254740991,%rax
cmpq %rbx,%rax
jae .L2449
movabsq $1,%rcx
movq %rbx,%rax
andq $1,%rax
movq %rax,%r13
movq %rbx,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rbx
testq %r13,%r13
jz .L2450
movq %rbx,%rax
orq $1,%rax
movq %rax,%rbx
jmp .L2451
.L2450:
.L2451:
movq %r12,%rax
addq $1,%rax
jnc .L2452
call rt_abort
.L2452:
movq %rax,%r12
jmp .L2448
.L2449:
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
jz .L2453
movabsq $4503599627370496,%rcx
movq %r12,%rax
mulq %rcx
jnc .L2455
call rt_abort
.L2455:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2456
call rt_abort
.L2456:
movq %rax,%r15
jmp .L2454
.L2453:
.L2454:
movq %r15,%rdi
call rt_f32_round
movq %rax,-56(%rbp)
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2457
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
movq -.F2444-8(%rbp),%rbx
movq -.F2444-16(%rbp),%r12
movq -.F2444-24(%rbp),%r13
movq -.F2444-32(%rbp),%r14
movq -.F2444-40(%rbp),%r15
leave
ret
jmp .L2458
.L2457:
.L2458:
movq -56(%rbp),%rax
movq -.F2444-8(%rbp),%rbx
movq -.F2444-16(%rbp),%r12
movq -.F2444-24(%rbp),%r13
movq -.F2444-32(%rbp),%r14
movq -.F2444-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2444-8(%rbp),%rbx
movq -.F2444-16(%rbp),%r12
movq -.F2444-24(%rbp),%r13
movq -.F2444-32(%rbp),%r14
movq -.F2444-40(%rbp),%r15
leave
ret
.set .F2444,64
.type rt_fmt_f32,@function
rt_fmt_f32:
pushq %rbp
movq %rsp,%rbp
subq $.F2459,%rsp
subq $48,%rsp
movq %rbx,-.F2459-8(%rbp)
movq %r12,-.F2459-16(%rbp)
movq %r13,-.F2459-24(%rbp)
movq %r14,-.F2459-32(%rbp)
movq %r15,-.F2459-40(%rbp)
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
jne .L2460
movq %rbx,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
jmp .L2461
.L2460:
.L2461:
movq %r13,%rcx
movabsq $9223372036854775807,%rax
cmpq %r13,%rax
jae .L2462
movq %rbx,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt125
call rt_pushb
jmp .Lopt126
.Lopt125:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt126:
jmp .L2463
.L2462:
.L2463:
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
jne .L2464
movq %rbx,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
jmp .L2465
.L2464:
.L2465:
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
jz .L2466
movq %rbx,%rdi
movabsq $48,%rsi
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
movabsq $0,%rax
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
jmp .L2467
.L2466:
.L2467:
movabsq $896,%rax
cmpq %r12,%rax
jae .L2468
movabsq $896,%rcx
movq %r12,%rax
subq $896,%rax
jnc .L2470
call rt_abort
.L2470:
movq %rax,%r14
movq %r15,%rdi
movabsq $536870912,%rsi
call rt_div
movq %rax,-48(%rbp)
movq %rax,-56(%rbp)
addq $8388608,%rax
jnc .L2471
call rt_abort
.L2471:
movq %rax,-64(%rbp)
cmpq $150,%r14
jae .L2472
movabsq $150,%rax
subq %r14,%rax
jnc .L2474
call rt_abort
.L2474:
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
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
jmp .L2473
.L2472:
.L2473:
movq %r14,%rax
subq $150,%rax
jnc .L2475
call rt_abort
.L2475:
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
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
jmp .L2469
.L2468:
.L2469:
movabsq $4503599627370496,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2476
call rt_abort
.L2476:
movq %rax,-96(%rbp)
movabsq $926,%rax
subq %r12,%rax
jnc .L2477
call rt_abort
.L2477:
movq %rax,-104(%rbp)
movq %rax,%rcx
movabsq $63,%rax
cmpq %rcx,%rax
jnc .L2478
call rt_abort
.L2478:
movq -96(%rbp),%rax
shrq %cl,%rax
movq %rax,-112(%rbp)
movq %rbx,%rdi
movq %rax,%rsi
movabsq $149,%rdx
movabsq $1,%rcx
movabsq $0,%r8
call rt_fmt_shortest
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2459-8(%rbp),%rbx
movq -.F2459-16(%rbp),%r12
movq -.F2459-24(%rbp),%r13
movq -.F2459-32(%rbp),%r14
movq -.F2459-40(%rbp),%r15
leave
ret
.set .F2459,112
.type rt_print_f32,@function
rt_print_f32:
pushq %rbp
movq %rsp,%rbp
subq $.F2479,%rsp
subq $16,%rsp
movq %rbx,-.F2479-8(%rbp)
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
jz .L2480
movq %rbx,%rdi
movabsq $10,%rsi
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
jmp .L2481
.L2480:
.L2481:
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
je .L2482
call rt_abort
jmp .L2483
.L2482:
.L2483:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2479-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2479-8(%rbp),%rbx
leave
ret
.set .F2479,48
.type rt_char_from,@function
rt_char_from:
pushq %rbp
movq %rsp,%rbp
subq $.F2484,%rsp
subq $16,%rsp
movq %rbx,-.F2484-8(%rbp)
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
jnc .L2485
call rt_abort
.L2485:
testq %rax,%rax
jz .L2486
call rt_abort
jmp .L2487
.L2486:
.L2487:
movq %rbx,%rax
movq -.F2484-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2484-8(%rbp),%rbx
leave
ret
.set .F2484,32
.type rt_print_char,@function
rt_print_char:
pushq %rbp
movq %rsp,%rbp
subq $.F2488,%rsp
subq $16,%rsp
movq %rbx,-.F2488-8(%rbp)
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
jz .L2489
movq %rbx,%rdi
movabsq $10,%rsi
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
jmp .L2490
.L2489:
.L2490:
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
je .L2491
call rt_abort
jmp .L2492
.L2491:
.L2492:
movq -40(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2488-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2488-8(%rbp),%rbx
leave
ret
.set .F2488,48
.type rt_char_upper,@function
rt_char_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2493,%rsp
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
.set .F2493,16
.type rt_char_lower,@function
rt_char_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2494,%rsp
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
.set .F2494,16
.type rt_char_is_upper,@function
rt_char_is_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2495,%rsp
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
.set .F2495,16
.type rt_char_is_lower,@function
rt_char_is_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2496,%rsp
subq $16,%rsp
movq %rbx,-.F2496-8(%rbp)
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
jnc .L2497
call rt_abort
.L2497:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $312,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2498
call rt_abort
.L2498:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $329,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2499
call rt_abort
.L2499:
movq -.F2496-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2496-8(%rbp),%rbx
leave
ret
.set .F2496,32
.type rt_char_is_alpha,@function
rt_char_is_alpha:
pushq %rbp
movq %rsp,%rbp
subq $.F2500,%rsp
subq $16,%rsp
movq %rbx,-.F2500-8(%rbp)
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
jnc .L2501
call rt_abort
.L2501:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $170,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2502
call rt_abort
.L2502:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $186,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2503
call rt_abort
.L2503:
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
jnc .L2504
call rt_abort
.L2504:
movq -.F2500-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2500-8(%rbp),%rbx
leave
ret
.set .F2500,48
.type rt_char_is_digit,@function
rt_char_is_digit:
pushq %rbp
movq %rsp,%rbp
subq $.F2505,%rsp
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
.set .F2505,16
.type rt_char_is_alnum,@function
rt_char_is_alnum:
pushq %rbp
movq %rsp,%rbp
subq $.F2506,%rsp
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
jnc .L2507
call rt_abort
.L2507:
leave
ret
xorq %rax,%rax
leave
ret
.set .F2506,16
.type rt_char_is_space,@function
rt_char_is_space:
pushq %rbp
movq %rsp,%rbp
subq $.F2508,%rsp
subq $16,%rsp
movq %rbx,-.F2508-8(%rbp)
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
jnc .L2509
call rt_abort
.L2509:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $133,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2510
call rt_abort
.L2510:
movq %rax,-40(%rbp)
movq %rbx,%rax
cmpq $160,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -40(%rbp),%rax
addq %rcx,%rax
jnc .L2511
call rt_abort
.L2511:
movq %rax,-48(%rbp)
movq %rbx,%rax
cmpq $5760,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
addq %rcx,%rax
jnc .L2512
call rt_abort
.L2512:
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
jnc .L2513
call rt_abort
.L2513:
movq %rax,-72(%rbp)
movq %rbx,%rax
cmpq $8232,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2514
call rt_abort
.L2514:
movq %rax,-80(%rbp)
movq %rbx,%rax
cmpq $8233,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L2515
call rt_abort
.L2515:
movq %rax,-88(%rbp)
movq %rbx,%rax
cmpq $8239,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2516
call rt_abort
.L2516:
movq %rax,-96(%rbp)
movq %rbx,%rax
cmpq $8287,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
addq %rcx,%rax
jnc .L2517
call rt_abort
.L2517:
movq %rax,-104(%rbp)
movq %rbx,%rax
cmpq $12288,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
addq %rcx,%rax
jnc .L2518
call rt_abort
.L2518:
movq -.F2508-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2508-8(%rbp),%rbx
leave
ret
.set .F2508,112
.type rt_char_is_ascii,@function
rt_char_is_ascii:
pushq %rbp
movq %rsp,%rbp
subq $.F2519,%rsp
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
.set .F2519,16
.type rt_char_len_utf8,@function
rt_char_len_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F2520,%rsp
subq $16,%rsp
movq %rbx,-.F2520-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq $0,-16(%rbp)
cmpq $128,%rbx
jae .L2521
movabsq $1,%rax
movq -.F2520-8(%rbp),%rbx
leave
ret
jmp .L2522
.L2521:
.L2522:
cmpq $2048,%rbx
jae .L2523
movabsq $2,%rax
movq -.F2520-8(%rbp),%rbx
leave
ret
jmp .L2524
.L2523:
.L2524:
cmpq $65536,%rbx
jae .L2525
movabsq $3,%rax
movq -.F2520-8(%rbp),%rbx
leave
ret
jmp .L2526
.L2525:
.L2526:
movabsq $4,%rax
movq -.F2520-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2520-8(%rbp),%rbx
leave
ret
.set .F2520,16
.type rt_seq_chars,@function
rt_seq_chars:
pushq %rbp
movq %rsp,%rbp
subq $.F2527,%rsp
subq $48,%rsp
movq %rbx,-.F2527-8(%rbp)
movq %r12,-.F2527-16(%rbp)
movq %r13,-.F2527-24(%rbp)
movq %r14,-.F2527-32(%rbp)
movq %r15,-.F2527-40(%rbp)
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
.L2528:
movq -24(%rbp),%rcx
cmpq %rcx,%r14
jae .L2529
movq -8(%rbp),%rdi
movq %r14,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt133
call rt_abort
.Lopt133:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rbx
movq %rax,%r13
movq $0,-32(%rbp)
cmpq $128,%rax
jae .L2530
movq $0,%r12
jmp .L2531
.L2530:
movq %rbx,%rax
andq $224,%rax
movq %rax,-40(%rbp)
cmpq $192,%rax
jne .L2532
movq $1,%r12
movq %rbx,%rax
andq $31,%rax
movq %rax,%r13
movq $128,-32(%rbp)
jmp .L2533
.L2532:
movq %rbx,%rax
andq $240,%rax
movq %rax,-48(%rbp)
cmpq $224,%rax
jne .L2534
movq $2,%r12
movq %rbx,%rax
andq $15,%rax
movq %rax,%r13
movq $2048,-32(%rbp)
jmp .L2535
.L2534:
movq %rbx,%rax
andq $248,%rax
movq %rax,-56(%rbp)
cmpq $240,%rax
jne .L2536
movq $3,%r12
movq %rbx,%rax
andq $7,%rax
movq %rax,%r13
movq $65536,-32(%rbp)
jmp .L2537
.L2536:
movq $99,%r12
.L2537:
.L2535:
.L2533:
.L2531:
cmpq $99,%r12
jne .L2538
movq -16(%rbp),%rdi
movabsq $65533,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt134
call rt_push
jmp .Lopt135
.Lopt134:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt135:
movq %r14,%rax
addq $1,%rax
jnc .L2540
call rt_abort
.L2540:
movq %rax,%r14
jmp .L2528
jmp .L2539
.L2538:
.L2539:
movq $1,-64(%rbp)
movq $1,%r15
.L2541:
movq %r12,%rax
addq $1,%rax
jnc .L2543
call rt_abort
.L2543:
movq %rax,%rcx
cmpq %rcx,%r15
jae .L2542
movq %r14,%rax
addq %r15,%rax
jnc .L2544
call rt_abort
.L2544:
movq %rax,-72(%rbp)
addq $1,%rax
jnc .L2545
call rt_abort
.L2545:
movq %rax,%rcx
movq -24(%rbp),%rax
cmpq %rcx,%rax
jae .L2546
movq $0,-64(%rbp)
jmp .L2542
jmp .L2547
.L2546:
.L2547:
movq %r14,%rax
addq %r15,%rax
jnc .L2548
call rt_abort
.L2548:
movq -8(%rbp),%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt136
call rt_abort
.Lopt136:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-80(%rbp)
movq %rax,-88(%rbp)
andq $192,%rax
movq %rax,-96(%rbp)
cmpq $128,%rax
je .L2549
movq $0,-64(%rbp)
jmp .L2542
jmp .L2550
.L2549:
.L2550:
movabsq $64,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2551
call rt_abort
.L2551:
movq %rax,-104(%rbp)
movq -80(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -104(%rbp),%rax
addq %rcx,%rax
jnc .L2552
call rt_abort
.L2552:
movq %rax,%r13
movq %r15,%rax
addq $1,%rax
jnc .L2553
call rt_abort
.L2553:
movq %rax,%r15
jmp .L2541
.L2542:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L2554
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
jnc .L2556
call rt_abort
.L2556:
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
jnc .L2557
call rt_abort
.L2557:
testq %rax,%rax
jz .L2558
movq $0,-64(%rbp)
jmp .L2559
.L2558:
.L2559:
jmp .L2555
.L2554:
.L2555:
movq -64(%rbp),%rax
testq %rax,%rax
jz .L2560
movq -16(%rbp),%rdi
movq %r13,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt137
call rt_push
jmp .Lopt138
.Lopt137:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt138:
movq %r12,%rax
addq $1,%rax
jnc .L2562
call rt_abort
.L2562:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2563
call rt_abort
.L2563:
movq %rax,%r14
jmp .L2561
.L2560:
movq -16(%rbp),%rdi
movabsq $65533,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt139
call rt_push
jmp .Lopt140
.Lopt139:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt140:
movq %r14,%rax
addq $1,%rax
jnc .L2564
call rt_abort
.L2564:
movq %rax,%r14
.L2561:
jmp .L2528
.L2529:
movq -16(%rbp),%rax
movq -.F2527-8(%rbp),%rbx
movq -.F2527-16(%rbp),%r12
movq -.F2527-24(%rbp),%r13
movq -.F2527-32(%rbp),%r14
movq -.F2527-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2527-8(%rbp),%rbx
movq -.F2527-16(%rbp),%r12
movq -.F2527-24(%rbp),%r13
movq -.F2527-32(%rbp),%r14
movq -.F2527-40(%rbp),%r15
leave
ret
.set .F2527,128
.type rt_big_half,@function
rt_big_half:
pushq %rbp
movq %rsp,%rbp
subq $.F2565,%rsp
subq $48,%rsp
movq %rbx,-.F2565-8(%rbp)
movq %r12,-.F2565-16(%rbp)
movq %r13,-.F2565-24(%rbp)
movq %r14,-.F2565-32(%rbp)
movq %r15,-.F2565-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r14
movq $0,-16(%rbp)
movq $0,%r13
movq $48,%rbx
.L2566:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2567
movq %rbx,%rax
subq $1,%rax
jnc .L2568
call rt_abort
.L2568:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2569
call rt_abort
.L2569:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2570
call rt_abort
.L2570:
movq (%rax),%rax
movq %rax,%r15
movabsq $1000000000,%rcx
movq %r13,%rax
mulq %rcx
jnc .L2571
call rt_abort
.L2571:
movq %rax,%rcx
movq %r15,%rax
addq %rcx,%rax
jnc .L2572
call rt_abort
.L2572:
movq %rax,%r12
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2573
call rt_abort
.L2573:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L2574
call rt_abort
.L2574:
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
.L2575:
movq %rdx,%r13
jmp .L2566
.L2567:
movq %r13,%rax
movq -.F2565-8(%rbp),%rbx
movq -.F2565-16(%rbp),%r12
movq -.F2565-24(%rbp),%r13
movq -.F2565-32(%rbp),%r14
movq -.F2565-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2565-8(%rbp),%rbx
movq -.F2565-16(%rbp),%r12
movq -.F2565-24(%rbp),%r13
movq -.F2565-32(%rbp),%r14
movq -.F2565-40(%rbp),%r15
leave
ret
.set .F2565,16
.type rt_big_is_zero,@function
rt_big_is_zero:
pushq %rbp
movq %rsp,%rbp
subq $.F2576,%rsp
subq $32,%rsp
movq %rbx,-.F2576-8(%rbp)
movq %r12,-.F2576-16(%rbp)
movq %r13,-.F2576-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq $0,%rbx
.L2577:
cmpq $48,%rbx
jae .L2578
movabsq $8,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L2579
call rt_abort
.L2579:
movq %rax,%rcx
movq %r13,%rax
addq %rcx,%rax
jnc .L2580
call rt_abort
.L2580:
movq (%rax),%rax
cmpq $0,%rax
je .L2581
movabsq $0,%rax
movq -.F2576-8(%rbp),%rbx
movq -.F2576-16(%rbp),%r12
movq -.F2576-24(%rbp),%r13
leave
ret
jmp .L2582
.L2581:
.L2582:
movq %rbx,%rax
addq $1,%rax
jnc .L2583
call rt_abort
.L2583:
movq %rax,%rbx
jmp .L2577
.L2578:
movabsq $1,%rax
movq -.F2576-8(%rbp),%rbx
movq -.F2576-16(%rbp),%r12
movq -.F2576-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F2576-8(%rbp),%rbx
movq -.F2576-16(%rbp),%r12
movq -.F2576-24(%rbp),%r13
leave
ret
.set .F2576,16
.type rt_fmt_f64_fixed,@function
rt_fmt_f64_fixed:
pushq %rbp
movq %rsp,%rbp
subq $.F2584,%rsp
subq $48,%rsp
movq %rbx,-.F2584-8(%rbp)
movq %r12,-.F2584-16(%rbp)
movq %r13,-.F2584-24(%rbp)
movq %r14,-.F2584-32(%rbp)
movq %r15,-.F2584-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%r15
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
leaq -.F2584(%rbp),%rdi
movq $.F2584/8-3,%rcx
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
jne .L2585
movq %r15,%rdi
movabsq $78,%rsi
movabsq $97,%rdx
movabsq $78,%rcx
call rt_push_text
movq -.F2584-8(%rbp),%rbx
movq -.F2584-16(%rbp),%r12
movq -.F2584-24(%rbp),%r13
movq -.F2584-32(%rbp),%r14
movq -.F2584-40(%rbp),%r15
leave
ret
jmp .L2586
.L2585:
.L2586:
movq -16(%rbp),%rcx
movabsq $9223372036854775807,%rax
cmpq %rcx,%rax
jae .L2587
movq %r15,%rdi
movabsq $45,%rsi
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
jmp .L2588
.L2587:
.L2588:
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
jne .L2589
movq %r15,%rdi
movabsq $105,%rsi
movabsq $110,%rdx
movabsq $102,%rcx
call rt_push_text
movq -.F2584-8(%rbp),%rbx
movq -.F2584-16(%rbp),%r12
movq -.F2584-24(%rbp),%r13
movq -.F2584-32(%rbp),%r14
movq -.F2584-40(%rbp),%r15
leave
ret
jmp .L2590
.L2589:
.L2590:
movq -56(%rbp),%rax
movq %rax,-64(%rbp)
movq $0,-72(%rbp)
movq $0,-80(%rbp)
movabsq $0,%rcx
movq -48(%rbp),%rax
cmpq $0,%rax
jne .L2591
movq $1074,-72(%rbp)
movq $1,-80(%rbp)
jmp .L2592
.L2591:
movabsq $4503599627370496,%rcx
movq -56(%rbp),%rax
addq %rcx,%rax
jnc .L2593
call rt_abort
.L2593:
movq %rax,-64(%rbp)
movq -48(%rbp),%rax
cmpq $1075,%rax
jae .L2594
movq -48(%rbp),%rcx
movabsq $1075,%rax
subq %rcx,%rax
jnc .L2596
call rt_abort
.L2596:
movq %rax,-72(%rbp)
movq $1,-80(%rbp)
jmp .L2595
.L2594:
movabsq $1075,%rcx
movq -48(%rbp),%rax
subq $1075,%rax
jnc .L2597
call rt_abort
.L2597:
movq %rax,-72(%rbp)
.L2595:
.L2592:
movq -64(%rbp),%rax
movq %rax,%rdi
call rt_big
movq %rax,-88(%rbp)
movq $0,%rbx
.L2598:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2599
movq -88(%rbp),%rdi
movabsq $10,%rsi
call rt_big_mul
movq %rbx,%rax
addq $1,%rax
jnc .L2600
call rt_abort
.L2600:
movq %rax,%rbx
jmp .L2598
.L2599:
movabsq $0,%rcx
movq -80(%rbp),%rax
cmpq $0,%rax
jne .L2601
movq -72(%rbp),%rax
movq -88(%rbp),%rdi
movq %rax,%rsi
call rt_big_shift
jmp .L2602
.L2601:
movq $0,-96(%rbp)
movq $0,-104(%rbp)
movq $0,%rbx
.L2603:
movq -72(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2604
movq -96(%rbp),%rax
testq %rax,%rax
jz .L2605
movq $1,-104(%rbp)
jmp .L2606
.L2605:
.L2606:
movq -88(%rbp),%rax
movq %rax,%rdi
call rt_big_half
movq %rax,-96(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2607
call rt_abort
.L2607:
movq %rax,%rbx
jmp .L2603
.L2604:
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
jnc .L2608
call rt_abort
.L2608:
movq %rax,-128(%rbp)
cmpq $0,%rax
setne %al
movzbq %al,%rax
movq %rax,%rcx
movq -96(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2609
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
jmp .L2610
.L2609:
.L2610:
.L2602:
call rt_new
movq %rax,%r14
movq $47,-144(%rbp)
.L2611:
movq -144(%rbp),%rcx
movabsq $0,%rax
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,-152(%rbp)
movabsq $8,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L2613
call rt_abort
.L2613:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2614
call rt_abort
.L2614:
movq (%rax),%rax
movq %rax,-160(%rbp)
cmpq $0,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2612
movq -144(%rbp),%rax
subq $1,%rax
jnc .L2615
call rt_abort
.L2615:
movq %rax,-144(%rbp)
jmp .L2611
.L2612:
movabsq $8,%rcx
movq -144(%rbp),%rax
mulq %rcx
jnc .L2616
call rt_abort
.L2616:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2617
call rt_abort
.L2617:
movq (%rax),%rax
movq %rax,-168(%rbp)
movq %r14,%rdi
movq %rax,%rsi
call rt_fmt_num
movq -144(%rbp),%rax
movq %rax,%rbx
.L2618:
movabsq $0,%rax
cmpq %rbx,%rax
jae .L2619
movq %rbx,%rax
subq $1,%rax
jnc .L2620
call rt_abort
.L2620:
movq %rax,%rbx
movabsq $8,%rcx
mulq %rcx
jnc .L2621
call rt_abort
.L2621:
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2622
call rt_abort
.L2622:
movq (%rax),%rax
movq %rax,-176(%rbp)
movq $100000000,%r12
.L2623:
movq %r12,%rcx
movabsq $0,%rax
cmpq %r12,%rax
jae .L2624
movq -176(%rbp),%rdi
movq %r12,%rsi
call rt_div
movabsq $10,%rcx
testq %rcx,%rcx
jnz .L2625
call rt_abort
.L2625:
xorq %rdx,%rdx
divq %rcx
movabsq $48,%rax
addq %rdx,%rax
jnc .L2626
call rt_abort
.L2626:
movq %r14,%rdi
movq %rax,%rsi
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
movq %r12,%rdi
movabsq $10,%rsi
call rt_div
movq %rax,%r12
jmp .L2623
.L2624:
jmp .L2618
.L2619:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-184(%rbp)
movq %rax,-192(%rbp)
movq -24(%rbp),%rax
addq $1,%rax
jnc .L2627
call rt_abort
.L2627:
movq %rax,%rcx
movq -192(%rbp),%rax
cmpq %rcx,%rax
jae .L2628
movq -24(%rbp),%rax
addq $1,%rax
jnc .L2630
call rt_abort
.L2630:
movq -184(%rbp),%rcx
subq %rcx,%rax
jnc .L2631
call rt_abort
.L2631:
movq %rax,-200(%rbp)
movq %r15,%rdi
movabsq $48,%rsi
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
movq -24(%rbp),%rax
testq %rax,%rax
jz .L2632
movq %r15,%rdi
movabsq $46,%rsi
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
jmp .L2633
.L2632:
.L2633:
movq -200(%rbp),%rax
subq $1,%rax
jnc .L2634
call rt_abort
.L2634:
movq %rax,-200(%rbp)
.L2635:
movq -200(%rbp),%rcx
movabsq $0,%rax
cmpq %rcx,%rax
jae .L2636
movq %r15,%rdi
movabsq $48,%rsi
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
movq -200(%rbp),%rax
subq $1,%rax
jnc .L2637
call rt_abort
.L2637:
movq %rax,-200(%rbp)
jmp .L2635
.L2636:
movq $0,%rbx
.L2638:
movq -184(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2639
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt151
call rt_abort
.Lopt151:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r15,%rdi
movq %rax,%rsi
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
movq %rbx,%rax
addq $1,%rax
jnc .L2640
call rt_abort
.L2640:
movq %rax,%rbx
jmp .L2638
.L2639:
jmp .L2629
.L2628:
movq $0,%rbx
.L2641:
movq -184(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2642
movq -184(%rbp),%rax
movq -24(%rbp),%rcx
subq %rcx,%rax
jnc .L2643
call rt_abort
.L2643:
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
jz .L2644
movq %r15,%rdi
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
jmp .L2645
.L2644:
.L2645:
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt156
call rt_abort
.Lopt156:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r15,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt157
call rt_pushb
jmp .Lopt158
.Lopt157:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt158:
movq %rbx,%rax
addq $1,%rax
jnc .L2646
call rt_abort
.L2646:
movq %rax,%rbx
jmp .L2641
.L2642:
.L2629:
movq %r14,%rdi
call rt_drop_seq
movq -88(%rbp),%rax
movq %rax,%rdi
call rt_free
movabsq $0,%rax
movq -.F2584-8(%rbp),%rbx
movq -.F2584-16(%rbp),%r12
movq -.F2584-24(%rbp),%r13
movq -.F2584-32(%rbp),%r14
movq -.F2584-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2584-8(%rbp),%rbx
movq -.F2584-16(%rbp),%r12
movq -.F2584-24(%rbp),%r13
movq -.F2584-32(%rbp),%r14
movq -.F2584-40(%rbp),%r15
leave
ret
.set .F2584,208
.type rt_print_acc,@function
rt_print_acc:
pushq %rbp
movq %rsp,%rbp
subq $.F2647,%rsp
subq $16,%rsp
movq %rbx,-.F2647-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2648
movq %rbx,%rdi
movabsq $10,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt159
call rt_pushb
jmp .Lopt160
.Lopt159:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt160:
jmp .L2649
.L2648:
.L2649:
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
je .L2650
call rt_abort
jmp .L2651
.L2650:
.L2651:
movq -32(%rbp),%rax
movq %rax,%rdi
call rt_free
movq %rbx,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2647-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2647-8(%rbp),%rbx
leave
ret
.set .F2647,48
.type f_host_exit,@function
f_host_exit:
pushq %rbp
movq %rsp,%rbp
subq $.F2652,%rsp
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
.set .F2652,16
.type rt_fmt_value,@function
rt_fmt_value:
pushq %rbp
movq %rsp,%rbp
subq $.F2653,%rsp
subq $48,%rsp
movq %rbx,-.F2653-8(%rbp)
movq %r12,-.F2653-16(%rbp)
movq %r13,-.F2653-24(%rbp)
movq %r14,-.F2653-32(%rbp)
movq %r15,-.F2653-40(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq $0,%r15
movq %rdi,%rbx
movq %rsi,%r14
movq %rdx,-24(%rbp)
leaq -.F2653(%rbp),%rdi
movq $.F2653/8-3,%rcx
xorl %eax,%eax
rep stosq
movabsq $1,%rcx
movq -24(%rbp),%rax
cmpq $1,%rax
jne .L2654
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_num
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2655
.L2654:
.L2655:
movabsq $2,%rcx
movq -24(%rbp),%rax
cmpq $2,%rax
jne .L2656
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_bool
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2657
.L2656:
.L2657:
movabsq $3,%rcx
movq -24(%rbp),%rax
cmpq $3,%rax
jne .L2658
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
.L2660:
movq -48(%rbp),%rcx
cmpq %rcx,%r15
jae .L2661
movq %rbx,%rdi
movq %r15,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt161
call rt_abort
.Lopt161:
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
jnc .L2662
call rt_abort
.L2662:
movq %rax,-80(%rbp)
movq -56(%rbp),%rax
cmpq $110,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -80(%rbp),%rax
addq %rcx,%rax
jnc .L2663
call rt_abort
.L2663:
movq %rax,-88(%rbp)
movq -56(%rbp),%rax
cmpq $78,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2664
call rt_abort
.L2664:
testq %rax,%rax
jz .L2665
movq $0,-40(%rbp)
jmp .L2666
.L2665:
.L2666:
movq %r15,%rax
addq $1,%rax
jnc .L2667
call rt_abort
.L2667:
movq %rax,%r15
jmp .L2660
.L2661:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2668
movq %rbx,%rdi
movabsq $46,%rsi
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
movq %rbx,%rdi
movabsq $48,%rsi
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
jmp .L2669
.L2668:
.L2669:
movabsq $0,%rax
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2659
.L2658:
.L2659:
movq -24(%rbp),%rax
cmpq $4,%rax
jne .L2670
movq %rbx,%rdi
movabsq $34,%rsi
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
movq %rbx,%rdi
movq %r14,%rsi
call rt_fmt_seq
movq %rbx,%rdi
movabsq $34,%rsi
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
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2671
.L2670:
.L2671:
movq -24(%rbp),%rax
cmpq $6,%rax
jne .L2672
movq %rbx,%rdi
movabsq $39,%rsi
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
movq %rbx,%rdi
movq %r14,%rsi
call rt_push_utf8
movq %rbx,%rdi
movabsq $39,%rsi
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
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2673
.L2672:
.L2673:
movabsq $7,%rcx
movq -24(%rbp),%rax
cmpq $7,%rax
jne .L2674
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
.L2676:
movq -112(%rbp),%rax
movq -120(%rbp),%rcx
cmpq %rcx,%rax
jae .L2677
movq -112(%rbp),%rax
movq %rbx,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt174
call rt_abort
.Lopt174:
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
jnc .L2678
call rt_abort
.L2678:
movq %rax,-152(%rbp)
movq -128(%rbp),%rax
cmpq $110,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -152(%rbp),%rax
addq %rcx,%rax
jnc .L2679
call rt_abort
.L2679:
movq %rax,-160(%rbp)
movq -128(%rbp),%rax
cmpq $78,%rax
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -160(%rbp),%rax
addq %rcx,%rax
jnc .L2680
call rt_abort
.L2680:
testq %rax,%rax
jz .L2681
movq $0,-104(%rbp)
jmp .L2682
.L2681:
.L2682:
movq -112(%rbp),%rax
addq $1,%rax
jnc .L2683
call rt_abort
.L2683:
movq %rax,-112(%rbp)
jmp .L2676
.L2677:
movq -104(%rbp),%rax
testq %rax,%rax
jz .L2684
movq %rbx,%rdi
movabsq $46,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt175
call rt_pushb
jmp .Lopt176
.Lopt175:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt176:
movq %rbx,%rdi
movabsq $48,%rsi
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
jmp .L2685
.L2684:
.L2685:
movabsq $0,%rax
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2675
.L2674:
.L2675:
movq -24(%rbp),%rax
andq $4095,%rax
movq %rax,-168(%rbp)
movabsq $5,%rcx
cmpq $5,%rax
jne .L2686
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
jb .Lopt179
call rt_pushb
jmp .Lopt180
.Lopt179:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt180:
movq $0,%r12
.L2688:
movq -184(%rbp),%rcx
cmpq %rcx,%r12
jae .L2689
movabsq $0,%rcx
cmpq $0,%r12
je .L2690
movq %rbx,%rdi
movabsq $44,%rsi
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
movq %rbx,%rdi
movabsq $32,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt183
call rt_pushb
jmp .Lopt184
.Lopt183:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt184:
jmp .L2691
.L2690:
.L2691:
movq %r14,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i93
call rt_abort
.Lopt36_i93:
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
jnc .L2692
call rt_abort
.L2692:
movq %rax,%r12
jmp .L2688
.L2689:
movq %rbx,%rdi
movabsq $93,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt185
call rt_pushb
jmp .Lopt186
.Lopt185:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt186:
movabsq $0,%rax
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2687
.L2686:
.L2687:
movq -24(%rbp),%rax
andq $4095,%rax
movq %rax,-200(%rbp)
movabsq $8,%rcx
cmpq $8,%rax
jne .L2693
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
movq $0,%r13
.L2695:
movq -216(%rbp),%rcx
cmpq %rcx,%r13
jae .L2696
movabsq $0,%rcx
cmpq $0,%r13
je .L2697
movq %rbx,%rdi
movabsq $44,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt189
call rt_pushb
jmp .Lopt190
.Lopt189:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt190:
movq %rbx,%rdi
movabsq $32,%rsi
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
jmp .L2698
.L2697:
.L2698:
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
jnc .L2699
call rt_abort
.L2699:
movq %rax,%r13
jmp .L2695
.L2696:
movq %rbx,%rdi
movabsq $93,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt193
call rt_pushb
jmp .Lopt194
.Lopt193:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt194:
movabsq $0,%rax
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2694
.L2693:
.L2694:
movq -24(%rbp),%rcx
movabsq $1023,%rax
cmpq %rcx,%rax
jae .L2700
movabsq $1024,%rcx
movq -24(%rbp),%rax
subq $1024,%rax
jnc .L2702
call rt_abort
.L2702:
movq %rbx,%rdi
movq %r14,%rsi
movq %rax,%rdx
call rt_fmt_int
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
jmp .L2701
.L2700:
.L2701:
call rt_abort
movabsq $0,%rax
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2653-8(%rbp),%rbx
movq -.F2653-16(%rbp),%r12
movq -.F2653-24(%rbp),%r13
movq -.F2653-32(%rbp),%r14
movq -.F2653-40(%rbp),%r15
leave
ret
.set .F2653,240
.type f_host_remove,@function
f_host_remove:
pushq %rbp
movq %rsp,%rbp
subq $.F2703,%rsp
subq $16,%rsp
movq %rbx,-.F2703-8(%rbp)
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
jne .L2704
movabsq $22,%rax
movq -.F2703-8(%rbp),%rbx
leave
ret
jmp .L2705
.L2704:
.L2705:
movq $0,-24(%rbp)
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2706
movq $512,-24(%rbp)
jmp .L2707
.L2706:
.L2707:
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
jz .L2708
movq -40(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F2703-8(%rbp),%rbx
leave
ret
jmp .L2709
.L2708:
.L2709:
movabsq $0,%rax
movq -.F2703-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2703-8(%rbp),%rbx
leave
ret
.set .F2703,48
.type f_host_create_dir,@function
f_host_create_dir:
pushq %rbp
movq %rsp,%rbp
subq $.F2710,%rsp
subq $16,%rsp
movq %rbx,-.F2710-8(%rbp)
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
jne .L2711
movabsq $22,%rax
movq -.F2710-8(%rbp),%rbx
leave
ret
jmp .L2712
.L2711:
.L2712:
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
jz .L2713
movq -24(%rbp),%rcx
movabsq $0,%rax
subq %rcx,%rax
movq -.F2710-8(%rbp),%rbx
leave
ret
jmp .L2714
.L2713:
.L2714:
movabsq $0,%rax
movq -.F2710-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2710-8(%rbp),%rbx
leave
ret
.set .F2710,32
.type rt_fmt_pad,@function
rt_fmt_pad:
pushq %rbp
movq %rsp,%rbp
subq $.F2715,%rsp
subq $48,%rsp
movq %rbx,-.F2715-8(%rbp)
movq %r12,-.F2715-16(%rbp)
movq %r13,-.F2715-24(%rbp)
movq %r14,-.F2715-32(%rbp)
movq %r15,-.F2715-40(%rbp)
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
.L2716:
cmpq %r15,%rbx
jae .L2717
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt195
call rt_abort
.Lopt195:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-64(%rbp)
andq $192,%rax
movq %rax,-72(%rbp)
cmpq $128,%rax
je .L2718
movq -56(%rbp),%rax
addq $1,%rax
jnc .L2720
call rt_abort
.L2720:
movq %rax,-56(%rbp)
jmp .L2719
.L2718:
.L2719:
movq %rbx,%rax
addq $1,%rax
jnc .L2721
call rt_abort
.L2721:
movq %rax,%rbx
jmp .L2716
.L2717:
movq $0,-80(%rbp)
movq -56(%rbp),%rax
movq -24(%rbp),%rcx
cmpq %rcx,%rax
jae .L2722
movq -24(%rbp),%rax
movq -56(%rbp),%rcx
subq %rcx,%rax
jnc .L2724
call rt_abort
.L2724:
movq %rax,-80(%rbp)
jmp .L2723
.L2722:
.L2723:
movq -40(%rbp),%rax
testq %rax,%rax
jz .L2725
movq $0,%rbx
cmpq $0,%r15
je .L2727
movq %r14,%rdi
movabsq $0,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt196
call rt_abort
.Lopt196:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-88(%rbp)
cmpq $45,%rax
jne .L2729
movq %r13,%rdi
movabsq $45,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt197
call rt_pushb
jmp .Lopt198
.Lopt197:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt198:
movq $1,%rbx
jmp .L2730
.L2729:
.L2730:
jmp .L2728
.L2727:
.L2728:
movq $0,-96(%rbp)
.L2731:
movq -96(%rbp),%rax
movq -80(%rbp),%rcx
cmpq %rcx,%rax
jae .L2732
movq %r13,%rdi
movabsq $48,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt199
call rt_pushb
jmp .Lopt200
.Lopt199:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt200:
movq -96(%rbp),%rax
addq $1,%rax
jnc .L2733
call rt_abort
.L2733:
movq %rax,-96(%rbp)
jmp .L2731
.L2732:
.L2734:
movq %r15,%rcx
cmpq %r15,%rbx
jae .L2735
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt201
call rt_abort
.Lopt201:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
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
addq $1,%rax
jnc .L2736
call rt_abort
.L2736:
movq %rax,%rbx
jmp .L2734
.L2735:
movq %r14,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2715-8(%rbp),%rbx
movq -.F2715-16(%rbp),%r12
movq -.F2715-24(%rbp),%r13
movq -.F2715-32(%rbp),%r14
movq -.F2715-40(%rbp),%r15
leave
ret
jmp .L2726
.L2725:
.L2726:
movq $0,-104(%rbp)
movq -32(%rbp),%rax
cmpq $2,%rax
jne .L2737
movq -80(%rbp),%rax
movq %rax,-104(%rbp)
jmp .L2738
.L2737:
.L2738:
movabsq $3,%rcx
movq -32(%rbp),%rax
cmpq $3,%rax
jne .L2739
movq -80(%rbp),%rdi
movabsq $2,%rsi
call rt_div
movq %rax,-104(%rbp)
jmp .L2740
.L2739:
.L2740:
movq -80(%rbp),%rax
movq -104(%rbp),%rcx
subq %rcx,%rax
jnc .L2741
call rt_abort
.L2741:
movq %rax,-112(%rbp)
movq $0,%r12
.L2742:
movq -104(%rbp),%rcx
cmpq %rcx,%r12
jae .L2743
movq -48(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_push_char
movq %r12,%rax
addq $1,%rax
jnc .L2744
call rt_abort
.L2744:
movq %rax,%r12
jmp .L2742
.L2743:
movq $0,%rbx
.L2745:
cmpq %r15,%rbx
jae .L2746
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt204
call rt_abort
.Lopt204:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt205
call rt_pushb
jmp .Lopt206
.Lopt205:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt206:
movq %rbx,%rax
addq $1,%rax
jnc .L2747
call rt_abort
.L2747:
movq %rax,%rbx
jmp .L2745
.L2746:
movq $0,%r12
.L2748:
movq -112(%rbp),%rcx
cmpq %rcx,%r12
jae .L2749
movq -48(%rbp),%rax
movq %r13,%rdi
movq %rax,%rsi
call rt_push_char
movq %r12,%rax
addq $1,%rax
jnc .L2750
call rt_abort
.L2750:
movq %rax,%r12
jmp .L2748
.L2749:
movq %r14,%rdi
call rt_drop_seq
movabsq $0,%rax
movq -.F2715-8(%rbp),%rbx
movq -.F2715-16(%rbp),%r12
movq -.F2715-24(%rbp),%r13
movq -.F2715-32(%rbp),%r14
movq -.F2715-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2715-8(%rbp),%rbx
movq -.F2715-16(%rbp),%r12
movq -.F2715-24(%rbp),%r13
movq -.F2715-32(%rbp),%r14
movq -.F2715-40(%rbp),%r15
leave
ret
.set .F2715,112
.type rt_push_char,@function
rt_push_char:
pushq %rbp
movq %rsp,%rbp
subq $.F2751,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq -16(%rbp),%rax
movq -8(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt207
call rt_pushb
jmp .Lopt208
.Lopt207:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt208:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F2751,16
.type rt_seq_cmp,@function
rt_seq_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2752,%rsp
subq $48,%rsp
movq %rbx,-.F2752-8(%rbp)
movq %r12,-.F2752-16(%rbp)
movq %r13,-.F2752-24(%rbp)
movq %r14,-.F2752-32(%rbp)
movq %r15,-.F2752-40(%rbp)
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
.L2753:
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
jz .L2754
movq -16(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt209
call rt_abort
.Lopt209:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt210
call rt_abort
.Lopt210:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r14
cmpq %r14,%r13
je .L2755
cmpq %r14,%r13
jae .L2757
movq $0,%r12
jmp .L2758
.L2757:
movq $2,%r12
.L2758:
jmp .L2754
jmp .L2756
.L2755:
.L2756:
movq %rbx,%rax
addq $1,%rax
jnc .L2759
call rt_abort
.L2759:
movq %rax,%rbx
jmp .L2753
.L2754:
cmpq $1,%r12
jne .L2760
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2762
movq $0,%r12
jmp .L2763
.L2762:
.L2763:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2764
movq $2,%r12
jmp .L2765
.L2764:
.L2765:
jmp .L2761
.L2760:
.L2761:
movq -8(%rbp),%rax
cmpq $258,%rax
jne .L2766
movq %r12,%rax
cmpq $1,%r12
sete %al
movzbq %al,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
jmp .L2767
.L2766:
.L2767:
movq -8(%rbp),%rax
cmpq $259,%rax
jne .L2768
movq %r12,%rax
cmpq $1,%r12
setne %al
movzbq %al,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
jmp .L2769
.L2768:
.L2769:
movq -8(%rbp),%rax
cmpq $60,%rax
jne .L2770
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
jmp .L2771
.L2770:
.L2771:
movq -8(%rbp),%rax
cmpq $62,%rax
jne .L2772
movq %r12,%rax
cmpq $2,%r12
sete %al
movzbq %al,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
jmp .L2773
.L2772:
.L2773:
movq -8(%rbp),%rax
cmpq $269,%rax
jne .L2774
movq %r12,%rax
cmpq $2,%r12
setne %al
movzbq %al,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
jmp .L2775
.L2774:
.L2775:
movabsq $270,%rcx
movq -8(%rbp),%rax
cmpq $270,%rax
jne .L2776
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
jmp .L2777
.L2776:
.L2777:
call rt_abort
movabsq $0,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2752-8(%rbp),%rbx
movq -.F2752-16(%rbp),%r12
movq -.F2752-24(%rbp),%r13
movq -.F2752-32(%rbp),%r14
movq -.F2752-40(%rbp),%r15
leave
ret
.set .F2752,48
.type rt_vec_cmp,@function
rt_vec_cmp:
pushq %rbp
movq %rsp,%rbp
subq $.F2778,%rsp
subq $48,%rsp
movq %rbx,-.F2778-8(%rbp)
movq %r12,-.F2778-16(%rbp)
movq %r13,-.F2778-24(%rbp)
movq %r14,-.F2778-32(%rbp)
movq %r15,-.F2778-40(%rbp)
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
.L2779:
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
jz .L2780
movq -16(%rbp),%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i96
call rt_abort
.Lopt36_i96:
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
jb .Lopt36_i97
call rt_abort
.Lopt36_i97:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i97
xorq %rax,%rax
jmp .Lret_i97
.Lret_i97:
movq %rax,%r14
cmpq %r14,%r13
je .L2781
cmpq %r14,%r13
jae .L2783
movq $0,%r12
jmp .L2784
.L2783:
movq $2,%r12
.L2784:
jmp .L2780
jmp .L2782
.L2781:
.L2782:
movq %rbx,%rax
addq $1,%rax
jnc .L2785
call rt_abort
.L2785:
movq %rax,%rbx
jmp .L2779
.L2780:
movabsq $1,%rcx
cmpq $1,%r12
jne .L2786
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L2788
movq $0,%r12
jmp .L2789
.L2788:
.L2789:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L2790
movq $2,%r12
jmp .L2791
.L2790:
.L2791:
jmp .L2787
.L2786:
.L2787:
movq -8(%rbp),%rdi
movq %r12,%rsi
call rt_order_result
movq -.F2778-8(%rbp),%rbx
movq -.F2778-16(%rbp),%r12
movq -.F2778-24(%rbp),%r13
movq -.F2778-32(%rbp),%r14
movq -.F2778-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2778-8(%rbp),%rbx
movq -.F2778-16(%rbp),%r12
movq -.F2778-24(%rbp),%r13
movq -.F2778-32(%rbp),%r14
movq -.F2778-40(%rbp),%r15
leave
ret
.set .F2778,48
.type rt_order_result,@function
rt_order_result:
pushq %rbp
movq %rsp,%rbp
subq $.F2792,%rsp
subq $16,%rsp
movq %rbx,-.F2792-8(%rbp)
movq %r12,-.F2792-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%rbx
movq %rsi,%r12
cmpq $258,%rbx
jne .L2793
movq %r12,%rax
cmpq $1,%r12
sete %al
movzbq %al,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
jmp .L2794
.L2793:
.L2794:
cmpq $259,%rbx
jne .L2795
movq %r12,%rax
cmpq $1,%r12
setne %al
movzbq %al,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
jmp .L2796
.L2795:
.L2796:
cmpq $60,%rbx
jne .L2797
movq %r12,%rax
cmpq $0,%r12
sete %al
movzbq %al,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
jmp .L2798
.L2797:
.L2798:
cmpq $62,%rbx
jne .L2799
movq %r12,%rax
cmpq $2,%r12
sete %al
movzbq %al,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
jmp .L2800
.L2799:
.L2800:
cmpq $269,%rbx
jne .L2801
movq %r12,%rax
cmpq $2,%r12
setne %al
movzbq %al,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
jmp .L2802
.L2801:
.L2802:
movabsq $270,%rcx
cmpq $270,%rbx
jne .L2803
movq %r12,%rax
cmpq $0,%r12
setne %al
movzbq %al,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
jmp .L2804
.L2803:
.L2804:
call rt_abort
movabsq $0,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2792-8(%rbp),%rbx
movq -.F2792-16(%rbp),%r12
leave
ret
.set .F2792,16
.type rt_concat,@function
rt_concat:
pushq %rbp
movq %rsp,%rbp
subq $.F2805,%rsp
subq $48,%rsp
movq %rbx,-.F2805-8(%rbp)
movq %r12,-.F2805-16(%rbp)
movq %r13,-.F2805-24(%rbp)
movq %r14,-.F2805-32(%rbp)
movq %r15,-.F2805-40(%rbp)
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
.L2806:
cmpq %r15,%rbx
jae .L2807
movq %r13,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt211
call rt_abort
.Lopt211:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
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
movq %rbx,%rax
addq $1,%rax
jnc .L2808
call rt_abort
.L2808:
movq %rax,%rbx
jmp .L2806
.L2807:
movq %r14,%rdi
movq 8(%rdi),%rax
movq %rax,-24(%rbp)
movq $0,%rbx
.L2809:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2810
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt214
call rt_abort
.Lopt214:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r12,%rdi
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
jnc .L2811
call rt_abort
.L2811:
movq %rax,%rbx
jmp .L2809
.L2810:
movq %r12,%rax
movq -.F2805-8(%rbp),%rbx
movq -.F2805-16(%rbp),%r12
movq -.F2805-24(%rbp),%r13
movq -.F2805-32(%rbp),%r14
movq -.F2805-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2805-8(%rbp),%rbx
movq -.F2805-16(%rbp),%r12
movq -.F2805-24(%rbp),%r13
movq -.F2805-32(%rbp),%r14
movq -.F2805-40(%rbp),%r15
leave
ret
.set .F2805,32
.type rt_concat_text,@function
rt_concat_text:
pushq %rbp
movq %rsp,%rbp
subq $.F2812,%rsp
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
.set .F2812,32
.type rt_seq_match,@function
rt_seq_match:
pushq %rbp
movq %rsp,%rbp
subq $.F2813,%rsp
subq $48,%rsp
movq %rbx,-.F2813-8(%rbp)
movq %r12,-.F2813-16(%rbp)
movq %r13,-.F2813-24(%rbp)
movq %r14,-.F2813-32(%rbp)
movq %r15,-.F2813-40(%rbp)
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
jnc .L2814
call rt_abort
.L2814:
movq %rax,%rcx
movq -40(%rbp),%rax
cmpq %rcx,%rax
jae .L2815
movabsq $0,%rax
movq -.F2813-8(%rbp),%rbx
movq -.F2813-16(%rbp),%r12
movq -.F2813-24(%rbp),%r13
movq -.F2813-32(%rbp),%r14
movq -.F2813-40(%rbp),%r15
leave
ret
jmp .L2816
.L2815:
.L2816:
movq $0,%rbx
.L2817:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2818
movq %r14,%rax
addq %rbx,%rax
jnc .L2819
call rt_abort
.L2819:
movq %r13,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt217
call rt_abort
.Lopt217:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq %r15,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt218
call rt_abort
.Lopt218:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rcx
cmpq %rcx,%r12
je .L2820
movabsq $0,%rax
movq -.F2813-8(%rbp),%rbx
movq -.F2813-16(%rbp),%r12
movq -.F2813-24(%rbp),%r13
movq -.F2813-32(%rbp),%r14
movq -.F2813-40(%rbp),%r15
leave
ret
jmp .L2821
.L2820:
.L2821:
movq %rbx,%rax
addq $1,%rax
jnc .L2822
call rt_abort
.L2822:
movq %rax,%rbx
jmp .L2817
.L2818:
movabsq $1,%rax
movq -.F2813-8(%rbp),%rbx
movq -.F2813-16(%rbp),%r12
movq -.F2813-24(%rbp),%r13
movq -.F2813-32(%rbp),%r14
movq -.F2813-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2813-8(%rbp),%rbx
movq -.F2813-16(%rbp),%r12
movq -.F2813-24(%rbp),%r13
movq -.F2813-32(%rbp),%r14
movq -.F2813-40(%rbp),%r15
leave
ret
.set .F2813,48
.type rt_seq_contains,@function
rt_seq_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F2823,%rsp
subq $48,%rsp
movq %rbx,-.F2823-8(%rbp)
movq %r12,-.F2823-16(%rbp)
movq %r13,-.F2823-24(%rbp)
movq %r14,-.F2823-32(%rbp)
movq %r15,-.F2823-40(%rbp)
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
jae .L2824
movabsq $0,%rax
movq -.F2823-8(%rbp),%rbx
movq -.F2823-16(%rbp),%r12
movq -.F2823-24(%rbp),%r13
movq -.F2823-32(%rbp),%r14
movq -.F2823-40(%rbp),%r15
leave
ret
jmp .L2825
.L2824:
.L2825:
movq $0,%rbx
.L2826:
movq %r15,%rax
movq -24(%rbp),%rcx
subq %rcx,%rax
jnc .L2828
call rt_abort
.L2828:
addq $1,%rax
jnc .L2829
call rt_abort
.L2829:
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L2827
movq %r13,%rdi
movq %rbx,%rsi
movq %r14,%rdx
call rt_seq_match
testq %rax,%rax
jz .L2830
movabsq $1,%rax
movq -.F2823-8(%rbp),%rbx
movq -.F2823-16(%rbp),%r12
movq -.F2823-24(%rbp),%r13
movq -.F2823-32(%rbp),%r14
movq -.F2823-40(%rbp),%r15
leave
ret
jmp .L2831
.L2830:
.L2831:
movq %rbx,%rax
addq $1,%rax
jnc .L2832
call rt_abort
.L2832:
movq %rax,%rbx
jmp .L2826
.L2827:
movabsq $0,%rax
movq -.F2823-8(%rbp),%rbx
movq -.F2823-16(%rbp),%r12
movq -.F2823-24(%rbp),%r13
movq -.F2823-32(%rbp),%r14
movq -.F2823-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2823-8(%rbp),%rbx
movq -.F2823-16(%rbp),%r12
movq -.F2823-24(%rbp),%r13
movq -.F2823-32(%rbp),%r14
movq -.F2823-40(%rbp),%r15
leave
ret
.set .F2823,32
.type rt_seq_starts,@function
rt_seq_starts:
pushq %rbp
movq %rsp,%rbp
subq $.F2833,%rsp
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
.set .F2833,16
.type rt_seq_ends,@function
rt_seq_ends:
pushq %rbp
movq %rsp,%rbp
subq $.F2834,%rsp
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
jae .L2835
movabsq $0,%rax
leave
ret
jmp .L2836
.L2835:
.L2836:
movq -24(%rbp),%rax
movq -32(%rbp),%rcx
subq %rcx,%rax
jnc .L2837
call rt_abort
.L2837:
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
.set .F2834,48
.type rt_case_map,@function
rt_case_map:
pushq %rbp
movq %rsp,%rbp
subq $.F2838,%rsp
subq $16,%rsp
movq %rbx,-.F2838-8(%rbp)
movq $0,%rbx
movq %rdi,%rbx
movq %rsi,-16(%rbp)
leaq -.F2838(%rbp),%rdi
movq $.F2838/8-2,%rcx
xorl %eax,%eax
rep stosq
movq -16(%rbp),%rax
testq %rax,%rax
jz .L2839
cmpq $940,%rbx
jne .L2841
movabsq $902,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2842
.L2841:
.L2842:
cmpq $941,%rbx
jne .L2843
movabsq $904,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2844
.L2843:
.L2844:
cmpq $942,%rbx
jne .L2845
movabsq $905,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2846
.L2845:
.L2846:
cmpq $943,%rbx
jne .L2847
movabsq $906,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2848
.L2847:
.L2848:
cmpq $972,%rbx
jne .L2849
movabsq $908,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2850
.L2849:
.L2850:
cmpq $973,%rbx
jne .L2851
movabsq $910,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2852
.L2851:
.L2852:
cmpq $974,%rbx
jne .L2853
movabsq $911,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2854
.L2853:
.L2854:
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
jz .L2855
movq %rbx,%rax
subq $32,%rax
jnc .L2857
call rt_abort
.L2857:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2856
.L2855:
.L2856:
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
jz .L2858
movq %rbx,%rax
subq $32,%rax
jnc .L2860
call rt_abort
.L2860:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2859
.L2858:
.L2859:
cmpq $255,%rbx
jne .L2861
movabsq $376,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2862
.L2861:
.L2862:
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
jz .L2863
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
jnc .L2865
call rt_abort
.L2865:
movq %rax,-72(%rbp)
movabsq $329,%rax
cmpq %rbx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L2866
call rt_abort
.L2866:
testq %rax,%rax
jz .L2867
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
jnc .L2869
call rt_abort
.L2869:
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
jz .L2870
movq %rbx,%rax
subq $1,%rax
jnc .L2872
call rt_abort
.L2872:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2871
.L2870:
.L2871:
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
jz .L2873
movq %rbx,%rax
subq $1,%rax
jnc .L2875
call rt_abort
.L2875:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2874
.L2873:
.L2874:
jmp .L2868
.L2867:
.L2868:
jmp .L2864
.L2863:
.L2864:
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
jz .L2876
movq %rbx,%rax
subq $32,%rax
jnc .L2878
call rt_abort
.L2878:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2877
.L2876:
.L2877:
cmpq $962,%rbx
jne .L2879
movabsq $931,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2880
.L2879:
.L2880:
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
jz .L2881
movq %rbx,%rax
subq $32,%rax
jnc .L2883
call rt_abort
.L2883:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2882
.L2881:
.L2882:
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
jz .L2884
movq %rbx,%rax
subq $80,%rax
jnc .L2886
call rt_abort
.L2886:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2885
.L2884:
.L2885:
movq %rbx,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2840
.L2839:
.L2840:
cmpq $902,%rbx
jne .L2887
movabsq $940,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2888
.L2887:
.L2888:
cmpq $904,%rbx
jne .L2889
movabsq $941,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2890
.L2889:
.L2890:
cmpq $905,%rbx
jne .L2891
movabsq $942,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2892
.L2891:
.L2892:
cmpq $906,%rbx
jne .L2893
movabsq $943,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2894
.L2893:
.L2894:
cmpq $908,%rbx
jne .L2895
movabsq $972,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2896
.L2895:
.L2896:
cmpq $910,%rbx
jne .L2897
movabsq $973,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2898
.L2897:
.L2898:
cmpq $911,%rbx
jne .L2899
movabsq $974,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2900
.L2899:
.L2900:
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
jz .L2901
movq %rbx,%rax
addq $32,%rax
jnc .L2903
call rt_abort
.L2903:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2902
.L2901:
.L2902:
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
jz .L2904
movq %rbx,%rax
addq $32,%rax
jnc .L2906
call rt_abort
.L2906:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2905
.L2904:
.L2905:
cmpq $376,%rbx
jne .L2907
movabsq $255,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2908
.L2907:
.L2908:
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
jz .L2909
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
jnc .L2911
call rt_abort
.L2911:
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
jz .L2912
movq %rbx,%rax
addq $1,%rax
jnc .L2914
call rt_abort
.L2914:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2913
.L2912:
.L2913:
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
jz .L2915
movq %rbx,%rax
addq $1,%rax
jnc .L2917
call rt_abort
.L2917:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2916
.L2915:
.L2916:
jmp .L2910
.L2909:
.L2910:
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
jz .L2918
movq %rbx,%rax
addq $32,%rax
jnc .L2920
call rt_abort
.L2920:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2919
.L2918:
.L2919:
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
jz .L2921
movq %rbx,%rax
addq $32,%rax
jnc .L2923
call rt_abort
.L2923:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2922
.L2921:
.L2922:
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
jz .L2924
movq %rbx,%rax
addq $80,%rax
jnc .L2926
call rt_abort
.L2926:
movq -.F2838-8(%rbp),%rbx
leave
ret
jmp .L2925
.L2924:
.L2925:
movq %rbx,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2838-8(%rbp),%rbx
leave
ret
.set .F2838,304
.type rt_push_utf8,@function
rt_push_utf8:
pushq %rbp
movq %rsp,%rbp
subq $.F2927,%rsp
subq $16,%rsp
movq %rbx,-.F2927-8(%rbp)
movq %r12,-.F2927-16(%rbp)
movq $0,%rbx
movq $0,%r12
movq %rdi,%r12
movq %rsi,%rbx
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
cmpq $128,%rbx
jae .L2928
movq %r12,%rdi
movq %rbx,%rsi
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
movabsq $0,%rax
movq -.F2927-8(%rbp),%rbx
movq -.F2927-16(%rbp),%r12
leave
ret
jmp .L2929
.L2928:
.L2929:
movabsq $2048,%rcx
cmpq $2048,%rbx
jae .L2930
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,%rcx
movabsq $192,%rax
addq %rcx,%rax
jnc .L2932
call rt_abort
.L2932:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt221
call rt_pushb
jmp .Lopt222
.Lopt221:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt222:
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2933:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2934
call rt_abort
.L2934:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt223
call rt_pushb
jmp .Lopt224
.Lopt223:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt224:
movabsq $0,%rax
movq -.F2927-8(%rbp),%rbx
movq -.F2927-16(%rbp),%r12
leave
ret
jmp .L2931
.L2930:
.L2931:
movabsq $65536,%rcx
cmpq $65536,%rbx
jae .L2935
movq %rbx,%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,%rcx
movabsq $224,%rax
addq %rcx,%rax
jnc .L2937
call rt_abort
.L2937:
movq %r12,%rdi
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
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,-24(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2938:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2939
call rt_abort
.L2939:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt227
call rt_pushb
jmp .Lopt228
.Lopt227:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt228:
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2940:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2941
call rt_abort
.L2941:
movq %r12,%rdi
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
movabsq $0,%rax
movq -.F2927-8(%rbp),%rbx
movq -.F2927-16(%rbp),%r12
leave
ret
jmp .L2936
.L2935:
.L2936:
movq %rbx,%rdi
movabsq $262144,%rsi
call rt_div
movq %rax,%rcx
movabsq $240,%rax
addq %rcx,%rax
jnc .L2942
call rt_abort
.L2942:
movq %r12,%rdi
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
movq %rbx,%rdi
movabsq $4096,%rsi
call rt_div
movq %rax,-32(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2943:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2944
call rt_abort
.L2944:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt233
call rt_pushb
jmp .Lopt234
.Lopt233:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt234:
movq %rbx,%rdi
movabsq $64,%rsi
call rt_div
movq %rax,-40(%rbp)
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2945:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2946
call rt_abort
.L2946:
movq %r12,%rdi
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
movq %rbx,%rax
movq %rax,%rdx
andq $63,%rdx
shrq $6,%rax
.L2947:
movabsq $128,%rax
addq %rdx,%rax
jnc .L2948
call rt_abort
.L2948:
movq %r12,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt237
call rt_pushb
jmp .Lopt238
.Lopt237:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt238:
movabsq $0,%rax
movq -.F2927-8(%rbp),%rbx
movq -.F2927-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F2927-8(%rbp),%rbx
movq -.F2927-16(%rbp),%r12
leave
ret
.set .F2927,48
.type rt_seq_case,@function
rt_seq_case:
pushq %rbp
movq %rsp,%rbp
subq $.F2949,%rsp
subq $48,%rsp
movq %rbx,-.F2949-8(%rbp)
movq %r12,-.F2949-16(%rbp)
movq %r13,-.F2949-24(%rbp)
movq %r14,-.F2949-32(%rbp)
movq %r15,-.F2949-40(%rbp)
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
.L2950:
movq -24(%rbp),%rcx
cmpq %rcx,%rbx
jae .L2951
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt239
call rt_abort
.Lopt239:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r12
movq %rax,-32(%rbp)
movabsq $128,%rcx
cmpq $128,%rax
jae .L2952
movq %r12,%rdi
movq %r15,%rsi
call rt_case_map
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt240
call rt_pushb
jmp .Lopt241
.Lopt240:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt241:
movq %rbx,%rax
addq $1,%rax
jnc .L2954
call rt_abort
.L2954:
movq %rax,%rbx
jmp .L2953
.L2952:
movq %r12,%rax
andq $224,%rax
movq %rax,-40(%rbp)
cmpq $192,%rax
sete %al
movzbq %al,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $1,%rax
jnc .L2955
call rt_abort
.L2955:
movq -24(%rbp),%rcx
cmpq %rcx,%rax
setb %al
movzbq %al,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
andq %rcx,%rax
testq %rax,%rax
jz .L2956
movq %rbx,%rax
addq $1,%rax
jnc .L2958
call rt_abort
.L2958:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt242
call rt_abort
.Lopt242:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,-56(%rbp)
movq %rax,-64(%rbp)
andq $192,%rax
movq %rax,-72(%rbp)
cmpq $128,%rax
jne .L2959
movq %r12,%rax
andq $31,%rax
movq %rax,-80(%rbp)
movabsq $64,%rcx
mulq %rcx
jnc .L2961
call rt_abort
.L2961:
movq %rax,-88(%rbp)
movq -56(%rbp),%rax
andq $63,%rax
movq %rax,%rcx
movq -88(%rbp),%rax
addq %rcx,%rax
jnc .L2962
call rt_abort
.L2962:
movq %rax,-96(%rbp)
movq -96(%rbp),%rdi
movq %r15,%rsi
call rt_case_map
movq %r13,%rdi
movq %rax,%rsi
call rt_push_utf8
movq %rbx,%rax
addq $2,%rax
jnc .L2963
call rt_abort
.L2963:
movq %rax,%rbx
jmp .L2960
.L2959:
movq %r13,%rdi
movq %r12,%rsi
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
movq %rbx,%rax
addq $1,%rax
jnc .L2964
call rt_abort
.L2964:
movq %rax,%rbx
.L2960:
jmp .L2957
.L2956:
movq %r13,%rdi
movq %r12,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt245
call rt_pushb
jmp .Lopt246
.Lopt245:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt246:
movq %rbx,%rax
addq $1,%rax
jnc .L2965
call rt_abort
.L2965:
movq %rax,%rbx
.L2957:
.L2953:
jmp .L2950
.L2951:
movq %r13,%rax
movq -.F2949-8(%rbp),%rbx
movq -.F2949-16(%rbp),%r12
movq -.F2949-24(%rbp),%r13
movq -.F2949-32(%rbp),%r14
movq -.F2949-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2949-8(%rbp),%rbx
movq -.F2949-16(%rbp),%r12
movq -.F2949-24(%rbp),%r13
movq -.F2949-32(%rbp),%r14
movq -.F2949-40(%rbp),%r15
leave
ret
.set .F2949,96
.type rt_seq_upper,@function
rt_seq_upper:
pushq %rbp
movq %rsp,%rbp
subq $.F2966,%rsp
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
.set .F2966,16
.type rt_seq_lower,@function
rt_seq_lower:
pushq %rbp
movq %rsp,%rbp
subq $.F2967,%rsp
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
.set .F2967,16
.type rt_space,@function
rt_space:
pushq %rbp
movq %rsp,%rbp
subq $.F2968,%rsp
subq $16,%rsp
movq %rbx,-.F2968-8(%rbp)
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
jnc .L2969
call rt_abort
.L2969:
movq %rax,-24(%rbp)
movq %rbx,%rax
cmpq $10,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L2970
call rt_abort
.L2970:
movq %rax,-32(%rbp)
movq %rbx,%rax
cmpq $13,%rbx
sete %al
movzbq %al,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L2971
call rt_abort
.L2971:
movq -.F2968-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F2968-8(%rbp),%rbx
leave
ret
.set .F2968,32
.type rt_seq_trim,@function
rt_seq_trim:
pushq %rbp
movq %rsp,%rbp
subq $.F2972,%rsp
subq $48,%rsp
movq %rbx,-.F2972-8(%rbp)
movq %r12,-.F2972-16(%rbp)
movq %r13,-.F2972-24(%rbp)
movq %r14,-.F2972-32(%rbp)
movq %r15,-.F2972-40(%rbp)
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
.L2973:
movq %rbx,%rcx
cmpq %rbx,%r12
jae .L2974
movq %r14,%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt247
call rt_abort
.Lopt247:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rdi
call rt_space
cmpq $0,%rax
jne .L2975
jmp .L2974
jmp .L2976
.L2975:
.L2976:
movq %r12,%rax
addq $1,%rax
jnc .L2977
call rt_abort
.L2977:
movq %rax,%r12
jmp .L2973
.L2974:
.L2978:
movq %rbx,%rcx
cmpq %rbx,%r12
jae .L2979
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L2980
call rt_abort
.L2980:
movq %r14,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt248
call rt_abort
.Lopt248:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%rdi
call rt_space
movq %rax,-16(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L2981
jmp .L2979
jmp .L2982
.L2981:
.L2982:
movq %rbx,%rax
subq $1,%rax
jnc .L2983
call rt_abort
.L2983:
movq %rax,%rbx
jmp .L2978
.L2979:
call rt_new
movq %rax,-24(%rbp)
movq %r12,%r13
.L2984:
cmpq %rbx,%r13
jae .L2985
movq %r14,%rdi
movq %r13,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt249
call rt_abort
.Lopt249:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq -24(%rbp),%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt250
call rt_pushb
jmp .Lopt251
.Lopt250:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt251:
movq %r13,%rax
addq $1,%rax
jnc .L2986
call rt_abort
.L2986:
movq %rax,%r13
jmp .L2984
.L2985:
movq -24(%rbp),%rax
movq -.F2972-8(%rbp),%rbx
movq -.F2972-16(%rbp),%r12
movq -.F2972-24(%rbp),%r13
movq -.F2972-32(%rbp),%r14
movq -.F2972-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2972-8(%rbp),%rbx
movq -.F2972-16(%rbp),%r12
movq -.F2972-24(%rbp),%r13
movq -.F2972-32(%rbp),%r14
movq -.F2972-40(%rbp),%r15
leave
ret
.set .F2972,32
.type rt_seq_replace,@function
rt_seq_replace:
pushq %rbp
movq %rsp,%rbp
subq $.F2987,%rsp
subq $48,%rsp
movq %rbx,-.F2987-8(%rbp)
movq %r12,-.F2987-16(%rbp)
movq %r13,-.F2987-24(%rbp)
movq %r14,-.F2987-32(%rbp)
movq %r15,-.F2987-40(%rbp)
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
.L2988:
movq -40(%rbp),%rcx
cmpq %rcx,%r12
jae .L2989
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
jz .L2990
movq $0,%rbx
.L2992:
cmpq %r15,%rbx
jae .L2993
movq %r14,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt252
call rt_abort
.Lopt252:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt253
call rt_pushb
jmp .Lopt254
.Lopt253:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt254:
movq %rbx,%rax
addq $1,%rax
jnc .L2994
call rt_abort
.L2994:
movq %rax,%rbx
jmp .L2992
.L2993:
movq %r12,%rax
movq -48(%rbp),%rcx
addq %rcx,%rax
jnc .L2995
call rt_abort
.L2995:
movq %rax,%r12
jmp .L2991
.L2990:
movq -8(%rbp),%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt255
call rt_abort
.Lopt255:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt256
call rt_pushb
jmp .Lopt257
.Lopt256:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt257:
movq %r12,%rax
addq $1,%rax
jnc .L2996
call rt_abort
.L2996:
movq %rax,%r12
.L2991:
jmp .L2988
.L2989:
movq -32(%rbp),%rax
testq %rax,%rax
jz .L2997
movq %r13,%rdi
call rt_utf8
jmp .L2998
.L2997:
.L2998:
movq %r13,%rax
movq -.F2987-8(%rbp),%rbx
movq -.F2987-16(%rbp),%r12
movq -.F2987-24(%rbp),%r13
movq -.F2987-32(%rbp),%r14
movq -.F2987-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2987-8(%rbp),%rbx
movq -.F2987-16(%rbp),%r12
movq -.F2987-24(%rbp),%r13
movq -.F2987-32(%rbp),%r14
movq -.F2987-40(%rbp),%r15
leave
ret
.set .F2987,64
.type rt_seq_repeat,@function
rt_seq_repeat:
pushq %rbp
movq %rsp,%rbp
subq $.F2999,%rsp
subq $48,%rsp
movq %rbx,-.F2999-8(%rbp)
movq %r12,-.F2999-16(%rbp)
movq %r13,-.F2999-24(%rbp)
movq %r14,-.F2999-32(%rbp)
movq %r15,-.F2999-40(%rbp)
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
.L3000:
movq -16(%rbp),%rcx
cmpq %rcx,%r15
jae .L3001
movq $0,%rbx
.L3002:
cmpq %r14,%rbx
jae .L3003
movq %r12,%rdi
movq %rbx,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt258
call rt_abort
.Lopt258:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %r13,%rdi
movq %rax,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt259
call rt_pushb
jmp .Lopt260
.Lopt259:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt260:
movq %rbx,%rax
addq $1,%rax
jnc .L3004
call rt_abort
.L3004:
movq %rax,%rbx
jmp .L3002
.L3003:
movq %r15,%rax
addq $1,%rax
jnc .L3005
call rt_abort
.L3005:
movq %rax,%r15
jmp .L3000
.L3001:
movq %r13,%rax
movq -.F2999-8(%rbp),%rbx
movq -.F2999-16(%rbp),%r12
movq -.F2999-24(%rbp),%r13
movq -.F2999-32(%rbp),%r14
movq -.F2999-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F2999-8(%rbp),%rbx
movq -.F2999-16(%rbp),%r12
movq -.F2999-24(%rbp),%r13
movq -.F2999-32(%rbp),%r14
movq -.F2999-40(%rbp),%r15
leave
ret
.set .F2999,16
.type rt_seq_split,@function
rt_seq_split:
pushq %rbp
movq %rsp,%rbp
subq $.F3006,%rsp
subq $48,%rsp
movq %rbx,-.F3006-8(%rbp)
movq %r12,-.F3006-16(%rbp)
movq %r13,-.F3006-24(%rbp)
movq %r14,-.F3006-32(%rbp)
movq %r15,-.F3006-40(%rbp)
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
.L3007:
movq -32(%rbp),%rcx
cmpq %rcx,%r12
jae .L3008
movq %r15,%rdi
movq %r12,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt261
call rt_abort
.Lopt261:
movq (%rdi),%rax
movzbq (%rax,%rsi,1),%rax
movq %rax,%r13
movq -16(%rbp),%rcx
cmpq %rcx,%rax
jne .L3009
movq -24(%rbp),%rax
testq %rax,%rax
jz .L3011
movq %rbx,%rdi
call rt_utf8
jmp .L3012
.L3011:
.L3012:
movq %r14,%rdi
movq %rbx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt262
call rt_push
jmp .Lopt263
.Lopt262:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt263:
call rt_new
movq %rax,%rbx
jmp .L3010
.L3009:
movq %rbx,%rdi
movq %r13,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt264
call rt_pushb
jmp .Lopt265
.Lopt264:
leaq 1(%rcx),%rdx
movq %rdx,8(%rdi)
addq (%rdi),%rcx
movq %rsi,%rax
movb %al,(%rcx)
movq $0,%rax
.Lopt265:
.L3010:
movq %r12,%rax
addq $1,%rax
jnc .L3013
call rt_abort
.L3013:
movq %rax,%r12
jmp .L3007
.L3008:
movq -24(%rbp),%rax
testq %rax,%rax
jz .L3014
movq %rbx,%rdi
call rt_utf8
jmp .L3015
.L3014:
.L3015:
movq %r14,%rdi
movq %rbx,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt266
call rt_push
jmp .Lopt267
.Lopt266:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt267:
movq %r14,%rax
movq -.F3006-8(%rbp),%rbx
movq -.F3006-16(%rbp),%r12
movq -.F3006-24(%rbp),%r13
movq -.F3006-32(%rbp),%r14
movq -.F3006-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F3006-8(%rbp),%rbx
movq -.F3006-16(%rbp),%r12
movq -.F3006-24(%rbp),%r13
movq -.F3006-32(%rbp),%r14
movq -.F3006-40(%rbp),%r15
leave
ret
.set .F3006,32
.type rt_load32,@function
rt_load32:
pushq %rbp
movq %rsp,%rbp
subq $.F3016,%rsp
subq $16,%rsp
movq %rbx,-.F3016-8(%rbp)
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
jnc .L3017
call rt_abort
.L3017:
movzbq (%rax),%rax
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $8,%rax
jnc .L3018
call rt_abort
.L3018:
movabsq $8,%rcx
movq -24(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -16(%rbp),%rax
orq %rcx,%rax
movq %rax,-32(%rbp)
movq %rbx,%rax
addq $2,%rax
jnc .L3019
call rt_abort
.L3019:
movzbq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $16,%rax
jnc .L3020
call rt_abort
.L3020:
movabsq $16,%rcx
movq -40(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -32(%rbp),%rax
orq %rcx,%rax
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $3,%rax
jnc .L3021
call rt_abort
.L3021:
movzbq (%rax),%rax
movq %rax,-56(%rbp)
movabsq $63,%rax
cmpq $24,%rax
jnc .L3022
call rt_abort
.L3022:
movabsq $24,%rcx
movq -56(%rbp),%rax
shlq %cl,%rax
movq %rax,%rcx
movq -48(%rbp),%rax
orq %rcx,%rax
movq -.F3016-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F3016-8(%rbp),%rbx
leave
ret
.set .F3016,64
.type rt_store32,@function
rt_store32:
pushq %rbp
movq %rsp,%rbp
subq $.F3023,%rsp
subq $16,%rsp
movq %rbx,-.F3023-8(%rbp)
movq %r12,-.F3023-16(%rbp)
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
jnc .L3024
call rt_abort
.L3024:
movq %rax,-24(%rbp)
movabsq $63,%rax
cmpq $8,%rax
jnc .L3025
call rt_abort
.L3025:
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
jnc .L3026
call rt_abort
.L3026:
movq %rax,-40(%rbp)
movabsq $63,%rax
cmpq $16,%rax
jnc .L3027
call rt_abort
.L3027:
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
jnc .L3028
call rt_abort
.L3028:
movq %rax,-56(%rbp)
movabsq $63,%rax
cmpq $24,%rax
jnc .L3029
call rt_abort
.L3029:
movabsq $24,%rcx
movq %r12,%rax
shrq %cl,%rax
movq %rax,-64(%rbp)
andq $255,%rax
movq -56(%rbp),%rcx
movb %al,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F3023-8(%rbp),%rbx
movq -.F3023-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F3023-8(%rbp),%rbx
movq -.F3023-16(%rbp),%r12
leave
ret
.set .F3023,64
.type rt_push4,@function
rt_push4:
pushq %rbp
movq %rsp,%rbp
subq $.F3030,%rsp
subq $32,%rsp
movq %rbx,-.F3030-8(%rbp)
movq %r12,-.F3030-16(%rbp)
movq %r13,-.F3030-24(%rbp)
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
jnc .L3031
call rt_abort
.L3031:
movq (%rax),%rax
movq %rax,%r12
movq %rbx,%rax
addq $16,%rax
jnc .L3032
call rt_abort
.L3032:
movq (%rax),%rax
movq %rax,-24(%rbp)
movq -24(%rbp),%rcx
cmpq %rcx,%r12
jne .L3033
movabsq $2,%rcx
movq -24(%rbp),%rax
mulq %rcx
jnc .L3035
call rt_abort
.L3035:
movq %rax,%r13
movq %rax,-32(%rbp)
cmpq $0,%rax
jne .L3036
movq $8,%r13
jmp .L3037
.L3036:
.L3037:
movq %r13,%rcx
movabsq $288230376151711744,%rax
cmpq %r13,%rax
jae .L3038
call rt_abort
jmp .L3039
.L3038:
.L3039:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-40(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L3040
call rt_abort
.L3040:
movq %rax,-48(%rbp)
movabsq $4,%rcx
movq %r13,%rax
mulq %rcx
jnc .L3041
call rt_abort
.L3041:
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
jnc .L3042
call rt_abort
.L3042:
movq %rax,-64(%rbp)
movq %r13,%rax
movq -64(%rbp),%rcx
movq %r13,(%rcx)
xorq %r13,%rax
jmp .L3034
.L3033:
.L3034:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-72(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L3043
call rt_abort
.L3043:
movq %rax,%rcx
movq -72(%rbp),%rax
addq %rcx,%rax
jnc .L3044
call rt_abort
.L3044:
movq %rax,-80(%rbp)
movq -16(%rbp),%rax
movq -80(%rbp),%rdi
movq %rax,%rsi
call rt_store32
movq %rbx,%rax
addq $8,%rax
jnc .L3045
call rt_abort
.L3045:
movq %rax,-88(%rbp)
movq %r12,%rax
addq $1,%rax
jnc .L3046
call rt_abort
.L3046:
movq -88(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movabsq $0,%rax
movq -.F3030-8(%rbp),%rbx
movq -.F3030-16(%rbp),%r12
movq -.F3030-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3030-8(%rbp),%rbx
movq -.F3030-16(%rbp),%r12
movq -.F3030-24(%rbp),%r13
leave
ret
.set .F3030,96
.type rt_fill4,@function
rt_fill4:
pushq %rbp
movq %rsp,%rbp
subq $.F3047,%rsp
subq $48,%rsp
movq %rbx,-.F3047-8(%rbp)
movq %r12,-.F3047-16(%rbp)
movq %r13,-.F3047-24(%rbp)
movq %r14,-.F3047-32(%rbp)
movq %r15,-.F3047-40(%rbp)
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
jae .L3048
call rt_abort
jmp .L3049
.L3048:
.L3049:
cmpq $0,%r12
je .L3050
movq %r13,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq %r12,%rax
mulq %rcx
jnc .L3052
call rt_abort
.L3052:
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
jnc .L3053
call rt_abort
.L3053:
movq %rax,-48(%rbp)
movq %r12,%rax
movq -48(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
jmp .L3051
.L3050:
.L3051:
movq $0,%rbx
.L3054:
cmpq %r12,%rbx
jae .L3055
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r14
movabsq $4,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L3056
call rt_abort
.L3056:
movq %rax,%rcx
movq %r14,%rax
addq %rcx,%rax
jnc .L3057
call rt_abort
.L3057:
movq %rax,%r15
movq -16(%rbp),%rax
movq %r15,%rdi
movq %rax,%rsi
call rt_store32
movq %rbx,%rax
addq $1,%rax
jnc .L3058
call rt_abort
.L3058:
movq %rax,%rbx
jmp .L3054
.L3055:
movq %r13,%rax
addq $8,%rax
jnc .L3059
call rt_abort
.L3059:
movq %rax,-56(%rbp)
movq %r12,%rax
movq -56(%rbp),%rcx
movq %r12,(%rcx)
xorq %r12,%rax
movabsq $0,%rax
movq -.F3047-8(%rbp),%rbx
movq -.F3047-16(%rbp),%r12
movq -.F3047-24(%rbp),%r13
movq -.F3047-32(%rbp),%r14
movq -.F3047-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F3047-8(%rbp),%rbx
movq -.F3047-16(%rbp),%r12
movq -.F3047-24(%rbp),%r13
movq -.F3047-32(%rbp),%r14
movq -.F3047-40(%rbp),%r15
leave
ret
.set .F3047,64
.type rt_slot4u,@function
rt_slot4u:
pushq %rbp
movq %rsp,%rbp
subq $.F3060,%rsp
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
jnc .L3061
call rt_abort
.L3061:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L3062
call rt_abort
.L3062:
leave
ret
xorq %rax,%rax
leave
ret
.set .F3060,32
.type rt_slot4,@function
rt_slot4:
pushq %rbp
movq %rsp,%rbp
subq $.F3063,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movq -8(%rbp),%rax
addq $8,%rax
jnc .L3064
call rt_abort
.L3064:
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
jne .L3065
call rt_abort
jmp .L3066
.L3065:
.L3066:
movq -8(%rbp),%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movabsq $4,%rcx
movq -16(%rbp),%rax
mulq %rcx
jnc .L3067
call rt_abort
.L3067:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L3068
call rt_abort
.L3068:
leave
ret
xorq %rax,%rax
leave
ret
.set .F3063,32
.type rt_at4u,@function
rt_at4u:
pushq %rbp
movq %rsp,%rbp
subq $.F3069,%rsp
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
jnc .L3070
call rt_abort
.L3070:
movq %rax,%rcx
movq -24(%rbp),%rax
addq %rcx,%rax
jnc .L3071
call rt_abort
.L3071:
movq %rax,%rdi
call rt_load32
leave
ret
xorq %rax,%rax
leave
ret
.set .F3069,32
.type rt_at4,@function
rt_at4:
pushq %rbp
movq %rsp,%rbp
subq $.F3072,%rsp
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
.set .F3072,16
.type rt_set4,@function
rt_set4:
pushq %rbp
movq %rsp,%rbp
subq $.F3073,%rsp
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
jnc .L3074
call rt_abort
.L3074:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L3075
call rt_abort
.L3075:
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
.set .F3073,48
.type rt_pop4,@function
rt_pop4:
pushq %rbp
movq %rsp,%rbp
subq $.F3076,%rsp
subq $16,%rsp
movq %rbx,-.F3076-8(%rbp)
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
jnc .L3077
call rt_abort
.L3077:
movq (%rax),%rax
movq %rax,-16(%rbp)
movq %rax,-24(%rbp)
movabsq $0,%rcx
cmpq $0,%rax
jne .L3078
call rt_abort
jmp .L3079
.L3078:
.L3079:
movq %rbx,%rax
movq (%rax),%rax
movq %rax,-32(%rbp)
movq -16(%rbp),%rax
subq $1,%rax
jnc .L3080
call rt_abort
.L3080:
movq %rax,-40(%rbp)
movabsq $4,%rcx
mulq %rcx
jnc .L3081
call rt_abort
.L3081:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L3082
call rt_abort
.L3082:
movq %rax,%rdi
call rt_load32
movq %rax,-48(%rbp)
movq %rbx,%rax
addq $8,%rax
jnc .L3083
call rt_abort
.L3083:
movq %rax,-56(%rbp)
movq -16(%rbp),%rax
subq $1,%rax
jnc .L3084
call rt_abort
.L3084:
movq -56(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
movq -48(%rbp),%rax
movq -.F3076-8(%rbp),%rbx
leave
ret
xorq %rax,%rax
movq -.F3076-8(%rbp),%rbx
leave
ret
.set .F3076,64
.type rt_vec_copy4,@function
rt_vec_copy4:
pushq %rbp
movq %rsp,%rbp
subq $.F3085,%rsp
subq $48,%rsp
movq %rbx,-.F3085-8(%rbp)
movq %r12,-.F3085-16(%rbp)
movq %r13,-.F3085-24(%rbp)
movq %r14,-.F3085-32(%rbp)
movq %r15,-.F3085-40(%rbp)
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
jnc .L3086
call rt_abort
.L3086:
movq (%rax),%rax
movq %rax,%r15
movq $0,%rbx
.L3087:
cmpq %r15,%rbx
jae .L3088
movq %r13,%rax
movq (%rax),%rax
movq %rax,%r12
movabsq $4,%rcx
movq %rbx,%rax
mulq %rcx
jnc .L3089
call rt_abort
.L3089:
movq %rax,%rcx
movq %r12,%rax
addq %rcx,%rax
jnc .L3090
call rt_abort
.L3090:
movq %rax,%rdi
call rt_load32
movq %r14,%rdi
movq %rax,%rsi
call rt_push4
movq %rbx,%rax
addq $1,%rax
jnc .L3091
call rt_abort
.L3091:
movq %rax,%rbx
jmp .L3087
.L3088:
movq %r14,%rax
movq -.F3085-8(%rbp),%rbx
movq -.F3085-16(%rbp),%r12
movq -.F3085-24(%rbp),%r13
movq -.F3085-32(%rbp),%r14
movq -.F3085-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F3085-8(%rbp),%rbx
movq -.F3085-16(%rbp),%r12
movq -.F3085-24(%rbp),%r13
movq -.F3085-32(%rbp),%r14
movq -.F3085-40(%rbp),%r15
leave
ret
.set .F3085,16
.type rt_vec_insert4,@function
rt_vec_insert4:
pushq %rbp
movq %rsp,%rbp
subq $.F3092,%rsp
subq $32,%rsp
movq %rbx,-.F3092-8(%rbp)
movq %r12,-.F3092-16(%rbp)
movq %r13,-.F3092-24(%rbp)
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
jae .L3093
call rt_abort
jmp .L3094
.L3093:
.L3094:
movq %r12,%rdi
movabsq $0,%rsi
call rt_push4
movq -32(%rbp),%rax
movq %rax,%rbx
.L3095:
movq %rbx,%rcx
cmpq %rbx,%r13
jae .L3096
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L3097
call rt_abort
.L3097:
movq %r12,%rdi
movq %rax,%rsi
call rt_at4
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_set4
movq %rbx,%rax
subq $1,%rax
jnc .L3098
call rt_abort
.L3098:
movq %rax,%rbx
jmp .L3095
.L3096:
movq -24(%rbp),%rax
movq %r12,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_set4
movabsq $0,%rax
movq -.F3092-8(%rbp),%rbx
movq -.F3092-16(%rbp),%r12
movq -.F3092-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3092-8(%rbp),%rbx
movq -.F3092-16(%rbp),%r12
movq -.F3092-24(%rbp),%r13
leave
ret
.set .F3092,32
.type rt_vec_remove4,@function
rt_vec_remove4:
pushq %rbp
movq %rsp,%rbp
subq $.F3099,%rsp
subq $32,%rsp
movq %rbx,-.F3099-8(%rbp)
movq %r12,-.F3099-16(%rbp)
movq %r13,-.F3099-24(%rbp)
movq %r14,-.F3099-32(%rbp)
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
jne .L3100
call rt_abort
jmp .L3101
.L3100:
.L3101:
movq %r12,%rdi
movq %r14,%rsi
call rt_at4
movq %rax,-32(%rbp)
movq %r14,%rbx
.L3102:
movq %rbx,%rax
addq $1,%rax
jnc .L3104
call rt_abort
.L3104:
movq %r13,%rcx
cmpq %r13,%rax
jae .L3103
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L3105
call rt_abort
.L3105:
movq %r12,%rdi
movq %rax,%rsi
call rt_at4
movq %r12,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_set4
movq %rbx,%rax
addq $1,%rax
jnc .L3106
call rt_abort
.L3106:
movq %rax,%rbx
jmp .L3102
.L3103:
movq %r12,%rdi
call rt_pop4
movq -32(%rbp),%rax
movq -.F3099-8(%rbp),%rbx
movq -.F3099-16(%rbp),%r12
movq -.F3099-24(%rbp),%r13
movq -.F3099-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F3099-8(%rbp),%rbx
movq -.F3099-16(%rbp),%r12
movq -.F3099-24(%rbp),%r13
movq -.F3099-32(%rbp),%r14
leave
ret
.set .F3099,32
.type rt_vec_swap4,@function
rt_vec_swap4:
pushq %rbp
movq %rsp,%rbp
subq $.F3107,%rsp
subq $32,%rsp
movq %rbx,-.F3107-8(%rbp)
movq %r12,-.F3107-16(%rbp)
movq %r13,-.F3107-24(%rbp)
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
jnc .L3108
call rt_abort
.L3108:
testq %rax,%rax
jz .L3109
call rt_abort
jmp .L3110
.L3109:
.L3110:
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
movq -.F3107-8(%rbp),%rbx
movq -.F3107-16(%rbp),%r12
movq -.F3107-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3107-8(%rbp),%rbx
movq -.F3107-16(%rbp),%r12
movq -.F3107-24(%rbp),%r13
leave
ret
.set .F3107,64
.type rt_vec_reverse4,@function
rt_vec_reverse4:
pushq %rbp
movq %rsp,%rbp
subq $.F3111,%rsp
subq $32,%rsp
movq %rbx,-.F3111-8(%rbp)
movq %r12,-.F3111-16(%rbp)
movq %r13,-.F3111-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
movq $0,%rbx
.L3112:
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L3113
movq %r12,%rax
subq $1,%rax
jnc .L3114
call rt_abort
.L3114:
movq %rbx,%rcx
subq %rbx,%rax
jnc .L3115
call rt_abort
.L3115:
movq %r13,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_swap4
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L3116
call rt_abort
.L3116:
movq %rax,%rbx
jmp .L3112
.L3113:
movabsq $0,%rax
movq -.F3111-8(%rbp),%rbx
movq -.F3111-16(%rbp),%r12
movq -.F3111-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3111-8(%rbp),%rbx
movq -.F3111-16(%rbp),%r12
movq -.F3111-24(%rbp),%r13
leave
ret
.set .F3111,16
.type rt_vec_truncate4,@function
rt_vec_truncate4:
pushq %rbp
movq %rsp,%rbp
subq $.F3117,%rsp
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
jae .L3118
movq -8(%rbp),%rax
addq $8,%rax
jnc .L3120
call rt_abort
.L3120:
movq %rax,-24(%rbp)
movq -16(%rbp),%rax
movq -24(%rbp),%rcx
movq %rax,(%rcx)
xorq %rax,%rax
jmp .L3119
.L3118:
.L3119:
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F3117,32
.type rt_vec_contains4,@function
rt_vec_contains4:
pushq %rbp
movq %rsp,%rbp
subq $.F3121,%rsp
subq $32,%rsp
movq %rbx,-.F3121-8(%rbp)
movq %r12,-.F3121-16(%rbp)
movq %r13,-.F3121-24(%rbp)
movq %r14,-.F3121-32(%rbp)
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
.L3122:
movq %r13,%rcx
cmpq %r13,%rbx
jae .L3123
movq %r12,%rdi
movq %rbx,%rsi
call rt_at4
cmpq %r14,%rax
jne .L3124
movabsq $1,%rax
movq -.F3121-8(%rbp),%rbx
movq -.F3121-16(%rbp),%r12
movq -.F3121-24(%rbp),%r13
movq -.F3121-32(%rbp),%r14
leave
ret
jmp .L3125
.L3124:
.L3125:
movq %rbx,%rax
addq $1,%rax
jnc .L3126
call rt_abort
.L3126:
movq %rax,%rbx
jmp .L3122
.L3123:
movabsq $0,%rax
movq -.F3121-8(%rbp),%rbx
movq -.F3121-16(%rbp),%r12
movq -.F3121-24(%rbp),%r13
movq -.F3121-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F3121-8(%rbp),%rbx
movq -.F3121-16(%rbp),%r12
movq -.F3121-24(%rbp),%r13
movq -.F3121-32(%rbp),%r14
leave
ret
.set .F3121,16
.type rt_narrow_decode,@function
rt_narrow_decode:
pushq %rbp
movq %rsp,%rbp
subq $.F3127,%rsp
subq $16,%rsp
movq %rbx,-.F3127-8(%rbp)
movq %r12,-.F3127-16(%rbp)
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
jne .L3128
movq %rbx,%rdi
call rt_f32_from_bits
movq -.F3127-8(%rbp),%rbx
movq -.F3127-16(%rbp),%r12
leave
ret
jmp .L3129
.L3128:
.L3129:
movabsq $1023,%rax
cmpq %r12,%rax
setb %al
movzbq %al,%rax
movq %rax,-24(%rbp)
movq %r12,%rax
subq $1024,%rax
jnc .L3130
call rt_abort
.L3130:
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
jz .L3131
movabsq $2147483648,%rcx
movq %rbx,%rax
andq %rcx,%rax
movq %rax,-48(%rbp)
cmpq $0,%rax
je .L3133
movabsq $18446744069414584320,%rcx
movq %rbx,%rax
orq %rcx,%rax
movq -.F3127-8(%rbp),%rbx
movq -.F3127-16(%rbp),%r12
leave
ret
jmp .L3134
.L3133:
.L3134:
jmp .L3132
.L3131:
.L3132:
movq %rbx,%rax
movq -.F3127-8(%rbp),%rbx
movq -.F3127-16(%rbp),%r12
leave
ret
xorq %rax,%rax
movq -.F3127-8(%rbp),%rbx
movq -.F3127-16(%rbp),%r12
leave
ret
.set .F3127,48
.type rt_vec_feq,@function
rt_vec_feq:
pushq %rbp
movq %rsp,%rbp
subq $.F3135,%rsp
subq $48,%rsp
movq %rbx,-.F3135-8(%rbp)
movq %r12,-.F3135-16(%rbp)
movq %r13,-.F3135-24(%rbp)
movq %r14,-.F3135-32(%rbp)
movq %r15,-.F3135-40(%rbp)
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
je .L3136
movabsq $0,%rax
movq -.F3135-8(%rbp),%rbx
movq -.F3135-16(%rbp),%r12
movq -.F3135-24(%rbp),%r13
movq -.F3135-32(%rbp),%r14
movq -.F3135-40(%rbp),%r15
leave
ret
jmp .L3137
.L3136:
.L3137:
movq $0,%rbx
.L3138:
movq -32(%rbp),%rcx
cmpq %rcx,%rbx
jae .L3139
movq -24(%rbp),%rax
testq %rax,%rax
jz .L3140
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
jmp .L3141
.L3140:
movq %r14,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i98
call rt_abort
.Lopt36_i98:
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
jb .Lopt36_i99
call rt_abort
.Lopt36_i99:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i99
xorq %rax,%rax
jmp .Lret_i99
.Lret_i99:
movq %rax,%r13
.L3141:
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
jne .L3142
movabsq $0,%rax
movq -.F3135-8(%rbp),%rbx
movq -.F3135-16(%rbp),%r12
movq -.F3135-24(%rbp),%r13
movq -.F3135-32(%rbp),%r14
movq -.F3135-40(%rbp),%r15
leave
ret
jmp .L3143
.L3142:
.L3143:
movq %rbx,%rax
addq $1,%rax
jnc .L3144
call rt_abort
.L3144:
movq %rax,%rbx
jmp .L3138
.L3139:
movabsq $1,%rax
movq -.F3135-8(%rbp),%rbx
movq -.F3135-16(%rbp),%r12
movq -.F3135-24(%rbp),%r13
movq -.F3135-32(%rbp),%r14
movq -.F3135-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F3135-8(%rbp),%rbx
movq -.F3135-16(%rbp),%r12
movq -.F3135-24(%rbp),%r13
movq -.F3135-32(%rbp),%r14
movq -.F3135-40(%rbp),%r15
leave
ret
.set .F3135,48
.type rt_vec_cmp4,@function
rt_vec_cmp4:
pushq %rbp
movq %rsp,%rbp
subq $.F3145,%rsp
subq $48,%rsp
movq %rbx,-.F3145-8(%rbp)
movq %r12,-.F3145-16(%rbp)
movq %r13,-.F3145-24(%rbp)
movq %r14,-.F3145-32(%rbp)
movq %r15,-.F3145-40(%rbp)
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
.L3146:
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
jz .L3147
movq -16(%rbp),%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%r13
movq -24(%rbp),%rdi
movq %rbx,%rsi
call rt_at4
movq %rax,%r14
cmpq %r14,%r13
je .L3148
cmpq %r14,%r13
jae .L3150
movq $0,%r12
jmp .L3151
.L3150:
movq $2,%r12
.L3151:
jmp .L3147
jmp .L3149
.L3148:
.L3149:
movq %rbx,%rax
addq $1,%rax
jnc .L3152
call rt_abort
.L3152:
movq %rax,%rbx
jmp .L3146
.L3147:
movabsq $1,%rcx
cmpq $1,%r12
jne .L3153
movq -32(%rbp),%rax
movq -40(%rbp),%rcx
cmpq %rcx,%rax
jae .L3155
movq $0,%r12
jmp .L3156
.L3155:
.L3156:
movq -40(%rbp),%rax
movq -32(%rbp),%rcx
cmpq %rcx,%rax
jae .L3157
movq $2,%r12
jmp .L3158
.L3157:
.L3158:
jmp .L3154
.L3153:
.L3154:
movq -8(%rbp),%rdi
movq %r12,%rsi
call rt_order_result
movq -.F3145-8(%rbp),%rbx
movq -.F3145-16(%rbp),%r12
movq -.F3145-24(%rbp),%r13
movq -.F3145-32(%rbp),%r14
movq -.F3145-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F3145-8(%rbp),%rbx
movq -.F3145-16(%rbp),%r12
movq -.F3145-24(%rbp),%r13
movq -.F3145-32(%rbp),%r14
movq -.F3145-40(%rbp),%r15
leave
ret
.set .F3145,48
.type rt_vec_set,@function
rt_vec_set:
pushq %rbp
movq %rsp,%rbp
subq $.F3159,%rsp
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
jnc .L3160
call rt_abort
.L3160:
movq %rax,%rcx
movq -32(%rbp),%rax
addq %rcx,%rax
jnc .L3161
call rt_abort
.L3161:
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
.set .F3159,48
.type rt_vec_insert,@function
rt_vec_insert:
pushq %rbp
movq %rsp,%rbp
subq $.F3162,%rsp
subq $32,%rsp
movq %rbx,-.F3162-8(%rbp)
movq %r12,-.F3162-16(%rbp)
movq %r13,-.F3162-24(%rbp)
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
jae .L3163
call rt_abort
jmp .L3164
.L3163:
.L3164:
movq %r12,%rdi
movabsq $0,%rsi
movq 8(%rdi),%rcx
cmpq 16(%rdi),%rcx
jb .Lopt268
call rt_push
jmp .Lopt269
.Lopt268:
movq (%rdi),%rdx
movq %rsi,(%rdx,%rcx,8)
incq %rcx
movq %rcx,8(%rdi)
movq $0,%rax
.Lopt269:
movq -32(%rbp),%rax
movq %rax,%rbx
.L3165:
movq %rbx,%rcx
cmpq %rbx,%r13
jae .L3166
movabsq $1,%rcx
movq %rbx,%rax
subq $1,%rax
jnc .L3167
call rt_abort
.L3167:
movq %r12,%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i100
call rt_abort
.Lopt36_i100:
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
jnc .L3168
call rt_abort
.L3168:
movq %rax,%rbx
jmp .L3165
.L3166:
movq -24(%rbp),%rax
movq %r12,%rdi
movq %r13,%rsi
movq %rax,%rdx
call rt_vec_set
movabsq $0,%rax
movq -.F3162-8(%rbp),%rbx
movq -.F3162-16(%rbp),%r12
movq -.F3162-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3162-8(%rbp),%rbx
movq -.F3162-16(%rbp),%r12
movq -.F3162-24(%rbp),%r13
leave
ret
.set .F3162,32
.type rt_vec_remove,@function
rt_vec_remove:
pushq %rbp
movq %rsp,%rbp
subq $.F3169,%rsp
subq $32,%rsp
movq %rbx,-.F3169-8(%rbp)
movq %r12,-.F3169-16(%rbp)
movq %r13,-.F3169-24(%rbp)
movq %r14,-.F3169-32(%rbp)
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
jne .L3170
call rt_abort
jmp .L3171
.L3170:
.L3171:
movq %r12,%rdi
movq %r14,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i101
call rt_abort
.Lopt36_i101:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i101
xorq %rax,%rax
jmp .Lret_i101
.Lret_i101:
movq %rax,-32(%rbp)
movq %r14,%rbx
.L3172:
movq %rbx,%rax
addq $1,%rax
jnc .L3174
call rt_abort
.L3174:
movq %r13,%rcx
cmpq %r13,%rax
jae .L3173
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L3175
call rt_abort
.L3175:
movq %r12,%rdi
movq %rax,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i102
call rt_abort
.Lopt36_i102:
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
jnc .L3176
call rt_abort
.L3176:
movq %rax,%rbx
jmp .L3172
.L3173:
movq %r12,%rdi
call rt_pop
movq -32(%rbp),%rax
movq -.F3169-8(%rbp),%rbx
movq -.F3169-16(%rbp),%r12
movq -.F3169-24(%rbp),%r13
movq -.F3169-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F3169-8(%rbp),%rbx
movq -.F3169-16(%rbp),%r12
movq -.F3169-24(%rbp),%r13
movq -.F3169-32(%rbp),%r14
leave
ret
.set .F3169,32
.type rt_vec_swap,@function
rt_vec_swap:
pushq %rbp
movq %rsp,%rbp
subq $.F3177,%rsp
subq $32,%rsp
movq %rbx,-.F3177-8(%rbp)
movq %r12,-.F3177-16(%rbp)
movq %r13,-.F3177-24(%rbp)
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
jnc .L3178
call rt_abort
.L3178:
testq %rax,%rax
jz .L3179
call rt_abort
jmp .L3180
.L3179:
.L3180:
movq %rbx,%rdi
movq %r12,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i103
call rt_abort
.Lopt36_i103:
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
jb .Lopt36_i104
call rt_abort
.Lopt36_i104:
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
movq -.F3177-8(%rbp),%rbx
movq -.F3177-16(%rbp),%r12
movq -.F3177-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3177-8(%rbp),%rbx
movq -.F3177-16(%rbp),%r12
movq -.F3177-24(%rbp),%r13
leave
ret
.set .F3177,64
.type rt_vec_reverse,@function
rt_vec_reverse:
pushq %rbp
movq %rsp,%rbp
subq $.F3181,%rsp
subq $32,%rsp
movq %rbx,-.F3181-8(%rbp)
movq %r12,-.F3181-16(%rbp)
movq %r13,-.F3181-24(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq %rdi,%r13
movq $0,-16(%rbp)
movq %r13,%rdi
movq 8(%rdi),%rax
movq %rax,%r12
movq $0,%rbx
.L3182:
movq %r12,%rdi
movabsq $2,%rsi
call rt_div
movq %rax,%rcx
cmpq %rcx,%rbx
jae .L3183
movq %r12,%rax
subq $1,%rax
jnc .L3184
call rt_abort
.L3184:
movq %rbx,%rcx
subq %rbx,%rax
jnc .L3185
call rt_abort
.L3185:
movq %r13,%rdi
movq %rbx,%rsi
movq %rax,%rdx
call rt_vec_swap
movabsq $1,%rcx
movq %rbx,%rax
addq $1,%rax
jnc .L3186
call rt_abort
.L3186:
movq %rax,%rbx
jmp .L3182
.L3183:
movabsq $0,%rax
movq -.F3181-8(%rbp),%rbx
movq -.F3181-16(%rbp),%r12
movq -.F3181-24(%rbp),%r13
leave
ret
xorq %rax,%rax
movq -.F3181-8(%rbp),%rbx
movq -.F3181-16(%rbp),%r12
movq -.F3181-24(%rbp),%r13
leave
ret
.set .F3181,16
.type rt_vec_truncate,@function
rt_vec_truncate:
pushq %rbp
movq %rsp,%rbp
subq $.F3187,%rsp
subq $32,%rsp
movq %rbx,-.F3187-8(%rbp)
movq %r12,-.F3187-16(%rbp)
movq %r13,-.F3187-24(%rbp)
movq %r14,-.F3187-32(%rbp)
movq $0,%rbx
movq $0,%r12
movq $0,%r13
movq $0,%r14
movq %rdi,%rbx
movq %rsi,%r14
movq %rdx,%r12
movq $0,-32(%rbp)
.L3188:
movq %rbx,%rdi
movq 8(%rdi),%rax
movq %rax,%rcx
cmpq %rcx,%r14
jae .L3189
movq %rbx,%rdi
call rt_pop
movq %rax,%r13
movabsq $0,%rcx
cmpq $0,%r12
je .L3190
movq %r13,%rdi
movabsq $0,%rsi
movq %r12,%rax
call *%rax
jmp .L3191
.L3190:
.L3191:
jmp .L3188
.L3189:
movabsq $0,%rax
movq -.F3187-8(%rbp),%rbx
movq -.F3187-16(%rbp),%r12
movq -.F3187-24(%rbp),%r13
movq -.F3187-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F3187-8(%rbp),%rbx
movq -.F3187-16(%rbp),%r12
movq -.F3187-24(%rbp),%r13
movq -.F3187-32(%rbp),%r14
leave
ret
.set .F3187,32
.type rt_vec_contains,@function
rt_vec_contains:
pushq %rbp
movq %rsp,%rbp
subq $.F3192,%rsp
subq $32,%rsp
movq %rbx,-.F3192-8(%rbp)
movq %r12,-.F3192-16(%rbp)
movq %r13,-.F3192-24(%rbp)
movq %r14,-.F3192-32(%rbp)
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
.L3193:
movq %r14,%rcx
cmpq %r14,%rbx
jae .L3194
movq %r12,%rdi
movq %rbx,%rsi
movq %rdi,%r8
movq %rsi,%r9
movq %r9,%rax
movq %r8,%rdi
movq %rax,%rsi
cmpq 8(%rdi),%rsi
jb .Lopt36_i105
call rt_abort
.Lopt36_i105:
movq (%rdi),%rax
leaq (%rax,%rsi,8),%rax
movq (%rax),%rax
jmp .Lret_i105
xorq %rax,%rax
jmp .Lret_i105
.Lret_i105:
cmpq %r13,%rax
jne .L3195
movabsq $1,%rax
movq -.F3192-8(%rbp),%rbx
movq -.F3192-16(%rbp),%r12
movq -.F3192-24(%rbp),%r13
movq -.F3192-32(%rbp),%r14
leave
ret
jmp .L3196
.L3195:
.L3196:
movq %rbx,%rax
addq $1,%rax
jnc .L3197
call rt_abort
.L3197:
movq %rax,%rbx
jmp .L3193
.L3194:
movabsq $0,%rax
movq -.F3192-8(%rbp),%rbx
movq -.F3192-16(%rbp),%r12
movq -.F3192-24(%rbp),%r13
movq -.F3192-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F3192-8(%rbp),%rbx
movq -.F3192-16(%rbp),%r12
movq -.F3192-24(%rbp),%r13
movq -.F3192-32(%rbp),%r14
leave
ret
.set .F3192,16
.type rt_syscall,@function
rt_syscall:
pushq %rbp
movq %rsp,%rbp
subq $.F3198,%rsp
subq $32,%rsp
movq %rbx,-.F3198-8(%rbp)
movq %r12,-.F3198-16(%rbp)
movq %r13,-.F3198-24(%rbp)
movq %r14,-.F3198-32(%rbp)
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
jne .L3199
movq %rbx,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3200
.L3199:
.L3200:
movabsq $0,%rcx
cmpq $0,%rbx
jne .L3201
movabsq $63,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3202
.L3201:
.L3202:
movabsq $1,%rcx
cmpq $1,%rbx
jne .L3203
movabsq $64,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3204
.L3203:
.L3204:
cmpq $2,%rbx
jne .L3205
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
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3206
.L3205:
.L3206:
movabsq $3,%rcx
cmpq $3,%rbx
jne .L3207
movabsq $57,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3208
.L3207:
.L3208:
movabsq $11,%rcx
cmpq $11,%rbx
jne .L3209
movabsq $215,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3210
.L3209:
.L3210:
movabsq $27,%rcx
cmpq $27,%rbx
jne .L3211
movabsq $232,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3212
.L3211:
.L3212:
movabsq $39,%rcx
cmpq $39,%rbx
jne .L3213
movabsq $172,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3214
.L3213:
.L3214:
movabsq $57,%rcx
cmpq $57,%rbx
jne .L3215
movabsq $220,%rax
movabsq $17,%rdi
movabsq $0,%rsi
movabsq $0,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3216
.L3215:
.L3216:
movabsq $202,%rcx
cmpq $202,%rbx
jne .L3217
movabsq $98,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3218
.L3217:
.L3218:
movabsq $10,%rcx
cmpq $10,%rbx
jne .L3219
movabsq $226,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3220
.L3219:
.L3220:
movabsq $204,%rcx
cmpq $204,%rbx
jne .L3221
movabsq $123,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3222
.L3221:
.L3222:
movabsq $231,%rcx
cmpq $231,%rbx
jne .L3223
movabsq $94,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3224
.L3223:
.L3224:
movabsq $291,%rcx
cmpq $291,%rbx
jne .L3225
movabsq $20,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3226
.L3225:
.L3226:
movabsq $283,%rcx
cmpq $283,%rbx
jne .L3227
movabsq $85,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3228
.L3227:
.L3228:
movabsq $293,%rcx
cmpq $293,%rbx
jne .L3229
movabsq $59,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3230
.L3229:
.L3230:
movabsq $271,%rcx
cmpq $271,%rbx
jne .L3231
movabsq $73,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3232
.L3231:
.L3232:
movabsq $228,%rcx
cmpq $228,%rbx
jne .L3233
movabsq $113,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3234
.L3233:
.L3234:
movabsq $35,%rcx
cmpq $35,%rbx
jne .L3235
movabsq $101,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3236
.L3235:
.L3236:
movabsq $290,%rcx
cmpq $290,%rbx
jne .L3237
movabsq $19,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3238
.L3237:
.L3238:
movabsq $263,%rcx
cmpq $263,%rbx
jne .L3239
movabsq $35,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3240
.L3239:
.L3240:
movabsq $217,%rcx
cmpq $217,%rbx
jne .L3241
movabsq $61,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3242
.L3241:
.L3242:
movabsq $41,%rcx
cmpq $41,%rbx
jne .L3243
movabsq $198,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3244
.L3243:
.L3244:
movabsq $49,%rcx
cmpq $49,%rbx
jne .L3245
movabsq $200,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3246
.L3245:
.L3246:
movabsq $50,%rcx
cmpq $50,%rbx
jne .L3247
movabsq $201,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3248
.L3247:
.L3248:
movabsq $42,%rcx
cmpq $42,%rbx
jne .L3249
movabsq $203,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3250
.L3249:
.L3250:
movabsq $51,%rcx
cmpq $51,%rbx
jne .L3251
movabsq $204,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3252
.L3251:
.L3252:
movabsq $258,%rcx
cmpq $258,%rbx
jne .L3253
movabsq $34,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3254
.L3253:
.L3254:
movabsq $59,%rcx
cmpq $59,%rbx
jne .L3255
movabsq $221,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3256
.L3255:
.L3256:
movabsq $60,%rcx
cmpq $60,%rbx
jne .L3257
movabsq $93,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3258
.L3257:
.L3258:
movabsq $61,%rcx
cmpq $61,%rbx
jne .L3259
movabsq $260,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3260
.L3259:
.L3260:
movabsq $62,%rcx
cmpq $62,%rbx
jne .L3261
movabsq $129,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
xorl %r10d,%r10d
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
jmp .L3262
.L3261:
.L3262:
movabsq $0,%rax
subq $38,%rax
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
xorq %rax,%rax
movq -.F3198-8(%rbp),%rbx
movq -.F3198-16(%rbp),%r12
movq -.F3198-24(%rbp),%r13
movq -.F3198-32(%rbp),%r14
leave
ret
.set .F3198,48
.type rt_syscall4,@function
rt_syscall4:
pushq %rbp
movq %rsp,%rbp
subq $.F3263,%rsp
subq $48,%rsp
movq %rbx,-.F3263-8(%rbp)
movq %r12,-.F3263-16(%rbp)
movq %r13,-.F3263-24(%rbp)
movq %r14,-.F3263-32(%rbp)
movq %r15,-.F3263-40(%rbp)
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
jne .L3264
movq %rbx,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
jmp .L3265
.L3264:
.L3265:
movabsq $233,%rcx
cmpq $233,%rbx
jne .L3266
movabsq $21,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
jmp .L3267
.L3266:
.L3267:
movabsq $281,%rcx
cmpq $281,%rbx
jne .L3268
movabsq $22,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
jmp .L3269
.L3268:
.L3269:
movabsq $286,%rcx
cmpq $286,%rbx
jne .L3270
movabsq $86,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
jmp .L3271
.L3270:
.L3271:
movabsq $25,%rcx
cmpq $25,%rbx
jne .L3272
movabsq $216,%rax
movq %r12,%rdi
movq %r13,%rsi
movq %r14,%rdx
movq %r15,%r10
xorl %r8d,%r8d
xorl %r9d,%r9d
syscall
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
jmp .L3273
.L3272:
.L3273:
movabsq $0,%rax
subq $38,%rax
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
xorq %rax,%rax
movq -.F3263-8(%rbp),%rbx
movq -.F3263-16(%rbp),%r12
movq -.F3263-24(%rbp),%r13
movq -.F3263-32(%rbp),%r14
movq -.F3263-40(%rbp),%r15
leave
ret
.set .F3263,48
.type rt_readlinkat,@function
rt_readlinkat:
pushq %rbp
movq %rsp,%rbp
subq $.F3274,%rsp
movq %rdi,-8(%rbp)
movq %rsi,-16(%rbp)
movq %rdx,-24(%rbp)
movq $0,-32(%rbp)
movq $0,-40(%rbp)
movq $0,-48(%rbp)
movabsq $0,%rax
cmpq $0,%rax
jne .L3275
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
jmp .L3276
.L3275:
.L3276:
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
.set .F3274,48
.type rt_faccessat,@function
rt_faccessat:
pushq %rbp
movq %rsp,%rbp
subq $.F3277,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movq $0,-24(%rbp)
movq $0,-32(%rbp)
movabsq $0,%rax
cmpq $0,%rax
jne .L3278
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
jmp .L3279
.L3278:
.L3279:
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
.set .F3277,32
.type rt_accept4,@function
rt_accept4:
pushq %rbp
movq %rsp,%rbp
subq $.F3280,%rsp
movq %rdi,-8(%rbp)
movq $0,-16(%rbp)
movabsq $0,%rcx
movabsq $0,%rax
cmpq $0,%rax
jne .L3281
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
jmp .L3282
.L3281:
.L3282:
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
.set .F3280,16
.type rt_os_init,@function
rt_os_init:
pushq %rbp
movq %rsp,%rbp
subq $.F3283,%rsp
movabsq $0,%rax
leave
ret
xorq %rax,%rax
leave
ret
.set .F3283,16
.type f_core_some$0,@function
f_core_some$0:
pushq %rbp
movq %rsp,%rbp
subq $.F3419,%rsp
subq $32,%rsp
movq %rbx,-.F3419-8(%rbp)
movq %r12,-.F3419-16(%rbp)
movq %r13,-.F3419-24(%rbp)
movq %r14,-.F3419-32(%rbp)
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
je .L3420
movq %r13,%rdi
call .D38
.L3420:
cmpq $0,%r12
je .L3421
movq %r14,%rdi
call .D37
.L3421:
movq %r13,%rax
movq -.F3419-8(%rbp),%rbx
movq -.F3419-16(%rbp),%r12
movq -.F3419-24(%rbp),%r13
movq -.F3419-32(%rbp),%r14
leave
ret
cmpq $0,%rbx
je .L3422
movq $0,%rbx
movq %r13,%rdi
call .D38
.L3422:
cmpq $0,%rbx
je .L3423
movq $0,%rbx
movq %r13,%rdi
call .D38
.L3423:
cmpq $0,%rbx
je .L3424
movq %r13,%rdi
call .D38
.L3424:
cmpq $0,%r12
je .L3425
movq %r14,%rdi
call .D37
.L3425:
xorq %rax,%rax
movq -.F3419-8(%rbp),%rbx
movq -.F3419-16(%rbp),%r12
movq -.F3419-24(%rbp),%r13
movq -.F3419-32(%rbp),%r14
leave
ret
.set .F3419,16
.D2:
testq %rdi,%rdi
jz .L3426
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_drop_seq
popq %r13
popq %r12
leave
.L3426:
ret
.D3:
testq %rdi,%rdi
jz .L3427
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_drop_seq
popq %r13
popq %r12
leave
.L3427:
ret
.D4:
testq %rdi,%rdi
jz .L3428
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L3428:
ret
.D5:
testq %rdi,%rdi
jz .L3429
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
xorq %r13,%r13
.L3430:
cmpq 8(%r12),%r13
jae .L3431
movq (%r12),%rax
movq (%rax,%r13,8),%rdi
call .D2
incq %r13
jmp .L3430
.L3431:
movq %r12,%rdi
call rt_drop_seq
popq %r13
popq %r12
leave
.L3429:
ret
.D6:
testq %rdi,%rdi
jz .L3432
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
.L3432:
ret
.D8:
testq %rdi,%rdi
jz .L3433
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L3433:
ret
.D18:
testq %rdi,%rdi
jz .L3434
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L3434:
ret
.D19:
testq %rdi,%rdi
jz .L3435
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
.L3435:
ret
.D22:
testq %rdi,%rdi
jz .L3436
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
.L3436:
ret
.D24:
testq %rdi,%rdi
jz .L3437
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
call rt_free
popq %r13
popq %r12
leave
.L3437:
ret
.D37:
testq %rdi,%rdi
jz .L3438
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
popq %r13
popq %r12
leave
.L3438:
ret
.D38:
testq %rdi,%rdi
jz .L3439
pushq %rbp
movq %rsp,%rbp
pushq %r12
pushq %r13
movq %rdi,%r12
cmpq $1,(%r12)
jne .L3440
movq 8(%r12),%rdi
call .D37
.L3440:
movq %r12,%rdi
call rt_free
popq %r13
popq %r12
leave
.L3439:
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
jz .L3441
call rt_abort
.L3441:
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
