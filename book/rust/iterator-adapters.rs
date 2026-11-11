fn main() {
    let squares: Vec<u64> = (1..6u64).map(|x| x * x).collect();
    println!("{}", squares.len());
    let mut evens = 0;
    for e in (0..10u64).filter(|x| *x % 2 == 0) {
        evens += e;
    }
    println!("{}", evens);
    for (i, v) in (100..1000u64).take(3).enumerate() {
        println!("{}: {}", i, v);
    }
    for (a, b) in (1..4u64).zip(squares.into_iter()) {
        println!("{} squared is {}", a, b);
    }
}
