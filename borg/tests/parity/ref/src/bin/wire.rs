//! Wire reference for `borg/tests/wire_test.grl`.
//!
//! The JSON layer is checked by `json.rs`, which is pure serde_json. There is no upstream Rust
//! program that classifies these fixtures without building the whole Borg workspace, so this
//! reference pins the v1 header rule itself — the one `borg/src/wire.grl` implements — and uses
//! serde_json for every value it reads. A divergence in either the parser or the rule shows up as
//! a line difference, and both sides read the same bytes.
//!
//! Reason names (`missing`, `type`, `protocol`, `version`, `envelope`) are part of the contract so
//! a failure names the layer that rejected the document.

use serde_json::{Map, Value};

type Checked<T> = Result<T, (String, String)>;

fn missing(path: &str) -> (String, String) {
    (path.to_string(), "missing".to_string())
}

fn wrong_type(path: &str) -> (String, String) {
    (path.to_string(), "type".to_string())
}

fn object<'a>(value: &'a Value, path: &str) -> Checked<&'a Map<String, Value>> {
    value.as_object().ok_or_else(|| wrong_type(path))
}

fn field<'a>(map: &'a Map<String, Value>, key: &str, path: &str) -> Checked<&'a Value> {
    map.get(key).ok_or_else(|| missing(&format!("{path}.{key}")))
}

fn string(map: &Map<String, Value>, key: &str, path: &str) -> Checked<String> {
    let value = field(map, key, path)?;
    let at = format!("{path}.{key}");
    value.as_str().map(str::to_string).ok_or_else(|| wrong_type(&at))
}

fn number(map: &Map<String, Value>, key: &str, path: &str) -> Checked<String> {
    let value = field(map, key, path)?;
    let at = format!("{path}.{key}");
    let number = value.as_number().ok_or_else(|| wrong_type(&at))?;
    if number.as_u64().is_none() {
        return Err(wrong_type(&at));
    }
    Ok(number.to_string())
}

fn object_field<'a>(map: &'a Map<String, Value>, key: &str, path: &str) -> Checked<&'a Map<String, Value>> {
    object(field(map, key, path)?, &format!("{path}.{key}"))
}

fn header(root: &Value) -> Checked<Vec<(String, String)>> {
    let map = object(root, "$")?;
    let protocol = string(map, "protocol", "$")?;
    if protocol != "borg.agent_runtime" {
        return Err(("$.protocol".to_string(), "protocol".to_string()));
    }
    let version = number(map, "version", "$")?;
    if version != "1" {
        return Err(("$.version".to_string(), "version".to_string()));
    }
    let mut out = vec![
        ("protocol".to_string(), protocol),
        ("version".to_string(), version),
    ];
    if map.contains_key("command") {
        out.push(("kind".to_string(), "command".to_string()));
        for key in ["request_id", "correlation_id", "idempotency_key"] {
            out.push((key.to_string(), string(map, key, "$")?));
        }
        out.push(("sequence".to_string(), number(map, "sequence", "$")?));
        out.push(("created_at".to_string(), string(map, "created_at", "$")?));
        let command = object_field(map, "command", "$")?;
        out.push(("command_type".to_string(), string(command, "type", "$.command")?));
        out.push(("session_id".to_string(), string(command, "session_id", "$.command")?));
    } else if map.contains_key("event") {
        out.push(("kind".to_string(), "event".to_string()));
        out.push(("session_id".to_string(), string(map, "session_id", "$")?));
        out.push(("cursor".to_string(), number(map, "cursor", "$")?));
        let event = object_field(map, "event", "$")?;
        let kind = object_field(event, "kind", "$.event")?;
        out.push(("event_type".to_string(), string(kind, "type", "$.event.kind")?));
    } else if map.contains_key("state") {
        out.push(("kind".to_string(), "snapshot".to_string()));
        out.push(("session_id".to_string(), string(map, "session_id", "$")?));
        out.push(("cursor".to_string(), number(map, "cursor", "$")?));
        let state = object_field(map, "state", "$")?;
        out.push(("state_status".to_string(), string(state, "status", "$.state")?));
    } else if map.contains_key("fixtures") {
        out.push(("kind".to_string(), "manifest".to_string()));
        out.push(("fixture_schema".to_string(), number(map, "fixture_schema", "$")?));
        let fixtures = field(map, "fixtures", "$")?
            .as_array()
            .ok_or_else(|| wrong_type("$.fixtures"))?;
        let mut names = Vec::new();
        for (index, item) in fixtures.iter().enumerate() {
            names.push(item.as_str().ok_or_else(|| wrong_type(&format!("$.fixtures[{index}]")))?.to_string());
        }
        out.push(("fixtures".to_string(), names.join(",")));
        let compatibility = object_field(map, "compatibility", "$")?;
        out.push((
            "legacy_protocol".to_string(),
            string(compatibility, "legacy_host_protocol", "$.compatibility")?,
        ));
        out.push((
            "legacy_version".to_string(),
            number(compatibility, "legacy_host_protocol_version", "$.compatibility")?,
        ));
        out.push((
            "adapter".to_string(),
            string(compatibility, "adapter", "$.compatibility")?,
        ));
    } else {
        return Err(("$".to_string(), "envelope".to_string()));
    }
    Ok(out)
}

fn main() {
    for path in std::env::args().skip(1) {
        let file = path.rsplit('/').next().unwrap_or(&path).to_string();
        let Ok(text) = std::fs::read_to_string(&path) else {
            println!("wire.error {file} $ json");
            continue;
        };
        let root: Value = match serde_json::from_str(&text) {
            Ok(value) => value,
            Err(_) => {
                println!("wire.error {file} $ json");
                continue;
            }
        };
        match header(&root) {
            Ok(fields) => {
                for (key, value) in fields {
                    println!("wire.header {file} {key} {value}");
                }
            }
            Err((path, reason)) => println!("wire.error {file} {path} {reason}"),
        }
    }
}
