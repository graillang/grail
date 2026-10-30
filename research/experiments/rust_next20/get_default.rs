use std::collections::HashMap;
fn get(map:&mut HashMap<u32,u32>,key:u32)->&mut u32 {
    match map.get_mut(&key) {
        Some(value)=>value,
        None=>{map.insert(key,0);map.get_mut(&key).unwrap()}
    }
}
fn main(){let mut map=HashMap::new();*get(&mut map,1)=7;assert_eq!(*get(&mut map,1),7);}
