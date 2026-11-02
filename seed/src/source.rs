//! Borrowed-token parser and local loan ending for the first .grl slice.
use crate::flow::live_before;
use crate::{Arm, Bin, Function, Mode, Op, Reg, Sig, State, Ty};
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Copy)]
struct Token<'a> {
    text: &'a str,
    offset: usize,
}
fn literal(text: &str) -> Result<Vec<u8>, String> {
    let bytes = &text.as_bytes()[1..text.len() - 1];
    let mut out = vec![];
    let mut i = 0;
    while i < bytes.len() {
        let c = bytes[i];
        i += 1;
        if c != b'\\' {
            out.push(c);
            continue;
        }
        let c = *bytes.get(i).ok_or("unterminated escape")?;
        i += 1;
        out.push(match c {
            b'n' => b'\n',
            b'r' => b'\r',
            b't' => b'\t',
            b'0' => 0,
            b'"' => b'"',
            b'\\' => b'\\',
            b'x' => {
                let h = *bytes.get(i).ok_or("short hex escape")?;
                let l = *bytes.get(i + 1).ok_or("short hex escape")?;
                i += 2;
                let h = (h as char).to_digit(16).ok_or("invalid hex escape")?;
                let l = (l as char).to_digit(16).ok_or("invalid hex escape")?;
                (h * 16 + l) as u8
            }
            _ => return Err("unknown string escape".into()),
        });
    }
    std::str::from_utf8(&out).map_err(|_| "literal is not valid UTF-8")?;
    Ok(out)
}
fn lex(text: &str) -> Result<Vec<Token<'_>>, String> {
    let b = text.as_bytes();
    let mut out = vec![];
    let mut i = 0;
    while i < b.len() {
        if b[i].is_ascii_whitespace() {
            i += 1;
            continue;
        }
        if b[i..].starts_with(b"//") {
            while i < b.len() && b[i] != b'\n' {
                i += 1
            }
            continue;
        }
        let start = i;
        if b[i] == b'"' {
            i += 1;
            let mut closed = false;
            while i < b.len() {
                if b[i] == b'"' {
                    i += 1;
                    closed = true;
                    break;
                }
                if b[i] < 32 {
                    return Err(format!("byte {i}: control character in literal"));
                }
                if b[i] == b'\\' {
                    i += 1;
                    if i == b.len() {
                        break;
                    }
                }
                i += 1;
            }
            if !closed {
                return Err(format!("byte {start}: unterminated string literal"));
            }
        } else if b[i].is_ascii_alphabetic() || b[i] == b'_' {
            i += 1;
            while i < b.len() && (b[i].is_ascii_alphanumeric() || b[i] == b'_') {
                i += 1
            }
        } else if b[i].is_ascii_digit() {
            i += 1;
            while i < b.len() && b[i].is_ascii_digit() {
                i += 1
            }
        } else if i + 1 < b.len()
            && [b"->", b"=>", b"==", b"!=", b"::"]
                .iter()
                .any(|s| b[i..].starts_with(*s))
        {
            i += 2
        } else if b"(){}<>,:;=+-*%&^.!?".contains(&b[i]) {
            i += 1
        } else {
            return Err(format!("byte {i}: unexpected character"));
        }
        out.push(Token {
            text: &text[start..i],
            offset: start,
        });
    }
    out.push(Token {
        text: "",
        offset: b.len(),
    });
    Ok(out)
}
#[derive(Clone)]
struct Binding {
    reg: Reg,
    mutable: bool,
}
struct Parser<'a> {
    tokens: Vec<Token<'a>>,
    at: usize,
    next: Reg,
    vars: BTreeMap<String, Binding>,
    regions: BTreeMap<String, u16>,
    type_params: BTreeMap<String, u16>,
    module: String,
    layouts: crate::types::Context,
    return_ty: Option<Ty>,
}
impl Parser<'_> {
    fn error(&self, msg: &str) -> String {
        format!(
            "byte {}: {msg}; found {:?}",
            self.tokens[self.at].offset,
            self.peek()
        )
    }
    fn peek(&self) -> &str {
        self.tokens[self.at].text
    }
    fn assignment_ahead(&self) -> bool {
        let mut end = self.at + 1;
        while self.tokens.get(end).is_some_and(|t| t.text == ".") {
            end += 2;
        }
        self.tokens.get(end).is_some_and(|t| t.text == "=")
    }
    fn eat(&mut self, s: &str) -> bool {
        if self.peek() == s {
            self.at += 1;
            true
        } else {
            false
        }
    }
    fn expect(&mut self, s: &str) -> Result<(), String> {
        if self.eat(s) {
            Ok(())
        } else {
            Err(self.error(&format!("expected {s}")))
        }
    }
    fn ident(&mut self) -> Result<String, String> {
        let s = self.peek();
        if !crate::name_ok(s) {
            return Err(self.error("expected identifier"));
        }
        let s = s.to_string();
        self.at += 1;
        Ok(s)
    }
    fn fresh(&mut self) -> Result<Reg, String> {
        let r = self.next;
        self.next = self.next.checked_add(1).ok_or("register overflow")?;
        if r > 65535 {
            return Err(self.error("register limit"));
        }
        Ok(r)
    }
    fn bind(&mut self, name: String, reg: Reg, mutable: bool) {
        self.vars.insert(name, Binding { reg, mutable });
    }
    fn generic_parameters(&mut self, max_regions: usize) -> Result<(), String> {
        self.regions.clear();
        self.type_params.clear();
        if self.eat("<") {
            loop {
                let is_type = self.eat("type");
                let n = self.ident()?;
                if self.regions.contains_key(&n)
                    || self.type_params.contains_key(&n)
                    || matches!(
                        n.as_str(),
                        "num"
                            | "unit"
                            | "bytes"
                            | "string"
                            | "read"
                            | "mut"
                            | "ref"
                            | "ref_mut"
                            | "read_holder"
                            | "mut_holder"
                            | "type"
                    )
                {
                    return Err(self.error("duplicate/reserved generic parameter"));
                }
                if is_type {
                    let i = self.type_params.len();
                    if i >= 64 {
                        return Err(self.error("type parameter limit"));
                    }
                    self.type_params.insert(n, i as u16);
                } else {
                    if !self.type_params.is_empty() {
                        return Err(self.error("lifetimes precede type parameters"));
                    }
                    let i = self.regions.len();
                    if i >= max_regions {
                        return Err(self.error("lifetime parameter limit"));
                    }
                    self.regions.insert(n, i as u16);
                }
                if self.eat(">") {
                    break;
                }
                self.expect(",")?;
            }
        }
        Ok(())
    }
    fn call_type_arguments(&self) -> bool {
        let mut depth = 0;
        for (i, t) in self.tokens[self.at..].iter().enumerate() {
            match t.text {
                "<" => depth += 1,
                ">" => {
                    depth -= 1;
                    if depth == 0 {
                        return self
                            .tokens
                            .get(self.at + i + 1)
                            .is_some_and(|t| t.text == "(");
                    }
                }
                ";" | "{" | "}" => return false,
                _ => {}
            }
            if depth > 64 {
                return false;
            }
        }
        false
    }
    fn function(&mut self) -> Result<(Function, bool, u16), String> {
        self.vars.clear();
        self.next = 0;
        let public = self.eat("pub");
        self.expect("fn")?;
        let name = self.ident()?;
        if self.module.is_empty() {
            self.module = name.clone();
        }
        self.generic_parameters(65536)?;
        self.expect("(")?;
        let mut params = vec![];
        if !self.eat(")") {
            loop {
                let n = self.ident()?;
                if self.vars.contains_key(&n) {
                    return Err(self.error("duplicate parameter"));
                }
                self.expect(":")?;
                let t = self.ty()?;
                let r = self.fresh()?;
                self.bind(n, r, false);
                params.push(t);
                if self.eat(")") {
                    break;
                }
                self.expect(",")?;
            }
        }
        self.expect("->")?;
        let result_ty = self.ty()?;
        let sig = Sig {
            name,
            params,
            result: result_ty,
        };
        let parameters = self.type_params.len() as u16;
        crate::types::validate_sig_bound(&sig, &self.layouts, parameters)?;
        self.return_ty = Some(sig.result.clone());
        self.expect("{")?;
        let ops = self.statements(0)?;
        self.expect("}")?;
        Ok((
            Function {
                sig,
                ops,
                result: None,
            },
            public,
            parameters,
        ))
    }
    fn path_name(&mut self) -> Result<String, String> {
        let mut n = self.ident()?;
        if self.eat("::") {
            n.push_str("::");
            n.push_str(&self.ident()?);
        }
        Ok(n)
    }
    fn nominal(&self, n: &str) -> String {
        if n.contains("::") {
            n.into()
        } else {
            format!("{}::{n}", self.module)
        }
    }
    fn constructor_type(&self, name: &str, explicit: Option<Ty>) -> Result<Ty, String> {
        if let Some(t) = explicit {
            return Ok(t);
        }
        if let Some(t @ Ty::Named(n, _, _)) = &self.return_ty
            && n == name
        {
            return Ok(t.clone());
        }
        let d = self
            .layouts
            .get(name)
            .ok_or_else(|| self.error("unknown constructor type"))?;
        if d.parameters != 0 {
            return Err(self.error("constructor needs explicit type arguments"));
        }
        Ok(Ty::Named(name.into(), vec![0; d.regions as usize], vec![]))
    }
    fn type_arguments(&mut self, depth: usize) -> Result<(Vec<u16>, Vec<Ty>), String> {
        if depth > 64 {
            return Err(self.error("type nesting limit"));
        }
        let mut rs = Vec::new();
        let mut args = Vec::new();
        if self.eat("<") {
            loop {
                if let Some(r) = self.regions.get(self.peek()).copied() {
                    if !args.is_empty() {
                        return Err(self.error("lifetimes precede type arguments"));
                    }
                    self.at += 1;
                    rs.push(r);
                } else {
                    args.push(self.ty_at(depth + 1)?);
                }
                if rs.len() > 64 || args.len() > 64 {
                    return Err(self.error("type argument count limit"));
                }
                if self.eat(">") {
                    break;
                }
                self.expect(",")?;
            }
        }
        Ok((rs, args))
    }
    fn ty(&mut self) -> Result<Ty, String> {
        self.ty_at(0)
    }
    fn ty_at(&mut self, depth: usize) -> Result<Ty, String> {
        if depth > 64 {
            return Err(self.error("type nesting limit"));
        }
        let name = self.path_name()?;
        match name.as_str() {
            "num" => return Ok(Ty::Num),
            "unit" => return Ok(Ty::Unit),
            "bytes" => return Ok(Ty::Bytes),
            "string" => return Ok(Ty::Text),
            _ => {}
        }
        if let Some(i) = self.type_params.get(&name) {
            return Ok(Ty::Param(*i));
        }
        let (rs, args) = self.type_arguments(depth)?;
        if name == "vec" {
            if !rs.is_empty() || args.len() != 1 {
                return Err(self.error("vec needs one element type"));
            }
            return Ok(Ty::Vector(Box::new(args[0].clone())));
        }
        if matches!(name.as_str(), "ref" | "ref_mut") {
            if rs.len() != 1 || args.len() != 1 {
                return Err(self.error("typed reference needs one lifetime and one type"));
            }
            return Ok(Ty::Ref(
                if name == "ref" {
                    Mode::Read
                } else {
                    Mode::Write
                },
                rs[0],
                Box::new(args[0].clone()),
            ));
        }
        if matches!(name.as_str(), "read" | "mut" | "read_holder" | "mut_holder") {
            if rs.len() != 1 || !args.is_empty() {
                return Err(self.error("view needs one lifetime"));
            }
            let mode = if name.starts_with("mut") {
                Mode::Write
            } else {
                Mode::Read
            };
            return Ok(if name.ends_with("holder") {
                Ty::Holder(mode, rs[0])
            } else {
                Ty::View(mode, rs[0])
            });
        }
        Ok(Ty::Named(self.nominal(&name), rs, args))
    }
    fn record(&mut self) -> Result<(String, crate::types::Definition), String> {
        if self.module.is_empty() {
            return Err(self.error("record declarations need an explicit module"));
        }
        let kind = if self.eat("struct") {
            crate::types::Kind::Record
        } else {
            self.expect("enum")?;
            crate::types::Kind::Enum
        };
        let name = self.ident()?;
        self.generic_parameters(64)?;
        let regions = self.regions.len() as u16;
        self.expect("{")?;
        let mut fields = Vec::new();
        if !self.eat("}") {
            loop {
                let n = self.ident()?;
                let t = if kind == crate::types::Kind::Record {
                    self.expect(":")?;
                    self.ty()?
                } else if self.eat("(") {
                    let t = self.ty()?;
                    self.expect(")")?;
                    t
                } else {
                    Ty::Unit
                };
                fields.push((n, t));
                if self.eat("}") {
                    break;
                }
                self.expect(",")?;
                if self.eat("}") {
                    break;
                }
            }
        }
        self.eat(";");
        Ok((
            self.nominal(&name),
            crate::types::Definition {
                kind,
                regions,
                parameters: self.type_params.len() as u16,
                fields,
            },
        ))
    }
    /// `?` is ordinary checked control flow, not a second cleanup/exception runtime.
    fn propagate(&mut self, src: Reg, ops: &mut Vec<Op>) -> Result<Reg, String> {
        let result = self
            .return_ty
            .clone()
            .ok_or_else(|| self.error("propagation outside function"))?;
        let success = crate::types::success(&result, &self.layouts)
            .map_err(|e| self.error(&format!("? return type: {e}")))?;
        let fields = crate::types::fields(&result, &self.layouts)?;

        let failure = 1 - success;
        let dst = self.fresh()?;
        let error = self.fresh()?;
        let returned = self.fresh()?;
        ops.push(Op::Match {
            src,
            arms: vec![
                Arm {
                    variant: fields[success].0.clone(),
                    binding: Some(dst),
                    body: vec![],
                },
                Arm {
                    variant: fields[failure].0.clone(),
                    binding: Some(error),
                    body: vec![
                        Op::Variant {
                            dst: returned,
                            ty: result,
                            variant: failure,
                            payload: Some(error),
                        },
                        Op::Return(returned),
                    ],
                },
            ],
        });
        Ok(dst)
    }
    fn storage_expr(&mut self, ops: &mut Vec<Op>, mode: Mode, depth: usize) -> Result<Reg, String> {
        if depth > 64 {
            return Err(self.error("expression depth limit"));
        }
        if self.eat("(") {
            let r = self.storage_expr(ops, mode, depth + 1)?;
            self.expect(")")?;
            return Ok(r);
        }
        if self.vars.contains_key(self.peek())
            && self.tokens.get(self.at + 1).is_some_and(|t| t.text == ".")
        {
            let name = self.ident()?;
            let src = self.vars[&name].reg;
            let mut path = Vec::new();
            while self.eat(".") {
                path.push(self.ident()?);
            }
            let dst = self.fresh()?;
            ops.push(Op::FieldBorrow {
                dst,
                src,
                path,
                mode,
            });
            return Ok(dst);
        }
        self.expr(ops, 0, depth)
    }
    fn expr(&mut self, ops: &mut Vec<Op>, minimum: u8, depth: usize) -> Result<Reg, String> {
        if depth > 128 {
            return Err(self.error("expression nesting limit"));
        }
        let grouped = self.eat("(");
        let mut left = if grouped && self.eat(")") {
            let r = self.fresh()?;
            ops.push(Op::Unit(r));
            r
        } else if grouped {
            let r = self.expr(ops, 0, depth + 1)?;
            self.expect(")")?;
            r
        } else if self.peek().starts_with('"') {
            let data = literal(self.peek()).map_err(|e| self.error(&e))?;
            self.at += 1;
            let dst = self.fresh()?;
            ops.push(Op::TextLiteral { dst, data });
            dst
        } else if self
            .peek()
            .as_bytes()
            .first()
            .is_some_and(u8::is_ascii_digit)
        {
            let n = self
                .peek()
                .parse::<u64>()
                .map_err(|_| self.error("number exceeds u64"))?;
            self.at += 1;
            let r = self.fresh()?;
            ops.push(Op::Num(r, n));
            r
        } else {
            let mut name = self.ident()?;
            while self.eat("::") {
                name.push_str("::");
                name.push_str(&self.ident()?);
            }
            let mut explicit = None;
            if self.layouts.contains_key(&self.nominal(&name))
                && !self.vars.contains_key(&name)
                && self.peek() == "<"
            {
                let n = self.nominal(&name);
                let (rs, args) = self.type_arguments(0)?;
                explicit = Some(Ty::Named(n, rs, args));
                if self.eat("::") {
                    name.push_str("::");
                    name.push_str(&self.ident()?);
                }
            }
            let mut function_args = None;
            if explicit.is_none() && self.peek() == "<" && self.call_type_arguments() {
                let (rs, args) = self.type_arguments(0)?;
                if !rs.is_empty() {
                    return Err(
                        self.error("function arguments here are types; lifetimes are implicit")
                    );
                }
                function_args = Some(args);
            }
            let variant = name.rsplit_once("::").and_then(|(base, v)| {
                let n = self.nominal(base);
                self.layouts
                    .get(&n)
                    .filter(|d| d.kind == crate::types::Kind::Enum)
                    .and_then(|d| {
                        d.fields
                            .iter()
                            .position(|(name, _)| name == v)
                            .map(|k| (n, k))
                    })
            });
            if let Some((name, variant)) = variant {
                let payload = if self.eat("(") {
                    let r = self.expr(ops, 0, depth + 1)?;
                    self.expect(")")?;
                    Some(r)
                } else {
                    None
                };
                let dst = self.fresh()?;
                let ty = self.constructor_type(&name, explicit.clone())?;
                ops.push(Op::Variant {
                    dst,
                    ty: ty.clone(),
                    variant,
                    payload,
                });
                if explicit.is_some() {
                    ops.push(Op::Ascribe { src: dst, ty });
                }
                dst
            } else if self.eat("(") {
                let mut args = vec![];
                if function_args.is_none()
                    && let Some(Ty::Named(_, rs, args)) = &explicit
                {
                    if !rs.is_empty() {
                        return Err(self.error("function lifetime arguments are implicit"));
                    }
                    function_args = Some(args.clone());
                }
                let vector_element = if name == "vec" {
                    let types = function_args
                        .take()
                        .ok_or_else(|| self.error("vec needs one element type"))?;
                    if types.len() != 1 {
                        return Err(self.error("vec needs one element type"));
                    }
                    Some(types[0].clone())
                } else {
                    None
                };
                let arity = if vector_element.is_some() {
                    Some(0)
                } else if function_args.is_some() {
                    None
                } else {
                    match name.as_str() {
                        "bytes" => Some(0),
                        "read" | "mut" | "hold" | "len" | "copy_bytes" | "text" | "borrow"
                        | "borrow_mut" | "load" => Some(1),
                        "exchange" | "vec_push" => Some(2),
                        "vec_pop" => Some(1),
                        "vec_get" | "vec_get_mut" => Some(2),
                        "at" => Some(2),
                        "slice" => Some(3),
                        _ => None,
                    }
                };
                if !self.eat(")") {
                    loop {
                        let storage = args.is_empty()
                            && matches!(
                                name.as_str(),
                                "read"
                                    | "mut"
                                    | "len"
                                    | "at"
                                    | "slice"
                                    | "copy_bytes"
                                    | "text"
                                    | "vec_push"
                                    | "vec_pop"
                                    | "vec_get"
                                    | "vec_get_mut"
                            );
                        let value = if matches!(name.as_str(), "borrow" | "borrow_mut") {
                            let n = self.ident()?;
                            let src = self
                                .vars
                                .get(&n)
                                .ok_or_else(|| self.error("unknown borrowed place"))?
                                .reg;
                            let mut path = Vec::new();
                            while self.eat(".") {
                                path.push(self.ident()?);
                            }
                            let dst = self.fresh()?;
                            ops.push(Op::Address {
                                dst,
                                src,
                                path,
                                mode: if name == "borrow_mut" {
                                    Mode::Write
                                } else {
                                    Mode::Read
                                },
                            });
                            dst
                        } else if storage {
                            self.storage_expr(
                                ops,
                                if matches!(name.as_str(), "mut" | "vec_push" | "vec_pop" | "vec_get_mut") {
                                    Mode::Write
                                } else {
                                    Mode::Read
                                },
                                depth + 1,
                            )?
                        } else {
                            self.expr(ops, 0, depth + 1)?
                        };
                        // User calls pass values, not deferred places. Move/copy each before
                        // evaluating the next operand; builtin places follow their own rules.
                        let arg = if arity.is_some() {
                            value
                        } else {
                            let dst = self.fresh()?;
                            ops.push(Op::Move { dst, src: value });
                            dst
                        };
                        args.push(arg);
                        if self.eat(")") {
                            break;
                        }
                        self.expect(",")?;
                    }
                }
                let r = self.fresh()?;
                if arity.is_some_and(|n| n != args.len()) {
                    return Err(self.error("builtin arity"));
                }
                ops.push(if let Some(element) = vector_element {
                    Op::Vector { dst: r, element }
                } else if let Some(type_args) = function_args {
                    Op::GenericCall {
                        dst: r,
                        name,
                        type_args: Some(type_args),
                        args,
                    }
                } else {
                    match name.as_str() {
                        "borrow" | "borrow_mut" => Op::Move {
                            dst: r,
                            src: args[0],
                        },
                        "vec_push" => Op::VectorPush {
                            dst: r,
                            owner: args[0],
                            value: args[1],
                        },
                        "vec_pop" => Op::VectorPop {
                            dst: r,
                            owner: args[0],
                        },
                        "vec_get" | "vec_get_mut" => Op::VectorGet {
                            dst: r,
                            owner: args[0],
                            index: args[1],
                            mode: if name == "vec_get_mut" {
                                Mode::Write
                            } else {
                                Mode::Read
                            },
                        },
                        "load" => Op::Load {
                            dst: r,
                            src: args[0],
                        },
                        "exchange" => Op::Exchange {
                            dst: r,
                            src: args[0],
                            value: args[1],
                        },
                        "text" => Op::Text {
                            dst: r,
                            src: args[0],
                        },
                        "bytes" => Op::Bytes { dst: r },
                        "copy_bytes" => Op::CopyBytes {
                            dst: r,
                            src: args[0],
                        },
                        "read" | "mut" => Op::Borrow {
                            dst: r,
                            src: args[0],
                            mode: if name == "read" {
                                Mode::Read
                            } else {
                                Mode::Write
                            },
                        },
                        "hold" => Op::Pack {
                            dst: r,
                            src: args[0],
                        },
                        "len" => Op::Len {
                            dst: r,
                            src: args[0],
                        },
                        "at" => Op::Read {
                            dst: r,
                            src: args[0],
                            index: args[1],
                        },
                        "slice" => Op::Slice {
                            dst: r,
                            src: args[0],
                            start: args[1],
                            end: args[2],
                        },
                        _ => Op::Call { dst: r, name, args },
                    }
                });
                r
            } else if self.layouts.contains_key(&self.nominal(&name))
                && !self.vars.contains_key(&name)
                && self.eat("{")
            {
                let mut fields = Vec::new();
                if !self.eat("}") {
                    loop {
                        let field = self.ident()?;
                        self.expect(":")?;
                        let value = self.expr(ops, 0, depth + 1)?;
                        let dst = self.fresh()?;
                        ops.push(Op::Move { dst, src: value });
                        fields.push((field, dst));
                        if self.eat("}") {
                            break;
                        }
                        self.expect(",")?;
                        if self.eat("}") {
                            break;
                        }
                    }
                }
                let dst = self.fresh()?;
                ops.push(Op::Record {
                    dst,
                    ty: self.constructor_type(&self.nominal(&name), explicit)?,
                    fields,
                });
                dst
            } else {
                let src = self
                    .vars
                    .get(&name)
                    .ok_or_else(|| self.error("undefined variable"))?
                    .reg;
                let mut path = Vec::new();
                while self.eat(".") {
                    path.push(self.ident()?);
                }
                if path.is_empty() {
                    src
                } else {
                    let dst = self.fresh()?;
                    ops.push(Op::FieldMove { dst, src, path });
                    dst
                }
            }
        };
        loop {
            if self.eat("?") {
                left = self.propagate(left, ops)?;
                continue;
            }
            if self.eat("!") {
                let dst = self.fresh()?;
                ops.push(Op::Unwrap { dst, src: left });
                left = dst;
                continue;
            }
            let (precedence, op) = match self.peek() {
                "&" => (1, Bin::And),
                "^" => (2, Bin::Xor),
                "==" => (3, Bin::Eq),
                "!=" => (3, Bin::Ne),
                "<" => (3, Bin::Lt),
                "+" => (4, Bin::Add),
                "-" => (4, Bin::Sub),
                "*" => (5, Bin::Mul),
                "%" => (5, Bin::Rem),
                _ => break,
            };
            if precedence < minimum {
                break;
            }
            self.at += 1;
            let right = self.expr(ops, precedence + 1, depth + 1)?;
            let dst = self.fresh()?;
            ops.push(Op::Binary {
                dst,
                op,
                left,
                right,
            });
            left = dst;
        }
        Ok(left)
    }
    fn statements(&mut self, depth: usize) -> Result<Vec<Op>, String> {
        if depth > 64 {
            return Err(self.error("block nesting limit"));
        }
        let mut ops = vec![];
        while !matches!(self.peek(), "}" | "") {
            if self.peek() == "break" || self.peek() == "continue" {
                let is_break = self.eat("break");
                if !is_break {
                    self.expect("continue")?;
                }
                self.expect(";")?;
                ops.push(if is_break { Op::Break } else { Op::Continue });
            } else if self.eat("return") {
                let r = self.expr(&mut ops, 0, 0)?;
                self.expect(";")?;
                ops.push(Op::Return(r));
            } else if self.eat("{") {
                let outer = self.vars.clone();
                let body = self.statements(depth + 1)?;
                self.expect("}")?;
                self.vars = outer;
                ops.push(Op::Block { body });
            } else if self.peek() == "let" || self.peek() == "var" {
                let mutable = self.eat("var");
                if !mutable {
                    self.expect("let")?;
                }
                let name = self.ident()?;
                if self.eat(":") {
                    if !mutable {
                        return Err(self.error("uninitialized declarations require var"));
                    }
                    let ty = self.ty()?;
                    self.expect(";")?;
                    let dst = self.fresh()?;
                    ops.push(Op::Declare { dst, ty });
                    self.bind(name, dst, true);
                    continue;
                }
                self.expect("=")?;
                let value = if self.eat("buffer") {
                    self.expect("(")?;
                    let len = self
                        .peek()
                        .parse::<usize>()
                        .map_err(|_| self.error("buffer length must be literal"))?;
                    self.at += 1;
                    self.expect(",")?;
                    let seed = self
                        .peek()
                        .parse::<u64>()
                        .map_err(|_| self.error("buffer seed must be literal"))?;
                    self.at += 1;
                    self.expect(")")?;
                    let dst = self.fresh()?;
                    ops.push(Op::Buffer { dst, len, seed });
                    dst
                } else {
                    self.expr(&mut ops, 0, 0)?
                };
                let dst = self.fresh()?;
                ops.push(Op::Move { dst, src: value });
                self.bind(name, dst, mutable);
                self.expect(";")?;
            } else if self.eat("while") {
                let mut test = vec![];
                let condition = self.expr(&mut test, 0, 0)?;
                let outer = self.vars.clone();
                self.expect("{")?;
                let body = self.statements(depth + 1)?;
                self.expect("}")?;
                self.vars = outer;
                ops.push(Op::While {
                    condition,
                    test,
                    body,
                });
            } else if self.eat("for") {
                let name = self.ident()?;
                self.expect("in")?;
                let bound = self.expr(&mut ops, 0, 0)?;
                let end = self.fresh()?;
                ops.push(Op::Move {
                    dst: end,
                    src: bound,
                });
                let index = self.fresh()?;
                let outer = self.vars.clone();
                self.bind(name, index, false);
                self.expect("{")?;
                let body = self.statements(depth + 1)?;
                self.expect("}")?;
                self.vars = outer;
                ops.push(Op::Loop { index, end, body });
            } else if self.eat("match") {
                let src = self.expr(&mut ops, 0, 0)?;
                self.expect("{")?;
                let outer = self.vars.clone();
                let mut arms = Vec::new();
                while !self.eat("}") {
                    let variant = self.ident()?;
                    let binding = if self.eat("(") {
                        let r = self.fresh()?;
                        if self.eat("_") {
                        } else {
                            let name = self.ident()?;
                            self.bind(name, r, false);
                        }
                        self.expect(")")?;
                        Some(r)
                    } else {
                        None
                    };
                    self.expect("=>")?;
                    self.expect("{")?;
                    let body = self.statements(depth + 1)?;
                    self.expect("}")?;
                    self.vars = outer.clone();
                    arms.push(Arm {
                        variant,
                        binding,
                        body,
                    });
                    if !self.eat(",") {
                        self.expect("}")?;
                        break;
                    }
                }
                ops.push(Op::Match { src, arms });
            } else if self.eat("if") {
                let condition = self.expr(&mut ops, 0, 0)?;
                let outer = self.vars.clone();
                self.expect("{")?;
                let yes = self.statements(depth + 1)?;
                self.expect("}")?;
                self.vars = outer.clone();
                let no = if self.eat("else") {
                    self.expect("{")?;
                    let no = self.statements(depth + 1)?;
                    self.expect("}")?;
                    no
                } else {
                    vec![]
                };
                self.vars = outer;
                ops.push(Op::If { condition, yes, no });
            } else if self.eat("drop") {
                self.expect("(")?;
                let n = self.ident()?;
                let r = self
                    .vars
                    .get(&n)
                    .ok_or_else(|| self.error("unknown drop variable"))?
                    .reg;
                self.expect(")")?;
                self.expect(";")?;
                ops.push(Op::End(r));
            } else if self.eat("append_text") {
                self.expect("(")?;
                let owner = self.expr(&mut ops, 0, 0)?;
                self.expect(",")?;
                let src = self.expr(&mut ops, 0, 0)?;
                self.expect(")")?;
                self.expect(";")?;
                ops.push(Op::AppendText { owner, src });
            } else if self.eat("push") {
                self.expect("(")?;
                let owner = self.expr(&mut ops, 0, 0)?;
                self.expect(",")?;
                let value = self.expr(&mut ops, 0, 0)?;
                self.expect(")")?;
                self.expect(";")?;
                ops.push(Op::Push { owner, value });
            } else if self.eat("write") {
                self.expect("(")?;
                let dst = self.storage_expr(&mut ops, Mode::Write, 0)?;
                self.expect(",")?;
                let index = self.expr(&mut ops, 0, 0)?;
                self.expect(",")?;
                let value = self.expr(&mut ops, 0, 0)?;
                self.expect(")")?;
                self.expect(";")?;
                ops.push(Op::Write { dst, index, value });
            } else if self.eat("assert") {
                self.expect("(")?;
                let r = self.expr(&mut ops, 0, 0)?;
                self.expect(")")?;
                self.expect(";")?;
                ops.push(Op::Assert(r));
            } else if self.assignment_ahead() {
                let name = self.ident()?;
                let b = self
                    .vars
                    .get(&name)
                    .ok_or_else(|| self.error("undefined assignment"))?
                    .clone();
                if !b.mutable {
                    return Err(self.error("assignment requires var"));
                }
                let mut path = Vec::new();
                while self.eat(".") {
                    path.push(self.ident()?);
                }
                self.expect("=")?;
                let src = self.expr(&mut ops, 0, 0)?;
                self.expect(";")?;
                if !path.is_empty() {
                    ops.push(Op::FieldAssign {
                        dst: b.reg,
                        path,
                        src,
                    });
                } else if src != b.reg {
                    ops.push(Op::Assign { dst: b.reg, src });
                }
            } else {
                let mut expression = Vec::new();
                let r = self.expr(&mut expression, 0, 0)?;
                self.expect(";")?;
                expression.push(Op::End(r));
                ops.push(Op::Block { body: expression });
            }
        }
        Ok(ops)
    }
}
/// Read import names without provider source or body analysis.
pub fn imports(text: &str) -> Result<Vec<String>, String> {
    let mut p = Parser {
        tokens: lex(text)?,
        at: 0,
        next: 0,
        vars: BTreeMap::new(),
        regions: BTreeMap::new(),
        type_params: BTreeMap::new(),
        module: String::new(),
        layouts: crate::types::Context::default(),
        return_ty: None,
    };
    if p.eat("module") {
        p.ident()?;
        p.expect(";")?;
    }
    let mut names = vec![];
    while p.eat("use") {
        let n = p.ident()?;
        if names.contains(&n) {
            return Err(p.error("duplicate import"));
        }
        names.push(n);
        p.expect(";")?;
    }
    Ok(names)
}
pub fn compile(
    text: &str,
    available: BTreeMap<String, crate::module::Interface>,
) -> Result<crate::module::CheckedModule, String> {
    let mut p = Parser {
        tokens: lex(text)?,
        at: 0,
        next: 0,
        vars: BTreeMap::new(),
        regions: BTreeMap::new(),
        type_params: BTreeMap::new(),
        module: String::new(),
        layouts: crate::types::Context::default(),
        return_ty: None,
    };
    let explicit = if p.eat("module") {
        let name = p.ident()?;
        p.expect(";")?;
        Some(name)
    } else {
        None
    };
    p.module = explicit.clone().unwrap_or_default();
    let mut definitions = crate::types::Definitions::new();
    let mut callable = BTreeMap::new();
    let mut generic_callable = BTreeMap::new();
    let mut dependencies = BTreeMap::new();
    while p.eat("use") {
        let name = p.ident()?;
        let header = available
            .get(&name)
            .ok_or_else(|| p.error("missing imported module interface"))?;
        header.validate()?;
        for (n, d) in &header.layouts {
            if let Some(old) = definitions.insert(n.clone(), d.clone())
                && old != *d
            {
                return Err(p.error("conflicting imported record layouts"));
            }
        }

        if header.name != name {
            return Err(p.error("import name does not match module"));
        }
        if dependencies.insert(name, header.fingerprint()?).is_some() {
            return Err(p.error("duplicate import"));
        }
        generic_callable.extend(header.generics.iter().map(|(n, g)| (n.clone(), g.clone())));
        callable.extend(header.exports.iter().map(|(n, s)| (n.clone(), s.clone())));
        if let Some(entry) = &header.entry {
            callable.insert(header.name.clone(), header.exports[entry].clone());
        }
        p.expect(";")?;
    }
    let mut public_types = BTreeSet::new();
    while matches!(p.peek(), "struct" | "enum")
        || (p.peek() == "pub"
            && p.tokens
                .get(p.at + 1)
                .is_some_and(|s| matches!(s.text, "struct" | "enum")))
    {
        let public = p.eat("pub");
        let (n, d) = p.record()?;
        if public {
            public_types.insert(n.clone());
        }
        if definitions.insert(n, d).is_some() {
            return Err(p.error("duplicate record declaration"));
        }
    }
    let layouts = crate::types::Context::new(definitions)?;
    p.layouts = layouts.clone();
    let mut functions = Vec::new();
    while !p.peek().is_empty() {
        if functions.len() >= 4096 {
            return Err(p.error("function limit"));
        }
        functions.push(p.function()?);
    }
    if functions.is_empty() && (public_types.is_empty() || explicit.is_none()) {
        return Err(p.error("expected function"));
    }
    let implicit = explicit.is_none();
    let name = explicit.unwrap_or_else(|| functions[0].0.sig.name.clone());
    let mut locals = BTreeMap::new();
    let mut generic_locals = BTreeMap::new();
    let mut exports = BTreeMap::new();
    let mut generic_exports = BTreeMap::new();
    let mut declared = BTreeSet::new();
    for (i, (f, public, parameters)) in functions.iter_mut().enumerate() {
        *public |= implicit && i == 0;
        let local = f.sig.name.clone();
        if callable.contains_key(&local)
            || generic_callable.contains_key(&local)
            || !declared.insert(local.clone())
        {
            return Err(p.error("function/import collision or duplicate function"));
        }
        if *public || *parameters > 0 {
            f.sig.name = format!("{name}::{local}");
        }
        if *parameters == 0 {
            locals.insert(local, f.sig.clone());
            if *public {
                exports.insert(f.sig.name.clone(), f.sig.clone());
            }
        } else {
            let g = crate::template::Signature {
                parameters: *parameters,
                function: f.sig.clone(),
            };
            generic_locals.insert(local, g.clone());
            if *public {
                generic_exports.insert(f.sig.name.clone(), g);
            }
        }
    }
    for (alias, sig) in locals {
        callable.insert(alias, sig.clone());
        callable.insert(sig.name.clone(), sig);
    }
    for (alias, g) in generic_locals {
        generic_callable.insert(alias, g.clone());
        generic_callable.insert(g.function.name.clone(), g);
    }
    let entry = functions
        .iter()
        .find(|(_, public, n)| *public && *n == 0)
        .map(|(f, _, _)| f.sig.name.clone());
    if entry.is_none() && public_types.is_empty() && generic_exports.is_empty() {
        return Err(p.error("explicit module needs a pub function or type"));
    }
    let mut surfaces = exports.clone();
    surfaces.extend(
        generic_exports
            .iter()
            .map(|(n, g)| (n.clone(), g.function.clone())),
    );
    let exposed = crate::types::exposed(&surfaces, &public_types, &layouts)?;
    let mut header = crate::module::Interface {
        name: name.clone(),
        entry,
        exports,
        generics: generic_exports,
        layouts: exposed,
        dependencies,
        implementations: BTreeMap::new(),
        template_hash: None,
    };
    header.validate()?;
    let mut checked = Vec::new();
    let mut bodies = Vec::new();
    let has_templates = functions.iter().any(|(_, _, n)| *n > 0);
    for (f, public, parameters) in functions {
        let label = f.sig.name.clone();
        let (body, public, parameters) = check_function(
            f,
            public,
            parameters,
            &callable,
            &generic_callable,
            &available,
            &name,
            &mut header,
            &layouts,
        )
        .map_err(|e| format!("fn {label}: {e}"))?;
        if parameters > 0 {
            bodies.push(body);
        } else {
            if has_templates && !public {
                bodies.push(body.clone());
            }
            checked.push((body, public));
        }
    }
    let bundle = if has_templates {
        let bundle = crate::template::Bundle::from_bodies(
            &name,
            layouts.clone(),
            bodies,
            header.implementations.clone(),
        )?;
        header.template_hash = Some(bundle.hash()?);
        Some(bundle)
    } else {
        None
    };
    header.validate()?;
    Ok(crate::module::CheckedModule {
        functions: checked,
        layouts,
        header,
        bundle,
    })
}
#[allow(clippy::too_many_arguments)]
fn check_function(
    mut f: Function,
    public: bool,
    parameters: u16,
    callable: &BTreeMap<String, Sig>,
    generic_callable: &BTreeMap<String, crate::template::Signature>,
    available: &BTreeMap<String, crate::module::Interface>,
    name: &str,
    header: &mut crate::module::Interface,
    layouts: &crate::types::Context,
) -> Result<(crate::Checked, bool, u16), String> {
    let mut names = BTreeSet::new();
    let mut generic_names = BTreeSet::new();
    resolve_calls(
        &mut f.ops,
        callable,
        generic_callable,
        &mut names,
        &mut generic_names,
    )?;
    let mut imports = BTreeMap::new();
    for n in names {
        if n != f.sig.name {
            imports.insert(n.clone(), callable[&n].clone());
        }
    }
    let generics = generic_names
        .iter()
        .map(|n| (n.clone(), generic_callable[n].clone()))
        .collect::<BTreeMap<_, _>>();
    for n in &generic_names {
        let (module, _) = n
            .split_once("::")
            .ok_or("generic function needs qualified module name")?;
        if module != name
            && let Some(h) = available.get(module).and_then(|h| h.template_hash.clone())
        {
            header.implementations.insert(module.into(), h);
        }
    }
    let mut available_calls = imports.clone();
    available_calls.insert(f.sig.name.clone(), f.sig.clone());
    let mut state = State::parameters_bound(&f.sig, layouts.clone(), parameters)?;
    state.generics = std::sync::Arc::new(generics.clone());
    state.install_scopes(&f.ops)?;
    let ops = ending(
        &f.ops,
        &mut state,
        &available_calls,
        &BTreeSet::new(),
        &BTreeSet::new(),
    )?;
    let body = crate::check_bound(
        Function { ops, ..f },
        imports,
        layouts.clone(),
        parameters,
        generics,
    )?;
    Ok((body, public, parameters))
}
fn resolve_calls(
    ops: &mut [Op],
    callable: &BTreeMap<String, Sig>,
    generics: &BTreeMap<String, crate::template::Signature>,
    names: &mut BTreeSet<String>,
    generic_names: &mut BTreeSet<String>,
) -> Result<(), String> {
    for op in ops {
        match op {
            Op::Call { dst, name, args } => {
                if let Some(sig) = callable.get(name) {
                    *name = sig.name.clone();
                    names.insert(name.clone());
                } else if let Some(g) = generics.get(name) {
                    let n = g.function.name.clone();
                    generic_names.insert(n.clone());
                    *op = Op::GenericCall {
                        dst: *dst,
                        name: n,
                        type_args: None,
                        args: args.clone(),
                    };
                } else {
                    return Err(format!("undefined function {name}"));
                }
            }
            Op::GenericCall { name, .. } => {
                let g = generics
                    .get(name)
                    .ok_or_else(|| format!("undefined generic function {name}"))?;
                *name = g.function.name.clone();
                generic_names.insert(name.clone());
            }
            Op::Block { body } | Op::Loop { body, .. } => {
                resolve_calls(body, callable, generics, names, generic_names)?
            }
            Op::While { test, body, .. } => {
                resolve_calls(test, callable, generics, names, generic_names)?;
                resolve_calls(body, callable, generics, names, generic_names)?;
            }
            Op::Match { arms, .. } => {
                for a in arms {
                    resolve_calls(&mut a.body, callable, generics, names, generic_names)?;
                }
            }
            Op::If { yes, no, .. } => {
                resolve_calls(yes, callable, generics, names, generic_names)?;
                resolve_calls(no, callable, generics, names, generic_names)?;
            }
            _ => {}
        }
    }
    Ok(())
}
fn clean(state: &mut State, live: &BTreeSet<Reg>, protected: &BTreeSet<Reg>, ops: &mut Vec<Op>) {
    loop {
        let candidates = state
            .resources
            .iter()
            .filter(|r| !state.values[r].ty.owned() && !live.contains(r) && !protected.contains(r))
            .copied()
            .collect::<Vec<_>>();
        let mut changed = false;
        for r in candidates {
            if state.end_if_live(r).is_ok() {
                ops.push(Op::EndIfLive(r));
                changed = true
            }
        }
        let layouts = state
            .resources
            .iter()
            .filter(|r| {
                matches!(state.values[r].ty, Ty::Named(..))
                    && !live.contains(r)
                    && !protected.contains(r)
            })
            .copied()
            .collect::<Vec<_>>();
        for r in layouts {
            if state.expire_captures(r).unwrap_or(false) {
                ops.push(Op::EndCaptures(r));
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
}
fn ending(
    ops: &[Op],
    state: &mut State,
    imports: &BTreeMap<String, Sig>,
    out: &BTreeSet<Reg>,
    protected: &BTreeSet<Reg>,
) -> Result<Vec<Op>, String> {
    let entry_owners = protected.clone();
    let afters = crate::flow::afters(ops, out);
    let mut result = vec![];
    for (op, after) in ops.iter().zip(afters) {
        if state.terminated {
            return Err("unreachable statement after control transfer".into());
        }
        if matches!(op, Op::Break | Op::Continue) {
            let frame = state
                .loops
                .last()
                .ok_or("loop exit outside loop body")?
                .clone();
            let keep = frame.values.keys().copied().collect();
            clean(state, &keep, &keep, &mut result);
            let owners = state
                .resources
                .iter()
                .rev()
                .filter(|r| state.values[r].ty.owned() && !frame.values.contains_key(r))
                .copied()
                .collect::<Vec<_>>();
            for r in owners {
                state.end_if_live(r)?;
                result.push(Op::EndIfLive(r));
            }
            state.ops(std::slice::from_ref(op), imports, 0)?;
            result.push(op.clone());
            continue;
        }
        if let Op::Return(r) = op {
            clean(state, &BTreeSet::from([*r]), &BTreeSet::new(), &mut result);
            let owners = state
                .resources
                .iter()
                .rev()
                .filter(|v| state.values[v].ty.owned() && **v != *r)
                .copied()
                .collect::<Vec<_>>();
            for owner in owners {
                state.end_if_live(owner)?;
                result.push(Op::EndIfLive(owner));
            }
            state.ops(std::slice::from_ref(op), imports, 0)?;
            result.push(op.clone());
            continue;
        }
        if let Op::Block { body } = op {
            // Unconditional execution: keep its actual effects, without cloning or replaying state.
            let entry = state
                .resources
                .union(&state.declared)
                .copied()
                .collect::<BTreeSet<_>>();
            let owners = entry
                .iter()
                .filter(|r| state.values.get(r).is_none_or(|v| v.ty.owned()))
                .copied()
                .collect();
            let body = ending(body, state, imports, &after, &owners)?;
            if !state.terminated {
                state.validate_resource_frame(&entry)?;
            }
            result.push(Op::Block { body });
            if !state.terminated {
                clean(state, &after, protected, &mut result);
                state.prune_scalars(&after);
            }
            continue;
        }
        let keep = if matches!(
            op,
            Op::Loop { .. } | Op::If { .. } | Op::While { .. } | Op::Match { .. }
        ) {
            protected
                .union(&state.resources)
                .chain(&state.declared)
                .copied()
                .collect()
        } else {
            BTreeSet::new()
        };
        let op = match op {
            Op::While {
                condition,
                test,
                body,
            } => {
                let mut condition_state = state.clone();
                condition_state.loops.clear();
                let condition_out = BTreeSet::from([*condition]);
                let test = ending(test, &mut condition_state, imports, &condition_out, &keep)?;
                let mut body_state = state.clone();
                body_state.enter_loop(None)?;
                let mut body_out = live_before(op, &after);
                body_out.extend(&after);
                body_out.extend(body_state.scalars());
                body_out.extend(body_state.resources.iter().copied());
                let body = crate::flow::in_loop_body(&body_out, || {
                    ending(body, &mut body_state, imports, &body_out, &keep)
                })?;
                Op::While {
                    condition: *condition,
                    test,
                    body,
                }
            }
            Op::Loop { index, end, body } => {
                let mut inner = state.clone();
                inner.enter_loop(Some(*index))?;
                let mut body_out = after.clone();
                body_out.extend(inner.scalars());
                body_out.extend(inner.resources.iter().copied());
                Op::Loop {
                    index: *index,
                    end: *end,
                    body: crate::flow::in_loop_body(&body_out, || {
                        ending(body, &mut inner, imports, &body_out, &keep)
                    })?,
                }
            }
            Op::Match { src, arms } => {
                let indices = state.arms(*src, arms)?;
                let mut output = Vec::new();
                for (a, k) in arms.iter().zip(indices) {
                    let mut branch = state.clone();
                    branch.payload(*src, k, a.binding)?;
                    let mut keep = keep.clone();
                    keep.remove(src);
                    let body = ending(&a.body, &mut branch, imports, &after, &keep)?;
                    output.push(Arm {
                        variant: a.variant.clone(),
                        binding: a.binding,
                        body,
                    });
                }
                Op::Match {
                    src: *src,
                    arms: output,
                }
            }
            Op::If { condition, yes, no } => {
                let mut y = state.clone();
                let mut n = state.clone();
                Op::If {
                    condition: *condition,
                    yes: ending(yes, &mut y, imports, &after, &keep)?,
                    no: ending(no, &mut n, imports, &after, &keep)?,
                }
            }
            _ => op.clone(),
        };
        state.ops(std::slice::from_ref(&op), imports, 0)?;
        result.push(op);
        if !state.terminated {
            clean(state, &after, protected, &mut result);
            state.prune_scalars(&after);
        }
    }
    if state.terminated {
        return Ok(result);
    }
    // An empty match arm can still introduce a payload loan. Close it before its owners.
    clean(state, out, protected, &mut result);
    // Owner cleanup is lexical and reverse-binding, unlike last-use loan ending.
    let owners = state
        .resources
        .iter()
        .rev()
        .filter(|r| state.values[r].ty.owned() && !entry_owners.contains(r) && !out.contains(r))
        .copied()
        .collect::<Vec<_>>();
    for r in owners {
        state.end_if_live(r)?;
        result.push(Op::EndIfLive(r));
    }
    Ok(result)
}
