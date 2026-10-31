struct Cell<'a>{source:&'a [u8]}
fn bad<'outer,'short,'long>(p:&'outer mut Cell<'short>,_anchor:&'long [u8])->&'outer mut Cell<'long>{p}
fn main(){}
