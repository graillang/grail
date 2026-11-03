//! Compile/lower only: retained capture cardinality across independently written loop bodies.
use std::{fs, path::PathBuf, time::Instant};
fn main() {
    let out = PathBuf::from(std::env::args().nth(1).unwrap());
    fs::create_dir_all(&out).unwrap();
    for fields in [1, 8, 32, 64] {
        for count in [16, 64, 256] {
            let mut s = "module cost;struct Cursor<a>{".to_owned();
            for i in 0..fields {
                s.push_str(&format!("p{i}:read<a>,"));
            }
            s.push_str("}fn update<outer,data>(p:ref_mut<outer,Cursor<data>>,value:read<data>)->num{exchange(borrow_mut(p.p0),value);return (&p.p0).len();}pub fn run(n:num)->num{");
            for i in 0..fields {
                s.push_str(&format!("let b{i}=bytes[];(b{i}).push({i});"));
            }
            s.push_str("let cursor=Cursor{");
            for i in 0..fields {
                s.push_str(&format!("p{i}:&(b{i}),"));
            }
            s.push_str("};mut sum=0;");
            for i in 0..count {
                s.push_str(&format!("for i{i} in n{{sum=sum+update(borrow_mut(cursor),&b0);}}"));
            }
            s.push_str("return sum;}");
            let t = Instant::now();
            let p = grail_seed::source::compile(&s, Default::default()).unwrap();
            let check = t.elapsed().as_secs_f64();
            let t = Instant::now();
            let c = grail_seed::emit::module_c(&p).unwrap();
            let emit = t.elapsed().as_secs_f64();
            fs::write(out.join(format!("capture-{fields}-{count}.c")), &c).unwrap();
            println!(
                "capture{fields} {count} {} {} {check:.9} {emit:.9}",
                s.len(),
                c.len()
            );
        }
    }
}
