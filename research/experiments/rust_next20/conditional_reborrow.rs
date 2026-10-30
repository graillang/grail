fn reborrow(a:&mut u8,choose:bool)->&mut u8 {
    let b=&mut *a;
    if choose {b}else{a}
}
fn main(){let mut x=0;*reborrow(&mut x,true)=1;*reborrow(&mut x,false)=2;assert_eq!(x,2);}
