//! Native layout substitution over independently checked definitions, not caller-root analysis.
use crate::{
    Checked, Op, Sig, Ty, ir,
    module::CheckedModule,
    template::{Bundle, Signature},
    types,
};
use std::{
    collections::{BTreeMap, BTreeSet, VecDeque},
    sync::Arc,
};
pub(crate) struct NativeModule {
    pub(crate) functions: Vec<(Checked, bool)>,
    pub(crate) layouts: types::Context,
}
struct Job {
    body: Checked,
    public: bool,
    origin: Option<String>,
    logical: String,
}
struct RewriteScope<'a> {
    types: &'a BTreeMap<crate::Reg, Ty>,
    generics: &'a BTreeMap<String, Signature>,
    imports: &'a BTreeMap<String, Sig>,
    origin: Option<&'a str>,
    logical: &'a str,
    current: &'a Sig,
}
struct Engine<'a, F> {
    source: &'a CheckedModule,
    resolve: &'a mut F,
    layouts: types::Context,
    bundles: BTreeMap<String, (Arc<Bundle>, String)>,
    normal: BTreeMap<String, usize>,
    queue: VecDeque<Job>,
    queued: BTreeSet<String>,
    memo: BTreeMap<String, Sig>,
    output: Vec<(Checked, bool)>,
}
impl<F: FnMut(&str) -> Result<Bundle, String>> Engine<'_, F> {
    fn merge(&mut self, bundle: &Bundle) -> Result<(), String> {
        let mut defs = (*self.layouts).clone();
        for (n, d) in bundle.layouts.iter() {
            if let Some(old) = defs.insert(n.clone(), d.clone())
                && old != *d
            {
                return Err("conflicting specialization layouts".into());
            }
        }
        self.layouts = types::Context::new(defs)?;
        Ok(())
    }
    fn bundle(&mut self, name: &str) -> Result<(Arc<Bundle>, String), String> {
        if let Some(b) = self.bundles.get(name) {
            return Ok(b.clone());
        }
        if name == self.source.header.name {
            return Err("missing local checked template definitions".into());
        }
        let b = (self.resolve)(name)?;
        if b.module != name {
            return Err("template module mismatch".into());
        }
        let hash = b.hash()?;
        self.merge(&b)?;
        let result = (Arc::new(b), hash);
        self.bundles.insert(name.into(), result.clone());
        Ok(result)
    }
    fn enqueue(
        &mut self,
        body: Checked,
        public: bool,
        origin: Option<String>,
        logical: String,
    ) -> Result<(), String> {
        if self.queued.contains(&body.function.sig.name) {
            return Ok(());
        }
        if self.queued.len() >= 4096 {
            return Err("native specialization/function count limit".into());
        }
        self.queued.insert(body.function.sig.name.clone());
        self.queue.push_back(Job {
            body,
            public,
            origin,
            logical,
        });
        Ok(())
    }
    fn original(&mut self, index: usize) -> Result<Sig, String> {
        let (p, public) = &self.source.functions[index];
        let sig = p.function.sig.clone();
        self.enqueue(p.clone(), *public, None, sig.name.clone())?;
        Ok(sig)
    }
    fn key(&self, hash: &str, name: &str, args: &[Ty]) -> Result<String, String> {
        let args = args.iter().map(Ty::erase_regions).collect::<Vec<_>>();
        let sig = Sig {
            name: "key".into(),
            params: args.clone(),
            result: Ty::Unit,
        };
        let defs = types::exposed(
            &BTreeMap::from([("key".into(), sig)]),
            &BTreeSet::new(),
            &self.layouts,
        )?;
        let mut w = ir::Writer::default();
        w.text("grail-native-instance-1")?;
        w.text(hash)?;
        w.text(name)?;
        w.num(args.len() as u64)?;
        for t in args {
            w.text(&t.word())?;
        }
        ir::write_layouts(&mut w, &defs)?;
        Ok(crate::sha256::hex(&w.data))
    }
    fn instance(
        &mut self,
        module: &str,
        name: &str,
        args: &[Ty],
        generic: bool,
    ) -> Result<Sig, String> {
        let (bundle, hash) = self.bundle(module)?;
        let def = bundle
            .functions
            .get(name)
            .ok_or_else(|| format!("missing checked definition {name}"))?;
        if def.type_parameters as usize != args.len() || generic != (def.type_parameters > 0) {
            return Err("native generic definition arity/kind".into());
        }
        for t in args {
            types::validate_type(t, &self.layouts, 0)?;
        }
        let key = self.key(&hash, name, args)?;
        if let Some(sig) = self.memo.get(&key) {
            return Ok(sig.clone());
        }
        let native = format!("_{}_{key}", if generic { "generic" } else { "helper" });
        let mut body = def.clone();
        let sub = |t: &Ty| t.substitute_types(args).map(|t| t.erase_regions());
        body.function.sig.params = body
            .function
            .sig
            .params
            .iter()
            .map(sub)
            .collect::<Result<_, _>>()?;
        body.function.sig.result = sub(&body.function.sig.result)?;
        body.types = body
            .types
            .iter()
            .map(|(r, t)| Ok((*r, sub(t)?)))
            .collect::<Result<_, String>>()?;
        for t in body
            .types
            .values()
            .chain(body.function.sig.params.iter())
            .chain([&body.function.sig.result])
        {
            if *t != Ty::Buffer {
                types::validate_type(t, &self.layouts, 0)?;
            }
        }
        substitute_ops(&mut body.function.ops, args)?;
        body.function.sig.name = native;
        body.type_parameters = 0;
        body.layouts = self.layouts.clone();
        let sig = body.function.sig.clone();
        self.memo.insert(key, sig.clone());
        self.enqueue(body, false, Some(module.into()), name.into())?;
        Ok(sig)
    }
    fn generic(
        &mut self,
        name: &str,
        g: &Signature,
        args: &[Ty],
        origin: Option<&str>,
    ) -> Result<Sig, String> {
        let (module, _) = name
            .split_once("::")
            .ok_or("generic native name must be module-qualified")?;
        let caller = origin.unwrap_or(&self.source.header.name);
        let expected = if caller == module {
            None
        } else if let Some(origin) = origin {
            self.bundle(origin)?.0.implementations.get(module).cloned()
        } else {
            self.source.header.implementations.get(module).cloned()
        };
        if caller != module && expected.is_none() {
            return Err(format!(
                "generic call to {module} lacks a checked implementation pin; rebuild its producer"
            ));
        }
        let (bundle, hash) = self.bundle(module)?;
        if expected.as_ref().is_some_and(|h| *h != hash) {
            return Err(format!(
                "stale generic implementation {module}; rebuild dependent modules"
            ));
        }
        let def = bundle
            .functions
            .get(name)
            .ok_or("missing generic template body")?;
        if def.type_parameters != g.parameters || def.function.sig != g.function {
            return Err("generic checking contract/definition mismatch".into());
        }
        self.instance(module, name, args, true)
    }
    fn rewrite(
        &mut self,
        ops: &mut [Op],
        scope: &RewriteScope<'_>,
        native_imports: &mut BTreeMap<String, Sig>,
    ) -> Result<(), String> {
        let RewriteScope {
            types: reg_types,
            generics,
            imports,
            origin,
            logical,
            current,
        } = *scope;
        for op in ops {
            match op {
                Op::GenericCall {
                    dst,
                    name,
                    type_args,
                    args,
                } => {
                    let g = generics
                        .get(name)
                        .ok_or("missing checked generic call contract")?;
                    let actual = args
                        .iter()
                        .map(|r| {
                            reg_types
                                .get(r)
                                .cloned()
                                .ok_or_else(|| "missing generic operand type".to_string())
                        })
                        .collect::<Result<Vec<_>, _>>()?;
                    let types = g.arguments(&actual, type_args.as_deref(), 0, &self.layouts)?;
                    let sig = self.generic(name, g, &types, origin)?;
                    native_imports.insert(sig.name.clone(), sig.clone());
                    *op = Op::Call {
                        dst: *dst,
                        name: sig.name,
                        args: args.clone(),
                    };
                }
                Op::Call { name, .. } => {
                    let sig = if name == logical {
                        current.clone()
                    } else if let Some(origin) = origin {
                        let (bundle, _) = self.bundle(origin)?;
                        if bundle.functions.contains_key(name) {
                            self.instance(origin, name, &[], false)?
                        } else {
                            imports
                                .get(name)
                                .ok_or("missing ordinary template call contract")?
                                .clone()
                        }
                    } else if let Some(index) = self.normal.get(name) {
                        self.original(*index)?
                    } else {
                        imports
                            .get(name)
                            .ok_or("missing ordinary call contract")?
                            .clone()
                    };
                    *name = sig.name.clone();
                    native_imports.insert(sig.name.clone(), sig);
                }
                Op::If { yes, no, .. } => {
                    self.rewrite(yes, scope, native_imports)?;
                    self.rewrite(no, scope, native_imports)?;
                }
                Op::Match { arms, .. } => {
                    for a in arms {
                        self.rewrite(&mut a.body, scope, native_imports)?;
                    }
                }
                Op::Block { body } | Op::Loop { body, .. } => {
                    self.rewrite(body, scope, native_imports)?
                }
                Op::While { test, body, .. } => {
                    self.rewrite(test, scope, native_imports)?;
                    self.rewrite(body, scope, native_imports)?;
                }
                _ => {}
            }
        }
        Ok(())
    }
}
fn substitute_ops(ops: &mut [Op], args: &[Ty]) -> Result<(), String> {
    for op in ops {
        match op {
            Op::Record { ty, .. } | Op::Variant { ty, .. } => {
                *ty = ty.substitute_types(args)?.erase_regions()
            }
            Op::GenericCall {
                type_args: Some(ts),
                ..
            } => {
                *ts = ts
                    .iter()
                    .map(|t| t.substitute_types(args).map(|t| t.erase_regions()))
                    .collect::<Result<_, _>>()?
            }
            Op::If { yes, no, .. } => {
                substitute_ops(yes, args)?;
                substitute_ops(no, args)?;
            }
            Op::Match { arms, .. } => {
                for a in arms {
                    substitute_ops(&mut a.body, args)?;
                }
            }
            Op::Block { body } | Op::Loop { body, .. } => substitute_ops(body, args)?,
            Op::While { test, body, .. } => {
                substitute_ops(test, args)?;
                substitute_ops(body, args)?;
            }
            _ => {}
        }
    }
    Ok(())
}
fn has_generics(ops: &[Op]) -> bool {
    ops.iter().any(|op| match op {
        Op::GenericCall { .. } => true,
        Op::If { yes, no, .. } => has_generics(yes) || has_generics(no),
        Op::Match { arms, .. } => arms.iter().any(|a| has_generics(&a.body)),
        Op::Block { body } | Op::Loop { body, .. } => has_generics(body),
        Op::While { test, body, .. } => has_generics(test) || has_generics(body),
        _ => false,
    })
}
pub(crate) fn materialize<F: FnMut(&str) -> Result<Bundle, String>>(
    source: &CheckedModule,
    resolve: &mut F,
) -> Result<NativeModule, String> {
    if source.bundle.is_none()
        && !source
            .functions
            .iter()
            .any(|(p, _)| has_generics(&p.function.ops))
    {
        return Ok(NativeModule {
            functions: source.functions.clone(),
            layouts: source.layouts.clone(),
        });
    }
    let mut e = Engine {
        source,
        resolve,
        layouts: source.layouts.clone(),
        bundles: BTreeMap::new(),
        normal: source
            .functions
            .iter()
            .enumerate()
            .map(|(i, (p, _))| (p.function.sig.name.clone(), i))
            .collect(),
        queue: VecDeque::new(),
        queued: BTreeSet::new(),
        memo: BTreeMap::new(),
        output: Vec::new(),
    };
    if let Some(b) = &source.bundle {
        let hash = b.hash()?;
        if source.header.template_hash.as_ref() != Some(&hash) {
            return Err("local template body hash mismatch".into());
        }
        e.bundles
            .insert(source.header.name.clone(), (Arc::new(b.clone()), hash));
    }
    for (i, (_, public)) in source.functions.iter().enumerate() {
        if *public {
            e.original(i)?;
        }
    }
    while let Some(Job {
        mut body,
        public,
        origin,
        logical,
    }) = e.queue.pop_front()
    {
        let mut native_imports = BTreeMap::new();
        let sig = body.function.sig.clone();
        e.rewrite(
            &mut body.function.ops,
            &RewriteScope {
                types: &body.types,
                generics: &body.generics,
                imports: &body.imports,
                origin: origin.as_deref(),
                logical: &logical,
                current: &sig,
            },
            &mut native_imports,
        )?;
        body.imports = native_imports;
        e.output.push((body, public));
    }
    for (p, _) in &mut e.output {
        p.layouts = e.layouts.clone();
    }
    Ok(NativeModule {
        functions: e.output,
        layouts: e.layouts,
    })
}
