// Isolated cross-module research probe.
fn main() { let source=String::from("alpha beta"); let tokens=view_api::tokenize(&source); let texts=view_api::map_owned(tokens, |t| t.text); assert_eq!(texts,vec!["alpha","beta"]); let suffixes=view_api::map_views(&source, |s| &s[1..]); assert_eq!(suffixes,vec!["lpha","eta"]); }
