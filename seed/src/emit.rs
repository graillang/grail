//! Checked IR lowering. Byte accesses and division are guarded; u64 arithmetic wraps.
use crate::{Bin, Checked, Op, Reg, Sig, Ty};
use std::collections::BTreeMap;
use std::fmt::Write;
fn cty(t: &Ty) -> &'static str {
    match t {
        Ty::Num => "uint64_t",
        Ty::Holder(..) => "gh",
        _ => "gv",
    }
}
fn signature(s: &Sig) -> String {
    format!(
        "{} g_{}({})",
        cty(&s.result),
        s.name,
        if s.params.is_empty() {
            "void".into()
        } else {
            s.params
                .iter()
                .enumerate()
                .map(|(i, t)| format!("{} r{i}", cty(t)))
                .collect::<Vec<_>>()
                .join(", ")
        }
    )
}
fn view(r: Reg, types: &BTreeMap<Reg, Ty>) -> String {
    if matches!(types[&r], Ty::Holder(..)) {
        format!("r{r}.value")
    } else {
        format!("r{r}")
    }
}
fn buffers(ops: &[Op], out: &mut BTreeMap<Reg, usize>) {
    for o in ops {
        match o {
            Op::Buffer { dst, len, .. } => {
                let v = out.entry(*dst).or_default();
                *v = (*v).max((*len).max(1));
            }
            Op::Loop { body, .. } => buffers(body, out),
            Op::If { yes, no, .. } => {
                buffers(yes, out);
                buffers(no, out);
            }
            _ => {}
        }
    }
}
pub fn c(p: &Checked) -> String {
    let mut s = String::from(
        "#include <stdint.h>\n#include <stdlib.h>\ntypedef struct { uint8_t *p; uint64_t n; } gv;\ntypedef struct { gv value; } gh;\n",
    );
    for sig in p.imports.values() {
        writeln!(s, "extern {};", signature(sig)).unwrap()
    }
    writeln!(s, "{} {{", signature(&p.function.sig)).unwrap();
    for (r, t) in &p.types {
        if *r as usize >= p.function.sig.params.len() {
            writeln!(s, "{} r{r};", cty(t)).unwrap()
        }
    }
    let mut bs = BTreeMap::new();
    buffers(&p.function.ops, &mut bs);
    for (r, len) in bs {
        writeln!(s, "uint8_t b{r}[{len}];").unwrap()
    }
    fn ops(s: &mut String, os: &[Op], types: &BTreeMap<Reg, Ty>) {
        for o in os {
            match o{
        Op::Num(r,n)=>{writeln!(s,"r{r} = UINT64_C({n});").unwrap()},
        Op::Buffer{dst,len,seed}=>{writeln!(s,"r{dst} = (gv){{b{dst}, UINT64_C({len})}};\nfor (uint64_t j=0; j<UINT64_C({len}); ++j) b{dst}[j]=(uint8_t)((j*UINT64_C(17)+UINT64_C({seed}))%UINT64_C(251));").unwrap()},
        Op::Borrow{dst,src,..}=>{writeln!(s,"r{dst} = {};",view(*src,types)).unwrap()},
        Op::Slice{dst,src,start,end}=>{let v=view(*src,types);writeln!(s,"if(r{start}>r{end} || r{end}>{v}.n) abort(); r{dst}=(gv){{{v}.p+r{start},r{end}-r{start}}};").unwrap()},
        Op::Assert(r)=>{writeln!(s,"if(!r{r}) abort();").unwrap()},
        Op::If{condition,yes,no}=>{writeln!(s,"if(r{condition}){{").unwrap();ops(s,yes,types);s.push_str("}else{\n");ops(s,no,types);s.push_str("}\n")},
        Op::Pack{dst,src}=>{writeln!(s,"r{dst} = (gh){{r{src}}};").unwrap()},
        Op::Move{dst,src}=>{writeln!(s,"r{dst}=r{src};").unwrap()},Op::End(_)=>{},
        Op::Len{dst,src}=>{writeln!(s,"r{dst}={}.n;",view(*src,types)).unwrap()},
        Op::Read{dst,src,index}=>{let v=view(*src,types);writeln!(s,"if (r{index}>={v}.n) abort(); r{dst}={v}.p[r{index}];").unwrap()},
        Op::Write{dst,index,value}=>{let v=view(*dst,types);writeln!(s,"if (r{index}>={v}.n) abort(); {v}.p[r{index}]=(uint8_t)r{value};").unwrap()},
        Op::Binary{dst,op,left,right}=>{let symbol=match op{Bin::Add=>"+",Bin::Sub=>"-",Bin::Lt=>"<",Bin::Mul=>"*",Bin::Xor=>"^",Bin::Rem=>"%",Bin::Eq=>"==",Bin::Ne=>"!=",Bin::And=>"&"};if matches!(op,Bin::Rem){writeln!(s,"if (!r{right}) abort();").unwrap()}writeln!(s,"r{dst}=r{left} {symbol} r{right};").unwrap()},
        Op::Call{dst,name,args}=>{writeln!(s,"r{dst}=g_{name}({});",args.iter().map(|r|format!("r{r}")).collect::<Vec<_>>().join(",")).unwrap()},
        Op::Loop{index,end,body}=>{writeln!(s,"for (r{index}=0; r{index}<r{end}; ++r{index}) {{").unwrap();ops(s,body,types);s.push_str("}\n")},
    }
        }
    }
    ops(&mut s, &p.function.ops, &p.types);
    writeln!(s, "return r{};\n}}", p.function.result).unwrap();
    s
}
fn lty(t: &Ty) -> &'static str {
    if *t == Ty::Num { "i64" } else { "{ ptr, i64 }" }
}
struct Ll {
    s: String,
    id: usize,
    types: BTreeMap<Reg, Ty>,
}
impl Ll {
    fn line(&mut self, s: impl AsRef<str>) {
        writeln!(self.s, "  {}", s.as_ref()).unwrap()
    }
    fn fresh(&mut self) -> String {
        self.id += 1;
        format!("v{}", self.id)
    }
    fn load(&mut self, r: Reg) -> String {
        let v = self.fresh();
        self.line(format!("%{v} = load {}, ptr %r{r}", lty(&self.types[&r])));
        format!("%{v}")
    }
    fn store(&mut self, r: Reg, v: &str) {
        self.line(format!("store {} {v}, ptr %r{r}", lty(&self.types[&r])))
    }
    fn field(&mut self, v: &str, n: usize) -> String {
        let x = self.fresh();
        self.line(format!("%{x} = extractvalue {{ ptr, i64 }} {v}, {n}"));
        format!("%{x}")
    }
    fn guard(&mut self, condition: &str) {
        let good = self.fresh();
        self.line(format!("br i1 {condition}, label %{good}, label %trap"));
        writeln!(self.s, "{good}:").unwrap()
    }
    fn address(&mut self, r: Reg, i: Reg) -> String {
        let v = self.load(r);
        let p = self.field(&v, 0);
        let n = self.field(&v, 1);
        let index = self.load(i);
        let cond = self.fresh();
        self.line(format!("%{cond} = icmp ult i64 {index}, {n}"));
        self.guard(&format!("%{cond}"));
        let ptr = self.fresh();
        self.line(format!("%{ptr} = getelementptr i8, ptr {p}, i64 {index}"));
        format!("%{ptr}")
    }
    fn ops(&mut self, os: &[Op]) {
        for o in os {
            match o {
                Op::Num(r, n) => self.store(*r, &n.to_string()),
                Op::Buffer { dst, len, seed } => {
                    let base = self.fresh();
                    self.line(format!(
                        "%{base} = insertvalue {{ ptr, i64 }} poison, ptr %b{dst}, 0"
                    ));
                    let aggregate = self.fresh();
                    self.line(format!(
                        "%{aggregate} = insertvalue {{ ptr, i64 }} %{base}, i64 {len}, 1"
                    ));
                    self.store(*dst, &format!("%{aggregate}"));
                    let head = self.fresh();
                    let body = self.fresh();
                    let done = self.fresh();
                    let idx = self.fresh();
                    self.line(format!("store i64 0, ptr %init{dst}"));
                    self.line(format!("br label %{head}"));
                    writeln!(self.s, "{head}:").unwrap();
                    self.line(format!("%{idx} = load i64, ptr %init{dst}"));
                    let cmp = self.fresh();
                    self.line(format!("%{cmp} = icmp ult i64 %{idx}, {len}"));
                    self.line(format!("br i1 %{cmp}, label %{body}, label %{done}"));
                    writeln!(self.s, "{body}:").unwrap();
                    let a = self.fresh();
                    let b = self.fresh();
                    let c = self.fresh();
                    let d = self.fresh();
                    let ptr = self.fresh();
                    self.line(format!("%{a} = mul i64 %{idx}, 17"));
                    self.line(format!("%{b} = add i64 %{a}, {seed}"));
                    self.line(format!("%{c} = urem i64 %{b}, 251"));
                    self.line(format!("%{d} = trunc i64 %{c} to i8"));
                    self.line(format!(
                        "%{ptr} = getelementptr i8, ptr %b{dst}, i64 %{idx}"
                    ));
                    self.line(format!("store i8 %{d}, ptr %{ptr}"));
                    let next = self.fresh();
                    self.line(format!("%{next} = add i64 %{idx}, 1"));
                    self.line(format!("store i64 %{next}, ptr %init{dst}"));
                    self.line(format!("br label %{head}"));
                    writeln!(self.s, "{done}:").unwrap();
                }
                Op::Borrow { dst, src, .. } | Op::Move { dst, src } | Op::Pack { dst, src } => {
                    let v = self.load(*src);
                    self.store(*dst, &v)
                }
                Op::End(_) => {}
                Op::Assert(r) => {
                    let value = self.load(*r);
                    let condition = self.fresh();
                    self.line(format!("%{condition} = icmp ne i64 {value}, 0"));
                    self.guard(&format!("%{condition}"));
                }
                Op::Slice {
                    dst,
                    src,
                    start,
                    end,
                } => {
                    let value = self.load(*src);
                    let ptr = self.field(&value, 0);
                    let len = self.field(&value, 1);
                    let a = self.load(*start);
                    let b = self.load(*end);
                    let x = self.fresh();
                    self.line(format!("%{x} = icmp ule i64 {a}, {b}"));
                    self.guard(&format!("%{x}"));
                    let x = self.fresh();
                    self.line(format!("%{x} = icmp ule i64 {b}, {len}"));
                    self.guard(&format!("%{x}"));
                    let p = self.fresh();
                    self.line(format!("%{p} = getelementptr i8, ptr {ptr}, i64 {a}"));
                    let n = self.fresh();
                    self.line(format!("%{n} = sub i64 {b}, {a}"));
                    let v = self.fresh();
                    self.line(format!(
                        "%{v} = insertvalue {{ptr,i64}} poison, ptr %{p}, 0"
                    ));
                    let w = self.fresh();
                    self.line(format!("%{w} = insertvalue {{ptr,i64}} %{v}, i64 %{n}, 1"));
                    self.store(*dst, &format!("%{w}"));
                }
                Op::If { condition, yes, no } => {
                    let v = self.load(*condition);
                    let c = self.fresh();
                    self.line(format!("%{c} = icmp ne i64 {v}, 0"));
                    let y = self.fresh();
                    let n = self.fresh();
                    let done = self.fresh();
                    self.line(format!("br i1 %{c}, label %{y}, label %{n}"));
                    writeln!(self.s, "{y}:").unwrap();
                    self.ops(yes);
                    self.line(format!("br label %{done}"));
                    writeln!(self.s, "{n}:").unwrap();
                    self.ops(no);
                    self.line(format!("br label %{done}"));
                    writeln!(self.s, "{done}:").unwrap();
                }
                Op::Len { dst, src } => {
                    let v = self.load(*src);
                    let n = self.field(&v, 1);
                    self.store(*dst, &n)
                }
                Op::Read { dst, src, index } => {
                    let p = self.address(*src, *index);
                    let b = self.fresh();
                    self.line(format!("%{b} = load i8, ptr {p}"));
                    let n = self.fresh();
                    self.line(format!("%{n} = zext i8 %{b} to i64"));
                    self.store(*dst, &format!("%{n}"))
                }
                Op::Write { dst, index, value } => {
                    let p = self.address(*dst, *index);
                    let v = self.load(*value);
                    let b = self.fresh();
                    self.line(format!("%{b} = trunc i64 {v} to i8"));
                    self.line(format!("store i8 %{b}, ptr {p}"))
                }
                Op::Binary {
                    dst,
                    op,
                    left,
                    right,
                } => {
                    let a = self.load(*left);
                    let b = self.load(*right);
                    if matches!(op, Bin::Rem) {
                        let cond = self.fresh();
                        self.line(format!("%{cond} = icmp ne i64 {b}, 0"));
                        self.guard(&format!("%{cond}"))
                    }
                    let x = self.fresh();
                    let opcode = match op {
                        Bin::Add => "add",
                        Bin::Sub => "sub",
                        Bin::Lt => "icmp ult",
                        Bin::Mul => "mul",
                        Bin::Xor => "xor",
                        Bin::Rem => "urem",
                        Bin::Eq => "icmp eq",
                        Bin::Ne => "icmp ne",
                        Bin::And => "and",
                    };
                    self.line(format!("%{x} = {opcode} i64 {a}, {b}"));
                    let value = if matches!(op, Bin::Eq | Bin::Ne | Bin::Lt) {
                        let wide = self.fresh();
                        self.line(format!("%{wide} = zext i1 %{x} to i64"));
                        format!("%{wide}")
                    } else {
                        format!("%{x}")
                    };
                    self.store(*dst, &value)
                }
                Op::Call { dst, name, args } => {
                    let values = args
                        .iter()
                        .map(|r| {
                            let v = self.load(*r);
                            format!("{} {v}", lty(&self.types[r]))
                        })
                        .collect::<Vec<_>>();
                    let x = self.fresh();
                    self.line(format!(
                        "%{x} = call {} @g_{name}({})",
                        lty(&self.types[dst]),
                        values.join(", ")
                    ));
                    self.store(*dst, &format!("%{x}"))
                }
                Op::Loop { index, end, body } => {
                    self.store(*index, "0");
                    let head = self.fresh();
                    let block = self.fresh();
                    let done = self.fresh();
                    self.line(format!("br label %{head}"));
                    writeln!(self.s, "{head}:").unwrap();
                    let a = self.load(*index);
                    let b = self.load(*end);
                    let cmp = self.fresh();
                    self.line(format!("%{cmp} = icmp ult i64 {a}, {b}"));
                    self.line(format!("br i1 %{cmp}, label %{block}, label %{done}"));
                    writeln!(self.s, "{block}:").unwrap();
                    self.ops(body);
                    let a = self.load(*index);
                    let next = self.fresh();
                    self.line(format!("%{next} = add i64 {a}, 1"));
                    self.store(*index, &format!("%{next}"));
                    self.line(format!("br label %{head}"));
                    writeln!(self.s, "{done}:").unwrap();
                }
            }
        }
    }
}
pub fn llvm(p: &Checked) -> String {
    let mut ll = Ll {
        s: "declare void @abort() noreturn\n".into(),
        id: 0,
        types: p.types.clone(),
    };
    for s in p.imports.values() {
        writeln!(
            ll.s,
            "declare {} @g_{}({})",
            lty(&s.result),
            s.name,
            s.params.iter().map(lty).collect::<Vec<_>>().join(", ")
        )
        .unwrap()
    }
    writeln!(
        ll.s,
        "define {} @g_{}({}) {{\nentry:",
        lty(&p.function.sig.result),
        p.function.sig.name,
        p.function
            .sig
            .params
            .iter()
            .enumerate()
            .map(|(i, t)| format!("{} %arg{i}", lty(t)))
            .collect::<Vec<_>>()
            .join(", ")
    )
    .unwrap();
    for (r, t) in &p.types {
        ll.line(format!("%r{r} = alloca {}", lty(t)))
    }
    let mut bs = BTreeMap::new();
    buffers(&p.function.ops, &mut bs);
    for (r, len) in bs {
        ll.line(format!("%b{r} = alloca [{len} x i8]"));
        ll.line(format!("%init{r} = alloca i64"))
    }
    for i in 0..p.function.sig.params.len() {
        ll.store(i as Reg, &format!("%arg{i}"))
    }
    ll.ops(&p.function.ops);
    let v = ll.load(p.function.result);
    ll.line(format!("ret {} {v}", lty(&p.function.sig.result)));
    ll.s.push_str("trap:\n  call void @abort()\n  unreachable\n}\n");
    ll.s
}
