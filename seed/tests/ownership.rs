//! These protect lifetime/authority and exported-interface contracts, not diagnostic wording.
use grail_seed::{Function, Mode, Op, Sig, Ty, check, fixture};
use std::collections::BTreeMap;
fn local(mut ops: Vec<Op>) -> Function {
    ops.push(Op::Num(100, 0));
    Function {
        sig: Sig {
            name: "test".into(),
            params: vec![],
            result: Ty::Num,
        },
        ops,
        result: 100,
    }
}
fn owner() -> Op {
    Op::Buffer {
        dst: 0,
        len: 16,
        seed: 7,
    }
}
fn borrow(dst: u32, src: u32, mode: Mode) -> Op {
    Op::Borrow { dst, src, mode }
}
fn accepted(ops: Vec<Op>) -> bool {
    check(local(ops), BTreeMap::new()).is_ok()
}
#[test]
fn owner_release_and_move_require_all_views_to_end() {
    for mode in [Mode::Read, Mode::Write] {
        assert!(!accepted(vec![owner(), borrow(1, 0, mode), Op::End(0)]));
        assert!(!accepted(vec![
            owner(),
            borrow(1, 0, mode),
            Op::Move { dst: 2, src: 0 }
        ]));
        assert!(accepted(vec![
            owner(),
            borrow(1, 0, mode),
            Op::End(1),
            Op::Move { dst: 2, src: 0 },
            Op::End(2)
        ]));
    }
}
#[test]
fn authority_matrix_and_carrier_reborrow() {
    for first in [Mode::Read, Mode::Write] {
        for second in [Mode::Read, Mode::Write] {
            assert_eq!(
                accepted(vec![owner(), borrow(1, 0, first), borrow(2, 0, second)]),
                first == Mode::Read && second == Mode::Read
            );
        }
    }
    let prefix = vec![
        owner(),
        borrow(1, 0, Mode::Write),
        Op::Pack { dst: 2, src: 1 },
        borrow(3, 2, Mode::Read),
    ];
    let mut invalid = prefix.clone();
    invalid.push(Op::Len { dst: 4, src: 2 });
    assert!(!accepted(invalid));
    let mut valid = prefix;
    valid.extend([
        Op::End(3),
        Op::Len { dst: 4, src: 2 },
        Op::End(2),
        Op::End(0),
    ]);
    assert!(accepted(valid));
    assert!(!accepted(vec![
        owner(),
        borrow(1, 0, Mode::Read),
        borrow(2, 1, Mode::Write)
    ]));
}
#[test]
fn written_region_is_checked_at_producer() {
    let sig = Sig {
        name: "identity".into(),
        params: vec![Ty::View(Mode::Read, 7), Ty::View(Mode::Read, 8)],
        result: Ty::View(Mode::Read, 7),
    };
    assert!(
        check(
            Function {
                sig: sig.clone(),
                ops: vec![],
                result: 0
            },
            BTreeMap::new()
        )
        .is_ok()
    );
    assert!(
        check(
            Function {
                sig: sig.clone(),
                ops: vec![],
                result: 1
            },
            BTreeMap::new()
        )
        .is_err()
    );
    assert!(
        check(
            Function {
                sig,
                ops: vec![
                    Op::Buffer {
                        dst: 2,
                        len: 2,
                        seed: 0
                    },
                    borrow(3, 2, Mode::Read)
                ],
                result: 3
            },
            BTreeMap::new()
        )
        .is_err()
    );
}
#[test]
fn returned_imported_view_preserves_owner_and_parent_restrictions() {
    let sig = Sig {
        name: "identity".into(),
        params: vec![Ty::View(Mode::Read, 7)],
        result: Ty::View(Mode::Read, 7),
    };
    let hidden = Sig::decode(&sig.encode().unwrap()).unwrap();
    let ops = vec![
        owner(),
        borrow(1, 0, Mode::Write),
        borrow(2, 1, Mode::Read),
        Op::Call {
            dst: 3,
            name: sig.name.clone(),
            args: vec![2],
        },
    ];
    let imports = BTreeMap::from([(sig.name.clone(), hidden)]);
    for illegal in [Op::End(0), Op::End(1), Op::Len { dst: 4, src: 1 }] {
        let mut p = ops.clone();
        p.push(illegal);
        assert!(check(local(p), imports.clone()).is_err());
    }
    let mut p = ops;
    p.extend([Op::End(3), Op::End(1), Op::End(0)]);
    assert!(check(local(p), imports).is_ok());
}
#[test]
fn interfaces_are_canonical_and_modes_are_not_erased_by_serialization() {
    let p = check(fixture::provider(0, 1), BTreeMap::new()).unwrap();
    let a = p.interface();
    let s = Sig::decode(&a).unwrap();
    assert_eq!(
        a,
        check(fixture::provider(19, 1), BTreeMap::new())
            .unwrap()
            .interface()
    );
    assert!(
        check(
            fixture::client(&s, 128, 2),
            BTreeMap::from([(s.name.clone(), s.clone())])
        )
        .is_ok()
    );
    let mut changed = s;
    changed.params[0] = Ty::View(Mode::Write, 0);
    assert!(
        check(
            fixture::client(&changed, 128, 2),
            BTreeMap::from([(changed.name.clone(), changed)])
        )
        .is_err()
    );
    for invalid in [
        a.replace("grail-seed-interface-2", "grail-seed-interface-0"),
        a.clone() + "\n",
        a.replace("scan", "bad-name"),
        a.replace("r0", "r00"),
    ] {
        assert!(Sig::decode(&invalid).is_err());
    }
}
#[test]
fn loop_cannot_drop_an_entry_resource_or_leak_a_fresh_loan() {
    assert!(!accepted(vec![
        owner(),
        Op::Num(1, 2),
        Op::Loop {
            index: 2,
            end: 1,
            body: vec![Op::End(0)]
        }
    ]));
    assert!(!accepted(vec![
        owner(),
        Op::Num(1, 2),
        Op::Loop {
            index: 2,
            end: 1,
            body: vec![borrow(3, 0, Mode::Read)]
        }
    ]));
    assert!(accepted(vec![
        owner(),
        Op::Num(1, 2),
        Op::Loop {
            index: 2,
            end: 1,
            body: vec![borrow(3, 0, Mode::Read), Op::End(3)]
        },
        Op::End(0)
    ]));
}

#[test]
fn ending_one_shared_view_does_not_release_other_views_or_moved_carriers() {
    let prefix = vec![
        owner(),
        borrow(1, 0, Mode::Read),
        borrow(2, 0, Mode::Read),
        Op::Pack { dst: 3, src: 2 },
        Op::Move { dst: 4, src: 3 },
        Op::End(1),
    ];
    let mut invalid = prefix.clone();
    invalid.push(Op::End(0));
    assert!(!accepted(invalid));
    let mut valid = prefix;
    valid.extend([Op::End(4), Op::End(0)]);
    assert!(accepted(valid));
}
