#![cfg(target_os = "linux")]
//! Public interfaces hide private helpers; C and LLVM must agree on recursive execution.
use std::{
    fs,
    path::Path,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
fn run(cmd: &mut Command) -> Vec<u8> {
    let p = cmd.output().unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    p.stdout
}
fn compile(dir: &Path, file: &Path, build: bool) {
    run(Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg(if build { "build" } else { "compile" })
        .arg(file)
        .arg(dir)
        .arg(dir));
}
#[test]
#[ignore = "requires Linux clang; executes recursive native source modules"]
fn recursive_modules_hide_helpers_and_allow_repeated_private_names() {
    let dir = std::env::temp_dir().join(format!(
        "grail-functions-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let provider = dir.join("functions.grl");
    fs::write(&provider, include_str!("../examples/functions.grl")).unwrap();
    compile(&dir, &provider, true);
    assert_eq!(run(&mut Command::new(dir.join("functions"))), b"146\n");
    let checked = grail_seed::source::compile(
        include_str!("../examples/functions.grl"),
        std::collections::BTreeMap::new(),
    )
    .unwrap();
    fs::write(
        dir.join("functions.ll"),
        grail_seed::emit::llvm(&checked).unwrap(),
    )
    .unwrap();
    run(Command::new("clang")
        .args(["-O0", "-Wno-override-module"])
        .arg(dir.join("functions.ll"))
        .arg(dir.join("functions-main.c"))
        .arg("-o")
        .arg(dir.join("functions-llvm")));
    assert_eq!(run(&mut Command::new(dir.join("functions-llvm"))), b"146\n");
    fs::remove_file(&provider).unwrap();
    assert!(!dir.join("fib.api").exists());
    let client = dir.join("client.grl");
    fs::write(
        &client,
        "use functions;fn client()->num{return functions()+1;}",
    )
    .unwrap();
    compile(&dir, &client, true);
    assert_eq!(run(&mut Command::new(dir.join("client"))), b"147\n");
    for (name, text) in [
        (
            "left",
            "fn left()->num{return helper(3);}fn helper(n:num)->num{return n+1;}",
        ),
        (
            "right",
            "fn right()->num{return helper(9);}fn helper(n:num)->num{return n+2;}",
        ),
    ] {
        let path = dir.join(format!("{name}.grl"));
        fs::write(&path, text).unwrap();
        compile(&dir, &path, false);
        fs::remove_file(path).unwrap();
    }
    fs::write(
        &client,
        "use left;use right;fn client()->num{return left()+right();}",
    )
    .unwrap();
    compile(&dir, &client, true);
    assert_eq!(run(&mut Command::new(dir.join("client"))), b"15\n");
    let heap = dir.join("heap.grl");
    fs::write(
        &heap,
        "fn heap_entry()->num{return hidden();}fn hidden()->num{let s=\"x\";return len(s);}",
    )
    .unwrap();
    compile(&dir, &heap, true);
    assert_eq!(run(&mut Command::new(dir.join("heap_entry"))), b"1\n");
    // An invalid unused helper cannot publish a valid-looking replacement public interface.
    let api = fs::read(dir.join("left.api")).unwrap();
    fs::write(
        &provider,
        "fn left()->num{return 0;}fn bad()->num{let b=bytes();drop(b);return len(b);}",
    )
    .unwrap();
    let p = Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg("compile")
        .arg(&provider)
        .arg(&dir)
        .arg(&dir)
        .output()
        .unwrap();
    assert!(!p.status.success());
    assert_eq!(fs::read(dir.join("left.api")).unwrap(), api);
    fs::remove_dir_all(dir).unwrap();
}
