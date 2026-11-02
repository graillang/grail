//! Public surfaces, names and region contracts remain independent of provider bodies.
use grail_seed::{Mode, Ty, emit, module::Interface, source};
use std::collections::BTreeMap;
#[test]
fn multiple_exports_are_canonical_and_private_names_do_not_escape() {
    let p=source::compile("fn api()->num{return helper();}pub fn add(n:num)->num{return n+1;}fn helper()->num{return 2;}",BTreeMap::new()).unwrap();
    let h = Interface::decode(&p.interface()).unwrap();
    let mut other = h.clone();
    other.entry = Some("api::add".into());
    assert_ne!(other.fingerprint().unwrap(), h.fingerprint().unwrap());
    assert_eq!(h.exports.len(), 2);
    assert!(h.exports.contains_key("api::add"));
    assert!(!h.exports.contains_key("helper"));
    assert!(
        source::compile(
            "use api;fn client()->num{return api::add(api());}",
            BTreeMap::from([("api".into(), h.clone())])
        )
        .is_ok()
    );
    assert!(
        source::compile(
            "use api;fn client()->num{return api::helper();}",
            BTreeMap::from([("api".into(), h)])
        )
        .is_err()
    );
    assert_ne!(emit::symbol("api::add"), emit::symbol("q_3_api_3_add"));
    assert_ne!(emit::symbol("a_b::c"), emit::symbol("a::b_c"));
}
#[test]
fn qualified_exports_preserve_modes_and_written_return_regions() {
    let p = source::compile(
        "fn api()->num{return 0;}pub fn first<a>(p:read<a>)->read<a>{return slice(p,0,1);}",
        BTreeMap::new(),
    )
    .unwrap();
    let h = Interface::decode(&p.interface()).unwrap();
    assert!(source::compile("use api;fn f()->num{let b=bytes();push(b,7);let p=api::first(read(b));return at(p,0);}",BTreeMap::from([("api".into(),h.clone())])).is_ok());
    assert!(source::compile("use api;fn f()->num{let b=bytes();push(b,7);let p=api::first(read(b));drop(b);return at(p,0);}",BTreeMap::from([("api".into(),h.clone())])).is_err());
    let mut changed = h;
    changed.exports.get_mut("api::first").unwrap().params[0] = Ty::View(Mode::Write, 0);
    assert!(
        source::compile(
            "use api;fn f<a>(p:read<a>)->num{return len(api::first(p));}",
            BTreeMap::from([("api".into(), changed)])
        )
        .is_err()
    );
}
#[test]
fn fingerprints_cover_public_contracts_not_dependency_rebuilds() {
    let p = source::compile("fn api()->num{return 1;}", BTreeMap::new()).unwrap();
    let mut h = p.header().clone();
    let hash = h.fingerprint().unwrap();
    h.dependencies.insert("dep".into(), "0".repeat(64));
    assert_eq!(h.fingerprint().unwrap(), hash);
    h.dependencies.insert("dep".into(), "1".repeat(64));
    assert_eq!(h.fingerprint().unwrap(), hash);
    h.exports.get_mut("api::api").unwrap().params.push(Ty::Num);
    assert_ne!(h.fingerprint().unwrap(), hash);
    assert!(Interface::decode(&h.encode().unwrap()).is_ok());
    let canonical = h.encode().unwrap();
    for text in [
        canonical.trim_end().to_string(),
        canonical.replace("grail-seed-module-6", "grail-seed-module-1"),
        canonical + "extra\n",
    ] {
        assert!(Interface::decode(&text).is_err());
    }
}

#[test]
fn explicit_library_modules_need_no_dummy_primary_function() {
    let p=source::compile("module arithmetic;fn hidden(n:num)->num{return n+1;}pub fn add(n:num)->num{return hidden(n);}",BTreeMap::new()).unwrap();
    assert_eq!(p.header().name, "arithmetic");
    assert_eq!(p.header().entry.as_deref(), Some("arithmetic::add"));
    assert_eq!(p.header().exports.len(), 1);
    assert!(
        source::compile(
            "use arithmetic;fn caller()->num{return arithmetic::add(7);}",
            BTreeMap::from([("arithmetic".into(), p.header().clone())])
        )
        .is_ok()
    );
    assert!(source::compile("module empty;fn hidden()->num{return 0;}", BTreeMap::new()).is_err());
    assert!(source::compile("module empty;", BTreeMap::new()).is_err());
}

#[test]
fn generic_contracts_are_public_but_implementation_pins_are_separate() {
    let mut h = Interface::single(grail_seed::Sig {
        name: "api".into(),
        params: vec![],
        result: Ty::Num,
    });
    let g = grail_seed::template::Signature {
        parameters: 1,
        function: grail_seed::Sig {
            name: "api::id".into(),
            params: vec![Ty::Param(0)],
            result: Ty::Param(0),
        },
    };
    h.generics.insert(g.function.name.clone(), g);
    h.template_hash = Some("0".repeat(64));
    h.dependencies.insert("other".into(), "1".repeat(64));
    h.implementations.insert("other".into(), "2".repeat(64));
    let hash = h.fingerprint().unwrap();
    let wire = h.encode().unwrap();
    assert_eq!(Interface::decode(&wire).unwrap(), h);
    h.template_hash = Some("3".repeat(64));
    h.implementations.insert("other".into(), "4".repeat(64));
    assert_eq!(h.fingerprint().unwrap(), hash);
    h.generics.get_mut("api::id").unwrap().function.result = Ty::Num;
    assert_ne!(h.fingerprint().unwrap(), hash);
}
