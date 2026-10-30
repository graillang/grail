//! Canonical source-module surfaces and direct dependency contracts; bodies remain hidden.
use crate::{Checked, Sig, name_ok};
use std::collections::BTreeMap;
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Interface {
    pub name: String,
    pub entry: String,
    pub exports: BTreeMap<String, Sig>,
    pub dependencies: BTreeMap<String, String>,
}
impl Interface {
    pub fn single(sig: Sig) -> Self {
        Self {
            name: sig.name.clone(),
            entry: sig.name.clone(),
            exports: BTreeMap::from([(sig.name.clone(), sig)]),
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
        for (name, sig) in &self.exports {
            sig.validate()?;
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
            "grail-seed-surface-1\n{}\n{}\n{}\n",
            self.name,
            self.entry,
            self.exports.len()
        );
        for sig in self.exports.values() {
            s.push_str(&sig.encode()?);
        }
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
            "grail-seed-module-1\n{}\n{}\n{}\n{}\n",
            self.name,
            self.entry,
            self.exports.len(),
            self.dependencies.len()
        );
        for sig in self.exports.values() {
            s.push_str(&sig.encode()?);
        }
        for (name, hash) in &self.dependencies {
            s.push_str(name);
            s.push('\n');
            s.push_str(hash);
            s.push('\n');
        }
        Ok(s)
    }
    pub fn decode(text: &str) -> Result<Self, String> {
        if text.len() > 8 * 1024 * 1024 {
            return Err("module interface too large".into());
        }
        let lines = text.lines().collect::<Vec<_>>();
        if lines.len() < 5 || lines[0] != "grail-seed-module-1" {
            return Err("invalid source module schema; rebuild source artifacts".into());
        }
        let n: usize = lines[3].parse().map_err(|_| "invalid export count")?;
        let d: usize = lines[4].parse().map_err(|_| "invalid dependency count")?;
        if n == 0 || n > 4096 || d > 4096 || lines.len() != 5 + n * 4 + d * 2 {
            return Err("invalid module counts".into());
        }
        let mut exports = BTreeMap::new();
        for i in 0..n {
            let at = 5 + i * 4;
            let sig = Sig::decode(&(lines[at..at + 4].join("\n") + "\n"))?;
            if exports.insert(sig.name.clone(), sig).is_some() {
                return Err("duplicate export".into());
            }
        }
        let mut dependencies = BTreeMap::new();
        for i in 0..d {
            let at = 5 + n * 4 + i * 2;
            if dependencies
                .insert(lines[at].into(), lines[at + 1].into())
                .is_some()
            {
                return Err("duplicate dependency".into());
            }
        }
        let module = Self {
            name: lines[1].into(),
            entry: lines[2].into(),
            exports,
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
