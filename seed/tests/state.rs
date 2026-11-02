use grail_seed::{Function, Op, Sig, Ty, check, source};
use std::collections::BTreeMap;
fn checked(ops: Vec<Op>, result: u32) -> bool {
    check(
        Function {
            sig: Sig {
                name: "f".into(),
                params: vec![Ty::Num],
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
fn dead_scalar_facts_do_not_create_values_or_erase_register_types() {
    assert!(
        !checked(
            vec![
                Op::Num(1, 5),
                Op::Loop {
                    index: 0,
                    end: 1,
                    body: vec![]
                }
            ],
            1
        ),
        "dead scalar is still a previously defined loop-index binding"
    );
    assert!(checked(
        vec![
            Op::Num(1, 5),
            Op::End(0),
            Op::Loop {
                index: 0,
                end: 1,
                body: vec![]
            }
        ],
        1
    ));
    assert!(checked(
        vec![
            Op::Num(1, 5),
            Op::Loop {
                index: 2,
                end: 1,
                body: vec![]
            },
            Op::Loop {
                index: 2,
                end: 1,
                body: vec![]
            }
        ],
        1
    ));
    assert!(!checked(
        vec![
            Op::Block {
                body: vec![Op::Num(3, 5)]
            },
            Op::Num(1, 5),
            Op::Loop {
                index: 3,
                end: 1,
                body: vec![]
            }
        ],
        1
    ));
    assert!(!checked(
        vec![
            Op::If {
                condition: 0,
                yes: vec![Op::Num(2, 5)],
                no: vec![Op::Num(2, 6)]
            },
            Op::Num(1, 5),
            Op::Loop {
                index: 2,
                end: 1,
                body: vec![]
            }
        ],
        1
    ));
    assert!(checked(
        vec![
            Op::If {
                condition: 0,
                yes: vec![Op::Num(2, 5)],
                no: vec![]
            },
            Op::Num(1, 5),
            Op::Loop {
                index: 2,
                end: 1,
                body: vec![]
            }
        ],
        1
    ));
    assert!(!checked(
        vec![Op::If {
            condition: 0,
            yes: vec![Op::Num(1, 1)],
            no: vec![]
        }],
        1
    ));
    assert!(!checked(
        vec![Op::Loop {
            index: 1,
            end: 0,
            body: vec![Op::Num(2, 1)]
        }],
        2
    ));
    assert!(!checked(
        vec![Op::Loop {
            index: 1,
            end: 0,
            body: vec![Op::End(0)]
        }],
        0
    ));
    assert!(!checked(
        vec![Op::Num(1, 7), Op::End(1), Op::Bytes { dst: 1 }, Op::End(1)],
        0
    ));
    assert!(!checked(
        vec![Op::If {
            condition: 0,
            yes: vec![Op::Num(1, 1)],
            no: vec![Op::Bytes { dst: 1 }, Op::End(1)]
        }],
        0
    ));
    assert!(checked(
        vec![Op::If {
            condition: 0,
            yes: vec![Op::Num(1, 1)],
            no: vec![Op::Num(1, 2)]
        }],
        1
    ));
    assert!(checked(
        vec![
            Op::Num(1, 1),
            Op::If {
                condition: 0,
                yes: vec![Op::Num(1, 2)],
                no: vec![]
            }
        ],
        1
    ));
}
#[test]
fn thousands_of_dead_scalars_cannot_hide_a_live_loan_or_change_scope_cleanup() {
    let mut prefix = "fn f()->num{var b =bytes();push(b,1);p :=read(b);".to_string();
    for i in 0..2000 {
        prefix.push_str(&format!("n{i}:={i};"));
    }
    assert!(
        source::compile(
            &format!("{prefix}push(b,2);return len(p);}}"),
            BTreeMap::new()
        )
        .is_err()
    );
    assert!(
        source::compile(
            &format!("{prefix}n :=len(p);push(b,2);return n+len(b);}}"),
            BTreeMap::new()
        )
        .is_ok()
    );
}
