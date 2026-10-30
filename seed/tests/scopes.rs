//! Names, lexical destruction, and resource identity are separate contracts.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn shadowing_preserves_old_storage_and_restores_outer_names() {
    for s in [
        "fn f()->num {let b=bytes();push(b,7);let p=read(b);let b=bytes();push(b,9);return at(p,0)+len(b);}",
        "fn f()->num {let x=1;let x=x+2;{let x=9;assert(x==9);}return x;}",
        "fn f(x:num)->num {let x=x+1;return x;}",
        "fn f()->num {let b=bytes();let b=b;push(b,1);return len(b);}",
        "fn f()->num {let i=9;for i in 3 {assert(i<3);}return i;}",
        "fn f()->num {var x=1;{let x=2;assert(x==2);}x=3;return x;}",
        "fn f()->num {let b=bytes();{let p=read(b);assert(len(p)==0);push(b,7);}return len(b);}",
        "fn f()->num {let b=bytes();{let c=b;push(c,7);}return 0;}",
        "fn f()->num {let b=bytes();{drop(b);}return 0;}",
    ] {
        assert!(ok(s), "{s}");
    }
}
#[test]
fn scopes_do_not_hide_moves_loans_or_invalid_names() {
    for s in [
        "fn f()->num {let b=bytes();{drop(b);}return len(b);}",
        "fn f()->num {let b=bytes();{let c=b;}return len(b);}",
        "fn f()->num {{let x=7;}return x;}",
        "fn f()->num {var x=1;{let x=2;x=3;}return x;}",
        "fn f(x:num,x:num)->num {return x;}",
        "fn f()->num {let b=bytes();let p=read(b);{drop(b);}return len(p);}",
        "fn f()->num {let b=bytes();let p=read(b);let b=bytes();drop(b);return len(b)+len(p);}",
        "fn f()->num {let b=buffer(4,0);let w=mut(b);let p=read(w);let w=bytes();write(b,0,1);return len(p);}",
    ] {
        assert!(!ok(s), "{s}");
    }
}
