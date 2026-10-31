use grail_seed::{
    Function, Op, Sig, Ty, check, template,
    types::{Context, Definition, Kind},
};
use std::collections::BTreeMap;
fn function(params: Vec<Ty>, result: Ty, ops: Vec<Op>) -> Function {
    Function {
        sig: Sig {
            name: "f".into(),
            params,
            result,
        },
        ops,
        result: None,
    }
}
fn checked(f: Function, layouts: Context) -> bool {
    template::check(f, 1, BTreeMap::new(), layouts).is_ok()
}
#[test]
fn opaque_type_parameters_check_once_as_affine_values() {
    let id = function(vec![Ty::Param(0)], Ty::Param(0), vec![Op::Return(0)]);
    assert!(check(id.clone(), BTreeMap::new()).is_err());
    let t = template::check(id, 1, BTreeMap::new(), Context::default()).unwrap();
    let contract = t.signature();
    assert_eq!(
        template::Signature::decode(&contract.encode().unwrap()).unwrap(),
        contract
    );
    assert!(contract.function.encode().is_err());
    assert!(!checked(
        function(
            vec![Ty::Param(0)],
            Ty::Num,
            vec![Op::Num(1, 0), Op::Return(1)]
        ),
        Context::default()
    ));
    assert!(checked(
        function(
            vec![Ty::Param(0)],
            Ty::Num,
            vec![Op::End(0), Op::Num(1, 0), Op::Return(1)]
        ),
        Context::default()
    ));
    assert!(!checked(
        function(
            vec![Ty::Param(0)],
            Ty::Param(0),
            vec![
                Op::Move { dst: 1, src: 0 },
                Op::Move { dst: 2, src: 0 },
                Op::Return(2)
            ]
        ),
        Context::default()
    ));
    assert!(!checked(
        function(vec![], Ty::Param(0), vec![Op::Num(0, 7), Op::Return(0)]),
        Context::default()
    ));
    assert!(!checked(
        function(vec![Ty::Param(1)], Ty::Param(1), vec![Op::Return(0)]),
        Context::default()
    ));
}
#[test]
fn symbolic_nominal_operations_preserve_opaque_ownership() {
    let layouts = Context::new(BTreeMap::from([
        (
            "f::Option".into(),
            Definition {
                kind: Kind::Enum,
                regions: 0,
                parameters: 1,
                fields: vec![("None".into(), Ty::Unit), ("Some".into(), Ty::Param(0))],
            },
        ),
        (
            "f::Pair".into(),
            Definition {
                kind: Kind::Record,
                regions: 0,
                parameters: 1,
                fields: vec![("a".into(), Ty::Param(0)), ("b".into(), Ty::Param(0))],
            },
        ),
    ]))
    .unwrap();
    let option = Ty::Named("f::Option".into(), vec![], vec![Ty::Param(0)]);
    assert!(checked(
        function(
            vec![Ty::Param(0)],
            option.clone(),
            vec![
                Op::Variant {
                    dst: 1,
                    ty: option.clone(),
                    variant: 1,
                    payload: Some(0)
                },
                Op::Return(1)
            ]
        ),
        layouts.clone()
    ));
    assert!(checked(
        function(
            vec![option],
            Ty::Param(0),
            vec![Op::Unwrap { dst: 1, src: 0 }, Op::Return(1)]
        ),
        layouts.clone()
    ));
    let pair = Ty::Named("f::Pair".into(), vec![], vec![Ty::Param(0)]);
    assert!(!checked(
        function(
            vec![Ty::Param(0)],
            pair.clone(),
            vec![
                Op::Record {
                    dst: 1,
                    ty: pair,
                    fields: vec![("a".into(), 0), ("b".into(), 0)]
                },
                Op::Return(1)
            ]
        ),
        layouts
    ));
}

#[test]
fn generic_calls_use_contracts_and_cannot_assume_a_specific_instantiation() {
    let contract = template::Signature {
        parameters: 1,
        function: Sig {
            name: "id".into(),
            params: vec![Ty::Param(0)],
            result: Ty::Param(0),
        },
    };
    let run = |ops| {
        template::check_with_generics(
            function(vec![Ty::Param(0)], Ty::Param(0), ops),
            1,
            BTreeMap::new(),
            Context::default(),
            BTreeMap::from([("id".into(), contract.clone())]),
        )
        .is_ok()
    };
    assert!(run(vec![
        Op::GenericCall {
            dst: 1,
            name: "id".into(),
            type_args: None,
            args: vec![0]
        },
        Op::Return(1)
    ]));
    assert!(run(vec![
        Op::GenericCall {
            dst: 1,
            name: "id".into(),
            type_args: Some(vec![Ty::Param(0)]),
            args: vec![0]
        },
        Op::Return(1)
    ]));
    assert!(!run(vec![
        Op::GenericCall {
            dst: 1,
            name: "id".into(),
            type_args: Some(vec![Ty::Num]),
            args: vec![0]
        },
        Op::Return(1)
    ]));
    assert!(!run(vec![
        Op::GenericCall {
            dst: 1,
            name: "id".into(),
            type_args: Some(vec![Ty::Param(1)]),
            args: vec![0]
        },
        Op::Return(1)
    ]));
    assert!(!run(vec![
        Op::GenericCall {
            dst: 1,
            name: "id".into(),
            type_args: None,
            args: vec![0]
        },
        Op::Return(0)
    ]));
}

