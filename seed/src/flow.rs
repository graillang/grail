//! Terminating paths do not participate in continuation ownership joins.
use super::*;
#[derive(Clone, Debug)]
pub(super) struct LoopFrame {
    pub(super) values: BTreeMap<Reg, Value>,
    defined: Vec<u64>,
}
impl State {
    pub(super) fn enter_loop(&mut self, index: Option<Reg>) -> Result<(), String> {
        self.loops.push(std::rc::Rc::new(LoopFrame {
            values: self.values.clone(),
            defined: self.copy_defined.clone(),
        }));
        if let Some(r) = index {
            self.num(r)?;
        }
        Ok(())
    }
    pub(super) fn validate_loop_exit(&self) -> Result<(), String> {
        let frame = self.loops.last().ok_or("loop exit outside loop body")?;
        self.validate_closed(&frame.values)
            .map_err(|e| format!("loop exit violates entry state: {e}"))?;
        for (index, word) in frame.defined.iter().enumerate() {
            if word & !self.copy_defined.get(index).copied().unwrap_or(0) != 0 {
                return Err("loop exit loses entry scalar definition".into());
            }
        }
        Ok(())
    }

    pub(super) fn copy_defined(&self, r: Reg) -> bool {
        self.copy_defined
            .get(r as usize / 64)
            .is_some_and(|word| word & (1u64 << (r % 64)) != 0)
    }
    pub(super) fn mark_copy(&mut self, r: Reg, defined: bool) {
        let index = r as usize / 64;
        if defined && self.copy_defined.len() <= index {
            self.copy_defined.resize(index + 1, 0);
        }
        if let Some(word) = self.copy_defined.get_mut(index) {
            if defined {
                *word |= 1u64 << (r % 64);
            } else {
                *word &= !(1u64 << (r % 64));
            }
        }
    }
    pub(super) fn prune_scalars(&mut self, live: &BTreeSet<Reg>) {
        self.values.retain(|r, v| {
            if v.ty.copy() && !self.addressed.contains(r) {
                debug_assert!(v.roots.is_empty() && v.ancestors.is_empty() && v.fields.is_empty());
                live.contains(r)
            } else {
                true
            }
        });
    }
    pub(super) fn scalars(&self) -> BTreeSet<Reg> {
        self.values
            .iter()
            .filter_map(|(r, v)| v.ty.copy().then_some(*r))
            .collect()
    }
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
        let compatible = aggregate::compatible(&result.ty, &sig.result);
        if !compatible {
            return Err("return type mismatch".into());
        }
        for source in provenance::sources(&sig.result, &self.layouts)? {
            let (mode, region) = source.ty.reference().expect("reference source");
            for value in self.path_values(&result, &source.path)? {
                for root in &value.roots {
                    let Root::Param(i, path) = root else {
                        return Err("local owner escapes".into());
                    };
                    let input = types::at(&sig.params[*i], path, &self.layouts)?;
                    let Some((m, r)) = input.reference() else {
                        return Err("invalid return origin".into());
                    };
                    if !self.regions.outlives(r, region)
                        || (mode == Mode::Write && m != Mode::Write)
                    {
                        return Err(
                            "return violates written region relationship or outer frame".into()
                        );
                    }
                }
            }
        }
        Ok(())
    }
    pub(super) fn join(&mut self, mut yes: Self, no: Self) -> Result<(), String> {
        let next = yes.next.max(no.next);
        debug_assert!(
            std::rc::Rc::ptr_eq(&self.types, &yes.types)
                && std::rc::Rc::ptr_eq(&self.types, &no.types)
        );
        match (yes.terminated, no.terminated) {
            (true, true) => self.terminated = true,
            (true, false) => *self = no,
            (false, true) => *self = yes,
            (false, false) => {
                if yes.memory != no.memory {
                    return Err("branch external storage states differ".into());
                }
                if yes.resources != no.resources
                    || yes.resources.iter().any(|r| yes.values[r] != no.values[r])
                {
                    return Err("branch ownership states differ; join not yet supported".into());
                }
                yes.values
                    .retain(|r, v| !v.ty.copy() || no.values.contains_key(r));
                for (index, word) in yes.copy_defined.iter_mut().enumerate() {
                    *word &= no.copy_defined.get(index).copied().unwrap_or(0);
                }
                *self = yes;
            }
        }
        self.next = next;
        Ok(())
    }
    pub(super) fn loop_body(
        &mut self,
        body: &[Op],
        index: Option<Reg>,
        imports: &BTreeMap<String, Sig>,
        depth: usize,
        out: Option<&BTreeSet<Reg>>,
    ) -> Result<(), String> {
        let mut inner = self.clone();
        inner.enter_loop(index)?;
        let live = out.map(|out| {
            let mut live = inner.scalars();
            live.extend(out);
            live
        });
        inner.ops_inner(body, imports, depth, live.as_ref())?;
        if !inner.terminated {
            inner.validate_closed(&self.values)?;
        }
        self.next = self.next.max(inner.next);
        Ok(())
    }
}

pub(crate) fn terminates(ops: &[Op]) -> bool {
    match ops.last() {
        Some(Op::Return(_) | Op::Break | Op::Continue) => true,
        Some(Op::Block { body }) => terminates(body),
        Some(Op::If { yes, no, .. }) => terminates(yes) && terminates(no),
        Some(Op::Match { arms, .. }) => {
            !arms.is_empty() && arms.iter().all(|a| terminates(&a.body))
        }
        _ => false,
    }
}

