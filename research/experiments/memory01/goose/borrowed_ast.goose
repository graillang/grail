struct Token { text: const u8[:] }
fn tokenize(source: const u8[:]) -> Token[>..] {
    var out: Token[>..] = [];
    var start: i64 = 0;
    for i in 0..source.len {
        if source[i] == 32 {
            out.push(Token { text: source[start..i] });
            start = i + 1;
        }
    }
    if start < source.len { out.push(Token { text: source[start..] }); }
    return out;
}
fn main() {
    var source: u8[>..] = [];
    source.append("alpha beta gamma");
    let ast = tokenize(source[..]);
    assert(ast.len == 3);
    assert(ast[1].text == "beta");
    print(ast[1].text);
}
