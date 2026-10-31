//! Grail bootstrap seed: checked IR and the first .grl source subset.
//! Reference values are currently affine; this is not a complete language implementation.
mod aggregate;
pub mod artifact;
pub mod driver;
pub mod emit;
pub mod fixture;
mod flow;
mod ir;
pub mod module;
mod reference;
mod sha256;
pub mod source;
mod specialize;
mod sum;
pub mod template;
mod ty;
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
    Named(String, Vec<u16>, Vec<Ty>),
    Param(u16),
    Unit,
    Buffer,
    Bytes,
    Text,
    View(Mode, u16),
    Holder(Mode, u16),
    Ref(Mode, u16, Box<Ty>),
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
        self.validate_bound(0)
    }
    pub(crate) fn validate_bound(&self, parameters: u16) -> Result<(), String> {
        if parameters > 64 {
            return Err("generic parameter limit".into());
        }
        if !(name_ok(&self.name) || qualified_ok(&self.name)) || self.params.len() > 64 {
            return Err("invalid signature name/arity".into());
        }
        for ty in self.params.iter().chain([&self.result]) {
            ty.validate_shape(parameters)?;
        }
        if let Some((mode, r)) = self.result.reference()
            && !self.params.iter().any(|t| matches!(t, Ty::Named(..)))
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
        self.encode_bound(0)
    }
    pub(crate) fn encode_bound(&self, parameters: u16) -> Result<String, String> {
        self.validate_bound(parameters)?;
        let text = format!(
            "grail-seed-interface-6\n{}\n{}\n{}\n",
            self.name,
            self.params
                .iter()
                .map(Ty::word)
                .collect::<Vec<_>>()
                .join(","),
            self.result.word()
        );
        if text.len() > 65536 {
            return Err("interface too large".into());
        }
        Ok(text)
    }
    pub fn decode(text: &str) -> Result<Self, String> {
        Self::decode_bound(text, 0)
    }
    pub(crate) fn decode_bound(text: &str, parameters: u16) -> Result<Self, String> {
        if text.len() > 65536 {
            return Err("interface too large".into());
        }
        let lines = text.lines().collect::<Vec<_>>();
        if lines.len() != 4 || lines[0] != "grail-seed-interface-6" {
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
        sig.validate_bound(parameters)?;
        if sig.encode_bound(parameters)? != text {
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
pub struct Arm {
    pub variant: String,
    pub binding: Option<Reg>,
    pub body: Vec<Op>,
}
#[derive(Clone, Debug)]
pub enum Op {
    Address {
        dst: Reg,
        src: Reg,
        path: Vec<String>,
        mode: Mode,
    },
    Load {
        dst: Reg,
        src: Reg,
    },
    Exchange {
        dst: Reg,
        src: Reg,
        value: Reg,
    },
    Return(Reg),
    Break,
    Continue,
    Num(Reg, u64),
    Unit(Reg),
    Variant {
        dst: Reg,
        ty: Ty,
        variant: usize,
        payload: Option<Reg>,
    },
    Unwrap {
        dst: Reg,
        src: Reg,
    },
    Match {
        src: Reg,
        arms: Vec<Arm>,
    },
    Record {
        dst: Reg,
        ty: Ty,
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
    GenericCall {
        dst: Reg,
        name: String,
        type_args: Option<Vec<Ty>>,
        args: Vec<Reg>,
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
    pub result: Option<Reg>,
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
    targets: BTreeSet<reference::Place>,
}
#[derive(Clone, Debug)]
struct State {
    signature: std::sync::Arc<Sig>,
    type_parameters: u16,
    plain_parameters: BTreeSet<u16>,
    generics: std::sync::Arc<BTreeMap<String, template::Signature>>,
    terminated: bool,
    loops: Vec<std::rc::Rc<flow::LoopFrame>>,
    layouts: types::Context,
    values: BTreeMap<Reg, Value>,
    memory: BTreeMap<Root, Value>,
    addressed: BTreeSet<Reg>,
    resources: BTreeSet<Reg>,
    next: usize,
    copy_defined: Vec<u64>,
    types: std::rc::Rc<std::cell::RefCell<BTreeMap<Reg, Ty>>>,
    access: BTreeMap<Root, (usize, usize)>,
    blocked: BTreeMap<usize, usize>,
}
impl State {
    fn parameters_bound(
        signature: &Sig,
        layouts: types::Context,
        parameters: u16,
    ) -> Result<Self, String> {
        let mut plain_parameters = BTreeSet::new();
        if parameters > 0 {
            for t in signature.params.iter().chain([&signature.result]) {
                plain_parameters.extend(types::required_plain(t, &layouts)?);
            }
        }
        let mut s = Self {
            plain_parameters,
            layouts,
            signature: std::sync::Arc::new(signature.clone()),
            type_parameters: parameters,
            generics: std::sync::Arc::new(BTreeMap::new()),
            terminated: false,
            loops: Vec::new(),
            values: BTreeMap::new(),
            memory: BTreeMap::new(),
            addressed: BTreeSet::new(),
            resources: BTreeSet::new(),
            next: 0,
            copy_defined: Vec::new(),
            types: std::rc::Rc::new(std::cell::RefCell::new(BTreeMap::new())),
            access: BTreeMap::new(),
            blocked: BTreeMap::new(),
        };
        for (i, t) in signature.params.iter().enumerate() {
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
        if self.place_borrowed(r, &[], true) {
            return Err("read of exclusively borrowed storage".into());
        }
        self.usable_value(v)?;
        Ok(v.clone())
    }
    fn put(&mut self, r: Reg, mut v: Value) -> Result<(), String> {
        if self.place_borrowed(r, &[], false) {
            return Err("overwrite of borrowed storage".into());
        }
        if r > 65535 {
            return Err("register limit".into());
        }
        if let Some(old) = self.values.get(&r)
            && (!old.ty.copy() || !v.ty.copy())
        {
            return Err(format!("r{r}: overwrite needs explicit end"));
        }
        if let Some(t) = self.types.borrow().get(&r)
            && *t != v.ty
        {
            return Err(format!("r{r}: register changes type"));
        }
        self.remove(r);
        reference::rename_owned(&mut v, &Root::Local(r, vec![]), &[]);
        self.types.borrow_mut().insert(r, v.ty.clone());
        if v.ty.copy() {
            self.mark_copy(r, true);
        }
        self.index_add(&v);
        if !v.ty.copy() {
            self.resources.insert(r);
        }
        self.values.insert(r, v);
        Ok(())
    }
    fn remove(&mut self, r: Reg) {
        self.mark_copy(r, false);
        if let Some(v) = self.values.remove(&r) {
            self.resources.remove(&r);
            self.index_remove(&v);
            self.retire_targets(&v);
        }
    }
    fn owner_borrowed(&self, v: &Value) -> bool {
        (v.ty.owned() && v.roots.iter().any(|r| self.access_conflict(r, false)))
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
            targets: BTreeSet::new(),
        }
    }
    fn num(&mut self, r: Reg) -> Result<(), String> {
        let v = self.new_value(Ty::Num, BTreeSet::new(), BTreeSet::new());
        self.put(r, v)
    }
    fn require_num(&self, r: Reg) -> Result<(), String> {
        self.usable(r)?;
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
        } else if matches!(&v.ty,Ty::Ref(_,_,t) if matches!(**t,Ty::Bytes|Ty::Text)) {
        } else if !matches!(v.ty, Ty::View(..) | Ty::Holder(..)) {
            return Err("expected byte storage or view".into());
        }
        Ok(())
    }
    fn end(&mut self, r: Reg) -> Result<(), String> {
        let v = self.get(r)?.clone();
        if self.place_borrowed(r, &[], false) {
            return Err("storage still borrowed".into());
        }
        // Default record drop destroys owned storage, not the referents of captured descriptors.
        if v.ty.reference().is_some() {
            self.usable_value(&v)?;
        }
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
            if !entry.contains_key(r) && !v.ty.copy() {
                return Err("block-local resource must end".into());
            }
        }
        for (r, v) in entry {
            let after = self.get(*r)?;
            if v.ty != after.ty || (!v.ty.copy() && v != after) {
                return Err("block changes entry ownership".into());
            }
        }
        Ok(())
    }
    fn call(&mut self, sig: &Sig, dst: Reg, args: &[Reg]) -> Result<(), String> {
        for t in sig.params.iter().chain([&sig.result]) {
            self.validate_kind(t)?;
        }
        if sig.params.len() != args.len() {
            return Err("call arity".into());
        }
        let mut actuals = Vec::new();
        let mut consumed = BTreeSet::new();
        for (r, t) in args.iter().zip(&sig.params) {
            let v = self.usable(*r)?;
            if !aggregate::compatible(t, &v.ty) {
                return Err("call argument type/mode".into());
            }
            if v.ty.owned() && self.owner_borrowed(&v) {
                return Err("call moves borrowed owner".into());
            }
            if !t.copy() && !consumed.insert(*r) {
                return Err("affine argument duplicated".into());
            }
            actuals.push(v);
        }
        let inputs = sig.params.iter().cloned().zip(actuals).collect::<Vec<_>>();
        let v = self.result_value(&sig.result, dst, &mut Vec::new(), &inputs)?;
        self.writeback(&inputs)?;
        for r in consumed {
            self.remove(r);
        }
        self.put(dst, v)
    }
    fn ops(
        &mut self,
        ops: &[Op],
        imports: &BTreeMap<String, Sig>,
        depth: usize,
    ) -> Result<(), String> {
        self.ops_inner(ops, imports, depth, None)
    }
    fn ops_inner(
        &mut self,
        ops: &[Op],
        imports: &BTreeMap<String, Sig>,
        depth: usize,
        out: Option<&BTreeSet<Reg>>,
    ) -> Result<(), String> {
        if depth > 64 {
            return Err("loop nesting limit".into());
        }
        let afters = out.map(|out| flow::afters(ops, out));
        for (position, op) in ops.iter().enumerate() {
            let after = afters.as_ref().map(|v| &v[position]);
            if self.terminated {
                return Err("unreachable operation after control transfer".into());
            }
            match op {
                Op::Address {
                    dst,
                    src,
                    path,
                    mode,
                } => self.address(*dst, *src, path, *mode)?,
                Op::Load { dst, src } => self.load_reference(*dst, *src)?,
                Op::Exchange { dst, src, value } => self.exchange(*dst, *src, *value)?,
                Op::Unit(r) => {
                    let v = self.new_value(Ty::Unit, BTreeSet::new(), BTreeSet::new());
                    self.put(*r, v)?;
                }
                Op::Variant {
                    dst,
                    ty,
                    variant,
                    payload,
                } => self.variant_value(*dst, ty, *variant, *payload)?,
                Op::Unwrap { dst, src } => {
                    let k = self.success(*src)?;
                    let unit = types::fields(&self.get(*src)?.ty, &self.layouts)?[k].1 == Ty::Unit;
                    self.payload(*src, k, if unit { None } else { Some(*dst) })?;
                    if unit {
                        let v = self.new_value(Ty::Unit, BTreeSet::new(), BTreeSet::new());
                        self.put(*dst, v)?;
                    }
                }
                Op::Match { src, arms } => {
                    let indices = self.arms(*src, arms)?;
                    let entry = self.clone();
                    let mut joined: Option<State> = None;
                    for (a, k) in arms.iter().zip(indices) {
                        let mut branch = entry.clone();
                        branch.payload(*src, k, a.binding)?;
                        branch.ops_inner(&a.body, imports, depth + 1, after)?;
                        if let Some(acc) = joined.take() {
                            self.join(acc, branch)?;
                            joined = Some(self.clone());
                        } else {
                            joined = Some(branch);
                        }
                    }
                    *self = joined.expect("nonempty exhaustive match");
                }

                Op::Break | Op::Continue => {
                    self.validate_loop_exit()?;
                    self.terminated = true;
                }
                Op::Return(r) => {
                    self.validate_return(*r)?;
                    self.terminated = true;
                }
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
                    let indirect = matches!(&v.ty,Ty::Ref(Mode::Write,_,t) if **t==Ty::Text);
                    if v.ty != Ty::Text && !indirect {
                        return Err("append_text expects owned string".into());
                    }
                    if !indirect && self.owner_borrowed(&v) {
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
                    let indirect = matches!(&v.ty,Ty::Ref(Mode::Write,_,t) if **t==Ty::Bytes);
                    if v.ty != Ty::Bytes && !indirect {
                        return Err("push expects owned bytes".into());
                    }
                    if !indirect && self.owner_borrowed(&v) {
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
                    let v = if matches!(p.ty, Ty::Ref(..)) {
                        self.borrow_reference_bytes(&p, *mode)?
                    } else {
                        self.borrow_value(p, *mode)?
                    };
                    self.put(*dst, v)?;
                }
                Op::Record { dst, ty, fields } => self.record_value(*dst, ty, fields)?,
                Op::FieldMove { dst, src, path } => self.field_move(*dst, *src, path)?,
                Op::FieldBorrow {
                    dst,
                    src,
                    path,
                    mode,
                } => {
                    if matches!(self.get(*src)?.ty, Ty::Ref(..)) {
                        let v = self.reference_field_bytes(*src, path, *mode)?;
                        self.put(*dst, v)?;
                        continue;
                    }
                    let (indices, _) = types::project(&self.get(*src)?.ty, path, &self.layouts)?;
                    if self.place_borrowed(*src, &indices, *mode == Mode::Read) {
                        return Err("borrow of restricted field storage".into());
                    }
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
                    if !matches!(self.get(*src)?.ty, Ty::View(..) | Ty::Holder(..)) {
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
                    let mut y = self.clone();
                    y.ops_inner(yes, imports, depth + 1, after)?;
                    let mut n = self.clone();
                    n.ops_inner(no, imports, depth + 1, after)?;
                    self.join(y, n)?;
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
                    if self.place_borrowed(*src, &[], v.ty.copy()) {
                        return Err("move/read of borrowed place".into());
                    }
                    if v.ty.owned() && self.owner_borrowed(&v) {
                        return Err("move of borrowed owner".into());
                    }
                    if !v.ty.copy() {
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
                    if !matches!(self.usable(*src)?.ty, Ty::View(..) | Ty::Holder(..)) {
                        return Err("read expects view".into());
                    }
                    self.require_num(*index)?;
                    self.num(*dst)?;
                }
                Op::Write { dst, index, value } => {
                    if !matches!(
                        self.usable(*dst)?.ty,
                        Ty::View(Mode::Write, _) | Ty::Holder(Mode::Write, _)
                    ) {
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
                Op::GenericCall {
                    dst,
                    name,
                    type_args,
                    args,
                } => {
                    let generic = self
                        .generics
                        .get(name)
                        .ok_or("unknown generic function")?
                        .clone();
                    let actual = args
                        .iter()
                        .map(|r| Ok(self.usable(*r)?.ty))
                        .collect::<Result<Vec<_>, String>>()?;
                    let types = generic.arguments(
                        &actual,
                        type_args.as_deref(),
                        self.type_parameters,
                        &self.layouts,
                    )?;
                    for t in &types {
                        self.validate_kind(t)?;
                    }
                    let sig = generic.instantiate(&types)?;
                    types::validate_sig_bound(&sig, &self.layouts, self.type_parameters)?;
                    self.call(&sig, *dst, args)?;
                }
                Op::Call { dst, name, args } => {
                    let sig = imports.get(name).ok_or("unknown imported function")?;
                    types::validate_sig_bound(sig, &self.layouts, self.type_parameters)?;
                    self.call(sig, *dst, args)?;
                }
                Op::Block { body } => {
                    let entry = self.resources.clone();
                    self.ops_inner(body, imports, depth + 1, after)?;
                    if !self.terminated {
                        self.validate_resource_frame(&entry)?;
                    }
                }
                Op::While {
                    condition,
                    test,
                    body,
                } => {
                    let entry = self.values.clone();
                    let entry_defined = self.copy_defined.clone();
                    let condition_out = after.map(|out| {
                        let mut live = self.scalars();
                        live.extend(out);
                        live.insert(*condition);
                        live
                    });
                    // A condition cannot jump out of a surrounding loop; only its nested loops
                    // introduce jump targets. Conditional function returns (e.g. `?`) remain valid.
                    let loops = std::mem::take(&mut self.loops);
                    self.ops_inner(test, imports, depth + 1, condition_out.as_ref())?;
                    self.loops = loops;
                    if self.terminated {
                        return Err("return in loop condition".into());
                    }
                    self.require_num(*condition)?;
                    self.validate_closed(&entry)?;
                    self.values = entry;
                    self.copy_defined = entry_defined;
                    let body_out = after.map(|out| {
                        let mut live = flow::live_before(op, out);
                        live.extend(out);
                        live
                    });
                    self.loop_body(body, None, imports, depth + 1, body_out.as_ref())?;
                }
                Op::Loop { index, end, body } => {
                    self.require_num(*end)?;
                    if index == end || self.values.contains_key(index) || self.copy_defined(*index)
                    {
                        return Err("loop index must be fresh".into());
                    }
                    self.loop_body(body, Some(*index), imports, depth + 1, after)?;
                }
            }
            if let Some(live) = after {
                self.prune_scalars(live);
            }
        }
        Ok(())
    }
}
/// Only this validated wrapper can reach native lowering.
#[derive(Clone)]
pub struct Checked {
    pub(crate) function: Function,
    pub(crate) imports: BTreeMap<String, Sig>,
    pub(crate) types: BTreeMap<Reg, Ty>,
    pub(crate) layouts: types::Context,
    pub(crate) return_tail: Option<Reg>,
    pub(crate) generics: std::sync::Arc<BTreeMap<String, template::Signature>>,
    pub(crate) type_parameters: u16,
}
impl Checked {
    pub fn interface(&self) -> String {
        self.function.sig.encode().expect("validated signature")
    }
}
pub fn check(function: Function, imports: BTreeMap<String, Sig>) -> Result<Checked, String> {
    check_with_types(function, imports, crate::types::Context::default())
}
pub fn check_with_types(
    function: Function,
    imports: BTreeMap<String, Sig>,
    layouts: types::Context,
) -> Result<Checked, String> {
    check_bound(function, imports, layouts, 0, BTreeMap::new())
}
fn check_bound(
    function: Function,
    imports: BTreeMap<String, Sig>,
    layouts: types::Context,
    parameters: u16,
    generics: BTreeMap<String, template::Signature>,
) -> Result<Checked, String> {
    types::validate_sig_bound(&function.sig, &layouts, parameters)?;
    for (name, sig) in &imports {
        types::validate_sig(sig, &layouts)?;
        if name != &sig.name || name == &function.sig.name {
            return Err("invalid import key/self import".into());
        }
    }
    for (name, g) in &generics {
        g.validate(&layouts)?;
        if name != &g.function.name {
            return Err("invalid generic import key".into());
        }
    }
    let mut s = State::parameters_bound(&function.sig, layouts.clone(), parameters)?;
    s.generics = std::sync::Arc::new(generics);
    let mut callable = imports.clone();
    callable.insert(function.sig.name.clone(), function.sig.clone());
    let tail_live = function.result.into_iter().collect();
    s.ops_inner(&function.ops, &callable, 0, Some(&tail_live))?;
    let return_tail = if s.terminated {
        None
    } else {
        let r = function
            .result
            .ok_or("function may fall through without return")?;
        s.validate_return(r)?;
        Some(r)
    };
    Ok(Checked {
        function,
        imports,
        types: std::rc::Rc::try_unwrap(s.types)
            .expect("body type ledger escaped")
            .into_inner(),
        layouts,
        return_tail,
        generics: s.generics,
        type_parameters: parameters,
    })
}
