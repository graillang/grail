use grail_seed::source;
use std::collections::BTreeMap;

#[test]
fn minimal_main_and_borrowed_output_check_without_explicit_imports() {
    for text in [
        "fn main(){println(\"Hello, world!\");}",
        "module quiet;fn main(){}",
        "fn main(){println();print(7);println(8);}",
        "fn main(){let s=\"kept\";print(s);println(s);}",
        "fn main(){let b=bytes();push(b,65);println(b);push(b,66);println(b);}",
        "fn main(){let b=bytes();push(b,65);let m=mut(b);print(m);write(m,0,66);println(m);}",
        "fn helper(flag:num){let b=bytes();if flag{return ();}println(len(b));}fn main(){helper(0);}",
        "fn helper(flag:num){if flag{return ();}else{return ();}}fn main(){helper(0);}",
    ] {
        let checked =
            source::compile(text, BTreeMap::new()).unwrap_or_else(|e| panic!("{text}: {e}"));
        assert!(checked.header().entry.as_ref().unwrap().ends_with("::main"));
    }
}
#[test]
fn named_main_takes_priority_over_public_helpers() {
    let checked = source::compile(
        "module program;pub fn helper()->num{return 9;}fn main(){}",
        BTreeMap::new(),
    )
    .unwrap();
    assert_eq!(checked.header().entry.as_deref(), Some("program::main"));
}
#[test]
fn output_cannot_launder_moves_or_exclusive_access() {
    for text in [
        "fn main(){let b=bytes();let moved=b;println(b);}",
        "fn main(){let b=bytes();let m=mut(b);println(b);write(m,0,1);}",
        "fn main(){println(vec<num>());}",
        "fn main(){print();}",
        "fn main<type T>(){}",
        "fn print(){}fn main(){}",
        "fn bad()->num{}fn main(){}",
    ] {
        assert!(
            source::compile(text, BTreeMap::new()).is_err(),
            "accepted {text}"
        );
    }
}
