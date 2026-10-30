// Isolated cross-module research probe.
fn main() { let mut a=[1,2,3,4]; let (l,r)=a.split_at_mut(2); view_api::visit(l, |v| *v+=10); view_api::visit(r, |v| *v+=20); assert_eq!(a,[11,12,23,24]); }
