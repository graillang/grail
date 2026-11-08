//! Reference for `borg/tests/permission_test.grl`.
//!
//! The gate rules are copied from Borg with citations; `--anchors` re-checks the snippets:
//!
//!   PermissionMode / ApprovalDecision   contract.rs:374, 2446
//!   enrolled-root check                filesystem.rs:390
//!   relative-path validation           filesystem.rs:404
//!   symlink refusal                    filesystem.rs:424
//!   containment                        filesystem.rs:437  component-wise starts_with

use serde_json::Value;

const MUST_BE_RELATIVE: &str = "path must be relative to the workspace root";
const TRAVERSAL: &str = "path contains unsupported traversal components";
const MUST_IDENTIFY: &str = "path must identify an item under the workspace root";
const NO_SYMLINKS: &str = "workspace file operations do not follow symlinks";
const STAY_UNDER: &str = "path must stay under the workspace root";

fn components(path: &str) -> Vec<&str> {
    path.split('/').filter(|part| !part.is_empty()).collect()
}

fn contains(root: &str, path: &str) -> bool {
    let root_parts = components(root);
    let path_parts = components(path);
    if root_parts.len() > path_parts.len() {
        return false;
    }
    root_parts.iter().zip(path_parts.iter()).all(|(a, b)| a == b)
}

fn validate_relative(path: &str, allow_root: bool) -> Option<&'static str> {
    if path.starts_with('/') {
        return Some(MUST_BE_RELATIVE);
    }
    let mut normal = false;
    for part in components(path) {
        if part == ".." {
            return Some(TRAVERSAL);
        }
        if part != "." {
            normal = true;
        }
    }
    if !allow_root && !normal {
        return Some(MUST_IDENTIFY);
    }
    None
}

fn check_path(root: &str, relative: &str, symlink: bool) -> String {
    if let Some(reason) = validate_relative(relative, true) {
        return reason.to_string();
    }
    if symlink {
        return NO_SYMLINKS.to_string();
    }
    if !contains(root, relative) {
        return STAY_UNDER.to_string();
    }
    "allowed".to_string()
}

fn text(value: &Value, key: &str) -> String {
    value.get(key).and_then(Value::as_str).unwrap_or("").to_string()
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
            "mode" => {
                let given = text(&scenario, "text");
                let shown = match given.as_str() {
                    "full_access" | "full-access" => "full_access",
                    "auto" => "auto",
                    "manual" => "manual",
                    _ => "error",
                };
                println!("mode {name} {shown}");
            }
            "relative" => {
                let result = validate_relative(&text(&scenario, "path"), flag(&scenario, "allow_root"));
                println!("relative {name} {}", result.unwrap_or("ok"));
            }
            "contains" => {
                println!("contains {name} {}", contains(&text(&scenario, "root"), &text(&scenario, "path")));
            }
            "enrolled" => {
                let requested = text(&scenario, "requested");
                let roots: Vec<String> = scenario
                    .get("roots")
                    .and_then(Value::as_array)
                    .map(|items| items.iter().filter_map(Value::as_str).map(str::to_string).collect())
                    .unwrap_or_default();
                let enrolled = roots.iter().any(|root| contains(root, &requested));
                println!("enrolled {name} {enrolled}");
            }
            "check" => {
                println!(
                    "check {name} {}",
                    check_path(&text(&scenario, "root"), &text(&scenario, "relative"), flag(&scenario, "symlink"))
                );
            }
            "grants" => {
                let mut grants: Vec<(String, String, bool)> = Vec::new();
                for step in scenario.get("steps").and_then(Value::as_array).cloned().unwrap_or_default() {
                    let tool = text(&step, "tool");
                    let scope = text(&step, "scope");
                    if step.get("allow").is_some() {
                        if flag(&step, "allow") {
                            grants.push((tool, scope, flag(&step, "session")));
                        }
                        println!("grants {name} recorded");
                    } else {
                        let covered = grants.iter().any(|(t, s, wide)| *wide && *t == tool && *s == scope);
                        println!("grants {name} {}", if covered { "covered" } else { "ask" });
                    }
                }
            }
            _ => {}
        }
    }
}
