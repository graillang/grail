//! Reference for `borg/tests/journal_test.grl`.
//!
//! Copied from Borg with citations; `--anchors` re-checks the snippets:
//!
//!   persistence        borg-agent-runtime/src/session_store.rs:280-400
//!   cursor advance     session.rs:3184   per-child cursor is the max sequence
//!   resume             session.rs:14276  replay asks for events after the cursor
//!   paged recovery     session.rs:14539  activity_recovery_page returns `next`
//!   status             contract.rs:408   StatusChanged is a journaled event

use serde_json::Value;

fn provider_persistence(kind: &str) -> &'static str {
    match kind {
        "reasoning_snapshot" | "native_model_message" | "native_context_edit" | "native_model_request"
        | "native_model_usage" | "prompt_cache_observed" | "native_prompt_context"
        | "native_tool_round_completed" | "context_microcompaction" | "native_request_prefix"
        | "native_context_checkpoint" | "network_retry" | "usage_limit_retry"
        | "usage_limit_retry_cancelled" | "usage_limit_retry_released" | "context_compaction"
        | "context_compaction_failed" | "context_replay_projected" | "context_replay_fallback"
        | "item/started:contextCompaction" | "item/completed:contextCompaction"
        | "item/started:context_compaction" | "item/completed:context_compaction"
        | "provider_prompt" | "native_steer_applied" | "action/preparing"
        | "action/preparing_cancelled" | "turn_effort" | "message_summarized"
        | "message_redirected" => "durable",
        "action/generation_status" => "coalesced",
        _ => "ephemeral",
    }
}

fn message_persistence(user_or_system: bool, in_progress: bool) -> &'static str {
    if !in_progress {
        return "durable";
    }
    if user_or_system {
        return "durable";
    }
    "coalesced"
}

fn subagent_persistence(child: &str, child_is_provider: bool, child_is_metadata: bool) -> &'static str {
    match child {
        "durable" => {
            if child_is_provider || child_is_metadata {
                "ephemeral"
            } else {
                "durable"
            }
        }
        _ => "ephemeral",
    }
}

fn text(value: &Value, key: &str) -> String {
    value.get(key).and_then(Value::as_str).unwrap_or("").to_string()
}

fn number(value: &Value, key: &str, fallback: u64) -> u64 {
    value.get(key).and_then(Value::as_u64).unwrap_or(fallback)
}

fn flag(value: &Value, key: &str) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(false)
}

fn main() {
    for path in std::env::args().skip(1) {
        let Ok(bytes) = std::fs::read_to_string(&path) else { continue };
        let Ok(scenario) = serde_json::from_str::<Value>(&bytes) else { continue };
        let name = scenario.get("name").and_then(Value::as_str).unwrap_or("unnamed").to_string();
        match scenario.get("kind").and_then(Value::as_str).unwrap_or("") {
            "provider" => println!("persistence {name} {}", provider_persistence(&text(&scenario, "provider_kind"))),
            "message" => {
                let actor = text(&scenario, "actor");
                let user_or_system = actor == "user" || actor == "system";
                let in_progress = text(&scenario, "status") == "in_progress";
                println!("persistence {name} {}", message_persistence(user_or_system, in_progress));
            }
            "delta" => println!("persistence {name} ephemeral"),
            "reasoning" | "context-window" => println!("persistence {name} coalesced"),
            "subagent" => println!(
                "persistence {name} {}",
                subagent_persistence(&text(&scenario, "child"), flag(&scenario, "child_provider"), flag(&scenario, "child_metadata"))
            ),
            "cursor" => {
                let mut current = 0u64;
                for step in scenario.get("steps").and_then(Value::as_array).cloned().unwrap_or_default() {
                    if let Some(value) = step.as_u64() {
                        current = current.max(value);
                    }
                }
                println!("cursor {name} {current}");
            }
            "replay" => println!(
                "replay {name} {}",
                number(&scenario, "sequence", 0) > number(&scenario, "cursor", 0)
            ),
            "page" => {
                let cursor = number(&scenario, "cursor", 0);
                let latest = number(&scenario, "latest", 0);
                let size = number(&scenario, "page", 1);
                let from = cursor + 1;
                if from > latest {
                    println!("page {name} {from} {cursor} false");
                } else {
                    let to = (from + size - 1).min(latest);
                    println!("page {name} {from} {to} {}", to < latest);
                }
            }
            "status" => {
                let mut current = String::from("starting");
                for step in scenario.get("steps").and_then(Value::as_array).cloned().unwrap_or_default() {
                    if let Some(value) = step.as_str() {
                        // Every step is a journaled StatusChanged, so the last one wins.
                        current = value.to_string();
                    }
                }
                println!("status {name} {current}");
            }
            _ => {}
        }
    }
}
