fn bad() -> const u8[:] {
    var source: u8[>..] = [];
    source.append("temporary");
    return source[..];
}
fn main() { print(bad()); }
