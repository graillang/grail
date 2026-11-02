//! Terminating paths do not participate in continuation ownership joins.
use super::*;
#[derive(Clone, Debug)]
pub(super) struct LoopFrame {
    pub(super) values: BTreeMap<Reg, Value>,
    memory: BTreeMap<Root, Value>,
    defined: Vec<u64>,
    resources: BTreeSet<Reg>,
    declared: BTreeSet<Reg>,
    live_loans: BTreeSet<usize>,
    backs: std::cell::RefCell<Option<State>>,
    breaks: std::cell::RefCell<Option<State>>,
}
impl State {
    pub(super) fn enter_loop(&mut self, index: Option<Reg>) -> Result<(), String> {
        self.loops.push(std::rc::Rc::new(LoopFrame {
            values: self.values.clone(),
            memory: self.memory.clone(),
            defined: self.copy_defined.clone(),
            resources: self.resources.union(&self.declared).copied().collect(),
            declared: self.declared.clone(),
            live_loans: self.live_loans(),
            backs: Default::default(),
            breaks: Default::default(),
        }));
        if let Some(r) = index {
            self.num(r)?;
        }
        Ok(())
    }
    pub(super) fn record_loop_exit(&self, is_break: bool) -> Result<(), String> {
        let frame = self
            .loops
            .last()
            .ok_or("loop exit outside loop body")?
            .clone();
        let edge = self.clone().loop_edge(&frame)?;
        Self::collect_edge(
            if is_break {
                &frame.breaks
            } else {
                &frame.backs
            },
            edge,
        )
    }
    fn collect_edge(into: &std::cell::RefCell<Option<State>>, edge: State) -> Result<(), String> {
        let mut into = into.borrow_mut();
        if let Some(previous) = into.take() {
            let mut merged = previous.clone();
            merged.join(previous, edge)?;
            *into = Some(merged);
        } else {
            *into = Some(edge);
        }
        Ok(())
    }
    fn live_loans(&self) -> BTreeSet<usize> {
        fn walk(v: &Value, out: &mut BTreeSet<usize>) {
            if v.active && v.ty.reference().is_some() {
                out.insert(v.loan);
            }
            for f in v.fields.iter().flatten() {
                walk(f, out);
            }
        }
        let mut out = BTreeSet::new();
        for v in self.values.values().chain(self.memory.values()) {
            walk(v, &mut out);
        }
        out
    }
    fn normalize_ancestors(&mut self, live: &BTreeSet<usize>) {
        fn walk(v: &mut Value, live: &BTreeSet<usize>) -> bool {
            let before = v.ancestors.len();
            v.ancestors.retain(|id| live.contains(id));
            let mut changed = before != v.ancestors.len();
            for f in v.fields.iter_mut().flatten() {
                changed |= walk(f, live);
            }
            changed
        }
        let mut changed = false;
        for v in self.values.values_mut().chain(self.memory.values_mut()) {
            changed |= walk(v, live);
        }
        if changed {
            self.rebuild_indices();
        }
    }
    fn loop_edge(mut self, frame: &LoopFrame) -> Result<Self, String> {
        if !self.resources.is_subset(&frame.resources) || self.memory.keys().ne(frame.memory.keys())
        {
            return Err("loop exit changes retained resource initialization".into());
        }
        for (r, before) in &frame.values {
            if let Some(after) = self.values.get(r) {
                self.same_position(before, after)?;
            }
        }
        for (p, before) in &frame.memory {
            self.same_position(before, &self.memory[p])?;
        }
        for (index, word) in frame.defined.iter().enumerate() {
            if word & !self.copy_defined.get(index).copied().unwrap_or(0) != 0 {
                return Err("loop exit loses entry scalar definition".into());
            }
        }
        self.values
            .retain(|r, _| frame.values.contains_key(r) || frame.declared.contains(r));
        self.declared = frame.declared.clone();
        // Non-reference IDs have no authority; canonicalize them to the retained storage position.
        for (r, value) in &mut self.values {
            if let Some(before) = frame.values.get(r) {
                reference::retain_loans(value, before);
            }
        }
        for (p, value) in &mut self.memory {
            reference::retain_loans(value, &frame.memory[p]);
        }
        self.copy_defined = frame.defined.clone();
        self.loops.pop();
        self.normalize_ancestors(&frame.live_loans);
        self.terminated = false;
        Ok(self)
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
        let mut result = self.usable(r)?;
        self.coerce_value(
            &mut result,
            &witness::Instance::formal(&self.signature.result),
        )?;
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
                if yes.memory.keys().ne(no.memory.keys()) {
                    return Err("branch external storage states differ".into());
                }
                for (p, value) in &mut yes.memory {
                    self.join_value(value, &no.memory[p])?;
                }
                // Keep the may-initialized state for cleanup and loan safety, but expose only
                // definitely initialized values to ordinary operations.
                let keys = yes
                    .values
                    .keys()
                    .chain(no.values.keys())
                    .copied()
                    .collect::<BTreeSet<_>>();
                for r in keys {
                    match (yes.values.get_mut(&r), no.values.get(&r)) {
                        (Some(a), Some(b)) => {
                            self.join_value(a, b)?;
                        }
                        (Some(a), None) => {
                            a.initialized = false;
                        }
                        (None, Some(b)) => {
                            let mut b = b.clone();
                            b.initialized = false;
                            yes.values.insert(r, b);
                        }
                        (None, None) => unreachable!(),
                    }
                }
                yes.declared = yes.declared.intersection(&no.declared).copied().collect();
                yes.rebuild_indices();
                for (index, word) in yes.copy_defined.iter_mut().enumerate() {
                    *word &= no.copy_defined.get(index).copied().unwrap_or(0);
                }
                *self = yes;
            }
        }
        self.next = next;
        Ok(())
    }
    fn same_position(&self, a: &Value, b: &Value) -> Result<(), String> {
        if a == b {
            return Ok(());
        }
        if a.ty != b.ty
            || a.fields.len() != b.fields.len()
            || (a.ty.reference().is_some() && a.loan != b.loan)
            || !self.instance_fits(&witness::Instance::of(a), &witness::Instance::of(b), true)?
        {
            return Err(
                "control flow changes capture slot initialization, lifetime or capability identity"
                    .into(),
            );
        }
        for (a, b) in a.fields.iter().zip(&b.fields) {
            match (a, b) {
                (Some(a), Some(b)) => self.same_position(a, b)?,
                (None, None) => (),
                _ => (),
            }
        }
        Ok(())
    }
    fn join_value(&self, value: &mut Value, other: &Value) -> Result<bool, String> {
        self.same_position(value, other)?;
        // Initialization is an intersection; capture roots and authority restrictions are unions.
        let mut changed = false;
        let initialized = value.initialized && other.initialized && value.active == other.active;
        if value.initialized != initialized {
            value.initialized = initialized;
            changed = true;
        }
        if !value.active && other.active {
            value.active = true;
            changed = true;
        }
        let before = value.roots.len() + value.ancestors.len() + value.targets.len();
        value.roots.extend(other.roots.clone());
        value.ancestors.extend(other.ancestors.clone());
        value.targets.extend(other.targets.clone());
        if value.roots.len() > 4096 || value.ancestors.len() > 4096 || value.targets.len() > 4096 {
            return Err("capture union expansion limit".into());
        }
        changed |= before != value.roots.len() + value.ancestors.len() + value.targets.len();
        for (a, b) in value.fields.iter_mut().zip(&other.fields) {
            match (a.as_mut(), b) {
                (Some(a), Some(b)) => {
                    changed |= self.join_value(a, b)?;
                }
                (Some(a), None) => {
                    changed |= a.initialized;
                    a.initialized = false;
                }
                (None, Some(b)) => {
                    let mut b = b.clone();
                    b.initialized = false;
                    *a = Some(b);
                    changed = true;
                }
                (None, None) => (),
            }
        }
        Ok(changed)
    }
    fn rebuild_indices(&mut self) {
        self.access.clear();
        self.blocked.clear();
        self.addressed.clear();
        self.resources = self
            .values
            .iter()
            .filter_map(|(r, v)| (!v.ty.copy()).then_some(*r))
            .collect();
        let values = self
            .values
            .values()
            .chain(self.memory.values())
            .cloned()
            .collect::<Vec<_>>();
        for value in values {
            self.index_add(&value);
        }
    }
    pub(super) fn loop_op(
        &mut self,
        op: &Op,
        imports: &BTreeMap<String, Sig>,
        depth: usize,
        out: Option<&BTreeSet<Reg>>,
    ) -> Result<(), String> {
        let (body, index, test) = match op {
            Op::Loop { index, end, body } => {
                self.require_num(*end)?;
                if index == end || self.values.contains_key(index) || self.copy_defined(*index) {
                    return Err("loop index must be fresh".into());
                }
                (body.as_slice(), Some(*index), None)
            }
            Op::While {
                condition,
                test,
                body,
            } => (body.as_slice(), None, Some((*condition, test.as_slice()))),
            _ => return Err("expected loop operation".into()),
        };
        let mut entry = self.clone();
        let live_loans = entry.live_loans();
        entry.normalize_ancestors(&live_loans);
        let mut header = entry.clone();
        let mut next = entry.next;
        for _ in 0..4096 {
            let mut inner = header.clone();
            inner.enter_loop(index)?;
            let frame = inner.loops.last().expect("loop frame").clone();
            let condition_exit = if let Some((condition, test)) = test {
                let mut live = inner.scalars();
                if let Some(out) = out {
                    live.extend(out);
                }
                live.insert(condition);
                let loops = std::mem::take(&mut inner.loops);
                inner.ops_inner(test, imports, depth, Some(&live))?;
                inner.loops = loops;
                if inner.terminated {
                    return Err("return in loop condition".into());
                }
                inner.require_num(condition)?;
                Some(inner.clone().loop_edge(&frame)?)
            } else {
                None
            };
            let live = out.map(|out| {
                let mut live = live_before(op, out);
                live.extend(out);
                live.extend(inner.scalars());
                live
            });
            match &live {
                Some(l) => in_loop_body(l, || inner.ops_inner(body, imports, depth, Some(l)))?,
                None => inner.ops_inner(body, imports, depth, None)?,
            }
            next = next.max(inner.next);
            if !inner.terminated {
                let edge = inner.loop_edge(&frame)?;
                Self::collect_edge(&frame.backs, edge)?;
            }
            let mut widened = entry.clone();
            if let Some(back) = frame.backs.borrow_mut().take()
                && (back.values != entry.values || back.memory != entry.memory)
            {
                widened.join(entry.clone(), back)?;
            }
            // Temporary capabilities are alpha-local to an iteration; retained slots keep their IDs.
            widened.next = entry.next;
            if widened.values == header.values && widened.memory == header.memory {
                let mut exit = condition_exit.unwrap_or_else(|| header.clone());
                if let Some(broken) = frame.breaks.borrow_mut().take()
                    && (broken.values != exit.values || broken.memory != exit.memory)
                {
                    exit.join(exit.clone(), broken)?;
                }
                exit.next = next;
                *self = exit;
                return Ok(());
            }
            header = widened;
        }
        Err("loop capture fixed-point iteration limit".into())
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

thread_local! {
    /// Live-out sets of the enclosing loop bodies being analysed. A `break` or `continue`
    /// leaves its block, so it keeps everything the innermost loop body keeps live on exit
    /// (which covers both the loop exit and the next iteration), not the rest of its block.
    static JUMP_LIVE: std::cell::RefCell<Vec<BTreeSet<Reg>>> = const { std::cell::RefCell::new(Vec::new()) };
}
/// Runs `f` with `live` as the target liveness of `break`/`continue` in a loop body.
pub(super) fn in_loop_body<T>(live: &BTreeSet<Reg>, f: impl FnOnce() -> T) -> T {
    JUMP_LIVE.with(|s| s.borrow_mut().push(live.clone()));
    let result = f();
    JUMP_LIVE.with(|s| s.borrow_mut().pop());
    result
}
pub(super) fn live_before(op: &Op, after: &BTreeSet<Reg>) -> BTreeSet<Reg> {
    let mut live = after.clone();
    let (defs, uses): (Vec<Reg>, Vec<Reg>) = match op {
        Op::FieldAssign { dst, src, .. } => (vec![], vec![*dst, *src]),
        Op::Declare { dst, .. } => (vec![*dst], vec![]),
        Op::Assign { dst, src } => (vec![*dst], vec![*src]),
        Op::Vector { dst, .. } => (vec![*dst], vec![]),
        Op::VectorPush { dst, owner, value } => (vec![*dst], vec![*owner, *value]),
        Op::VectorPop { dst, owner } => (vec![*dst], vec![*owner]),
        Op::VectorGet {
            dst, owner, index, ..
        } => (vec![*dst], vec![*owner, *index]),
        Op::Ascribe { src, .. } => (vec![], vec![*src]),
        Op::Address { dst, src, .. } | Op::Load { dst, src } => (vec![*dst], vec![*src]),
        Op::Exchange { dst, src, value } => (vec![*dst], vec![*src, *value]),
        Op::Return(r) => return BTreeSet::from([*r]),
        Op::Break | Op::Continue => {
            JUMP_LIVE.with(|s| {
                if let Some(target) = s.borrow().last() {
                    live.extend(target);
                }
            });
            return live;
        }
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
        Op::End(r) | Op::EndIfLive(r) => (vec![*r], vec![*r]),
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
                let mut exit = in_loop_body(&live, || before(body, &live));
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
                next.extend(in_loop_body(&live, || before(body, &live)));
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

/// Register binding definitions (not End's liveness kill), shared with storage-scope accounting.
pub(super) fn definitions(op: &Op) -> Vec<Reg> {
    match op {
        Op::Declare { dst, .. }
        | Op::Assign { dst, .. }
        | Op::Vector { dst, .. }
        | Op::VectorPush { dst, .. }
        | Op::VectorPop { dst, .. }
        | Op::VectorGet { dst, .. }
        | Op::Address { dst, .. }
        | Op::Load { dst, .. }
        | Op::Exchange { dst, .. }
        | Op::Variant { dst, .. }
        | Op::Unwrap { dst, .. }
        | Op::Record { dst, .. }
        | Op::FieldMove { dst, .. }
        | Op::FieldBorrow { dst, .. }
        | Op::Buffer { dst, .. }
        | Op::Bytes { dst }
        | Op::TextLiteral { dst, .. }
        | Op::Borrow { dst, .. }
        | Op::Move { dst, .. }
        | Op::Pack { dst, .. }
        | Op::Len { dst, .. }
        | Op::CopyBytes { dst, .. }
        | Op::Text { dst, .. }
        | Op::Slice { dst, .. }
        | Op::Read { dst, .. }
        | Op::Binary { dst, .. }
        | Op::Call { dst, .. }
        | Op::GenericCall { dst, .. } => vec![*dst],
        Op::Num(r, _) | Op::Unit(r) => vec![*r],
        Op::FieldAssign { .. }
        | Op::Ascribe { .. }
        | Op::EndIfLive(_)
        | Op::End(_)
        | Op::EndCaptures(_)
        | Op::Assert(_)
        | Op::AppendText { .. }
        | Op::Push { .. }
        | Op::Write { .. }
        | Op::Return(_)
        | Op::Break
        | Op::Continue
        | Op::If { .. }
        | Op::Block { .. }
        | Op::Loop { .. }
        | Op::While { .. }
        | Op::Match { .. } => vec![],
    }
}
