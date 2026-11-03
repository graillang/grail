//! Compile/lower only; counted-loop corpus is not run here.
use std::{fs, path::PathBuf, time::Instant};
fn main() {
    let out = PathBuf::from(std::env::args().nth(1).unwrap());
    fs::create_dir_all(&out).unwrap();
    for count in [32, 128, 512, 1000] {
        let mut s="module cost;fn set<a>(p:ref_mut<a,num>,v:num)->unit{exchange(p,v);return ();}pub fn run(n:num)->num{mut x=0;".to_owned();
        for i in 0..count {
            s.push_str(&format!("for i{i} in n{{set(borrow_mut(x),i{i});}}"));
        }
        s.push_str("return x;}");
        let t = Instant::now();
        let p = grail_seed::source::compile(&s, Default::default()).unwrap();
        let check = t.elapsed().as_secs_f64();
        let t = Instant::now();
        let c = grail_seed::emit::module_c(&p).unwrap();
        let emit = t.elapsed().as_secs_f64();
        fs::write(out.join(format!("refs-{count}.c")), &c).unwrap();
        println!("refs {count} {} {} {check:.9} {emit:.9}", s.len(), c.len());
    }
}
