//! Reference for `borg/tests/transport_test.grl`.
//!
//! The transport rules are copied from Borg with citations; `--anchors` re-checks the snippets:
//!
//!   descriptor socket addressing   borg-lanes/src/services.rs:485   `/proc/self/fd/<fd>/name` so a
//!                                                                   deep directory never reaches the
//!                                                                   108-byte `sun_path` limit
//!   permissions                    local_control.rs:1157, 1166      0700 directory, 0600 socket
//!   command bound                  local_control.rs:23              1 MiB
//!   reply bound                    local_control.rs:905             4096
//!   peer credentials               computer_use/linux/windows.rs:114  SO_PEERCRED must fill ucred
//!   shutdown                       local_control.rs:1297            no new commands while stopping

use serde_json::Value;

fn socket_address(dir: &str, name: &str, fd: &str) -> (String, u64) {
    let direct = if dir.ends_with('/') { format!("{dir}{name}") } else { format!("{dir}/{name}") };
    let length = direct.len() as u64;
    if length <= 107 {
        (direct, length)
    } else {
        (format!("/proc/self/fd/{fd}/{name}"), length)
    }
}

fn text(value: &Value, key: &str) -> String {
    value.get(key).and_then(Value::as_str).unwrap_or("").to_string()
}

fn number(value: &Value, key: &str, fallback: u64) -> u64 {
    value.get(key).and_then(Value::as_u64).unwrap_or(fallback)
}

fn main() {
    for path in std::env::args().skip(1) {
        let Ok(bytes) = std::fs::read_to_string(&path) else { continue };
        let Ok(scenario) = serde_json::from_str::<Value>(&bytes) else { continue };
        let name = scenario.get("name").and_then(Value::as_str).unwrap_or("unnamed").to_string();
        match scenario.get("kind").and_then(Value::as_str).unwrap_or("") {
            "address" => {
                let mut fd = "7".to_string();
                if scenario.get("fd").and_then(Value::as_str).is_some() {
                    fd = text(&scenario, "fd");
                }
                let (address, length) = socket_address(&text(&scenario, "dir"), &text(&scenario, "socket"), &fd);
                println!("address {name} {address}");
                println!("fits {name} {}", length <= 107);
            }
            "limits" => {
                // 0700 and 0600 are printed as the decimal values the port reports.
                println!("limits {name} 448 384 1048576 4096 12 108");
            }
            "peer" => {
                let size = number(&scenario, "size", 0);
                println!("ucred {name} {}", size == 12);
                let verdict = if number(&scenario, "uid", 0) == number(&scenario, "server", 0) {
                    "same-user"
                } else {
                    "other-user"
                };
                println!("peer {name} {verdict}");
            }
            "conn" => {
                let mut state = "idle";
                let mut replies = 0u64;
                let mut streaming = false;
                for (index, op) in scenario.get("ops").and_then(Value::as_array).cloned().unwrap_or_default().iter().enumerate() {
                    let kind = op.get("op").and_then(Value::as_str).unwrap_or("");
                    let mut result = "ok".to_string();
                    match kind {
                        "accept" => state = "reading",
                        "command" => {
                            if state == "closed" {
                                result = "closed".to_string();
                            } else if state != "reading" {
                                result = "unexpected".to_string();
                            } else if number(&op, "bytes", 0) > 1_048_576 {
                                state = "closed";
                                result = "too-large".to_string();
                            } else {
                                replies += 1;
                                if streaming {
                                    state = "streaming";
                                    result = "streaming".to_string();
                                } else {
                                    state = "replied";
                                    result = "replied".to_string();
                                }
                            }
                        }
                        "stream" => {
                            if state == "replied" || state == "reading" {
                                streaming = true;
                                state = "streaming";
                                result = "streaming".to_string();
                            } else {
                                result = "unexpected".to_string();
                            }
                        }
                        "eof" => state = "closed",
                        "shutdown" => {
                            if state == "closed" {
                                result = "closed".to_string();
                            } else if state == "reading" {
                                state = "closed";
                                result = "closed".to_string();
                            } else {
                                result = "draining".to_string();
                            }
                        }
                        _ => {}
                    }
                    println!("conn {name} {index} {kind} {state} {result} replies={replies}");
                }
            }
            _ => {}
        }
    }
}
