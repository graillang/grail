//! Compile/lower only. Generated control-flow workloads are not executed.
use std::{fs, path::PathBuf, time::Instant};
fn main() {
    let out = PathBuf::from(std::env::args().nth(1).unwrap());
    let exits = std::env::args().nth(2).unwrap() == "exits";
    fs::create_dir_all(&out).unwrap();
    for kind in if exits {
        vec!["break", "continue"]
    } else {
        vec!["counted", "while"]
    } {
        for count in [32, 128, 512, 1000] {
            let mut s = "fn f(n:num)->num{mut sum=0;".to_string();
            for i in 0..count {
                s.push_str(&match kind {
                    "counted" => format!("for i{i} in n{{sum=sum+i{i};}}"),
                    "while" => "{mut i=0;while i<n{sum=sum+i;i=i+1;}}".into(),
                    "break" => format!("for i{i} in n{{let local=\"x\";if n{{break;}}continue;}}"),
                    "continue" => {
                        format!("for i{i} in n{{let local=\"x\";if i{i}{{continue;}}break;}}")
                    }
                    _ => unreachable!(),
                });
            }
            s.push_str("return sum;}");
            let t = Instant::now();
            let p = grail_seed::source::compile(&s, Default::default()).unwrap();
            let check = t.elapsed().as_secs_f64();
            let t = Instant::now();
            let c = grail_seed::emit::module_c(&p);
            let emit = t.elapsed().as_secs_f64();
            fs::write(out.join(format!("{kind}-{count}.c")), &c).unwrap();
            fs::write(out.join(format!("{kind}-{count}.api")), p.interface()).unwrap();
            println!(
                "{kind} {count} {} {} {check:.9} {emit:.9}",
                s.len(),
                c.len()
            );
        }
    }
}
