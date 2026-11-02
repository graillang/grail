use grail_seed::{Function, Mode, Op, Sig, Ty, check, emit};
use std::collections::BTreeMap;
fn checked(ops: Vec<Op>, result: u32) -> Result<grail_seed::Checked, String> {
    check(
        Function {
            sig: Sig {
                name: "refs".into(),
                params: vec![],
                result: Ty::Num,
            },
            ops,
            result: Some(result),
        },
        BTreeMap::new(),
    )
}
fn address(dst: u32, src: u32, mode: Mode) -> Op {
    Op::Address {
        dst,
        src,
        path: vec![],
        mode,
    }
}
#[test]
fn addressed_scalars_stay_live_through_indirect_reads_and_exchanges() {
    let p = checked(
        vec![
            Op::Num(0, 7),
            address(1, 0, Mode::Write),
            Op::Num(2, 9),
            Op::Exchange {
                dst: 3,
                src: 1,
                value: 2,
            },
            Op::Load { dst: 4, src: 1 },
            Op::End(1),
        ],
        4,
    )
    .unwrap();
    let c = emit::c(&p);
    assert!(c.contains("r3=*r1;*r1=r2;"));
    assert!(emit::llvm(&p).unwrap().contains("load i64, ptr"));
    assert!(
        checked(
            vec![
                Op::Num(0, 7),
                address(1, 0, Mode::Read),
                Op::Load { dst: 2, src: 1 },
                Op::End(1)
            ],
            2
        )
        .is_ok()
    );
}
#[test]
fn scalar_storage_cannot_be_overwritten_ended_or_read_through_conflicting_loans() {
    for op in [
        Op::Num(0, 9),
        Op::End(0),
        Op::Move { dst: 2, src: 0 },
        address(2, 0, Mode::Read),
    ] {
        assert!(
            checked(
                vec![
                    Op::Num(0, 7),
                    address(1, 0, Mode::Write),
                    op,
                    Op::Load { dst: 3, src: 1 },
                    Op::End(1)
                ],
                3
            )
            .is_err()
        );
    }
    assert!(
        checked(
            vec![
                Op::Num(0, 7),
                address(1, 0, Mode::Read),
                Op::Num(2, 9),
                Op::Exchange {
                    dst: 3,
                    src: 1,
                    value: 2
                },
                Op::End(1)
            ],
            3
        )
        .is_err()
    );
    assert!(
        checked(
            vec![
                Op::Num(0, 7),
                address(1, 0, Mode::Read),
                Op::Num(2, 9),
                Op::End(1)
            ],
            2
        )
        .is_ok()
    );
}
#[test]
fn typed_parameter_reborrows_freeze_the_parent_and_local_addresses_cannot_escape() {
    let t = Ty::Ref(Mode::Write, 0, Box::new(Ty::Num));
    let f = |ops| {
        check(
            Function {
                sig: Sig {
                    name: "f".into(),
                    params: vec![t.clone()],
                    result: Ty::Num,
                },
                ops,
                result: Some(2),
            },
            BTreeMap::new(),
        )
    };
    assert!(
        f(vec![
            address(1, 0, Mode::Read),
            Op::Load { dst: 2, src: 1 },
            Op::End(1),
            Op::End(0)
        ])
        .is_ok()
    );
    assert!(
        f(vec![
            address(1, 0, Mode::Read),
            Op::Load { dst: 2, src: 0 },
            Op::End(1),
            Op::End(0)
        ])
        .is_err()
    );
    assert!(
        check(
            Function {
                sig: Sig {
                    name: "f".into(),
                    params: vec![t.clone()],
                    result: t
                },
                ops: vec![Op::Num(1, 7), address(2, 1, Mode::Write), Op::End(0)],
                result: Some(2)
            },
            BTreeMap::new()
        )
        .is_err()
    );
}

#[test]
fn field_move_relocates_owned_storage_without_relocating_external_captures() {
    let text = "module f;struct R{name:string,other:string}pub fn run()->num{r :=R{name:\"name\",other:\"other\"};name :=r.name;view :=read(name);drop(r);return len(view);}";
    assert!(grail_seed::source::compile(text, BTreeMap::new()).is_ok());
}
#[test]
fn addressed_heap_fields_cannot_overlap_exclusive_data_views() {
    for body in [
        "p :=mut(r.data);q :=borrow(r.data);s :=read(q);write(p,0,8);return len(s);",
        "p :=mut(r.data);q :=borrow(r);s :=read(q.data);write(p,0,8);return len(s);",
        "p :=borrow_mut(r.data);s :=read(p);push(p,8);return len(s);",
    ] {
        let text = format!(
            "module f;struct R{{data:bytes}}pub fn run()->num{{var b =bytes();push(b,7);r :=R{{data:b}};{body}}}"
        );
        assert!(
            grail_seed::source::compile(&text, BTreeMap::new()).is_err(),
            "{body}"
        );
    }
}

#[test]
fn generic_storage_borrows_are_universal_but_do_not_permit_moving_borrowed_values() {
    for text in [
        "module f;pub fn inspect<type T>(v:T)->num{var local=v;p :=borrow_mut(local);return 0;}",
        "module f;struct Phantom<type T>{value:num}pub fn inspect<a,type T>(v:T)->num{p :=Phantom<ref_mut<a,T>>{value:0};return 0;}",
        "module f;pub fn replace<a,type T>(slot:ref_mut<a,T>,value:T)->T{return exchange(slot,value);}",
        "module f;struct C<a,type T>{slot:ref_mut<a,T>}pub fn inspect<a>(v:C<a,read<a>>)->num{return 0;}",
    ] {
        assert!(
            grail_seed::source::compile(text, BTreeMap::new()).is_ok(),
            "{text}"
        );
    }
    let bad = "module f;fn hidden<a,type T>(slot:ref_mut<a,T>,v:T)->num{return 0;}pub fn bad<type T>(v:T)->num{p :=borrow_mut(v);return hidden(p,v);}";
    assert!(grail_seed::source::compile(bad, BTreeMap::new()).is_err());
}
