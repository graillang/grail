// Rust twin of bench/json.grl: serde_json::Value, the dynamic document type.
use serde_json::Value;
use std::fmt::Write;

#[derive(Default)]
struct Totals {
    ints: u64,
    strings: u64,
    nodes: u64,
}
fn walk(v: &Value, t: &mut Totals) {
    t.nodes += 1;
    match v {
        Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                t.ints = t.ints.wrapping_add(i as u64);
            }
        }
        Value::String(s) => t.strings += s.len() as u64,
        Value::Array(items) => {
            for item in items {
                walk(item, t);
            }
        }
        Value::Object(members) => {
            for (k, item) in members {
                t.strings += k.len() as u64;
                walk(item, t);
            }
        }
        _ => {}
    }
}
fn main() {
    let n: u64 = 92000;
    let mut text = String::from("{\"items\":[");
    for i in 0..n {
        if i > 0 {
            text.push(',');
        }
        text.push_str("{\"id\":");
        write!(text, "{},\"name\":\"item{}\",\"tags\":[\"t{}\",\"u{}\"],\"value\":{},\"nested\":", i, i, i % 7, i % 13, i * 37 % 100003).unwrap();
        text.push_str("{\"a\":");
        write!(text, "{},\"b\":[1,2,3],\"label\":\"n{}\"", i % 100, i % 1000).unwrap();
        text.push_str("}}");
    }
    text.push_str("]}");
    let doc: Value = serde_json::from_str(&text).unwrap();
    let mut t = Totals::default();
    walk(&doc, &mut t);
    let out = serde_json::to_string(&doc).unwrap();
    println!("{} {} {} {} {}", text.len(), t.nodes, t.ints, t.strings, out.len());
}
