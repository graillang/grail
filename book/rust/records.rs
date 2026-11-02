struct Message { body: Vec<u8>, label: String }
fn main() {
    let message = Message { body: Vec::new(), label: String::from("note") };
    let body = message.body;
    assert_eq!(message.label.len(), 4);
    println!("{}", body.len() + message.label.len());
}
