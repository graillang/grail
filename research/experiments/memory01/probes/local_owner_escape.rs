// Isolated cross-module research probe.
fn bad() -> Vec<view_api::Token<'static>> { let source=String::from("alpha beta"); view_api::tokenize(&source) } fn main() {}
