//! Compile/lower only; generated instance-count workload is not executed here.
use std::{fs, path::PathBuf, time::Instant};
fn main() {
    let out = PathBuf::from(std::env::args().nth(1).unwrap());
    fs::create_dir_all(&out).unwrap();
    for style in ["concrete", "generic", "repeat"] {
        for count in [0, 16, 64, 256] {
            let mut s = "module cost;".to_owned();
            for i in 0..count {
                s.push_str(&format!("struct P{i}{{value:num}}"));
            }
            if style != "concrete" {
                s.push_str("fn id<type T>(value:T)->T{return value;}");
            } else {
                for i in 0..count {
                    s.push_str(&format!("fn id{i}(value:P{i})->P{i}{{return value;}}"));
                }
            }
            s.push_str("pub fn run()->num{var sum=0;");
            for i in 0..count {
                let ty = if style == "repeat" { 0 } else { i };
                let call = if style == "concrete" {
                    format!("id{i}")
                } else {
                    "id".into()
                };
                s.push_str(&format!(
                    "{{let x={call}(P{ty}{{value:{i}}});sum=sum+x.value;}}"
                ));
            }
            s.push_str("return sum;}");
            let t = Instant::now();
            let p = grail_seed::source::compile(&s, Default::default()).unwrap();
            let check = t.elapsed().as_secs_f64();
            let t = Instant::now();
            let c = grail_seed::emit::module_c(&p).unwrap();
            let emit = t.elapsed().as_secs_f64();
            let ir = p.template_ir().unwrap();
            let t = Instant::now();
            if !ir.is_empty() {
                grail_seed::template::Bundle::decode(&ir).unwrap();
            }
            let decode = t.elapsed().as_secs_f64();
            let instances = c
                .lines()
                .filter(|s| {
                    s.starts_with("static ") && s.contains("g__generic_") && s.ends_with('{')
                })
                .count();
            fs::write(out.join(format!("{style}-{count}.c")), &c).unwrap();
            println!(
                "{style} {count} {} {} {} {} {instances} {check:.9} {emit:.9} {decode:.9}",
                s.len(),
                c.len(),
                p.interface().len(),
                ir.len()
            );
        }
    }
}