#[test]
fn canonical_template_ir_is_rechecked_without_instantiating_the_type() {
    let t = template::check(
        function(vec![Ty::Param(0)], Ty::Param(0), vec![Op::Return(0)]),
        1,
        BTreeMap::new(),
        Context::default(),
    )
    .unwrap();
    let bytes = t.encode_ir().unwrap();
    let recovered = template::CheckedTemplate::decode_ir(&bytes, Context::default()).unwrap();
    assert_eq!(recovered.signature(), t.signature());
    assert_eq!(recovered.encode_ir().unwrap(), bytes);
    for end in 0..bytes.len() {
        assert!(template::CheckedTemplate::decode_ir(&bytes[..end], Context::default()).is_err());
    }
    let mut noncanonical = vec![b'0'];
    noncanonical.extend(&bytes);
    assert!(template::CheckedTemplate::decode_ir(&noncanonical, Context::default()).is_err());
    let mut trailing = bytes.clone();
    trailing.push(b'0');
    assert!(template::CheckedTemplate::decode_ir(&trailing, Context::default()).is_err());
    let bad = String::from_utf8(bytes)
        .unwrap()
        .replace("6:return1:0", "6:return1:1");
    assert!(
        template::CheckedTemplate::decode_ir(bad.as_bytes(), Context::default()).is_err(),
        "decoded IR must recheck definitions"
    );
}

#[test]
fn hidden_template_closures_bind_private_helper_bodies_and_recheck_ir() {
    let helper_sig = Sig {
        name: "helper".into(),
        params: vec![Ty::Num],
        result: Ty::Num,
    };
    let t = template::check(
        Function {
            sig: Sig {
                name: "f::id".into(),
                params: vec![Ty::Param(0), Ty::Num],
                result: Ty::Param(0),
            },
            ops: vec![
                Op::Call {
                    dst: 2,
                    name: "helper".into(),
                    args: vec![1],
                },
                Op::Return(0),
            ],
            result: None,
        },
        1,
        BTreeMap::from([("helper".into(), helper_sig.clone())]),
        Context::default(),
    )
    .unwrap();
    let helper = |value| {
        check(
            Function {
                sig: helper_sig.clone(),
                ops: vec![Op::Num(1, value), Op::Return(1)],
                result: None,
            },
            BTreeMap::new(),
        )
        .unwrap()
    };
    let before =
        template::Bundle::new("f", vec![t.clone()], vec![helper(7)], Context::default()).unwrap();
    let after = template::Bundle::new("f", vec![t], vec![helper(8)], Context::default()).unwrap();
    assert_ne!(before.hash().unwrap(), after.hash().unwrap());
    let data = before.encode().unwrap();
    assert_eq!(
        template::Bundle::decode(&data).unwrap().encode().unwrap(),
        data
    );
    let mut extra = data;
    extra.push(b'0');
    assert!(template::Bundle::decode(&extra).is_err());
}

