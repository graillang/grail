struct Node {value:u32,next:Option<Box<Node>>}
fn append(mut slot:&mut Option<Box<Node>>,value:u32){
    while let Some(node)=slot {slot=&mut node.next;}
    *slot=Some(Box::new(Node{value,next:None}));
}
fn main(){let mut head=None;append(&mut head,1);append(&mut head,2);assert_eq!(head.unwrap().next.unwrap().value,2);}
