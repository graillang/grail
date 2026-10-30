fn bad<'a, 'b>(r: Result<u64, &'a [u8]>, _p: &'b [u8]) -> Result<String, &'b [u8]> {
    let n = r?;
    Ok(n.to_string())
}
fn main() {}