#[test]
fn source_generic_definitions_and_body_hidden_calls_check_independently() {
    use grail_seed::source;
    let text = "module api;pub enum Option<type T>{None,Some(T)}pub fn some<type T>(value:T)->Option<T>{return Option::Some(value);}pub fn none<type T>()->Option<T>{return Option::None;}pub fn score<type T>(value:T)->num{return helper();}fn helper()->num{return 7;}";
    let provider = source::compile(text, BTreeMap::new()).unwrap();
    assert!(provider.header().entry.is_none());
    assert!(provider.header().exports.is_empty());
    assert_eq!(provider.header().generics.len(), 3);
    let ir = provider.template_ir().unwrap();
    assert!(!ir.is_empty());
    assert_eq!(template::Bundle::decode(&ir).unwrap().encode().unwrap(), ir);
    let changed = source::compile(&text.replace("return 7", "return 8"), BTreeMap::new()).unwrap();
    assert_eq!(
        provider.header().fingerprint().unwrap(),
        changed.header().fingerprint().unwrap()
    );
    assert_ne!(
        provider.header().template_hash,
        changed.header().template_hash
    );
    let client=source::compile("module client;use api;pub fn run()->num{let value=api::some(7);let n=value!;let empty=api::none<num>();match empty{Some(x)=>{return x;},None=>{return n+api::score(\"owned\");}}}",BTreeMap::from([("api".into(),provider.header().clone())])).unwrap();
    assert_eq!(
        client.header().implementations["api"],
        provider.header().template_hash.clone().unwrap()
    );
    for text in [
        "module f;pub fn bad<type T>(value:T)->T{return 7;}",
        "module f;pub fn bad<type T>(value:T)->T{return value+1;}",
        "module f;pub struct Pair<type T>{a:T,b:T}pub fn bad<type T>(value:T)->Pair<T>{return Pair<T>{a:value,b:value};}",
    ] {
        assert!(source::compile(text, BTreeMap::new()).is_err());
    }
}

#[test]
fn helper_contracts_and_transitive_body_pins_cannot_be_silently_rebound() {
    let helper_sig = Sig {
        name: "helper".into(),
        params: vec![],
        result: Ty::Num,
    };
    let t = template::check(
        Function {
            sig: Sig {
                name: "f::id".into(),
                params: vec![Ty::Param(0)],
                result: Ty::Param(0),
            },
            ops: vec![
                Op::Call {
                    dst: 1,
                    name: "helper".into(),
                    args: vec![],
                },
                Op::Return(0),
            ],
            result: None,
        },
        1,
        BTreeMap::from([("helper".into(), helper_sig)]),
        Context::default(),
    )
    .unwrap();
    let wrong = check(
        Function {
            sig: Sig {
                name: "helper".into(),
                params: vec![],
                result: Ty::Text,
            },
            ops: vec![
                Op::TextLiteral {
                    dst: 0,
                    data: b"bad ABI".to_vec(),
                },
                Op::Return(0),
            ],
            result: None,
        },
        BTreeMap::new(),
    )
    .unwrap();
    assert!(template::Bundle::new("f", vec![t.clone()], vec![wrong], Context::default()).is_err());
    let helper = check(
        Function {
            sig: Sig {
                name: "helper".into(),
                params: vec![],
                result: Ty::Num,
            },
            ops: vec![Op::Num(0, 7), Op::Return(0)],
            result: None,
        },
        BTreeMap::new(),
    )
    .unwrap();
    let bundle = template::Bundle::new("f", vec![t], vec![helper], Context::default()).unwrap();
    let old = bundle
        .clone()
        .with_implementations(BTreeMap::from([("other".into(), "0".repeat(64))]))
        .unwrap();
    let new = bundle
        .with_implementations(BTreeMap::from([("other".into(), "1".repeat(64))]))
        .unwrap();
    assert_ne!(old.hash().unwrap(), new.hash().unwrap());
    assert_eq!(
        template::Bundle::decode(&new.encode().unwrap())
            .unwrap()
            .hash()
            .unwrap(),
        new.hash().unwrap()
    );
}

#[test]
fn materialization_uses_checked_bodies_and_requires_hidden_implementation_pins() {
    use grail_seed::{emit, source};
    let provider=source::compile("module api;pub fn score<type T>(value:T)->num{return helper();}fn helper()->num{return 7;}",BTreeMap::new()).unwrap();
    let bundle = template::Bundle::decode(&provider.template_ir().unwrap()).unwrap();
    let client = source::compile(
        "module client;use api;pub fn run()->num{return api::score(\"owned\");}",
        BTreeMap::from([("api".into(), provider.header().clone())]),
    )
    .unwrap();
    assert!(emit::module_c(&client).is_err());
    let c =
        emit::module_c_with_bundles(&client, &BTreeMap::from([("api".into(), bundle)])).unwrap();
    assert!(c.contains("g__generic_"));
    assert!(c.contains("g__helper_"));
    assert!(!c.contains("g_helper("));
    let local=source::compile("module local;enum Option<type T>{None,Some(T)}pub fn run()->num{let wrapped=some(\"x\");let value=unwrap(wrapped);return len(value)+id(7);}fn id<type T>(v:T)->T{return v;}fn some<type T>(v:T)->Option<T>{return Option::Some(v);}fn unwrap<type T>(v:Option<T>)->T{return v!;}",BTreeMap::new()).unwrap();
    assert!(emit::module_c(&local).unwrap().contains("g__generic_"));
    let numeric = source::compile(
        "module numeric;pub fn run()->num{return id(7);}fn id<type T>(v:T)->T{return v;}",
        BTreeMap::new(),
    )
    .unwrap();
    assert!(emit::module_llvm(&numeric).unwrap().contains("g__generic_"));
}
#[test]
fn native_instance_keys_erase_lifetime_values_but_not_type_shapes() {
    use grail_seed::{emit, source};
    let p=source::compile("module f;pub fn run<a,b>(p:read<a>,q:read<b>)->num{let x=id(read(p));let y=id(read(q));return len(x)+len(y);}fn id<type T>(value:T)->T{return value;}",BTreeMap::new()).unwrap();
    let c = emit::module_c(&p).unwrap();
    let instances = c
        .lines()
        .filter(|s| s.starts_with("static gv g__generic_") && s.ends_with('{'))
        .count();
    assert_eq!(instances, 1, "lifetime-only instantiations share code");
}

