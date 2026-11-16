// FNV-1a over 64 MiB of pseudo-random bytes, eight times; prints the final hash (twin of bench/fnv.c).
package main

import "fmt"

func main() {
	const n = 67108864
	data := make([]byte, 0, n)
	var x uint64 = 88172645463325252
	for i := 0; i < n; i++ {
		x ^= x << 13
		x ^= x >> 7
		x ^= x << 17
		data = append(data, byte(x&255))
	}
	var h uint64 = 14695981039346656037
	for round := 0; round < 8; round++ {
		for i := 0; i < n; i++ {
			h = (h ^ uint64(data[i])) * 1099511628211
		}
	}
	fmt.Println(h)
}
