use std::{fs, path::PathBuf, time::Instant};
fn main() {
    let dir = PathBuf::from(std::env::args().nth(1).unwrap());
    fs::create_dir_all(&dir).unwrap();
    let generic = std::env::args().nth(2).unwrap() == "generic";
    for count in [8, 32, 128, 256] {
        let mut s = "module bench;".to_string();
        if generic {
            s.push_str("enum Result<type T,type E>{Ok(T),Err(E)}");
        }
        for i in 0..count {
            s.push_str(&format!(
                "struct Item{i}<a>{{span:read<a>,name:string,value:num}}"
            ));
            if !generic {
                s.push_str(&format!("enum Result{i}<a>{{Ok(Item{i}<a>),Err(string)}}"));
            }
        }
        for i in 0..count {
            let ty = if generic {
                format!("Result<Item{i}<a>,string>")
            } else {
                format!("Result{i}<a>")
            };
            let ctor = if generic {
                "Result".into()
            } else {
                format!("Result{i}")
            };
            s.push_str(&format!("pub fn make{i}<a>(p:read<a>)->{ty}{{return {ctor}::Ok(Item{i}{{span:p,name:\"owned\",value:{i}}});}}"));
        }
        let t = Instant::now();
        let p = grail_seed::source::compile(&s, Default::default()).unwrap();
        let check = t.elapsed().as_secs_f64();
        let t = Instant::now();
        let c = grail_seed::emit::module_c(&p);
        let emit = t.elapsed().as_secs_f64();
        let t = Instant::now();
        let api = p.interface();
        let _ = p.header().fingerprint().unwrap();
        let interface = t.elapsed().as_secs_f64();
        fs::write(dir.join(format!("{count}.grl")), &s).unwrap();
        fs::write(dir.join(format!("{count}.c")), &c).unwrap();
        fs::write(dir.join(format!("{count}.api")), &api).unwrap();
        println!(
            "{count} {} {} {} {check:.9} {emit:.9} {interface:.9}",
            s.len(),
            c.len(),
            api.len()
        );
    }
}
