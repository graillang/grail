fn bad<'a>(p: &'a [u8]) -> Result<&'a [u8], &'a [u8]> {
    let local = vec![1];
    if p.len() == 1 {
        return Err(&local);
    }
    Ok(p)
}
fn main() {}