#[test]
fn generic_contracts_preserve_origins_parent_loans_and_caller_binders() {
    use grail_seed::{emit, source};
    let pre = "fn id<type T>(value:T)->T{return value;}";
    for body in [
        "pub fn run<a>(p:read<a>)->read<a>{let b=bytes();push(b,7);return id(read(b));}",
        "pub fn run()->num{let b=bytes();push(b,7);let p=id(read(b));push(b,8);return len(p);}",
        "pub fn run()->num{let b=bytes();push(b,7);let p=mut(b);let q=id(read(p));write(p,0,8);return len(q);}",
        "pub fn run()->num{let b=bytes();push(b,7);let p=pair(mut(b),mut(b));return len(p.first);}fn pair<type T,type U>(a:T,b:U)->Pair<T,U>{return Pair{first:a,second:b};}struct Pair<type T,type U>{first:T,second:U}",
        "pub fn run()->num{return wrong(7);}fn wrong<type T>(x:T)->num{return x+1;}",
        "pub fn run()->num{return id<num,string>(7);}",
    ] {
        assert!(
            source::compile(&format!("module f;{pre}{body}"), BTreeMap::new()).is_err(),
            "{body}"
        );
    }
    let p=source::compile(&format!("module f;{pre}fn second<type T,type U>(a:T,b:U)->U{{return id(b);}}pub fn run()->num{{let value=second(7,\"x\");return len(value);}}"),BTreeMap::new()).unwrap();
    assert!(emit::module_c(&p).is_ok());
    let p=source::compile(&format!("module f;{pre}pub fn run<a>(p:mut<a>)->num{{let first=id(read(p));let n=len(first);let second=id(mut(p));return n+len(second);}}"),BTreeMap::new()).unwrap();
    let c = emit::module_c(&p).unwrap();
    assert_eq!(
        c.lines()
            .filter(|s| s.starts_with("static gv g__generic_") && s.ends_with('{'))
            .count(),
        2,
        "mutable and readonly modes retain different keys"
    );
}
#[test]
fn instance_keys_include_caller_private_layouts_and_growing_recursion_is_bounded() {
    use grail_seed::{emit, source};
    let api = source::compile(
        "module api;pub fn id<type T>(value:T)->T{return value;}",
        BTreeMap::new(),
    )
    .unwrap();
    let mut names = Vec::new();
    for ty in ["num", "string"] {
        let literal = if ty == "num" { "7" } else { "\"x\"" };
        let src = format!(
            "module client;use api;struct Private{{field:{ty}}}pub fn run()->num{{let p=api::id(Private{{field:{literal}}});return 0;}}"
        );
        let p =
            source::compile(&src, BTreeMap::from([("api".into(), api.header().clone())])).unwrap();
        let c = emit::module_c_with_bundles(
            &p,
            &BTreeMap::from([(
                "api".into(),
                template::Bundle::decode(&api.template_ir().unwrap()).unwrap(),
            )]),
        )
        .unwrap();
        names.push(
            c.lines()
                .find(|s| s.starts_with("static ") && s.contains("g__generic_"))
                .unwrap()
                .to_owned(),
        );
    }
    assert_ne!(
        names[0]
            .split("g__generic_")
            .nth(1)
            .unwrap()
            .split('(')
            .next()
            .unwrap(),
        names[1]
            .split("g__generic_")
            .nth(1)
            .unwrap()
            .split('(')
            .next()
            .unwrap()
    );
    let p=source::compile("module grow;struct Wrap<type T>{value:T}pub fn run()->num{return grow(7);}fn grow<type T>(v:T)->num{return grow(Wrap<T>{value:v});}",BTreeMap::new()).unwrap();
    let err = emit::module_c(&p).unwrap_err();
    assert!(err.contains("limit") || err.contains("depth"), "{err}");
}
