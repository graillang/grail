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
    pub parameters: u16,
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
fn substitute(t: &Ty, regions: &[u16], args: &[Ty]) -> Result<Ty, String> {
    let slot = |r: &u16| {
        regions
            .get(*r as usize)
            .copied()
            .ok_or_else(|| "layout lifetime slot out of range".to_string())
    };
    let result = match t {
        Ty::Param(i) => args
            .get(*i as usize)
            .ok_or("layout type slot out of range")?
            .clone(),
        Ty::Ref(m, r, t) => Ty::Ref(*m, slot(r)?, Box::new(substitute(t, regions, args)?)),
        Ty::View(m, r) => Ty::View(*m, slot(r)?),
        Ty::Holder(m, r) => Ty::Holder(*m, slot(r)?),
        Ty::Named(n, rs, ts) => Ty::Named(
            n.clone(),
            rs.iter().map(slot).collect::<Result<_, _>>()?,
            ts.iter()
                .map(|t| substitute(t, regions, args))
                .collect::<Result<_, _>>()?,
        ),
        _ => t.clone(),
    };
    result.validate_shape(64)?;
    Ok(result)
}
fn application<'a, 'b>(
    t: &'b Ty,
    defs: &'a Definitions,
) -> Result<(&'a Definition, &'b [u16], &'b [Ty]), String> {
    let Ty::Named(n, rs, args) = t else {
        return Err("expected nominal type".into());
    };
    let d = defs
        .get(n)
        .ok_or_else(|| format!("unknown nominal type {n}"))?;
    if rs.len() != d.regions as usize || args.len() != d.parameters as usize {
        return Err("nominal lifetime/type argument arity".into());
    }
    Ok((d, rs, args))
}
pub fn fields(t: &Ty, defs: &Definitions) -> Result<Vec<(String, Ty)>, String> {
    let (d, rs, args) = application(t, defs)?;
    d.fields
        .iter()
        .map(|(n, t)| Ok((n.clone(), substitute(t, rs, args)?)))
        .collect()
}
pub fn field(t: &Ty, index: usize, defs: &Definitions) -> Result<Ty, String> {
    let (d, rs, args) = application(t, defs)?;
    substitute(&d.fields.get(index).ok_or("field index")?.1, rs, args)
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
        t = if *i == crate::provenance::DEREF {
            let Ty::Ref(_, _, inner) = t else {
                return Err("invalid dereference provenance".into());
            };
            *inner
        } else {
            field(&t, *i, defs)?
        };
    }
    Ok(t)
}
/// Deterministic physical instance order. Regions never multiply native layouts.
pub fn instances(roots: &[Ty], defs: &Definitions) -> Result<Vec<Ty>, String> {
    fn visit(
        t: &Ty,
        defs: &Definitions,
        active: &mut BTreeSet<String>,
        done: &mut BTreeSet<String>,
        out: &mut Vec<Ty>,
    ) -> Result<(), String> {
        if let Ty::Ref(_, _, inner) = t {
            return visit(inner, defs, active, done, out);
        }
        if !matches!(t, Ty::Named(..)) {
            return Ok(());
        }
        t.validate_shape(64)?;
        let t = t.erase_regions();
        let key = t.word();
        if done.contains(&key) {
            return Ok(());
        }
        if active.len() > 64 {
            return Err("layout depth limit".into());
        }
        if !active.insert(key.clone()) {
            return Err("recursive by-value nominal layout".into());
        }
        for (_, field) in fields(&t, defs)? {
            visit(&field, defs, active, done, out)?;
        }
        active.remove(&key);
        done.insert(key);
        out.push(t);
        Ok(())
    }
    let mut result = Vec::new();
    let mut done = BTreeSet::new();
    for t in roots {
        visit(t, defs, &mut BTreeSet::new(), &mut done, &mut result)?;
    }
    Ok(result)
}
fn references(t: &Ty, defs: &Definitions, regions: Option<u16>) -> Result<(), String> {
    match t {
        Ty::Ref(mode, r, inner) => {
            if regions.is_some_and(|count| *r >= count) {
                return Err("undeclared typed-reference lifetime".into());
            }
            fn graph(
                t: &Ty,
                defs: &Definitions,
                depth: usize,
                nodes: &mut usize,
            ) -> Result<(), String> {
                *nodes += 1;
                if depth > 64 || *nodes > 4096 {
                    return Err("reference provenance expansion limit".into());
                }
                match t {
                    Ty::Ref(_, _, inner) => graph(inner, defs, depth + 1, nodes)?,
                    Ty::Named(..) => {
                        for (_, f) in fields(t, defs)? {
                            graph(&f, defs, depth + 1, nodes)?;
                        }
                    }
                    _ => {}
                }
                Ok(())
            }
            graph(inner, defs, 0, &mut 0)?;
            references(inner, defs, regions)?;
            // Capture-bearing referents require invariant lifetime witnesses and opaque writeback.
            // This first storage gate must fail closed, not treat placeholder region zero as proof.
            fn plain(
                t: &Ty,
                defs: &Definitions,
                depth: usize,
                nodes: &mut usize,
            ) -> Result<bool, String> {
                *nodes += 1;
                if depth > 64 || *nodes > 4096 {
                    return Err("typed referent expansion limit".into());
                }
                match t {
                    Ty::View(..) | Ty::Holder(..) | Ty::Ref(..) => Ok(false),
                    Ty::Named(_, rs, args) => {
                        if !rs.is_empty() {
                            return Ok(false);
                        }
                        for t in args {
                            if !plain(t, defs, depth + 1, nodes)? {
                                return Ok(false);
                            }
                        }
                        for (_, t) in fields(t, defs)? {
                            if !plain(&t, defs, depth + 1, nodes)? {
                                return Ok(false);
                            }
                        }
                        Ok(true)
                    }
                    _ => Ok(true),
                }
            }
            if *mode == crate::Mode::Write && !plain(inner, defs, 0, &mut 0)? {
                return Err(
                    "capture-bearing typed referents require the pending invariance/writeback gate"
                        .into(),
                );
            }
        }
        Ty::Named(_, rs, args) => {
            application(t, defs)?;
            if regions.is_some_and(|count| rs.iter().any(|r| *r >= count)) {
                return Err("undeclared layout lifetime".into());
            }
            for a in args {
                references(a, defs, regions)?;
            }
        }
        Ty::View(_, r) | Ty::Holder(_, r) if regions.is_some_and(|count| *r >= count) => {
            return Err("undeclared layout lifetime".into());
        }
        _ => {}
    }
    Ok(())
}
pub(crate) fn validate_type(t: &Ty, defs: &Definitions, parameters: u16) -> Result<(), String> {
    t.validate_shape(parameters)?;
    references(t, defs, None)?;
    for (_, leaf) in leaves(t, defs)? {
        references(&leaf, defs, None)?;
    }
    Ok(())
}
pub(crate) fn required_plain(t: &Ty, defs: &Definitions) -> Result<BTreeSet<u16>, String> {
    fn collect(
        t: &Ty,
        defs: &Definitions,
        plain: bool,
        out: &mut BTreeSet<u16>,
        depth: usize,
        nodes: &mut usize,
    ) -> Result<(), String> {
        *nodes += 1;
        if depth > 64 || *nodes > 4096 {
            return Err("reference kind expansion limit".into());
        }
        match t {
            Ty::Param(i) if plain => {
                out.insert(*i);
            }
            Ty::Ref(m, _, t) => collect(
                t,
                defs,
                plain || *m == crate::Mode::Write,
                out,
                depth + 1,
                nodes,
            )?,
            Ty::Named(_, _, args) => {
                for t in args {
                    collect(t, defs, plain, out, depth + 1, nodes)?;
                }
                for (_, t) in fields(t, defs)? {
                    collect(&t, defs, plain, out, depth + 1, nodes)?;
                }
            }
            _ => {}
        }
        Ok(())
    }
    let mut out = BTreeSet::new();
    collect(t, defs, false, &mut out, 0, &mut 0)?;
    Ok(out)
}
pub fn validate(defs: &Definitions) -> Result<(), String> {
    if defs.len() > 4096 {
        return Err("layout definition count limit".into());
    }
    for (n, d) in defs {
        if !qualified_ok(n)
            || d.regions > 64
            || d.parameters > 64
            || d.fields.len() > 64
            || (d.kind == Kind::Enum && d.fields.is_empty())
        {
            return Err("invalid layout declaration".into());
        }
        let mut names = BTreeSet::new();
        for (name, t) in &d.fields {
            if !name_ok(name) || !names.insert(name) {
                return Err("invalid/duplicate layout field".into());
            }
            t.validate_shape(d.parameters)?;
            references(t, defs, Some(d.regions))?;
        }
    }
    for (n, d) in defs {
        let t = Ty::Named(
            n.clone(),
            (0..d.regions).collect(),
            (0..d.parameters).map(Ty::Param).collect(),
        );
        leaves(&t, defs)?;
    }
    Ok(())
}
pub fn validate_sig(sig: &Sig, defs: &Definitions) -> Result<(), String> {
    validate_sig_bound(sig, defs, 0)
}
pub(crate) fn validate_sig_bound(
    sig: &Sig,
    defs: &Definitions,
    parameters: u16,
) -> Result<(), String> {
    sig.validate_bound(parameters)?;
    for t in sig.params.iter().chain([&sig.result]) {
        validate_type(t, defs, parameters)?;
    }
    if sig.result.reference().is_some() {
        let contract = crate::provenance::Contract::new(sig, defs)?;
        let mut suitable = false;
        for source in contract.inputs.iter().flatten() {
            suitable |= source.eligible(&sig.result, &contract, defs)?;
        }
        if !suitable {
            return Err("result region has no suitable input capture or frame".into());
        }
    }
    Ok(())
}
/// Only layouts reachable from public signatures belong in the public surface.
pub fn exposed(
    sigs: &BTreeMap<String, Sig>,
    public_types: &BTreeSet<String>,
    defs: &Definitions,
) -> Result<Definitions, String> {
    fn add(t: &Ty, defs: &Definitions, out: &mut Definitions) -> Result<(), String> {
        if let Ty::Ref(_, _, inner) = t {
            add(inner, defs, out)?;
        }
        if let Ty::Named(n, _, args) = t {
            if !out.contains_key(n) {
                let d = defs.get(n).ok_or("missing exported layout")?.clone();
                out.insert(n.clone(), d.clone());
                for (_, t) in &d.fields {
                    add(t, defs, out)?;
                }
            }
            for a in args {
                add(a, defs, out)?;
            }
        }
        Ok(())
    }
    let mut out = Definitions::new();
    for s in sigs.values() {
        for t in s.params.iter().chain([&s.result]) {
            add(t, defs, &mut out)?;
        }
    }
    for n in public_types {
        let d = defs.get(n).ok_or("unknown public layout")?;
        add(
            &Ty::Named(
                n.clone(),
                (0..d.regions).collect(),
                (0..d.parameters).map(Ty::Param).collect(),
            ),
            defs,
            &mut out,
        )?;
    }
    Ok(out)
}

pub fn is_enum(t: &Ty, defs: &Definitions) -> Result<bool, String> {
    match t {
        Ty::Named(n, _, _) => Ok(defs.get(n).ok_or("unknown nominal type")?.kind == Kind::Enum),
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
