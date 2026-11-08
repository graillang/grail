# Minimal in-process COM object used by the Windows COM interop cases.
# IUnknown only: QueryInterface, AddRef, Release. Object layout: [vtable][refcount][payload].
.text
.globl grail_com_make_object
grail_com_make_object:            # HRESULT grail_com_make_object(void **out)
  subq $40,%rsp
  testq %rcx,%rcx
  jz .Lmake_null
  leaq grail_com_object(%rip),%rax
  movq %rax,(%rcx)
  movl $1,grail_com_object+8(%rip)
  xorl %eax,%eax
  addq $40,%rsp
  ret
.Lmake_null:
  movl $2147500035,%eax           # E_POINTER
  addq $40,%rsp
  ret

.globl grail_com_iid_address
grail_com_iid_address:            # const GUID *grail_com_iid_address(void)
  leaq grail_com_iid(%rip),%rax
  ret

grail_com_qi:                     # HRESULT QI(this=%rcx, riid=%rdx, ppv=%r8)
  subq $40,%rsp
  testq %r8,%r8
  jz .Lqi_ptr
  movq $0,(%r8)
  testq %rdx,%rdx
  jz .Lqi_ptr
  leaq grail_com_iid(%rip),%r9
  movq (%rdx),%rax
  cmpq (%r9),%rax
  jne .Lqi_no
  movq 8(%rdx),%rax
  cmpq 8(%r9),%rax
  jne .Lqi_no
  movq %rcx,(%r8)
  lock incl grail_com_object+8(%rip)
  xorl %eax,%eax                  # S_OK
  addq $40,%rsp
  ret
.Lqi_no:
  movl $2147500034,%eax           # E_NOINTERFACE
  addq $40,%rsp
  ret
.Lqi_ptr:
  movl $2147500035,%eax           # E_POINTER
  addq $40,%rsp
  ret

grail_com_addref:                 # ULONG AddRef(this=%rcx)
  movl $1,%eax
  lock xaddl %eax,grail_com_object+8(%rip)
  addl $1,%eax
  ret

grail_com_release:                # ULONG Release(this=%rcx)
  movl $-1,%eax
  lock xaddl %eax,grail_com_object+8(%rip)
  subl $1,%eax
  ret

.section .data,"dw"
.p2align 3
grail_com_object:
  .quad grail_com_vtbl
  .long 1
  .long 0
  .quad 11259375
.p2align 3
grail_com_vtbl:
  .quad grail_com_qi
  .quad grail_com_addref
  .quad grail_com_release
.p2align 3
grail_com_iid:
  .long 0x7A3F0001
  .short 0x1234
  .short 0x5678
  .byte 0x9A,0xBC,0xDE,0xF0,0x11,0x22,0x33,0x44
