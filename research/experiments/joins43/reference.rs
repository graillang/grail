use std::{cell::RefCell,rc::Rc};
type Log=Rc<RefCell<Vec<u64>>>;
struct Owned<T>{value:T,id:u64,log:Log}
impl<T>Owned<T>{fn new(value:T,id:u64,log:&Log)->Self{Self{value,id,log:log.clone()}}}
impl<T>Drop for Owned<T>{fn drop(&mut self){self.log.borrow_mut().push(self.id);}}
struct Cell<'a>{source:&'a[u8],_name:Owned<String>}
fn fill<'a>(p:&mut Cell<'a>,a:&'a[u8],b:&'a[u8],n:usize)->&'a[u8]{for i in 0..n{if i&1!=0{p.source=a;continue;}p.source=b;if n==3{break;}}p.source}
fn pop_loop<'a>(input:&mut Option<&'a mut[u8]>,p:&mut Cell<'a>,n:usize,log:&Log)->&'a[u8]{for _ in 0..n{let Some(value)=input.take()else{break};let name=Owned::new("holder".to_owned(),6,log);let span:&'a[u8]=value;drop(name);p.source=span;}p.source}
// Assignment kills the old reference; initialized-value replacement still uses it.
fn assignment_control(){let a=vec![1];let mut b=Vec::new();let mut source=a.as_slice();for _ in 0..3{b.push(2);source=b.as_slice();}assert_eq!(source.len(),3);}
fn main(){assignment_control();let log=Log::default();let result={
 let mut a=Owned::new(vec![7],1,&log);let b=Owned::new(vec![11],2,&log);let c=Owned::new(vec![13],3,&log);
 let mut cell=Cell{source:&a.value,_name:Owned::new("cell".into(),4,&log)};let mut sum=0;
 for n in [0,1,2,3]{sum+=u64::from(fill(&mut cell,&b.value,&c.value,n)[0]);}drop(cell);
 let mut option=Some(a.value.as_mut_slice());let mut output=Cell{source:&b.value,_name:Owned::new("output".into(),5,&log)};
 let span=pop_loop(&mut option,&mut output,3,&log);drop(option);drop(output);sum+u64::from(span[0])+span.len()as u64};
 assert_eq!(result,52);assert_eq!(*log.borrow(),[4,6,5,3,2,1]);println!("{result} {:?}",log.borrow());}
