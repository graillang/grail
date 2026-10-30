//! Text invariants must survive direct IR, source escapes, mutation and interface boundaries.
use grail_seed::{Function, Op, Sig, Ty, check, source};
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn utf8_text_cannot_be_mutated_as_arbitrary_bytes() {
    assert!(ok(
        "fn f()->num {let s=\"hé🙂\";append_text(s,\"!\");return len(s);}"
    ));
    assert!(!ok(
        "fn f()->num {let s=\"abc\";let p=mut(s);write(p,0,255);return 0;}"
    ));
    assert!(!ok("fn f()->num {let s=\"abc\";push(s,255);return 0;}"));
    assert!(!ok(
        "fn f()->num {let s=\"abc\";let v=read(s);append_text(s,\"!\");return at(v,0);}"
    ));
    assert!(ok(
        "fn f()->num {let s=\"abc\";let v=read(s);let n=len(v);append_text(s,\"!\");return n+len(s);}"
    ));
    assert!(!ok(
        "fn f()->num {let s=\"abc\";append_text(s,s);return 0;}"
    ));
}
#[test]
fn literal_escaping_and_raw_ir_are_checked() {
    assert!(ok(
        r#"fn f()->num {let s="\"\\\n\r\t\0\xc3\xa9";return len(s);}"#
    ));
    for s in [
        r#"fn f()->num {let s="\xff";return 0;}"#,
        r#"fn f()->num {let s="\x0";return 0;}"#,
        r#"fn f()->num {let s="\q";return 0;}"#,
        r#"fn f()->num {let s="unterminated;return 0;}"#,
    ] {
        assert!(!ok(s), "{s}");
    }
    assert!(
        check(
            Function {
                sig: Sig {
                    name: "bad".into(),
                    params: vec![],
                    result: Ty::Text
                },
                ops: vec![Op::TextLiteral {
                    dst: 0,
                    data: vec![255]
                }],
                result: 0
            },
            BTreeMap::new()
        )
        .is_err()
    );
}
#[test]
fn strings_move_and_return_through_written_interfaces() {
    let f = source::compile("fn echo(s:string)->string {return s;}", BTreeMap::new()).unwrap();
    let sig = grail_seed::module::Interface::decode(&f.interface()).unwrap();
    assert!(
        source::compile(
            "use echo; fn f()->num {let s=echo(\"hello\");return len(s);}",
            BTreeMap::from([("echo".into(), sig)])
        )
        .is_ok()
    );
    assert!(!ok(
        "fn f()->num {let s=\"abc\";let moved=s;return len(s)+len(moved);}"
    ));
}
