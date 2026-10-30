// Isolated cross-module research probe.
fn main() { let page=view_api::Page::new(vec![1,2,3]); let guard=page.pin(); assert_eq!(guard.row(),&[1,2,3]); }
