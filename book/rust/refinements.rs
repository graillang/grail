struct Aligned(u64);

impl Aligned {
    fn new(value: u64) -> Aligned {
        assert!(value % 16 == 0, "align % 16 == 0");
        Aligned(value)
    }
}

struct Ray {
    t_max: f32,
}

impl Ray {
    fn new(t_max: f32) -> Ray {
        assert!(t_max.is_finite() && t_max > 0.0, "t_max is finite and positive");
        Ray { t_max }
    }
}

fn take(align: Aligned) -> u64 {
    align.0
}

fn main() {
    println!("{}", take(Aligned::new(16)));
    let n = 48;
    println!("{}", take(Aligned::new(n)));
    let r = Ray::new(2.5);
    println!("{}", r.t_max);
}
