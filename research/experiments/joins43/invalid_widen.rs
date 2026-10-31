fn bad(n:usize){let a=vec![1];let mut b=Vec::new();let mut source=a.as_slice();for _ in 0..n{b.push(2);std::mem::replace(&mut source,b.as_slice());}println!("{}",source.len());}
fn main(){}
