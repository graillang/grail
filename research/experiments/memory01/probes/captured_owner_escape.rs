// Isolated cross-module research probe.
fn main() { let f; { let source=String::from("alpha"); f=view_api::selector(&source); } println!("{}",f(0)); }
