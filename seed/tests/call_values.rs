//! User function arguments are materialized left-to-right, not loaded at the final call.
use grail_seed::{Mode, Sig, Ty, source};
use std::collections::BTreeMap;
fn checked(text: &str, first: Ty) -> bool {
    let sig = Sig {
        name: "take".into(),
        params: vec![first, Ty::Num],
        result: Ty::Num,
    };
    source::compile(
        text,
        BTreeMap::from([("take".into(), grail_seed::module::Interface::single(sig))]),
    )
    .is_ok()
}
#[test]
fn earlier_affine_argument_is_moved_before_later_argument() {
    assert!(!checked(
        "use take;fn f()->num {b :=bytes();return take(b,len(b));}",
        Ty::Bytes
    ));
    assert!(!checked(
        "use take;fn f()->num {s :=\"x\";return take(s,len(s));}",
        Ty::Text
    ));
    assert!(!checked(
        "use take;fn f<a>(p:mut<a>)->num {return take(p,len(p));}",
        Ty::View(Mode::Write, 0)
    ));
    assert!(!checked(
        "use take;fn f<a>(p:read<a>)->num {return take(p,len(p));}",
        Ty::View(Mode::Read, 0)
    ));
}
#[test]
fn values_may_be_snapshotted_or_explicitly_reborrowed_before_the_call() {
    assert!(checked(
        "use take;fn f()->num {b :=bytes();n :=len(b);return take(b,n);}",
        Ty::Bytes
    ));
    assert!(checked(
        "use take;fn f()->num {s :=\"x\";n :=len(s);return take(s,n);}",
        Ty::Text
    ));
    assert!(checked(
        "use take;fn f<a>(p:read<a>)->num {return take(read(p),len(p));}",
        Ty::View(Mode::Read, 0)
    ));
    assert!(checked(
        "use take;fn f()->num {var n=2;return take(n,n+1);}",
        Ty::Num
    ));
}
