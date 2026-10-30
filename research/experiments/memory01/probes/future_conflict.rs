// Isolated cross-module research probe.
fn main() { let mut data=[0u8;8]; let f=view_api::suspended_fill(&mut data); data[0]=4; drop(f); }
