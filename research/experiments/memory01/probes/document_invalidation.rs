fn main() { let mut document=view_api::Document::parse(String::from("alpha beta")); let text=document.texts().next().unwrap(); document.replace(String::from("other")); println!("{text}"); }
