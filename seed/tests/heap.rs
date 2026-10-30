//! Heap owners introduce real use-after-free/reallocation risks; type/lint checks cannot test these contracts.
use grail_seed::{Sig, Ty, source};
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn growth_requires_all_views_to_end_but_last_use_is_sufficient() {
    assert!(ok(
        "fn f()->num {let b=bytes();push(b,7);let v=read(b);let n=at(v,0);push(b,8);return n+len(b);}"
    ));
    assert!(!ok(
        "fn f()->num {let b=bytes();push(b,7);let v=read(b);push(b,8);return at(v,0);}"
    ));
    assert!(!ok(
        "fn f()->num {let b=bytes();let v=read(b);drop(b);return len(v);}"
    ));
    assert!(!ok(
        "fn f()->num {let b=bytes();let v=mut(b);let n=len(b);return n+len(v);}"
    ));
}
#[test]
fn moving_or_returning_an_owner_cannot_leave_dangling_views() {
    assert!(ok("fn f(b:bytes)->bytes {return b;}"));
    assert!(!ok("fn f<a>(b:bytes,p:read<a>)->read<a> {return read(b);}"));
    assert!(!ok(
        "fn f()->num {let b=bytes();let c=b;return len(b)+len(c);}"
    ));
    let take = Sig {
        name: "take".into(),
        params: vec![Ty::Bytes],
        result: Ty::Bytes,
    };
    assert!(
        source::compile(
            "use take; fn f()->num {let b=bytes();push(b,7);let c=take(b);return len(c);}",
            BTreeMap::from([("take".into(), take.clone())])
        )
        .is_ok()
    );
    assert!(source::compile("use take; fn f()->num {let b=bytes();push(b,7);let v=read(b);let c=take(b);return len(c)+at(v,0);}",BTreeMap::from([("take".into(),take)])).is_err());
}
#[test]
fn lexical_heap_cleanup_composes_with_loops_and_branches() {
    assert!(ok(
        "fn f()->num {for i in 4 {let b=bytes();push(b,i);} if 1 {let b=bytes();push(b,9);}return 0;}"
    ));
    assert!(ok(
        "fn f()->num {let b=bytes();if 1 {push(b,9);}for i in 4 {push(b,i);}return len(b);}"
    ));
    assert!(ok(
        "fn f()->num {let b=bytes();let v=read(b);let c=copy_bytes(v);push(c,1);return len(c);}"
    ));
    let checked = source::compile(
        "fn f()->num {let b=bytes();return len(b);}",
        BTreeMap::new(),
    )
    .unwrap();
    assert!(
        grail_seed::emit::llvm(&checked).is_err(),
        "unsupported heap layout must never be silently emitted as a view"
    );
}
#[test]
fn owned_interface_roundtrips_and_old_schema_is_rejected() {
    let sig = Sig {
        name: "take".into(),
        params: vec![Ty::Bytes],
        result: Ty::Bytes,
    };
    let encoded = sig.encode().unwrap();
    assert_eq!(Sig::decode(&encoded).unwrap(), sig);
    assert!(Sig::decode(&encoded.replace("interface-3", "interface-2")).is_err());
}
