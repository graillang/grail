#![cfg(target_os = "linux")]
//! Requires a host C toolchain. Run explicitly: cargo test --test native -- --ignored.
use std::{
    fs,
    os::unix::process::ExitStatusExt,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
#[test]
#[ignore = "requires clang and a Linux host; runs generated native programs"]
fn two_modules_parse_borrowed_tokens_and_abort_on_invalid_input() {
    let dir = std::env::temp_dir().join(format!(
        "grail-source-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let provider = dir.join("number.grl");
    fs::write(&provider, include_str!("../examples/number.grl")).unwrap();
    let client = dir.join("sum.grl");
    fs::write(&client, include_str!("../examples/sum.grl")).unwrap();
    let binary = env!("CARGO_BIN_EXE_grail-seed");
    let p = Command::new(binary)
        .args([
            "compile",
            provider.to_str().unwrap(),
            dir.to_str().unwrap(),
            dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    // Physically remove producer source before checking/linking its client.
    fs::remove_file(provider).unwrap();
    let p = Command::new(binary)
        .args([
            "build",
            client.to_str().unwrap(),
            dir.to_str().unwrap(),
            dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    for (text, expected) in [
        ("0", "0"),
        ("9", "9"),
        ("12+34+5", "51"),
        ("18446744073709551615+1", "0"),
    ] {
        let p = Command::new(dir.join("sum")).arg(text).output().unwrap();
        assert!(p.status.success());
        assert_eq!(String::from_utf8(p.stdout).unwrap().trim(), expected);
    }
    for text in ["", "+", "1+", "1++2", "a", "-1", "1 2"] {
        let p = Command::new("bash")
            .args(["-c", "ulimit -c 0; exec \"$@\"", "guard"])
            .arg(dir.join("sum"))
            .arg(text)
            .output()
            .unwrap();
        assert_eq!(
            p.status.signal(),
            Some(6),
            "invalid input must abort: {text:?}"
        );
    }
    // Direct LLVM emission must preserve the new branch/slice semantics too.
    let checked = grail_seed::source::compile(
        include_str!("../examples/number.grl"),
        std::collections::BTreeMap::new(),
    )
    .unwrap();
    let sig = grail_seed::Sig::decode(&checked.interface()).unwrap();
    let app = grail_seed::source::compile(
        include_str!("../examples/sum.grl"),
        std::collections::BTreeMap::from([(sig.name.clone(), sig)]),
    )
    .unwrap();
    fs::write(
        dir.join("number.ll"),
        grail_seed::emit::llvm(&checked).unwrap(),
    )
    .unwrap();
    fs::write(dir.join("sum.ll"), grail_seed::emit::llvm(&app).unwrap()).unwrap();
    let p = Command::new("clang")
        .args(["-O0", "-Wno-override-module"])
        .arg(dir.join("number.ll"))
        .arg(dir.join("sum.ll"))
        .arg(dir.join("sum-main.c"))
        .arg("-o")
        .arg(dir.join("sum-llvm"))
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    let p = Command::new(dir.join("sum-llvm"))
        .arg("12+34+5")
        .output()
        .unwrap();
    assert!(p.status.success());
    assert_eq!(p.stdout, b"51\n");
    // A range evaluates its count once, rather than aliasing a mutable source variable.
    let bound = dir.join("bound.grl");
    fs::write(
        &bound,
        "fn bound()->num {var n=3;var count=0;for i in n {count=count+1;n=0;}return count;}",
    )
    .unwrap();
    let p = Command::new(binary)
        .args([
            "build",
            bound.to_str().unwrap(),
            dir.to_str().unwrap(),
            dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    let p = Command::new(dir.join("bound")).output().unwrap();
    assert!(p.status.success());
    assert_eq!(p.stdout, b"3\n");
    let loop_file = dir.join("loop.grl");
    let loop_source = "fn loop_sum<a>(input:read<a>)->num {var i=0;var sum=0;while i<len(input) {sum=sum+at(input,i);i=i+1;}return sum;}";
    fs::write(&loop_file, loop_source).unwrap();
    let p = Command::new(binary)
        .args([
            "build",
            loop_file.to_str().unwrap(),
            dir.to_str().unwrap(),
            dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    for (input, expected) in [("123", b"150\n".as_slice()), ("", b"0\n".as_slice())] {
        let p = Command::new(dir.join("loop_sum"))
            .arg(input)
            .output()
            .unwrap();
        assert!(p.status.success());
        assert_eq!(p.stdout, expected);
    }
    let checked =
        grail_seed::source::compile(loop_source, std::collections::BTreeMap::new()).unwrap();
    fs::write(
        dir.join("loop_sum.ll"),
        grail_seed::emit::llvm(&checked).unwrap(),
    )
    .unwrap();
    let p = Command::new("clang")
        .args(["-O0", "-Wno-override-module"])
        .arg(dir.join("loop_sum.ll"))
        .arg(dir.join("loop_sum-main.c"))
        .arg("-o")
        .arg(dir.join("loop-llvm"))
        .output()
        .unwrap();
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    let p = Command::new(dir.join("loop-llvm"))
        .arg("123")
        .output()
        .unwrap();
    assert!(p.status.success());
    assert_eq!(p.stdout, b"150\n");
    // A producer failure must not publish a new interface over the valid one.
    let before = fs::read(dir.join("number.api")).unwrap();
    let invalid = dir.join("invalid.grl");
    fs::write(
        &invalid,
        "fn number<a>(token:read<a>)->read<a> {let b=buffer(8,7); return read(b);}",
    )
    .unwrap();
    let p = Command::new(binary)
        .args([
            "compile",
            invalid.to_str().unwrap(),
            dir.to_str().unwrap(),
            dir.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    assert!(!p.status.success());
    assert_eq!(before, fs::read(dir.join("number.api")).unwrap());
    fs::remove_dir_all(dir).unwrap();
}
