use std::{fs, path::PathBuf, time::Instant};
fn main() {
    let out = PathBuf::from(std::env::args().nth(1).unwrap());
    fs::create_dir_all(&out).unwrap();
    for kind in ["branch", "propagate"] {
        for count in [32, 128, 512, 1000] {
            let mut source = if kind == "branch" {
                "fn f(n:num)->num{".to_string()
            } else {
                "module f;enum R{Ok(num),Err(string)}pub fn run(r:R)->R{let first=r?;".into()
            };
            for i in 0..count {
                if kind == "branch" {
                    source.push_str(&format!("if n=={i}{{return {i};}}"));
                } else {
                    source.push_str(&format!("let n{i}=R::Ok({i})?;"));
                }
            }
            source.push_str(if kind == "branch" {
                "return 10000;}"
            } else {
                "return R::Ok(first);}"
            });
            let t = Instant::now();
            let p = grail_seed::source::compile(&source, Default::default()).unwrap();
            let check = t.elapsed().as_secs_f64();
            let t = Instant::now();
            let c = grail_seed::emit::module_c(&p);
            let emit = t.elapsed().as_secs_f64();
            fs::write(out.join(format!("{kind}-{count}.c")), &c).unwrap();
            fs::write(out.join(format!("{kind}-{count}.api")), p.interface()).unwrap();
            println!(
                "{kind} {count} {} {} {check:.9} {emit:.9}",
                source.len(),
                c.len()
            );
        }
    }
}
