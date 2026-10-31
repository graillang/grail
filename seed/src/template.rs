//! Independently checked, universally quantified by-value function contracts.
//! Parameters are opaque affine values, never unchecked native layout placeholders.
use crate::{Checked, Function, Sig, Ty, types};
use std::collections::BTreeMap;
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Signature {
    pub parameters: u16,
    pub function: Sig,
}
impl Signature {
    pub(crate) fn instantiate(&self, args: &[Ty]) -> Result<Sig, String> {
        if args.len() != self.parameters as usize {
            return Err("generic argument arity".into());
        }
        Ok(Sig {
            name: self.function.name.clone(),
            params: self
                .function
                .params
                .iter()
                .map(|t| t.substitute_types(args))
                .collect::<Result<_, _>>()?,
            result: self.function.result.substitute_types(args)?,
        })
    }
    pub(crate) fn arguments(
        &self,
        actual: &[Ty],
        explicit: Option<&[Ty]>,
        caller_parameters: u16,
        layouts: &types::Definitions,
    ) -> Result<Vec<Ty>, String> {
        if actual.len() != self.function.params.len() {
            return Err("generic call arity".into());
        }
        fn unify(pattern: &Ty, actual: &Ty, args: &mut [Option<Ty>]) -> Result<(), String> {
            match pattern {
                Ty::Param(i) => {
                    let slot = args
                        .get_mut(*i as usize)
                        .ok_or("invalid generic type slot")?;
                    if let Some(t) = slot {
                        if !crate::aggregate::compatible(t, actual) {
                            return Err("conflicting generic arguments".into());
                        }
                    } else {
                        *slot = Some(actual.clone());
                    }
                }
                Ty::Ref(m, _, t) => {
                    let Ty::Ref(a, _, v) = actual else {
                        return Err("generic typed-reference shape".into());
                    };
                    if m != a {
                        return Err("generic typed-reference mode".into());
                    }
                    unify(t, v, args)?;
                }
                Ty::Named(n, _, ts) => {
                    let Ty::Named(a, _, values) = actual else {
                        return Err("generic nominal argument shape".into());
                    };
                    if n != a || ts.len() != values.len() {
                        return Err("generic nominal argument shape".into());
                    }
                    for (t, a) in ts.iter().zip(values) {
                        unify(t, a, args)?;
                    }
                }
                _ => {
                    if !crate::aggregate::compatible(pattern, actual) {
                        return Err("generic argument type/mode".into());
                    }
                }
            }
            Ok(())
        }
        let args = if let Some(args) = explicit {
            if args.len() != self.parameters as usize {
                return Err("generic argument arity".into());
            }
            args.to_vec()
        } else {
            let mut slots = vec![None; self.parameters as usize];
            for (p, a) in self.function.params.iter().zip(actual) {
                unify(p, a, &mut slots)?;
            }
            slots
                .into_iter()
                .map(|t| {
                    t.ok_or_else(|| {
                        "cannot infer generic type argument; provide it explicitly".to_string()
                    })
                })
                .collect::<Result<Vec<_>, _>>()?
        };
        for t in &args {
            types::validate_type(t, layouts, caller_parameters)?;
        }
        Ok(args)
    }
    pub fn validate(&self, layouts: &types::Definitions) -> Result<(), String> {
        if self.parameters == 0 || self.parameters > 64 {
            return Err("generic function parameter count".into());
        }
        types::validate_sig_bound(&self.function, layouts, self.parameters)
    }
    pub fn encode(&self) -> Result<String, String> {
        if self.parameters == 0 || self.parameters > 64 {
            return Err("generic function parameter count".into());
        }
        let text = format!(
            "grail-seed-generic-signature-1\n{}\n{}",
            self.parameters,
            self.function.encode_bound(self.parameters)?
        );
        if text.len() > 65536 {
            return Err("generic signature byte limit".into());
        }
        Ok(text)
    }
    pub fn decode(text: &str) -> Result<Self, String> {
        if text.len() > 65536 {
            return Err("generic signature byte limit".into());
        }
        let mut lines = text.splitn(3, '\n');
        if lines.next() != Some("grail-seed-generic-signature-1") {
            return Err("invalid generic signature schema".into());
        }
        let parameters = lines
            .next()
            .ok_or("missing generic arity")?
            .parse::<u16>()
            .map_err(|_| "invalid generic arity")?;
        let function = Sig::decode_bound(
            lines.next().ok_or("missing generic function contract")?,
            parameters,
        )?;
        let result = Self {
            parameters,
            function,
        };
        if result.encode()? != text {
            return Err("noncanonical generic contract".into());
        }
        Ok(result)
    }
}
/// The body checks without concrete arguments, caller roots or native specialization.
#[derive(Clone)]
pub struct CheckedTemplate {
    pub(crate) body: Checked,
}
impl CheckedTemplate {
    pub fn encode_ir(&self) -> Result<Vec<u8>, String> {
        crate::ir::encode(&self.body)
    }
    pub fn decode_ir(data: &[u8], layouts: types::Context) -> Result<Self, String> {
        let body = crate::ir::decode(data, layouts)?;
        if body.type_parameters == 0 {
            return Err("checked IR is not a generic definition".into());
        }
        Ok(Self { body })
    }
    pub fn signature(&self) -> Signature {
        Signature {
            parameters: self.body.type_parameters,
            function: self.body.function.sig.clone(),
        }
    }
}
pub fn check(
    function: Function,
    parameters: u16,
    imports: BTreeMap<String, Sig>,
    layouts: types::Context,
) -> Result<CheckedTemplate, String> {
    check_with_generics(function, parameters, imports, layouts, BTreeMap::new())
}
pub fn check_with_generics(
    function: Function,
    parameters: u16,
    imports: BTreeMap<String, Sig>,
    layouts: types::Context,
    generics: BTreeMap<String, Signature>,
) -> Result<CheckedTemplate, String> {
    if parameters == 0 || parameters > 64 {
        return Err("generic function parameter count".into());
    }
    Ok(CheckedTemplate {
        body: crate::check_bound(function, imports, layouts, parameters, generics)?,
    })
}

