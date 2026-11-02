//! Canonical, bounded checked-IR payloads. Decode rechecks definitions, never caller roots.
use crate::{Arm, Bin, Checked, Function, Mode, Op, Reg, Sig, template, types};
use std::collections::{BTreeMap, BTreeSet};
pub(crate) const MAX: usize = 16 * 1024 * 1024;
#[derive(Default)]
pub(crate) struct Writer {
    pub(crate) data: Vec<u8>,
    nodes: usize,
}
impl Writer {
    pub(crate) fn put(&mut self, data: &[u8]) -> Result<(), String> {
        let prefix = format!("{}:", data.len());
        if self.data.len() + prefix.len() + data.len() > MAX {
            return Err("template IR byte limit".into());
        }
        self.data.extend_from_slice(prefix.as_bytes());
        self.data.extend_from_slice(data);
        Ok(())
    }
    pub(crate) fn text(&mut self, s: &str) -> Result<(), String> {
        self.put(s.as_bytes())
    }
    pub(crate) fn num(&mut self, n: u64) -> Result<(), String> {
        self.text(&n.to_string())
    }
    fn regs(&mut self, regs: &[Reg]) -> Result<(), String> {
        self.num(regs.len() as u64)?;
        for r in regs {
            self.num(*r as u64)?;
        }
        Ok(())
    }
    fn optional(&mut self, r: Option<Reg>) -> Result<(), String> {
        self.num(r.is_some() as u64)?;
        if let Some(r) = r {
            self.num(r as u64)?;
        }
        Ok(())
    }
    fn path(&mut self, path: &[String]) -> Result<(), String> {
        self.num(path.len() as u64)?;
        for n in path {
            self.text(n)?;
        }
        Ok(())
    }
    fn mode(&mut self, m: Mode) -> Result<(), String> {
        self.text(if m == Mode::Read { "read" } else { "write" })
    }
    fn ops(&mut self, ops: &[Op], depth: usize) -> Result<(), String> {
        if depth > 64 || ops.len() > 65536 {
            return Err("template IR operation/depth limit".into());
        }
        self.nodes += ops.len();
        if self.nodes > 262144 {
            return Err("template IR node limit".into());
        }
        self.num(ops.len() as u64)?;
        for op in ops {
            match op {
                Op::FieldAssign { dst, path, src } => {
                    self.text("field-assign")?;
                    self.num(*dst as u64)?;
                    self.path(path)?;
                    self.num(*src as u64)?;
                }
                Op::Declare { dst, ty } => {
                    self.text("declare")?;
                    self.num(*dst as u64)?;
                    self.text(&ty.word())?;
                }
                Op::Assign { dst, src } => {
                    self.text("assign")?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                }
                Op::Vector { dst, element } => {
                    self.text("vector")?;
                    self.num(*dst as u64)?;
                    self.text(&element.word())?;
                }
                Op::VectorPush { dst, owner, value } => {
                    self.text("vector-push")?;
                    self.num(*dst as u64)?;
                    self.num(*owner as u64)?;
                    self.num(*value as u64)?;
                }
                Op::VectorPop { dst, owner } => {
                    self.text("vector-pop")?;
                    self.num(*dst as u64)?;
                    self.num(*owner as u64)?;
                }
                Op::VectorGet {
                    dst,
                    owner,
                    index,
                    mode,
                } => {
                    self.text("vector-get")?;
                    self.num(*dst as u64)?;
                    self.num(*owner as u64)?;
                    self.num(*index as u64)?;
                    self.mode(*mode)?;
                }
                Op::Ascribe { src, ty } => {
                    self.text("ascribe")?;
                    self.num(*src as u64)?;
                    self.text(&ty.word())?;
                }
                Op::Address {
                    dst,
                    src,
                    path,
                    mode,
                } => {
                    self.text("address")?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                    self.path(path)?;
                    self.mode(*mode)?;
                }
                Op::Load { dst, src } => {
                    self.text("load")?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                }
                Op::Exchange { dst, src, value } => {
                    self.text("exchange")?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                    self.num(*value as u64)?;
                }
                Op::Return(r)
                | Op::Unit(r)
                | Op::End(r)
                | Op::EndIfLive(r)
                | Op::EndCaptures(r)
                | Op::Assert(r) => {
                    self.text(match op {
                        Op::Return(_) => "return",
                        Op::Unit(_) => "unit",
                        Op::End(_) => "end",
                        Op::EndIfLive(_) => "end-if-live",
                        Op::EndCaptures(_) => "end-captures",
                        _ => "assert",
                    })?;
                    self.num(*r as u64)?;
                }
                Op::Break => self.text("break")?,
                Op::Continue => self.text("continue")?,
                Op::Num(r, n) => {
                    self.text("num")?;
                    self.num(*r as u64)?;
                    self.num(*n)?;
                }
                Op::Variant {
                    dst,
                    ty,
                    variant,
                    payload,
                } => {
                    self.text("variant")?;
                    self.num(*dst as u64)?;
                    self.text(&ty.word())?;
                    self.num(*variant as u64)?;
                    self.optional(*payload)?;
                }
                Op::Unwrap { dst, src }
                | Op::Text { dst, src }
                | Op::CopyBytes { dst, src }
                | Op::Pack { dst, src }
                | Op::Move { dst, src }
                | Op::Len { dst, src } => {
                    self.text(match op {
                        Op::Unwrap { .. } => "unwrap",
                        Op::Text { .. } => "text",
                        Op::CopyBytes { .. } => "copy",
                        Op::Pack { .. } => "pack",
                        Op::Move { .. } => "move",
                        _ => "len",
                    })?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                }
                Op::Match { src, arms } => {
                    self.text("match")?;
                    self.num(*src as u64)?;
                    self.num(arms.len() as u64)?;
                    for a in arms {
                        self.text(&a.variant)?;
                        self.optional(a.binding)?;
                        self.ops(&a.body, depth + 1)?;
                    }
                }
                Op::Record { dst, ty, fields } => {
                    self.text("record")?;
                    self.num(*dst as u64)?;
                    self.text(&ty.word())?;
                    self.num(fields.len() as u64)?;
                    for (n, r) in fields {
                        self.text(n)?;
                        self.num(*r as u64)?;
                    }
                }
                Op::FieldMove { dst, src, path } | Op::FieldBorrow { dst, src, path, .. } => {
                    self.text(if matches!(op, Op::FieldMove { .. }) {
                        "field"
                    } else {
                        "field-borrow"
                    })?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                    self.path(path)?;
                    if let Op::FieldBorrow { mode, .. } = op {
                        self.mode(*mode)?;
                    }
                }
                Op::TextLiteral { dst, data } => {
                    self.text("literal")?;
                    self.num(*dst as u64)?;
                    self.put(data)?;
                }
                Op::AppendText { owner, src } => {
                    self.text("append")?;
                    self.num(*owner as u64)?;
                    self.num(*src as u64)?;
                }
                Op::Bytes { dst } => {
                    self.text("bytes")?;
                    self.num(*dst as u64)?;
                }
                Op::Push { owner, value } => {
                    self.text("push")?;
                    self.num(*owner as u64)?;
                    self.num(*value as u64)?;
                }
                Op::Buffer { dst, len, seed } => {
                    self.text("buffer")?;
                    self.num(*dst as u64)?;
                    self.num(*len as u64)?;
                    self.num(*seed)?;
                }
                Op::Borrow { dst, src, mode } => {
                    self.text("borrow")?;
                    self.num(*dst as u64)?;
                    self.num(*src as u64)?;
                    self.mode(*mode)?;
                }
                Op::Slice {
                    dst,
                    src,
                    start,
                    end,
                } => {
                    self.text("slice")?;
                    for r in [dst, src, start, end] {
                        self.num(*r as u64)?;
                    }
                }
                Op::If { condition, yes, no } => {
                    self.text("if")?;
                    self.num(*condition as u64)?;
                    self.ops(yes, depth + 1)?;
                    self.ops(no, depth + 1)?;
                }
                Op::Read { dst, src, index } => {
                    self.text("read")?;
                    for r in [dst, src, index] {
                        self.num(*r as u64)?;
                    }
                }
                Op::Write { dst, index, value } => {
                    self.text("write")?;
                    for r in [dst, index, value] {
                        self.num(*r as u64)?;
                    }
                }
                Op::Binary {
                    dst,
                    op,
                    left,
                    right,
                } => {
                    self.text("binary")?;
                    self.num(*dst as u64)?;
                    self.text(match op {
                        Bin::Add => "add",
                        Bin::Sub => "sub",
                        Bin::Lt => "lt",
                        Bin::Mul => "mul",
                        Bin::Xor => "xor",
                        Bin::Rem => "rem",
                        Bin::Eq => "eq",
                        Bin::Ne => "ne",
                        Bin::And => "and",
                    })?;
                    self.num(*left as u64)?;
                    self.num(*right as u64)?;
                }
                Op::Call { dst, name, args }
                | Op::GenericCall {
                    dst, name, args, ..
                } => {
                    self.text(if matches!(op, Op::Call { .. }) {
                        "call"
                    } else {
                        "generic"
                    })?;
                    self.num(*dst as u64)?;
                    self.text(name)?;
                    if let Op::GenericCall { type_args, .. } = op {
                        self.num(type_args.is_some() as u64)?;
                        if let Some(ts) = type_args {
                            self.num(ts.len() as u64)?;
                            for t in ts {
                                self.text(&t.word())?;
                            }
                        }
                    }
                    self.regs(args)?;
                }
                Op::Block { body } => {
                    self.text("block")?;
                    self.ops(body, depth + 1)?;
                }
                Op::While {
                    condition,
                    test,
                    body,
                } => {
                    self.text("while")?;
                    self.num(*condition as u64)?;
                    self.ops(test, depth + 1)?;
                    self.ops(body, depth + 1)?;
                }
                Op::Loop { index, end, body } => {
                    self.text("loop")?;
                    self.num(*index as u64)?;
                    self.num(*end as u64)?;
                    self.ops(body, depth + 1)?;
                }
            }
        }
        Ok(())
    }
}
pub(crate) struct Reader<'a> {
    data: &'a [u8],
    at: usize,
    nodes: usize,
}
impl<'a> Reader<'a> {
    pub(crate) fn new(data: &'a [u8]) -> Result<Self, String> {
        if data.len() > MAX {
            return Err("template IR byte limit".into());
        }
        Ok(Self {
            data,
            at: 0,
            nodes: 0,
        })
    }
    pub(crate) fn get(&mut self) -> Result<&'a [u8], String> {
        let rest = &self.data[self.at..];
        let colon = rest
            .iter()
            .position(|b| *b == b':')
            .ok_or("truncated IR atom")?;
        if colon > 8 {
            return Err("IR atom length limit".into());
        }
        let digits = std::str::from_utf8(&rest[..colon]).map_err(|_| "invalid IR length")?;
        let n = digits.parse::<usize>().map_err(|_| "invalid IR length")?;
        if digits != n.to_string() {
            return Err("noncanonical IR length".into());
        }
        let start = self.at + colon + 1;
        let end = start
            .checked_add(n)
            .filter(|e| *e <= self.data.len())
            .ok_or("truncated IR bytes")?;
        self.at = end;
        Ok(&self.data[start..end])
    }
    pub(crate) fn text(&mut self) -> Result<String, String> {
        String::from_utf8(self.get()?.to_vec()).map_err(|_| "IR string is not UTF-8".into())
    }
    pub(crate) fn num(&mut self) -> Result<u64, String> {
        let s = self.text()?;
        let n = s.parse::<u64>().map_err(|_| "invalid IR integer")?;
        if n.to_string() != s {
            return Err("noncanonical IR integer".into());
        }
        Ok(n)
    }
    pub(crate) fn count(&mut self, max: usize) -> Result<usize, String> {
        let n = usize::try_from(self.num()?).map_err(|_| "IR count overflow")?;
        if n > max {
            return Err("IR count limit".into());
        }
        Ok(n)
    }
    pub(crate) fn done(&self) -> Result<(), String> {
        if self.at != self.data.len() {
            return Err("trailing IR bytes".into());
        }
        Ok(())
    }
    fn reg(&mut self) -> Result<Reg, String> {
        Ok(self.count(65535)? as Reg)
    }
    fn regs(&mut self) -> Result<Vec<Reg>, String> {
        let n = self.count(64)?;
        (0..n).map(|_| self.reg()).collect()
    }
    fn optional(&mut self) -> Result<Option<Reg>, String> {
        if self.count(1)? == 0 {
            Ok(None)
        } else {
            Ok(Some(self.reg()?))
        }
    }
    fn path(&mut self) -> Result<Vec<String>, String> {
        let n = self.count(64)?;
        (0..n).map(|_| self.text()).collect()
    }
    fn mode(&mut self) -> Result<Mode, String> {
        match self.text()?.as_str() {
            "read" => Ok(Mode::Read),
            "write" => Ok(Mode::Write),
            _ => Err("invalid IR mode".into()),
        }
    }
    fn ty(&mut self) -> Result<crate::Ty, String> {
        crate::Ty::parse(&self.text()?)
    }
    fn ops(&mut self, depth: usize) -> Result<Vec<Op>, String> {
        if depth > 64 {
            return Err("IR depth limit".into());
        }
        let n = self.count(65536)?;
        self.nodes += n;
        if self.nodes > 262144 {
            return Err("IR node limit".into());
        }
        let mut ops = Vec::new();
        for _ in 0..n {
            let tag = self.text()?;
            let op = match tag.as_str() {
                "ascribe" => Op::Ascribe {
                    src: self.reg()?,
                    ty: self.ty()?,
                },
                "address" => Op::Address {
                    dst: self.reg()?,
                    src: self.reg()?,
                    path: self.path()?,
                    mode: self.mode()?,
                },
                "load" => Op::Load {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "exchange" => Op::Exchange {
                    dst: self.reg()?,
                    src: self.reg()?,
                    value: self.reg()?,
                },

                "field-assign" => Op::FieldAssign {
                    dst: self.reg()?,
                    path: self.path()?,
                    src: self.reg()?,
                },
                "declare" => Op::Declare {
                    dst: self.reg()?,
                    ty: self.ty()?,
                },
                "assign" => Op::Assign {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "vector" => Op::Vector {
                    dst: self.reg()?,
                    element: self.ty()?,
                },
                "vector-push" => Op::VectorPush {
                    dst: self.reg()?,
                    owner: self.reg()?,
                    value: self.reg()?,
                },
                "vector-pop" => Op::VectorPop {
                    dst: self.reg()?,
                    owner: self.reg()?,
                },
                "vector-get" => Op::VectorGet {
                    dst: self.reg()?,
                    owner: self.reg()?,
                    index: self.reg()?,
                    mode: self.mode()?,
                },
                "return" => Op::Return(self.reg()?),
                "unit" => Op::Unit(self.reg()?),
                "end" => Op::End(self.reg()?),
                "end-if-live" => Op::EndIfLive(self.reg()?),
                "end-captures" => Op::EndCaptures(self.reg()?),
                "assert" => Op::Assert(self.reg()?),
                "break" => Op::Break,
                "continue" => Op::Continue,
                "num" => Op::Num(self.reg()?, self.num()?),
                "variant" => Op::Variant {
                    dst: self.reg()?,
                    ty: self.ty()?,
                    variant: self.count(63)?,
                    payload: self.optional()?,
                },
                "unwrap" => Op::Unwrap {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "text" => Op::Text {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "copy" => Op::CopyBytes {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "pack" => Op::Pack {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "move" => Op::Move {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "len" => Op::Len {
                    dst: self.reg()?,
                    src: self.reg()?,
                },
                "match" => {
                    let src = self.reg()?;
                    let n = self.count(64)?;
                    let mut arms = Vec::new();
                    for _ in 0..n {
                        arms.push(Arm {
                            variant: self.text()?,
                            binding: self.optional()?,
                            body: self.ops(depth + 1)?,
                        });
                    }
                    Op::Match { src, arms }
                }
                "record" => {
                    let dst = self.reg()?;
                    let ty = self.ty()?;
                    let n = self.count(64)?;
                    let mut fields = Vec::new();
                    for _ in 0..n {
                        fields.push((self.text()?, self.reg()?));
                    }
                    Op::Record { dst, ty, fields }
                }
                "field" => Op::FieldMove {
                    dst: self.reg()?,
                    src: self.reg()?,
                    path: self.path()?,
                },
                "field-borrow" => Op::FieldBorrow {
                    dst: self.reg()?,
                    src: self.reg()?,
                    path: self.path()?,
                    mode: self.mode()?,
                },
                "literal" => Op::TextLiteral {
                    dst: self.reg()?,
                    data: self.get()?.to_vec(),
                },
                "append" => Op::AppendText {
                    owner: self.reg()?,
                    src: self.reg()?,
                },
                "bytes" => Op::Bytes { dst: self.reg()? },
                "push" => Op::Push {
                    owner: self.reg()?,
                    value: self.reg()?,
                },
                "buffer" => Op::Buffer {
                    dst: self.reg()?,
                    len: self.count(1024 * 1024)?,
                    seed: self.num()?,
                },
                "borrow" => Op::Borrow {
                    dst: self.reg()?,
                    src: self.reg()?,
                    mode: self.mode()?,
                },
                "slice" => Op::Slice {
                    dst: self.reg()?,
                    src: self.reg()?,
                    start: self.reg()?,
                    end: self.reg()?,
                },
                "if" => Op::If {
                    condition: self.reg()?,
                    yes: self.ops(depth + 1)?,
                    no: self.ops(depth + 1)?,
                },
                "read" => Op::Read {
                    dst: self.reg()?,
                    src: self.reg()?,
                    index: self.reg()?,
                },
                "write" => Op::Write {
                    dst: self.reg()?,
                    index: self.reg()?,
                    value: self.reg()?,
                },
                "binary" => {
                    let dst = self.reg()?;
                    let op = match self.text()?.as_str() {
                        "add" => Bin::Add,
                        "sub" => Bin::Sub,
                        "lt" => Bin::Lt,
                        "mul" => Bin::Mul,
                        "xor" => Bin::Xor,
                        "rem" => Bin::Rem,
                        "eq" => Bin::Eq,
                        "ne" => Bin::Ne,
                        "and" => Bin::And,
                        _ => return Err("invalid IR binary operator".into()),
                    };
                    Op::Binary {
                        dst,
                        op,
                        left: self.reg()?,
                        right: self.reg()?,
                    }
                }
                "call" => Op::Call {
                    dst: self.reg()?,
                    name: self.text()?,
                    args: self.regs()?,
                },
                "generic" => {
                    let dst = self.reg()?;
                    let name = self.text()?;
                    let type_args = if self.count(1)? == 0 {
                        None
                    } else {
                        let n = self.count(64)?;
                        Some((0..n).map(|_| self.ty()).collect::<Result<_, _>>()?)
                    };
                    Op::GenericCall {
                        dst,
                        name,
                        type_args,
                        args: self.regs()?,
                    }
                }
                "block" => Op::Block {
                    body: self.ops(depth + 1)?,
                },
                "while" => Op::While {
                    condition: self.reg()?,
                    test: self.ops(depth + 1)?,
                    body: self.ops(depth + 1)?,
                },
                "loop" => Op::Loop {
                    index: self.reg()?,
                    end: self.reg()?,
                    body: self.ops(depth + 1)?,
                },
                _ => return Err("unknown IR operation".into()),
            };
            ops.push(op);
        }
        Ok(ops)
    }
}
fn generic_names(ops: &[Op], out: &mut BTreeSet<String>) {
    for op in ops {
        match op {
            Op::GenericCall { name, .. } => {
                out.insert(name.clone());
            }
            Op::If { yes, no, .. } => {
                generic_names(yes, out);
                generic_names(no, out);
            }
            Op::Match { arms, .. } => {
                for a in arms {
                    generic_names(&a.body, out);
                }
            }
            Op::Block { body } | Op::Loop { body, .. } => generic_names(body, out),
            Op::While { test, body, .. } => {
                generic_names(test, out);
                generic_names(body, out);
            }
            _ => {}
        }
    }
}
pub(crate) fn encode(p: &Checked) -> Result<Vec<u8>, String> {
    let mut w = Writer::default();
    w.text("grail-seed-checked-ir-3")?;
    w.num(p.type_parameters as u64)?;
    w.text(&p.function.sig.encode_bound(p.type_parameters)?)?;
    w.num(p.imports.len() as u64)?;
    for s in p.imports.values() {
        w.text(&s.encode()?)?;
    }
    let mut used = BTreeSet::new();
    generic_names(&p.function.ops, &mut used);
    w.num(used.len() as u64)?;
    for n in used {
        w.text(
            &p.generics
                .get(&n)
                .ok_or("missing generic IR contract")?
                .encode()?,
        )?;
    }
    w.ops(&p.function.ops, 0)?;
    w.optional(p.function.result)?;
    Ok(w.data)
}
pub(crate) fn decode(data: &[u8], layouts: types::Context) -> Result<Checked, String> {
    let mut r = Reader::new(data)?;
    if r.text()? != "grail-seed-checked-ir-3" {
        return Err("invalid checked IR schema".into());
    }
    let parameters = r.count(64)? as u16;
    let sig = Sig::decode_bound(&r.text()?, parameters)?;
    let n = r.count(4096)?;
    let mut imports = BTreeMap::new();
    for _ in 0..n {
        let s = Sig::decode(&r.text()?)?;
        if imports.insert(s.name.clone(), s).is_some() {
            return Err("duplicate IR import".into());
        }
    }
    let n = r.count(4096)?;
    let mut generics = BTreeMap::new();
    for _ in 0..n {
        let s = template::Signature::decode(&r.text()?)?;
        if generics.insert(s.function.name.clone(), s).is_some() {
            return Err("duplicate IR generic".into());
        }
    }
    let ops = r.ops(0)?;
    let result = r.optional()?;
    r.done()?;
    let checked = crate::check_bound(
        Function { sig, ops, result },
        imports,
        layouts,
        parameters,
        generics,
    )?;
    if encode(&checked)? != data {
        return Err("noncanonical checked IR".into());
    }
    Ok(checked)
}

pub(crate) fn write_layouts(w: &mut Writer, defs: &types::Definitions) -> Result<(), String> {
    w.num(defs.len() as u64)?;
    for (n, d) in defs {
        w.text(n)?;
        w.text(d.kind.word())?;
        w.num(d.regions as u64)?;
        w.num(d.parameters as u64)?;
        w.num(d.fields.len() as u64)?;
        for (n, t) in &d.fields {
            w.text(n)?;
            w.text(&t.word())?;
        }
    }
    Ok(())
}
pub(crate) fn read_layouts(r: &mut Reader<'_>) -> Result<types::Context, String> {
    let n = r.count(4096)?;
    let mut defs = BTreeMap::new();
    for _ in 0..n {
        let name = r.text()?;
        let kind = match r.text()?.as_str() {
            "record" => types::Kind::Record,
            "enum" => types::Kind::Enum,
            _ => return Err("invalid IR layout kind".into()),
        };
        let regions = r.count(64)? as u16;
        let parameters = r.count(64)? as u16;
        let count = r.count(64)?;
        let mut fields = Vec::new();
        for _ in 0..count {
            fields.push((r.text()?, crate::Ty::parse(&r.text()?)?));
        }
        if defs
            .insert(
                name,
                types::Definition {
                    kind,
                    regions,
                    parameters,
                    fields,
                },
            )
            .is_some()
        {
            return Err("duplicate IR layout".into());
        }
    }
    types::Context::new(defs)
}
pub(crate) fn operation_count(ops: &[Op]) -> usize {
    ops.iter()
        .map(|op| {
            1 + match op {
                Op::If { yes, no, .. } => operation_count(yes) + operation_count(no),
                Op::Match { arms, .. } => arms.iter().map(|a| operation_count(&a.body)).sum(),
                Op::Block { body } | Op::Loop { body, .. } => operation_count(body),
                Op::While { test, body, .. } => operation_count(test) + operation_count(body),
                _ => 0,
            }
        })
        .sum()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn supported_concrete_ir_roundtrips_without_changing_c() {
        for source in [
            include_str!("../examples/loops/control.grl"),
            include_str!("../examples/loops/cleanup.grl"),
            r#"module all;enum R{Ok(num),Err(string)}struct Pair{first:string,second:string}pub fn run<a>(input:read<a>,n:num)->R{let unit=();let stack=buffer(4,7);let v=read(stack);let part=slice(v,0,1);let held=hold(part);let view=read(held);let value=at(view,0);let text=text(input);append_text(text,"\x00");let pair=Pair{first:text,second:"tail"};let first=pair.first;let b=bytes();push(b,value);let w=mut(b);write(w,0,n);let copied=copy_bytes(read(b));let result=R::Ok(helper(len(first)+len(copied)));match result{Ok(x)=>{return R::Ok(x);},Err(e)=>{return R::Err(e);}}}fn helper(n:num)->num{assert(1);let a=(n+2)*3;let b=(a-1)^4;let c=b&255;let d=c%7;if d!=0{return d;}return 0;}"#,
        ] {
            let module = crate::source::compile(source, BTreeMap::new()).unwrap();
            for (body, _) in &module.functions {
                let encoded = encode(body).unwrap();
                let recovered = decode(&encoded, module.layouts.clone()).unwrap();
                assert_eq!(encode(&recovered).unwrap(), encoded);
                assert_eq!(crate::emit::c(body), crate::emit::c(&recovered));
            }
        }
    }
}
