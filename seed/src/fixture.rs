//! Fixed representative workloads built through the public typed IR, not surface syntax.
use crate::{Bin, Function, Mode, Op, Reg, Sig, Ty};
fn bin(dst: Reg, op: Bin, left: Reg, right: Reg) -> Op {
    Op::Binary {
        dst,
        op,
        left,
        right,
    }
}
/// A byte lexer (space transitions), rolling hash, and bucket-table update.
pub fn provider(bias: u64, version: u8) -> Function {
    let mut params = vec![Ty::View(Mode::Read, 0), Ty::Num];
    if version == 2 {
        params.push(Ty::Num)
    }
    Function {
        sig: Sig {
            name: "scan".into(),
            params,
            result: Ty::Num,
        },
        ops: vec![
            Op::Len { dst: 10, src: 0 },
            Op::Num(11, 14695981039346656037),
            Op::Num(12, 1099511628211),
            Op::Num(13, 0),
            Op::Num(14, 32),
            Op::Num(15, 1),
            Op::Num(16, 128),
            Op::Buffer {
                dst: 17,
                len: 128,
                seed: 0,
            },
            Op::Borrow {
                dst: 18,
                src: 17,
                mode: Mode::Write,
            },
            Op::Loop {
                index: 20,
                end: 10,
                body: vec![
                    Op::Read {
                        dst: 21,
                        src: 0,
                        index: 20,
                    },
                    bin(22, Bin::Xor, 11, 21),
                    bin(11, Bin::Mul, 22, 12),
                    bin(23, Bin::Ne, 21, 14),
                    bin(24, Bin::And, 23, 15),
                    bin(13, Bin::Add, 13, 24),
                    bin(15, Bin::Eq, 21, 14),
                    bin(25, Bin::Rem, 21, 16),
                    Op::Read {
                        dst: 26,
                        src: 18,
                        index: 25,
                    },
                    Op::Num(27, 1),
                    bin(26, Bin::Add, 26, 27),
                    Op::Write {
                        dst: 18,
                        index: 25,
                        value: 26,
                    },
                ],
            },
            Op::Loop {
                index: 30,
                end: 16,
                body: vec![
                    Op::Read {
                        dst: 31,
                        src: 18,
                        index: 30,
                    },
                    bin(11, Bin::Xor, 11, 31),
                ],
            },
            Op::End(18),
            Op::End(17),
            bin(40, Bin::Add, 11, 13),
            bin(40, Bin::Add, 40, 1),
            Op::Num(41, bias),
            bin(40, Bin::Add, 40, 41),
        ],
        result: Some(40),
    }
}
pub fn client(sig: &Sig, len: usize, repeats: u64) -> Function {
    let args = if sig.params.len() == 3 {
        vec![3, 4, 4]
    } else {
        vec![3, 4]
    };
    Function {
        sig: Sig {
            name: "entry".into(),
            params: vec![],
            result: Ty::Num,
        },
        ops: vec![
            Op::Buffer {
                dst: 0,
                len,
                seed: 7,
            },
            Op::Borrow {
                dst: 1,
                src: 0,
                mode: Mode::Read,
            },
            Op::Pack { dst: 2, src: 1 },
            Op::Num(4, 9),
            Op::Num(5, repeats),
            Op::Num(6, 0),
            Op::Loop {
                index: 7,
                end: 5,
                body: vec![
                    Op::Borrow {
                        dst: 3,
                        src: 2,
                        mode: Mode::Read,
                    },
                    Op::Call {
                        dst: 8,
                        name: sig.name.clone(),
                        args,
                    },
                    bin(6, Bin::Add, 6, 8),
                ],
            },
            Op::End(2),
            Op::End(0),
        ],
        result: Some(6),
    }
}
/// Distinguish ordinary growing IR from many simultaneously live loans of one owner.
pub fn scaling(n: u32, fanout: bool) -> Function {
    let mut ops = vec![
        Op::Buffer {
            dst: 0,
            len: 8,
            seed: 7,
        },
        Op::Borrow {
            dst: 1,
            src: 0,
            mode: Mode::Read,
        },
    ];
    for r in 2..n + 2 {
        ops.push(if fanout {
            Op::Borrow {
                dst: r,
                src: 0,
                mode: Mode::Read,
            }
        } else {
            Op::Len { dst: r, src: 1 }
        })
    }
    ops.push(Op::Num(n + 2, 0));
    Function {
        sig: Sig {
            name: "scale".into(),
            params: vec![],
            result: Ty::Num,
        },
        ops,
        result: Some(n + 2),
    }
}
