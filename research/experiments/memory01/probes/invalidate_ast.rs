// Isolated cross-module research probe.
fn main() { let mut source=String::from("alpha beta"); let ast=view_api::tokenize(&source); source.clear(); println!("{}",ast[0].text); }
