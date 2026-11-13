fn main() {
    let text = "aé€👋";
    println!("{} bytes, {} characters", text.len(), text.chars().count());
    for (at, c) in text.char_indices() {
        println!("{} {}", at, c as u32);
    }
    let mut back = Vec::new();
    for c in text.chars() {
        let mut buffer = [0u8; 4];
        back.extend_from_slice(c.encode_utf8(&mut buffer).as_bytes());
    }
    println!("round trip: {}", std::str::from_utf8(&back).is_ok());
    let bad: &[u8] = &[104, 226, 130, 65, 255];
    println!("valid: {}", std::str::from_utf8(bad).is_ok());
    match std::str::from_utf8(bad) {
        Err(e) => println!("first bad byte: {}", e.valid_up_to()),
        Ok(_) => println!("valid"),
    }
    let lossy: String = String::from_utf8_lossy(bad).into();
    println!("{}", lossy);
    println!("{} {}", text.is_char_boundary(3), text.is_char_boundary(4));
}
