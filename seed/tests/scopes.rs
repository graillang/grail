//! Names, lexical destruction, and resource identity are separate contracts.
use grail_seed::source;
use std::collections::BTreeMap;
fn ok(s: &str) -> bool {
    source::compile(s, BTreeMap::new()).is_ok()
}
#[test]
fn shadowing_preserves_old_storage_and_restores_outer_names() {
    for s in [
        "fn f()->num {var b =bytes();push(b,7);p :=read(b);var b =bytes();push(b,9);return at(p,0)+len(b);}",
        "fn f()->num {x :=1;x :=x+2;{x :=9;assert(x==9);}return x;}",
        "fn f(x:num)->num {x :=x+1;return x;}",
        "fn f()->num {var b =bytes();var b =b;push(b,1);return len(b);}",
        "fn f()->num {i :=9;for i in 3 {assert(i<3);}return i;}",
        "fn f()->num {var x=1;{x :=2;assert(x==2);}x=3;return x;}",
        "fn f()->num {var b =bytes();{p :=read(b);assert(len(p)==0);push(b,7);}return len(b);}",
        "fn f()->num {b :=bytes();{var c =b;push(c,7);}return 0;}",
        "fn f()->num {b :=bytes();{drop(b);}return 0;}",
    ] {
        assert!(ok(s), "{s}");
    }
}
#[test]
fn scopes_do_not_hide_moves_loans_or_invalid_names() {
    for s in [
        "fn f()->num {b :=bytes();{drop(b);}return len(b);}",
        "fn f()->num {b :=bytes();{c :=b;}return len(b);}",
        "fn f()->num {{x :=7;}return x;}",
        "fn f()->num {var x=1;{x :=2;x=3;}return x;}",
        "fn f(x:num,x:num)->num {return x;}",
        "fn f()->num {b :=bytes();p :=read(b);{drop(b);}return len(p);}",
        "fn f()->num {b :=bytes();p :=read(b);b :=bytes();drop(b);return len(b)+len(p);}",
        "fn f()->num {var b =buffer(4,0);w :=mut(b);p :=read(w);w :=bytes();write(b,0,1);return len(p);}",
    ] {
        assert!(!ok(s), "{s}");
    }
}
