use std::{collections::BTreeMap, time::Instant};
fn main() {
    for n in [250, 1000, 4000] {
        let mut source = String::from("module layouts;");
        for i in 0..n {
            source.push_str(&format!(
                "struct T{i}<a>{{span:read<a>,name:string,offset:num}}"
            ));
        }
        for i in 0..n {
            source.push_str(&format!(
                "pub fn f{i}<a>(t:T{i}<a>)->read<a>{{return t.span;}}"
            ));
        }
        let mut times = vec![];
        let mut codec = vec![];
        let mut bytes = 0;
        for _ in 0..5 {
            let t = Instant::now();
            let p = grail_seed::source::compile(&source, BTreeMap::new()).unwrap();
            times.push(t.elapsed().as_secs_f64());
            let t = Instant::now();
            let text = p.interface();
            bytes = text.len();
            let h = grail_seed::module::Interface::decode(&text).unwrap();
            std::hint::black_box(h.fingerprint().unwrap());
            codec.push(t.elapsed().as_secs_f64());
        }
        times.sort_by(f64::total_cmp);
        codec.sort_by(f64::total_cmp);
        println!("{n} {bytes} {} {}", times[2], codec[2]);
    }
}
