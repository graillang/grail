struct Cell<'a>{source:&'a [u8]}
fn set<'a>(p:&mut Cell<'a>,v:&'a [u8]){p.source=v;}
fn bad<'a>(p:&mut Cell<'a>){let short=vec![9];set(p,&short);}
fn main(){}
