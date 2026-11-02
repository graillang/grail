//! Source safety contracts: host Rust checks cannot guard the new compiler's loan ending.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn last_use_ends_loans_before_owner_drop() {
    assert!(ok(
        "fn f()->num { b :=buffer(8,7); v :=read(b); n :=len(v); drop(b); return n; }"
    ));
    assert!(!ok(
        "fn f()->num { b :=buffer(8,7); v :=read(b); drop(b); return len(v); }"
    ));
    assert!(!ok(
        "fn f()->num { b :=buffer(8,7); drop(b); return len(read(b)); }"
    ));
}
#[test]
fn slice_keeps_origin_and_parent_until_its_last_use() {
    assert!(ok(
        "fn f()->num { var b =buffer(8,7); p :=mut(b); s :=slice(p,0,3); n :=len(s); m :=len(p); drop(p); drop(b); return n+m; }"
    ));
    assert!(!ok(
        "fn f()->num { var b =buffer(8,7); p :=mut(b); s :=slice(p,0,3); n :=len(p); return n+len(s); }"
    ));
    assert!(!ok(
        "fn f<a>(p:read<a>)->read<a> { b :=buffer(8,7); return read(b); }"
    ));
    assert!(ok("fn f<a>(p:read<a>)->read<a> { return slice(p,0,0); }"));
    assert!(!ok("fn f<a,b>(p:read<a>,q:read<b>)->read<a> { return q; }"));
}
#[test]
fn imported_signature_suffices_and_wrong_modes_fail() {
    let provider =
        source::compile(include_str!("../examples/number.grl"), BTreeMap::new()).unwrap();
    let sig = grail_seed::module::Interface::decode(&provider.interface()).unwrap();
    assert!(
        source::compile(
            include_str!("../examples/sum.grl"),
            BTreeMap::from([(sig.name.clone(), sig.clone())])
        )
        .is_ok()
    );
    let mut changed = sig;
    changed.exports.get_mut("number::number").unwrap().params[0] =
        grail_seed::Ty::View(grail_seed::Mode::Write, 0);
    assert!(
        source::compile(
            include_str!("../examples/sum.grl"),
            BTreeMap::from([(changed.name.clone(), changed)])
        )
        .is_err()
    );
}
#[test]
fn invalid_source_fails_without_panicking() {
    for s in [
        "",
        "fn f(}",
        "fn f()->num { return 18446744073709551616; }",
        "fn f<a>(x:read<b>)->num {return 0;}",
        "fn f()->num {x :=1; x=2; return x;}",
        "fn f()->num {return 0;} trailing",
        "fn f()->num {return ☃;}",
        "use x; use x; fn f()->num {return 0;}",
    ] {
        assert!(!ok(s), "{s}");
    }
}

#[test]
fn exclusive_byte_writes_respect_live_read_slices() {
    assert!(ok(
        "fn f()->num {var b =buffer(8,7);p :=mut(b);write(p,0,9);return at(p,0);}"
    ));
    assert!(!ok(
        "fn f()->num {b :=buffer(8,7);var p =read(b);write(p,0,9);return 0;}"
    ));
    assert!(!ok(
        "fn f()->num {var b =buffer(8,7);p :=mut(b);s :=slice(p,0,1);write(p,0,9);return at(s,0);}"
    ));
    assert!(ok(
        "fn f()->num {var b =buffer(8,7);p :=mut(b);s :=slice(p,0,1);n :=at(s,0);write(p,0,9);return n;}"
    ));
}

#[test]
fn expression_statements_close_temporaries_without_dummy_bindings() {
    for text in [
        "fn f()->num{helper();return 7;}fn helper()->unit{return ();}",
        "fn f()->num{var b =bytes();push(b,7);read(b);push(b,8);copy_bytes(b);return len(b);}",
        "fn f()->num{();7+8;return 0;}",
    ] {
        assert!(
            grail_seed::source::compile(text, std::collections::BTreeMap::new()).is_ok(),
            "{text}"
        );
    }
}

#[test]
fn nested_loop_blocks_keep_borrowed_entry_values_live_for_the_backedge() {
    for text in [
        "fn f<a>(p:read<a>)->num{var sum=0;for i in len(p){{n :=at(p,i);sum=sum+n;}}return sum;}",
        "fn f<a>(p:read<a>)->num{var i=0;var sum=0;while i<len(p){{n :=at(p,i);sum=sum+n;i=i+1;}}return sum;}",
    ] {
        assert!(
            grail_seed::source::compile(text, Default::default()).is_ok(),
            "{text}"
        );
    }
}
