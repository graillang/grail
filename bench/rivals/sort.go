// Bottom-up merge sort of 4 million pseudo-random u64 values, three times; prints a checksum
// (twin of bench/sort.c).
package main

import "fmt"

func main() {
	const n = 4194304
	var check uint64
	for round := 0; round < 3; round++ {
		v := make([]uint64, 0, n)
		x := uint64(2463534242) + uint64(round)
		for i := 0; i < n; i++ {
			x ^= x << 13
			x ^= x >> 7
			x ^= x << 17
			v = append(v, x)
		}
		tmp := make([]uint64, n)
		copy(tmp, v)
		for width := 1; width < n; width *= 2 {
			for lo := 0; lo < n; {
				mid, hi := min(lo+width, n), min(lo+2*width, n)
				i, j := lo, mid
				for k := lo; k < hi; k++ {
					if i < mid && (j >= hi || v[i] <= v[j]) {
						tmp[k] = v[i]
						i++
					} else {
						tmp[k] = v[j]
						j++
					}
				}
				lo = hi
			}
			v, tmp = tmp, v
		}
		check ^= v[0] ^ v[n/2] ^ v[n-1]
	}
	fmt.Println(check)
}
