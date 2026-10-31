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
    for (i, extension) in ["api", "c", "o", "ir"].iter().enumerate() {
        let c = format!("source {i}");
        let o = format!("object {i}");
        let snap = artifact::publish(&dir, &h, c.as_bytes(), o.as_bytes()).unwrap();
        fs::write(snap.object.with_extension(extension), "tampered").unwrap();
        assert!(artifact::load(&dir, "sample").is_err());
    }
    fs::remove_dir_all(dir).unwrap();
}

#[test]
fn checked_template_payloads_are_bound_independently_of_public_contracts() {
    let dir = std::env::temp_dir().join(format!(
        "grail-template-artifact-{}-{}",
        std::process::id(),
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    fs::create_dir_all(&dir).unwrap();
    let p = grail_seed::source::compile(
        "module api;pub fn id<type T>(value:T)->T{return value;}",
        Default::default(),
    )
    .unwrap();
    let ir = p.template_ir().unwrap();
    let c = grail_seed::emit::module_c(&p).unwrap();
    let snapshot = artifact::publish_with_templates(
        &dir,
        p.header(),
        c.as_bytes(),
        b"synthetic object never executed",
        &ir,
    )
    .unwrap();
    assert!(snapshot.templates.is_some());
    assert_eq!(
        artifact::templates(&dir, "api").unwrap().encode().unwrap(),
        ir
    );
    fs::write(dir.join("api.ir"), "corrupt convenience copy").unwrap();
    assert_eq!(
        artifact::templates(&dir, "api").unwrap().encode().unwrap(),
        ir
    );
    let before = fs::read(dir.join("api.artifact")).unwrap();
    let mut declarations = p.header().clone();
    declarations.template_hash = None;
    assert!(
        declarations.encode().is_ok(),
        "independent metadata checking permits declarations without bodies"
    );
    assert!(
        artifact::publish(&dir, &declarations, c.as_bytes(), b"not executed").is_err(),
        "native generic producers must provide checked code"
    );
    let mut wrong = p.header().clone();
    wrong.generics.get_mut("api::id").unwrap().function.result = Ty::Num;
    assert!(
        artifact::publish_with_templates(&dir, &wrong, c.as_bytes(), b"not executed", &ir).is_err()
    );
    assert_eq!(fs::read(dir.join("api.artifact")).unwrap(), before);
    fs::write(snapshot.templates.unwrap(), "corrupt immutable template").unwrap();
    assert!(artifact::load(&dir, "api").is_err());
    assert!(artifact::templates(&dir, "api").is_err());
    fs::remove_dir_all(dir).unwrap();
}
