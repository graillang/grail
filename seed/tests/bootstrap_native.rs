//! Bootstrap v0: the seed builds the Grail-written compiler (stage 1), which compiles itself
//! (stage 2) and again (stage 3). Stages must be byte-identical and match the committed
//! `compiler/bootstrap/grailc.c`. Example programs must behave as when built by the seed.
#![cfg(target_os = "linux")]
use std::{
    fs,
    path::{Path, PathBuf},
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..")
}
fn scratch(name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let dir = std::env::temp_dir().join(format!("grail-{name}-{}-{nanos}", std::process::id()));
    fs::create_dir_all(&dir).unwrap();
    dir
}
fn run(command: &mut Command) -> Output {
    let output = command.output().unwrap();
    assert!(
        output.status.success(),
        "{command:?}: {:?}\n{}{}",
        output.status,
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    output
}
fn seed() -> Command {
    Command::new(env!("CARGO_BIN_EXE_grail-seed"))
}
/// Compiles GRAIL sources (entry first) with `compiler` into an executable at `out`.
fn grailc(compiler: &Path, sources: &[PathBuf], out: &Path) {
    let c = out.with_extension("c");
    run(Command::new(compiler).arg(&c).args(sources));
    run(Command::new("clang")
        .arg("-O1")
        .arg("-w")
        .arg("-I")
        .arg(root().join("compiler"))
        .arg(&c)
        .arg("-o")
        .arg(out));
}
fn behaviour(binary: &Path, arg: Option<&str>) -> (Option<i32>, Vec<u8>) {
    let output = Command::new(binary).args(arg).output().unwrap();
    (output.status.code(), output.stdout)
}
#[test]
#[ignore = "requires Linux clang"]
fn grail_compiler_reproduces_itself_and_matches_seed_behaviour() {
    let dir = scratch("bootstrap");
    let compiler = root().join("compiler");
    let sources = [compiler.join("grailc.grl"), compiler.join("lexer.grl")];
    run(seed().arg("host").arg(&dir));
    run(seed().arg("compile").arg(&sources[1]).arg(&dir).arg(&dir));
    run(seed().arg("build").arg(&sources[0]).arg(&dir).arg(&dir));
    let stage1 = dir.join("grailc");
    let stage2 = dir.join("stage2");
    grailc(&stage1, &sources, &stage2);
    let stage3 = dir.join("stage3");
    grailc(&stage2, &sources, &stage3);
    let two = fs::read(stage2.with_extension("c")).unwrap();
    assert_eq!(two, fs::read(stage3.with_extension("c")).unwrap(), "stage 2/3 differ");
    let artifact = fs::read(compiler.join("bootstrap/grailc.c")).unwrap();
    assert!(
        two == artifact,
        "compiler/bootstrap/grailc.c is stale; regenerate it from stage 2"
    );

    let examples = root().join("seed/examples");
    let cases: &[(&[&str], Option<&str>)] = &[
        (&["loops/cleanup"], None),
        (&["records/drop_only"], None),
        (&["records/unique"], None),
        (&["modules/middle", "modules/arithmetic"], None),
        (&["enums/parse", "enums/number"], Some("12x")),
        (&["enums/parse", "enums/number"], None),
        (&["enums/recover", "enums/number", "enums/result"], Some("42")),
        (&["enums/unwrap", "enums/number", "enums/result"], Some("4x2")),
    ];
    for (n, (modules, arg)) in cases.iter().enumerate() {
        let files = modules
            .iter()
            .map(|m| examples.join(format!("{m}.grl")))
            .collect::<Vec<_>>();
        let work = dir.join(format!("case{n}"));
        fs::create_dir_all(&work).unwrap();
        run(seed().arg("host").arg(&work));
        for dependency in files[1..].iter().rev() {
            run(seed().arg("compile").arg(dependency).arg(&work).arg(&work));
        }
        run(seed().arg("build").arg(&files[0]).arg(&work).arg(&work));
        let name = Path::new(modules[0]).file_name().unwrap();
        let expected = behaviour(&work.join(name), *arg);
        let ours = work.join("grailc-built");
        grailc(&stage3, &files, &ours);
        assert_eq!(behaviour(&ours, *arg), expected, "{modules:?} {arg:?}");
    }
    fs::remove_dir_all(dir).unwrap();
}
