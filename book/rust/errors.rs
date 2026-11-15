fn make(flag: bool) -> Result<Vec<u8>, String> {
    if flag {
        Err(String::from("missing"))
    } else {
        Ok(Vec::new())
    }
}
fn forward(flag: bool) -> Result<Vec<u8>, String> {
    let value = make(flag)?;
    Ok(value)
}
fn main() {
    let ok = forward(false).unwrap();
    assert_eq!(ok.len(), 0);
    match forward(true) {
        Ok(data) => println!("{}", data.len()),
        Err(message) => println!("{}", message.len()),
    }
}
