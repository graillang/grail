// Isolated cross-module research probe.
fn main() { let mut data=[1u32,2]; let mut retained=None; view_api::visit(&mut data, |item| { retained=Some(item); }); println!("{:?}",retained); }
