use grail_seed::{Function, Op, Sig, Ty, check, emit, source};
use std::collections::BTreeMap;
fn accepted(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn loop_exits_close_local_scopes_and_target_the_innermost_loop() {
    for s in [
        "fn f<a>(p:mut<a>,n:num)->num{for i in n{let local=read(p);assert(len(local)==1);if i==0{continue;}break;}write(p,0,9);return at(read(p),0);}",
        "fn f(n:num)->num{var sum=0;for i in n{if i==2{continue;}if i==5{break;}sum=sum+i;}return sum;}",
        "fn f(n:num)->num{var i=0;var sum=0;while i<n{i=i+1;if i==2{continue;}if i==5{break;}sum=sum+i;}return sum;}",
        "fn f(n:num)->num{var sum=0;for outer in n{for inner in 4{if inner==1{continue;}if outer==2{break;}sum=sum+outer*10+inner;}if outer==3{break;}}return sum;}",
        "module f;enum O{Some(num),None}pub fn f(n:num)->num{var sum=0;for i in n{let v=O::Some(i);match v{Some(x)=>{if x==3{break;}if x==1{continue;}sum=sum+x;},None=>{break;}}}return sum;}",
        "module f;struct Pair{a:string,b:string}pub fn f()->num{let source=bytes();push(source,7);for i in 6{let pair=Pair{a:\"a\",b:\"bb\"};let first=pair.a;let r=read(first);assert(len(r)==1);if i%2==0{{let inner=\"inner\";continue;}}break;}push(source,9);return len(source);}",
        "fn f()->num{let b=bytes();push(b,7);for i in 3{drop(b);break;}return 0;}",
        "fn f(n:num)->num{for i in n{if i{continue;}else{break;}}return 0;}",
        "fn f(n:num)->num{let b=bytes();push(b,7);let p=read(b);for i in n{if at(p,0){continue;}break;}return at(p,0);}",
    ] {
        let p = source::compile(s, BTreeMap::new()).unwrap_or_else(|e| panic!("{s}\n{e}"));
        emit::module_c(&p).unwrap();
    }
}
#[test]
fn loop_exits_cannot_hide_ownership_changes_or_unreachable_operations() {
    for s in [
        "fn f()->num{break;return 0;}",
        "fn f()->num{continue;return 0;}",
        "fn f()->num{for i in 3{break;let x=1;}return 0;}",
        "fn f(n:num)->num{while n{if n{break;}else{continue;}let x=1;}return 0;}",
        "fn f()->num{let b=bytes();push(b,7);for i in 3{let moved=b;continue;}return 0;}",
        "fn f()->num{var x=7;for i in 3{drop(x);break;}return x;}",
        "fn f()->num{let b=bytes();push(b,7);let p=read(b);for i in 3{push(b,9);continue;}return at(p,0);}",
    ] {
        assert!(!accepted(s), "{s}");
    }
}
fn raw(ops: Vec<Op>, params: Vec<Ty>, result: u32) -> bool {
    check(
        Function {
            sig: Sig {
                name: "f".into(),
                params,
                result: Ty::Num,
            },
            ops,
            result: Some(result),
        },
        BTreeMap::new(),
    )
    .is_ok()
}
#[test]
fn raw_jumps_validate_frames_even_when_all_branch_paths_terminate() {
    assert!(!raw(vec![Op::Break, Op::Num(0, 0)], vec![], 0));
    for jump in [Op::Break, Op::Continue] {
        assert!(!raw(
            vec![
                Op::Num(1, 2),
                Op::Loop {
                    index: 2,
                    end: 1,
                    body: vec![Op::Bytes { dst: 3 }, jump.clone()]
                },
                Op::Num(4, 0)
            ],
            vec![],
            4
        ));
        assert!(raw(
            vec![
                Op::Num(1, 2),
                Op::Loop {
                    index: 2,
                    end: 1,
                    body: vec![Op::Bytes { dst: 3 }, Op::End(3), jump.clone()]
                },
                Op::Num(4, 0)
            ],
            vec![],
            4
        ));
        assert!(!raw(
            vec![
                Op::Num(1, 2),
                Op::Loop {
                    index: 2,
                    end: 1,
                    body: vec![Op::End(0), jump.clone()]
                },
                Op::End(0),
                Op::Num(4, 0)
            ],
            vec![Ty::Bytes],
            4
        ));
        assert!(!raw(
            vec![
                Op::Num(1, 2),
                Op::Loop {
                    index: 2,
                    end: 1,
                    body: vec![Op::End(0), jump.clone()]
                },
                Op::Num(4, 0)
            ],
            vec![Ty::Num],
            4
        ));
        assert!(!raw(
            vec![
                Op::Num(1, 2),
                Op::Loop {
                    index: 2,
                    end: 1,
                    body: vec![Op::While {
                        condition: 3,
                        test: vec![Op::Num(3, 0), jump],
                        body: vec![]
                    }]
                },
                Op::Num(4, 0)
            ],
            vec![],
            4
        ));
    }
    assert!(!raw(
        vec![
            Op::Num(1, 2),
            Op::Loop {
                index: 2,
                end: 1,
                body: vec![Op::If {
                    condition: 0,
                    yes: vec![Op::End(0), Op::Break],
                    no: vec![Op::Continue]
                }]
            },
            Op::Num(4, 0)
        ],
        vec![Ty::Num],
        4
    ));
}
