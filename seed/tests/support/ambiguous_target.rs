struct Cell<'a>{source:&'a[u8]}
fn select<'outer,'data>(left:&'outer mut Cell<'data>,right:&'outer mut Cell<'data>,n:bool)->&'outer mut Cell<'data>{if n{left}else{right}}
fn bad(n:bool)->u8{let mut a=vec![1];let b=vec![2];let c=vec![3];let mut left=Cell{source:&a};let mut right=Cell{source:&b};let chosen=select(&mut left,&mut right,n);std::mem::replace(&mut chosen.source,&c);for _ in 0..256{a.push(9);}left.source[0]+right.source[0]}
fn main(){}
