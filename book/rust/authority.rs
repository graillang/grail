use std::fs::{self, File};
use std::io::Write;

fn main() {
    // Rust's std has no capability value: the same rule is written by hand here.
    let root = std::env::current_dir().unwrap();
    let data = fs::read(root.join("note.txt")).unwrap();
    println!("{}", data.len());
    // Containment by canonicalised components, not by a string prefix.
    let escape = root.join("../outside.txt");
    let denied = match escape.canonicalize() {
        Ok(path) => {
            if path.starts_with(&root) {
                0
            } else {
                1
            }
        }
        Err(_) => 1,
    };
    println!("{}", denied);
    // The only "grant" std offers is the handle: a read-only file refuses the write.
    let mut note = File::open(root.join("note.txt")).unwrap();
    let refused = match note.write_all(b"x") {
        Ok(()) => 0,
        Err(_) => 1,
    };
    println!("{}", refused);
}
