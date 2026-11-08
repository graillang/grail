    // Minimal in-process COM object for the windows-aarch64 static checks. IUnknown only.
.text
.globl grail_com_make_object
grail_com_make_object:    // HRESULT grail_com_make_object(void **out) -> x0
  cbz x0,.Lmake_null
  adrp x9,grail_com_object
  add x9,x9,:lo12:grail_com_object
  str x9,[x0]
  mov w10,#1
  str w10,[x9,#8]
  mov w0,#0
  ret
.Lmake_null:
  movz w0,#16387
  movk w0,#32768,lsl #16    // E_POINTER
  ret

.globl grail_com_iid_address
grail_com_iid_address:
  adrp x0,grail_com_iid
  add x0,x0,:lo12:grail_com_iid
  ret

grail_com_qi:    // HRESULT QI(this=x0, riid=x1, ppv=x2)
  cbz x2,.Lqi_ptr
  str xzr,[x2]
  cbz x1,.Lqi_ptr
  adrp x9,grail_com_iid
  add x9,x9,:lo12:grail_com_iid
  ldr x10,[x1]
  ldr x11,[x9]
  cmp x10,x11
  b.ne .Lqi_no
  ldr x10,[x1,#8]
  ldr x11,[x9,#8]
  cmp x10,x11
  b.ne .Lqi_no
  str x0,[x2]
  adrp x12,grail_com_object
  add x12,x12,:lo12:grail_com_object
  ldr w13,[x12,#8]
  add w13,w13,#1
  str w13,[x12,#8]
  mov w0,#0
  ret
.Lqi_no:
  movz w0,#16386
  movk w0,#32768,lsl #16    // E_NOINTERFACE
  ret
.Lqi_ptr:
  movz w0,#16387
  movk w0,#32768,lsl #16    // E_POINTER
  ret

grail_com_addref:
  adrp x9,grail_com_object
  add x9,x9,:lo12:grail_com_object
  ldr w10,[x9,#8]
  add w10,w10,#1
  str w10,[x9,#8]
  mov w0,w10
  ret

grail_com_release:
  adrp x9,grail_com_object
  add x9,x9,:lo12:grail_com_object
  ldr w10,[x9,#8]
  sub w10,w10,#1
  str w10,[x9,#8]
  mov w0,w10
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
