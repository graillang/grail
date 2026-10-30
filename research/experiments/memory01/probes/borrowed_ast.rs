// Isolated cross-module research probe.
fn main() { let source=String::from("alpha beta gamma"); let ast=view_api::tokenize(&source); assert_eq!(ast.len(),3); let start=source.as_ptr() as usize; for t in &ast { let ptr=t.text.as_ptr() as usize; assert!(ptr>=start && ptr+t.text.len()<=start+source.len()); } assert_eq!(ast[1].text,"beta"); }
