//! Heap collections summarize every retained element; captures are conservative may-sets.
use super::*;
impl State {
    pub(super) fn vector_element(&self, r: Reg) -> Result<Ty, String> {
        let v = self.usable(r)?;
        let t = if let Ty::Ref(_, _, t) = &v.ty {
            t.as_ref()
        } else {
            &v.ty
        };
        if let Ty::Vector(t) = t {
            Ok((**t).clone())
        } else {
            Err("expected vector storage".into())
        }
    }
    pub(super) fn vector_new(&mut self, dst: Reg, element: &Ty) -> Result<(), String> {
        let ty = Ty::Vector(Box::new(element.clone()));
        types::validate_type(&ty, &self.layouts, self.type_parameters)?;
        let value = self.initialized_value(&ty, dst, &mut Vec::new())?;
        self.put(dst, value)
    }
    fn vector_places(&self, owner: Reg) -> Result<Vec<reference::Place>, String> {
        self.vector_element(owner)?;
        let v = self.usable(owner)?;
        if let Ty::Ref(mode, _, _) = &v.ty {
            if *mode != Mode::Write {
                return Err("vector mutation requires mutable storage".into());
            }
            Ok(v.targets.iter().cloned().collect())
        } else {
            if self.owner_borrowed(&v) {
                return Err("vector storage still borrowed".into());
            }
            Ok(vec![reference::Place {
                base: Root::Local(owner, vec![]),
                path: vec![],
            }])
        }
    }
    pub(super) fn vector_push(&mut self, dst: Reg, owner: Reg, value: Reg) -> Result<(), String> {
        let places = self.vector_places(owner)?;
        let incoming = self.usable(value)?;
        if self.owner_borrowed(&incoming) {
            return Err("vector push moves borrowed element".into());
        }
        let mut updates = Vec::new();
        for place in places {
            let mut v = self.target(&place)?.clone();
            let summary = v.fields[0].as_mut().ok_or("vector summary missing")?;
            let mut item = incoming.clone();
            self.coerce_value(&mut item, &witness::Instance::of(summary))?;
            reference::retain_loans(&mut item, summary);
            let mut path = place.path.clone();
            path.push(0);
            reference::rename_owned(&mut item, &place.base, &path);
            self.merge_value(summary, &item)?;
            updates.push((place, v));
        }
        if !incoming.ty.copy() {
            self.remove(value);
        }
        for (place, v) in updates {
            self.replace_vector(&place, v)?;
        }
        let unit = self.new_value(Ty::Unit, BTreeSet::new(), BTreeSet::new());
        self.put(dst, unit)
    }
    pub(super) fn vector_pop(&mut self, dst: Reg, owner: Reg) -> Result<(), String> {
        let places = self.vector_places(owner)?;
        let mut out = None;
        for place in places {
            let item = self.target(&place)?.fields[0]
                .as_ref()
                .ok_or("vector summary missing")?
                .clone();
            if let Some(previous) = &mut out {
                self.merge_value(previous, &item)?;
            } else {
                out = Some(item);
            }
        }
        let mut out = out.ok_or("vector target missing")?;
        self.fresh_loans(&mut out);
        self.put(dst, out)
    }
    fn replace_vector(&mut self, place: &reference::Place, value: Value) -> Result<(), String> {
        // Replacement changes only the summary of the same allocation, not its frame identity.
        let old = self.target(place)?.clone();
        self.index_remove(&old);
        self.index_add(&value);
        match &place.base {
            Root::Local(r, _) => {
                *self
                    .values
                    .get_mut(r)
                    .ok_or("dead vector")?
                    .at_mut(&place.path)? = value
            }
            Root::Param(..) => {
                *self
                    .memory
                    .get_mut(&place.base)
                    .ok_or("dead external vector")?
                    .at_mut(&place.path)? = value
            }
        }
        Ok(())
    }
}
