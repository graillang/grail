use std::cell::RefCell;
struct Token<'a> {
    span: &'a str,
    name: String,
    value: u64,
}
fn parse(p: &str) -> Result<Token<'_>, String> {
    if p.is_empty() {
        return Err("empty".into());
    }
    if !p.bytes().all(|b| b.is_ascii_digit()) {
        return Err("invalid".into());
    }
    let value = p.parse::<u64>().map_err(|_| "overflow".to_owned())?;
    Ok(Token {
        span: p,
        name: "num".into(),
        value,
    })
}
struct Owner<'a> {
    id: u64,
    trace: &'a RefCell<Vec<u64>>,
}
impl Drop for Owner<'_> {
    fn drop(&mut self) {
        self.trace.borrow_mut().push(self.id);
    }
}
struct Pair<T, U> {
    first: T,
    second: U,
}
fn failure<'a>(trace: &'a RefCell<Vec<u64>>) -> Result<u64, Owner<'a>> {
    let _scratch = Owner { id: 3, trace };
    let value: Result<u64, Owner<'a>> = Err(Owner { id: 4, trace });
    let n = value?;
    Ok(n)
}
fn main() {
    for p in [
        "",
        "0",
        "42",
        "00042",
        "18446744073709551615",
        "18446744073709551616",
        "bad",
    ] {
        let n = match parse(p) {
            Ok(t) => t.value.wrapping_add((t.name.len() + t.span.len()) as u64),
            Err(e) => e.len() as u64,
        };
        println!("{n}");
    }
    let trace = RefCell::new(Vec::new());
    {
        let source = Owner {
            id: 1,
            trace: &trace,
        };
        let one: Result<Pair<Owner<'_>, Owner<'_>>, Owner<'_>> = Ok(Pair {
            first: Owner {
                id: 2,
                trace: &trace,
            },
            second: Owner {
                id: 3,
                trace: &trace,
            },
        });
        let two: Option<Result<Owner<'_>, Owner<'_>>> = Some(Err(Owner {
            id: 4,
            trace: &trace,
        }));
        let pair = match one {
            Ok(p) => p,
            Err(_) => panic!(),
        };
        let first = pair.first;
        drop(pair.second);
        match two.unwrap() {
            Ok(v) => drop(v),
            Err(e) => drop(e),
        }
        drop(first);
        drop(source);
    }
    assert_eq!(*trace.borrow(), [3, 4, 2, 1]);
    println!("3 4 2 1");
    trace.borrow_mut().clear();
    {
        let _source = Owner {
            id: 1,
            trace: &trace,
        };
        let keep = Owner {
            id: 2,
            trace: &trace,
        };
        drop(failure(&trace));
        drop(keep);
    }
    assert_eq!(*trace.borrow(), [3, 4, 2, 1]);
    println!("3 4 2 1");
}
