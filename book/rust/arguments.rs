use std::os::unix::ffi::OsStrExt;

fn main() {
    let mut arguments = std::env::args_os().skip(1);
    let Some(argument) = arguments.next() else {
        std::process::exit(2);
    };
    if arguments.next().is_some() {
        std::process::exit(2);
    }
    println!("{}", argument.as_os_str().as_bytes().len());
}
