//! Reference for `borg/tests/events_test.grl`.
//!
//! Mirrors the serde shapes of `SessionEvent` and the transcript `SessionEventKind` variants
//! (contract.rs:2624-2720) so the fixtures are accepted by the same derive rules the runtime uses,
//! including `#[serde(default)]`, `skip_serializing_if = "Vec::is_empty"` on attachments, and the
//! nullable `detail`/`delivery`/`usage_tokens`/`model` fields. `--anchors` re-checks the enum.

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Deserialize, Serialize)]
struct Event {
    id: String,
    session_id: String,
    sequence: u64,
    created_at: String,
    kind: Kind,
}

#[derive(Deserialize, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum Kind {
    SessionStarted,
    SessionTitled {
        title: String,
        #[serde(default)]
        generated: bool,
        #[serde(default)]
        usage_tokens: Option<u64>,
        #[serde(default)]
        model: Option<String>,
    },
    StatusChanged {
        status: String,
        detail: Option<String>,
    },
    Message {
        message_id: String,
        actor: String,
        text: String,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        attachments: Vec<String>,
        status: String,
        delivery: Option<String>,
    },
    MessageDelta {
        message_id: String,
        delta: String,
    },
}

fn tag(kind: &Kind) -> &'static str {
    match kind {
        Kind::SessionStarted => "session_started",
        Kind::SessionTitled { .. } => "session_titled",
        Kind::StatusChanged { .. } => "status_changed",
        Kind::Message { .. } => "message",
        Kind::MessageDelta { .. } => "message_delta",
    }
}

fn label(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}

fn main() {
    for path in std::env::args().skip(1) {
        let name = label(&path);
        let Ok(bytes) = std::fs::read_to_string(&path) else { continue };
        let Ok(value) = serde_json::from_str::<Value>(&bytes) else {
            println!("error {name} not-object");
            continue;
        };
        match serde_json::from_value::<Event>(value) {
            Ok(event) => {
                println!("tag {name} {}", tag(&event.kind));
                println!("field {name} sequence {}", event.sequence);
                let (title, generated, tokens, status, actor, text, attachments, delivery, detail) = match &event.kind {
                    Kind::SessionTitled { title, generated, usage_tokens, model: _ } => (
                        title.clone(),
                        generated.to_string(),
                        usage_tokens.map(|v| v.to_string()).unwrap_or_else(|| "-".into()),
                        "-".to_string(), "-".to_string(), "-".to_string(),
                        "0".to_string(), "-".to_string(), "-".to_string(),
                    ),
                    Kind::StatusChanged { status, detail } => (
                        "-".to_string(), "-".to_string(), "-".to_string(), status.clone(),
                        "-".to_string(), "-".to_string(), "0".to_string(), "-".to_string(),
                        detail.clone().unwrap_or_else(|| "-".into()),
                    ),
                    Kind::Message { actor, text, attachments, status, delivery, .. } => (
                        "-".to_string(), "-".to_string(), "-".to_string(), status.clone(),
                        actor.clone(), text.clone(), attachments.len().to_string(),
                        delivery.clone().unwrap_or_else(|| "-".into()), "-".to_string(),
                    ),
                    Kind::MessageDelta { delta, .. } => (
                        "-".to_string(), "-".to_string(), "-".to_string(), "-".to_string(),
                        "-".to_string(), delta.clone(), "0".to_string(), "-".to_string(), "-".to_string(),
                    ),
                    Kind::SessionStarted => (
                        "-".to_string(), "-".to_string(), "-".to_string(), "-".to_string(),
                        "-".to_string(), "-".to_string(), "0".to_string(), "-".to_string(), "-".to_string(),
                    ),
                };
                println!("field {name} title {title}");
                println!("field {name} generated {generated}");
                println!("field {name} usage_tokens {tokens}");
                println!("field {name} status {status}");
                println!("field {name} actor {actor}");
                println!("field {name} text {text}");
                println!("field {name} attachments {attachments}");
                println!("field {name} delivery {delivery}");
                println!("field {name} detail {detail}");
                // The exact wire text, then decode it again: the writer is checked against both
                // the reference's own encoding and the reader.
                let wire = serde_json::to_string(&event).expect("event serialises");
                println!("wire {name} {wire}");
                let roundtrip = serde_json::from_str::<Event>(&wire).is_ok();
                println!("roundtrip {name} {}", if roundtrip { "ok" } else { "fail" });
            }
            Err(error) => {
                let text = error.to_string();
                let reason = if text.contains("unknown variant") {
                    "unknown-kind"
                } else if text.contains("missing field") {
                    "missing"
                } else if text.contains("invalid type") {
                    "type"
                } else {
                    "shape"
                };
                println!("error {name} {reason}");
            }
        }
    }
}
