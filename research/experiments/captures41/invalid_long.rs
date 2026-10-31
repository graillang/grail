struct Unique<'data> {
    source: &'data mut [u8],
}
fn wrong<'outer, 'data>(cursor: &'outer Unique<'data>) -> &'data [u8] {
    cursor.source
}
fn main() {}
