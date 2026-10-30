use std::{collections::BTreeMap,time::Instant};
fn main(){
 for n in [250,1000,4000] {
  let source=format!("fn cost()->num {{let x=1;{}return x;}}","{let x=x+1;assert(x<3);}".repeat(n));
  let mut times=vec![];
  for _ in 0..5 {let t=Instant::now();let p=grail_seed::source::compile(std::hint::black_box(&source),BTreeMap::new()).unwrap();std::hint::black_box(p);times.push(t.elapsed().as_secs_f64());}
  times.sort_by(f64::total_cmp);println!("{n} {} {}",source.len(),times[2]);
 }
}
