//! Bounded canonical type expressions; type parameters occur only in layout templates so far.
use crate::{Mode, Ty, qualified_ok};
impl Ty {
    pub(super) fn copy(&self) -> bool {
        matches!(self, Self::Num | Self::Unit)
    }
    pub(super) fn owned(&self) -> bool {
        matches!(
            self,
            Self::Buffer | Self::Bytes | Self::Text | Self::Named(..)
        )
    }
    pub(super) fn heap(&self) -> bool {
        matches!(self, Self::Bytes | Self::Text)
    }
    pub(super) fn reference(&self) -> Option<(Mode, u16)> {
        match self {
            Self::View(m, r) | Self::Holder(m, r) => Some((*m, *r)),
            _ => None,
        }
    }
    pub(super) fn word(&self) -> String {
        match self {
            Self::Num => "n".into(),
            Self::Unit => "u".into(),
            Self::Bytes => "o".into(),
            Self::Text => "s".into(),
            Self::Buffer => "b".into(),
            Self::Param(i) => format!("p{i}"),
            Self::View(m, r) => format!("{}{r}", if *m == Mode::Read { "r" } else { "w" }),
            Self::Holder(m, r) => format!("h{}{r}", if *m == Mode::Read { "r" } else { "w" }),
            Self::Named(n, rs, args) => {
                let mut s = format!(
                    "t{n}@{}",
                    rs.iter().map(u16::to_string).collect::<Vec<_>>().join(":")
                );
                if !args.is_empty() {
                    s.push('[');
                    for t in args {
                        let word = t.word();
                        s.push_str(&format!("{}#{word}", word.len()));
                    }
                    s.push(']');
                }
                s
            }
        }
    }
    pub(super) fn parse(s: &str) -> Result<Self, String> {
        Self::parse_at(s, 0, &mut 0)
    }
    fn parse_at(s: &str, depth: usize, nodes: &mut usize) -> Result<Self, String> {
        *nodes += 1;
        if depth > 64 || *nodes > 4096 || s.len() > 65536 {
            return Err("type expression limit".into());
        }
        if let Some(s) = s.strip_prefix('t') {
            let (head, tail) = if let Some((h, args)) = s.split_once('[') {
                (
                    h,
                    Some(args.strip_suffix(']').ok_or("invalid type arguments")?),
                )
            } else {
                (s, None)
            };
            let (name, regions) = head.split_once('@').ok_or("invalid nominal type")?;
            if !qualified_ok(name) {
                return Err("invalid nominal name".into());
            }
            let regions = if regions.is_empty() {
                vec![]
            } else {
                regions
                    .split(':')
                    .map(|r| r.parse::<u16>().map_err(|_| "invalid lifetime".to_string()))
                    .collect::<Result<Vec<_>, _>>()?
            };
            let mut args = Vec::new();
            if let Some(mut tail) = tail {
                while !tail.is_empty() {
                    let (len, rest) = tail.split_once('#').ok_or("invalid argument length")?;
                    let len = len
                        .parse::<usize>()
                        .map_err(|_| "invalid argument length")?;
                    let value = rest.get(..len).ok_or("truncated type argument")?;
                    args.push(Self::parse_at(value, depth + 1, nodes)?);
                    tail = rest.get(len..).ok_or("type argument boundary")?;
                    if args.len() > 64 {
                        return Err("type argument count limit".into());
                    }
                }
            }
            if regions.len() > 64 {
                return Err("lifetime argument limit".into());
            }
            return Ok(Self::Named(name.into(), regions, args));
        }
        if let Some(p) = s.strip_prefix('p') {
            return Ok(Self::Param(
                p.parse().map_err(|_| "invalid type parameter")?,
            ));
        }
        match s {
            "n" => return Ok(Self::Num),
            "u" => return Ok(Self::Unit),
            "o" => return Ok(Self::Bytes),
            "s" => return Ok(Self::Text),
            _ => {}
        }
        let (holder, s) = if let Some(s) = s.strip_prefix('h') {
            (true, s)
        } else {
            (false, s)
        };
        let mode = match s.as_bytes().first() {
            Some(b'r') => Mode::Read,
            Some(b'w') => Mode::Write,
            _ => return Err("invalid interface type".into()),
        };
        let region = s
            .get(1..)
            .ok_or("invalid lifetime")?
            .parse()
            .map_err(|_| "invalid lifetime")?;
        Ok(if holder {
            Self::Holder(mode, region)
        } else {
            Self::View(mode, region)
        })
    }
    pub(super) fn validate_shape(&self, parameters: u16) -> Result<(), String> {
        fn visit(
            t: &Ty,
            parameters: u16,
            depth: usize,
            nodes: &mut usize,
        ) -> Result<usize, String> {
            *nodes += 1;
            if depth > 64 || *nodes > 4096 {
                return Err("type expression limit".into());
            }
            let bytes = match t {
                Ty::Buffer => return Err("owned buffers cannot cross seed interfaces".into()),
                Ty::Param(i) => {
                    if *i >= parameters {
                        return Err("unbound type parameter".into());
                    }
                    1 + i.to_string().len()
                }
                Ty::Named(n, rs, args) => {
                    if !qualified_ok(n) || rs.len() > 64 || args.len() > 64 {
                        return Err("invalid nominal type".into());
                    }
                    let mut bytes = 2
                        + n.len()
                        + rs.iter().map(|r| r.to_string().len()).sum::<usize>()
                        + rs.len().saturating_sub(1);
                    if !args.is_empty() {
                        bytes += 2;
                    }
                    for a in args {
                        let len = visit(a, parameters, depth + 1, nodes)?;
                        bytes += len + 1 + len.to_string().len();
                    }
                    bytes
                }
                Ty::View(_, r) => 1 + r.to_string().len(),
                Ty::Holder(_, r) => 2 + r.to_string().len(),
                _ => 1,
            };
            if bytes > 65536 {
                return Err("type expression byte limit".into());
            }
            Ok(bytes)
        }
        visit(self, parameters, 0, &mut 0).map(|_| ())
    }
    pub(super) fn erase_regions(&self) -> Self {
        match self {
            Self::View(m, _) => Self::View(*m, 0),
            Self::Holder(m, _) => Self::Holder(*m, 0),
            Self::Named(n, rs, args) => Self::Named(
                n.clone(),
                vec![0; rs.len()],
                args.iter().map(Self::erase_regions).collect(),
            ),
            _ => self.clone(),
        }
    }
}
