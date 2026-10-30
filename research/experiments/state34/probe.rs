//! Compile/lower only: generated loops and deliberately invalid IR are never executed.
use grail_seed::{Bin, Function, Mode, Op, Sig, Ty, check};
use std::{fs, path::PathBuf};
fn next(s: &mut u64) -> u32 {
    *s = s
        .wrapping_mul(6364136223846793005)
        .wrapping_add(1442695040888963407);
    (*s >> 32) as u32
}
fn main() {
    let out = PathBuf::from(std::env::args().nth(1).unwrap());
    fs::create_dir_all(&out).unwrap();
    let mut random = 0x123456789abcdefu64;
    let mut accepted = 0;
    for case in 0..1200 {
        let mut ops = Vec::new();
        let loans = case % 3 == 0;
        let params = if loans {
            vec![Ty::Num, Ty::View(Mode::Read, 0), Ty::View(Mode::Write, 1)]
        } else {
            vec![Ty::Num; 4]
        };
        if loans {
            ops.push(Op::Bytes { dst: 8 });
            for r in 3..8 {
                ops.push(Op::Num(r, 0));
            }
        }
        for step in 0..16 {
            let raw_a = next(&mut random) % 8;
            let raw_b = next(&mut random) % 8;
            let raw_c = next(&mut random) % 8;
            let a = if loans { 3 + raw_a % 5 } else { raw_a };
            let b = if loans {
                if raw_b % 6 == 0 { 0 } else { 3 + raw_b % 5 }
            } else {
                raw_b
            };
            let c = if loans {
                if raw_c % 6 == 0 { 0 } else { 3 + raw_c % 5 }
            } else {
                raw_c
            };
            let v = next(&mut random);
            let op = match v % 10 {
                0 | 1 => Op::Num(a, u64::from(v)),
                2 => Op::Move { dst: a, src: b },
                3 => Op::Binary {
                    dst: a,
                    op: Bin::Add,
                    left: b,
                    right: c,
                },
                4 => Op::If {
                    condition: 0,
                    yes: vec![Op::Num(a, 1)],
                    no: vec![],
                },
                5 => Op::If {
                    condition: 0,
                    yes: vec![Op::Num(a, 1)],
                    no: vec![Op::Num(a, 2)],
                },
                6 => Op::Block {
                    body: vec![Op::Num(a, 1)],
                },
                7 => Op::End(a),
                8 if loans => Op::Block {
                    body: vec![
                        Op::Borrow {
                            dst: 16 + step,
                            src: [1, 2, 8][v as usize % 3],
                            mode: if v & 1 == 0 { Mode::Read } else { Mode::Write },
                        },
                        Op::Len {
                            dst: a,
                            src: 16 + step,
                        },
                        Op::End(16 + step),
                    ],
                },
                8 => Op::Loop {
                    index: if v & 16 == 0 { 100 + step } else { a },
                    end: 0,
                    body: vec![Op::Num(a, 1)],
                },
                _ if loans => Op::Len {
                    dst: a,
                    src: [1, 2, 8][v as usize % 3],
                },
                _ => Op::While {
                    condition: 200 + step,
                    test: vec![Op::Num(200 + step, 0)],
                    body: vec![Op::Num(a, 1)],
                },
            };
            ops.push(op);
        }
        if loans {
            ops.push(Op::End(8));
        }
        let f = Function {
            sig: Sig {
                name: "f".into(),
                params,
                result: Ty::Num,
            },
            ops,
            result: Some(0),
        };
        let value = check(f, Default::default());
        match value {
            Ok(p) => {
                accepted += 1;
                fs::write(out.join(format!("{case}.c")), grail_seed::emit::c(&p)).unwrap();
                println!("{case} accept");
            }
            Err(_) => println!("{case} reject"),
        }
    }
    eprintln!("{accepted} accepted raw / 1200");
    let mut accepted = 0;
    for case in 0..400 {
        let hold = case % 5 == 0;
        let mut text =
            "module p;enum R{Ok(num),Err(string)}pub fn run(n:num)->R{let b=bytes();push(b,1);"
                .to_string();
        if hold {
            text.push_str("let held=read(b);");
        }
        for _ in 0..8 {
            let value = next(&mut random);
            text.push_str(match value % 8 {
                0 => "let temp=n+1;let copied=temp;",
                1 => "let view=read(b);let size=len(view);",
                2 => "let view=read(b);push(b,2);assert(len(view)==1);",
                3 => "let view=mut(b);write(view,0,3);",
                4 => "let scalar=R::Ok(n)?;",
                5 => "while 0{let copy=copy_bytes(b);}",
                6 => "if n{return R::Err(\"bad\");}",
                _ => "{let name=\"x\";assert(len(name)==1);}",
            });
        }
        text.push_str(if hold {
            "return R::Ok(len(held));}"
        } else {
            "return R::Ok(len(b));}"
        });
        match grail_seed::source::compile(&text, Default::default()) {
            Ok(p) => {
                accepted += 1;
                fs::write(
                    out.join(format!("source-{case}.c")),
                    grail_seed::emit::module_c(&p),
                )
                .unwrap();
                fs::write(out.join(format!("source-{case}.api")), p.interface()).unwrap();
                println!("source-{case} accept");
            }
            Err(_) => println!("source-{case} reject"),
        }
    }
    eprintln!("{accepted} accepted source / 400");
}
