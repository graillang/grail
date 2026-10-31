//! Written reference sources and implied outlives relations, independent of caller roots.
use crate::{Mode, Sig, Ty, types};
use std::collections::{BTreeMap, BTreeSet};
pub(crate) const DEREF: usize = usize::MAX;
#[derive(Clone, Debug)]
pub(crate) struct Frame {
    pub(crate) path: Vec<usize>,
    pub(crate) mode: Mode,
    pub(crate) region: u16,
}
#[derive(Clone, Debug)]
pub(crate) struct Source {
    pub(crate) path: Vec<usize>,
    pub(crate) ty: Ty,
    pub(crate) frames: Vec<Frame>,
}
#[derive(Clone, Debug, Default)]
pub(crate) struct Contract {
    pub(crate) inputs: Vec<Vec<Source>>,
    edges: BTreeMap<u16, BTreeSet<u16>>,
}
pub(crate) fn sources(t: &Ty, defs: &types::Definitions) -> Result<Vec<Source>, String> {
    fn walk(
        t: &Ty,
        defs: &types::Definitions,
        path: &mut Vec<usize>,
        frames: &mut Vec<Frame>,
        out: &mut Vec<Source>,
        nodes: &mut usize,
    ) -> Result<(), String> {
        *nodes += 1;
        if path.len() > 64 || *nodes > 4096 {
            return Err("reference provenance expansion limit".into());
        }
        if t.reference().is_some() {
            out.push(Source {
                path: path.clone(),
                ty: t.clone(),
                frames: frames.clone(),
            });
        }
        match t {
            Ty::Ref(m, r, inner) => {
                frames.push(Frame {
                    path: path.clone(),
                    mode: *m,
                    region: *r,
                });
                path.push(DEREF);
                walk(inner, defs, path, frames, out, nodes)?;
                path.pop();
                frames.pop();
            }
            Ty::Named(..) => {
                for (i, (_, field)) in types::fields(t, defs)?.iter().enumerate() {
                    path.push(i);
                    walk(field, defs, path, frames, out, nodes)?;
                    path.pop();
                }
            }
            _ => {}
        }
        Ok(())
    }
    let mut out = Vec::new();
    walk(t, defs, &mut Vec::new(), &mut Vec::new(), &mut out, &mut 0)?;
    Ok(out)
}
impl Contract {
    pub(crate) fn new(sig: &Sig, defs: &types::Definitions) -> Result<Self, String> {
        let mut c = Self::default();
        for t in &sig.params {
            let input = sources(t, defs)?;
            for source in &input {
                let (_, r) = source.ty.reference().expect("reference source");
                for frame in &source.frames {
                    c.edges.entry(r).or_default().insert(frame.region);
                }
            }
            c.inputs.push(input);
        }
        Ok(c)
    }
    pub(crate) fn outlives(&self, from: u16, to: u16) -> bool {
        if from == to {
            return true;
        }
        let mut todo = vec![from];
        let mut seen = BTreeSet::new();
        while let Some(r) = todo.pop() {
            if !seen.insert(r) {
                continue;
            }
            if let Some(edges) = self.edges.get(&r) {
                if edges.contains(&to) {
                    return true;
                }
                todo.extend(edges);
            }
        }
        false
    }
}
fn byte_place(t: &Ty, mode: Mode, defs: &types::Definitions) -> Result<bool, String> {
    Ok(match t {
        Ty::Bytes => true,
        Ty::Text => mode == Mode::Read,
        Ty::View(m, _) | Ty::Holder(m, _) => mode == Mode::Read || *m == Mode::Write,
        Ty::Named(..) if !types::is_enum(t, defs)? => {
            let mut any = false;
            for (_, field) in types::fields(t, defs)? {
                any |= byte_place(&field, mode, defs)?;
            }
            any
        }
        _ => false,
    })
}
fn subplace(t: &Ty, want: &Ty, defs: &types::Definitions) -> Result<bool, String> {
    if crate::aggregate::compatible(t, want) {
        return Ok(true);
    }
    if matches!(t, Ty::Named(..)) && !types::is_enum(t, defs)? {
        for (_, field) in types::fields(t, defs)? {
            if subplace(&field, want, defs)? {
                return Ok(true);
            }
        }
    }
    Ok(false)
}
impl Source {
    pub(crate) fn eligible(
        &self,
        result: &Ty,
        contract: &Contract,
        defs: &types::Definitions,
    ) -> Result<bool, String> {
        let Some((mode, r)) = result.reference() else {
            return Ok(false);
        };
        let (m, s) = self.ty.reference().expect("reference source");
        if !contract.outlives(s, r) || (mode == Mode::Write && m != Mode::Write) {
            return Ok(false);
        }
        if m == Mode::Write
            && self.frames.iter().any(|f| {
                !contract.outlives(f.region, r) || (mode == Mode::Write && f.mode != Mode::Write)
            })
        {
            return Ok(false);
        }
        Ok(match (result, &self.ty) {
            (Ty::Ref(_, _, want), Ty::Ref(_, _, inner)) => subplace(inner, want, defs)?,
            (Ty::Ref(..), _) => false,
            (_, Ty::Ref(_, _, inner)) => byte_place(inner, mode, defs)?,
            _ => true,
        })
    }
}

#[derive(Clone, Debug)]
pub(super) struct InputSource {
    pub(super) spec: Source,
    pub(super) value: crate::Value,
    pub(super) frame_roots: BTreeSet<crate::Root>,
    pub(super) frame_ancestors: BTreeSet<usize>,
}
impl crate::State {
    pub(super) fn path_values<'a>(
        &'a self,
        value: &'a crate::Value,
        path: &[usize],
    ) -> Result<Vec<&'a crate::Value>, String> {
        let mut values = vec![value];
        for step in path {
            let mut next = Vec::new();
            for v in values {
                if *step == DEREF {
                    for p in &v.targets {
                        next.push(self.target(p)?);
                    }
                } else {
                    next.push(v.at(&[*step])?);
                }
                if next.len() > 4096 {
                    return Err("capture-source expansion limit".into());
                }
            }
            values = next;
        }
        Ok(values)
    }
    pub(super) fn input_sources(
        &self,
        inputs: &[(Ty, crate::Value)],
        contract: &Contract,
    ) -> Result<Vec<InputSource>, String> {
        let mut out = Vec::new();
        for ((_, value), sources) in inputs.iter().zip(&contract.inputs) {
            for source in sources {
                let mut frame_roots = BTreeSet::new();
                let mut frame_ancestors = BTreeSet::new();
                for frame in &source.frames {
                    for v in self.path_values(value, &frame.path)? {
                        frame_roots.extend(v.roots.clone());
                        frame_ancestors.extend(v.ancestors.clone());
                        if frame.mode == Mode::Write && frame.path.contains(&DEREF) {
                            frame_ancestors.insert(v.loan);
                        }
                    }
                }
                for v in self.path_values(value, &source.path)? {
                    if !v.active {
                        return Err("expired capture behind typed reference".into());
                    }
                    out.push(InputSource {
                        spec: source.clone(),
                        value: v.clone(),
                        frame_roots: frame_roots.clone(),
                        frame_ancestors: frame_ancestors.clone(),
                    });
                }
            }
        }
        Ok(out)
    }
}
