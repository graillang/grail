use grail_seed::{Sig, check, emit, fixture};
use std::{collections::BTreeMap, env, fs, path::Path, time::Instant};
fn run() -> Result<(), String> {
    let a = env::args().collect::<Vec<_>>();
    if (a.len() == 5 || a.len() == 6) && (a[1] == "compile" || a[1] == "build") {
        return grail_seed::driver::compile(
            Path::new(&a[2]),
            Path::new(&a[3]),
            Path::new(&a[4]),
            a[1] == "build",
            a.get(5).map(String::as_str).unwrap_or("clang"),
        );
    }
    if a.len() == 3 && a[1] == "scale" {
        let n: u32 = a[2].parse().map_err(|_| "scale size")?;
        if !(1..=4096).contains(&n) {
            return Err("scale size must be 1..4096".into());
        }
        for fanout in [false, true] {
            let f = fixture::scaling(n, fanout);
            let start = Instant::now();
            let _checked = check(f, BTreeMap::new())?;
            println!(
                "{{\"fanout\":{fanout},\"size\":{n},\"check_ns\":{}}}",
                start.elapsed().as_nanos()
            );
        }
        return Ok(());
    }

    if a.len() != 6 {
        return Err("usage: grail-seed compile|build FILE OUT IMPORTS [clang|clang-release|tcc] | provider OUT BIAS VERSION c|llvm | client OUT API LEN:REPEATS c|llvm | scale SIZE".into());
    }
    let start = Instant::now();
    let (f, imports) = match a[1].as_str() {
        "provider" => (
            fixture::provider(
                a[3].parse().map_err(|_| "bias")?,
                a[4].parse().map_err(|_| "version")?,
            ),
            BTreeMap::new(),
        ),
        "client" => {
            let sig = Sig::decode(&fs::read_to_string(&a[3]).map_err(|e| e.to_string())?)?;
            let (len, n) = a[4].split_once(':').ok_or("LEN:REPEATS")?;
            (
                fixture::client(
                    &sig,
                    len.parse().map_err(|_| "length")?,
                    n.parse().map_err(|_| "repeats")?,
                ),
                BTreeMap::from([(sig.name.clone(), sig)]),
            )
        }
        _ => return Err("unknown command".into()),
    };
    let checked = check(f, imports)?;
    let check_ns = start.elapsed().as_nanos();
    let start = Instant::now();
    let (text, ext) = match a[5].as_str() {
        "c" => (emit::c(&checked), "c"),
        "llvm" => (emit::llvm(&checked)?, "ll"),
        _ => return Err("backend must be c or llvm".into()),
    };
    let emit_ns = start.elapsed().as_nanos();
    let out = Path::new(&a[2]);
    fs::create_dir_all(out).map_err(|e| e.to_string())?;
    let name = if a[1] == "provider" { "scan" } else { "entry" };
    fs::write(out.join(format!("{name}.api")), checked.interface()).map_err(|e| e.to_string())?;
    fs::write(out.join(format!("{name}.{ext}")), &text).map_err(|e| e.to_string())?;
    println!(
        "{{\"check_ns\":{check_ns},\"emit_ns\":{emit_ns},\"bytes\":{}}}",
        text.len()
    );
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("seed: {e}");
        std::process::exit(1)
    }
}
