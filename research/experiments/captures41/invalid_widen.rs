struct Cursor<'data> {
    source: &'data [u8],
}
fn wrong<'outer, 'short, 'long>(
    cursor: &'outer Cursor<'short>,
    _anchor: &'long [u8],
) -> &'outer Cursor<'long> {
    cursor
}
fn main() {}
