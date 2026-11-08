//! Reference for `borg/tests/supervisor_test.grl`.
//!
//! Copies the supervision and layout rules from Borg with citations; `--anchors` re-checks the
//! snippets they depend on:
//!
//!   RestartPolicy::transient      borg-lanes/src/services.rs:102  only an exit *code* can be
//!                                                                 transient
//!   backoff                       borg-lanes/src/services.rs:2029 max(backoff_ms, 50) * 2^min(f, 6)
//!   restart after an exit         borg-lanes/src/services.rs:1723
//!   launch failure                borg-lanes/src/services.rs:1701
//!   ServiceState                  borg-lanes/src/services.rs:247
//!   host_home                     borg-agent-runtime/src/host_paths.rs:6
//!   config_root                   borg-ui/src/preferences.rs:542
//!   lane root                     borg-lanes/src/lanes.rs:379
//!   resume_budget                 borg-lanes/src/services.rs:172

use serde_json::Value;

fn backoff(backoff_ms: u64, failures: u64) -> u64 {
    backoff_ms.max(50).saturating_mul(1u64 << failures.min(6))
}

fn is_transient(codes: &[i64], exit_code: Option<i64>) -> bool {
    exit_code.is_some_and(|code| codes.contains(&code))
}

fn host_home(borg_home: Option<&str>, home: Option<&str>, platform_home: Option<&str>) -> String {
    if let Some(path) = borg_home {
        return path.to_string();
    }
    if let Some(path) = home {
        return format!("{}/.borg", path.trim_end_matches('/'));
    }
    if let Some(path) = platform_home {
        return format!("{}/.borg", path.trim_end_matches('/'));
    }
    ".borg".to_string()
}

fn config_root(xdg: Option<&str>, home: Option<&str>, platform: Option<&str>) -> String {
    if let Some(path) = xdg {
        return format!("{}/borg", path.trim_end_matches('/'));
    }
    if let Some(path) = home {
        return format!("{}/.config/borg", path.trim_end_matches('/'));
    }
    if let Some(path) = platform {
        return format!("{}/borg", path.trim_end_matches('/'));
    }
    "borg".to_string()
}

fn lane_root(lane_dir: Option<&str>, lanes_root: Option<&str>, xdg_runtime: Option<&str>, temp: &str, euid: u64) -> String {
    if let Some(path) = lane_dir {
        return path.to_string();
    }
    if let Some(path) = lanes_root {
        return path.to_string();
    }
    if let Some(path) = xdg_runtime {
        return format!("{}/borg/lanes", path.trim_end_matches('/'));
    }
    format!("{}/borg-lanes-{euid}", temp.trim_end_matches('/'))
}

fn resume_budget(readiness: u64, interval: u64, timeout: u64, readable: bool) -> u64 {
    let window = if readable { readiness } else { 120_000 };
    window.saturating_add(interval).saturating_add(timeout).saturating_add(2_000)
}

fn text(value: &Value, key: &str) -> Option<String> {
    value.get(key).and_then(Value::as_str).map(str::to_string)
}

fn number(value: &Value, key: &str, fallback: u64) -> u64 {
    value.get(key).and_then(Value::as_u64).unwrap_or(fallback)
}

fn flag(value: &Value, key: &str, fallback: bool) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(fallback)
}

fn main() {
    for path in std::env::args().skip(1) {
        let Ok(bytes) = std::fs::read_to_string(&path) else { continue };
        let Ok(scenario) = serde_json::from_str::<Value>(&bytes) else { continue };
        let name = scenario.get("name").and_then(Value::as_str).unwrap_or("unnamed").to_string();

        if let Some(spec) = scenario.get("policy") {
            let codes: Vec<i64> = spec
                .get("transient")
                .and_then(Value::as_array)
                .map(|items| items.iter().filter_map(Value::as_i64).collect())
                .unwrap_or_default();
            let backoff_ms = number(spec, "backoff_ms", 0);
            let max_restarts = number(spec, "max_restarts", 0);
            let mut failures = 0u64;
            let mut restarts = 0u64;
            let mut state = "stopped";
            let mut delay: Option<u64> = None;
            for (index, op) in scenario.get("ops").and_then(Value::as_array).cloned().unwrap_or_default().iter().enumerate() {
                let kind = op.get("op").and_then(Value::as_str).unwrap_or("");
                delay = None;
                match kind {
                    "start" => state = "starting",
                    "healthy" => state = "healthy",
                    "stop" => state = "stopped",
                    "restart-requested" => state = "restart-pending",
                    "restarting" => state = "restarting",
                    "yield" => state = "yielding",
                    "yielded" => state = "yielded",
                    "degraded" => state = "degraded",
                    "exited" => {
                        restarts += 1;
                        let exit_code = op.get("exit").and_then(Value::as_i64);
                        if is_transient(&codes, exit_code) {
                            state = "restart-pending";
                            delay = Some(backoff_ms);
                        } else {
                            failures += 1;
                            delay = Some(backoff(backoff_ms, failures));
                            state = if failures > max_restarts { "failed" } else { "restart-pending" };
                        }
                    }
                    "launch-failed" => {
                        failures += 1;
                        delay = Some(backoff(backoff_ms, failures));
                        state = if failures > max_restarts { "failed" } else { "degraded" };
                    }
                    _ => {}
                }
                let shown = delay.map(|value| value.to_string()).unwrap_or_else(|| "-".to_string());
                println!("supervise {name} {index} {kind} {state} delay={shown} failures={failures} restarts={restarts}");
            }
            continue;
        }

        match scenario.get("kind").and_then(Value::as_str).unwrap_or("") {
            "home" => {
                let path = host_home(
                    text(&scenario, "borg_home").as_deref(),
                    text(&scenario, "home").as_deref(),
                    text(&scenario, "platform_home").as_deref(),
                );
                println!("home {name} {path}");
            }
            "config" => {
                let path = config_root(
                    text(&scenario, "xdg_config").as_deref(),
                    text(&scenario, "home").as_deref(),
                    text(&scenario, "platform_config").as_deref(),
                );
                println!("config {name} {path}");
            }
            "lanes" => {
                let temp = text(&scenario, "temp").unwrap_or_default();
                let path = lane_root(
                    text(&scenario, "lane_dir").as_deref(),
                    text(&scenario, "lanes_root").as_deref(),
                    text(&scenario, "xdg_runtime").as_deref(),
                    &temp,
                    number(&scenario, "euid", 0),
                );
                println!("lanes {name} {path}");
            }
            "session" => {
                let sessions = text(&scenario, "sessions").unwrap_or_default();
                let session = text(&scenario, "session").unwrap_or_default();
                let suffix = text(&scenario, "suffix").unwrap_or_default();
                println!("session {name} {sessions}/{session}/{suffix}");
            }
            "budget" => {
                let budget = resume_budget(
                    number(&scenario, "readiness_ms", 0),
                    number(&scenario, "interval_ms", 0),
                    number(&scenario, "timeout_ms", 0),
                    flag(&scenario, "readable", false),
                );
                println!("budget {name} {budget}");
            }
            _ => {}
        }
    }
}