pub(super) fn live_before(op: &Op, after: &BTreeSet<Reg>) -> BTreeSet<Reg> {
    let mut live = after.clone();
    let (defs, uses): (Vec<Reg>, Vec<Reg>) = match op {
        Op::Address { dst, src, .. } | Op::Load { dst, src } => (vec![*dst], vec![*src]),
        Op::Exchange { dst, src, value } => (vec![*dst], vec![*src, *value]),
        Op::Return(r) => return BTreeSet::from([*r]),
        Op::Break | Op::Continue => return live,
        Op::Unit(r) => (vec![*r], vec![]),
        Op::Variant { dst, payload, .. } => (vec![*dst], payload.iter().copied().collect()),
        Op::Unwrap { dst, src } => (vec![*dst], vec![*src]),
        Op::Match { src, arms } => {
            live.clear(); // Arm bindings are definitions, not live-in values.
            for arm in arms {
                let mut arm_live = after.clone();
                for op in arm.body.iter().rev() {
                    arm_live = live_before(op, &arm_live);
                }
                if let Some(r) = arm.binding {
                    arm_live.remove(&r);
                }
                live.extend(arm_live);
            }
            live.insert(*src);
            return live;
        }
        Op::Record { dst, fields, .. } => (vec![*dst], fields.iter().map(|(_, r)| *r).collect()),
        Op::FieldMove { dst, src, .. } | Op::FieldBorrow { dst, src, .. } => {
            (vec![*dst], vec![*src])
        }
        Op::EndCaptures(src) => (vec![], vec![*src]),
        Op::Num(r, _)
        | Op::Buffer { dst: r, .. }
        | Op::Bytes { dst: r }
        | Op::TextLiteral { dst: r, .. } => (vec![*r], vec![]),
        Op::Borrow { dst, src, .. }
        | Op::Move { dst, src }
        | Op::Pack { dst, src }
        | Op::Len { dst, src }
        | Op::CopyBytes { dst, src }
        | Op::Text { dst, src } => (vec![*dst], vec![*src]),
        Op::Slice {
            dst,
            src,
            start,
            end,
        } => (vec![*dst], vec![*src, *start, *end]),
        Op::End(r) => (vec![*r], vec![*r]),
        Op::Assert(r) => (vec![], vec![*r]),
        Op::AppendText { owner, src } => (vec![], vec![*owner, *src]),
        Op::Push { owner, value } => (vec![], vec![*owner, *value]),
        Op::Read { dst, src, index } => (vec![*dst], vec![*src, *index]),
        Op::Write { dst, index, value } => (vec![], vec![*dst, *index, *value]),
        Op::Binary {
            dst, left, right, ..
        } => (vec![*dst], vec![*left, *right]),
        Op::Call { dst, args, .. } | Op::GenericCall { dst, args, .. } => {
            (vec![*dst], args.clone())
        }
        Op::If { condition, yes, no } => {
            live = before(yes, after);
            live.extend(before(no, after));
            live.insert(*condition);
            return live;
        }
        Op::Block { body } => return before(body, after),
        Op::While {
            condition,
            test,
            body,
        } => {
            loop {
                let mut exit = before(body, &live);
                exit.extend(after);
                exit.insert(*condition);
                let mut next = live.clone();
                next.extend(before(test, &exit));
                if next == live {
                    break;
                }
                live = next;
            }
            return live;
        }
        Op::Loop { index, end, body } => {
            loop {
                let mut next = live.clone();
                next.extend(before(body, &live));
                next.remove(index);
                if next == live {
                    break;
                }
                live = next;
            }
            live.insert(*end);
            return live;
        }
    };
    for r in defs {
        live.remove(&r);
    }
    live.extend(uses);
    live
}
fn before(ops: &[Op], after: &BTreeSet<Reg>) -> BTreeSet<Reg> {
    ops.iter()
        .rev()
        .fold(after.clone(), |live, op| live_before(op, &live))
}

pub(super) fn afters(ops: &[Op], out: &BTreeSet<Reg>) -> Vec<BTreeSet<Reg>> {
    let mut result = Vec::with_capacity(ops.len());
    let mut live = out.clone();
    for op in ops.iter().rev() {
        result.push(live.clone());
        live = live_before(op, &live);
    }
    result.reverse();
    result
}

/// Exits for the immediately enclosing loop; nested loops establish their own targets.
pub(crate) fn loop_jumps(ops: &[Op]) -> (bool, bool) {
    let (mut breaks, mut continues) = (false, false);
    for op in ops {
        let (b, c) = match op {
            Op::Break => (true, false),
            Op::Continue => (false, true),
            Op::Block { body } => loop_jumps(body),
            Op::If { yes, no, .. } => {
                let (a, b) = loop_jumps(yes);
                let (c, d) = loop_jumps(no);
                (a || c, b || d)
            }
            Op::Match { arms, .. } => arms
                .iter()
                .map(|a| loop_jumps(&a.body))
                .fold((false, false), |(a, b), (c, d)| (a || c, b || d)),
            _ => (false, false),
        };
        breaks |= b;
        continues |= c;
    }
    (breaks, continues)
}
