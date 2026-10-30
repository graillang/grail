// Isolated cross-module research probe.
fn main() { let mut decoder=view_api::Reuser::default(); assert_eq!(decoder.next_view(),Some("alpha")); assert_eq!(decoder.next_view(),Some("beta")); }
