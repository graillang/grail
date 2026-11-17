// Go twin of bench/hashmap.grl: the built-in map.
package main

import "fmt"

func xs(x uint64) uint64 {
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	return x
}

func main() {
	const n = 1000000
	m := make(map[uint64]uint64)
	keys := make([]uint64, 0, n)
	var x uint64 = 88172645463325252
	for i := uint64(0); i < n; i++ {
		x = xs(x)
		keys = append(keys, x)
		m[x] = i
	}
	var sum, removed, found uint64
	for _, k := range keys {
		if v, ok := m[k]; ok {
			sum += v
		}
	}
	for i, k := range keys {
		if i%2 == 0 {
			if v, ok := m[k]; ok {
				removed += v
				delete(m, k)
			}
		}
	}
	for _, k := range keys {
		if _, ok := m[k]; ok {
			found++
		}
	}
	fmt.Println(sum, removed, found, len(m))
}
