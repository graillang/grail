struct Message { body: Vec<u8>, label: String }
fn main() {
    let body = Vec::new();
    let label = String::from("note");
    let message = Message { body, label };
    let moved = message.body;
    assert_eq!(message.label.len(), 4);
    println!("{}", moved.len() + message.label.len());
}
