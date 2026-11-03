use std::process::Command;

fn main() {
    let status = Command::new("/bin/true")
        .status()
        .expect("could not execute /bin/true");
    println!("{}", status.code().expect("command terminated by signal"));
}
