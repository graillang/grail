#![cfg(target_os = "linux")]
//! Actual driver profiles, not just recompiling generated C with ad-hoc flags.
use grail_seed::artifact;
use std::{
    collections::BTreeMap,
    fs,
    os::unix::process::ExitStatusExt,
    path::Path,
    process::{Command, Output},
    time::{SystemTime, UNIX_EPOCH},
};
fn run(c: &mut Command) -> Output {
    let p = c.output().unwrap();
    assert!(
        p.status.success(),
        "{c:?} status={}\n{}",
        p.status,
        String::from_utf8_lossy(&p.stderr)
    );
    p
}
fn command(dir: &Path, name: &str, build: bool, profile: &str) -> Command {
    let mut c = Command::new(env!("CARGO_BIN_EXE_grail-seed"));
    c.arg(if build { "build" } else { "compile" })
        .arg(dir.join(format!("{name}.grl")))
        .arg(dir)
        .arg(dir)
        .arg(profile);
    c
}
const WORKLOAD: &str = r#"module workload;use core;use parse;pub fn run<a>(input:read<a>)->num{let empty=bytes();let zero=slice(read(empty),0,0);let copied=copy_bytes(zero);let text=text(read(copied));let pair=core::Pair<string,string>{first:text,second:""};assert(len(pair.first)==0);let v=bytes();for i in 257{push(v,i);}let owner=carry(v);let view=read(owner);var total=0;for i in len(view){total=total+at(view,i);}let result=parse::parse(input);match result{Ok(token)=>{return total+token.value+len(token.name)+len(token.span);},Err(error)=>{return total+len(error);}}}fn carry(b:bytes)->bytes{return b;}"#;
#[test]
#[ignore = "requires Linux clang; optional mixed tcc requires configured root"]
fn native_profiles_reproduce_objects_and_executables_with_hidden_sources() {
    let root = std::env::temp_dir().join(format!(
        "grail-profiles-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&root).unwrap();
    let mut dev = None;
    let mut contracts = BTreeMap::new();
    let profiles = if std::env::var_os("GRAIL_RELEASE_MIXED_BACKEND").is_some() {
        vec!["clang", "clang-release", "tcc"]
    } else {
        vec!["clang", "clang-release"]
    };
    for profile in profiles {
        let dir = root.join(profile);
        fs::create_dir(&dir).unwrap();
        for (name, source) in [
            ("core", include_str!("../std/core.grl")),
            ("parse", include_str!("../examples/generics/parse.grl")),
        ] {
            fs::write(dir.join(format!("{name}.grl")), source).unwrap();
            run(&mut command(&dir, name, false, profile));
            let before = artifact::load(&dir, name).unwrap();
            let relocated = root.join(format!("{profile}-{name}-relocated"));
            fs::create_dir(&relocated).unwrap();
            if name == "parse" {
                let core = artifact::load(&dir, "core").unwrap();
                artifact::publish(
                    &relocated,
                    &core.header,
                    &fs::read(core.object.with_extension("c")).unwrap(),
                    &fs::read(&core.object).unwrap(),
                )
                .unwrap();
            }
            let mut c = Command::new(env!("CARGO_BIN_EXE_grail-seed"));
            c.arg("compile")
                .arg(dir.join(format!("{name}.grl")))
                .arg(&relocated)
                .arg(&relocated)
                .arg(profile);
            run(&mut c);
            assert_eq!(artifact::load(&relocated, name).unwrap().id, before.id);
            let contract = before.header.fingerprint().unwrap();
            if profile == "clang" {
                contracts.insert(name, contract);
            } else {
                assert_eq!(contracts[name], contract);
            }
            fs::remove_file(dir.join(format!("{name}.grl"))).unwrap();
        }
        fs::write(dir.join("workload.grl"), WORKLOAD).unwrap();
        run(&mut command(&dir, "workload", true, profile));
        let original = artifact::load(&dir, "workload").unwrap();
        let binary = fs::read(dir.join("workload")).unwrap();
        let object = fs::read(&original.object).unwrap();
        let c = fs::read(original.object.with_extension("c")).unwrap();
        for _ in 0..2 {
            run(&mut command(&dir, "workload", true, profile));
            assert_eq!(artifact::load(&dir, "workload").unwrap().id, original.id);
            assert_eq!(fs::read(dir.join("workload")).unwrap(), binary);
        }
        let relocated = root.join(format!("{profile}-app-relocated"));
        fs::create_dir(&relocated).unwrap();
        for name in ["core", "parse"] {
            let dep = artifact::load(&dir, name).unwrap();
            artifact::publish(
                &relocated,
                &dep.header,
                &fs::read(dep.object.with_extension("c")).unwrap(),
                &fs::read(&dep.object).unwrap(),
            )
            .unwrap();
        }
        fs::write(relocated.join("workload.grl"), WORKLOAD).unwrap();
        run(&mut command(&relocated, "workload", true, profile));
        assert_eq!(
            artifact::load(&relocated, "workload").unwrap().id,
            original.id
        );
        assert_eq!(fs::read(relocated.join("workload")).unwrap(), binary);
        for input in [
            "",
            "0",
            "42",
            "00042",
            "18446744073709551615",
            "18446744073709551616",
            "bad",
            "hé🙂",
        ] {
            let suffix = if input.is_empty() {
                5
            } else {
                match input.parse::<u64>() {
                    Ok(n) => n.wrapping_add(3 + input.len() as u64),
                    Err(_) => {
                        if input.bytes().all(|b| b.is_ascii_digit()) {
                            8
                        } else {
                            7
                        }
                    }
                }
            };
            let expected = 32640_u64.wrapping_add(suffix);
            assert_eq!(
                run(Command::new(dir.join("workload")).arg(input)).stdout,
                format!("{expected}\n").as_bytes()
            );
        }
        for (name, source) in [
            (
                "bounds",
                "module bounds;pub fn run()->num{let b=bytes();return at(read(b),0);}",
            ),
            (
                "remainder",
                "module remainder;pub fn run()->num{return 7%0;}",
            ),
            (
                "unwrap",
                "module unwrap;use core;pub fn run()->num{let v=core::Option<num>::None;return v!;}",
            ),
        ] {
            fs::write(dir.join(format!("{name}.grl")), source).unwrap();
            run(&mut command(&dir, name, true, profile));
            let p = Command::new("bash")
                .args(["-c", "ulimit -c 0;exec \"$@\"", "release-guard"])
                .arg(dir.join(name))
                .output()
                .unwrap();
            assert_eq!(p.status.signal(), Some(6), "{profile} {name}");
        }
        assert!(
            !command(&dir, "workload", true, "invalid-profile")
                .output()
                .unwrap()
                .status
                .success()
        );
        assert_eq!(artifact::load(&dir, "workload").unwrap().id, original.id);
        assert_eq!(fs::read(dir.join("workload")).unwrap(), binary);
        if let Some((dev_c, dev_object, dev_header)) = &dev {
            assert_eq!(&c, dev_c);
            assert_eq!(&original.header, dev_header);
            assert_ne!(&object, dev_object);
        } else {
            dev = Some((c, object, original.header));
        }
        if std::env::var_os("GRAIL_RELEASE_MIXED_BACKEND").is_some() {
            let mixed = if profile == "clang-release" {
                "tcc"
            } else {
                "clang-release"
            };
            run(&mut command(&dir, "workload", true, mixed));
            assert_eq!(
                run(Command::new(dir.join("workload")).arg("42")).stdout,
                b"32687\n"
            );
        }
    }
    fs::remove_dir_all(root).unwrap();
}
