use std::{fs, io::{self, Write}};

fn main() {
    let contents = fs::read("note.txt").expect("read note.txt");
    fs::write("copy.txt", &contents).expect("write copy.txt");
    io::stdout().write_all(&contents).expect("write stdout");
    println!("{}", contents.len());
}
