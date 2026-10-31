//! Compile-time lifetime witnesses. Region numbers are binders, never local storage lifetimes.
use super::*;
pub(super) type Scope = Vec<u32>;
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(super) enum Atom {
    Formal(u16),
    Scope(Scope),
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub(super) struct Life(BTreeSet<Atom>);
impl Life {
    pub(super) fn formal(r: u16) -> Self {
        Self(BTreeSet::from([Atom::Formal(r)]))
    }
    pub(super) fn scope(p: Scope) -> Self {
        Self(BTreeSet::from([Atom::Scope(p)]))
    }
}
pub(super) fn formal(t: &Ty) -> Vec<Life> {
    let mut out = Vec::new();
    fn walk(t: &Ty, out: &mut Vec<Life>) {
        match t {
            Ty::View(_, r) | Ty::Holder(_, r) => out.push(Life::formal(*r)),
            Ty::Ref(_, r, inner) => {
                out.push(Life::formal(*r));
                walk(inner, out);
            }
            Ty::Named(_, rs, args) => {
                out.extend(rs.iter().map(|r| Life::formal(*r)));
                for t in args {
                    walk(t, out);
                }
            }
            _ => {}
        }
    }
    walk(t, &mut out);
    out
}
pub(super) fn scopes(ops: &[Op], parameters: usize) -> Result<BTreeMap<Reg, Scope>, String> {
    fn add(out: &mut BTreeMap<Reg, Scope>, r: Reg, path: &Scope) {
        out.entry(r)
            .and_modify(|p| {
                let n = p.iter().zip(path).take_while(|(a, b)| a == b).count();
                p.truncate(n);
            })
            .or_insert_with(|| path.clone());
    }
    fn child(path: &Scope, next: &mut u32) -> Scope {
        *next += 1;
        let mut p = path.clone();
        p.push(*next);
        p
    }
    fn walk(
        ops: &[Op],
        path: &Scope,
        next: &mut u32,
        out: &mut BTreeMap<Reg, Scope>,
        nodes: &mut usize,
    ) -> Result<(), String> {
        if path.len() > 64 {
            return Err("storage scope depth limit".into());
        }
        for op in ops {
            *nodes += 1;
            if *nodes > 262144 {
                return Err("storage scope operation limit".into());
            }
            match op {
                Op::Block { body } => walk(body, &child(path, next), next, out, nodes)?,
                Op::If { yes, no, .. } => {
                    walk(yes, &child(path, next), next, out, nodes)?;
                    walk(no, &child(path, next), next, out, nodes)?;
                }
                Op::Loop { index, body, .. } => {
                    add(out, *index, path);
                    walk(body, &child(path, next), next, out, nodes)?;
                }
                Op::While { test, body, .. } => {
                    walk(test, &child(path, next), next, out, nodes)?;
                    walk(body, &child(path, next), next, out, nodes)?;
                }
                Op::Match { arms, .. } => {
                    for arm in arms {
                        let p = child(path, next);
                        if let Some(r) = arm.binding {
                            add(out, r, &p);
                        }
                        walk(&arm.body, &p, next, out, nodes)?;
                    }
                }
                _ => {
                    for r in flow::definitions(op) {
                        add(out, r, path);
                    }
                }
            }
        }
        Ok(())
    }
    let mut out = (0..parameters).map(|r| (r as Reg, vec![])).collect();
    walk(ops, &vec![], &mut 0, &mut out, &mut 0)?;
    Ok(out)
}
impl State {
    pub(super) fn install_scopes(&mut self, ops: &[Op]) -> Result<(), String> {
        self.scopes = std::sync::Arc::new(scopes(ops, self.signature.params.len())?);
        Ok(())
    }
    fn atom_outlives(&self, a: &Atom, b: &Atom) -> bool {
        match (a, b) {
            (Atom::Formal(a), Atom::Formal(b)) => self.regions.outlives(*a, *b),
            (Atom::Formal(_), Atom::Scope(_)) => true,
            (Atom::Scope(a), Atom::Scope(b)) => b.starts_with(a),
            _ => false,
        }
    }
    pub(super) fn life_outlives(&self, a: &Life, b: &Life) -> bool {
        a.0.iter()
            .all(|a| b.0.iter().any(|b| self.atom_outlives(a, b)))
    }
    pub(super) fn life_meet(&self, a: &Life, b: &Life) -> Life {
        let mut atoms = a.0.union(&b.0).cloned().collect::<BTreeSet<_>>();
        let before = atoms.clone();
        atoms.retain(|a| {
            !before
                .iter()
                .any(|b| a != b && self.atom_outlives(a, b) && (!self.atom_outlives(b, a) || a > b))
        });
        Life(atoms)
    }
    pub(super) fn roots_life(&self, roots: &BTreeSet<Root>) -> Result<Life, String> {
        let mut out = None;
        for root in roots {
            let value = match root {
                Root::Local(r, _) => {
                    Life::scope(self.scopes.get(r).cloned().ok_or("missing storage scope")?)
                }
                Root::Param(i, p) => {
                    let t = types::at(&self.signature.params[*i], p, &self.layouts)?;
                    let (_, r) = t
                        .reference()
                        .ok_or("owned external storage needs its frame lifetime")?;
                    Life::formal(r)
                }
            };
            out = Some(if let Some(a) = out {
                self.life_meet(&a, &value)
            } else {
                value
            });
        }
        Ok(out.unwrap_or_else(|| Life::scope(vec![])))
    }
}

#[derive(Clone, Debug)]
pub(super) struct Instance {
    pub(super) ty: Ty,
    pub(super) lives: Vec<Life>,
}
impl Instance {
    pub(super) fn of(v: &Value) -> Self {
        Self {
            ty: v.ty.clone(),
            lives: v.lives.clone(),
        }
    }
    pub(super) fn formal(t: &Ty) -> Self {
        Self {
            ty: t.clone(),
            lives: formal(t),
        }
    }
    pub(super) fn scoped(t: &Ty, scope: &Scope) -> Self {
        Self {
            ty: t.clone(),
            lives: formal(t)
                .into_iter()
                .map(|_| Life::scope(scope.clone()))
                .collect(),
        }
    }
    fn argument_parts(&self) -> Result<(Vec<Life>, Vec<Self>), String> {
        let Ty::Named(_, rs, args) = &self.ty else {
            return Err("nominal lifetime instance expected".into());
        };
        let mut at = rs.len();
        let head = self
            .lives
            .get(..at)
            .ok_or("nominal lifetime witness arity")?
            .to_vec();
        let mut out = Vec::new();
        for t in args {
            let n = formal(t).len();
            out.push(Self {
                ty: t.clone(),
                lives: self
                    .lives
                    .get(at..at + n)
                    .ok_or("type argument witness arity")?
                    .to_vec(),
            });
            at += n;
        }
        if at != self.lives.len() {
            return Err("nominal witness trailing slots".into());
        }
        Ok((head, out))
    }
    pub(super) fn inner(&self) -> Result<Self, String> {
        let Ty::Ref(_, _, t) = &self.ty else {
            return Err("reference lifetime instance expected".into());
        };
        Ok(Self {
            ty: (**t).clone(),
            lives: self
                .lives
                .get(1..)
                .ok_or("reference witness arity")?
                .to_vec(),
        })
    }
    pub(super) fn fields(&self, defs: &types::Definitions) -> Result<Vec<Self>, String> {
        let Ty::Named(name, rs, _) = &self.ty else {
            return Err("nominal instance expected".into());
        };
        let d = defs.get(name).ok_or("missing instance layout")?;
        let (head, args) = self.argument_parts()?;
        d.fields
            .iter()
            .map(|(_, t)| {
                apply(
                    t,
                    &|r| {
                        Ok((
                            *rs.get(r as usize).ok_or("layout lifetime slot")?,
                            head.get(r as usize).ok_or("layout witness slot")?.clone(),
                        ))
                    },
                    &|i| {
                        args.get(i as usize)
                            .cloned()
                            .ok_or_else(|| "layout type slot".into())
                    },
                )
            })
            .collect()
    }
}
fn apply(
    t: &Ty,
    region: &impl Fn(u16) -> Result<(u16, Life), String>,
    argument: &impl Fn(u16) -> Result<Instance, String>,
) -> Result<Instance, String> {
    Ok(match t {
        Ty::Param(i) => argument(*i)?,
        Ty::View(m, r) | Ty::Holder(m, r) => {
            let (n, life) = region(*r)?;
            Instance {
                ty: if matches!(t, Ty::View(..)) {
                    Ty::View(*m, n)
                } else {
                    Ty::Holder(*m, n)
                },
                lives: vec![life],
            }
        }
        Ty::Ref(m, r, inner) => {
            let (n, life) = region(*r)?;
            let inner = apply(inner, region, argument)?;
            let mut lives = vec![life];
            lives.extend(inner.lives);
            Instance {
                ty: Ty::Ref(*m, n, Box::new(inner.ty)),
                lives,
            }
        }
        Ty::Named(n, rs, args) => {
            let mut native = Vec::new();
            let mut lives = Vec::new();
            for r in rs {
                let (r, life) = region(*r)?;
                native.push(r);
                lives.push(life);
            }
            let mut values = Vec::new();
            for t in args {
                let a = apply(t, region, argument)?;
                values.push(a.ty);
                lives.extend(a.lives);
            }
            Instance {
                ty: Ty::Named(n.clone(), native, values),
                lives,
            }
        }
        _ => Instance {
            ty: t.clone(),
            lives: vec![],
        },
    })
}
#[derive(Clone, Debug, Default)]
pub(super) struct Bindings {
    pub(super) regions: BTreeMap<u16, Life>,
    pinned_regions: BTreeSet<u16>,
    pub(super) args: BTreeMap<u16, Instance>,
    pinned_args: BTreeSet<u16>,
}
impl Bindings {
    pub(super) fn explicit(args: &[Ty]) -> Self {
        let mut s = Self::default();
        for (i, t) in args.iter().enumerate() {
            s.args.insert(i as u16, Instance::formal(t));
            s.pinned_args.insert(i as u16);
        }
        s
    }
    pub(super) fn instantiate(&self, t: &Ty) -> Result<Instance, String> {
        apply(
            t,
            &|r| {
                Ok((
                    r,
                    self.regions
                        .get(&r)
                        .cloned()
                        .unwrap_or_else(|| Life::formal(r)),
                ))
            },
            &|i| {
                self.args
                    .get(&i)
                    .cloned()
                    .ok_or_else(|| "missing bound type argument".into())
            },
        )
    }
    fn region(&mut self, state: &State, r: u16, life: &Life, pin: bool) -> Result<(), String> {
        if pin {
            if let Some(old) = self.regions.get(&r)
                && self.pinned_regions.contains(&r)
                && (!state.life_outlives(old, life) || !state.life_outlives(life, old))
            {
                return Err("invariant referent lifetime mismatch".into());
            }
            self.regions.insert(r, life.clone());
            self.pinned_regions.insert(r);
        } else if !self.pinned_regions.contains(&r) {
            let life = self
                .regions
                .get(&r)
                .map(|old| state.life_meet(old, life))
                .unwrap_or_else(|| life.clone());
            self.regions.insert(r, life);
        }
        Ok(())
    }
    pub(super) fn observe(
        &mut self,
        state: &State,
        pattern: &Ty,
        actual: &Instance,
        pins_only: bool,
    ) -> Result<(), String> {
        self.walk(state, pattern, actual, (false, pins_only), 0, &mut 0)
    }
    fn walk(
        &mut self,
        state: &State,
        p: &Ty,
        a: &Instance,
        phase: (bool, bool),
        depth: usize,
        nodes: &mut usize,
    ) -> Result<(), String> {
        let (inv, pins_only) = phase;
        *nodes += 1;
        if depth > 64 || *nodes > 16384 {
            return Err("lifetime matching expansion limit".into());
        }
        if let Ty::Param(i) = p {
            if pins_only && !inv {
                return Ok(());
            }
            if inv {
                if let Some(old) = self.args.get(i)
                    && !state.instance_fits(a, old, true)?
                {
                    return Err("invariant type argument lifetime mismatch".into());
                }
                self.args.insert(*i, a.clone());
                self.pinned_args.insert(*i);
            } else if !self.pinned_args.contains(i) {
                let value = if let Some(old) = self.args.get(i) {
                    if !aggregate::compatible(&old.ty, &a.ty) || old.lives.len() != a.lives.len() {
                        return Err("conflicting bound type arguments".into());
                    }
                    let joined = Instance {
                        ty: old.ty.clone(),
                        lives: old
                            .lives
                            .iter()
                            .zip(&a.lives)
                            .map(|(x, y)| state.life_meet(x, y))
                            .collect(),
                    };
                    if !state.instance_fits(old, &joined, false)?
                        || !state.instance_fits(a, &joined, false)?
                    {
                        return Err("no common invariant type argument".into());
                    }
                    joined
                } else {
                    a.clone()
                };
                self.args.insert(*i, value);
            }
            return Ok(());
        }
        let shape = match (p, &a.ty) {
            (Ty::Ref(m, ..), Ty::Ref(n, ..)) => m == n,
            (Ty::Named(n, rs, args), Ty::Named(other, other_rs, other_args)) => {
                n == other && rs.len() == other_rs.len() && args.len() == other_args.len()
            }
            _ => aggregate::compatible(p, &a.ty),
        };
        if !shape {
            return Err("bound argument shape or mode".into());
        }
        fn parameters(t: &Ty) -> bool {
            match t {
                Ty::Param(_) => true,
                Ty::Ref(_, _, t) => parameters(t),
                Ty::Named(_, _, args) => args.iter().any(parameters),
                _ => false,
            }
        }
        if formal(p).is_empty() && !parameters(p) {
            return Ok(());
        }
        match p {
            Ty::View(_, r) | Ty::Holder(_, r) => {
                if !pins_only || inv {
                    self.region(
                        state,
                        *r,
                        a.lives.first().ok_or("reference witness absent")?,
                        inv,
                    )?;
                }
            }
            Ty::Ref(m, r, t) => {
                if !pins_only || inv {
                    self.region(
                        state,
                        *r,
                        a.lives.first().ok_or("frame witness absent")?,
                        inv,
                    )?;
                }
                self.walk(
                    state,
                    t,
                    &a.inner()?,
                    (inv || *m == Mode::Write, pins_only),
                    depth + 1,
                    nodes,
                )?;
            }
            Ty::Named(_, rs, args) => {
                let (head, values) = a.argument_parts()?;
                if !pins_only || inv {
                    for (r, v) in rs.iter().zip(&head) {
                        self.region(state, *r, v, inv)?;
                    }
                    for (t, v) in args.iter().zip(&values) {
                        self.walk(state, t, v, (inv, pins_only), depth + 1, nodes)?;
                    }
                }
                for ((_, t), v) in types::fields(p, &state.layouts)?
                    .iter()
                    .zip(a.fields(&state.layouts)?)
                {
                    self.walk(state, t, &v, (inv, pins_only), depth + 1, nodes)?;
                }
            }
            _ => {}
        }
        Ok(())
    }
}
impl State {
    pub(super) fn instance_fits(
        &self,
        a: &Instance,
        b: &Instance,
        invariant: bool,
    ) -> Result<bool, String> {
        compare(
            a,
            b,
            invariant,
            &self.layouts,
            &|a, b| self.life_outlives(a, b),
            0,
            &mut 0,
        )
    }

    pub(super) fn stamp_value(&self, v: &mut Value, want: &Instance) -> Result<(), String> {
        if !aggregate::compatible(&v.ty, &want.ty) {
            return Err("lifetime stamp changes value shape".into());
        }
        if matches!(want.ty, Ty::Named(..)) {
            for (f, bound) in v.fields.iter_mut().zip(want.fields(&self.layouts)?) {
                if let Some(f) = f {
                    self.stamp_value(f, &bound)?;
                }
            }
        }
        v.ty = want.ty.clone();
        v.lives = want.lives.clone();
        Ok(())
    }
    pub(super) fn coerce_value(&self, v: &mut Value, want: &Instance) -> Result<(), String> {
        if !aggregate::compatible(&v.ty, &want.ty) {
            return Err("lifetime coercion shape or mode".into());
        }
        if v.ty.reference().is_some() {
            if !v.roots.is_empty() || !v.targets.is_empty() {
                let lifetime = want
                    .lives
                    .first()
                    .ok_or("missing desired reference lifetime")?;
                if !self.life_outlives(&v.lives[0], lifetime)
                    && !self.life_outlives(&self.roots_life(&v.roots)?, lifetime)
                {
                    return Err("source does not outlive stored lifetime witness".into());
                }
                if let Ty::Ref(mode, ..) = v.ty {
                    if mode == Mode::Write {
                        if !self.instance_fits(&Instance::of(v).inner()?, &want.inner()?, true)? {
                            return Err("mutable referent lifetime invariance".into());
                        }
                    } else {
                        for p in &v.targets {
                            let mut value = self.target(p)?.clone();
                            self.coerce_value(&mut value, &want.inner()?)?;
                        }
                    }
                }
            }
        } else if matches!(v.ty, Ty::Named(..)) {
            for (f, bound) in v.fields.iter_mut().zip(want.fields(&self.layouts)?) {
                self.coerce_value(f.as_mut().ok_or("partially moved lifetime value")?, &bound)?;
            }
        }
        self.stamp_value(v, want)
    }
}

impl State {
    pub(super) fn constructor_witnesses(
        &self,
        dst: Reg,
        v: &mut Value,
        active: Option<usize>,
    ) -> Result<(), String> {
        let Ty::Named(name, rs, args) = &v.ty else {
            return Err("constructor lifetime shape".into());
        };
        let d = self.layouts.get(name).ok_or("constructor layout")?;
        let mut bindings = Bindings::default();
        for pins in [true, false] {
            for (i, (_, pattern)) in d.fields.iter().enumerate() {
                if active.is_none_or(|k| k == i) {
                    bindings.observe(
                        self,
                        pattern,
                        &Instance::of(v.fields[i].as_ref().ok_or("missing constructor field")?),
                        pins,
                    )?;
                }
            }
        }
        let scope = self
            .scopes
            .get(&dst)
            .cloned()
            .ok_or("constructor storage scope missing")?;
        let mut lives = Vec::new();
        for i in 0..rs.len() {
            lives.push(
                bindings
                    .regions
                    .get(&(i as u16))
                    .cloned()
                    .unwrap_or_else(|| Life::scope(scope.clone())),
            );
        }
        for (i, t) in args.iter().enumerate() {
            let value = bindings
                .args
                .get(&(i as u16))
                .cloned()
                .unwrap_or_else(|| Instance::scoped(t, &scope));
            if !aggregate::compatible(t, &value.ty) {
                return Err("constructor type witness shape".into());
            }
            lives.extend(value.lives);
        }
        self.coerce_value(
            v,
            &Instance {
                ty: v.ty.clone(),
                lives,
            },
        )
    }
    pub(super) fn ascribe(&mut self, src: Reg, ty: &Ty) -> Result<(), String> {
        types::validate_type(ty, &self.layouts, self.type_parameters)?;

        let mut v = self.usable(src)?;
        self.coerce_value(&mut v, &Instance::formal(ty))?;
        self.values.insert(src, v);
        Ok(())
    }
}

impl Instance {
    pub(super) fn reference_lives(&self, defs: &types::Definitions) -> Result<Vec<Life>, String> {
        fn walk(
            t: &Instance,
            defs: &types::Definitions,
            out: &mut Vec<Life>,
            depth: usize,
        ) -> Result<(), String> {
            if depth > 64 {
                return Err("lifetime witness expansion limit".into());
            }
            if t.ty.reference().is_some() {
                out.push(t.lives.first().ok_or("missing reference lifetime")?.clone());
            }
            match t.ty {
                Ty::Ref(..) => walk(&t.inner()?, defs, out, depth + 1)?,
                Ty::Named(..) => {
                    for f in t.fields(defs)? {
                        walk(&f, defs, out, depth + 1)?;
                    }
                }
                _ => {}
            }
            Ok(())
        }
        let mut out = Vec::new();
        walk(self, defs, &mut out, 0)?;
        Ok(out)
    }
}

impl Bindings {
    fn shorten(&mut self, state: &State, r: u16, upper: &Life) -> Result<bool, String> {
        let current = self
            .regions
            .get(&r)
            .cloned()
            .unwrap_or_else(|| Life::formal(r));
        if state.life_outlives(upper, &current) {
            return Ok(false);
        }
        if self.pinned_regions.contains(&r) {
            return Err("stored lifetime witness cannot be shortened".into());
        }
        let next = state.life_meet(&current, upper);
        let changed = next != current;
        self.regions.insert(r, next);
        Ok(changed)
    }
    pub(super) fn solve(&mut self, state: &State, sig: &Sig) -> Result<(), String> {
        fn walk(
            bindings: &mut Bindings,
            state: &State,
            t: &Ty,
            changed: &mut bool,
            depth: usize,
        ) -> Result<(), String> {
            if depth > 64 {
                return Err("lifetime constraint expansion limit".into());
            }
            match t {
                Ty::Ref(_, r, inner) => {
                    let bound = bindings.instantiate(inner)?;
                    for life in bound.reference_lives(&state.layouts)? {
                        *changed |= bindings.shorten(state, *r, &life)?;
                    }
                    walk(bindings, state, inner, changed, depth + 1)?;
                }
                Ty::Named(..) => {
                    for (_, field) in types::fields(t, &state.layouts)? {
                        walk(bindings, state, &field, changed, depth + 1)?;
                    }
                }
                _ => {}
            }
            Ok(())
        }
        for _ in 0..128 {
            let mut changed = false;
            for t in &sig.params {
                walk(self, state, t, &mut changed, 0)?;
            }
            if !changed {
                return Ok(());
            }
        }
        Err("lifetime constraint iteration limit".into())
    }
}
impl State {
    pub(super) fn call_witnesses(
        &self,
        pattern: &Sig,
        explicit: Option<&[Ty]>,
        values: &[Value],
    ) -> Result<(Bindings, Vec<Value>), String> {
        let mut bindings = explicit.map(Bindings::explicit).unwrap_or_default();
        for pins in [true, false] {
            for (t, v) in pattern.params.iter().zip(values) {
                bindings.observe(self, t, &Instance::of(v), pins)?;
            }
        }
        bindings.solve(self, pattern)?;
        let mut coerced = Vec::new();
        for (t, v) in pattern.params.iter().zip(values) {
            let mut v = v.clone();
            self.coerce_value(&mut v, &bindings.instantiate(t)?)?;
            coerced.push(v);
        }
        Ok((bindings, coerced))
    }
}

impl Bindings {
    pub(super) fn contract_signature(&self, pattern: &Sig) -> Result<Sig, String> {
        let mut next = pattern
            .params
            .iter()
            .chain([&pattern.result])
            .flat_map(formal)
            .flat_map(|l| l.0)
            .filter_map(|a| {
                if let Atom::Formal(r) = a {
                    Some(u32::from(r) + 1)
                } else {
                    None
                }
            })
            .max()
            .unwrap_or(0);
        fn rename(t: &Ty, next: &mut u32) -> Result<Ty, String> {
            fn slot(next: &mut u32) -> Result<u16, String> {
                let r = u16::try_from(*next).map_err(|_| "generic lifetime namespace limit")?;
                *next += 1;
                Ok(r)
            }
            Ok(match t {
                Ty::View(m, _) => Ty::View(*m, slot(next)?),
                Ty::Holder(m, _) => Ty::Holder(*m, slot(next)?),
                Ty::Ref(m, _, inner) => Ty::Ref(*m, slot(next)?, Box::new(rename(inner, next)?)),
                Ty::Named(n, rs, args) => {
                    let mut regions = Vec::new();
                    for _ in rs {
                        regions.push(slot(next)?);
                    }
                    let mut values = Vec::new();
                    for t in args {
                        values.push(rename(t, next)?);
                    }
                    Ty::Named(n.clone(), regions, values)
                }
                _ => t.clone(),
            })
        }
        let mut args = BTreeMap::new();
        for (i, value) in &self.args {
            args.insert(*i, Instance::formal(&rename(&value.ty, &mut next)?));
        }
        let region = |r| Ok((r, Life::formal(r)));
        let argument = |i| {
            args.get(&i)
                .cloned()
                .ok_or_else(|| "contract type argument absent".into())
        };
        Ok(Sig {
            name: pattern.name.clone(),
            params: pattern
                .params
                .iter()
                .map(|t| apply(t, &region, &argument).map(|v| v.ty))
                .collect::<Result<Vec<_>, _>>()?,
            result: apply(&pattern.result, &region, &argument)?.ty,
        })
    }
}

/// Lifetime comparison for a written source contract, without actual caller roots.
pub(super) fn formal_fits(
    a: &Ty,
    b: &Ty,
    invariant: bool,
    contract: &provenance::Contract,
    defs: &types::Definitions,
) -> Result<bool, String> {
    let ge = |a: &Life, b: &Life| {
        a.0.iter().all(|a| {
            b.0.iter().any(
                |b| matches!((a,b),(Atom::Formal(x),Atom::Formal(y))if contract.outlives(*x,*y)),
            )
        })
    };
    compare(
        &Instance::formal(a),
        &Instance::formal(b),
        invariant,
        defs,
        &ge,
        0,
        &mut 0,
    )
}
fn compare(
    a: &Instance,
    b: &Instance,
    inv: bool,
    defs: &types::Definitions,
    ge: &impl Fn(&Life, &Life) -> bool,
    depth: usize,
    nodes: &mut usize,
) -> Result<bool, String> {
    *nodes += 1;
    if depth > 64 || *nodes > 4096 {
        return Err("lifetime comparison expansion limit".into());
    }
    if !aggregate::compatible(&a.ty, &b.ty) || a.lives.len() != b.lives.len() {
        return Ok(false);
    }
    if inv {
        return Ok(a
            .lives
            .iter()
            .zip(&b.lives)
            .all(|(a, b)| ge(a, b) && ge(b, a)));
    }
    Ok(match &a.ty {
        Ty::View(..) | Ty::Holder(..) => ge(&a.lives[0], &b.lives[0]),
        Ty::Ref(m, ..) => {
            ge(&a.lives[0], &b.lives[0])
                && compare(
                    &a.inner()?,
                    &b.inner()?,
                    *m == Mode::Write,
                    defs,
                    ge,
                    depth + 1,
                    nodes,
                )?
        }
        Ty::Named(..) => {
            let mut yes = true;
            for (a, b) in a.fields(defs)?.iter().zip(b.fields(defs)?) {
                yes &= compare(a, &b, false, defs, ge, depth + 1, nodes)?;
            }
            yes
        }
        _ => true,
    })
}
