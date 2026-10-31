//! Field-sensitive values. Owned storage roots are separate from reference captures.
use super::*;
impl Value {
    pub(super) fn at(&self, path: &[usize]) -> Result<&Self, String> {
        let mut v = self;
        for i in path {
            v = v
                .fields
                .get(*i)
                .and_then(Option::as_ref)
                .ok_or("field moved or undefined")?;
        }
        Ok(v)
    }
    pub(super) fn at_mut(&mut self, path: &[usize]) -> Result<&mut Self, String> {
        let mut v = self;
        for i in path {
            v = v
                .fields
                .get_mut(*i)
                .and_then(Option::as_mut)
                .ok_or("field moved or undefined")?;
        }
        Ok(v)
    }
    pub(super) fn has_heap(&self) -> bool {
        self.ty.heap()
            || matches!(self.ty, Ty::Param(_))
            || self.fields.iter().flatten().any(Self::has_heap)
    }
}
impl State {
    pub(super) fn usable_value(&self, v: &Value) -> Result<(), String> {
        if !v.active || self.blocked.contains_key(&v.loan) {
            return Err("value/field expired or restricted by live child".into());
        }
        for field in &v.fields {
            self.usable_value(field.as_ref().ok_or("partially moved record")?)?;
        }
        Ok(())
    }
    pub(super) fn index_add(&mut self, v: &Value) {
        for p in v.targets.iter().filter(|_| v.active) {
            if let Root::Local(r, _) = p.base
                && p.path.is_empty()
                && self.values.get(&r).is_some_and(|v| v.ty.copy())
            {
                self.addressed.insert(r);
                self.resources.insert(r);
            }
        }
        if v.active {
            if let Some((mode, _)) = v.ty.reference() {
                for root in &v.roots {
                    let c = self.access.entry(root.clone()).or_default();
                    if mode == Mode::Read {
                        c.0 += 1
                    } else {
                        c.1 += 1
                    }
                }
            }
            for a in &v.ancestors {
                *self.blocked.entry(*a).or_default() += 1;
            }
        }
        for f in v.fields.iter().flatten() {
            self.index_add(f);
        }
    }
    pub(super) fn index_remove(&mut self, v: &Value) {
        if v.active {
            if let Some((mode, _)) = v.ty.reference() {
                for root in &v.roots {
                    let c = self.access.get_mut(root).expect("indexed root");
                    if mode == Mode::Read {
                        c.0 -= 1
                    } else {
                        c.1 -= 1
                    }
                    if *c == (0, 0) {
                        self.access.remove(root);
                    }
                }
            }
            for a in &v.ancestors {
                let n = self.blocked.get_mut(a).expect("indexed ancestor");
                *n -= 1;
                if *n == 0 {
                    self.blocked.remove(a);
                }
            }
        }
        for f in v.fields.iter().flatten() {
            self.index_remove(f);
        }
    }
    pub(super) fn parameter_value(
        &mut self,
        t: &Ty,
        input: usize,
        path: &mut Vec<usize>,
    ) -> Result<Value, String> {
        let roots = if t.reference().is_some() || t.owned() {
            BTreeSet::from([Root::Param(input, path.clone())])
        } else {
            BTreeSet::new()
        };
        let mut v = self.new_value(t.clone(), roots, BTreeSet::new());
        if matches!(t, Ty::Named(..)) {
            for (i, (_, field)) in types::fields(t, &self.layouts)?.iter().enumerate() {
                path.push(i);
                v.fields
                    .push(Some(self.parameter_value(field, input, path)?));
                path.pop();
            }
        }
        if let Ty::Ref(_, _, inner) = t {
            let base = Root::Param(input, path.clone());
            let target = self.parameter_value(inner, input, path)?;
            self.memory.insert(base.clone(), target);
            v.targets.insert(reference::Place { base, path: vec![] });
        }
        Ok(v)
    }
    pub(super) fn borrow_value(&mut self, p: Value, mode: Mode) -> Result<Value, String> {
        self.usable_value(&p)?;
        if p.ty == Ty::Text && mode == Mode::Write {
            return Err("string bytes cannot be mutably borrowed".into());
        }
        let mut ancestors = p.ancestors.clone();
        let region = if matches!(p.ty, Ty::Bytes | Ty::Text | Ty::Buffer) {
            for root in &p.roots {
                let (r, w) = self.access.get(root).copied().unwrap_or_default();
                if w > 0 || (mode == Mode::Write && r > 0) {
                    return Err("conflicting owner access".into());
                }
            }
            0
        } else {
            let (m, r) =
                p.ty.reference()
                    .ok_or("byte borrow needs byte storage/view")?;
            if mode == Mode::Write && m != Mode::Write {
                return Err("write reborrow from read view".into());
            }
            // Valid existing references provide authority independently of lifetime-origin may-sets.
            // Exclusive descendants freeze their parent capability; shared derivation copies descriptors.
            if m == Mode::Write {
                ancestors.insert(p.loan);
            }
            r
        };
        Ok(self.new_value(Ty::View(mode, region), p.roots, ancestors))
    }
    pub(super) fn field_move(&mut self, dst: Reg, src: Reg, path: &[String]) -> Result<(), String> {
        if path.is_empty() || dst == src {
            return Err("invalid field move".into());
        }
        if matches!(self.get(src)?.ty, Ty::Ref(..)) {
            return self.load_reference_field(dst, src, path);
        }
        let (indices, _) = types::project(&self.get(src)?.ty, path, &self.layouts)?;
        let v = self.get(src)?.at(&indices)?.clone();
        if self.place_borrowed(src, &indices, v.ty.copy()) {
            return Err("field storage still borrowed".into());
        }
        self.usable_value(&v)?;
        if v.ty.owned() && self.owner_borrowed(&v) {
            return Err("move of borrowed field".into());
        }
        if !v.ty.copy() {
            self.index_remove(&v);
            let last = *indices.last().unwrap();
            let parent = self
                .values
                .get_mut(&src)
                .unwrap()
                .at_mut(&indices[..indices.len() - 1])?;
            parent.fields[last] = None;
        }
        self.put(dst, v)
    }
    pub(super) fn expire_captures(&mut self, r: Reg) -> Result<bool, String> {
        fn paths(v: &Value, path: &mut Vec<usize>, out: &mut Vec<Vec<usize>>) {
            if v.ty.reference().is_some() && v.active {
                out.push(path.clone());
            }
            for (i, f) in v.fields.iter().enumerate() {
                if let Some(f) = f {
                    path.push(i);
                    paths(f, path, out);
                    path.pop();
                }
            }
        }
        if !matches!(self.get(r)?.ty, Ty::Named(..)) {
            return Err("capture ending expects record".into());
        }
        let mut todo = Vec::new();
        paths(self.get(r)?, &mut Vec::new(), &mut todo);
        let mut changed = false;
        for path in todo {
            let v = self.get(r)?.at(&path)?.clone();
            if self.usable_value(&v).is_ok() {
                self.index_remove(&v);
                self.retire_targets(&v);
                self.values.get_mut(&r).unwrap().at_mut(&path)?.active = false;
                changed = true;
            }
        }
        Ok(changed)
    }
    pub(super) fn record_value(
        &mut self,
        dst: Reg,
        ty: &Ty,
        fields: &[(String, Reg)],
    ) -> Result<(), String> {
        types::validate_type(ty, &self.layouts, self.type_parameters)?;
        self.validate_kind(ty)?;
        let Ty::Named(name, _, _) = ty else {
            return Err("record constructor needs nominal type".into());
        };
        let kind = self
            .layouts
            .get(name)
            .ok_or("unknown record constructor")?
            .kind;
        let layout = types::fields(ty, &self.layouts)?;
        if fields.len() != layout.len() {
            return Err("record constructor field count".into());
        }
        if kind != types::Kind::Record {
            return Err("enum needs a variant constructor".into());
        }
        let mut values = vec![None; layout.len()];
        let mut consumed = BTreeSet::new();
        for (name, r) in fields {
            let (i, (_, expected)) = layout
                .iter()
                .enumerate()
                .find(|(_, f)| f.0 == *name)
                .ok_or("unknown constructor field")?;
            let v = self.usable(*r)?;
            if values[i].is_some() || !compatible(&v.ty, expected) {
                return Err("duplicate/mismatched constructor field".into());
            }
            if v.ty.owned() && self.owner_borrowed(&v) {
                return Err("construct from borrowed owner".into());
            }
            if !v.ty.copy() && !consumed.insert(*r) {
                return Err("affine constructor field duplicated".into());
            }
            values[i] = Some(v);
        }
        for r in consumed {
            self.remove(r);
        }
        let mut v = self.new_value(
            ty.clone(),
            BTreeSet::from([Root::Local(dst, vec![])]),
            BTreeSet::new(),
        );
        v.fields = values;
        self.put(dst, v)
    }
    pub(super) fn result_value(
        &mut self,
        t: &Ty,
        dst: Reg,
        path: &mut Vec<usize>,
        inputs: &[(Ty, Value)],
    ) -> Result<Value, String> {
        let mut roots = BTreeSet::new();
        let mut ancestors = BTreeSet::new();
        if let Some((mode, region)) = t.reference() {
            for (ty, value) in inputs {
                for (p, leaf) in types::leaves(ty, &self.layouts)? {
                    if leaf.reference().is_some_and(|(m, r)| {
                        r == region && (mode == Mode::Read || m == Mode::Write)
                    }) {
                        let v = value.at(&p)?;
                        roots.extend(v.roots.clone());
                        ancestors.extend(v.ancestors.clone());
                    }
                }
            }
        } else if t.owned() {
            roots.insert(Root::Local(dst, path.clone()));
        }
        let mut v = self.new_value(t.clone(), roots, ancestors);
        if let Ty::Ref(mode, region, target) = t {
            for (ty, value) in inputs {
                for (path, leaf) in types::leaves(ty, &self.layouts)? {
                    if let Ty::Ref(m, r, inner) = leaf
                        && r == *region
                        && (*mode == Mode::Read || m == Mode::Write)
                    {
                        let input = value.at(&path)?;
                        for p in &input.targets {
                            self.matching_places(p, &inner, target, &mut v.targets)?;
                        }
                    }
                }
            }
        }
        if matches!(t, Ty::Named(..)) {
            for (i, (_, field)) in types::fields(t, &self.layouts)?.iter().enumerate() {
                path.push(i);
                v.fields
                    .push(Some(self.result_value(field, dst, path, inputs)?));
                path.pop();
            }
        }
        Ok(v)
    }
}
pub(super) fn compatible(a: &Ty, b: &Ty) -> bool {
    match (a, b) {
        (Ty::Named(a, _, xs), Ty::Named(b, _, ys)) => {
            a == b && xs.len() == ys.len() && xs.iter().zip(ys).all(|(x, y)| compatible(x, y))
        }
        (Ty::Ref(a, _, x), Ty::Ref(b, _, y)) => a == b && compatible(x, y),
        (Ty::View(a, _), Ty::View(b, _)) | (Ty::Holder(a, _), Ty::Holder(b, _)) => a == b,
        _ => a == b,
    }
}
