//! Reference for `borg/tests/session_test.grl`.
//!
//! No crate can be linked here: the owner-record rules live in `borg-agent-runtime`, whose build
//! pulls the whole 363k-line workspace. This binary therefore carries the rule **copied verbatim**
//! from Borg's source, with the citation next to each function, and applies it to the same scenario
//! documents the port reads. `bun tools/borg-test.mjs --anchors` re-checks that each cited snippet
//! still exists in the agent checkout, so a rule change upstream fails this reference instead of
//! silently diverging.
//!
//! Citations (crates/borg-agent-runtime/src/local_control.rs):
//!   LocalSessionOwnerMetadata        :405-414
//!   read_local_session_owner_metadata:529-542  (parse -> None, version != 1 -> None)
//!   executable_identity              :559-572
//!   process_start_time               :607-624  (rsplit_once(") "), nth(19))
//!   owner_process_matches_metadata   :631-649
//!   obsolete_local_session_owner_pid :656-671  (shape: identity differs, owner matches, lock held)

use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Copied from `struct LocalSessionOwnerMetadata` (local_control.rs:405).
#[derive(Debug, Deserialize, Serialize)]
struct OwnerRecord {
    schema_version: u8,
    pid: u32,
    executable_identity: String,
    #[serde(default)]
    package_version: Option<String>,
    #[serde(default)]
    process_start_time: Option<u64>,
}

/// Mirrors `read_local_session_owner_metadata`: a document that does not deserialize, or whose
/// schema version is not 1, is absent — not an error.
fn read_record(text: &str) -> Result<OwnerRecord, &'static str> {
    match serde_json::from_str::<OwnerRecord>(text) {
        Ok(record) if record.schema_version == 1 => Ok(record),
        Ok(_) => Err("schema"),
        Err(_) => Err("parse"),
    }
}

/// Copied from `executable_identity` (local_control.rs:559), unix branch.
fn executable_identity(dev: u64, ino: u64, len: u64, mtime: i64, mtime_nsec: i64) -> String {
    format!("{dev}:{ino}:{len}:{mtime}:{mtime_nsec}")
}

/// Copied from `process_start_time` (local_control.rs:607): the field after the last `") "` is the
/// rest of the stat line, and the state start time is its index 19.
fn process_start_time(contents: &str) -> Option<u64> {
    let (_, fields) = contents.rsplit_once(") ")?;
    fields.split_whitespace().nth(19).and_then(|value| value.parse().ok())
}

/// Copied from `owner_process_matches_metadata` (local_control.rs:631), linux branch, with the
/// observations supplied instead of read from `/proc`.
fn owner_process_matches(
    record: &OwnerRecord,
    alive: bool,
    identity: Option<&str>,
    start_time: Option<Option<u64>>,
) -> bool {
    if !alive {
        return false;
    }
    let Some(identity) = identity else {
        return false;
    };
    if identity != record.executable_identity {
        return false;
    }
    if let Some(expected) = record.process_start_time
        && start_time.flatten() != Some(expected)
    {
        return false;
    }
    true
}

fn state(record: Option<&OwnerRecord>, present: bool, alive: bool, identity: Option<&str>, start: Option<Option<u64>>) -> &'static str {
    match record {
        Some(found) => {
            if owner_process_matches(found, alive, identity, start) {
                "active"
            } else {
                "stale"
            }
        }
        None if present => "invalid",
        None => "absent",
    }
}

fn field<'a>(value: &'a Value, key: &str) -> Option<&'a Value> {
    value.get(key).filter(|item| !item.is_null())
}

fn optional_u64(value: Option<&Value>) -> Option<Option<u64>> {
    value.map(|item| item.as_u64())
}

fn main() {
    for path in std::env::args().skip(1) {
        let Ok(text) = std::fs::read_to_string(&path) else { continue };
        let Ok(case) = serde_json::from_str::<Value>(&text) else { continue };
        let name = case.get("name").and_then(Value::as_str).unwrap_or("unnamed");

        if let Some(line) = case.get("stat_line").and_then(Value::as_str) {
            match process_start_time(line) {
                Some(value) => println!("case {name} start {value}"),
                None => println!("case {name} start none"),
            }
        }
        if let Some(parts) = case.get("identity_parts").and_then(Value::as_array) {
            let numbers: Vec<i64> = parts.iter().filter_map(Value::as_i64).collect();
            if numbers.len() == 5 {
                println!(
                    "case {name} identity {}",
                    executable_identity(numbers[0] as u64, numbers[1] as u64, numbers[2] as u64, numbers[3], numbers[4])
                );
            }
        }

        let record_text = case.get("record_text").and_then(Value::as_str);
        let present = case
            .get("present")
            .and_then(Value::as_bool)
            .unwrap_or(record_text.is_some());
        let decoded = record_text.map(read_record);
        if record_text.is_some() {
            match decoded.as_ref().and_then(|result| result.as_ref().ok()) {
                Some(record) => {
                    println!("case {name} record ok");
                    println!("case {name} field schema_version {}", record.schema_version);
                    println!("case {name} field pid {}", record.pid);
                    println!("case {name} field executable_identity {}", record.executable_identity);
                    println!(
                        "case {name} field package_version {}",
                        record.package_version.as_deref().unwrap_or("-")
                    );
                    println!(
                        "case {name} field process_start_time {}",
                        record.process_start_time.map(|value| value.to_string()).unwrap_or_else(|| "-".to_string())
                    );
                    // Encode, decode again, compare: the writer is checked against the reader.
                    let encoded = serde_json::to_string(record).expect("record serialises");
                    let roundtrip = match read_record(&encoded) {
                        Ok(again) => {
                            again.schema_version == record.schema_version
                                && again.pid == record.pid
                                && again.package_version == record.package_version
                        }
                        Err(_) => false,
                    };
                    println!("case {name} roundtrip {}", if roundtrip { "ok" } else { "fail" });
                }
                None => {
                    let reason = decoded.as_ref().and_then(|result| result.as_ref().err()).copied().unwrap_or("parse");
                    println!("case {name} record invalid {reason}");
                }
            }
        }

        let has_process = case.get("alive").is_some() || case.get("identity").is_some();
        if has_process {
            let alive = case.get("alive").and_then(Value::as_bool).unwrap_or(false);
            let identity = case.get("identity").and_then(Value::as_str);
            let start = optional_u64(field(&case, "start_time"));
            let current = case.get("current_identity").and_then(Value::as_str);
            let holds_lock = case.get("holds_lock").and_then(Value::as_bool).unwrap_or(false);
            let found = decoded.as_ref().and_then(|result| result.as_ref().ok());
            let active = found.map(|record| owner_process_matches(record, alive, identity, start)).unwrap_or(false);
            println!("case {name} active {active}");
            println!("case {name} state {}", state(found, present, alive, identity, start));
            // `obsolete_local_session_owner_pid` (local_control.rs:656)
            let obsolete = match (found, current) {
                (Some(record), Some(current)) => {
                    record.executable_identity != current
                        && owner_process_matches(record, alive, identity, start)
                        && holds_lock
                }
                _ => false,
            };
            println!("case {name} obsolete {obsolete}");
        }
    }
}