/// Checked code/layout closure for specialization. It is not a caller-specific analysis result.
#[derive(Clone)]
pub struct Bundle {
    pub(crate) module: String,
    pub(crate) implementations: BTreeMap<String, String>,
    pub(crate) layouts: types::Context,
    pub(crate) functions: BTreeMap<String, Checked>,
}
impl Bundle {
    pub fn new(
        module: &str,
        templates: Vec<CheckedTemplate>,
        helpers: Vec<Checked>,
        layouts: types::Context,
    ) -> Result<Self, String> {
        let bodies = templates
            .into_iter()
            .map(|t| t.body)
            .chain(helpers)
            .collect();
        Self::from_bodies(module, layouts, bodies, BTreeMap::new())
    }
    pub(crate) fn from_bodies(
        module: &str,
        layouts: types::Context,
        bodies: Vec<Checked>,
        implementations: BTreeMap<String, String>,
    ) -> Result<Self, String> {
        if !crate::name_ok(module) || bodies.is_empty() || bodies.len() > 4096 {
            return Err("template bundle module/function limit".into());
        }
        if implementations.len() > 4096
            || implementations
                .iter()
                .any(|(n, h)| !crate::name_ok(n) || n == module || !crate::sha256::is_hex(h))
        {
            return Err("invalid template implementation dependency".into());
        }
        let mut functions = BTreeMap::new();
        let mut generic = false;
        let mut nodes = 0;
        for p in bodies {
            let name = &p.function.sig.name;
            let qualified = name
                .strip_prefix(&format!("{module}::"))
                .is_some_and(crate::name_ok);
            if (!qualified && !crate::name_ok(name)) || (p.type_parameters > 0 && !qualified) {
                return Err("template definition belongs to another module".into());
            }
            if *p.layouts != *layouts {
                return Err("template closure layout contexts differ".into());
            }
            generic |= p.type_parameters > 0;
            nodes += crate::ir::operation_count(&p.function.ops);
            if nodes > 262144 {
                return Err("template bundle operation limit".into());
            }
            if functions.insert(name.clone(), p).is_some() {
                return Err("duplicate template/helper definition".into());
            }
        }
        for p in functions.values() {
            for (n, sig) in &p.imports {
                if let Some(callee) = functions.get(n)
                    && (callee.type_parameters != 0 || callee.function.sig != *sig)
                {
                    return Err("private helper contract/definition mismatch".into());
                }
            }
            for (n, g) in p.generics.iter() {
                if let Some(callee) = functions.get(n) {
                    if callee.type_parameters != g.parameters || callee.function.sig != g.function {
                        return Err("generic helper contract/definition mismatch".into());
                    }
                } else if n.starts_with(&format!("{module}::")) {
                    return Err("missing local generic definition".into());
                }
            }
        }
        if !generic {
            return Err("template bundle needs a generic definition".into());
        }
        Ok(Self {
            module: module.into(),
            implementations,
            layouts,
            functions,
        })
    }
    pub fn encode(&self) -> Result<Vec<u8>, String> {
        let mut w = crate::ir::Writer::default();
        w.text("grail-seed-template-bundle-1")?;
        w.text(&self.module)?;
        w.num(self.implementations.len() as u64)?;
        for (n, h) in &self.implementations {
            w.text(n)?;
            w.text(h)?;
        }
        crate::ir::write_layouts(&mut w, &self.layouts)?;
        w.num(self.functions.len() as u64)?;
        for p in self.functions.values() {
            w.put(&crate::ir::encode(p)?)?;
        }
        Ok(w.data)
    }
    pub fn decode(data: &[u8]) -> Result<Self, String> {
        let mut r = crate::ir::Reader::new(data)?;
        if r.text()? != "grail-seed-template-bundle-1" {
            return Err("invalid template bundle schema".into());
        }
        let module = r.text()?;
        let count = r.count(4096)?;
        let mut implementations = BTreeMap::new();
        for _ in 0..count {
            let n = r.text()?;
            let h = r.text()?;
            if implementations.insert(n, h).is_some() {
                return Err("duplicate template implementation dependency".into());
            }
        }
        let layouts = crate::ir::read_layouts(&mut r)?;
        let count = r.count(4096)?;
        let mut bodies = Vec::new();
        let mut nodes = 0;
        for _ in 0..count {
            let p = crate::ir::decode(r.get()?, layouts.clone())?;
            nodes += crate::ir::operation_count(&p.function.ops);
            if nodes > 262144 {
                return Err("template bundle operation limit".into());
            }
            bodies.push(p);
        }
        r.done()?;
        let result = Self::from_bodies(&module, layouts, bodies, implementations)?;
        if result.encode()? != data {
            return Err("noncanonical template bundle".into());
        }
        Ok(result)
    }
    pub fn with_implementations(
        self,
        implementations: BTreeMap<String, String>,
    ) -> Result<Self, String> {
        Self::from_bodies(
            &self.module,
            self.layouts,
            self.functions.into_values().collect(),
            implementations,
        )
    }
    pub fn hash(&self) -> Result<String, String> {
        Ok(crate::sha256::hex(&self.encode()?))
    }
}
