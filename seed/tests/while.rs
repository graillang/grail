//! Loop-condition scopes and back edges must preserve ownership, not merely type-check syntax.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn while_rechecks_numbers_and_closes_condition_temporaries() {
    assert!(ok(
        "fn f()->num {var b =bytes();push(b,7);var i=0;while i<len(read(b)) {push(b,8);i=i+2;}return len(b);}"
    ));

    assert!(ok(
        "fn f<a>(input:read<a>)->num {var i=0;var sum=0;while i<len(input) {sum=sum+at(input,i);i=i+1;}return sum;}"
    ));
    assert!(ok(
        "fn f()->num {var b =bytes();push(b,7);var i=0;while i<len(copy_bytes(b)) {i=i+1;}return i;}"
    ));
    assert!(ok(
        "fn f()->num {var i=0;while i<2 {s :=\"x\";assert(len(s)==1);i=i+1;}return i;}"
    ));
}
#[test]
fn while_rejects_consumed_entry_owners_and_non_numeric_conditions() {
    assert!(!ok(
        "fn f()->num {var b =bytes();push(b,7);p :=read(b);var i=0;while i<len(p) {push(b,8);i=i+1;}return len(b);}"
    ));

    assert!(!ok(
        "fn f()->num {b :=bytes();var i=0;while i<2 {drop(b);i=i+1;}return i;}"
    ));
    assert!(!ok("fn f()->num {b :=bytes();while b {}return 0;}"));
    assert!(!ok(
        "fn f()->num {var i=0;while i<2 {b :=bytes();p :=read(b);drop(b);assert(len(p)==0);i=i+1;}return i;}"
    ));
}
