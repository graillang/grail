//! Checked IR lowering. Byte accesses and division are guarded; u64 arithmetic wraps.
use crate::{Bin, Checked, Mode, Op, Reg, Sig, Ty};
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
        Ty::Ref(m, _, t) => format!(
            "{}{}*",
            cty(t),
            if *m == Mode::Read { " const" } else { "" }
        ),
        Ty::Num => "uint64_t".into(),
        Ty::Unit => "uint8_t".into(),
        Ty::Named(n, _, args) => {
            if args.is_empty() {
                format!("t_{}", symbol(n))
            } else {
                format!(
                    "t_g_{}",
                    crate::sha256::hex(t.erase_regions().word().as_bytes())
                )
            }
        }
        Ty::Param(_) => unreachable!("unresolved layout type parameter"),
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
fn path_expr(
    r: Reg,
    t: &Ty,
    path: &[usize],
    layouts: &crate::types::Definitions,
) -> (String, Vec<String>) {
    let (mut value, mut t) = if let Ty::Ref(_, _, inner) = t {
        (format!("(*r{r})"), (**inner).clone())
    } else {
        (format!("r{r}"), t.clone())
    };
    let mut guards = Vec::new();
    for i in path {
        if crate::types::is_enum(&t, layouts).unwrap() {
            guards.push(format!("{value}.tag=={i}"));
            value.push_str(&format!(".data.f{i}"));
        } else {
            value.push_str(&format!(".f{i}"));
        }
        t = crate::types::field(&t, *i, layouts).unwrap();
    }
    (value, guards)
}
fn field_expr(r: Reg, t: &Ty, path: &[usize], layouts: &crate::types::Definitions) -> String {
    path_expr(r, t, path, layouts).0
}
fn owned_paths(t: &Ty, layouts: &crate::types::Definitions) -> Vec<Vec<usize>> {
    if !matches!(t, Ty::Named(..)) {
        return Vec::new();
    }
    crate::types::leaves(t, layouts)
        .unwrap()
        .into_iter()
        .filter_map(|(p, t)| t.heap().then_some(p))
        .collect()
}
fn record_flags(s: &mut String, r: Reg, t: &Ty, layouts: &crate::types::Definitions, live: bool) {
    for (i, path) in owned_paths(t, layouts).iter().enumerate() {
        let guards = path_expr(r, t, path, layouts).1;
        let value = if !live {
            "0".into()
        } else if guards.is_empty() {
            "1".into()
        } else {
            guards.join("&&")
        };
        writeln!(s, "r{r}_live[{i}]={value};").unwrap();
    }
}
fn clear_variant_flags(
    s: &mut String,
    r: Reg,
    t: &Ty,
    layouts: &crate::types::Definitions,
    variant: usize,
) {
    for (i, path) in owned_paths(t, layouts).iter().enumerate() {
        if path.first() == Some(&variant) {
            writeln!(s, "r{r}_live[{i}]=0;").unwrap();
        }
    }
}
fn view_expr(value: String, t: &Ty) -> String {
    if let Ty::Ref(_, _, inner) = t {
        return view_expr(format!("(*{value})"), inner);
    }
    if t.heap() {
        format!("((gv){{{value}.p,{value}.n}})")
    } else if matches!(t, Ty::Holder(..)) {
        format!("{value}.value")
    } else {
        value
    }
}
fn view(r: Reg, types: &BTreeMap<Reg, Ty>) -> String {
    if let Ty::Ref(_, _, inner) = &types[&r] {
        return view_expr(format!("(*r{r})"), inner);
    }
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
            Op::Match { arms, .. } => {
                for a in arms {
                    buffers(&a.body, out);
                }
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
    c_functions(&[(p, true)], &p.layouts)
}
pub fn module_c(p: &crate::module::CheckedModule) -> Result<String, String> {
    module_c_with_resolver(p, &mut |n| {
        Err(format!(
            "native generic body for {n} requires a checked artifact"
        ))
    })
}
pub fn module_c_with_bundles(
    p: &crate::module::CheckedModule,
    bundles: &BTreeMap<String, crate::template::Bundle>,
) -> Result<String, String> {
    module_c_with_resolver(p, &mut |n| {
        bundles
            .get(n)
            .cloned()
            .ok_or_else(|| format!("missing checked template bundle {n}"))
    })
}
pub fn module_c_with_resolver<F: FnMut(&str) -> Result<crate::template::Bundle, String>>(
    p: &crate::module::CheckedModule,
    resolve: &mut F,
) -> Result<String, String> {
    let native = crate::specialize::materialize(p, resolve)?;
    Ok(c_functions(
        &native
            .functions
            .iter()
            .map(|(p, public)| (p, *public))
            .collect::<Vec<_>>(),
        &native.layouts,
    ))
}
fn c_functions(functions: &[(&Checked, bool)], layouts: &crate::types::Definitions) -> String {
    let mut s = String::from(
        "#include <stdint.h>\n#include <stdlib.h>\n#include <string.h>\ntypedef struct { uint8_t *p; uint64_t n; } gv;\ntypedef struct { gv value; } gh;\ntypedef struct {uint8_t*p;uint64_t n,c;} gb;\n#define GRAIL_BYTES_TYPES_DEFINED\n",
    );
    let mut roots = Vec::new();
    for (p, _) in functions {
        roots.extend(p.types.values().cloned());
        for sig in p.imports.values().chain([&p.function.sig]) {
            roots.extend(sig.params.iter().chain([&sig.result]).cloned());
        }
    }
    for t in crate::types::instances(&roots, layouts).expect("checked layouts") {
        let Ty::Named(n, _, _) = &t else {
            unreachable!()
        };
        let d = &layouts[n];
        let fields = crate::types::fields(&t, layouts).unwrap();
        s.push_str("typedef struct {\n");
        if d.kind == crate::types::Kind::Enum {
            s.push_str("uint64_t tag;\n");
            if fields.iter().any(|(_, t)| *t != Ty::Unit) {
                s.push_str("union {\n");
                for (i, (_, t)) in fields.iter().enumerate() {
                    if *t != Ty::Unit {
                        writeln!(s, "{} f{i};", cty(t)).unwrap();
                    }
                }
                s.push_str("} data;\n");
            }
        } else {
            if fields.is_empty() {
                s.push_str("uint8_t unit;\n");
            }
            for (i, (_, t)) in fields.iter().enumerate() {
                writeln!(s, "{} f{i};", cty(t)).unwrap();
            }
        }
        writeln!(s, "}} {};", cty(&t)).unwrap();
    }
    if functions.iter().any(|(p, _)| {
        p.types
            .values()
            .any(|t| t.heap() || matches!(t,Ty::Ref(_,_,inner)if inner.heap()))
    }) {
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
#[derive(Default)]
struct CLoops {
    stack: Vec<usize>,
    next: usize,
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
        if matches!(t, Ty::Named(..)) {
            let count = owned_paths(t, &p.layouts).len().max(1);
            writeln!(s, "uint8_t r{r}_live[{count}]={{0}};").unwrap();
            if (*r as usize) < p.function.sig.params.len() {
                record_flags(s, *r, t, &p.layouts, true);
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
        layouts: &crate::types::Definitions,
        jumps: &mut CLoops,
    ) {
        for o in os {
            match o{
        Op::Address{dst,src,path,..}=>{
            let (base,ty)=if let Ty::Ref(_,_,t)=&types[src]{(format!("(*r{src})"),t.as_ref())}else{(format!("r{src}"),&types[src])};
            let(indices,_)=if path.is_empty(){(vec![],ty.clone())}else{crate::types::project(ty,path,layouts).unwrap()};
            let mut place=base;for i in indices{place.push_str(&format!(".f{i}"));}
            writeln!(s,"r{dst}=&({place});").unwrap();
        },
        Op::Load{dst,src}=>{writeln!(s,"r{dst}=*r{src};").unwrap();},
        Op::Exchange{dst,src,value}=>{writeln!(s,"r{dst}=*r{src};*r{src}=r{value};").unwrap();record_flags(s,*dst,&types[dst],layouts,true);record_flags(s,*value,&types[value],layouts,false);},
        Op::Break|Op::Continue=>{let id=jumps.stack.last().expect("checked loop jump");let kind=if matches!(o,Op::Break){"break"}else{"continue"};writeln!(s,"goto loop_{kind}_{id};").unwrap();},
        Op::GenericCall{..}=>unreachable!("generic calls must be materialized before native emission"),
        Op::Return(r)=>{writeln!(s,"return r{r};").unwrap()},
        Op::Unit(r)=>{writeln!(s,"r{r}=0;").unwrap()},
        Op::Variant{dst,variant,payload,..}=>{writeln!(s,"r{dst}=({}){{.tag={variant}}};",cty(&types[dst])).unwrap();if let Some(r)=payload{if types[r]!=Ty::Unit{writeln!(s,"r{dst}.data.f{variant}=r{r};").unwrap();}record_flags(s,*r,&types[r],layouts,false);}record_flags(s,*dst,&types[dst],layouts,true);},
        Op::Unwrap{dst,src}=>{let k=crate::types::success(&types[src],layouts).unwrap();writeln!(s,"if(r{src}.tag!={k})abort();").unwrap();if types[dst]==Ty::Unit{writeln!(s,"r{dst}=0;").unwrap();}else{writeln!(s,"r{dst}=r{src}.data.f{k};").unwrap();}record_flags(s,*dst,&types[dst],layouts,true);clear_variant_flags(s,*src,&types[src],layouts,k);},
        Op::Match{src,arms}=>{let fields=crate::types::fields(&types[src],layouts).unwrap();writeln!(s,"switch(r{src}.tag){{").unwrap();for a in arms{let k=fields.iter().position(|(n,_)|*n==a.variant).unwrap();writeln!(s,"case {k}:{{").unwrap();if let Some(r)=a.binding{if types[&r]==Ty::Unit{writeln!(s,"r{r}=0;").unwrap();}else{writeln!(s,"r{r}=r{src}.data.f{k};").unwrap();}record_flags(s,r,&types[&r],layouts,true);}clear_variant_flags(s,*src,&types[src],layouts,k);ops(s,&a.body,types,layouts,jumps);if !crate::flow::terminates(&a.body){s.push_str("break;");}s.push_str("}\n");}s.push_str("default:abort();}\n");},

        Op::Record{dst,ty,fields}=>{
            writeln!(s,"r{dst}=({}){{0}};",cty(&types[dst])).unwrap();
            for(field,src)in fields{let i=crate::types::fields(ty,layouts).unwrap().iter().position(|f|f.0==*field).unwrap();writeln!(s,"r{dst}.f{i}=r{src};").unwrap();record_flags(s,*src,&types[src],layouts,false);}
            record_flags(s,*dst,&types[dst],layouts,true);
        },
        Op::FieldMove{dst,src,path}=>{
            let ty=if let Ty::Ref(_,_,t)=&types[src]{t.as_ref()}else{&types[src]};let(indices,_)=crate::types::project(ty,path,layouts).unwrap();let value=field_expr(*src,&types[src],&indices,layouts);writeln!(s,"r{dst}={value};").unwrap();
            for(i,field)in owned_paths(&types[src],layouts).iter().enumerate(){if field.starts_with(&indices){writeln!(s,"r{src}_live[{i}]=0;").unwrap();}}
            record_flags(s,*dst,&types[dst],layouts,true);
        },
        Op::FieldBorrow{dst,src,path,..}=>{let ty=if let Ty::Ref(_,_,t)=&types[src]{t.as_ref()}else{&types[src]};let(indices,t)=crate::types::project(ty,path,layouts).unwrap();writeln!(s,"r{dst}={};",view_expr(field_expr(*src,&types[src],&indices,layouts),&t)).unwrap();},
        Op::EndCaptures(_)=>{},
        Op::TextLiteral{dst,data}=>{let values=if data.is_empty(){"0".into()}else{data.iter().map(u8::to_string).collect::<Vec<_>>().join(",")};writeln!(s,"{{static const uint8_t text[]={{ {values} }};r{dst}=gr_copy_bytes((gv){{(uint8_t*)text,UINT64_C({})}});}}",data.len()).unwrap()},
        Op::Text{dst,src}=>{let v=view(*src,types);writeln!(s,"gr_utf8({v});r{dst}=gr_copy_bytes({v});").unwrap()},
        Op::AppendText{owner,src}=>{let ptr=if matches!(types[owner],Ty::Ref(..)){format!("r{owner}")}else{format!("&r{owner}")};writeln!(s,"gr_append_text({ptr},{});",view(*src,types)).unwrap()},
        Op::Bytes{dst}=>{writeln!(s,"r{dst}=(gb){{0,0,0}};").unwrap()},
        Op::CopyBytes{dst,src}=>{writeln!(s,"r{dst}=gr_copy_bytes({});",view(*src,types)).unwrap()},
        Op::Push{owner,value}=>{let ptr=if matches!(types[owner],Ty::Ref(..)){format!("r{owner}")}else{format!("&r{owner}")};writeln!(s,"gr_push({ptr},r{value});").unwrap()},
        Op::Num(r,n)=>{writeln!(s,"r{r} = UINT64_C({n});").unwrap()},
        Op::Buffer{dst,len,seed}=>{writeln!(s,"r{dst} = (gv){{b{dst}, UINT64_C({len})}};\nfor (uint64_t j=0; j<UINT64_C({len}); ++j) b{dst}[j]=(uint8_t)((j*UINT64_C(17)+UINT64_C({seed}))%UINT64_C(251));").unwrap()},
        Op::Borrow{dst,src,..}=>{writeln!(s,"r{dst} = {};",view(*src,types)).unwrap()},
        Op::Slice{dst,src,start,end}=>{let v=view(*src,types);writeln!(s,"if(r{start}>r{end} || r{end}>{v}.n) abort(); r{dst}=(gv){{r{start}?{v}.p+r{start}:{v}.p,r{end}-r{start}}};").unwrap()},
        Op::Assert(r)=>{writeln!(s,"if(!r{r}) abort();").unwrap()},
        Op::If{condition,yes,no}=>{writeln!(s,"if(r{condition}){{").unwrap();ops(s,yes,types,layouts,jumps);s.push_str("}else{\n");ops(s,no,types,layouts,jumps);s.push_str("}\n")},
        Op::Pack{dst,src}=>{writeln!(s,"r{dst} = (gh){{r{src}}};").unwrap()},
        Op::Move{dst,src}=>{writeln!(s,"r{dst}=r{src};").unwrap();record_flags(s,*dst,&types[dst],layouts,true);record_flags(s,*src,&types[src],layouts,false);},
        Op::End(r)=>{if types[r].heap(){writeln!(s,"free(r{r}.p);").unwrap();}else{for(i,path)in owned_paths(&types[r],layouts).iter().enumerate(){writeln!(s,"if(r{r}_live[{i}]){{free({}.p);r{r}_live[{i}]=0;}}",field_expr(*r,&types[r],path,layouts)).unwrap();}}},
        Op::Len{dst,src}=>{writeln!(s,"r{dst}={}.n;",view(*src,types)).unwrap()},
        Op::Read{dst,src,index}=>{let v=view(*src,types);writeln!(s,"if (r{index}>={v}.n) abort(); r{dst}={v}.p[r{index}];").unwrap()},
        Op::Write{dst,index,value}=>{let v=view(*dst,types);writeln!(s,"if (r{index}>={v}.n) abort(); {v}.p[r{index}]=(uint8_t)r{value};").unwrap()},
        Op::Binary{dst,op,left,right}=>{let symbol=match op{Bin::Add=>"+",Bin::Sub=>"-",Bin::Lt=>"<",Bin::Mul=>"*",Bin::Xor=>"^",Bin::Rem=>"%",Bin::Eq=>"==",Bin::Ne=>"!=",Bin::And=>"&"};if matches!(op,Bin::Rem){writeln!(s,"if (!r{right}) abort();").unwrap()}writeln!(s,"r{dst}=r{left} {symbol} r{right};").unwrap()},
        Op::Call{dst,name,args}=>{writeln!(s,"r{dst}={}({});",symbol(name),args.iter().map(|r|format!("r{r}")).collect::<Vec<_>>().join(",")).unwrap();for r in args{record_flags(s,*r,&types[r],layouts,false);}record_flags(s,*dst,&types[dst],layouts,true);},
        Op::Block{body}=>{s.push_str("{\n");ops(s,body,types,layouts,jumps);s.push_str("}\n")},
        Op::While{condition,test,body}=>{
            let id=jumps.next;jumps.next+=1;let(b,c)=crate::flow::loop_jumps(body);
            s.push_str("while(1){\n");ops(s,test,types,layouts,jumps);writeln!(s,"if(!r{condition})break;").unwrap();
            jumps.stack.push(id);ops(s,body,types,layouts,jumps);jumps.stack.pop();
            if c{writeln!(s,"loop_continue_{id}:;").unwrap();}s.push_str("}\n");if b{writeln!(s,"loop_break_{id}:;").unwrap();}
        },
        Op::Loop{index,end,body}=>{
            let id=jumps.next;jumps.next+=1;let(b,c)=crate::flow::loop_jumps(body);
            writeln!(s,"for (r{index}=0; r{index}<r{end}; ++r{index}) {{").unwrap();
            jumps.stack.push(id);ops(s,body,types,layouts,jumps);jumps.stack.pop();
            if c{writeln!(s,"loop_continue_{id}:;").unwrap();}s.push_str("}\n");if b{writeln!(s,"loop_break_{id}:;").unwrap();}
        },
    }
        }
    }
    ops(
        s,
        &p.function.ops,
        &p.types,
        &p.layouts,
        &mut CLoops::default(),
    );
    if let Some(r) = p.return_tail {
        writeln!(s, "return r{r};").unwrap();
    }
    s.push_str("}\n");
}

fn lty(t: &Ty) -> &'static str {
    match t {
        Ty::Ref(..) => "ptr",
        Ty::Num => "i64",
        Ty::Unit => "i8",
        _ => "{ ptr, i64 }",
    }
}
struct Ll {
    s: String,
    id: usize,
    types: BTreeMap<Reg, Ty>,
    loops: Vec<(String, String)>,
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
    fn view_load(&mut self, r: Reg) -> String {
        let value = self.load(r);
        if let Ty::Ref(_, _, inner) = &self.types[&r] {
            let ty = lty(inner);
            let result = self.fresh();
            self.line(format!("%{result} = load {ty}, ptr {value}"));
            format!("%{result}")
        } else {
            value
        }
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
                Op::Address { dst, src, path, .. } => {
                    debug_assert!(path.is_empty());
                    let ptr = if matches!(self.types[src], Ty::Ref(..)) {
                        self.load(*src)
                    } else {
                        format!("%r{src}")
                    };
                    self.store(*dst, &ptr);
                }
                Op::Load { dst, src } => {
                    let ptr = self.load(*src);
                    let value = self.fresh();
                    self.line(format!(
                        "%{value} = load {}, ptr {ptr}",
                        lty(&self.types[dst])
                    ));
                    self.store(*dst, &format!("%{value}"));
                }
                Op::Exchange { dst, src, value } => {
                    let ptr = self.load(*src);
                    let old = self.fresh();
                    let new = self.load(*value);
                    let ty = lty(&self.types[dst]);
                    self.line(format!("%{old} = load {ty}, ptr {ptr}"));
                    self.line(format!("store {ty} {new}, ptr {ptr}"));
                    self.store(*dst, &format!("%{old}"));
                }
                Op::Break | Op::Continue => {
                    let targets = self.loops.last().expect("checked loop jump");
                    let label = if matches!(o, Op::Break) {
                        &targets.0
                    } else {
                        &targets.1
                    }
                    .clone();
                    self.line(format!("br label %{label}"));
                    return false;
                }
                Op::Unit(r) => self.store(*r, "0"),
                Op::Return(r) => {
                    let v = self.load(*r);
                    self.line(format!("ret {} {v}", lty(&self.types[r])));
                    return false;
                }
                Op::GenericCall { .. } => {
                    unreachable!("generic calls must be materialized before native emission")
                }
                Op::Variant { .. }
                | Op::Match { .. }
                | Op::Unwrap { .. }
                | Op::Record { .. }
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
                Op::Borrow { dst, src, .. } => {
                    let v = self.view_load(*src);
                    self.store(*dst, &v)
                }
                Op::Move { dst, src } | Op::Pack { dst, src } => {
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
                    self.loops.push((done.clone(), head.clone()));
                    let continuing = self.ops(body);
                    self.loops.pop();
                    if continuing {
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
                    let has_continue = crate::flow::loop_jumps(body).1;
                    let latch = if has_continue {
                        self.fresh()
                    } else {
                        head.clone()
                    };
                    self.loops.push((done.clone(), latch.clone()));
                    let continuing = self.ops(body);
                    self.loops.pop();
                    if has_continue {
                        if continuing {
                            self.line(format!("br label %{latch}"));
                        }
                        writeln!(self.s, "{latch}:").unwrap();
                    }
                    if continuing || has_continue {
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
    let native = crate::specialize::materialize(p, &mut |n| {
        Err(format!(
            "native generic body for {n} requires a checked artifact"
        ))
    })?;
    llvm_functions(
        &native
            .functions
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
            .any(|t| {
                let t = if let Ty::Ref(_, _, t) = t {
                    t.as_ref()
                } else {
                    t
                };
                t.heap() || matches!(t, Ty::Named(..))
            })
    }) {
        return Err(
            "LLVM comparison backend does not yet support owned heap values or layouts".into(),
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
        loops: Vec::new(),
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
