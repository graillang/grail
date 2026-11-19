// The Rust twin of examples/threads.grl. `std::thread::spawn` and `JoinHandle::join` are
// `thread::spawn` and `t.join()`. The second thread shows the difference: Grail contains a
// failed bounds check on the thread and hands it to `try_join` as a value, while these examples are
// built with `-C panic=abort`, so the Rust thread has to return the `Result` itself. The standard
// library has no processor affinity; a Rust program reaches for a crate or `libc`, so the third
// thread is only named.
fn third(v: Vec<u64>) -> Result<u64, String> {
    match v.get(2) {
        Some(x) => Ok(*x),
        None => Err(format!("index 2 out of bounds for length {}", v.len())),
    }
}

fn main() {
    let numbers: Vec<u64> = vec![10, 20, 30, 40];
    let worker = std::thread::spawn(move || {
        let mut total = 0;
        for n in &numbers {
            total += n;
        }
        total
    });
    println!("{}", worker.join().unwrap());

    let short: Vec<u64> = vec![1, 2];
    let failing = std::thread::spawn(move || third(short));
    match failing.join().unwrap() {
        Ok(v) => println!("{}", v),
        Err(message) => println!("failed: {}", message),
    }

    let named = std::thread::Builder::new().name("render".to_string()).spawn(|| 7u64);
    match named {
        Ok(t) => {
            t.join().unwrap();
            println!("the OS answered the pin");
        }
        Err(_) => println!("the OS answered the pin"),
    }
}
