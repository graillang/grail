define weak_odr { i64, i64 } @"f_.inherent$iter$Filter_next$ff2557a608b4c9c2"(i64 %a0) local_unnamed_addr #2 {
entry:
  %s.11.i.i = alloca [2 x i64], align 8
  %s.22.i.i = alloca [2 x i64], align 8
  %s.6.i = alloca [2 x i64], align 8
  %s.24.i = alloca [2 x i64], align 8
  %s.32.i = alloca [2 x i64], align 8
  %s.6 = alloca [2 x i64], align 8
  %t1 = getelementptr inbounds nuw i8, ptr %s.6, i64 8
  %s.23 = alloca [2 x i64], align 8
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.6, i8 0, i64 16, i1 false)
  %s.30 = alloca [2 x i64], align 8
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.23, i8 0, i64 16, i1 false)
  %t1.i = getelementptr inbounds nuw i8, ptr %s.6.i, i64 8
  %t12.i.i = inttoptr i64 %a0 to ptr
  %t39.i = ptrtoint ptr %s.6.i to i64
  %t66.i = add i64 %t39.i, 8
  %t67.i = inttoptr i64 %t66.i to ptr
  %t39 = ptrtoint ptr %s.6 to i64
  %t66 = add i64 %t39, 8
  %t67 = inttoptr i64 %t66 to ptr
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.30, i8 0, i64 16, i1 false)
  br label %b_Lmain_67b17cd6_7_2

b_Lmain_67b17cd6_7_2:                             ; preds = %n1, %entry
  call void @llvm.lifetime.start.p0(ptr nonnull %s.6.i)
  call void @llvm.lifetime.start.p0(ptr nonnull %s.24.i)
  call void @llvm.lifetime.start.p0(ptr nonnull %s.32.i)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.24.i, i8 0, i64 16, i1 false)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.32.i, i8 0, i64 16, i1 false)
  call void @llvm.lifetime.start.p0(ptr nonnull %s.11.i.i)
  call void @llvm.lifetime.start.p0(ptr nonnull %s.22.i.i)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.11.i.i, i8 0, i64 16, i1 false)
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.22.i.i, i8 0, i64 16, i1 false)
  %t13.i.i = load i64, ptr %t12.i.i, align 1
  %t16.i.i.i = add i64 %t13.i.i, 8
  %t30.i.i.i = inttoptr i64 %t16.i.i.i to ptr
  %t31.i.i.i = load i64, ptr %t30.i.i.i, align 1
  %t44.not.i.i = icmp eq i64 %t31.i.i.i, 0
  br i1 %t44.not.i.i, label %n1.i.i, label %rt_pop.exit.i.i

n1.i.i:                                           ; preds = %b_Lmain_67b17cd6_7_2
  store i64 1, ptr %s.11.i.i, align 8
  br label %"f_.inherent$iter$VecIter_next$4b4884e25da627b4.exit.i"

rt_pop.exit.i.i:                                  ; preds = %b_Lmain_67b17cd6_7_2
  %t115.i.i.i = inttoptr i64 %t13.i.i to ptr
  %t116.i.i.i = load i64, ptr %t115.i.i.i, align 1
  %t136.i.i.i = add i64 %t31.i.i.i, -1
  %t156.i.i.i = shl i64 %t136.i.i.i, 3
  %t170.i.i.i = add i64 %t116.i.i.i, %t156.i.i.i
  %t184.i.i.i = inttoptr i64 %t170.i.i.i to ptr
  %t185.i.i.i = load i64, ptr %t184.i.i.i, align 1
  store i64 0, ptr %t184.i.i.i, align 1
  store i64 %t136.i.i.i, ptr %t30.i.i.i, align 1
  br label %"f_.inherent$iter$VecIter_next$4b4884e25da627b4.exit.i"

