// Rust's Iterator trait: `next(&mut self) -> Option<Item>`, consumed by `for`.
struct Countdown {
    n: u64,
}
impl Iterator for Countdown {
    type Item = u64;
    fn next(&mut self) -> Option<u64> {
        if self.n == 0 {
            return None;
        }
        self.n -= 1;
        Some(self.n)
    }
}

struct Items<'a> {
    items: &'a [u64],
    pos: usize,
}
impl<'a> Iterator for Items<'a> {
    type Item = &'a u64;
    fn next(&mut self) -> Option<&'a u64> {
        let item = self.items.get(self.pos)?;
        self.pos += 1;
        Some(item)
    }
}

fn main() {
    let mut count = Countdown { n: 5 };
    for x in &mut count {
        if x == 2 {
            break;
        }
        println!("{}", x);
    }
    for x in &mut count {
        println!("then {}", x);
    }
    let prices = vec![120u64, 80, 45];
    let mut total = 0;
    for p in (Items { items: &prices, pos: 0 }) {
        total += *p;
    }
    println!("total {}", total);
}
