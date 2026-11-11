// The Rust twin of examples/ffi-handle-array.grl, linking the same C fixture. Rust has no `handle`
// type, so a command buffer is a plain word; `MaybeUninit` is how Rust spells "storage C will
// write", and `assume_init` is the point at which the bytes become a value - the same rule Grail
// states as "zeroed bytes are not an initialised handle".
#[repr(C)]
struct CommandBuffers {
    b0: u64,
    b1: u64,
    b2: u64,
    b3: u64,
}

unsafe extern "C" {
    fn c_alloc_buffers(out: *mut CommandBuffers) -> i64;
    fn c_sum_buffers(buffers: *const CommandBuffers) -> i64;
    fn c_first(buffers: *const CommandBuffers) -> u64;
}

fn main() {
    let mut storage = std::mem::MaybeUninit::<CommandBuffers>::uninit();
    let count = unsafe { c_alloc_buffers(storage.as_mut_ptr()) };
    println!("{count}");

    let buffers = unsafe { storage.assume_init() };
    println!("{}", unsafe { c_sum_buffers(&buffers) });

    let seeded = CommandBuffers {
        b0: buffers.b0,
        b1: buffers.b0,
        b2: buffers.b0,
        b3: buffers.b3,
    };
    println!("{}", unsafe { c_sum_buffers(&seeded) });

    let back = unsafe { c_first(&buffers) };
    println!("{}", u64::from(buffers.b0 == back));
}
