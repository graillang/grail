use std::{collections::BTreeMap, time::Instant};
fn main() {
    for n in [250, 1000, 4000] {
        let mut source = String::from("module cost;");
        for i in 0..n {
            source.push_str(&format!("pub fn f{i}(n:num)->num{{return n+1;}}"));
        }
        let mut checks = vec![];
        let mut codecs = vec![];
        let mut size = 0;
        for _ in 0..5 {
            let t = Instant::now();
            let m = grail_seed::source::compile(&source, BTreeMap::new()).unwrap();
            checks.push(t.elapsed().as_secs_f64());
            let t = Instant::now();
            let text = m.interface();
            size = text.len();
            let h = grail_seed::module::Interface::decode(&text).unwrap();
            std::hint::black_box(h.fingerprint().unwrap());
            codecs.push(t.elapsed().as_secs_f64());
        }
        checks.sort_by(f64::total_cmp);
        codecs.sort_by(f64::total_cmp);
        println!("{n} {size} {} {}", checks[2], codecs[2]);
    }
}
