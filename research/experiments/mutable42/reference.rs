use std::{cell::RefCell,rc::Rc};
type Log=Rc<RefCell<Vec<u64>>>;
struct Owned<T>{value:T,id:u64,log:Log}
impl<T>Owned<T>{fn new(value:T,id:u64,log:&Log)->Self{Self{value,id,log:log.clone()}}}
impl<T>Drop for Owned<T>{fn drop(&mut self){self.log.borrow_mut().push(self.id);}}
struct Cursor<'a>{source:&'a[u8],remaining:&'a[u8],_name:Owned<String>}
struct Unique<'a>{source:&'a mut[u8],_name:Owned<String>}
fn advance(c:&mut Cursor<'_>,n:usize)->usize{c.remaining=&c.remaining[n..];c.remaining.len()}
fn take<'a>(c:&mut Unique<'a>,v:&'a mut[u8])->&'a mut[u8]{std::mem::replace(&mut c.source,v)}
fn pop<'a>(p:&mut Option<&'a mut[u8]>)->Option<&'a mut[u8]>{std::mem::replace(p,None)}
fn fail<T>(_value:T,log:&Log)->Result<u64,Owned<String>>{Err(Owned::new("failure".to_owned(),6,log))}
fn main(){let log=Log::default();let result={
 let mut a=Owned::new(vec![3,4,5],1,&log);let mut b=Owned::new(vec![7],2,&log);
 let mut c=Cursor{source:&a.value,remaining:&a.value,_name:Owned::new("cursor".into(),3,&log)};let mut sum=0;
 for _ in 0..2{sum+=advance(&mut c,1)as u64;}assert_eq!(c.source.len(),3);drop(c);
 let mut unique=Unique{source:&mut a.value,_name:Owned::new("unique".into(),4,&log)};
 let old=take(&mut unique,&mut b.value);old[0]=9;
 let second=u64::from(unique.source[0]);drop(unique);let first=u64::from(a.value[0]);
 let mut option=Some(a.value.as_mut_slice());let taken=pop(&mut option);drop(option);let extracted=taken.unwrap();extracted[2]=13;
 let third=u64::from(a.value[2]);let retired=Unique{source:&mut a.value,_name:Owned::new("retired".into(),5,&log)};
 match fail(retired,&log){Ok(n)=>sum+=n,Err(e)=>sum+=e.value.len()as u64}
 let mut view=a.value.as_mut_slice();let previous=std::mem::replace(&mut view,b.value.as_mut_slice());previous[1]=11;
 sum+first+second+third+u64::from(view[0])};
 assert_eq!(result,46);assert_eq!(*log.borrow(),[3,4,5,6,2,1]);println!("{result} {:?}",log.borrow());}
