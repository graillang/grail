struct Cell<'a>{source:&'a[u8]}
fn bad<'short,'long>(p:&mut Cell<'short>,value:&'short[u8],anchor:&'short &'long[u8],n:usize)->&'long[u8]{p.source=*anchor;for _ in 0..n{p.source=value;}p.source}
fn main(){}
