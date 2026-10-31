//! Public checking contracts and separately pinned implementation dependencies.
use crate::{Checked, Sig, name_ok, template, types};
use std::collections::BTreeMap;
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Interface {
    pub name: String,
    pub entry: Option<String>,
    pub exports: BTreeMap<String, Sig>,
    pub generics: BTreeMap<String, template::Signature>,
    pub layouts: types::Definitions,
    pub dependencies: BTreeMap<String, String>,
    pub implementations: BTreeMap<String, String>,
    pub template_hash: Option<String>,
}
impl Interface {
    pub fn single(sig: Sig) -> Self {
        Self {
            name: sig.name.clone(),
            entry: Some(sig.name.clone()),
            exports: BTreeMap::from([(sig.name.clone(), sig)]),
            generics: BTreeMap::new(),
            layouts: BTreeMap::new(),
            dependencies: BTreeMap::new(),
            implementations: BTreeMap::new(),
            template_hash: None,
        }
    }
    fn prefix(&self) -> String {
        format!(
            "grail-seed-module-5\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n{}\n",
            self.name,
            self.entry.as_deref().unwrap_or(""),
            self.exports.len(),
            self.generics.len(),
            self.dependencies.len(),
            self.implementations.len(),
            self.layouts.len(),
            self.template_hash.as_deref().unwrap_or("")
        )
    }
    pub fn validate(&self) -> Result<(), String> {
        if !name_ok(&self.name)
            || (self.exports.is_empty() && self.generics.is_empty() && self.layouts.is_empty())
            || self.exports.len() + self.generics.len() > 4096
            || self.dependencies.len() > 4096
            || self.implementations.len() > 4096
            || match &self.entry {
                Some(n) => !self.exports.contains_key(n),
                None => !self.exports.is_empty(),
            }
        {
            return Err("invalid module name/export count/entry".into());
        }
        if self
            .template_hash
            .as_ref()
            .is_some_and(|h| !crate::sha256::is_hex(h))
        {
            return Err("invalid template body hash".into());
        }
        for (n, h) in &self.dependencies {
            if !name_ok(n) || n == &self.name || !crate::sha256::is_hex(h) {
                return Err("invalid module dependency".into());
            }
        }
        for (n, h) in &self.implementations {
            if !self.dependencies.contains_key(n) || !crate::sha256::is_hex(h) {
                return Err("invalid implementation dependency".into());
            }
        }
        // Shape/byte bounds precede layout expansion and publication on producers too.
        let mut bytes = self.prefix().len();
        for sig in self.exports.values() {
            bytes += sig.encode()?.len();
        }
        for g in self.generics.values() {
            bytes += g.encode()?.len();
        }
        for (n, d) in &self.layouts {
            bytes += format!(
                "{n}\n{}\n{}\n{}\n{}\n",
                d.kind.word(),
                d.regions,
                d.parameters,
                d.fields.len()
            )
            .len();
            for (n, t) in &d.fields {
                t.validate_shape(d.parameters)?;
                bytes += n.len() + t.word().len() + 2;
                if bytes > 8 * 1024 * 1024 {
                    return Err("module interface too large".into());
                }
            }
        }
        for (n, h) in self.dependencies.iter().chain(&self.implementations) {
            bytes += n.len() + h.len() + 2;
        }
        if bytes > 8 * 1024 * 1024 {
            return Err("module interface too large".into());
        }
        types::validate(&self.layouts)?;
        for (name, sig) in &self.exports {
            types::validate_sig(sig, &self.layouts)?;
            let member = name.strip_prefix(&format!("{}::", self.name));
            if name != &sig.name || (name != &self.name && !member.is_some_and(name_ok)) {
                return Err("export does not belong to module".into());
            }
        }
        for (name, g) in &self.generics {
            g.validate(&self.layouts)?;
            if name != &g.function.name
                || self.exports.contains_key(name)
                || !name
                    .strip_prefix(&format!("{}::", self.name))
                    .is_some_and(name_ok)
            {
                return Err("generic export does not belong to module".into());
            }
        }
        Ok(())
    }
    fn layout_text(&self) -> String {
        let mut s = String::new();
        for (n, d) in &self.layouts {
            s.push_str(&format!(
                "{n}\n{}\n{}\n{}\n{}\n",
                d.kind.word(),
                d.regions,
                d.parameters,
                d.fields.len()
            ));
            for (n, t) in &d.fields {
                s.push_str(&format!("{n}={}\n", t.word()));
            }
        }
        s
    }
    fn surface(&self) -> Result<String, String> {
        self.validate()?;
        let mut s = format!(
            "grail-seed-surface-5\n{}\n{}\n{}\n{}\n{}\n",
            self.name,
            self.entry.as_deref().unwrap_or(""),
            self.exports.len(),
            self.generics.len(),
            self.layouts.len()
        );
        for sig in self.exports.values() {
            s.push_str(&sig.encode()?);
        }
        for g in self.generics.values() {
            s.push_str(&g.encode()?);
        }
        s.push_str(&self.layout_text());
        Ok(s)
    }
    /// Public types/contracts only; implementation pins are enforced independently at native linking.
    pub fn fingerprint(&self) -> Result<String, String> {
        Ok(crate::sha256::hex(self.surface()?.as_bytes()))
    }
    pub fn encode(&self) -> Result<String, String> {
        self.validate()?;
        let mut s = self.prefix();
        for sig in self.exports.values() {
            s.push_str(&sig.encode()?);
        }
        for g in self.generics.values() {
            s.push_str(&g.encode()?);
        }
        s.push_str(&self.layout_text());
        for (n, h) in self.dependencies.iter().chain(&self.implementations) {
            s.push_str(n);
            s.push('\n');
            s.push_str(h);
            s.push('\n');
        }
        Ok(s)
    }
    pub fn decode(text: &str) -> Result<Self, String> {
        if text.len() > 8 * 1024 * 1024 {
            return Err("module interface too large".into());
        }
        let lines = text.lines().collect::<Vec<_>>();
        if lines.len() < 9 || lines[0] != "grail-seed-module-5" {
            return Err("invalid source module schema; rebuild source artifacts".into());
        }
        let count = |i: usize| -> Result<usize, String> {
            let n = lines[i]
                .parse::<usize>()
                .map_err(|_| "invalid module count")?;
            if n > 4096 {
                return Err("module count limit".into());
            }
            Ok(n)
        };
        let (n, g, d, i, l) = (count(3)?, count(4)?, count(5)?, count(6)?, count(7)?);
        if n + g > 4096 || lines.len() < 9 + n * 4 + g * 6 + (d + i) * 2 {
            return Err("invalid module counts".into());
        }
        let mut at = 9;
        let mut exports = BTreeMap::new();
        for _ in 0..n {
            let sig = Sig::decode(&(lines[at..at + 4].join("\n") + "\n"))?;
            if exports.insert(sig.name.clone(), sig).is_some() {
                return Err("duplicate export".into());
            }
            at += 4;
        }
        let mut generics = BTreeMap::new();
        for _ in 0..g {
            let sig = template::Signature::decode(&(lines[at..at + 6].join("\n") + "\n"))?;
            if generics.insert(sig.function.name.clone(), sig).is_some() {
                return Err("duplicate generic export".into());
            }
            at += 6;
        }
        let mut layouts = BTreeMap::new();
        for _ in 0..l {
            if at + 5 > lines.len() {
                return Err("truncated layout".into());
            }
            let name = lines[at].to_string();
            let kind = match lines[at + 1] {
                "record" => types::Kind::Record,
                "enum" => types::Kind::Enum,
                _ => return Err("invalid layout kind".into()),
            };
            let regions = lines[at + 2]
                .parse::<u16>()
                .map_err(|_| "invalid layout lifetime count")?;
            let parameters = lines[at + 3]
                .parse::<u16>()
                .map_err(|_| "invalid layout type count")?;
            let count = lines[at + 4]
                .parse::<usize>()
                .map_err(|_| "invalid layout field count")?;
            at += 5;
            if count > 64 || at + count > lines.len() {
                return Err("layout field count limit".into());
            }
            let mut fields = Vec::new();
            for line in &lines[at..at + count] {
                let (n, t) = line.split_once('=').ok_or("invalid layout field")?;
                fields.push((n.into(), crate::Ty::parse(t)?));
            }
            at += count;
            if layouts
                .insert(
                    name,
                    types::Definition {
                        kind,
                        regions,
                        parameters,
                        fields,
                    },
                )
                .is_some()
            {
                return Err("duplicate layout".into());
            }
        }
        if at + (d + i) * 2 != lines.len() {
            return Err("invalid module dependency count".into());
        }
        let mut maps = [BTreeMap::new(), BTreeMap::new()];
        for (map, count) in maps.iter_mut().zip([d, i]) {
            for _ in 0..count {
                if map.insert(lines[at].into(), lines[at + 1].into()).is_some() {
                    return Err("duplicate module dependency".into());
                }
                at += 2;
            }
        }
        let [dependencies, implementations] = maps;
        let module = Self {
            name: lines[1].into(),
            entry: (!lines[2].is_empty()).then(|| lines[2].into()),
            exports,
            generics,
            layouts,
            dependencies,
            implementations,
            template_hash: (!lines[8].is_empty()).then(|| lines[8].into()),
        };
        module.validate()?;
        if module.encode()? != text {
            return Err("noncanonical module interface".into());
        }
        Ok(module)
    }
}
/// Only source checking constructs this flat module; function checks remain independently gated.
#[derive(Clone)]
pub struct CheckedModule {
    pub(crate) functions: Vec<(Checked, bool)>,
    pub(crate) header: Interface,
    pub(crate) layouts: crate::types::Context,
    pub(crate) bundle: Option<crate::template::Bundle>,
}
impl CheckedModule {
    pub fn template_ir(&self) -> Result<Vec<u8>, String> {
        self.bundle
            .as_ref()
            .map_or_else(|| Ok(Vec::new()), |b| b.encode())
    }
    pub fn interface(&self) -> String {
        self.header.encode().expect("validated module")
    }
    pub fn header(&self) -> &Interface {
        &self.header
    }
    pub fn entry_signature(&self) -> Option<&Sig> {
        self.header
            .entry
            .as_ref()
            .and_then(|n| self.header.exports.get(n))
    }
}
