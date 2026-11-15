struct Task {
    name: String,
    priority: u64,
    minutes: u64,
}
fn main() {
    let mut tasks = vec![
        Task {
            name: "write tests".to_string(),
            priority: 2,
            minutes: 30,
        },
        Task {
            name: "fix crash".to_string(),
            priority: 3,
            minutes: 45,
        },
        Task {
            name: "update docs".to_string(),
            priority: 1,
            minutes: 20,
        },
        Task {
            name: "review patch".to_string(),
            priority: 2,
            minutes: 15,
        },
    ];
    // Highest priority first; equal priorities keep their order (the sort is stable).
    tasks.sort_by(|a, b| b.priority.cmp(&a.priority));
    let budget = 90;
    let mut used = 0;
    for task in &tasks {
        if used + task.minutes <= budget {
            used += task.minutes;
            println!("{} ({} min)", task.name, task.minutes);
        }
    }
    println!("{} of {} minutes planned", used, budget);
}
