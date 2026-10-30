use std::{collections::BTreeMap, time::Instant};
fn main() {
    for n in [250, 1000, 4000] {
        let mut source = String::from("fn entry()->num{return f0();}");
        for i in 0..n {
            source.push_str(&format!(
                "fn f{i}()->num{{return {};}}",
                if i + 1 == n {
                    "0".into()
                } else {
                    format!("f{}()+1", i + 1)
                }
            ));
        }
        let mut times = vec![];
        for _ in 0..5 {
            let start = Instant::now();
            let p = grail_seed::source::compile(std::hint::black_box(&source), BTreeMap::new())
                .unwrap();
            std::hint::black_box(p);
            times.push(start.elapsed().as_secs_f64());
        }
        times.sort_by(f64::total_cmp);
        println!("{n} {} {}", source.len(), times[2]);
    }
}
