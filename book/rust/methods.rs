struct Counter {
    name: String,
    count: u32,
}
impl Counter {
    fn new(name: String) -> Counter {
        Counter { name, count: 0 }
    }
    fn add(&mut self, amount: u32) {
        self.count += amount;
    }
    fn report(&self) -> String {
        format!("{} = {}", self.name, self.count)
    }
}
fn main() {
    let mut visits = Counter::new(String::from("visits"));
    for day in 1..4 {
        visits.add(day);
    }
    println!("{}", visits.report());
    if visits.count > 5 {
        println!("busy week");
    } else if visits.count > 0 {
        println!("quiet week");
    }
}
