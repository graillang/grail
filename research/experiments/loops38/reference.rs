use std::cell::{Cell, RefCell};
struct Trace<'a> {
    id: u64,
    log: &'a RefCell<Vec<u64>>,
}
impl Drop for Trace<'_> {
    fn drop(&mut self) {
        self.log.borrow_mut().push(self.id);
    }
}
struct Pair<T> {
    a: T,
    b: T,
}
fn counted(n: u64) -> u64 {
    let mut sum = 0;
    for i in 0..n {
        if i == 2 {
            continue;
        }
        if i == 5 {
            break;
        }
        sum += i;
    }
    sum
}
fn repeated(n: u64) -> u64 {
    let (mut i, mut sum) = (0, 0);
    while i < n {
        i += 1;
        if i == 2 {
            continue;
        }
        if i == 5 {
            break;
        }
        sum += i;
    }
    sum
}
fn nested(n: u64) -> u64 {
    let mut sum = 0;
    for outer in 0..n {
        for inner in 0..4 {
            if inner == 1 {
                continue;
            }
            if outer == 2 {
                break;
            }
            sum += outer * 10 + inner;
        }
        if outer == 3 {
            break;
        }
    }
    sum
}
fn main() {
    for n in 0..12 {
        println!("{}", counted(n) + 64 * repeated(n) + 4096 * nested(n));
    }
    let log = RefCell::new(Vec::new());
    let serial = Cell::new(0);
    let make = || {
        let id = serial.get() + 1;
        serial.set(id);
        Trace { id, log: &log }
    };
    {
        let _source = make();
        let mut i = 0;
        while {
            let _condition = make();
            true
        } {
            let pair = Pair {
                a: make(),
                b: make(),
            };
            assert!(pair.b.id > 0);
            let first = pair.a;
            let r = &first;
            assert!(r.id > 0);
            i += 1;
            assert!(i < 4);
            if i == 1 {
                continue;
            }
            break;
        }
    }
    assert_eq!(*log.borrow(), [2, 3, 4, 5, 6, 7, 1]);
    println!("2 3 4 5 6 7 1");
    log.borrow_mut().clear();
    serial.set(0);
    enum Signal<T> {
        Next(T),
        Stop(T),
    }
    {
        let _source = make();
        for i in 0..6 {
            let _before = make();
            let event = if i == 0 {
                Signal::Next(make())
            } else {
                Signal::Stop(make())
            };
            match event {
                Signal::Next(_value) => continue,
                Signal::Stop(_reason) => break,
            }
        }
    }
    assert_eq!(*log.borrow(), [3, 2, 5, 4, 1]);
    println!("3 2 5 4 1");
    // This safe program deliberately exceeds the current Grail loop-entry ownership invariant.
    let owner = String::from("owned");
    for i in 0..3 {
        if i == 0 {
            drop(owner);
            break;
        }
    }
    println!("outer-move Rust accepts; Grail currently rejects");
}
