use std::collections::BTreeMap;

fn main() {
    let mut counts: BTreeMap<&str, u64> = BTreeMap::new();
    counts.insert("cat", 1);
    counts.insert("dog", 2);
    counts.insert("emu", 3);
    for (key, value) in &counts {
        println!("{key} {value}");
    }
    for (_key, value) in &mut counts {
        *value *= 10;
    }
    for (key, value) in &counts {
        println!("{key} {value}");
    }
    println!("{}", counts.len());
}
