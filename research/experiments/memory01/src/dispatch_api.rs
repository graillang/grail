//! Artificial specialization-stress workload, not an application benchmark.
pub trait Value {
    fn value(&self) -> u64;
}
#[inline(never)]
pub fn generic<T: Value>(x: &T) -> u64 {
    let mut total = x.value();
    for k in 0..64u64 {
        total = total.rotate_left(3).wrapping_add(x.value() ^ k);
    }
    total
}
#[inline(never)]
pub fn erased(x: &dyn Value) -> u64 {
    let mut total = x.value();
    for k in 0..64u64 {
        total = total.rotate_left(3).wrapping_add(x.value() ^ k);
    }
    total
}
