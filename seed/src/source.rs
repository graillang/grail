//! Borrowed-token parser and local loan ending for the first .grl slice.
use crate::{Bin, Checked, Function, Mode, Op, Reg, Sig, State, Ty, check};
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
        } else if i + 1 < b.len() && [b"->", b"==", b"!="].iter().any(|s| b[i..].starts_with(*s)) {
            i += 2
        } else if b"(){}<>,:;=+-*%&^".contains(&b[i]) {
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
    fn bind(&mut self, name: String, reg: Reg, mutable: bool) -> Result<(), String> {
        if self.vars.contains_key(&name) {
            return Err(self.error("shadowing is not supported yet"));
        }
        self.vars.insert(name, Binding { reg, mutable });
        Ok(())
    }
    fn ty(&mut self) -> Result<Ty, String> {
        let name = self.ident()?;
        if name == "string" {
            return Ok(Ty::Text);
        }
        if name == "num" {
            return Ok(Ty::Num);
        }
        if name == "bytes" {
            return Ok(Ty::Bytes);
        }
        let mode = match name.as_str() {
            "read" | "read_holder" => Mode::Read,
            "mut" | "mut_holder" => Mode::Write,
            _ => return Err(self.error("unknown type")),
        };
        self.expect("<")?;
        let r = self.ident()?;
        let region = *self
            .regions
            .get(&r)
            .ok_or_else(|| self.error("undeclared region"))?;
        self.expect(">")?;
        Ok(if name.ends_with("holder") {
            Ty::Holder(mode, region)
        } else {
            Ty::View(mode, region)
        })
    }
    fn expr(&mut self, ops: &mut Vec<Op>, minimum: u8, depth: usize) -> Result<Reg, String> {
        if depth > 128 {
            return Err(self.error("expression nesting limit"));
        }
        let mut left = if self.eat("(") {
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
            let name = self.ident()?;
            if self.eat("(") {
                let mut args = vec![];
                if !self.eat(")") {
                    loop {
                        args.push(self.expr(ops, 0, depth + 1)?);
                        if self.eat(")") {
                            break;
                        }
                        self.expect(",")?;
                    }
                }
                let r = self.fresh()?;
                let arity = match name.as_str() {
                    "bytes" => Some(0),
                    "read" | "mut" | "hold" | "len" | "copy_bytes" | "text" => Some(1),
                    "at" => Some(2),
                    "slice" => Some(3),
                    _ => None,
                };
                if arity.is_some_and(|n| n != args.len()) {
                    return Err(self.error("builtin arity"));
                }
                ops.push(match name.as_str() {
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
                });
                r
            } else {
                self.vars
                    .get(&name)
                    .ok_or_else(|| self.error("undefined variable"))?
                    .reg
            }
        };
        loop {
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
        while !matches!(self.peek(), "}" | "return" | "") {
            if self.peek() == "let" || self.peek() == "var" {
                let mutable = self.eat("var");
                if !mutable {
                    self.expect("let")?;
                }
                let name = self.ident()?;
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
                self.bind(name, dst, mutable)?;
                self.expect(";")?;
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
                self.bind(name, index, false)?;
                self.expect("{")?;
                let body = self.statements(depth + 1)?;
                self.expect("}")?;
                self.vars = outer;
                ops.push(Op::Loop { index, end, body });
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
                let dst = self.expr(&mut ops, 0, 0)?;
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
            } else {
                let name = self.ident()?;
                let b = self
                    .vars
                    .get(&name)
                    .ok_or_else(|| self.error("undefined assignment"))?
                    .clone();
                if !b.mutable {
                    return Err(self.error("assignment requires var"));
                }
                self.expect("=")?;
                let src = self.expr(&mut ops, 0, 0)?;
                self.expect(";")?;
                if src != b.reg {
                    ops.push(Op::Move { dst: b.reg, src });
                }
            }
        }
        Ok(ops)
    }
}
/// One source module exports one function; imports are names resolved by the caller.
pub fn imports(text: &str) -> Result<Vec<String>, String> {
    let mut p = Parser {
        tokens: lex(text)?,
        at: 0,
        next: 0,
        vars: BTreeMap::new(),
        regions: BTreeMap::new(),
    };
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
pub fn compile(text: &str, available: BTreeMap<String, Sig>) -> Result<Checked, String> {
    let mut p = Parser {
        tokens: lex(text)?,
        at: 0,
        next: 0,
        vars: BTreeMap::new(),
        regions: BTreeMap::new(),
    };
    let mut imported = BTreeMap::new();
    while p.eat("use") {
        let name = p.ident()?;
        let sig = available
            .get(&name)
            .ok_or_else(|| p.error("missing imported interface"))?
            .clone();
        if imported.insert(name, sig).is_some() {
            return Err(p.error("duplicate import"));
        }
        p.expect(";")?;
    }
    p.expect("fn")?;
    let name = p.ident()?;
    if p.eat("<") {
        loop {
            let n = p.ident()?;
            let id = u16::try_from(p.regions.len()).map_err(|_| p.error("region limit"))?;
            if p.regions.insert(n, id).is_some() {
                return Err(p.error("duplicate region"));
            }
            if p.eat(">") {
                break;
            }
            p.expect(",")?;
        }
    }
    p.expect("(")?;
    let mut params = vec![];
    if !p.eat(")") {
        loop {
            let n = p.ident()?;
            p.expect(":")?;
            let t = p.ty()?;
            let r = p.fresh()?;
            p.bind(n, r, false)?;
            params.push(t);
            if p.eat(")") {
                break;
            }
            p.expect(",")?;
        }
    }
    p.expect("->")?;
    let result_ty = p.ty()?;
    let sig = Sig {
        name,
        params,
        result: result_ty,
    };
    sig.validate()?;
    p.expect("{")?;
    let mut ops = p.statements(0)?;
    p.expect("return")?;
    let result = p.expr(&mut ops, 0, 0)?;
    p.expect(";")?;
    p.expect("}")?;
    if !p.peek().is_empty() {
        return Err(p.error("only one function per module is supported"));
    }
    let f = Function { sig, ops, result };
    let mut state = State::default();
    for (i, t) in f.sig.params.iter().enumerate() {
        let roots = if t.reference().is_some() || t.owned() {
            BTreeSet::from([crate::Root::Param(i)])
        } else {
            BTreeSet::new()
        };
        let v = state.new_value(t.clone(), roots, BTreeSet::new());
        state.put(i as Reg, v)?;
    }
    let ops = ending(
        &f.ops,
        &mut state,
        &imported,
        &BTreeSet::from([result]),
        &BTreeSet::new(),
    )?;
    check(Function { ops, ..f }, imported)
}
fn live_before(op: &Op, after: &BTreeSet<Reg>) -> BTreeSet<Reg> {
    let mut live = after.clone();
    let (defs, uses): (Vec<Reg>, Vec<Reg>) = match op {
        Op::Num(r, _)
        | Op::Buffer { dst: r, .. }
        | Op::Bytes { dst: r }
        | Op::TextLiteral { dst: r, .. } => (vec![*r], vec![]),
        Op::Borrow { dst, src, .. }
        | Op::Move { dst, src }
        | Op::Pack { dst, src }
        | Op::Len { dst, src }
        | Op::CopyBytes { dst, src }
        | Op::Text { dst, src } => (vec![*dst], vec![*src]),
        Op::Slice {
            dst,
            src,
            start,
            end,
        } => (vec![*dst], vec![*src, *start, *end]),
        Op::End(r) => (vec![*r], vec![*r]),
        Op::Assert(r) => (vec![], vec![*r]),
        Op::AppendText { owner, src } => (vec![], vec![*owner, *src]),
        Op::Push { owner, value } => (vec![], vec![*owner, *value]),
        Op::Read { dst, src, index } => (vec![*dst], vec![*src, *index]),
        Op::Write { dst, index, value } => (vec![], vec![*dst, *index, *value]),
        Op::Binary {
            dst, left, right, ..
        } => (vec![*dst], vec![*left, *right]),
        Op::Call { dst, args, .. } => (vec![*dst], args.clone()),
        Op::If { condition, yes, no } => {
            live.extend(before(yes, after));
            live.extend(before(no, after));
            live.insert(*condition);
            return live;
        }
        Op::Loop { index, end, body } => {
            loop {
                let mut next = live.clone();
                next.extend(before(body, &live));
                next.remove(index);
                if next == live {
                    break;
                }
                live = next;
            }
            live.insert(*end);
            return live;
        }
    };
    for r in defs {
        live.remove(&r);
    }
    live.extend(uses);
    live
}
fn before(ops: &[Op], after: &BTreeSet<Reg>) -> BTreeSet<Reg> {
    ops.iter()
        .rev()
        .fold(after.clone(), |live, op| live_before(op, &live))
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
            if state.end(r).is_ok() {
                ops.push(Op::End(r));
                changed = true
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
    let mut afters = vec![];
    let mut live = out.clone();
    for op in ops.iter().rev() {
        afters.push(live.clone());
        live = live_before(op, &live)
    }
    afters.reverse();
    let mut result = vec![];
    for (op, after) in ops.iter().zip(afters) {
        let keep = if matches!(op, Op::Loop { .. } | Op::If { .. }) {
            protected.union(&state.resources).copied().collect()
        } else {
            BTreeSet::new()
        };
        let op = match op {
            Op::Loop { index, end, body } => {
                let mut inner = state.clone();
                inner.num(*index)?;
                Op::Loop {
                    index: *index,
                    end: *end,
                    body: ending(body, &mut inner, imports, &after, &keep)?,
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
        clean(state, &after, protected, &mut result);
    }
    // Owner cleanup is lexical and reverse-binding, unlike last-use loan ending.
    let owners = state
        .resources
        .iter()
        .rev()
        .filter(|r| state.values[r].ty.owned() && !entry_owners.contains(r) && !out.contains(r))
        .copied()
        .collect::<Vec<_>>();
    for r in owners {
        state.end(r)?;
        result.push(Op::End(r));
    }
    Ok(result)
}
