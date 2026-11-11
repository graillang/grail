// The Rust twin of examples/ffi-uninitialised-record.grl. Rust refuses the read for the same
// reason and with the same shape of error: a binding that nothing has written has no value to
// read. Rust's error is E0381 ("used binding isn't initialized"); Grail's is the same rule stated
// as a partially initialized value, because its storage exists and is zeroed but holds no value.
#[repr(C)]
struct Caps {
    width: u32,
    height: u32,
}

fn main() {
    let caps: Caps;
    println!("{}", caps.width);
}
