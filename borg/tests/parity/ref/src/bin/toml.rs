//! Reference for `borg/tests/toml_test.grl`.
//!
//! Parses with the `toml` crate (1.1.4, the version Borg builds with) and walks `toml::Value` in the
//! same order and path notation the port prints, so a divergence in either the parser or the model
//! is a line difference. Formatting is not compared: what a document means is the contract.

use toml::Value;

fn label(path: &str) -> String {
    path.rsplit('/').next().unwrap_or(path).to_string()
}

fn walk(value: &Value, path: &str, name: &str) {
    match value {
        Value::String(text) => println!("toml.value {name} {path} str {text}"),
        Value::Integer(number) => println!("toml.value {name} {path} int {number}"),
        Value::Boolean(flag) => println!("toml.value {name} {path} bool {flag}"),
        Value::Float(_) => println!("toml.value {name} {path} float"),
        Value::Datetime(_) => println!("toml.value {name} {path} datetime"),
        Value::Array(items) => {
            println!("toml.value {name} {path} array {}", items.len());
            for (index, item) in items.iter().enumerate() {
                walk(item, &format!("{path}[{index}]"), name);
            }
        }
        Value::Table(entries) => {
            println!("toml.value {name} {path} table {}", entries.len());
            for (key, item) in entries {
                walk(item, &format!("{path}.{key}"), name);
            }
        }
    }
}

fn main() {
    for path in std::env::args().skip(1) {
        let name = label(&path);
        let Ok(text) = std::fs::read_to_string(&path) else {
            println!("toml.error {name}");
            continue;
        };
        match toml::from_str::<Value>(&text) {
            Ok(value) => walk(&value, "$", &name),
            Err(_) => println!("toml.error {name}"),
        }
    }
}
