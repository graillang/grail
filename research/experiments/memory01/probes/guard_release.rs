// Isolated cross-module research probe.
fn main() { let page=view_api::Page::new(vec![1,2,3]); let guard=page.pin(); let row=guard.row(); drop(guard); println!("{:?}",row); }
