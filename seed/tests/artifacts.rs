//! Identity/integrity contracts; these synthetic object bytes are never executed.
use grail_seed::{Sig, Ty, artifact, module::Interface};
use std::{
    fs,
    time::{SystemTime, UNIX_EPOCH},
};
#[test]
fn metadata_only_checking_is_distinct_from_native_snapshot_loading() {
    let dir = std::env::temp_dir().join(format!(
        "grail-metadata-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let h = Interface::single(Sig {
        name: "sample".into(),
        params: vec![],
        result: Ty::Num,
    });
    fs::write(dir.join("sample.api"), h.encode().unwrap()).unwrap();
    assert_eq!(artifact::interface(&dir, "sample").unwrap(), h);
    assert!(artifact::load(&dir, "sample").is_err());
    let snap = artifact::publish(&dir, &h, b"source", b"object").unwrap();
    fs::write(dir.join("sample.artifact"), "malformed\n").unwrap();
    assert!(artifact::interface(&dir, "sample").is_err());
    assert!(artifact::load(&dir, "sample").is_err());
    fs::write(dir.join("sample.artifact"), format!("{}\n", snap.id)).unwrap();
    assert_eq!(artifact::load(&dir, "sample").unwrap().id, snap.id);
    fs::remove_dir_all(dir).unwrap();
}
#[test]
fn every_published_payload_is_bound_to_its_generation() {
    let dir = std::env::temp_dir().join(format!(
        "grail-integrity-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let h = Interface::single(Sig {
        name: "sample".into(),
        params: vec![],
        result: Ty::Num,
    });
    for (i, extension) in ["api", "c", "o"].iter().enumerate() {
        let c = format!("source {i}");
        let o = format!("object {i}");
        let snap = artifact::publish(&dir, &h, c.as_bytes(), o.as_bytes()).unwrap();
        fs::write(snap.object.with_extension(extension), "tampered").unwrap();
        assert!(artifact::load(&dir, "sample").is_err());
    }
    fs::remove_dir_all(dir).unwrap();
}
