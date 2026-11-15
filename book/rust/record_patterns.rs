struct Order {
    id: u64,
    items: Vec<u64>,
    note: String,
}
fn items_of(order: &Order) -> u64 {
    match order {
        Order { items, .. } => items.len() as u64,
    }
}
fn restock(order: &mut Order, count: u64) {
    match order {
        Order { items, .. } => items.push(count),
    }
}
fn main() {
    let mut order = Order {
        id: 7,
        items: vec![2, 3, 5],
        note: String::from("rush"),
    };
    println!("{} items", items_of(&order));
    restock(&mut order, 7);
    match order {
        Order { id, items, note } => {
            println!("order {}: {} items, note {}", id, items.len(), note.len());
        }
    }
}
