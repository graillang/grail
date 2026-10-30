//! Grail bootstrap seed: checked IR and the first .grl source subset.
//! Reference values are currently affine; this is not a complete language implementation.
pub mod driver;
pub mod emit;
pub mod fixture;
pub mod source;
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
    Buffer,
    Bytes,
    Text,
    View(Mode, u16),
    Holder(Mode, u16),
}
impl Ty {
    fn owned(&self) -> bool {
        matches!(self, Self::Buffer | Self::Bytes | Self::Text)
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
            Self::Buffer => "b".into(),
            Self::Bytes => "o".into(),
            Self::Text => "s".into(),
            Self::View(m, r) => format!("{}{}", if *m == Mode::Read { "r" } else { "w" }, r),
            Self::Holder(m, r) => format!("h{}{}", if *m == Mode::Read { "r" } else { "w" }, r),
        }
    }
    fn parse(s: &str) -> Result<Self, String> {
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
impl Sig {
    pub fn validate(&self) -> Result<(), String> {
        if !name_ok(&self.name) || self.params.len() > 64 {
            return Err("invalid signature name/arity".into());
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
            "grail-seed-interface-3\n{}\n{}\n{}\n",
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
        if text.len() > 8192 {
            return Err("interface too large".into());
        }
        let lines = text.lines().collect::<Vec<_>>();
        if lines.len() != 4 || lines[0] != "grail-seed-interface-3" {
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
    Local(Reg),
    Param(usize),
}
#[derive(Clone, Debug, PartialEq, Eq)]
struct Value {
    ty: Ty,
    roots: BTreeSet<Root>,
    loan: usize,
    ancestors: BTreeSet<usize>,
}
#[derive(Clone, Debug, Default)]
struct State {
    values: BTreeMap<Reg, Value>,
    resources: BTreeSet<Reg>,
    next: usize,
    types: BTreeMap<Reg, Ty>,
    access: BTreeMap<Root, (usize, usize)>,
    loans: BTreeMap<usize, (Mode, BTreeSet<Root>)>,
    blocked: BTreeMap<usize, usize>,
}
impl State {
    fn parameters(params: &[Ty]) -> Result<Self, String> {
        let mut s = Self::default();
        for (i, t) in params.iter().enumerate() {
            let roots = if t.reference().is_some() || t.owned() {
                BTreeSet::from([Root::Param(i)])
            } else {
                BTreeSet::new()
            };
            let v = s.new_value(t.clone(), roots, BTreeSet::new());
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
        if self.blocked.contains_key(&v.loan) {
            return Err(format!("r{r}: carrier restricted by live child"));
        }
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
        if let Some((mode, _)) = v.ty.reference() {
            for root in &v.roots {
                let counts = self.access.entry(root.clone()).or_default();
                if mode == Mode::Read {
                    counts.0 += 1;
                } else {
                    counts.1 += 1;
                }
            }
            self.loans.insert(v.loan, (mode, v.roots.clone()));
        }
        for ancestor in &v.ancestors {
            *self.blocked.entry(*ancestor).or_default() += 1;
        }
        if v.ty != Ty::Num {
            self.resources.insert(r);
        }
        self.values.insert(r, v);
        Ok(())
    }
    fn remove(&mut self, r: Reg) {
        if let Some(v) = self.values.remove(&r) {
            self.resources.remove(&r);
            if let Some((mode, _)) = v.ty.reference() {
                self.loans.remove(&v.loan);
                for root in &v.roots {
                    let counts = self.access.get_mut(root).expect("indexed root");
                    if mode == Mode::Read {
                        counts.0 -= 1;
                    } else {
                        counts.1 -= 1;
                    }
                    if *counts == (0, 0) {
                        self.access.remove(root);
                    }
                }
            }
            for ancestor in v.ancestors {
                let count = self.blocked.get_mut(&ancestor).expect("indexed parent");
                *count -= 1;
                if *count == 0 {
                    self.blocked.remove(&ancestor);
                }
            }
        }
    }
    fn owner_borrowed(&self, v: &Value) -> bool {
        v.roots.iter().any(|r| self.access.contains_key(r))
    }
    fn new_value(&mut self, ty: Ty, roots: BTreeSet<Root>, ancestors: BTreeSet<usize>) -> Value {
        self.next += 1;
        Value {
            ty,
            roots,
            loan: self.next,
            ancestors,
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
        if v.ty.owned() {
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
        let v = self.usable(r)?;
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
                        BTreeSet::from([Root::Local(*dst)]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::Text { dst, src } => {
                    self.readable(*src)?;
                    let v = self.new_value(
                        Ty::Text,
                        BTreeSet::from([Root::Local(*dst)]),
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
                        BTreeSet::from([Root::Local(*dst)]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::CopyBytes { dst, src } => {
                    self.readable(*src)?;
                    let v = self.new_value(
                        Ty::Bytes,
                        BTreeSet::from([Root::Local(*dst)]),
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
                        BTreeSet::from([Root::Local(*dst)]),
                        BTreeSet::new(),
                    );
                    self.put(*dst, v)?;
                }
                Op::Borrow { dst, src, mode } => {
                    let p = self.usable(*src)?;
                    let mut ancestors = p.ancestors.clone();
                    if p.ty == Ty::Text && *mode == Mode::Write {
                        return Err("string bytes cannot be mutably borrowed".into());
                    }
                    let region = if p.ty.owned() {
                        0
                    } else {
                        let (m, r) = p.ty.reference().ok_or("borrow of nonstorage")?;
                        if *mode == Mode::Write && m != Mode::Write {
                            return Err("write reborrow from read view".into());
                        }
                        // A readonly byte-view descriptor is copied, not borrowed as storage.
                        // Preserve exclusive ancestors, but do not freeze the readonly carrier.
                        if m == Mode::Write {
                            ancestors.insert(p.loan);
                        }
                        r
                    };
                    for root in &p.roots {
                        let (mut reads, mut writes) =
                            self.access.get(root).copied().unwrap_or_default();
                        for ancestor in &ancestors {
                            if let Some((m, roots)) = self.loans.get(ancestor)
                                && roots.contains(root)
                            {
                                if *m == Mode::Read {
                                    reads -= 1;
                                } else {
                                    writes -= 1;
                                }
                            }
                        }
                        if writes > 0 || (*mode == Mode::Write && reads > 0) {
                            return Err("conflicting access".into());
                        }
                    }
                    let v = self.new_value(Ty::View(*mode, region), p.roots, ancestors);
                    self.put(*dst, v)?;
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
                    sig.validate()?;
                    if sig.params.len() != args.len() {
                        return Err("call arity".into());
                    }
                    let mut actuals = vec![];
                    let mut consumed = BTreeSet::new();
                    for (r, t) in args.iter().zip(&sig.params) {
                        let v = self.usable(*r)?;
                        let matches = match (&v.ty, t) {
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
                    let mut roots = BTreeSet::new();
                    let mut ancestors = BTreeSet::new();
                    if let Some((out_mode, out_r)) = sig.result.reference() {
                        for (t, v) in sig.params.iter().zip(&actuals) {
                            if let Some((m, r)) = t.reference()
                                && r == out_r
                                && (out_mode == Mode::Read || m == Mode::Write)
                            {
                                roots.extend(v.roots.clone());
                                ancestors.extend(v.ancestors.clone());
                            }
                        }
                    }
                    if sig.result.heap() {
                        roots.insert(Root::Local(*dst));
                    }
                    for r in consumed {
                        self.remove(r);
                    }
                    let v = self.new_value(sig.result.clone(), roots, ancestors);
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
    pub(crate) local_functions: Vec<Checked>,
    pub(crate) imports: BTreeMap<String, Sig>,
    pub(crate) types: BTreeMap<Reg, Ty>,
}
impl Checked {
    pub fn interface(&self) -> String {
        self.function.sig.encode().expect("validated signature")
    }
}
pub fn check(function: Function, imports: BTreeMap<String, Sig>) -> Result<Checked, String> {
    function.sig.validate()?;
    for (name, sig) in &imports {
        sig.validate()?;
        if name != &sig.name || name == &function.sig.name {
            return Err("invalid import key/self import".into());
        }
    }
    let mut s = State::parameters(&function.sig.params)?;
    let mut callable = imports.clone();
    callable.insert(function.sig.name.clone(), function.sig.clone());
    s.ops(&function.ops, &callable, 0)?;
    let result = s.usable(function.result)?;
    if s.values
        .iter()
        .any(|(r, v)| v.ty.heap() && *r != function.result)
    {
        return Err("heap owner must be ended or returned".into());
    }
    let compatible = match (&result.ty, &function.sig.result) {
        (Ty::Num, Ty::Num) | (Ty::Bytes, Ty::Bytes) | (Ty::Text, Ty::Text) => true,
        (Ty::View(m, _), Ty::View(n, _)) | (Ty::Holder(m, _), Ty::Holder(n, _)) => m == n,
        _ => false,
    };
    if !compatible {
        return Err("return type mismatch".into());
    }
    if let Some((mode, region)) = function.sig.result.reference() {
        for root in &result.roots {
            let Root::Param(i) = root else {
                return Err("local owner escapes".into());
            };
            let Some((m, r)) = function.sig.params[*i].reference() else {
                return Err("invalid return origin".into());
            };
            if r != region || (mode == Mode::Write && m != Mode::Write) {
                return Err("return violates written region relationship".into());
            }
        }
    }
    Ok(Checked {
        local_functions: Vec::new(),
        function,
        imports,
        types: s.types,
    })
}