"f_.inherent$iter$VecIter_next$4b4884e25da627b4.exit.i": ; preds = %rt_pop.exit.i.i, %n1.i.i
  %t190.sink.in.i.i = phi ptr [ %s.22.i.i, %rt_pop.exit.i.i ], [ %s.11.i.i, %n1.i.i ]
  %t185.i.sink.i.i = phi i64 [ %t185.i.i.i, %rt_pop.exit.i.i ], [ 0, %n1.i.i ]
  %t190.sink.i.i = ptrtoint ptr %t190.sink.in.i.i to i64
  %t204.i.i = add i64 %t190.sink.i.i, 8
  %t205.i.i = inttoptr i64 %t204.i.i to ptr
  store i64 %t185.i.sink.i.i, ptr %t205.i.i, align 8
  %t112.pn.i.i = load i64, ptr %t190.sink.in.i.i, align 8
  call void @llvm.lifetime.end.p0(ptr nonnull %s.11.i.i)
  call void @llvm.lifetime.end.p0(ptr nonnull %s.22.i.i)
  store i64 %t112.pn.i.i, ptr %s.6.i, align 8
  store i64 %t185.i.sink.i.i, ptr %t1.i, align 8
  switch i64 %t112.pn.i.i, label %b_Lmain_67b17cd6_8_17.i [
    i64 0, label %n1.i
    i64 1, label %n16.i
  ]

n1.i:                                             ; preds = %"f_.inherent$iter$VecIter_next$4b4884e25da627b4.exit.i"
  %t68.i = load i64, ptr %t67.i, align 8
  %t19.i.i = shl i64 %t68.i, 1
  store i64 0, ptr %s.24.i, align 8
  br label %"f_.inherent$iter$Map_next$37f02f615970d181.exit"

n16.i:                                            ; preds = %"f_.inherent$iter$VecIter_next$4b4884e25da627b4.exit.i"
  store i64 1, ptr %s.32.i, align 8
  br label %"f_.inherent$iter$Map_next$37f02f615970d181.exit"

b_Lmain_67b17cd6_8_17.i:                          ; preds = %"f_.inherent$iter$VecIter_next$4b4884e25da627b4.exit.i"
  call fastcc void @rt_abort.cold() #27
  unreachable

"f_.inherent$iter$Map_next$37f02f615970d181.exit": ; preds = %n1.i, %n16.i
  %t425.sink.in.i = phi ptr [ %s.32.i, %n16.i ], [ %s.24.i, %n1.i ]
  %.sink.i = phi i64 [ 0, %n16.i ], [ %t19.i.i, %n1.i ]
  %t425.sink.i = ptrtoint ptr %t425.sink.in.i to i64
  %t439.i = add i64 %t425.sink.i, 8
  %t440.i = inttoptr i64 %t439.i to ptr
  store i64 %.sink.i, ptr %t440.i, align 8
  %t232.pn.i = load i64, ptr %t425.sink.in.i, align 8
  call void @llvm.lifetime.end.p0(ptr nonnull %s.6.i)
  call void @llvm.lifetime.end.p0(ptr nonnull %s.24.i)
  call void @llvm.lifetime.end.p0(ptr nonnull %s.32.i)
  store i64 %t232.pn.i, ptr %s.6, align 8
  store i64 %.sink.i, ptr %t1, align 8
  %t58.not = icmp eq i64 %t232.pn.i, 0
  br i1 %t58.not, label %n1, label %b_Lmain_67b17cd6_7_15

n1:                                               ; preds = %"f_.inherent$iter$Map_next$37f02f615970d181.exit"
  %t68 = load i64, ptr %t67, align 8
  %0 = urem i64 %t68, 3
  %t71.i.not = icmp eq i64 %0, 0
  br i1 %t71.i.not, label %n2, label %b_Lmain_67b17cd6_7_2

n2:                                               ; preds = %n1
  store i64 0, ptr %s.23, align 8
  br label %common.ret

common.ret:                                       ; preds = %b_Lmain_67b17cd6_7_15, %n2
  %t294.sink.in = phi ptr [ %s.30, %b_Lmain_67b17cd6_7_15 ], [ %s.23, %n2 ]
  %.sink = phi i64 [ 0, %b_Lmain_67b17cd6_7_15 ], [ %t68, %n2 ]
  %t294.sink = ptrtoint ptr %t294.sink.in to i64
  %t308 = add i64 %t294.sink, 8
  %t309 = inttoptr i64 %t308 to ptr
  store i64 %.sink, ptr %t309, align 8
  %t196.pn = load i64, ptr %t294.sink.in, align 8
  %t199.pn = insertvalue { i64, i64 } undef, i64 %t196.pn, 0
  %common.ret.op = insertvalue { i64, i64 } %t199.pn, i64 %.sink, 1
  ret { i64, i64 } %common.ret.op

b_Lmain_67b17cd6_7_15:                            ; preds = %"f_.inherent$iter$Map_next$37f02f615970d181.exit"
  store i64 1, ptr %s.30, align 8
  br label %common.ret
}
