// Isolated cross-module research probe.
fn main() { let source=String::from("alpha"); let f=view_api::selector(&source); assert_eq!(f(1),"lpha"); }
