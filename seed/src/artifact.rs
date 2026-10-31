//! Immutable module generations. Metadata/object/source bytes are bound by a verified manifest;
//! one atomically replaced pointer selects a generation. Hostile filesystem writers remain trusted.
use crate::{module::Interface, name_ok, sha256};
use std::{
    fs, io,
    path::{Path, PathBuf},
    sync::atomic::{AtomicU64, Ordering},
    time::{SystemTime, UNIX_EPOCH},
};
static NEXT: AtomicU64 = AtomicU64::new(0);
fn error(e: io::Error) -> String {
    e.to_string()
}
/// A job owns only its fresh work directory; failures never delete a prior generation.
pub(crate) struct Work {
    pub path: PathBuf,
}
impl Work {
    pub fn new(out: &Path) -> Result<Self, String> {
        fs::create_dir_all(out.join(".grail-work")).map_err(error)?;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_nanos();
        for _ in 0..16 {
            let path = out.join(".grail-work").join(format!(
                "{}-{now}-{}",
                std::process::id(),
                NEXT.fetch_add(1, Ordering::Relaxed)
            ));
            match fs::create_dir(&path) {
                Ok(()) => {
                    return Ok(Self {
                        path: fs::canonicalize(path).map_err(error)?,
                    });
                }
                Err(e) if e.kind() == io::ErrorKind::AlreadyExists => continue,
                Err(e) => return Err(error(e)),
            }
        }
        Err("cannot allocate compiler work directory".into())
    }
}
impl Drop for Work {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.path);
    }
}
#[derive(Clone)]
pub struct Snapshot {
    pub header: Interface,
    pub object: PathBuf,
    pub id: String,
    pub templates: Option<PathBuf>,
}
fn generation(out: &Path, name: &str, id: &str, objects: bool) -> Result<Snapshot, String> {
    if !name_ok(name) || !sha256::is_hex(id) {
        return Err("invalid artifact identity".into());
    }
    let dir = fs::canonicalize(out.join(".grail-store").join(id)).map_err(error)?;
    let text = fs::read_to_string(dir.join("manifest")).map_err(error)?;
    let lines = text.lines().collect::<Vec<_>>();
    if lines.len() != 6
        || lines[0] != "grail-seed-artifact-2"
        || lines[1] != name
        || !lines[2..].iter().all(|s| sha256::is_hex(s))
        || sha256::hex(text.as_bytes()) != id
    {
        return Err("invalid artifact manifest".into());
    }
    let api = fs::read(dir.join(format!("{name}.api"))).map_err(error)?;
    if sha256::hex(&api) != lines[2] {
        return Err("artifact interface integrity failure".into());
    }
    let header = Interface::decode(std::str::from_utf8(&api).map_err(|e| e.to_string())?)?;
    if header.name != name {
        return Err("artifact module name mismatch".into());
    }
    let object = dir.join(format!("{name}.o"));
    let ir = dir.join(format!("{name}.ir"));
    let empty = sha256::hex(&[]);
    let expected = if lines[5] == empty {
        None
    } else {
        Some(lines[5])
    };
    if header.template_hash.as_deref() != expected {
        return Err("artifact template binding failure".into());
    }

    if objects {
        if sha256::hex(&fs::read(&object).map_err(error)?) != lines[3] {
            return Err("artifact object integrity failure".into());
        }
        if sha256::hex(&fs::read(dir.join(format!("{name}.c"))).map_err(error)?) != lines[4] {
            return Err("artifact source integrity failure".into());
        }
        if fs::metadata(&ir).map_err(error)?.len() > crate::ir::MAX as u64 {
            return Err("artifact IR byte limit".into());
        }
        if sha256::hex(&fs::read(&ir).map_err(error)?) != lines[5] {
            return Err("artifact template integrity failure".into());
        }
    }
    let templates = header.template_hash.as_ref().map(|_| ir);
    Ok(Snapshot {
        header,
        object,
        id: id.into(),
        templates,
    })
}
fn pointer(out: &Path, name: &str) -> Result<Option<String>, String> {
    if !name_ok(name) {
        return Err("invalid module name".into());
    }
    match fs::read_to_string(out.join(format!("{name}.artifact"))) {
        Ok(text) => {
            let id = text.strip_suffix('\n').ok_or("invalid artifact pointer")?;
            if !sha256::is_hex(id) {
                return Err("invalid artifact pointer".into());
            }
            Ok(Some(id.into()))
        }
        Err(e) if e.kind() == io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(error(e)),
    }
}
/// Independent checking may use metadata-only declarations. Native linking requires a generation.
pub fn interface(out: &Path, name: &str) -> Result<Interface, String> {
    if let Some(id) = pointer(out, name)? {
        return Ok(generation(out, name, &id, false)?.header);
    }
    let path = out.join(format!("{name}.api"));
    let header = Interface::decode(
        &fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?,
    )?;
    if header.name != name {
        return Err("import name does not match interface".into());
    }
    Ok(header)
}
pub fn load(out: &Path, name: &str) -> Result<Snapshot, String> {
    let id = pointer(out, name)?
        .ok_or_else(|| format!("module {name} has no immutable artifact; rebuild its producer"))?;
    generation(out, name, &id, true)
}
/// Publishes independently supplied native bytes too (trusted FFI/test producers). This checks
/// identity and structure, not whether those bytes implement the declared language contract.
pub fn publish(
    out: &Path,
    header: &Interface,
    c: &[u8],
    object: &[u8],
) -> Result<Snapshot, String> {
    publish_with_templates(out, header, c, object, &[])
}
pub fn publish_with_templates(
    out: &Path,
    header: &Interface,
    c: &[u8],
    object: &[u8],
    templates: &[u8],
) -> Result<Snapshot, String> {
    validate_templates(header, templates)?;
    let api = header.encode()?;
    let name = &header.name;
    let work = Work::new(out)?;
    let payload = work.path.join("payload");
    fs::create_dir(&payload).map_err(error)?;
    let manifest = format!(
        "grail-seed-artifact-2\n{name}\n{}\n{}\n{}\n{}\n",
        sha256::hex(api.as_bytes()),
        sha256::hex(object),
        sha256::hex(c),
        sha256::hex(templates)
    );
    let id = sha256::hex(manifest.as_bytes());
    for (file, bytes) in [
        (format!("{name}.api"), api.as_bytes()),
        (format!("{name}.c"), c),
        (format!("{name}.o"), object),
        (format!("{name}.ir"), templates),
        ("manifest".into(), manifest.as_bytes()),
    ] {
        fs::write(payload.join(file), bytes).map_err(error)?;
    }
    fs::create_dir_all(out.join(".grail-store")).map_err(error)?;
    let target = out.join(".grail-store").join(&id);
    match fs::rename(&payload, &target) {
        Ok(()) => {}
        Err(e) if target.is_dir() => {
            generation(out, name, &id, true)
                .map_err(|why| format!("existing artifact invalid: {why}; {e}"))?;
        }
        Err(e) => return Err(error(e)),
    }
    // Convenience copies are not a native-link snapshot. The pointer is published only after all
    // bytes are complete; compiler readers use its immutable generation, never these object copies.
    for extension in ["api", "c", "o", "ir"] {
        let file = format!("{name}.{extension}");
        let staged = work.path.join(&file);
        fs::copy(target.join(&file), &staged).map_err(error)?;
        fs::rename(staged, out.join(file)).map_err(error)?;
    }
    let staged = work.path.join("pointer");
    fs::write(&staged, format!("{id}\n")).map_err(error)?;
    fs::rename(staged, out.join(format!("{name}.artifact"))).map_err(error)?;
    generation(out, name, &id, true)
}

