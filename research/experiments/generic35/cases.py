"""Independent preimplementation requirements, not claims of implemented Grail references."""

CASES: dict[str, tuple[bool, str]] = {
    "shared_cursor": (
        True,
        r"""struct Cursor<'a>{source:&'a[u8],pos:usize}fn next<'a>(c:&mut Cursor<'a>)->Option<&'a[u8]>{if c.pos==c.source.len(){return None;}let n=c.pos;c.pos+=1;Some(&c.source[n..n+1])}fn main(){let b=[1,2];let mut c=Cursor{source:&b,pos:0};let a=next(&mut c).unwrap();let z=next(&mut c).unwrap();assert_eq!((a[0],z[0]),(1,2));}""",
    ),
    "unique_cursor_short": (
        True,
        r"""struct Cursor<'a>{source:&'a mut[u8]}fn next<'s,'a>(c:&'s mut Cursor<'a>)->&'s[u8]{&*c.source}fn main(){let mut b=[1];let mut c=Cursor{source:&mut b};assert_eq!(next(&mut c)[0],1);assert_eq!(next(&mut c)[0],1);}""",
    ),
    "unique_cursor_extend": (
        False,
        r"""struct Cursor<'a>{source:&'a mut[u8]}fn next<'s,'a>(c:&'s mut Cursor<'a>)->&'a[u8]{&*c.source}fn main(){}""",
    ),
    "cell_replace": (
        True,
        r"""struct Cell<'a>{value:&'a[u8]}fn set<'a>(c:&mut Cell<'a>,x:&'a[u8]){c.value=x;}fn main(){let a=[1];let b=[2];let mut c=Cell{value:&a};set(&mut c,&b);assert_eq!(c.value[0],2);}""",
    ),
    "cell_shorten_body": (
        False,
        r"""struct Cell<'a>{value:&'a[u8]}fn set<'a,'s>(c:&'s mut Cell<'a>,x:&'s[u8]){c.value=x;}fn main(){}""",
    ),
    "cell_shorten_caller": (
        False,
        r"""struct Cell<'a>{value:&'a[u8]}fn set<'a>(c:&mut Cell<'a>,x:&'a[u8]){c.value=x;}fn main(){let a=[1];let mut c=Cell{value:&a};{let b=vec![2];set(&mut c,&b);}println!("{}",c.value[0]);}""",
    ),
    "generic_swap": (
        True,
        r"""struct Cell<'a>{value:&'a[u8]}fn exchange<T>(a:&mut T,b:&mut T){std::mem::swap(a,b);}fn main(){let a=[1];let b=[2];let mut x=Cell{value:&a};let mut y=Cell{value:&b};exchange(&mut x,&mut y);assert_eq!((x.value[0],y.value[0]),(2,1));}""",
    ),
    "unique_take": (
        True,
        r"""fn take<'a>(p:&mut Option<&'a mut[u8]>)->Option<&'a mut[u8]>{p.take()}fn main(){let mut a=[1];let mut p=Some(a.as_mut_slice());let v=take(&mut p).unwrap();assert!(take(&mut p).is_none());v[0]=2;assert_eq!(a[0],2);}""",
    ),
    "vector_shared_copy": (
        True,
        r"""fn first<'a>(v:&Vec<&'a[u8]>)->&'a[u8]{v[0]}fn main(){let a=[1];let b=[2];let mut v=vec![a.as_slice()];let r=first(&v);v.push(&b);assert_eq!((r[0],v[1][0]),(1,2));}""",
    ),
    "vector_unique_extend": (
        False,
        r"""fn first<'a>(v:&mut Vec<&'a mut[u8]>)->&'a[u8]{&*v[0]}fn main(){}""",
    ),
    "vector_shorten": (
        False,
        r"""fn append<'a,'s>(v:&'s mut Vec<&'a[u8]>,x:&'s[u8]){v.push(x);}fn main(){}""",
    ),
    "vector_unique_pop": (
        True,
        r"""fn pop<'a>(v:&mut Vec<&'a mut[u8]>)->Option<&'a mut[u8]>{v.pop()}fn main(){let mut a=[1];let mut b=[2];let mut v=vec![a.as_mut_slice(),b.as_mut_slice()];let x=pop(&mut v).unwrap();let y=pop(&mut v).unwrap();x[0]=3;y[0]=4;assert_eq!((a[0],b[0]),(4,3));}""",
    ),
}
