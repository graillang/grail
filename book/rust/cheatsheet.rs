use std::rc::Rc;

trait Shape {
    fn area(&self) -> u64;
}

struct Rect {
    w: u64,
    h: u64,
}

impl Shape for Rect {
    fn area(&self) -> u64 {
        self.w * self.h
    }
}

enum Token {
    Num(u64),
    #[allow(dead_code)]
    Plus,
}

struct Guard {
    name: String,
}

impl Drop for Guard {
    fn drop(&mut self) {
        println!("drop {}", self.name);
    }
}

fn largest<T: Shape>(items: &[T]) -> u64 {
    let mut best = 0;
    for item in items {
        let a = item.area();
        if a > best {
            best = a;
        }
    }
    best
}

// Rust has no refinement types: the divisor's invariant is a runtime assertion.
fn divmod(a: u64, b: u64) -> (u64, u64) {
    assert!(b != 0);
    (a / b, a % b)
}

fn first_even(v: &[u64]) -> Option<u64> {
    v.iter().copied().find(|n| n % 2 == 0)
}

fn main() {
    let x = 5;
    let mut total = 0;
    total += x;
    let rects = vec![Rect { w: 2, h: 3 }, Rect { w: 4, h: 1 }];
    println!("largest {}", largest(&rects));
    let t = Token::Num(7);
    match t {
        Token::Num(n) => println!("num {}", n),
        Token::Plus => println!("plus"),
    }
    let (q, r) = divmod(17, 5);
    println!("{} {}", q, r);
    let v = vec![3u64, 5, 8, 9];
    match first_even(&v) {
        Some(e) => println!("even {}", e),
        None => println!("none"),
    }
    let big: Vec<u64> = v.into_iter().filter(|n| *n > 4).collect();
    println!("{} big, total {}", big.len(), total);
    let shared = Rc::new(Guard {
        name: "g".to_string(),
    });
    let other = Rc::clone(&shared);
    println!("count {}", Rc::strong_count(&other));
}
