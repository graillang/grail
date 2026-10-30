// Isolated cross-module research probe.
fn main() { let mut a=[0u32;8]; let (l,r)=a.split_at_mut(4); std::thread::scope(|s| { s.spawn(move || l.fill(1)); s.spawn(move || r.fill(2)); }); assert_eq!(a,[1,1,1,1,2,2,2,2]); }
