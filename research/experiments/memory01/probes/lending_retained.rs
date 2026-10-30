// Isolated cross-module research probe.
fn main() { let mut decoder=view_api::Reuser::default(); let first=decoder.next_view().unwrap(); let second=decoder.next_view().unwrap(); println!("{first} {second}"); }
