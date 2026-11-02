//! Independent backend: Grail source -> x86-64 assembly -> GNU as -> native executable.
#![cfg(all(target_os = "linux", target_arch = "x86_64"))]
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn run(c: &mut Command) -> Output {
    let o = c.output().unwrap();
    assert!(
        o.status.success(),
        "{c:?}: {:?}\n{}{}",
        o.status,
        String::from_utf8_lossy(&o.stdout),
        String::from_utf8_lossy(&o.stderr)
    );
    o
}
fn seed() -> Command {
    Command::new(env!("CARGO_BIN_EXE_grail-seed"))
}
fn root_runtime() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../compiler/runtime.grl")
}
fn assemble(w: &Path, compiler: &Path, sources: &[PathBuf]) -> PathBuf {
    let asm = w.join("program.s");
    let obj = w.join("program.o");
    let exe = w.join("program");
    run(Command::new(compiler)
        .arg(&asm)
        .args(sources)
        .arg(root_runtime()));
    run(Command::new("as").arg("-o").arg(&obj).arg(&asm));
    run(Command::new("ld").arg(&obj).arg("-o").arg(&exe));
    exe
}
#[test]
#[ignore = "requires Linux x86-64, clang for the legacy bootstrap check, GNU as and ld"]
fn independent_native_backend_selfhosts_and_matches_seed() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let w = std::env::temp_dir().join(format!(
        "grail-native-codegen-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&w).unwrap();
    run(seed().arg("host").arg(&w));
    run(seed()
        .arg("compile")
        .arg(root.join("compiler/lexer.grl"))
        .arg(&w)
        .arg(&w));
    run(seed()
        .arg("build")
        .arg(root.join("compiler/native.grl"))
        .arg(&w)
        .arg(&w));
    let compiler = w.join("native");
    let sources = [
        root.join("compiler/native.grl"),
        root.join("compiler/lexer.grl"),
    ];
    // Native stage 2 and 3, including equality with the delivered assembly bootstrap.
    let native2 = assemble(&w, &compiler, &sources);
    let stage2 = w.join("native2");
    fs::copy(native2, &stage2).unwrap();
    let assembly2 = fs::read(w.join("program.s")).unwrap();
    let native3 = assemble(&w, &stage2, &sources);
    let stage3 = w.join("native3");
    fs::copy(native3, &stage3).unwrap();
    assert_eq!(
        assembly2,
        fs::read(w.join("program.s")).unwrap(),
        "native stage 2/3 differ"
    );
    assert_eq!(
        assembly2,
        fs::read(root.join("compiler/bootstrap/native.s")).unwrap(),
        "native bootstrap artifact is stale"
    );
    // The existing C bootstrap can also build the native compiler: no Rust dependency.
    let c_boot = w.join("c_boot");
    run(Command::new("cc")
        .arg("-O1")
        .arg("-I")
        .arg(root.join("compiler"))
        .arg(root.join("compiler/bootstrap/grailc.c"))
        .arg("-o")
        .arg(&c_boot));
    let native_c = w.join("native.c");
    run(Command::new(&c_boot).arg(&native_c).args(&sources));
    let from_c = w.join("from_c");
    run(Command::new("cc")
        .arg("-O1")
        .arg("-I")
        .arg(root.join("compiler"))
        .arg(&native_c)
        .arg("-o")
        .arg(&from_c));
    assemble(&w, &from_c, &sources);
    assert_eq!(
        assembly2,
        fs::read(w.join("program.s")).unwrap(),
        "C-bootstrap and seed-built native backends differ"
    );
    let compiler = stage3;
    let example = root.join("compiler/examples/native_numbers.grl");
    let exe = assemble(&w, &compiler, std::slice::from_ref(&example));
    assert_eq!(run(&mut Command::new(exe)).stdout, b"171\n");
    run(seed().arg("build").arg(&example).arg(&w).arg(&w));
    assert_eq!(
        run(&mut Command::new(w.join("native_numbers"))).stdout,
        b"171\n"
    );
    let asm = fs::read_to_string(w.join("program.s")).unwrap();
    assert!(asm.contains("divq %rcx") && asm.contains("call f_native_numbers_fib"));
    assert!(!asm.contains("#include"));
    // Aborts are explicit native guards, including unsigned remainder by zero.
    for source in [
        "module probe;pub fn run()->num{return 42%0;}",
        "module probe;pub fn run()->num{assert(0);return 0;}",
    ] {
        let src = w.join("probe.grl");
        fs::write(&src, source).unwrap();
        let exe = assemble(&w, &compiler, &[src]);
        use std::os::unix::process::ExitStatusExt;
        assert_eq!(Command::new(exe).output().unwrap().status.signal(), Some(6));
    }
    // Unknown types must fail, rather than silently emitting numeric code.
    let bad = w.join("bad.grl");
    fs::write(
        &bad,
        "module bad;pub fn run(x:unknown_type)->num{return 0;}",
    )
    .unwrap();
    assert!(
        !Command::new(&compiler)
            .arg(w.join("bad.s"))
            .arg(bad)
            .output()
            .unwrap()
            .status
            .success()
    );
    // Native-built C backend must still reproduce the checked-in C bootstrap too.
    let c_sources = [
        root.join("compiler/grailc.grl"),
        root.join("compiler/lexer.grl"),
    ];
    let executable = assemble(&w, &compiler, &c_sources);
    let c_output = w.join("reproduced.c");
    run(Command::new(executable).arg(&c_output).args(&c_sources));
    assert_eq!(
        fs::read(c_output).unwrap(),
        fs::read(root.join("compiler/bootstrap/grailc.c")).unwrap()
    );
    let raw = w.join("raw.grl");
    fs::write(&raw, "module raw;pub fn run()->num{return raw_load(0);}").unwrap();
    assert!(
        !Command::new(&compiler)
            .arg(w.join("raw.s"))
            .arg(raw)
            .arg(root_runtime())
            .output()
            .unwrap()
            .status
            .success()
    );
    // Cross-module calls, loops, record fields and enum recovery against the checked seed.
    let cases: &[(&[&str], Option<&str>)] = &[
        (&["loops/cleanup"], None),
        (&["records/unique"], None),
        (&["modules/middle", "modules/arithmetic"], None),
        (
            &["enums/recover", "enums/number", "enums/result"],
            Some("42"),
        ),
        (
            &["enums/unwrap", "enums/number", "enums/result"],
            Some("4x2"),
        ),
    ];
    for (modules, arg) in cases {
        let files = modules
            .iter()
            .map(|m| root.join(format!("seed/examples/{m}.grl")))
            .collect::<Vec<_>>();
        for dep in files[1..].iter().rev() {
            run(seed().arg("compile").arg(dep).arg(&w).arg(&w));
        }
        run(seed().arg("build").arg(&files[0]).arg(&w).arg(&w));
        let name = Path::new(modules[0]).file_name().unwrap();
        let expected = run(Command::new(w.join(name)).args(*arg)).stdout;
        let exe = assemble(&w, &compiler, &files);
        assert_eq!(
            run(Command::new(exe).args(*arg)).stdout,
            expected,
            "{modules:?}"
        );
    }
    let audit = assemble(
        &w,
        &compiler,
        &[root.join("compiler/tests/runtime_audit.grl")],
    );
    assert_eq!(run(&mut Command::new(audit)).stdout, b"0\n");
    // Execute binary I/O, argv, malformed paths and process status on the assembly runtime.
    let exe = assemble(
        &w,
        &compiler,
        &[root.join("compiler/examples/native_io.grl")],
    );
    let input = w.join("input ; literal.bin");
    let output = w.join("output.bin");
    fs::write(&input, [0, 1, 128, 0, 255]).unwrap();
    let io = run(Command::new(exe).arg(&input).arg(&output).arg(""));
    assert_eq!(io.stdout, [0, 1, 128, 0, 255, b'1', b'9', b'\n']);
    assert_eq!(fs::read(output).unwrap(), [0, 1, 128, 0, 255]);
    fs::remove_dir_all(w).unwrap();
}
