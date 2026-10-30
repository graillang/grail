fn main() {
 let source=String::from("(add (mul alpha beta) gamma)");
 let leaves;
 { let tree=view_api::parse_tree(&source).unwrap(); leaves=tree.leaves(); }
 assert_eq!(leaves,vec!["add","mul","alpha","beta","gamma"]);
 let start=source.as_ptr() as usize;
 for text in leaves { let p=text.as_ptr() as usize; assert!(p>=start && p+text.len()<=start+source.len()); }
 for invalid in ["(alpha", ")", "alpha beta", "λ"] { assert!(view_api::parse_tree(invalid).is_err()); }
 let large=format!("(root {})", "name ".repeat(10000));
 assert_eq!(view_api::parse_tree(&large).unwrap().leaves().len(),10001);
}
