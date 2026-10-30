// Isolated cross-module research probe.
fn main() { let mut data=[0u8;8]; let f=view_api::suspended_fill(&mut data); drop(f); data[0]=4; assert_eq!(data[0],4); }
