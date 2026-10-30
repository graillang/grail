//! Descriptor copies must preserve data/unique-ancestor obligations, not freeze readonly carriers.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn readonly_descriptors_can_be_used_moved_or_ended_while_slices_live() {
    assert!(ok(
        "fn f()->num {let b=buffer(4,7);let p=read(b);let s=slice(p,0,1);let n=len(p);drop(p);return n+at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {let b=buffer(4,7);let p=hold(read(b));let s=read(p);drop(p);return at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {let b=buffer(4,7);let p=read(b);let s=read(p);let moved=p;return len(moved)+at(s,0);}"
    ));
}
#[test]
fn descriptor_ending_does_not_release_the_data_or_exclusive_ancestor() {
    assert!(!ok(
        "fn f()->num {let b=bytes();push(b,7);let p=read(b);let s=read(p);drop(p);drop(b);return at(s,0);}"
    ));
    assert!(!ok(
        "fn f()->num {let b=bytes();push(b,7);let w=mut(b);let p=read(w);let s=read(p);drop(p);write(w,0,9);return at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {let b=bytes();push(b,7);let w=mut(b);let p=read(w);let s=read(p);drop(p);let n=at(s,0);write(w,0,9);return n;}"
    ));
}
