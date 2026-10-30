//! Grail bootstrap seed: checked IR and the first .grl source subset.
//! Reference values are currently affine; this is not a complete language implementation.
mod aggregate;
pub mod artifact;
pub mod driver;
pub mod emit;
pub mod fixture;
pub mod module;
mod sha256;
pub mod source;
pub mod types;
use std::collections::{BTreeMap, BTreeSet};

pub type Reg = u32;
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Read,
    Write,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Ty {
    Num,
    Record(String, Vec<u16>),
    Buffer,
    Bytes,
    Text,
    View(Mode, u16),
    Holder(Mode, u16),
}
impl Ty {
    fn owned(&self) -> bool {
        matches!(
            self,
            Self::Buffer | Self::Bytes | Self::Text | Self::Record(..)
        )
    }
    fn heap(&self) -> bool {
        matches!(self, Self::Bytes | Self::Text)
    }
    fn reference(&self) -> Option<(Mode, u16)> {
        match self {
            Self::View(m, r) | Self::Holder(m, r) => Some((*m, *r)),
            _ => None,
        }
    }
    fn word(&self) -> String {
        match self {
            Self::Num => "n".into(),
            Self::Record(n, args) => format!(
                "t{n}@{}",
                args.iter()
                    .map(u16::to_string)
                    .collect::<Vec<_>>()
                    .join(":")
            ),
            Self::Buffer => "b".into(),
            Self::Bytes => "o".into(),
            Self::Text => "s".into(),
            Self::View(m, r) => format!("{}{}", if *m == Mode::Read { "r" } else { "w" }, r),
            Self::Holder(m, r) => format!("h{}{}", if *m == Mode::Read { "r" } else { "w" }, r),
        }
    }
    fn parse(s: &str) -> Result<Self, String> {
        if let Some(s) = s.strip_prefix('t') {
            let (n, args) = s.split_once('@').ok_or("invalid record type")?;
            if !qualified_ok(n) {
                return Err("invalid record name".into());
            }
            let args = if args.is_empty() {
                Vec::new()
            } else {
                args.split(':')
                    .map(|r| {
                        r.parse::<u16>()
                            .map_err(|_| "invalid record region".to_string())
                    })
                    .collect::<Result<Vec<_>, _>>()?
            };
            if args.len() > 64 {
                return Err("record lifetime arity limit".into());
            }
            return Ok(Self::Record(n.into(), args));
        }

        if s == "n" {
            return Ok(Self::Num);
        }
        if s == "s" {
            return Ok(Self::Text);
        }
        if s == "o" {
            return Ok(Self::Bytes);
        }
        let (holder, s) = if let Some(s) = s.strip_prefix('h') {
            (true, s)
        } else {
            (false, s)
        };
        let m = match s.as_bytes().first() {
            Some(b'r') => Mode::Read,
            Some(b'w') => Mode::Write,
            _ => return Err("invalid interface type".into()),
        };
        let r = s
            .get(1..)
            .ok_or("invalid region")?
            .parse::<u16>()
            .map_err(|_| "invalid region")?;
        Ok(if holder {
            Self::Holder(m, r)
        } else {
            Self::View(m, r)
        })
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Sig {
    pub name: String,
    pub params: Vec<Ty>,
    pub result: Ty,
}
fn name_ok(n: &str) -> bool {
    !n.is_empty()
        && n.len() <= 80
        && n.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'_')
        && n.as_bytes()[0].is_ascii_alphabetic()
}
fn qualified_ok(n: &str) -> bool {
    n.split_once("::")
        .is_some_and(|(a, b)| name_ok(a) && name_ok(b))
}
impl Sig {
    pub fn validate(&self) -> Result<(), String> {
        if !(name_ok(&self.name) || qualified_ok(&self.name)) || self.params.len() > 64 {
            return Err("invalid signature name/arity".into());
        }
        if self
            .params
            .iter()
            .chain([&self.result])
            .any(|t| matches!(t,Ty::Record(n,args)if !qualified_ok(n)||args.len()>64))
        {
            return Err("invalid nominal signature type".into());
        }
        if self
            .params
            .iter()
            .chain([&self.result])
            .any(|t| *t == Ty::Buffer)
        {
            return Err("owned buffers cannot cross seed interfaces".into());
        }
        if let Some((mode, r)) = self.result.reference()
            && !self.params.iter().any(|t| matches!(t, Ty::Record(..)))
            && !self.params.iter().any(|t| {
                t.reference()
                    .is_some_and(|(m, p)| p == r && (mode == Mode::Read || m == Mode::Write))
            })
        {
            return Err("result region has no suitable input".into());
        }
        Ok(())
    }
    pub fn encode(&self) -> Result<String, String> {
        self.validate()?;
        Ok(format!(
            "grail-seed-interface-4\n{}\n{}\n{}\n",
            self.name,
            self.params
                .iter()
                .map(Ty::word)
                .collect::<Vec<_>>()
                .join(","),
            self.result.word()
        ))
    }
    pub fn decode(text: &str) -> Result<Self, String> {
        if text.len() > 65536 {
            return Err("interface too large".into());
        }
        let lines = text.lines().collect::<Vec<_>>();
        if lines.len() != 4 || lines[0] != "grail-seed-interface-4" {
            return Err("invalid interface schema".into());
        }
        let params = if lines[2].is_empty() {
            vec![]
        } else {
            lines[2]
                .split(',')
                .map(Ty::parse)
                .collect::<Result<Vec<_>, _>>()?
        };
        let sig = Self {
            name: lines[1].into(),
            params,
            result: Ty::parse(lines[3])?,
        };
        sig.validate()?;
        if sig.encode()? != text {
            return Err("noncanonical interface".into());
        }
        Ok(sig)
    }
}
#[derive(Clone, Copy, Debug)]
pub enum Bin {
    Add,
    Sub,
    Lt,
    Mul,
    Xor,
    Rem,
    Eq,
    Ne,
    And,
}
#[derive(Clone, Debug)]
pub enum Op {
    Num(Reg, u64),
    Record {
        dst: Reg,
        name: String,
        fields: Vec<(String, Reg)>,
    },
    FieldMove {
        dst: Reg,
        src: Reg,
        path: Vec<String>,
    },
    FieldBorrow {
        dst: Reg,
        src: Reg,
        path: Vec<String>,
        mode: Mode,
    },
    EndCaptures(Reg),
    TextLiteral {
        dst: Reg,
        data: Vec<u8>,
    },
    Text {
        dst: Reg,
        src: Reg,
    },
    AppendText {
        owner: Reg,
        src: Reg,
    },
    Bytes {
        dst: Reg,
    },
    CopyBytes {
        dst: Reg,
        src: Reg,
    },
    Push {
        owner: Reg,
        value: Reg,
    },
    Buffer {
        dst: Reg,
        len: usize,
        seed: u64,
    },
    Borrow {
        dst: Reg,
        src: Reg,
        mode: Mode,
    },
    Slice {
        dst: Reg,
        src: Reg,
        start: Reg,
        end: Reg,
    },
    Assert(Reg),
    If {
        condition: Reg,
        yes: Vec<Op>,
        no: Vec<Op>,
    },
    Pack {
        dst: Reg,
        src: Reg,
    },
    Move {
        dst: Reg,
        src: Reg,
    },
    End(Reg),
    Len {
        dst: Reg,
        src: Reg,
    },
    Read {
        dst: Reg,
        src: Reg,
        index: Reg,
    },
    Write {
        dst: Reg,
        index: Reg,
        value: Reg,
    },
    Binary {
        dst: Reg,
        op: Bin,
        left: Reg,
        right: Reg,
    },
    Call {
        dst: Reg,
        name: String,
        args: Vec<Reg>,
    },
    Block {
        body: Vec<Op>,
    },
    While {
        condition: Reg,
        test: Vec<Op>,
        body: Vec<Op>,
    },
    Loop {
        index: Reg,
        end: Reg,
        body: Vec<Op>,
    },
}
#[derive(Clone, Debug)]
pub struct Function {
    pub sig: Sig,
    pub ops: Vec<Op>,
    pub result: Reg,
}
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum Root {
    Local(Reg, Vec<usize>),
    Param(usize, Vec<usize>),
}
#[derive(Clone, Debug, PartialEq, Eq)]
struct Value {
    ty: Ty,
    roots: BTreeSet<Root>,
    loan: usize,
    ancestors: BTreeSet<usize>,
    fields: Vec<Option<Value>>,
    active: bool,
}
#[derive(Clone, Debug, Default)]
struct State {
    records: types::Context,
    values: BTreeMap<Reg, Value>,
    resources: BTreeSet<Reg>,
    next: usize,
    types: BTreeMap<Reg, Ty>,
    access: BTreeMap<Root, (usize, usize)>,
    blocked: BTreeMap<usize, usize>,
}
impl State {
    fn parameters(params: &[Ty], records: types::Context) -> Result<Self, String> {
        let mut s = Self {
            records,
            ..Self::default()
        };
        for (i, t) in params.iter().enumerate() {
            let v = s.parameter_value(t, i, &mut Vec::new())?;
            s.put(i as Reg, v)?;
        }
        Ok(s)
    }
    fn get(&self, r: Reg) -> Result<&Value, String> {
        self.values
            .get(&r)
            .ok_or_else(|| format!("r{r}: dead or undefined"))
    }
    fn usable(&self, r: Reg) -> Result<Value, String> {
        let v = self.get(r)?;
        self.usable_value(v)?;
        Ok(v.clone())
    }
    fn put(&mut self, r: Reg, v: Value) -> Result<(), String> {
        if r > 65535 {
            return Err("register limit".into());
        }
        if let Some(old) = self.values.get(&r)
            && (old.ty != Ty::Num || v.ty != Ty::Num)
        {
            return Err(format!("r{r}: overwrite needs explicit end"));
        }
        if let Some(t) = self.types.get(&r)
            && *t != v.ty
        {
            return Err(format!("r{r}: register changes type"));
        }
        self.remove(r);
        self.types.insert(r, v.ty.clone());
        self.index_add(&v);
        if v.ty != Ty::Num {
            self.resources.insert(r);
        }
        self.values.insert(r, v);
        Ok(())
    }
    fn remove(&mut self, r: Reg) {
        if let Some(v) = self.values.remove(&r) {
            self.resources.remove(&r);
            self.index_remove(&v);
        }
    }
    fn owner_borrowed(&self, v: &Value) -> bool {
        (v.ty.owned() && v.roots.iter().any(|r| self.access.contains_key(r)))
            || v.fields
                .iter()
                .flatten()
                .any(|f| f.ty.owned() && self.owner_borrowed(f))
    }
    fn new_value(&mut self, ty: Ty, roots: BTreeSet<Root>, ancestors: BTreeSet<usize>) -> Value {
        self.next += 1;
        Value {
            ty,
            roots,
            loan: self.next,
            ancestors,
            fields: Vec::new(),
            active: true,
        }
    }
    fn num(&mut self, r: Reg) -> Result<(), String> {
        let v = self.new_value(Ty::Num, BTreeSet::new(), BTreeSet::new());
        self.put(r, v)
    }
    fn require_num(&self, r: Reg) -> Result<(), String> {
        if self.get(r)?.ty != Ty::Num {
            return Err(format!("r{r}: expected number"));
        }
        Ok(())
    }
    fn readable(&self, r: Reg) -> Result<(), String> {
        let v = self.usable(r)?;
        if matches!(v.ty, Ty::Buffer | Ty::Bytes | Ty::Text) {
            if v.roots
                .iter()
                .any(|root| self.access.get(root).is_some_and(|(_, writes)| *writes > 0))
            {
                return Err("owner restricted by write loan".into());
            }
        } else if v.ty.reference().is_none() {
            return Err("expected byte storage or view".into());
        }
        Ok(())
    }
    fn end(&mut self, r: Reg) -> Result<(), String> {
        let v = self.get(r)?.clone();
        self.drop_usable(&v)?;
        if v.ty.owned() && self.owner_borrowed(&v) {
            return Err(format!("r{r}: owner still borrowed"));
        }
        self.remove(r);
        Ok(())
    }
    fn validate_resource_frame(&self, entry: &BTreeSet<Reg>) -> Result<(), String> {
        if self.resources.difference(entry).next().is_some() {
            return Err("block-local resource must end or move out".into());
        }
        Ok(())
    }
    fn validate_closed(&self, entry: &BTreeMap<Reg, Value>) -> Result<(), String> {
        for (r, v) in &self.values {
            if !entry.contains_key(r) && v.ty != Ty::Num {
                return Err("block-local resource must end".into());
            }
        }
        for (r, v) in entry {
            let after = self.get(*r)?;
            if v.ty != after.ty || (v.ty != Ty::Num && v != after) {
                return Err("block changes entry ownership".into());
            }
        }
        Ok(())
    }
    fn closed(
        &mut self,
        ops: &[Op],
        imports: &BTreeMap<String, Sig>,
        depth: usize,
    ) -> Result<(), String> {
        let entry = self.values.clone();
        self.ops(ops, imports, depth)?;
        self.validate_closed(&entry)?;
        self.values = entry;
        Ok(())
    }
    fn ops(
        &mut self,
        ops: &[Op],
        imports: &BTreeMap<String, Sig>,
        depth: usize,
    ) -> Result<(), String> {
        if depth > 64 {
            return Err("loop nesting limit".into());
        }
        for op in ops {
            match op {
                Op::Num(r, _) => self.num(*r)?,
                Op::TextLiteral { dst, data } => {
                    if data.len() > 1024 * 1024 || std::str::from_utf8(data).is_err() {
                        return Err("invalid UTF-8 literal or literal size limit".into());
                    }
                    let v = self.new_value(
                        Ty::Text,
                        BTreeSet::from([Root::Local(*dst, vec![])]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::Text { dst, src } => {
                    self.readable(*src)?;
                    let v = self.new_value(
                        Ty::Text,
                        BTreeSet::from([Root::Local(*dst, vec![])]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::AppendText { owner, src } => {
                    let v = self.usable(*owner)?;
                    if v.ty != Ty::Text {
                        return Err("append_text expects owned string".into());
                    }
                    if self.owner_borrowed(&v) {
                        return Err("text growth while borrowed".into());
                    }
                    self.readable(*src)?;
                    if !self.get(*src)?.roots.is_disjoint(&v.roots) {
                        return Err("self-append requires an explicit copy".into());
                    }
                }
                Op::Bytes { dst } => {
                    let v = self.new_value(
                        Ty::Bytes,
                        BTreeSet::from([Root::Local(*dst, vec![])]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::CopyBytes { dst, src } => {
                    self.readable(*src)?;
                    let v = self.new_value(
                        Ty::Bytes,
                        BTreeSet::from([Root::Local(*dst, vec![])]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::Push { owner, value } => {
                    let v = self.usable(*owner)?;
                    if v.ty != Ty::Bytes {
                        return Err("push expects owned bytes".into());
                    }
                    if self.owner_borrowed(&v) {
                        return Err("growth while owner is borrowed".into());
                    }
                    self.require_num(*value)?;
                }
                Op::Buffer { dst, len, .. } => {
                    if *len > 1024 * 1024 {
                        return Err("buffer size limit".into());
                    }
                    let v = self.new_value(
                        Ty::Buffer,
                        BTreeSet::from([Root::Local(*dst, vec![])]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::Borrow { dst, src, mode } => {
                    let p = self.usable(*src)?;
                    let v = self.borrow_value(p, *mode)?;
                    self.put(*dst, v)?;
                }
                Op::Record { dst, name, fields } => self.record_value(*dst, name, fields)?,
                Op::FieldMove { dst, src, path } => self.field_move(*dst, *src, path)?,
                Op::FieldBorrow {
                    dst,
                    src,
                    path,
                    mode,
                } => {
                    let (indices, _) = types::project(&self.get(*src)?.ty, path, &self.records)?;
                    let p = self.get(*src)?.at(&indices)?.clone();
                    let v = self.borrow_value(p, *mode)?;
                    self.put(*dst, v)?;
                }
                Op::EndCaptures(src) => {
                    self.expire_captures(*src)?;
                }
                Op::Slice {
                    dst,
                    src,
                    start,
                    end,
                } => {
                    self.require_num(*start)?;
                    self.require_num(*end)?;
                    if self.get(*src)?.ty.reference().is_none() {
                        return Err("slice expects view".into());
                    }
                    self.ops(
                        &[Op::Borrow {
                            dst: *dst,
                            src: *src,
                            mode: Mode::Read,
                        }],
                        imports,
                        depth,
                    )?;
                }
                Op::Assert(r) => self.require_num(*r)?,
                Op::If { condition, yes, no } => {
                    self.require_num(*condition)?;
                    self.closed(yes, imports, depth + 1)?;
                    self.closed(no, imports, depth + 1)?;
                }
                Op::Pack { dst, src } => {
                    let mut v = self.usable(*src)?;
                    let Ty::View(m, r) = v.ty else {
                        return Err("pack expects view".into());
                    };
                    v.ty = Ty::Holder(m, r);
                    if dst == src {
                        return Err("pack needs new register".into());
                    }
                    self.remove(*src);
                    self.put(*dst, v)?;
                }
                Op::Move { dst, src } => {
                    if dst == src {
                        return Err("self move".into());
                    }
                    let v = self.usable(*src)?;
                    if v.ty.owned() && self.owner_borrowed(&v) {
                        return Err("move of borrowed owner".into());
                    }
                    if v.ty != Ty::Num {
                        self.remove(*src);
                    }
                    self.put(*dst, v)?;
                }
                Op::End(r) => self.end(*r)?,
                Op::Len { dst, src } => {
                    self.readable(*src)?;
                    self.num(*dst)?;
                }
                Op::Read { dst, src, index } => {
                    if self.usable(*src)?.ty.reference().is_none() {
                        return Err("read expects view".into());
                    }
                    self.require_num(*index)?;
                    self.num(*dst)?;
                }
                Op::Write { dst, index, value } => {
                    if !self
                        .usable(*dst)?
                        .ty
                        .reference()
                        .is_some_and(|(m, _)| m == Mode::Write)
                    {
                        return Err("write expects exclusive view".into());
                    }
                    self.require_num(*index)?;
                    self.require_num(*value)?;
                }
                Op::Binary {
                    dst, left, right, ..
                } => {
                    self.require_num(*left)?;
                    self.require_num(*right)?;
                    self.num(*dst)?;
                }
                Op::Call { dst, name, args } => {
                    let sig = imports.get(name).ok_or("unknown imported function")?;
                    types::validate_sig(sig, &self.records)?;
                    if sig.params.len() != args.len() {
                        return Err("call arity".into());
                    }
                    let mut actuals = vec![];
                    let mut consumed = BTreeSet::new();
                    for (r, t) in args.iter().zip(&sig.params) {
                        let v = self.usable(*r)?;
                        let matches = match (&v.ty, t) {
                            (Ty::Record(a, _), Ty::Record(b, _)) => a == b,
                            (Ty::Num, Ty::Num) | (Ty::Bytes, Ty::Bytes) | (Ty::Text, Ty::Text) => {
                                true
                            }
                            (Ty::View(a, _), Ty::View(b, _))
                            | (Ty::Holder(a, _), Ty::Holder(b, _)) => a == b,
                            _ => false,
                        };
                        if !matches {
                            return Err("call argument type/mode".into());
                        }
                        if v.ty.owned() && self.owner_borrowed(&v) {
                            return Err("call moves borrowed owner".into());
                        }
                        if *t != Ty::Num && !consumed.insert(*r) {
                            return Err("affine argument duplicated".into());
                        }
                        actuals.push(v);
                    }
                    let inputs = sig.params.iter().cloned().zip(actuals).collect::<Vec<_>>();
                    let v = self.result_value(&sig.result, *dst, &mut Vec::new(), &inputs)?;
                    for r in consumed {
                        self.remove(r);
                    }
                    self.put(*dst, v)?;
                }
                Op::Block { body } => {
                    let entry = self.resources.clone();
                    self.ops(body, imports, depth + 1)?;
                    self.validate_resource_frame(&entry)?;
                }
                Op::While {
                    condition,
                    test,
                    body,
                } => {
                    let entry = self.values.clone();
                    self.ops(test, imports, depth + 1)?;
                    self.require_num(*condition)?;
                    self.validate_closed(&entry)?;
                    self.values = entry;
                    self.closed(body, imports, depth + 1)?;
                }
                Op::Loop { index, end, body } => {
                    self.require_num(*end)?;
                    if index == end || self.values.contains_key(index) {
                        return Err("loop index must be fresh".into());
                    }
                    let entry = self.values.clone();
                    self.num(*index)?;
                    self.ops(body, imports, depth + 1)?;
                    for (r, v) in &self.values {
                        if !entry.contains_key(r) && v.ty != Ty::Num {
                            return Err("loop-local resource must end each iteration".into());
                        }
                    }
                    for (r, v) in &entry {
                        let after = self.get(*r)?;
                        if v.ty != Ty::Num && v != after {
                            return Err("loop changes ownership at back edge".into());
                        }
                        if v.ty != after.ty {
                            return Err("loop changes type".into());
                        }
                    }
                    self.values = entry;
                }
            }
        }
        Ok(())
    }
}
/// Only this validated wrapper can reach native lowering.
pub struct Checked {
    pub(crate) function: Function,
    pub(crate) imports: BTreeMap<String, Sig>,
    pub(crate) types: BTreeMap<Reg, Ty>,
    pub(crate) records: types::Context,
}
impl Checked {
    pub fn interface(&self) -> String {
        self.function.sig.encode().expect("validated signature")
    }
}
pub fn check(function: Function, imports: BTreeMap<String, Sig>) -> Result<Checked, String> {
    check_with_records(function, imports, crate::types::Context::default())
}
pub fn check_with_records(
    function: Function,
    imports: BTreeMap<String, Sig>,
    records: types::Context,
) -> Result<Checked, String> {
    types::validate_sig(&function.sig, &records)?;
    for (name, sig) in &imports {
        types::validate_sig(sig, &records)?;
        if name != &sig.name || name == &function.sig.name {
            return Err("invalid import key/self import".into());
        }
    }
    let mut s = State::parameters(&function.sig.params, records.clone())?;
    let mut callable = imports.clone();
    callable.insert(function.sig.name.clone(), function.sig.clone());
    s.ops(&function.ops, &callable, 0)?;
    let result = s.usable(function.result)?;
    if s.values
        .iter()
        .any(|(r, v)| v.has_heap() && *r != function.result)
    {
        return Err("heap owner must be ended or returned".into());
    }
    let compatible = match (&result.ty, &function.sig.result) {
        (Ty::Record(a, _), Ty::Record(b, _)) => a == b,
        (Ty::Num, Ty::Num) | (Ty::Bytes, Ty::Bytes) | (Ty::Text, Ty::Text) => true,
        (Ty::View(m, _), Ty::View(n, _)) | (Ty::Holder(m, _), Ty::Holder(n, _)) => m == n,
        _ => false,
    };
    if !compatible {
        return Err("return type mismatch".into());
    }
    for (path, ty) in types::leaves(&function.sig.result, &records)? {
        if let Some((mode, region)) = ty.reference() {
            for root in &result.at(&path)?.roots {
                let Root::Param(i, p) = root else {
                    return Err("local owner escapes".into());
                };
                let input = types::at(&function.sig.params[*i], p, &records)?;
                let Some((m, r)) = input.reference() else {
                    return Err("invalid return origin".into());
                };
                if r != region || (mode == Mode::Write && m != Mode::Write) {
                    return Err("return violates written region relationship".into());
                }
            }
        }
    }
    Ok(Checked {
        function,
        imports,
        types: s.types,
        records,
    })
}
