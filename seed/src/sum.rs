//! Sum values track every possible payload; impossible constructor alternatives have no origins.
use super::*;
impl State {
    fn inactive_value(&mut self, t: &Ty) -> Result<Value, String> {
        let mut v = self.new_value(t.clone(), BTreeSet::new(), BTreeSet::new());
        if matches!(t, Ty::Named(..)) {
            for (_, field) in types::fields(t, &self.layouts)? {
                v.fields.push(Some(self.inactive_value(&field)?));
            }
        }
        Ok(v)
    }
    pub(super) fn variant_value(
        &mut self,
        dst: Reg,
        ty: &Ty,
        variant: usize,
        payload: Option<Reg>,
    ) -> Result<(), String> {
        types::validate_type(ty, &self.layouts, self.type_parameters)?;
        let Ty::Named(name, _, _) = ty else {
            return Err("variant constructor needs nominal type".into());
        };
        let kind = self.layouts.get(name).ok_or("unknown enum")?.kind;
        let fields = types::fields(ty, &self.layouts)?;
        if kind != types::Kind::Enum {
            return Err("variant constructor needs enum".into());
        }
        let expected = &fields.get(variant).ok_or("unknown variant")?.1;
        let actual = if let Some(r) = payload {
            let v = self.usable(r)?;
            if !aggregate::compatible(&v.ty, expected) {
                return Err("variant payload type mismatch".into());
            }
            if v.ty.owned() && self.owner_borrowed(&v) {
                return Err("move of borrowed payload".into());
            }
            if !v.ty.copy() {
                self.remove(r);
            }
            v
        } else {
            if *expected != Ty::Unit {
                return Err("missing variant payload".into());
            }
            self.inactive_value(expected)?
        };
        let mut v = self.new_value(
            ty.clone(),
            BTreeSet::from([Root::Local(dst, vec![])]),
            BTreeSet::new(),
        );
        for (i, (_, t)) in fields.iter().enumerate() {
            v.fields.push(Some(if i == variant {
                actual.clone()
            } else {
                self.inactive_value(t)?
            }));
        }
        self.put(dst, v)
    }
    pub(super) fn payload(
        &mut self,
        src: Reg,
        variant: usize,
        dst: Option<Reg>,
    ) -> Result<(), String> {
        let v = self.usable(src)?;
        if !types::is_enum(&v.ty, &self.layouts)? {
            return Err("match/unwrap needs enum".into());
        }
        let t = types::fields(&v.ty, &self.layouts)?
            .get(variant)
            .ok_or("unknown variant")?
            .1
            .clone();
        if t != Ty::Unit && dst.is_none() {
            return Err("variant pattern payload arity".into());
        }
        let payload = v.at(&[variant])?.clone();
        self.remove(src);
        if let Some(r) = dst {
            self.put(r, payload)?;
        }
        Ok(())
    }
    pub(super) fn success(&self, src: Reg) -> Result<usize, String> {
        types::success(&self.get(src)?.ty, &self.layouts)
    }
    pub(super) fn arms(&self, src: Reg, arms: &[Arm]) -> Result<Vec<usize>, String> {
        let v = self.usable(src)?;
        if !types::is_enum(&v.ty, &self.layouts)? {
            return Err("match needs enum".into());
        }
        let f = types::fields(&v.ty, &self.layouts)?;
        let mut seen = BTreeSet::new();
        let mut indices = Vec::new();
        for a in arms {
            let k = f
                .iter()
                .position(|(n, _)| *n == a.variant)
                .ok_or("unknown match variant")?;
            if !seen.insert(k) {
                return Err("duplicate match variant".into());
            }
            indices.push(k);
        }
        if seen.len() != f.len() {
            return Err("non-exhaustive match".into());
        }
        Ok(indices)
    }
}
