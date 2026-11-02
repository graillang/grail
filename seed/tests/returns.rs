use grail_seed::{emit, source};
fn accepted(s: &str) -> bool {
    source::compile(s, std::collections::BTreeMap::new()).is_ok()
}
#[test]
fn terminated_branches_blocks_and_loop_paths_do_not_join() {
    for s in [
        "module f;struct T<a>{span:mut<a>,name:string}pub fn span<a>(t:T<a>,n:num)->read<a>{if n{return read(t.span);}return read(t.span);}",
        "module f;struct T<a>{span:mut<a>,name:string}pub fn f()->num{let b=bytes();push(b,7);let t=T{span:mut(b),name:\"n\"};let r=read(t.span);drop(t);return at(r,0);}",
        "fn f(n:num)->num{if n{return 7;}else{return 8;}}",
        "fn f(n:num)->num{if n{return 7;} return 8;}",
        "fn f(n:num)->num{{return n;}}",
        "fn f(n:num)->num{while n{return 7;} return 8;}",
        "fn f(n:num)->num{for i in n{return i;}return 9;}",
        "fn f(n:num)->string{let b=bytes();push(b,1);if n {return \"one\";}return \"two\";}",
        "fn f(n:num)->string{let b=bytes();push(b,1);while n{let c=copy_bytes(b);return text(c);}return \"two\";}",
        "fn f(n:num)->bytes{let b=bytes();push(b,1);for i in n{if i{return b;}}return b;}",
        "module f;struct R{a:string,b:string}pub fn f(n:num)->string{let r=R{a:\"a\",b:\"b\"};if n{return r.a;}return r.b;}",
        "module f;struct R{a:string,b:string}pub fn f(n:num)->string{let r=R{a:\"a\",b:\"b\"};if n{let x=r.a;}else{let y=r.a;}return r.b;}",
        "module f;struct R{a:string,b:string}pub fn f(n:num)->string{let r=R{a:\"a\",b:\"b\"};if n{let x=r.a;}return r.b;}",
        "fn f<a>(n:num,v:read<a>)->read<a>{if n{let b=bytes();push(b,1);return read(v);}return v;}",
    ] {
        let p = source::compile(s, std::collections::BTreeMap::new())
            .unwrap_or_else(|e| panic!("{s}\n{e}"));
        emit::module_c(&p).unwrap();
    }
}
#[test]
fn every_exit_checks_type_origin_and_cleanup_obligations() {
    for s in [
        r#"module f;struct T<a>{span:mut<a>,name:string}pub fn f()->num{let b=bytes();push(b,7);let t=T{span:mut(b),name:"n"};let r=read(t.span);drop(t);let w=mut(b);write(w,0,8);return at(r,0);}"#,
        r#"module f;struct T<a>{span:mut<a>,name:string}pub fn f()->num{let b=bytes();push(b,7);let t=T{span:mut(b),name:"n"};let r=mut(t.span);drop(t);let p=read(b);write(r,0,8);return at(p,0);}"#,
        r#"module f;struct T<a>{span:mut<a>,name:string}pub fn f<a>(t:T<a>)->read<a>{return read(t.name);}"#,
        "fn f(n:num)->num{if n{return 1;}}",
        "fn f(n:num)->num{return 1;return 2;}",
        "fn f(n:num)->num{{return 1;}let x=2;}",
        "fn f(n:num)->num{if n{return 1;}else{return 2;}return 3;}",
        "fn f(n:num)->num{if n{return \"bad\";}return 0;}",
        "fn f<a>(n:num,v:read<a>)->read<a>{if n{let b=bytes();push(b,1);return read(b);}return v;}",
        "fn f<a,b>(n:num,v:read<a>,w:read<b>)->read<a>{if n{return w;}return v;}",
        "fn f(n:num)->bytes{let b=bytes();push(b,1);if n{drop(b);}return b;}",
        "fn f(n:num)->num{let b=bytes();push(b,1);while n{drop(b);}return 0;}",
        "module f;struct R{a:string,b:string}pub fn f(n:num)->R{let r=R{a:\"a\",b:\"b\"};if n{let x=r.a;}else{let y=r.a;}return r;}",
    ] {
        assert!(!accepted(s), "{s}");
    }
}

#[test]
fn raw_ir_joins_do_not_invent_numeric_definitions() {
    use grail_seed::{Function, Op, Sig, Ty, check};
    use std::collections::BTreeMap;
    let f = |no| Function {
        sig: Sig {
            name: "f".into(),
            params: vec![Ty::Num],
            result: Ty::Num,
        },
        ops: vec![
            Op::If {
                condition: 0,
                yes: vec![Op::Num(1, 7)],
                no,
            },
            Op::Return(1),
        ],
        result: None,
    };
    assert!(check(f(vec![]), BTreeMap::new()).is_err());
    assert!(check(f(vec![Op::Num(1, 8)]), BTreeMap::new()).is_ok());
    let f = Function {
        sig: Sig {
            name: "f".into(),
            params: vec![Ty::Num],
            result: Ty::Num,
        },
        ops: vec![Op::Bytes { dst: 1 }, Op::Return(0)],
        result: None,
    };
    assert!(
        check(f, BTreeMap::new()).is_err(),
        "raw IR does not gain unchecked implicit cleanup"
    );
}
