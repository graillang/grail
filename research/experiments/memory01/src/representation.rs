//! Representation experiment only: safe parser/traversals, optional allocator instrumentation.
use std::{hint::black_box, mem::size_of, time::Instant};

#[cfg(count_alloc)]
mod allocation_counter {
    // Unsafe is confined to forwarding the allocator's unchanged contract to System.
    // This measurement infrastructure is NOT part of the parser/ownership API under study.
    use std::alloc::{GlobalAlloc, Layout, System};
    use std::sync::atomic::{AtomicU64, Ordering::Relaxed};
    pub struct Count;
    static CALLS: AtomicU64 = AtomicU64::new(0);
    static BYTES: AtomicU64 = AtomicU64::new(0);
    unsafe impl GlobalAlloc for Count {
        unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
            CALLS.fetch_add(1, Relaxed);
            BYTES.fetch_add(layout.size() as u64, Relaxed);
            unsafe { System.alloc(layout) }
        }
        unsafe fn alloc_zeroed(&self, layout: Layout) -> *mut u8 {
            CALLS.fetch_add(1, Relaxed);
            BYTES.fetch_add(layout.size() as u64, Relaxed);
            unsafe { System.alloc_zeroed(layout) }
        }
        unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
            CALLS.fetch_add(1, Relaxed);
            BYTES.fetch_add(new_size as u64, Relaxed);
            unsafe { System.realloc(ptr, layout, new_size) }
        }
        unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
            unsafe { System.dealloc(ptr, layout) }
        }
    }
    pub fn snapshot() -> (u64, u64) {
        (CALLS.load(Relaxed), BYTES.load(Relaxed))
    }
}
#[cfg(count_alloc)]
#[global_allocator]
static ALLOCATOR: allocation_counter::Count = allocation_counter::Count;

#[derive(Clone, Copy)]
struct Span {
    start: u32,
    end: u32,
}

fn scan<'a, T>(
    source: &'a str,
    count: usize,
    mut make: impl FnMut(&'a str, u32, u32) -> T,
) -> Vec<T> {
    assert!(source.len() <= u32::MAX as usize);
    let mut result = Vec::with_capacity(count);
    let mut begin = 0;
    for (i, byte) in source.bytes().enumerate() {
        if byte.is_ascii_whitespace() {
            if begin < i {
                result.push(make(&source[begin..i], begin as u32, i as u32));
            }
            begin = i + 1;
        }
    }
    if begin < source.len() {
        result.push(make(&source[begin..], begin as u32, source.len() as u32));
    }
    assert_eq!(result.len(), count);
    result
}

fn checksum<'a>(parts: impl Iterator<Item = &'a str>) -> u64 {
    parts.fold(0u64, |mut sum, part| {
        for byte in part.bytes() {
            sum = sum.rotate_left(3).wrapping_add(byte as u64);
        }
        sum.wrapping_add(part.len() as u64)
    })
}

fn measure<'s, T>(
    mode: &str,
    source: &'s str,
    count: usize,
    rounds: usize,
    build: impl Fn(&'s str, usize) -> Vec<T>,
    read: impl Fn(&[T], &'s str) -> u64,
) {
    let expected = checksum(source.split_ascii_whitespace());
    let (mut parse_ns, mut read_ns, mut drop_ns) = (0u128, 0u128, 0u128);
    #[cfg(count_alloc)]
    let (mut allocation_calls, mut requested_bytes) = (0u64, 0u64);
    #[cfg(not(count_alloc))]
    let (allocation_calls, requested_bytes) = (0u64, 0u64);
    for _ in 0..rounds {
        #[cfg(count_alloc)]
        let before = allocation_counter::snapshot();
        let start = Instant::now();
        let values = build(black_box(source), count);
        parse_ns += start.elapsed().as_nanos();
        #[cfg(count_alloc)]
        {
            let after = allocation_counter::snapshot();
            allocation_calls += after.0 - before.0;
            requested_bytes += after.1 - before.1;
        }
        let start = Instant::now();
        let actual = read(black_box(&values), black_box(source));
        read_ns += start.elapsed().as_nanos();
        assert_eq!(black_box(actual), expected);
        let start = Instant::now();
        drop(black_box(values));
        drop_ns += start.elapsed().as_nanos();
    }
    // In a non-instrumented binary these fields intentionally report zero, not allocation claims.
    let own_rss = own_peak_rss_kib();
    println!(
        "{{\"process_vm_hwm_kib\":{own_rss},\"mode\":\"{mode}\",\"tokens\":{count},\"rounds\":{rounds},\"input_bytes\":{},\"descriptor_bytes\":{},\"parse_ns\":{parse_ns},\"traverse_ns\":{read_ns},\"drop_ns\":{drop_ns},\"checksum\":{expected},\"allocation_instrumented\":{},\"allocation_calls\":{allocation_calls},\"requested_bytes\":{requested_bytes}}}",
        source.len(),
        size_of::<T>(),
        cfg!(count_alloc)
    );
}

fn own_peak_rss_kib() -> u64 {
    // Linux mm high-water mark, sampled after timed sections. Unlike wait4 rusage,
    // this avoids a fork/exec wrapper's inherited high-water memory floor.
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|text| {
            text.lines().find_map(|line| {
                line.strip_prefix("VmHWM:")?
                    .split_whitespace()
                    .next()?
                    .parse()
                    .ok()
            })
        })
        .unwrap_or(0)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mode = args.get(1).map(String::as_str).unwrap_or("views");
    let count: usize = args.get(2).map(|v| v.parse().unwrap()).unwrap_or(200_000);
    let rounds: usize = args.get(3).map(|v| v.parse().unwrap()).unwrap_or(8);
    let mut source = String::with_capacity(count * 24);
    for i in 0..count {
        source.push_str("field_");
        source.push_str(&(i % 10000).to_string());
        source.push_str(if i % 7 == 0 { "_long_value\n" } else { " " });
    }
    match mode {
        "views" => measure(
            mode,
            &source,
            count,
            rounds,
            |s, n| scan(s, n, |text, _, _| text),
            |v, _| checksum(v.iter().copied()),
        ),
        "offsets" => measure(
            mode,
            &source,
            count,
            rounds,
            |s, n| scan(s, n, |_, start, end| Span { start, end }),
            |v, s| checksum(v.iter().map(|p| &s[p.start as usize..p.end as usize])),
        ),
        "owned" => measure(
            mode,
            &source,
            count,
            rounds,
            |s, n| scan(s, n, |text, _, _| text.to_owned()),
            |v, _| checksum(v.iter().map(String::as_str)),
        ),
        _ => panic!("unknown mode"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn representations_match_tokens_and_checksums() {
        for source in ["", "   ", "one", "a b\ncc", "a\tb\rcc", "été λ\n世界"] {
            let expected: Vec<_> = source.split_ascii_whitespace().collect();
            let views = scan(source, expected.len(), |text, _, _| text);
            let spans = scan(source, expected.len(), |_, start, end| Span { start, end });
            let owned = scan(source, expected.len(), |text, _, _| text.to_owned());
            assert_eq!(views, expected);
            assert_eq!(
                spans
                    .iter()
                    .map(|p| &source[p.start as usize..p.end as usize])
                    .collect::<Vec<_>>(),
                expected
            );
            assert_eq!(
                owned.iter().map(String::as_str).collect::<Vec<_>>(),
                expected
            );
            assert_eq!(
                checksum(views.iter().copied()),
                checksum(owned.iter().map(String::as_str))
            );
        }
    }
}
