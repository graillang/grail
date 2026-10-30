fn wrong<'short, 'long>(slot: &'short mut &'long mut i32) -> &'long mut i32 {
    &mut **slot
}
fn main() {}