fn validate_templates(
    header: &Interface,
    data: &[u8],
) -> Result<Option<crate::template::Bundle>, String> {
    if data.is_empty() {
        if header.template_hash.is_some() || !header.generics.is_empty() {
            return Err("missing artifact template payload".into());
        }
        return Ok(None);
    }
    if header.template_hash.as_deref() != Some(sha256::hex(data).as_str()) {
        return Err("artifact template body hash mismatch".into());
    }
    let bundle = crate::template::Bundle::decode(data)?;
    if bundle.module != header.name || bundle.implementations != header.implementations {
        return Err("artifact template module/dependencies mismatch".into());
    }
    for (n, d) in &header.layouts {
        if bundle.layouts.get(n) != Some(d) {
            return Err("artifact template/public layout mismatch".into());
        }
    }
    for (n, g) in &header.generics {
        let p = bundle
            .functions
            .get(n)
            .ok_or("missing exported generic definition")?;
        if p.type_parameters != g.parameters || p.function.sig != g.function {
            return Err("artifact generic contract/body mismatch".into());
        }
    }
    Ok(Some(bundle))
}
/// Native template loading authenticates immutable bytes and rechecks the universal definitions.
pub fn templates(out: &Path, name: &str) -> Result<crate::template::Bundle, String> {
    let snapshot = load(out, name)?;
    let path = snapshot
        .templates
        .as_ref()
        .ok_or("module has no checked template payload")?;
    validate_templates(&snapshot.header, &fs::read(path).map_err(error)?)?
        .ok_or_else(|| "missing template bundle".into())
}
