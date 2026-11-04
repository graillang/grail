#[allow(dead_code)]
enum Slot {
    Empty,
    Full(u64),
}

fn main() {
    let mut slot = Slot::Full(41);
    match &slot {
        Slot::Full(n) => {
            let next = n + 1;
            slot = Slot::Full(next);
            println!("{}", next);
        }
        Slot::Empty => {
            println!("0");
        }
    }
    let _ = slot;
}
