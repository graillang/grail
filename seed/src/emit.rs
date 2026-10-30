//! Checked IR lowering. Byte accesses and division are guarded; u64 arithmetic wraps.
use crate::{Bin, Checked, Op, Reg, Sig, Ty};
use std::collections::BTreeMap;
use std::fmt::Write;
/// Distinct prefixes and component lengths keep qualified names disjoint from plain symbols.
pub fn symbol(name: &str) -> String {
    if let Some((module, member)) = name.split_once("::") {
        format!("q_{}_{}_{}_{}", module.len(), module, member.len(), member)
    } else {
        format!("g_{name}")
    }
}
fn cty(t: &Ty) -> String {
    match t {
        Ty::Num => "uint64_t".into(),
        Ty::Record(n, _) => format!("t_{}", symbol(n)),
        Ty::Bytes | Ty::Text => "gb".into(),
        Ty::Holder(..) => "gh".into(),
        _ => "gv".into(),
    }
}
fn signature(s: &Sig) -> String {
    format!(
        "{} {}({})",
        cty(&s.result),
        symbol(&s.name),
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
fn field_expr(r: Reg, path: &[usize]) -> String {
    format!(
        "r{r}{}",
        path.iter().map(|i| format!(".f{i}")).collect::<String>()
    )
}
fn owned_paths(t: &Ty, records: &crate::types::Definitions) -> Vec<Vec<usize>> {
    if !matches!(t, Ty::Record(..)) {
        return Vec::new();
    }
    crate::types::leaves(t, records)
        .unwrap()
        .into_iter()
        .filter_map(|(p, t)| t.heap().then_some(p))
        .collect()
}
fn record_flags(s: &mut String, r: Reg, t: &Ty, records: &crate::types::Definitions, live: bool) {
    for i in 0..owned_paths(t, records).len() {
        writeln!(s, "r{r}_live[{i}]={};", u8::from(live)).unwrap();
    }
}
fn view_expr(value: String, t: &Ty) -> String {
    if t.heap() {
        format!("((gv){{{value}.p,{value}.n}})")
    } else if matches!(t, Ty::Holder(..)) {
        format!("{value}.value")
    } else {
        value
    }
}
fn view(r: Reg, types: &BTreeMap<Reg, Ty>) -> String {
    if types[&r].heap() {
        return format!("((gv){{r{r}.p,r{r}.n}})");
    }
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
            Op::Loop { body, .. } | Op::Block { body } => buffers(body, out),
            Op::While { test, body, .. } => {
                buffers(test, out);
                buffers(body, out);
            }
            Op::If { yes, no, .. } => {
                buffers(yes, out);
                buffers(no, out);
            }
            _ => {}
        }
    }
}
pub fn c(p: &Checked) -> String {
    c_functions(&[(p, true)], &p.records)
}
pub fn module_c(p: &crate::module::CheckedModule) -> String {
    c_functions(
        &p.functions
            .iter()
            .map(|(p, public)| (p, *public))
            .collect::<Vec<_>>(),
        &p.records,
    )
}
fn c_functions(functions: &[(&Checked, bool)], records: &crate::types::Definitions) -> String {
    let mut s = String::from(
        "#include <stdint.h>\n#include <stdlib.h>\n#include <string.h>\ntypedef struct { uint8_t *p; uint64_t n; } gv;\ntypedef struct { gv value; } gh;\ntypedef struct {uint8_t*p;uint64_t n,c;} gb;\n#define GRAIL_BYTES_TYPES_DEFINED\n",
    );
    for n in crate::types::order(records).expect("checked layouts") {
        let d = &records[&n];
        writeln!(s, "typedef struct {{").unwrap();
        if d.fields.is_empty() {
            s.push_str("uint8_t unit;\n");
        }
        for (i, (_, t)) in d.fields.iter().enumerate() {
            writeln!(s, "{} f{i};", cty(t)).unwrap();
        }
        writeln!(s, "}} t_{};", symbol(&n)).unwrap();
    }
    if functions
        .iter()
        .any(|(p, _)| p.types.values().any(|t| t.heap()))
    {
        s.push_str(include_str!("bytes_runtime.h"));
    }
    let locals = functions
        .iter()
        .map(|(p, public)| (p.function.sig.name.as_str(), *public))
        .collect::<BTreeMap<_, _>>();
    let mut declarations = BTreeMap::new();
    for (p, _) in functions {
        declarations.extend(p.imports.iter().map(|(n, s)| (n.clone(), s.clone())));
        declarations.insert(p.function.sig.name.clone(), p.function.sig.clone());
    }
    for sig in declarations.values() {
        let private = locals.get(sig.name.as_str()) == Some(&false);
        writeln!(
            s,
            "{} {};",
            if private { "static" } else { "extern" },
            signature(sig)
        )
        .unwrap();
    }
    for (p, public) in functions {
        c_body(p, &mut s, !public);
    }
    s
}
fn c_body(p: &Checked, s: &mut String, private: bool) {
    writeln!(
        s,
        "{}{} {{",
        if private { "static " } else { "" },
        signature(&p.function.sig)
    )
    .unwrap();
    for (r, t) in &p.types {
        if *r as usize >= p.function.sig.params.len() {
            writeln!(s, "{} r{r};", cty(t)).unwrap()
        }
    }
    for (r, t) in &p.types {
        if matches!(t, Ty::Record(..)) {
            let count = owned_paths(t, &p.records).len().max(1);
            writeln!(s, "uint8_t r{r}_live[{count}]={{0}};").unwrap();
            if (*r as usize) < p.function.sig.params.len() {
                record_flags(s, *r, t, &p.records, true);
            }
        }
    }
    let mut bs = BTreeMap::new();
    buffers(&p.function.ops, &mut bs);
    for (r, len) in bs {
        writeln!(s, "uint8_t b{r}[{len}];").unwrap()
    }
    fn ops(
        s: &mut String,
        os: &[Op],
        types: &BTreeMap<Reg, Ty>,
        records: &crate::types::Definitions,
    ) {
        for o in os {
            match o{
        Op::Return(r)=>{writeln!(s,"return r{r};").unwrap()},
        Op::Record{dst,name,fields}=>{
            writeln!(s,"r{dst}=({}){{0}};",cty(&types[dst])).unwrap();
            for(field,src)in fields{let i=records[name].fields.iter().position(|f|f.0==*field).unwrap();writeln!(s,"r{dst}.f{i}=r{src};").unwrap();record_flags(s,*src,&types[src],records,false);}
            record_flags(s,*dst,&types[dst],records,true);
        },
        Op::FieldMove{dst,src,path}=>{
            let(indices,_)=crate::types::project(&types[src],path,records).unwrap();let value=field_expr(*src,&indices);writeln!(s,"r{dst}={value};").unwrap();
            for(i,field)in owned_paths(&types[src],records).iter().enumerate(){if field.starts_with(&indices){writeln!(s,"r{src}_live[{i}]=0;").unwrap();}}
            record_flags(s,*dst,&types[dst],records,true);
        },
        Op::FieldBorrow{dst,src,path,..}=>{let(indices,t)=crate::types::project(&types[src],path,records).unwrap();writeln!(s,"r{dst}={};",view_expr(field_expr(*src,&indices),&t)).unwrap();},
        Op::EndCaptures(_)=>{},
        Op::TextLiteral{dst,data}=>{let values=if data.is_empty(){"0".into()}else{data.iter().map(u8::to_string).collect::<Vec<_>>().join(",")};writeln!(s,"{{static const uint8_t text[]={{ {values} }};r{dst}=gr_copy_bytes((gv){{(uint8_t*)text,UINT64_C({})}});}}",data.len()).unwrap()},
        Op::Text{dst,src}=>{let v=view(*src,types);writeln!(s,"gr_utf8({v});r{dst}=gr_copy_bytes({v});").unwrap()},
        Op::AppendText{owner,src}=>{writeln!(s,"gr_append_text(&r{owner},{});",view(*src,types)).unwrap()},
        Op::Bytes{dst}=>{writeln!(s,"r{dst}=(gb){{0,0,0}};").unwrap()},
        Op::CopyBytes{dst,src}=>{writeln!(s,"r{dst}=gr_copy_bytes({});",view(*src,types)).unwrap()},
        Op::Push{owner,value}=>{writeln!(s,"gr_push(&r{owner},r{value});").unwrap()},
        Op::Num(r,n)=>{writeln!(s,"r{r} = UINT64_C({n});").unwrap()},
        Op::Buffer{dst,len,seed}=>{writeln!(s,"r{dst} = (gv){{b{dst}, UINT64_C({len})}};\nfor (uint64_t j=0; j<UINT64_C({len}); ++j) b{dst}[j]=(uint8_t)((j*UINT64_C(17)+UINT64_C({seed}))%UINT64_C(251));").unwrap()},
        Op::Borrow{dst,src,..}=>{writeln!(s,"r{dst} = {};",view(*src,types)).unwrap()},
        Op::Slice{dst,src,start,end}=>{let v=view(*src,types);writeln!(s,"if(r{start}>r{end} || r{end}>{v}.n) abort(); r{dst}=(gv){{r{start}?{v}.p+r{start}:{v}.p,r{end}-r{start}}};").unwrap()},
        Op::Assert(r)=>{writeln!(s,"if(!r{r}) abort();").unwrap()},
        Op::If{condition,yes,no}=>{writeln!(s,"if(r{condition}){{").unwrap();ops(s,yes,types,records);s.push_str("}else{\n");ops(s,no,types,records);s.push_str("}\n")},
        Op::Pack{dst,src}=>{writeln!(s,"r{dst} = (gh){{r{src}}};").unwrap()},
        Op::Move{dst,src}=>{writeln!(s,"r{dst}=r{src};").unwrap();record_flags(s,*dst,&types[dst],records,true);record_flags(s,*src,&types[src],records,false);},
        Op::End(r)=>{if types[r].heap(){writeln!(s,"free(r{r}.p);").unwrap();}else{for(i,path)in owned_paths(&types[r],records).iter().enumerate(){writeln!(s,"if(r{r}_live[{i}]){{free({}.p);r{r}_live[{i}]=0;}}",field_expr(*r,path)).unwrap();}}},
        Op::Len{dst,src}=>{writeln!(s,"r{dst}={}.n;",view(*src,types)).unwrap()},
        Op::Read{dst,src,index}=>{let v=view(*src,types);writeln!(s,"if (r{index}>={v}.n) abort(); r{dst}={v}.p[r{index}];").unwrap()},
        Op::Write{dst,index,value}=>{let v=view(*dst,types);writeln!(s,"if (r{index}>={v}.n) abort(); {v}.p[r{index}]=(uint8_t)r{value};").unwrap()},
        Op::Binary{dst,op,left,right}=>{let symbol=match op{Bin::Add=>"+",Bin::Sub=>"-",Bin::Lt=>"<",Bin::Mul=>"*",Bin::Xor=>"^",Bin::Rem=>"%",Bin::Eq=>"==",Bin::Ne=>"!=",Bin::And=>"&"};if matches!(op,Bin::Rem){writeln!(s,"if (!r{right}) abort();").unwrap()}writeln!(s,"r{dst}=r{left} {symbol} r{right};").unwrap()},
        Op::Call{dst,name,args}=>{writeln!(s,"r{dst}={}({});",symbol(name),args.iter().map(|r|format!("r{r}")).collect::<Vec<_>>().join(",")).unwrap();for r in args{record_flags(s,*r,&types[r],records,false);}record_flags(s,*dst,&types[dst],records,true);},
        Op::Block{body}=>{s.push_str("{\n");ops(s,body,types,records);s.push_str("}\n")},
        Op::While{condition,test,body}=>{s.push_str("while(1){\n");ops(s,test,types,records);writeln!(s,"if(!r{condition})break;").unwrap();ops(s,body,types,records);s.push_str("}\n")},
        Op::Loop{index,end,body}=>{writeln!(s,"for (r{index}=0; r{index}<r{end}; ++r{index}) {{").unwrap();ops(s,body,types,records);s.push_str("}\n")},
    }
        }
    }
    ops(s, &p.function.ops, &p.types, &p.records);
    if let Some(r) = p.return_tail {
        writeln!(s, "return r{r};").unwrap();
    }
    s.push_str("}\n");
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
    fn ops(&mut self, os: &[Op]) -> bool {
        for o in os {
            match o {
                Op::Return(r) => {
                    let v = self.load(*r);
                    self.line(format!("ret {} {v}", lty(&self.types[r])));
                    return false;
                }
                Op::Record { .. }
                | Op::FieldMove { .. }
                | Op::FieldBorrow { .. }
                | Op::EndCaptures(..)
                | Op::Bytes { .. }
                | Op::CopyBytes { .. }
                | Op::Push { .. }
                | Op::Text { .. }
                | Op::TextLiteral { .. }
                | Op::AppendText { .. } => {
                    unreachable!("heap layouts rejected before LLVM lowering")
                }
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
                    let y_cont = self.ops(yes);
                    if y_cont {
                        self.line(format!("br label %{done}"));
                    }
                    writeln!(self.s, "{n}:").unwrap();
                    let n_cont = self.ops(no);
                    if n_cont {
                        self.line(format!("br label %{done}"));
                    }
                    if y_cont || n_cont {
                        writeln!(self.s, "{done}:").unwrap();
                    } else {
                        return false;
                    }
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
                        "%{x} = call {} @{}({})",
                        lty(&self.types[dst]),
                        symbol(name),
                        values.join(", ")
                    ));
                    self.store(*dst, &format!("%{x}"))
                }
                Op::Block { body } => {
                    if !self.ops(body) {
                        return false;
                    }
                }
                Op::While {
                    condition,
                    test,
                    body,
                } => {
                    let head = self.fresh();
                    let block = self.fresh();
                    let done = self.fresh();
                    self.line(format!("br label %{head}"));
                    writeln!(self.s, "{head}:").unwrap();
                    assert!(self.ops(test), "checked loop condition");
                    let value = self.load(*condition);
                    let cmp = self.fresh();
                    self.line(format!("%{cmp} = icmp ne i64 {value}, 0"));
                    self.line(format!("br i1 %{cmp}, label %{block}, label %{done}"));
                    writeln!(self.s, "{block}:").unwrap();
                    if self.ops(body) {
                        self.line(format!("br label %{head}"));
                    }
                    writeln!(self.s, "{done}:").unwrap();
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
                    if self.ops(body) {
                        let a = self.load(*index);
                        let next = self.fresh();
                        self.line(format!("%{next} = add i64 {a}, 1"));
                        self.store(*index, &format!("%{next}"));
                        self.line(format!("br label %{head}"));
                    }
                    writeln!(self.s, "{done}:").unwrap();
                }
            }
        }
        true
    }
}
pub fn llvm(p: &Checked) -> Result<String, String> {
    llvm_functions(&[(p, true)])
}
pub fn module_llvm(p: &crate::module::CheckedModule) -> Result<String, String> {
    llvm_functions(
        &p.functions
            .iter()
            .map(|(p, public)| (p, *public))
            .collect::<Vec<_>>(),
    )
}
fn llvm_functions(functions: &[(&Checked, bool)]) -> Result<String, String> {
    if functions.iter().any(|(p, _)| {
        p.types
            .values()
            .chain(
                p.imports
                    .values()
                    .flat_map(|s| s.params.iter().chain([&s.result])),
            )
            .any(|t| t.heap() || matches!(t, Ty::Record(..)))
    }) {
        return Err(
            "LLVM comparison backend does not yet support owned heap values or records".into(),
        );
    }
    let locals = functions
        .iter()
        .map(|(p, _)| p.function.sig.name.as_str())
        .collect::<std::collections::BTreeSet<_>>();
    let mut declarations = BTreeMap::new();
    for (p, _) in functions {
        declarations.extend(
            p.imports
                .iter()
                .filter(|(n, _)| !locals.contains(n.as_str()))
                .map(|(n, s)| (n.clone(), s.clone())),
        );
    }
    let mut s = String::from("declare void @abort() noreturn\n");
    for sig in declarations.values() {
        writeln!(
            s,
            "declare {} @{}({})",
            lty(&sig.result),
            symbol(&sig.name),
            sig.params.iter().map(lty).collect::<Vec<_>>().join(", ")
        )
        .unwrap();
    }
    for (p, public) in functions {
        s.push_str(&llvm_body(p, !public));
    }
    Ok(s)
}
fn llvm_body(p: &Checked, private: bool) -> String {
    let mut ll = Ll {
        s: String::new(),
        id: 0,
        types: p.types.clone(),
    };
    writeln!(
        ll.s,
        "define {}{} @{}({}) {{\nentry:",
        if private { "internal " } else { "" },
        lty(&p.function.sig.result),
        symbol(&p.function.sig.name),
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
    if let Some(r) = p.return_tail {
        let v = ll.load(r);
        ll.line(format!("ret {} {v}", lty(&p.function.sig.result)));
    }
    ll.s.push_str("trap:\n  call void @abort()\n  unreachable\n}\n");
    ll.s
}
