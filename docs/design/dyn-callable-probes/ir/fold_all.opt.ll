define weak_odr i64 @"f_iter_fold_all$239805308fc557d9"(i64 %a0, i64 %a1, i64 %a2) local_unnamed_addr #2 {
entry:
  %s.10 = alloca [5 x i64], align 8
  %s.16 = alloca [2 x i64], align 8
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(40) %s.10, i8 0, i64 40, i1 false)
  %s.22 = alloca [2 x i64], align 8
  call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %s.16, i8 0, i64 16, i1 false)
  %t6 = getelementptr inbounds nuw i8, ptr %s.22, i64 8
  %t20 = ptrtoint ptr %s.10 to i64
  %t28 = inttoptr i64 %a0 to ptr
  %t29 = load i64, ptr %t28, align 1
  store i64 %t29, ptr %s.10, align 8
  %t34 = add i64 %a0, 8
  %t35 = inttoptr i64 %t34 to ptr
  %t36 = load i64, ptr %t35, align 1
  %t39 = add i64 %t20, 8
  %t40 = inttoptr i64 %t39 to ptr
  store i64 %t36, ptr %t40, align 8
  %t42 = add i64 %a0, 16
  %t43 = inttoptr i64 %t42 to ptr
  %t44 = load i64, ptr %t43, align 1
  %t47 = add i64 %t20, 16
  %t48 = inttoptr i64 %t47 to ptr
  store i64 %t44, ptr %t48, align 8
  %t50 = add i64 %a0, 24
  %t51 = inttoptr i64 %t50 to ptr
  %t52 = load i64, ptr %t51, align 1
  %t55 = add i64 %t20, 24
  %t56 = inttoptr i64 %t55 to ptr
  store i64 %t52, ptr %t56, align 8
  %t58 = add i64 %a0, 32
  %t59 = inttoptr i64 %t58 to ptr
  %t60 = load i64, ptr %t59, align 1
  %t63 = add i64 %t20, 32
  %t64 = inttoptr i64 %t63 to ptr
  store i64 %t60, ptr %t64, align 8
  %t76 = ptrtoint ptr %s.16 to i64
  %t84 = inttoptr i64 %a2 to ptr
  %t85 = load i64, ptr %t84, align 1
  store i64 %t85, ptr %s.16, align 8
  %t90 = add i64 %a2, 8
  %t91 = inttoptr i64 %t90 to ptr
  %t92 = load i64, ptr %t91, align 1
  %t95 = add i64 %t76, 8
  %t96 = inttoptr i64 %t95 to ptr
  store i64 %t92, ptr %t96, align 8
  %t111178 = call { i64, i64 } @"f_.inherent$iter$Filter_next$ff2557a608b4c9c2"(i64 %t20)
  %t112179 = extractvalue { i64, i64 } %t111178, 0
  %t113180 = extractvalue { i64, i64 } %t111178, 1
  store i64 %t112179, ptr %s.22, align 8
  store i64 %t113180, ptr %t6, align 8
  %t138.not181 = icmp eq i64 %t112179, 0
  br i1 %t138.not181, label %n1.lr.ph, label %n17

n1.lr.ph:                                         ; preds = %entry
  %t119 = ptrtoint ptr %s.22 to i64
  %t146 = add i64 %t119, 8
  %t147 = inttoptr i64 %t146 to ptr
  br label %n1

n1:                                               ; preds = %n1.lr.ph, %n1
  %s.13.0182 = phi i64 [ %a1, %n1.lr.ph ], [ %t18.i, %n1 ]
  %t148 = load i64, ptr %t147, align 8
  %t18.i = add i64 %t148, %s.13.0182
  %t111 = call { i64, i64 } @"f_.inherent$iter$Filter_next$ff2557a608b4c9c2"(i64 %t20)
  %t112 = extractvalue { i64, i64 } %t111, 0
  %t113 = extractvalue { i64, i64 } %t111, 1
  store i64 %t112, ptr %s.22, align 8
  store i64 %t113, ptr %t6, align 8
  %t138.not = icmp eq i64 %t112, 0
  br i1 %t138.not, label %n1, label %n17

n17:                                              ; preds = %n1, %entry
  %r.rsi.0.lcssa = phi i64 [ %a1, %entry ], [ %s.13.0182, %n1 ]
  %s.13.0.lcssa = phi i64 [ %a1, %entry ], [ %t18.i, %n1 ]
  %t113.lcssa = phi i64 [ %t113180, %entry ], [ %t113, %n1 ]
  %t513 = call { i64, i64 } @.Pfea3108e9ed22599(i64 %t20, i64 %r.rsi.0.lcssa, i64 %t113.lcssa, i64 %a2, i64 undef, i64 undef)
  ret i64 %s.13.0.lcssa
}
