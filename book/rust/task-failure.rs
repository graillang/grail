fn work(n: u64, base: u64) -> u64 {
    n + base
}

fn failing(_n: u64) -> Result<u64, String> {
    Err("bad input".to_string())
}

fn main() {
    match failing(0) {
        Ok(v) => println!("{v}"),
        Err(message) => println!("{message}"),
    }
    println!("{}", work(5, 2));
}
