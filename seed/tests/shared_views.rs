//! Descriptor copies must preserve data/unique-ancestor obligations, not freeze readonly carriers.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn readonly_descriptors_can_be_used_moved_or_ended_while_slices_live() {
    assert!(ok(
        "fn f()->num {b :=buffer(4,7);p :=read(b);s :=slice(p,0,1);n :=len(p);drop(p);return n+at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {b :=buffer(4,7);p :=hold(read(b));s :=read(p);drop(p);return at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {b :=buffer(4,7);p :=read(b);s :=read(p);moved :=p;return len(moved)+at(s,0);}"
    ));
}
#[test]
fn descriptor_ending_does_not_release_the_data_or_exclusive_ancestor() {
    assert!(!ok(
        "fn f()->num {var b =bytes();push(b,7);p :=read(b);s :=read(p);drop(p);drop(b);return at(s,0);}"
    ));
    assert!(!ok(
        "fn f()->num {var b =bytes();push(b,7);w :=mut(b);p :=read(w);s :=read(p);drop(p);write(w,0,9);return at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {var b =bytes();push(b,7);w :=mut(b);p :=read(w);s :=read(p);drop(p);n :=at(s,0);write(w,0,9);return n;}"
    ));
}
