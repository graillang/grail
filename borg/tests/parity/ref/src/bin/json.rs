//! JSON reference for `borg/tests/json_test.grl`.
//!
//! Prints, for every fixture: the compact re-serialisation and one line per scalar value, in the
//! order Borg's own `serde_json::Value` walks them (objects in `BTreeMap` key order). Number text
//! comes from `serde_json`'s arbitrary-precision `Number`, so the port is compared against the
//! normalisation Borg actually performs, not against a restatement of it.

use serde_json::Value;

fn label(path: &str) -> &str {
    path.rsplit('/').next().unwrap_or(path)
}

fn walk(value: &Value, path: &str, file: &str) {
    match value {
        Value::Null => println!("json.scalar {file} {path} null"),
        Value::Bool(flag) => println!("json.scalar {file} {path} {flag}"),
        Value::Number(number) => println!("json.scalar {file} {path} {number}"),
        Value::String(text) => println!(
            "json.scalar {file} {path} {}",
            serde_json::to_string(text).expect("string serialises")
        ),
        Value::Array(items) => {
            for (index, item) in items.iter().enumerate() {
                walk(item, &format!("{path}[{index}]"), file);
            }
        }
        Value::Object(map) => {
            for (key, item) in map {
                walk(item, &format!("{path}.{key}"), file);
            }
        }
    }
}

fn main() {
    for path in std::env::args().skip(1) {
        let file = label(&path);
        let Ok(text) = std::fs::read_to_string(&path) else {
            println!("json.error {file}");
            continue;
        };
        match serde_json::from_str::<Value>(&text) {
            Ok(value) => {
                println!(
                    "json.compact {file} {}",
                    serde_json::to_string(&value).expect("value serialises")
                );
                walk(&value, "$", file);
            }
            Err(_) => println!("json.error {file}"),
        }
    }
}
