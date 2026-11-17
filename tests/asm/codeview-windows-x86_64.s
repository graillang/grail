// CodeView line information (.cv_* and .secrel32/.secidx in .debug$S) as the Windows debug build writes it.
.cv_file 1 "a.grl"
.cv_file 2 "/x/lib/b.grl"
.text
.def f
.scl 2
.type 32
.endef
.globl f
f:
.cv_func_id 0
.Lf_1:
.cv_loc 0 1 3 5
pushq %rbp
.cv_loc 0 1 4 2
movq %rsp,%rbp
.cv_loc 0 2 10 1
popq %rbp
.cv_loc 0 1 300 1
ret
.Lf_2:
g:
.cv_func_id 1
.Lg_1:
.cv_loc 1 2 7 1
ret
.Lg_2:
.section .debug$S,"dr"
.p2align 2
.long 4
.long 241
.long .Le-.Lb
.Lb:
.short 2
.short 6
.Le:
.p2align 2
.cv_linetable 0, .Lf_1, .Lf_2
.cv_linetable 1, .Lg_1, .Lg_2
.cv_filechecksums
.cv_stringtable
.secrel32 .Lf_1
.secidx .Lf_1
