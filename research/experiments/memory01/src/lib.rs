//! Safe Rust reference-envelope probes, not a Grail implementation.
#[derive(Debug)]
pub struct Token<'a> {
    pub text: &'a str,
}

pub fn tokenize(source: &str) -> Vec<Token<'_>> {
    source
        .split_ascii_whitespace()
        .map(|text| Token { text })
        .collect()
}

pub fn choose<'a>(a: &'a str, b: &'a str, left: bool) -> &'a str {
    if left { a } else { b }
}

pub fn map_owned<T, U>(items: Vec<T>, f: impl FnMut(T) -> U) -> Vec<U> {
    items.into_iter().map(f).collect()
}

pub fn map_views<'a>(source: &'a str, f: impl FnMut(&'a str) -> &'a str) -> Vec<&'a str> {
    source.split_ascii_whitespace().map(f).collect()
}

pub fn visit(items: &mut [u32], mut f: impl FnMut(&mut u32)) {
    for item in items {
        f(item);
    }
}

pub fn selector<'a>(source: &'a str) -> impl Fn(usize) -> &'a str + 'a {
    move |offset| &source[offset..]
}

pub struct Reuser {
    buffer: String,
    step: usize,
}
impl Default for Reuser {
    fn default() -> Self {
        Self {
            buffer: String::with_capacity(16),
            step: 0,
        }
    }
}
impl Reuser {
    pub fn next_view(&mut self) -> Option<&str> {
        if self.step == 3 {
            return None;
        }
        self.buffer.clear();
        self.buffer.push_str(["alpha", "beta", "gamma"][self.step]);
        self.step += 1;
        Some(&self.buffer)
    }
}

pub struct PairViews<'a, 'b> {
    pub short: &'a str,
    pub long: &'b str,
}
pub fn pair<'a, 'b>(short: &'a str, long: &'b str) -> PairViews<'a, 'b> {
    PairViews { short, long }
}

/// A lifetime-only lease illustration, not a real mmap/cache eviction implementation.
pub struct Page {
    bytes: Vec<u8>,
}
pub struct PageGuard<'a> {
    page: &'a Page,
}
impl Page {
    pub fn new(bytes: Vec<u8>) -> Self {
        Self { bytes }
    }
    pub fn pin(&self) -> PageGuard<'_> {
        PageGuard { page: self }
    }
}
impl PageGuard<'_> {
    pub fn row(&self) -> &[u8] {
        &self.page.bytes
    }
}

/// Suspension-type probe only: intentionally never completes, and is never executed.
pub async fn suspended_fill(buffer: &mut [u8]) {
    std::future::pending::<()>().await;
    buffer[0] = 1;
}

/// Owning zero-copy document alternative: private offsets, not self-referential pointers.
pub struct Document {
    source: String,
    spans: Vec<(u32, u32)>,
}
impl Document {
    pub fn parse(source: String) -> Self {
        assert!(source.len() <= u32::MAX as usize);
        let spans = source
            .split_ascii_whitespace()
            .map(|s| {
                let start = s.as_ptr() as usize - source.as_ptr() as usize;
                (start as u32, (start + s.len()) as u32)
            })
            .collect();
        Self { source, spans }
    }
    pub fn texts(&self) -> impl Iterator<Item = &str> {
        self.spans
            .iter()
            .map(|&(start, end)| &self.source[start as usize..end as usize])
    }
    pub fn replace(&mut self, source: String) {
        *self = Self::parse(source);
    }
}

/// Tiny recursive parser workload: atoms and parenthesized groups, not a JSON parser.
#[derive(Debug)]
pub enum Expr<'a> {
    Atom(&'a str),
    Group(Vec<Expr<'a>>),
}
struct Cursor<'a> {
    source: &'a str,
    offset: usize,
}
impl<'a> Cursor<'a> {
    fn whitespace(&mut self) {
        while self
            .source
            .as_bytes()
            .get(self.offset)
            .is_some_and(u8::is_ascii_whitespace)
        {
            self.offset += 1;
        }
    }
    fn expression(&mut self) -> Result<Expr<'a>, &'static str> {
        self.whitespace();
        if self.source.as_bytes().get(self.offset) == Some(&b'(') {
            self.offset += 1;
            let mut children = Vec::new();
            loop {
                self.whitespace();
                match self.source.as_bytes().get(self.offset) {
                    Some(b')') => {
                        self.offset += 1;
                        break;
                    }
                    None => return Err("unclosed group"),
                    _ => children.push(self.expression()?),
                }
            }
            return Ok(Expr::Group(children));
        }
        let start = self.offset;
        while self
            .source
            .as_bytes()
            .get(self.offset)
            .is_some_and(|b| b.is_ascii_alphanumeric() || *b == b'_')
        {
            self.offset += 1;
        }
        if start == self.offset {
            return Err("expected atom or group");
        }
        Ok(Expr::Atom(&self.source[start..self.offset]))
    }
}
impl<'a> Expr<'a> {
    /// Leaf views retain the input's lifetime, not this AST node's lifetime.
    pub fn leaves(&self) -> Vec<&'a str> {
        fn visit<'a>(node: &Expr<'a>, out: &mut Vec<&'a str>) {
            match node {
                Expr::Atom(text) => out.push(text),
                Expr::Group(children) => {
                    for child in children {
                        visit(child, out);
                    }
                }
            }
        }
        let mut out = Vec::new();
        visit(self, &mut out);
        out
    }
}
pub fn parse_tree(source: &str) -> Result<Expr<'_>, &'static str> {
    let mut cursor = Cursor { source, offset: 0 };
    let result = cursor.expression()?;
    cursor.whitespace();
    if cursor.offset != source.len() {
        return Err("trailing input");
    }
    Ok(result)
}
