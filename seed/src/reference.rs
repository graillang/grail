use super::*;
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(super) struct Place {
    pub(super) base: Root,
    pub(super) path: Vec<usize>,
}
impl State {
    pub(super) fn validate_kind(&self, t: &Ty) -> Result<(), String> {
        if self.type_parameters > 0
            && !types::required_plain(t, &self.layouts)?.is_subset(&self.plain_parameters)
        {
            return Err(
                "typed-reference kind requirement is not declared by the function signature".into(),
            );
        }
        Ok(())
    }
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
    pub(super) fn matching_places(
        &self,
        p: &Place,
        t: &Ty,
        want: &Ty,
        out: &mut BTreeSet<Place>,
    ) -> Result<(), String> {
        if aggregate::compatible(t, want) {
            out.insert(p.clone());
            if out.len() > 4096 {
                return Err("typed-reference target count limit".into());
            }
        }
        if matches!(t, Ty::Named(..)) && !types::is_enum(t, &self.layouts)? {
            for (i, (_, t)) in types::fields(t, &self.layouts)?.iter().enumerate() {
                let mut p = p.clone();
                p.path.push(i);
                self.matching_places(&p, t, want, out)?;
            }
        }
        Ok(())
    }
    pub(super) fn borrow_reference_bytes(
        &mut self,
        p: &Value,
        mode: Mode,
    ) -> Result<Value, String> {
        let Ty::Ref(m, r, t) = &p.ty else {
            return Err("expected typed reference".into());
        };
        if !matches!(**t, Ty::Bytes | Ty::Text) {
            return Err("typed referent is not byte storage".into());
        }
        if mode == Mode::Write && (*m != Mode::Write || **t == Ty::Text) {
            return Err("mutable bytes need mutable byte-vector storage".into());
        }
        self.usable_value(p)?;
        let mut ancestors = p.ancestors.clone();
        if *m == Mode::Write {
            ancestors.insert(p.loan);
        }
        Ok(self.new_value(Ty::View(mode, *r), p.roots.clone(), ancestors))
    }
    pub(super) fn reference_field_bytes(
        &mut self,
        src: Reg,
        path: &[String],
        mode: Mode,
    ) -> Result<Value, String> {
        let (mut v, m, r, t) = self.reference_parts(src)?;
        let (_, field) = types::project(&t, path, &self.layouts)?;
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
    pub(super) fn writeback(&mut self, inputs: &[(Ty, Value)]) -> Result<(), String> {
        for (t, v) in inputs {
            for (path, leaf) in types::leaves(t, &self.layouts)? {
                if let Ty::Ref(Mode::Write, _, inner) = leaf {
                    for p in &v.at(&path)?.targets {
                        let old = self.target(p)?.clone();
                        let mut next = self.result_value(&inner, 0, &mut Vec::new(), &[])?;
                        retain_loans(&mut next, &old);
                        rename_owned(&mut next, &p.base, &p.path);
                        *self.target_mut(p)? = next;
                    }
                }
            }
        }
        Ok(())
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
    fn target(&self, p: &Place) -> Result<&Value, String> {
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
        self.validate_kind(&result_ty)?;
        let mut targets = BTreeSet::new();
        let mut roots = BTreeSet::new();
        for mut p in base {
            p.path.extend(&indices);
            let value = self.target(&p)?;
            self.usable_value(value)?;
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
        self.put(dst, result)
    }
    pub(super) fn load_reference(&mut self, dst: Reg, src: Reg) -> Result<(), String> {
        let (_, _, _, t) = self.reference_parts(src)?;
        if !t.copy() {
            return Err("load cannot copy affine referent; use exchange".into());
        }
        let value = self.new_value(t, BTreeSet::new(), BTreeSet::new());
        self.put(dst, value)
    }
    pub(super) fn exchange(&mut self, dst: Reg, src: Reg, value: Reg) -> Result<(), String> {
        let (reference, m, _, t) = self.reference_parts(src)?;
        if m != Mode::Write {
            return Err("exchange needs mutable typed reference".into());
        }
        let incoming = self.usable(value)?;
        if !aggregate::compatible(&t, &incoming.ty) {
            return Err("exchange value type".into());
        }
        if self.owner_borrowed(&incoming) {
            return Err("exchange moves borrowed value".into());
        }
        for p in &reference.targets {
            let old = self.target(p)?;
            self.usable_value(old)?;
        }
        if !incoming.ty.copy() {
            self.remove(value);
        }
        for p in &reference.targets {
            let mut new = incoming.clone();
            let old = self.target(p)?;
            retain_loans(&mut new, old);
            rename_owned(&mut new, &p.base, &p.path);
            *self.target_mut(p)? = new;
        }
        let out = self.result_value(&t, dst, &mut Vec::new(), &[])?;
        self.put(dst, out)
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
fn retain_loans(new: &mut Value, old: &Value) {
    new.loan = old.loan;
    for (a, b) in new.fields.iter_mut().zip(&old.fields) {
        if let (Some(a), Some(b)) = (a, b) {
            retain_loans(a, b);
        }
    }
}
