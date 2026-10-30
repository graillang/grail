#![cfg(target_os = "linux")]
//! Real native generations remain consistent under compiler publication and concurrent publishers.
use grail_seed::artifact;
use std::{
    collections::BTreeMap,
    fs,
    path::Path,
    process::{Command, Output, Stdio},
    sync::{Arc, Barrier},
    time::{SystemTime, UNIX_EPOCH},
};
fn command(dir: &Path, file: &Path, build: bool) -> Command {
    let mut c = Command::new(env!("CARGO_BIN_EXE_grail-seed"));
    c.arg(if build { "build" } else { "compile" })
        .arg(file)
        .arg(dir)
        .arg(dir)
        .arg(std::env::var("GRAIL_ARTIFACT_TEST_BACKEND").unwrap_or_else(|_| "clang".into()));
    c
}
fn success(p: Output) -> Vec<u8> {
    assert!(p.status.success(), "{}", String::from_utf8_lossy(&p.stderr));
    p.stdout
}
#[test]
#[ignore = "requires Linux clang; optional explicit tcc also needs configured root"]
fn immutable_generations_survive_parallel_publication_and_corruption_of_copies() {
    let dir = std::env::temp_dir().join(format!(
        "grail-artifacts-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let mut known = BTreeMap::new();
    let mut payloads = Vec::new();
    let mut files = Vec::new();
    let mut first = None;
    for value in [11, 29] {
        let file = dir.join(format!("v{value}.grl"));
        fs::write(
            &file,
            format!("module provider;pub fn value()->num{{return {value};}} "),
        )
        .unwrap();
        success(command(&dir, &file, false).output().unwrap());
        let snap = artifact::load(&dir, "provider").unwrap();
        known.insert(snap.id.clone(), value);
        let relocated = dir.join(format!("other-{value}"));
        fs::create_dir_all(&relocated).unwrap();
        success(command(&relocated, &file, false).output().unwrap());
        assert_eq!(artifact::load(&relocated, "provider").unwrap().id, snap.id);

        if first.is_none() {
            first = Some(snap.clone());
        }
        payloads.push((
            snap.header.clone(),
            fs::read(snap.object.with_extension("c")).unwrap(),
            fs::read(&snap.object).unwrap(),
        ));
        success(command(&dir, &file, false).output().unwrap());
        assert_eq!(artifact::load(&dir, "provider").unwrap().id, snap.id);
        files.push(file);
    }
    // Actual compilers use isolated job paths; identical input/backend yields the same generation id.
    let mut children = Vec::new();
    for i in 0..8 {
        children.push(
            command(&dir, &files[i % 2], false)
                .stdout(Stdio::piped())
                .stderr(Stdio::piped())
                .spawn()
                .unwrap(),
        );
    }
    for child in children {
        success(child.wait_with_output().unwrap());
    }
    assert!(known.contains_key(&artifact::load(&dir, "provider").unwrap().id));
    // Synchronize publishers so a reader exercises immutable snapshots while pointers are replaced.
    let payloads = Arc::new(payloads);
    let barrier = Arc::new(Barrier::new(3));
    let mut threads = Vec::new();
    for writer in 0..2 {
        let payloads = payloads.clone();
        let barrier = barrier.clone();
        let dir = dir.clone();
        threads.push(std::thread::spawn(move || {
            barrier.wait();
            for i in 0..16 {
                let (h, c, o) = &payloads[(writer + i) % 2];
                artifact::publish(&dir, h, c, o).unwrap();
            }
        }));
    }
    barrier.wait();
    for _ in 0..128 {
        let snap = artifact::load(&dir, "provider").unwrap();
        assert!(known.contains_key(&snap.id));
    }
    for thread in threads {
        thread.join().unwrap();
    }
    let snap = artifact::load(&dir, "provider").unwrap();
    let expected = known[&snap.id];
    fs::write(dir.join("provider.api"), "not a header").unwrap();
    fs::write(dir.join("provider.o"), "not an object").unwrap();
    let client = dir.join("client.grl");
    fs::write(
        &client,
        "use provider;fn client()->num{return provider::value();}",
    )
    .unwrap();
    success(command(&dir, &client, true).output().unwrap());
    assert_eq!(
        success(Command::new(dir.join("client")).output().unwrap()),
        format!("{expected}\n").as_bytes()
    );
    let binary = fs::read(dir.join("client")).unwrap();
    let client_id = artifact::load(&dir, "client").unwrap().id;
    success(command(&dir, &client, true).output().unwrap());
    assert_eq!(fs::read(dir.join("client")).unwrap(), binary);
    let relocated = dir.join(format!("other-{expected}"));
    success(command(&relocated, &client, true).output().unwrap());
    assert_eq!(fs::read(relocated.join("client")).unwrap(), binary);
    let failure = Command::new(env!("CARGO_BIN_EXE_grail-seed"))
        .arg("build")
        .arg(&client)
        .arg(&dir)
        .arg(&dir)
        .arg("invalid-backend")
        .output()
        .unwrap();
    assert!(!failure.status.success());
    assert_eq!(artifact::load(&dir, "client").unwrap().id, client_id);
    assert_eq!(fs::read(dir.join("client")).unwrap(), binary);
    // A captured older generation remains linkable after publication of different current code.
    let first = first.unwrap();
    let client_snapshot = artifact::load(&dir, "client").unwrap();
    success(
        Command::new("clang")
            .arg(dir.join("client-main.c"))
            .arg(client_snapshot.object)
            .arg(&first.object)
            .arg("-o")
            .arg(dir.join("captured"))
            .output()
            .unwrap(),
    );
    assert_eq!(
        success(Command::new(dir.join("captured")).output().unwrap()),
        b"11\n"
    );
    // Detected corruption in immutable storage fails closed and leaves the previous executable intact.
    fs::write(&snap.object, "corrupt immutable object").unwrap();
    assert!(artifact::load(&dir, "provider").is_err());
    let before = fs::read(dir.join("client.artifact")).unwrap();
    let p = command(&dir, &client, true).output().unwrap();
    assert!(!p.status.success());
    assert_eq!(fs::read(dir.join("client.artifact")).unwrap(), before);
    assert_eq!(
        success(Command::new(dir.join("client")).output().unwrap()),
        format!("{expected}\n").as_bytes()
    );
    fs::remove_dir_all(dir).unwrap();
}
