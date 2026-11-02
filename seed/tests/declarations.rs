use grail_seed::source;
use std::collections::BTreeMap;

#[test]
fn explicit_declarations_and_mutable_capabilities() {
    for text in [
        "fn main(){base:=40;var answer=base;answer+=2;println(answer);}",
        "fn main(){data:=bytes();println(len(data));var moved=data;push(moved,1);}",
        "fn main(){var data=bytes();push(data,1);writer:=mut(data);write(writer,0,7);}",
        "fn main(){var n=1;r:=borrow_mut(n);exchange(r,2);}",
        "module f;struct P{n:num}fn main(){var p=P{n:1};r:=borrow_mut(p);r.n+=2;println(p.n);}",
        "fn main(){var n=2;n+=n;n*=n;n/=2;n%=5;n**=3;println(n);}",
        "fn main(){x:=2**3**2;assert(x==512);assert(2*3**2==18);assert(2**64==0);assert(0**0==1);}",
    ] {
        assert!(source::compile(text, BTreeMap::new()).is_ok(), "{text}");
    }
}

#[test]
fn immutable_owners_and_bindings_reject_writes() {
    for text in [
        "fn main(){data:=bytes();push(data,1);}",
        "fn main(){data:=bytes();writer:=mut(data);}",
        "fn main(){data:=\"text\";append_text(data,read(\"x\"));}",
        "fn main(){data:=vec<num>();vec_push(data,1);}",
        "fn main(){data:=vec<num>();vec_pop(data);}",
        "fn main(){data:=vec<num>();vec_get_mut(data,0);}",
        "fn main(){n:=1;r:=borrow_mut(n);}",
        "module f;struct P{n:num}fn main(){p:=P{n:1};p.n=2;}",
        "fn main(){x:=1;x+=2;}",
        "fn main(){x:=1;x=2;}",
        "fn main(){x=40;}",
        "fn main(){let x=40;}",
        "fn main(){var data=bytes();writer:=mut(data);borrow_mut(writer);}",
        "fn main(){var x;}",
        "fn main(){var n:num;n+=1;}",
        "fn main(){var b=bytes();b+=1;}",
        "fn bad<a>(p:ref_mut<a,num>)->num{return exchange(p,9);}fn main(){var n=1;n+=bad(borrow_mut(n));}",
    ] {
        assert!(
            source::compile(text, BTreeMap::new()).is_err(),
            "accepted {text}"
        );
    }
}
