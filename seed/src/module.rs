//! Canonical source-module surfaces and direct dependency contracts; bodies remain hidden.
use crate::{Checked, Sig, name_ok};
use std::collections::BTreeMap;
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Interface {
    pub name: String,
    pub entry: String,
    pub exports: BTreeMap<String, Sig>,
    pub layouts: crate::types::Definitions,
    pub dependencies: BTreeMap<String, String>,
}
impl Interface {
    pub fn single(sig: Sig) -> Self {
        Self {
            name: sig.name.clone(),
            entry: sig.name.clone(),
            exports: BTreeMap::from([(sig.name.clone(), sig)]),
            layouts: BTreeMap::new(),
            dependencies: BTreeMap::new(),
        }
    }
    pub fn validate(&self) -> Result<(), String> {
        if !name_ok(&self.name)
            || self.exports.is_empty()
            || self.exports.len() > 4096
            || self.dependencies.len() > 4096
            || !self.exports.contains_key(&self.entry)
        {
            return Err("invalid module name/export count/entry".into());
        }
        // Enforce the byte bound before publication too, not only during decoding. Otherwise
        // a producer could atomically publish an interface that no consumer can admit.
        let mut bytes = format!(
            "grail-seed-module-3\n{}\n{}\n{}\n{}\n{}\n",
            self.name,
            self.entry,
            self.exports.len(),
            self.dependencies.len(),
            self.layouts.len()
        )
        .len();
        for sig in self.exports.values() {
            bytes += sig.encode()?.len();
        }
        for (n, d) in &self.layouts {
            bytes += format!(
                "{n}\n{}\n{}\n{}\n",
                d.kind.word(),
                d.regions,
                d.fields.len()
            )
            .len();
            for (n, t) in &d.fields {
                bytes += n.len() + t.word().len() + 2;
                if bytes > 8 * 1024 * 1024 {
                    return Err("module interface too large".into());
                }
            }
        }
        for (n, h) in &self.dependencies {
            bytes += n.len() + h.len() + 2;
        }
        if bytes > 8 * 1024 * 1024 {
            return Err("module interface too large".into());
        }
        crate::types::validate(&self.layouts)?;
        for (name, sig) in &self.exports {
            crate::types::validate_sig(sig, &self.layouts)?;
            let member = name.strip_prefix(&format!("{}::", self.name));
            if name != &sig.name || (name != &self.name && !member.is_some_and(name_ok)) {
                return Err("export does not belong to module".into());
            }
        }
        for (name, hash) in &self.dependencies {
            if !name_ok(name)
                || name == &self.name
                || hash.len() != 64
                || !hash
                    .bytes()
                    .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
            {
                return Err("invalid module dependency".into());
            }
        }
        Ok(())
    }
    fn surface(&self) -> Result<String, String> {
        self.validate()?;
        let mut s = format!(
            "grail-seed-surface-3\n{}\n{}\n{}\n{}\n",
            self.name,
            self.entry,
            self.exports.len(),
            self.layouts.len()
        );
        for sig in self.exports.values() {
            s.push_str(&sig.encode()?);
        }
        s.push_str(&self.record_text());
        Ok(s)
    }
    /// Fingerprint only the public surface: private bodies and dependency implementation edits
    /// need not invalidate callers. Link validation separately follows dependency contracts.
    pub fn fingerprint(&self) -> Result<String, String> {
        Ok(crate::sha256::hex(self.surface()?.as_bytes()))
    }
    pub fn encode(&self) -> Result<String, String> {
        self.validate()?;
        let mut s = format!(
            "grail-seed-module-3\n{}\n{}\n{}\n{}\n{}\n",
            self.name,
            self.entry,
            self.exports.len(),
            self.dependencies.len(),
            self.layouts.len()
        );
        for sig in self.exports.values() {
            s.push_str(&sig.encode()?);
        }
        s.push_str(&self.record_text());
        for (name, hash) in &self.dependencies {
            s.push_str(name);
            s.push('\n');
            s.push_str(hash);
            s.push('\n');
        }
        Ok(s)
    }
    fn record_text(&self) -> String {
        let mut s = String::new();
        for (n, d) in &self.layouts {
            s.push_str(&format!(
                "{n}\n{}\n{}\n{}\n",
                d.kind.word(),
                d.regions,
                d.fields.len()
            ));
            for (name, t) in &d.fields {
                s.push_str(&format!("{name}={}\n", t.word()));
            }
        }
        s
    }
    pub fn decode(text: &str) -> Result<Self, String> {
        if text.len() > 8 * 1024 * 1024 {
            return Err("module interface too large".into());
        }
        let lines = text.lines().collect::<Vec<_>>();
        if lines.len() < 6 || lines[0] != "grail-seed-module-3" {
            return Err("invalid source module schema; rebuild source artifacts".into());
        }
        let n: usize = lines[3].parse().map_err(|_| "invalid export count")?;
        let d: usize = lines[4].parse().map_err(|_| "invalid dependency count")?;
        let layouts: usize = lines[5].parse().map_err(|_| "invalid type count")?;
        if n == 0 || n > 4096 || d > 4096 || layouts > 4096 || lines.len() < 6 + n * 4 + d * 2 {
            return Err("invalid module counts".into());
        }
        let mut exports = BTreeMap::new();
        let mut at = 6;
        for _ in 0..n {
            let sig = Sig::decode(&(lines[at..at + 4].join("\n") + "\n"))?;
            if exports.insert(sig.name.clone(), sig).is_some() {
                return Err("duplicate export".into());
            }
            at += 4;
        }
        let mut types = BTreeMap::new();
        for _ in 0..layouts {
            if at + 4 > lines.len() {
                return Err("truncated record".into());
            }
            let name = lines[at].to_string();
            let kind = match lines[at + 1] {
                "record" => crate::types::Kind::Record,
                "enum" => crate::types::Kind::Enum,
                _ => return Err("invalid nominal layout kind".into()),
            };
            let regions = lines[at + 2]
                .parse::<u16>()
                .map_err(|_| "invalid record lifetime count")?;
            let count = lines[at + 3]
                .parse::<usize>()
                .map_err(|_| "invalid field count")?;
            at += 4;
            if count > 64 || at + count > lines.len() {
                return Err("invalid field count".into());
            }
            let mut fields = Vec::new();
            for line in &lines[at..at + count] {
                let (n, t) = line.split_once('=').ok_or("invalid field")?;
                fields.push((n.into(), crate::Ty::parse(t)?));
            }
            at += count;
            if types
                .insert(
                    name,
                    crate::types::Definition {
                        kind,
                        regions,
                        fields,
                    },
                )
                .is_some()
            {
                return Err("duplicate record".into());
            }
        }
        if at + d * 2 != lines.len() {
            return Err("invalid dependency count".into());
        }
        let mut dependencies = BTreeMap::new();
        for _ in 0..d {
            if dependencies
                .insert(lines[at].into(), lines[at + 1].into())
                .is_some()
            {
                return Err("duplicate dependency".into());
            }
            at += 2;
        }
        let module = Self {
            name: lines[1].into(),
            entry: lines[2].into(),
            exports,
            layouts: types,
            dependencies,
        };
        module.validate()?;
        if module.encode()? != text {
            return Err("noncanonical module interface".into());
        }
        Ok(module)
    }
}
/// Only source checking constructs this flat module; function checks remain independently gated.
pub struct CheckedModule {
    pub(crate) functions: Vec<(Checked, bool)>,
    pub(crate) header: Interface,
    pub(crate) layouts: crate::types::Context,
}
impl CheckedModule {
    pub fn interface(&self) -> String {
        self.header.encode().expect("validated module")
    }
    pub fn header(&self) -> &Interface {
        &self.header
    }
    pub fn entry_signature(&self) -> &Sig {
        &self.header.exports[&self.header.entry]
    }
}
