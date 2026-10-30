fn bad(r: Result<u64, String>) -> Result<u64, u64> {
    let n = r?;
    Ok(n)
}
fn main() {}
