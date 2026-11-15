use std::mem::size_of;

const PAGE: u64 = 4 * 1024;
const MASK: u64 = PAGE - 1;
const VERBOSE: bool = false;

#[repr(C)]
struct Header {
    magic: u32,
    flags: u16,
    kind: u8,
    pad: u8,
    size: u64,
}
const _: () = assert!(
    size_of::<Header>() == 16,
    "Header is read from disk as 16 bytes"
);

#[cfg(target_os = "windows")]
fn separator() -> &'static str {
    "\\"
}
#[cfg(not(target_os = "windows"))]
fn separator() -> &'static str {
    "/"
}

fn round_up(n: u64) -> u64 {
    (n + MASK) & !MASK
}

fn main() {
    const _: () = assert!(PAGE & MASK == 0, "PAGE must be a power of two");
    println!("{}", round_up(5000));
    println!("path{}to", separator());
    if VERBOSE {
        println!("verbose build");
    }
    println!("{}", size_of::<u32>() + size_of::<Header>());
}
