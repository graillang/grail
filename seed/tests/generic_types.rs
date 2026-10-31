use grail_seed::{emit, module::Interface, source};
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn generic_layouts_substitute_nested_owned_and_captured_payloads() {
    for s in [
        "module f;enum R<type T,type E>{Ok(T),Err(E)}pub fn run()->R<num,string>{return R::Ok(3);}",
        "module f;struct Pair<type T,type U>{first:T,second:U}pub fn run()->num{let p=Pair<num,string>{first:3,second:\"name\"};let q=Pair<string,num>{first:\"q\",second:4};return p.first+len(p.second)+len(q.first)+q.second;}",
        "module f;struct Token<a>{span:read<a>,name:string}enum R<type T,type E>{Ok(T),Err(E)}pub fn parse<a>(p:read<a>)->R<Token<a>,string>{return R::Ok(Token{span:p,name:\"n\"});}",
        "module f;enum R<type T,type E>{Ok(T),Err(E)}pub fn change(r:R<num,string>)->R<string,string>{let n=r?;return R::Ok(\"n\");}",
        "module f;struct Phantom<type T>{n:num}struct A{p:Phantom<A>}pub fn run()->num{let p=Phantom<A>{n:7};let a=A{p:p};return a.p.n;}",
        "module f;struct Wrap<type T>{v:T}enum O<type T>{None,Some(T)}pub fn run()->num{let x=O<Wrap<string>>::Some(Wrap<string>{v:\"abc\"});let w=x!;return len(w.v);}",
    ] {
        let p = source::compile(s, BTreeMap::new()).unwrap_or_else(|e| panic!("{s}\n{e}"));
        emit::module_c(&p);
        let wire = p.interface();
        assert_eq!(wire, Interface::decode(&wire).unwrap().encode().unwrap());
    }
}
#[test]
fn generic_parameters_do_not_erase_shapes_modes_or_return_origins() {
    for s in [
        "module f;struct R<type T>{v:T}pub fn run()->num{let r=R<num>{v:\"bad\"};return 0;}",
        "module f;struct R<type T>{v:T}pub fn run(r:R<num,string>)->num{return 0;}",
        "module f;struct R<type T>{v:T}pub fn run(r:R)->num{return 0;}",
        "module f;struct R<type T>{v:U}pub fn run()->num{return 0;}",
        "module f;struct R<type T>{v:T}pub fn bad<a>(p:read<a>)->R<read<a>>{let b=bytes();return R<read<a>>{v:read(b)};}",
        "module f;struct R<type T>{v:T}pub fn bad<a>(p:read<a>)->R<mut<a>>{return R<mut<a>>{v:p};}",
        "module f;struct Wrap<type T>{v:T}struct R<type T>{next:R<Wrap<T>>}pub fn run()->num{return 0;}",
        "module f;struct Wrap<type T>{v:T}struct R{next:Wrap<R>}pub fn run()->num{return 0;}",
    ] {
        assert!(!ok(s), "{s}");
    }
}

#[test]
fn public_type_only_surfaces_are_closed_and_independently_decodable() {
    let p=source::compile("module types;struct Hidden{n:num}pub struct Box<type T>{value:T}pub enum Result<type T,type E>{Ok(T),Err(E)}pub enum Option<type T>{Some(T),None}pub struct Public{inner:Hidden}",BTreeMap::new()).unwrap();
    assert!(p.header().entry.is_none());
    assert!(p.entry_signature().is_none());
    assert!(p.header().exports.is_empty());
    assert!(p.header().layouts.contains_key("types::Hidden"));
    let interface = Interface::decode(&p.interface()).unwrap();
    let c=source::compile("module client;use types;pub fn run()->num{let r=types::Result<types::Box<num>,string>::Ok(types::Box<num>{value:7});let b=r!;return b.value;}",BTreeMap::from([("types".into(),interface.clone())])).unwrap();
    assert!(emit::module_c(&c).contains("t_g_"));
    assert!(
        source::compile(
            "use types;fn client()->num{return types();}",
            BTreeMap::from([("types".into(), interface.clone())])
        )
        .is_err()
    );
    let mut wrong = interface.clone();
    wrong.entry = Some("types::fake".into());
    assert!(wrong.encode().is_err());
    let hash = interface.fingerprint().unwrap();
    let mut changed = interface;
    changed
        .layouts
        .get_mut("types::Result")
        .unwrap()
        .fields
        .swap(0, 1);
    assert_ne!(hash, changed.fingerprint().unwrap());
}

#[test]
fn generic_codec_bounds_producers_and_rejects_noncanonical_consumers() {
    use grail_seed::{Sig, Ty};
    let atom = Ty::Named(
        format!("{}::{}", "a".repeat(80), "b".repeat(80)),
        vec![],
        vec![],
    );
    let wide = Ty::Named("f::W".into(), vec![], vec![atom.clone(); 64]);
    let sig = Sig {
        name: "f".into(),
        params: vec![wide.clone(); 64],
        result: Ty::Num,
    };
    assert!(sig.encode().is_err());
    let huge = Ty::Named("f::W".into(), vec![], vec![wide; 63]);
    let sig = Sig {
        name: "f".into(),
        params: vec![huge],
        result: Ty::Num,
    };
    assert!(sig.encode().is_err());
    let sig = Sig {
        name: "f".into(),
        params: vec![Ty::Named("f::R".into(), vec![], vec![Ty::Num, Ty::Text])],
        result: Ty::Num,
    };
    let text = sig.encode().unwrap();
    assert_eq!(Sig::decode(&text).unwrap(), sig);
    for bad in [
        text.replace("1#n", "01#n"),
        text.replace("1#n", "2#n"),
        text.replace("1#n", "0#n"),
        text.replace("interface-6", "interface-5"),
        text.replace("[1#n1#s]", "[]"),
        text.replace("1#n", "1#p"),
        text.replace("1#n", "9999999999999999999999999999999999999999999999#n"),
    ] {
        assert!(Sig::decode(&bad).is_err(), "{bad}");
    }
}

#[test]
fn substituting_a_type_argument_preserves_its_own_lifetime_scope() {
    let good = "module f;struct Mixed<a,type T>{own:read<a>,other:T}pub fn mix<a,b>(p:read<a>,q:read<b>)->Mixed<a,read<b>>{return Mixed<a,read<b>>{own:p,other:q};}";
    assert!(ok(good));
    assert!(!ok(&good.replace("other:q", "other:p")));
    // A phantom argument must still resolve even though it has no physical fields.
    assert!(!ok(
        "module f;struct Phantom<type T>{n:num}pub fn run(p:Phantom<Missing>)->num{return 0;}"
    ));
    // Every reachable native layout is ordered, including the maximum empty-leaf chain.
    let mut s = "module f;struct Empty{}".to_string();
    for i in 0..64 {
        s.push_str(&format!(
            "struct R{i}{{v:{}}}",
            if i == 0 {
                "Empty".into()
            } else {
                format!("R{}", i - 1)
            }
        ));
    }
    s.push_str("pub fn run(r:R63)->num{return 0;}");
    let p = source::compile(&s, BTreeMap::new()).unwrap();
    emit::module_c(&p);
}
