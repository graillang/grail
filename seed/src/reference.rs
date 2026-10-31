use super::*;
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(super) struct Place {
    pub(super) base: Root,
    pub(super) path: Vec<usize>,
}
impl State {
    pub(super) fn access_conflict(&self, root: &Root, writes_only: bool) -> bool {
        let blocked =
            |(reads, writes): &(usize, usize)| *writes > 0 || (!writes_only && *reads > 0);
        let Root::Local(r, path) = root else {
            return self.access.get(root).is_some_and(blocked);
        };
        for len in 0..path.len() {
            if self
                .access
                .get(&Root::Local(*r, path[..len].to_vec()))
                .is_some_and(blocked)
            {
                return true;
            }
        }
        for (key, count) in self.access.range(root.clone()..) {
            if let Root::Local(other, p) = key
                && other == r
                && p.starts_with(path)
            {
                if blocked(count) {
                    return true;
                }
            } else {
                break;
            }
        }
        false
    }
    pub(super) fn place_borrowed(&self, r: Reg, path: &[usize], writes_only: bool) -> bool {
        if self.access.is_empty() {
            return false;
        }
        self.access_conflict(&Root::Local(r, path.to_vec()), writes_only)
    }
    pub(super) fn retire_targets(&mut self, v: &Value) {
        for p in &v.targets {
            if let Root::Local(r, _) = p.base
                && p.path.is_empty()
                && self.addressed.contains(&r)
                && !self.place_borrowed(r, &[], false)
            {
                self.addressed.remove(&r);
                self.resources.remove(&r);
            }
        }
        for field in v.fields.iter().flatten() {
            self.retire_targets(field);
        }
    }
    pub(super) fn borrow_reference_bytes(
        &mut self,
        p: &Value,
        mode: Mode,
    ) -> Result<Value, String> {
        let Ty::Ref(parent, outer, inner) = &p.ty else {
            return Err("expected typed reference".into());
        };
        self.usable_value(p)?;
        if mode == Mode::Write && *parent != Mode::Write {
            return Err("mutable data through shared typed reference".into());
        }
        let mut ancestors = p.ancestors.clone();
        if *parent == Mode::Write {
            ancestors.insert(p.loan);
        }
        if matches!(**inner, Ty::Bytes | Ty::Text) {
            if mode == Mode::Write && **inner == Ty::Text {
                return Err("string bytes cannot be mutably borrowed".into());
            }
            let mut value = self.new_value(Ty::View(mode, *outer), p.roots.clone(), ancestors);
            value.lives = vec![p.lives[0].clone()];
            return Ok(value);
        }
        let (stored, region) = match **inner {
            Ty::View(m, r) | Ty::Holder(m, r) => (m, r),
            _ => return Err("typed referent is not byte storage or descriptor".into()),
        };
        if mode == Mode::Write && stored != Mode::Write {
            return Err("mutable reborrow from stored shared descriptor".into());
        }
        let mut roots = BTreeSet::new();
        let mut from = BTreeSet::new();
        let mut lifetime = None;
        for target in &p.targets {
            let value = self.target(target)?;
            self.usable_value(value)?;
            lifetime = Some(if let Some(old) = lifetime {
                self.life_meet(&old, &value.lives[0])
            } else {
                value.lives[0].clone()
            });
            roots.extend(value.roots.clone());
            from.extend(value.ancestors.clone());
            if stored == Mode::Write {
                from.insert(value.loan);
            }
        }
        if stored == Mode::Write {
            roots.extend(p.roots.clone());
            from.extend(ancestors);
        }
        let mut value = self.new_value(
            Ty::View(mode, if stored == Mode::Read { region } else { *outer }),
            roots,
            from,
        );
        value.lives = vec![if stored == Mode::Read {
            lifetime.ok_or("missing stored lifetime")?
        } else {
            p.lives[0].clone()
        }];
        Ok(value)
    }
    pub(super) fn reference_field_bytes(
        &mut self,
        src: Reg,
        path: &[String],
        mode: Mode,
    ) -> Result<Value, String> {
        let (mut v, m, r, t) = self.reference_parts(src)?;
        let (indices, field) = types::project(&t, path, &self.layouts)?;
        v.targets = v
            .targets
            .into_iter()
            .map(|mut p| {
                p.path.extend(&indices);
                p
            })
            .collect();
        let mut lives = vec![v.lives[0].clone()];
        let mut inner = None::<Vec<witness::Life>>;
        for p in &v.targets {
            let bound = self.target(p)?;
            inner = Some(if let Some(old) = inner {
                old.iter()
                    .zip(&bound.lives)
                    .map(|(a, b)| self.life_meet(a, b))
                    .collect()
            } else {
                bound.lives.clone()
            });
        }
        lives.extend(inner.ok_or("missing field lifetime target")?);
        v.lives = lives;
        v.ty = Ty::Ref(m, r, Box::new(field));
        self.borrow_reference_bytes(&v, mode)
    }
    pub(super) fn load_reference_field(
        &mut self,
        dst: Reg,
        src: Reg,
        path: &[String],
    ) -> Result<(), String> {
        let (_, _, _, t) = self.reference_parts(src)?;
        let (_, field) = types::project(&t, path, &self.layouts)?;
        if !field.copy() {
            return Err(
                "cannot move an affine field through typed reference; borrow or exchange it".into(),
            );
        }
        let v = self.new_value(field, BTreeSet::new(), BTreeSet::new());
        self.put(dst, v)
    }
    pub(super) fn writeback(
        &mut self,
        sources: &[provenance::InputSource],
        results: &mut provenance::Results<'_>,
    ) -> Result<Vec<Value>, String> {
        let mut updates = BTreeMap::new();
        for source in sources {
            let Ty::Ref(Mode::Write, _, inner) = &source.spec.ty else {
                continue;
            };
            if source.spec.frames.iter().any(|f| f.mode != Mode::Write) {
                continue;
            }
            for p in &source.value.targets {
                let old = self.target(p)?.clone();
                let mut next = self.result_sources(inner, 0, &mut Vec::new(), results)?;
                self.stamp_value(&mut next, &witness::Instance::of(&old))?;
                retain_loans(&mut next, &old);
                rename_owned(&mut next, &p.base, &p.path);
                if let Some((_, previous)) = updates.get_mut(p) {
                    self.merge_value(previous, &next)?;
                } else {
                    updates.insert(p.clone(), (old, next));
                }
            }
        }
        let mut retired = Vec::new();
        for (p, (old, next)) in updates {
            self.replace_target(&p, next)?;
            retired.push(old);
        }
        Ok(retired)
    }
    fn replace_target(&mut self, p: &Place, next: Value) -> Result<(), String> {
        let old = self.target(p)?.clone();
        self.index_remove(&old);
        *self.target_mut(p)? = next.clone();
        self.index_add(&next);
        Ok(())
    }
    fn fresh_loans(&mut self, v: &mut Value) {
        self.next += 1;
        v.loan = self.next;
        for field in v.fields.iter_mut().flatten() {
            self.fresh_loans(field);
        }
    }
    pub(super) fn merge_value(&self, v: &mut Value, other: &Value) -> Result<bool, String> {
        if v == other {
            return Ok(false);
        }
        if !self.instance_fits(
            &witness::Instance::of(v),
            &witness::Instance::of(other),
            true,
        )? {
            return Err("stored lifetime witness differs across possible cells".into());
        }
        let before = v.roots.len() + v.ancestors.len() + v.targets.len();
        v.roots.extend(other.roots.clone());
        v.ancestors.extend(other.ancestors.clone());
        v.targets.extend(other.targets.clone());
        if v.roots.len() > 4096 || v.ancestors.len() > 4096 || v.targets.len() > 4096 {
            return Err("capture union expansion limit".into());
        }
        let mut changed = before != v.roots.len() + v.ancestors.len() + v.targets.len();
        for (a, b) in v.fields.iter_mut().zip(&other.fields) {
            match (a, b) {
                (Some(a), Some(b)) => {
                    changed |= self.merge_value(a, b)?;
                }
                (None, None) => (),
                _ => return Err("possibly uninitialized cell".into()),
            }
        }
        Ok(changed)
    }
    fn owner_has_write(&self, v: &Value) -> bool {
        (v.ty.owned() && v.roots.iter().any(|r| self.access_conflict(r, true)))
            || v.fields.iter().flatten().any(|v| self.owner_has_write(v))
    }
    fn reference_parts(&self, r: Reg) -> Result<(Value, Mode, u16, Ty), String> {
        let v = self.usable(r)?;
        let Ty::Ref(m, region, t) = &v.ty else {
            return Err("expected typed reference".into());
        };
        Ok((v.clone(), *m, *region, (**t).clone()))
    }
    pub(super) fn target(&self, p: &Place) -> Result<&Value, String> {
        match &p.base {
            Root::Local(r, base) => {
                if !base.is_empty() {
                    return Err("invalid local place base".into());
                }
                self.get(*r)?.at(&p.path)
            }
            Root::Param(..) => self
                .memory
                .get(&p.base)
                .ok_or("missing external cell")?
                .at(&p.path),
        }
    }
    fn target_mut(&mut self, p: &Place) -> Result<&mut Value, String> {
        match &p.base {
            Root::Local(r, _) => self
                .values
                .get_mut(r)
                .ok_or("dead local cell")?
                .at_mut(&p.path),
            Root::Param(..) => self
                .memory
                .get_mut(&p.base)
                .ok_or("missing external cell")?
                .at_mut(&p.path),
        }
    }
    pub(super) fn address(
        &mut self,
        dst: Reg,
        src: Reg,
        path: &[String],
        mode: Mode,
    ) -> Result<(), String> {
        if dst == src {
            return Err("address needs a fresh register".into());
        }
        let v = self.get(src)?.clone();
        let (base, ty, mut ancestors, region) = if let Ty::Ref(m, r, t) = &v.ty {
            self.usable_value(&v)?;
            if mode == Mode::Write && *m != Mode::Write {
                return Err("mutable reborrow from shared typed reference".into());
            }
            let mut a = v.ancestors.clone();
            if *m == Mode::Write {
                a.insert(v.loan);
            }
            (v.targets.clone(), (**t).clone(), a, *r)
        } else {
            (
                BTreeSet::from([Place {
                    base: Root::Local(src, vec![]),
                    path: vec![],
                }]),
                v.ty.clone(),
                BTreeSet::new(),
                0,
            )
        };
        let (indices, inner) = if path.is_empty() {
            (vec![], ty)
        } else {
            types::project(&ty, path, &self.layouts)?
        };
        let result_ty = Ty::Ref(mode, region, Box::new(inner));
        types::validate_type(&result_ty, &self.layouts, self.type_parameters)?;

        let mut targets = BTreeSet::new();
        let mut roots = BTreeSet::new();
        let mut referent: Option<witness::Instance> = None;
        for mut p in base {
            p.path.extend(&indices);
            let value = self.target(&p)?;
            self.usable_value(value)?;
            let bound = witness::Instance::of(value);
            if let Some(old) = &mut referent {
                if mode == Mode::Write && !self.instance_fits(&bound, old, true)? {
                    return Err("mutable reference spans unequal lifetime witnesses".into());
                }
                old.lives = old
                    .lives
                    .iter()
                    .zip(&bound.lives)
                    .map(|(a, b)| self.life_meet(a, b))
                    .collect();
            } else {
                referent = Some(bound);
            }
            if !matches!(v.ty, Ty::Ref(..)) && mode == Mode::Write && self.owner_borrowed(value) {
                return Err("typed mutable borrow of borrowed storage".into());
            }
            if !matches!(v.ty, Ty::Ref(..)) && mode == Mode::Read && self.owner_has_write(value) {
                return Err("shared typed borrow conflicts with exclusive data access".into());
            }
            let root = match &p.base {
                Root::Local(r, _) => Root::Local(*r, p.path.clone()),
                r => r.clone(),
            };
            if !matches!(v.ty, Ty::Ref(..)) && self.access_conflict(&root, mode == Mode::Read) {
                return Err("conflicting typed storage access".into());
            }
            roots.insert(root);
            targets.insert(p);
        }
        if targets.is_empty() {
            return Err("typed reference has no possible target".into());
        }
        let mut result = self.new_value(result_ty, roots, std::mem::take(&mut ancestors));
        result.targets = targets;
        let referent = referent.ok_or("typed reference has no lifetime instance")?;
        let mut outer = if matches!(v.ty, Ty::Ref(..)) {
            v.lives[0].clone()
        } else {
            self.roots_life(&result.roots)?
        };
        for life in referent.reference_lives(&self.layouts)? {
            outer = self.life_meet(&outer, &life);
        }
        result.lives = vec![outer];
        result.lives.extend(referent.lives);
        self.put(dst, result)
    }
    pub(super) fn load_reference(&mut self, dst: Reg, src: Reg) -> Result<(), String> {
        let (p, _, _, t) = self.reference_parts(src)?;
        if t.copy() {
            let value = self.new_value(t, BTreeSet::new(), BTreeSet::new());
            return self.put(dst, value);
        }
        if !matches!(
            t,
            Ty::View(Mode::Read, _) | Ty::Holder(Mode::Read, _) | Ty::Ref(Mode::Read, _, _)
        ) {
            return Err(
                "load cannot copy affine referent; use exchange or an explicit reborrow".into(),
            );
        }
        let mut roots = BTreeSet::new();
        let mut ancestors = BTreeSet::new();
        let mut targets = BTreeSet::new();
        let mut lives = None::<Vec<witness::Life>>;
        for target in &p.targets {
            let v = self.target(target)?;
            self.usable_value(v)?;
            roots.extend(v.roots.clone());
            ancestors.extend(v.ancestors.clone());
            targets.extend(v.targets.clone());
            lives = Some(if let Some(old) = lives {
                old.iter()
                    .zip(&v.lives)
                    .map(|(a, b)| self.life_meet(a, b))
                    .collect()
            } else {
                v.lives.clone()
            });
        }
        let mut value = self.new_value(t, roots, ancestors);
        value.lives = lives.ok_or("missing loaded lifetime instance")?;
        value.targets = targets;
        self.put(dst, value)
    }
    pub(super) fn exchange(&mut self, dst: Reg, src: Reg, value: Reg) -> Result<(), String> {
        let (reference, m, _, t) = self.reference_parts(src)?;
        if m != Mode::Write {
            return Err("exchange needs mutable typed reference".into());
        }
        let mut incoming = self.usable(value)?;
        if !aggregate::compatible(&t, &incoming.ty) {
            return Err("exchange value type".into());
        }
        if self.owner_borrowed(&incoming) {
            return Err("exchange moves borrowed value".into());
        }
        let mut olds = Vec::new();
        for p in &reference.targets {
            let old = self.target(p)?.clone();
            self.usable_value(&old)?;
            self.coerce_value(&mut incoming, &witness::Instance::of(&old))?;
            olds.push(old);
        }
        let mut out = olds.first().cloned().ok_or("exchange target missing")?;
        for other in olds.iter().skip(1) {
            self.merge_value(&mut out, other)?;
        }
        self.fresh_loans(&mut out);
        if !incoming.ty.copy() {
            self.remove(value);
        }
        for (p, old) in reference.targets.iter().zip(&olds) {
            let mut next = incoming.clone();
            retain_loans(&mut next, old);
            rename_owned(&mut next, &p.base, &p.path);
            self.replace_target(p, next)?;
        }
        self.put(dst, out)?;
        for old in olds {
            self.retire_targets(&old);
        }
        Ok(())
    }
}
pub(super) fn rename_owned(v: &mut Value, base: &Root, path: &[usize]) {
    if v.ty.owned() {
        v.roots = BTreeSet::from([match base {
            Root::Local(r, b) => {
                let mut q = b.clone();
                q.extend(path);
                Root::Local(*r, q)
            }
            Root::Param(i, b) => {
                let mut q = b.clone();
                q.extend(path);
                Root::Param(*i, q)
            }
        }]);
    }
    for (i, f) in v.fields.iter_mut().enumerate() {
        if let Some(f) = f {
            let mut p = path.to_vec();
            p.push(i);
            rename_owned(f, base, &p);
        }
    }
}
pub(super) fn retain_loans(new: &mut Value, old: &Value) {
    new.loan = old.loan;
    for (a, b) in new.fields.iter_mut().zip(&old.fields) {
        if let (Some(a), Some(b)) = (a, b) {
            retain_loans(a, b);
        }
    }
}
