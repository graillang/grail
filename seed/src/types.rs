//! Nominal record layouts; lifetime slots describe captures, never storage/target identity.
use crate::{Sig, Ty, name_ok, qualified_ok};
use std::collections::{BTreeMap, BTreeSet};
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Kind {
    Record,
    Enum,
}
impl Kind {
    pub fn word(self) -> &'static str {
        match self {
            Self::Record => "record",
            Self::Enum => "enum",
        }
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Definition {
    pub kind: Kind,
    pub regions: u16,
    pub fields: Vec<(String, Ty)>,
}
pub type Definitions = BTreeMap<String, Definition>;
#[derive(Clone, Debug, Default)]
pub struct Context {
    definitions: std::sync::Arc<Definitions>,
}
impl Context {
    pub fn new(definitions: Definitions) -> Result<Self, String> {
        validate(&definitions)?;
        Ok(Self {
            definitions: std::sync::Arc::new(definitions),
        })
    }
}
impl std::ops::Deref for Context {
    type Target = Definitions;
    fn deref(&self) -> &Definitions {
        &self.definitions
    }
}
fn substitute(t: &Ty, args: &[u16]) -> Result<Ty, String> {
    let slot = |r: &u16| {
        args.get(*r as usize)
            .copied()
            .ok_or_else(|| "record lifetime slot out of range".to_string())
    };
    Ok(match t {
        Ty::View(m, r) => Ty::View(*m, slot(r)?),
        Ty::Holder(m, r) => Ty::Holder(*m, slot(r)?),
        Ty::Named(n, rs) => Ty::Named(n.clone(), rs.iter().map(slot).collect::<Result<_, _>>()?),
        _ => t.clone(),
    })
}
pub fn fields(t: &Ty, defs: &Definitions) -> Result<Vec<(String, Ty)>, String> {
    let Ty::Named(n, args) = t else {
        return Err("expected nominal type".into());
    };
    let d = defs
        .get(n)
        .ok_or_else(|| format!("unknown nominal type {n}"))?;
    if args.len() != d.regions as usize {
        return Err("record lifetime arity".into());
    }
    d.fields
        .iter()
        .map(|(n, t)| Ok((n.clone(), substitute(t, args)?)))
        .collect()
}
/// Resolve only the selected child; do not clone a whole union table for a path step.
pub fn field(t: &Ty, index: usize, defs: &Definitions) -> Result<Ty, String> {
    let Ty::Named(n, args) = t else {
        return Err("expected nominal type".into());
    };
    let d = defs.get(n).ok_or("unknown nominal type")?;
    if args.len() != d.regions as usize {
        return Err("nominal lifetime arity".into());
    }
    substitute(&d.fields.get(index).ok_or("field index")?.1, args)
}
pub fn leaves(t: &Ty, defs: &Definitions) -> Result<Vec<(Vec<usize>, Ty)>, String> {
    fn walk(
        t: &Ty,
        defs: &Definitions,
        path: &mut Vec<usize>,
        out: &mut Vec<(Vec<usize>, Ty)>,
        nodes: &mut usize,
    ) -> Result<(), String> {
        *nodes += 1;
        if path.len() > 64 || *nodes > 4096 {
            return Err("record expansion limit".into());
        }
        if matches!(t, Ty::Named(..)) {
            for (i, (_, field)) in fields(t, defs)?.iter().enumerate() {
                path.push(i);
                walk(field, defs, path, out, nodes)?;
                path.pop();
            }
        } else {
            out.push((path.clone(), t.clone()));
        }
        Ok(())
    }
    let mut out = Vec::new();
    walk(t, defs, &mut Vec::new(), &mut out, &mut 0)?;
    Ok(out)
}
pub fn project(t: &Ty, path: &[String], defs: &Definitions) -> Result<(Vec<usize>, Ty), String> {
    let mut t = t.clone();
    let mut indices = Vec::new();
    for name in path {
        if is_enum(&t, defs)? {
            return Err("enum payload needs match or unwrap".into());
        }
        let fields = fields(&t, defs)?;
        let (i, (_, field)) = fields
            .iter()
            .enumerate()
            .find(|(_, f)| f.0 == *name)
            .ok_or_else(|| format!("unknown field {name}"))?;
        indices.push(i);
        t = field.clone();
    }
    Ok((indices, t))
}
pub fn at(t: &Ty, path: &[usize], defs: &Definitions) -> Result<Ty, String> {
    let mut t = t.clone();
    for i in path {
        t = field(&t, *i, defs)?;
    }
    Ok(t)
}
pub fn order(defs: &Definitions) -> Result<Vec<String>, String> {
    fn visit(
        n: &str,
        defs: &Definitions,
        active: &mut BTreeSet<String>,
        done: &mut BTreeSet<String>,
        out: &mut Vec<String>,
    ) -> Result<(), String> {
        if done.contains(n) {
            return Ok(());
        }
        if !active.insert(n.into()) {
            return Err("recursive by-value nominal layout".into());
        }
        if active.len() > 64 {
            return Err("record depth limit".into());
        }
        let d = defs
            .get(n)
            .ok_or_else(|| format!("unknown nominal type {n}"))?;
        for (_, t) in &d.fields {
            if let Ty::Named(child, args) = t {
                let c = defs
                    .get(child)
                    .ok_or_else(|| format!("unknown nominal type {child}"))?;
                if args.len() != c.regions as usize {
                    return Err("record lifetime arity".into());
                }
                visit(child, defs, active, done, out)?;
            }
        }
        active.remove(n);
        done.insert(n.into());
        out.push(n.into());
        Ok(())
    }
    let mut out = Vec::new();
    let mut done = BTreeSet::new();
    for n in defs.keys() {
        visit(n, defs, &mut BTreeSet::new(), &mut done, &mut out)?;
    }
    Ok(out)
}
pub fn validate(defs: &Definitions) -> Result<(), String> {
    if defs.len() > 4096 {
        return Err("record definition count limit".into());
    }
    for (n, d) in defs {
        if !qualified_ok(n)
            || d.regions > 64
            || d.fields.len() > 64
            || (d.kind == Kind::Enum && d.fields.is_empty())
        {
            return Err("invalid record declaration".into());
        }
        let mut names = BTreeSet::new();
        for (name, t) in &d.fields {
            if !name_ok(name) || !names.insert(name) || *t == Ty::Buffer {
                return Err("invalid/duplicate record field".into());
            }
            let rs = match t {
                Ty::View(_, r) | Ty::Holder(_, r) => vec![*r],
                Ty::Named(_, rs) => rs.clone(),
                _ => vec![],
            };
            if rs.iter().any(|r| *r >= d.regions) {
                return Err("undeclared record lifetime".into());
            }
        }
    }
    order(defs)?;
    for (n, d) in defs {
        leaves(&Ty::Named(n.clone(), (0..d.regions).collect()), defs)?;
    }
    Ok(())
}
pub fn validate_sig(sig: &Sig, defs: &Definitions) -> Result<(), String> {
    sig.validate()?;
    for t in sig.params.iter().chain([&sig.result]) {
        leaves(t, defs)?;
    }
    if let Some((mode, region)) = sig.result.reference() {
        let input = sig
            .params
            .iter()
            .map(|t| leaves(t, defs))
            .collect::<Result<Vec<_>, _>>()?;
        if !input.iter().flatten().any(|(_, t)| {
            t.reference().is_some_and(|(m, r)| {
                r == region && (mode == crate::Mode::Read || m == crate::Mode::Write)
            })
        }) {
            return Err("result region has no suitable input capture".into());
        }
    }
    Ok(())
}
/// Only layouts reachable from public signatures belong in the public surface.
pub fn exposed(sigs: &BTreeMap<String, Sig>, defs: &Definitions) -> Result<Definitions, String> {
    fn add(t: &Ty, defs: &Definitions, out: &mut Definitions) -> Result<(), String> {
        if let Ty::Named(n, _) = t
            && !out.contains_key(n)
        {
            let d = defs.get(n).ok_or("missing exported record")?.clone();
            out.insert(n.clone(), d.clone());
            for (_, t) in d.fields {
                add(&t, defs, out)?;
            }
        }
        Ok(())
    }
    let mut out = Definitions::new();
    for sig in sigs.values() {
        for t in sig.params.iter().chain([&sig.result]) {
            add(t, defs, &mut out)?;
        }
    }
    Ok(out)
}

pub fn is_enum(t: &Ty, defs: &Definitions) -> Result<bool, String> {
    match t {
        Ty::Named(n, _) => Ok(defs.get(n).ok_or("unknown nominal type")?.kind == Kind::Enum),
        _ => Ok(false),
    }
}

pub fn success(t: &Ty, defs: &Definitions) -> Result<usize, String> {
    if !is_enum(t, defs)? {
        return Err("unwrap needs Result-like or Option-like enum".into());
    }
    let f = fields(t, defs)?;
    let result = f.len() == 2 && f.iter().any(|(n, _)| n == "Err");
    let option = f.len() == 2 && f.iter().any(|(n, t)| n == "None" && *t == Ty::Unit);
    f.iter()
        .position(|(n, _)| (result && n == "Ok") || (option && n == "Some"))
        .ok_or("unwrap needs Ok/Err or Some/None variants".into())
}
