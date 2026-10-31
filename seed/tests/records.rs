//! Actual record programs, not unsupported-syntax rejection controls.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
const DECL: &str = "module tokens;struct Token<a>{span:read<a>,name:string,offset:num}";
#[test]
fn mixed_records_move_fields_without_losing_other_obligations() {
    for body in [
        "pub fn f<a>(p:read<a>)->num{let t=Token{span:read(p),name:\"lex\",offset:3};let name=t.name;let n=len(t.span);let span=t.span;return len(name)+n+len(span)+t.offset;}",
        "pub fn f<a>(p:read<a>)->num{let t=Token{span:read(p),name:\"lex\",offset:3};let q=read(t.span);drop(t);return len(q);}",
        "pub fn f<a>(p:read<a>)->read<a>{let t=Token{span:p,name:\"lex\",offset:3};return t.span;}",
        "pub fn make<a>(p:read<a>)->Token<a>{return Token{span:p,name:\"lex\",offset:3};}",
        "pub fn f()->num{let b=bytes();push(b,7);let t=Token{span:read(b),name:\"lex\",offset:3};let n=len(t.name);drop(b);return n;}",
    ] {
        let s = format!("{DECL}{body}");
        assert!(ok(&s), "{s}");
    }
}
#[test]
fn partial_moves_captured_sources_and_owned_fields_are_checked() {
    for body in [
        "pub fn f<a>(p:read<a>)->num{let t=Token{span:p,name:\"x\",offset:0};let a=t.name;return len(t.name)+len(a);}",
        "pub fn f<a>(p:read<a>)->num{let t=Token{span:p,name:\"x\",offset:0};let a=t.name;let moved=t;return len(a);}",
        "pub fn f()->num{let b=bytes();let t=Token{span:read(b),name:\"x\",offset:0};drop(b);return len(t.span);}",
        "pub fn f<a>(p:read<a>)->read<a>{let b=bytes();let t=Token{span:read(b),name:\"x\",offset:0};return t.span;}",
        "pub fn f<a>(p:read<a>)->read<a>{let t=Token{span:p,name:\"x\",offset:0};return read(t.name);}",
        "pub fn f<a>(p:read<a>)->num{let t=Token{span:p,name:\"x\",offset:0};let q=read(t.name);drop(t);return len(q);}",
    ] {
        let s = format!("{DECL}{body}");
        assert!(!ok(&s), "{s}");
    }
}

#[test]
fn captured_lifetimes_are_not_exclusive_target_identity() {
    let s = "module pairs;struct Pair<a>{left:mut<a>,right:mut<a>}pub fn run<a,b>(x:mut<a>,y:mut<b>)->num{let p=pair(x,y);let l=mut(p.left);let r=mut(p.right);write(l,0,3);write(r,0,4);return 0;}fn pair<a>(x:mut<a>,y:mut<a>)->Pair<a>{return Pair{left:x,right:y};}";
    assert!(ok(s));
    assert!(!ok(
        "module pairs;struct Pair<a>{left:mut<a>,right:mut<a>}pub fn run()->num{let b=bytes();let p=Pair{left:mut(b),right:mut(b)};return 0;}"
    ));
}
#[test]
fn parameter_storage_cannot_masquerade_as_a_captured_source() {
    assert!(!ok(&format!(
        "{DECL}pub fn bad<a>(t:Token<a>)->read<a>{{return read(t.name);}}"
    )));
    assert!(ok(&format!(
        "{DECL}pub fn span<a>(t:Token<a>)->read<a>{{return t.span;}}"
    )));
    assert!(!ok(
        "module nodes;struct A{next:B}struct B{next:A}pub fn run()->num{return 0;}"
    ));
    assert!(!ok(
        "module bad;struct T<a>{x:read<a>}pub fn run(p:T)->num{return 0;}"
    ));
}

#[test]
fn constructor_order_and_layout_expansion_are_bounded() {
    assert!(!ok(
        "module owned;struct R{data:bytes,n:num}pub fn run()->num{let b=bytes();let r=R{data:b,n:len(b)};return r.n;}"
    ));
    assert!(ok(
        "module owned;struct R{data:bytes,n:num}pub fn run()->num{let b=bytes();let n=len(b);let r=R{data:b,n:n};return r.n;}"
    ));
    let mut s = String::from("module expansion;struct Empty{}");
    for i in 0..8 {
        let child = if i == 0 {
            "Empty".into()
        } else {
            format!("R{}", i - 1)
        };
        s.push_str(&format!(
            "struct R{i}{{a:{child},b:{child},c:{child},d:{child}}}"
        ));
    }
    s.push_str("pub fn run()->num{return 0;}");
    assert!(!ok(&s));
}

#[test]
fn record_constructors_do_not_steal_shadowed_condition_names() {
    assert!(ok(
        "module names;struct n{value:num}pub fn run()->num{let n=1;var value=0;if n {value=3;}return value;}"
    ));
}

#[test]
fn nominal_payload_bounds_roundtrip_before_artifact_publication() {
    use grail_seed::{Sig, Ty, module::Interface, types::Definition};
    let sig = Sig {
        name: "wide".into(),
        params: vec![Ty::Named("many::T".into(), vec![65535; 64], vec![]); 64],
        result: Ty::Num,
    };
    let text = sig.encode().unwrap();
    assert!(text.len() > 8192);
    assert_eq!(Sig::decode(&text).unwrap(), sig);
    let mut header = Interface::single(Sig {
        name: "large".into(),
        params: vec![],
        result: Ty::Num,
    });
    let fields = (0..64)
        .map(|i| (format!("field_{i}_{}", "x".repeat(65)), Ty::Num))
        .collect::<Vec<_>>();
    for i in 0..4096 {
        header.layouts.insert(
            format!("large::R{i}"),
            Definition {
                kind: grail_seed::types::Kind::Record,
                regions: 0,
                parameters: 0,
                fields: fields.clone(),
            },
        );
    }
    assert!(header.validate().is_err());
    assert!(header.encode().is_err());
}
