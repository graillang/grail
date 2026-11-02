#![cfg(target_os = "linux")]
use grail_seed::{artifact, host};
use std::{
    fs,
    path::Path,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
fn run(command: &mut Command) -> std::process::Output {
    let output = command.output().unwrap();
    assert!(
        output.status.success(),
        "{command:?}: status {:?}\n{}",
        output.status,
        String::from_utf8_lossy(&output.stderr)
    );
    output
}
#[test]
fn trusted_interface_is_declared_and_compiler_choice_explicit() {
    let api = host::interface();
    api.validate().unwrap();
    assert_eq!(api.exports.len(), 6);
    assert!(api.generics.is_empty());
    assert!(
        host::publish(Path::new("unused-host-output"), "tcc")
            .err().unwrap()
            .contains("clang")
    );
}
#[test]
#[ignore = "requires Linux clang, ASan/UBSan and linker allocator wrapping"]
fn native_io_argv_command_and_ownership() {
    let dir = std::env::temp_dir().join(format!(
        "grail-host-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let seed = env!("CARGO_BIN_EXE_grail-seed");
    run(Command::new(seed).arg("host").arg(&dir));
    let original = artifact::load(&dir, "host").unwrap();
    assert_eq!(original.header, host::interface());
    assert!(original.templates.is_none());
    let before = fs::read(&original.object).unwrap();
    run(Command::new(seed)
        .arg("host")
        .arg(&dir)
        .arg("clang-release"));
    assert_eq!(fs::read(original.object).unwrap(), before);
    let source = r#"module probe;use host;
        pub fn run()->num {
            assert(host::argc()==4);
            let path=host::arg(1);let destination=host::arg(2);let extra=host::arg(3);
            assert(len(extra)==0);
            let input=host::read_file(read(path));
            assert(len(input)==5);assert(at(read(input),0)==0);assert(at(read(input),4)==255);
            assert(host::write_file(read(destination),read(input))==0);
            assert(host::write_file(read(path),read(input))==0);
            let absent="/no/such/grail-host-test-dir/file";
            assert(host::write_file(read(absent),read(input))!=0);
            let bad=bytes();push(bad,0);
            assert(host::write_file(read(bad),read(input))!=0);
            let full="/dev/full";
            assert(host::write_file(read(full),read(input))!=0);
            let args=vec<bytes>();let yes="/bin/true";vec_push(args,copy_bytes(yes));
            assert(host::command(args)==0);
            let args=vec<bytes>();let no="/bin/false";vec_push(args,copy_bytes(no));
            assert(host::command(args)==1);
            let args=vec<bytes>();let missing="/no/such/grail-executable";vec_push(args,copy_bytes(missing));
            assert(host::command(args)==127);
            let args=vec<bytes>();assert(host::command(args)!=0);
            let args=vec<bytes>();vec_push(args,bad);assert(host::command(args)!=0);
            let args=vec<bytes>();let cmp="/usr/bin/cmp";vec_push(args,copy_bytes(cmp));
            vec_push(args,copy_bytes(path));vec_push(args,copy_bytes(destination));
            assert(host::command(args)==0);
            host::print(read(input));return 19;
        }"#;
    fs::write(dir.join("probe.grl"), source).unwrap();
    run(Command::new(seed)
        .arg("build")
        .arg(dir.join("probe.grl"))
        .arg(&dir)
        .arg(&dir));
    let input = dir.join("input ; literal.bin");
    let output = dir.join("output.bin");
    fs::write(&input, [0, 1, 128, 0, 255]).unwrap();
    let native = run(Command::new(dir.join("probe"))
        .arg(&input)
        .arg(&output)
        .arg(""));
    assert_eq!(native.stdout, b"\0\x01\x80\0\xff19\n");
    assert_eq!(fs::read(&output).unwrap(), [0, 1, 128, 0, 255]);
    fs::write(dir.join("main.c"),"#include <stdint.h>\nuint64_t q_5_probe_3_run(void);int main(void){return q_5_probe_3_run()!=19;}\n").unwrap();
    fs::write(
        dir.join("audit.c"),
        include_str!("support/allocator_audit.c"),
    )
    .unwrap();
    for level in ["-O0", "-O2"] {
        for audit in [false, true] {
            let mut cmd = Command::new("clang");
            cmd.arg(level);
            if audit {
                cmd.args([
                    "-DGRAIL_AUDIT_ORDER=0",
                    "-Wl,--wrap=malloc,--wrap=realloc,--wrap=free",
                ])
                .arg(dir.join("audit.c"));
            } else {
                cmd.args(["-fsanitize=address,undefined", "-fno-omit-frame-pointer"]);
            }
            cmd.arg(dir.join("host.c"))
                .arg(dir.join("probe.c"))
                .arg(dir.join("main.c"))
                .arg("-o")
                .arg(dir.join("checked"));
            run(&mut cmd);
            let p = run(Command::new(dir.join("checked"))
                .arg(&input)
                .arg(&output)
                .arg("")
                .env("ASAN_OPTIONS", "detect_leaks=1"));
            assert_eq!(p.stdout, [0, 1, 128, 0, 255]);
        }
    }
    assert!(
        fs::read_dir(dir.join(".grail-work"))
            .unwrap()
            .next()
            .is_none()
    );
    fs::remove_dir_all(dir).unwrap();
}
