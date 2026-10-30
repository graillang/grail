//! Terminating paths do not participate in continuation ownership joins.
use super::*;
impl State {
    pub(super) fn validate_return(&self, r: Reg) -> Result<(), String> {
        let sig = self.signature.as_ref();
        let result = self.usable(r)?;
        if self
            .values
            .iter()
            .any(|(other, v)| v.has_heap() && *other != r)
        {
            return Err("heap owner must be ended or returned".into());
        }
        let compatible = match (&result.ty, &sig.result) {
            (Ty::Record(a, _), Ty::Record(b, _)) => a == b,
            (Ty::View(a, _), Ty::View(b, _)) | (Ty::Holder(a, _), Ty::Holder(b, _)) => a == b,
            (a, b) => a == b,
        };
        if !compatible {
            return Err("return type mismatch".into());
        }
        for (path, t) in types::leaves(&sig.result, &self.records)? {
            if let Some((mode, region)) = t.reference() {
                for root in &result.at(&path)?.roots {
                    let Root::Param(i, p) = root else {
                        return Err("local owner escapes".into());
                    };
                    let input = types::at(&sig.params[*i], p, &self.records)?;
                    let Some((m, r)) = input.reference() else {
                        return Err("invalid return origin".into());
                    };
                    if r != region || (mode == Mode::Write && m != Mode::Write) {
                        return Err("return violates written region relationship".into());
                    }
                }
            }
        }
        Ok(())
    }
    pub(super) fn merge_types(&mut self, other: &BTreeMap<Reg, Ty>) -> Result<(), String> {
        for (r, t) in other {
            if self.types.get(r).is_some_and(|old| old != t) {
                return Err("branches change register type".into());
            }
            self.types.insert(*r, t.clone());
        }
        Ok(())
    }
    pub(super) fn join(&mut self, mut yes: Self, no: Self) -> Result<(), String> {
        let next = yes.next.max(no.next);
        let mut types = yes.types.clone();
        for (r, t) in &no.types {
            if types.get(r).is_some_and(|old| old != t) {
                return Err("branches change register type".into());
            }
            types.insert(*r, t.clone());
        }
        match (yes.terminated, no.terminated) {
            (true, true) => self.terminated = true,
            (true, false) => *self = no,
            (false, true) => *self = yes,
            (false, false) => {
                if yes.resources != no.resources
                    || yes.resources.iter().any(|r| yes.values[r] != no.values[r])
                {
                    return Err("branch ownership states differ; join not yet supported".into());
                }
                yes.values
                    .retain(|r, v| v.ty != Ty::Num || no.values.contains_key(r));
                *self = yes;
            }
        }
        self.types = types;
        self.next = next;
        Ok(())
    }
    pub(super) fn loop_body(
        &mut self,
        body: &[Op],
        index: Option<Reg>,
        imports: &BTreeMap<String, Sig>,
        depth: usize,
    ) -> Result<(), String> {
        let mut inner = self.clone();
        if let Some(r) = index {
            inner.num(r)?;
        }
        inner.ops(body, imports, depth)?;
        if !inner.terminated {
            inner.validate_closed(&self.values)?;
        }
        self.merge_types(&inner.types)?;
        self.next = self.next.max(inner.next);
        Ok(())
    }
}
