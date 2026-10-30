// Isolated cross-module research probe.
fn main() { let long=String::from("long"); let kept; { let short=String::from("short"); let pair=view_api::pair(&short,&long); assert_eq!(pair.short,"short"); kept=pair.long; } assert_eq!(kept,"long"); }
