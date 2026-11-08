//! Reference for `borg/tests/config_test.grl`.
//!
//! Applies Borg's compiled-in defaults (`impl Default for CapabilityConfig`, `UsageCountConfig`,
//! `PromptConfig`, `UpdateConfig` in crates/borg-cli/src/agent_config.rs) to a `toml` value parsed
//! from the same bytes, then the capability intersection Borg actually applies
//! (`apply_dependency_intersection` in crates/borg-agent-runtime/src/contract.rs), and prints the
//! same schema-ordered lines. A wrong-typed key is an error at its path, not a fallback.

use std::collections::BTreeMap;

use toml::Value;

fn label(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}

/// Capability keys in `CapabilityConfig` declaration order, with their compiled-in defaults.
const CAPABILITIES: [(&str, bool); 12] = [
    ("multiplayer", true),
    ("subagents", true),
    ("autonomous_team", true),
    ("shared_work", true),
    ("presence", true),
    ("cloud_sync", true),
    ("web_relay", true),
    ("telemetry", false),
    ("auto_resume_usage_limits", true),
    ("watcher_yield", true),
    ("resume_paused_goal_on_message", false),
    ("claude_refusal_fallback", false),
];

struct Loader {
    root: Value,
    lines: Vec<String>,
    file: String,
}

impl Loader {
    fn table(&self, section: &str) -> Option<&toml::Table> {
        self.root.get(section).and_then(Value::as_table)
    }

    fn push_flag(&mut self, path: &str, value: bool) {
        self.lines.push(format!("config.value {} {path} {value}", self.file));
    }

    fn flag(&mut self, section: &str, key: &str, fallback: bool) -> Result<bool, String> {
        let path = format!("{section}.{key}");
        let value = match self.table(section).and_then(|t| t.get(key)) {
            None => fallback,
            Some(Value::Boolean(flag)) => *flag,
            Some(_) => return Err(path),
        };
        self.push_flag(&path, value);
        Ok(value)
    }

    fn text(&mut self, section: &str, key: &str) -> Result<(), String> {
        let path = format!("{section}.{key}");
        let value = match self.table(section).and_then(|t| t.get(key)) {
            None => String::new(),
            Some(Value::String(text)) => text.clone(),
            Some(_) => return Err(path),
        };
        let quoted = serde_json::to_string(&value).expect("string serialises");
        self.lines.push(format!("config.value {} {path} {quoted}", self.file));
        Ok(())
    }

    fn count(&mut self, section: &str, key: &str, fallback: u64) -> Result<(), String> {
        let path = format!("{section}.{key}");
        let value = match self.table(section).and_then(|t| t.get(key)) {
            None => fallback,
            Some(Value::Integer(number)) if *number >= 0 => *number as u64,
            Some(_) => return Err(path),
        };
        self.lines.push(format!("config.value {} {path} {value}", self.file));
        Ok(())
    }
}

fn schema(loader: &mut Loader) -> Result<(), String> {
    let mut flags: BTreeMap<&str, bool> = BTreeMap::new();
    for (key, fallback) in CAPABILITIES {
        let value = match loader.table("capabilities").and_then(|t| t.get(key)) {
            None => fallback,
            Some(Value::Boolean(flag)) => *flag,
            Some(_) => return Err(format!("capabilities.{key}")),
        };
        flags.insert(key, value);
    }
    // A dependent feature is only as available as its parent.
    if !flags["subagents"] {
        flags.insert("autonomous_team", false);
    }
    if !flags["multiplayer"] {
        flags.insert("shared_work", false);
        flags.insert("presence", false);
    }
    if !flags["cloud_sync"] {
        flags.insert("web_relay", false);
    }
    for (key, _) in CAPABILITIES {
        let path = format!("capabilities.{key}");
        let value = flags[key];
        loader.push_flag(&path, value);
    }
    loader.flag("usage_count", "enabled", false)?;
    loader.text("prompt", "append")?;
    loader.flag("update", "auto_install", true)?;
    loader.count("update", "check_interval_hours", 24)?;
    Ok(())
}

fn main() {
    for path in std::env::args().skip(1) {
        let name = label(&path);
        let Ok(text) = std::fs::read_to_string(&path) else {
            println!("config.error {name} parse");
            continue;
        };
        let Ok(value) = toml::from_str::<Value>(&text) else {
            println!("config.error {name} parse");
            continue;
        };
        if !value.is_table() {
            println!("config.error {name} $");
            continue;
        }
        let mut loader = Loader { root: value, lines: Vec::new(), file: name.clone() };
        match schema(&mut loader) {
            Ok(()) => {
                for line in loader.lines {
                    println!("{line}");
                }
            }
            Err(at) => println!("config.error {name} {at}"),
        }
    }
}
