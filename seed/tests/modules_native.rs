#![cfg(target_os = "linux")]
//! Hidden-source transitive linking and stale ABI prevention, with real native objects.
use std::{
    fs,
    path::Path,
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn compile(dir: &Path, file: &Path, build: bool) -> Output {
    Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg(if build { "build" } else { "compile" })
        .arg(file)
        .arg(dir)
        .arg(dir)
        .arg(std::env::var("GRAIL_MODULE_TEST_BACKEND").unwrap_or_else(|_| "clang".into()))
        .output()
        .unwrap()
}
fn success(p: Output) -> Vec<u8> {
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    p.stdout
}
#[test]
#[ignore = "requires Linux clang; explicit tcc selection also requires its configured root"]
fn public_namespaces_transitive_objects_and_stale_contracts() {
    let dir = std::env::temp_dir().join(format!(
        "grail-modules-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let a = dir.join("a.grl");
    let b = dir.join("b.grl");
    let client = dir.join("client.grl");
    let original = "module a;fn helper(n:num)->num{return n*3;}pub fn start()->num{return plus(2);}pub fn plus(n:num)->num{return helper(n)+2;}";
    fs::write(&a, original).unwrap();
    success(compile(&dir, &a, false));
    // Qualified public calls must also survive the independent LLVM lowering.
    let m = grail_seed::source::compile(original, std::collections::BTreeMap::new()).unwrap();
    fs::write(dir.join("a.ll"), grail_seed::emit::module_llvm(&m).unwrap()).unwrap();
    success(
        Command::new("clang")
            .args(["-c", "-Wno-override-module"])
            .arg(dir.join("a.ll"))
            .arg("-o")
            .arg(dir.join("a-llvm.o"))
            .output()
            .unwrap(),
    );
    fs::write(&b, "use a;fn b()->num{return a::plus(4)+a();}").unwrap();
    success(compile(&dir, &b, false));
    fs::remove_file(&a).unwrap();
    fs::remove_file(&b).unwrap();
    fs::write(&client, "use b;fn client()->num{return b();}").unwrap();
    success(compile(&dir, &client, true));
    assert_eq!(
        success(Command::new(dir.join("client")).output().unwrap()),
        b"22\n"
    );
    // Link the same client with the LLVM-produced provider as an independent backend check.
    success(
        Command::new("clang")
            .arg(dir.join("client-main.c"))
            .arg(dir.join("client.o"))
            .arg(dir.join("b.o"))
            .arg(dir.join("a-llvm.o"))
            .arg("-o")
            .arg(dir.join("client-llvm"))
            .output()
            .unwrap(),
    );
    assert_eq!(
        success(Command::new(dir.join("client-llvm")).output().unwrap()),
        b"22\n"
    );
    let surface = fs::read(dir.join("a.api")).unwrap();
    fs::write(&a, original.replace("n*3", "n*4")).unwrap();
    success(compile(&dir, &a, false));
    assert_eq!(fs::read(dir.join("a.api")).unwrap(), surface);
    fs::remove_file(&a).unwrap();
    success(compile(&dir, &client, true));
    assert_eq!(
        success(Command::new(dir.join("client")).output().unwrap()),
        b"28\n"
    );
    let old = fs::read(dir.join("client.api")).unwrap();
    fs::write(
        &a,
        "fn a()->num{return 9;}pub fn plus(n:bytes)->num{return len(n);}",
    )
    .unwrap();
    success(compile(&dir, &a, false));
    fs::remove_file(&a).unwrap();
    let p = compile(&dir, &client, true);
    assert!(!p.status.success());
    assert_eq!(fs::read(dir.join("client.api")).unwrap(), old);
    assert_eq!(
        success(Command::new(dir.join("client")).output().unwrap()),
        b"28\n"
    );
    fs::remove_dir_all(dir).unwrap();
}

#[test]
#[ignore = "requires Linux clang; creates valid objects behind a cyclic metadata graph"]
fn cyclic_metadata_is_rejected_before_an_otherwise_valid_link() {
    use grail_seed::{Sig, Ty, module::Interface};
    let dir = std::env::temp_dir().join(format!(
        "grail-cycle-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let mut a = Interface::single(Sig {
        name: "aa".into(),
        params: vec![],
        result: Ty::Num,
    });
    let mut b = Interface::single(Sig {
        name: "bb".into(),
        params: vec![],
        result: Ty::Num,
    });
    a.dependencies.insert("bb".into(), b.fingerprint().unwrap());
    b.dependencies.insert("aa".into(), a.fingerprint().unwrap());
    for (name, header) in [("aa", a), ("bb", b)] {
        fs::write(dir.join(format!("{name}.api")), header.encode().unwrap()).unwrap();
        let c = dir.join(format!("{name}.c"));
        fs::write(
            &c,
            format!("#include <stdint.h>\nuint64_t g_{name}(void){{return 1;}}\n"),
        )
        .unwrap();
        success(
            Command::new("clang")
                .arg("-c")
                .arg(&c)
                .arg("-o")
                .arg(dir.join(format!("{name}.o")))
                .output()
                .unwrap(),
        );
    }
    let file = dir.join("client.grl");
    fs::write(&file, "use aa;fn client()->num{return aa();}").unwrap();
    let p = compile(&dir, &file, true);
    assert!(!p.status.success());
    assert!(!dir.join("client").exists());
    fs::remove_dir_all(dir).unwrap();
}
