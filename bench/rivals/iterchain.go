// Go twin of bench/iterchain.grl: 20 rounds over ten million u64 using Go 1.23+ iter.Seq adapters.
package main

import (
	"fmt"
	"iter"
	"slices"
)

func mapSeq(s iter.Seq[uint64], f func(uint64) uint64) iter.Seq[uint64] {
	return func(yield func(uint64) bool) {
		for x := range s {
			if !yield(f(x)) {
				return
			}
		}
	}
}

func filterSeq(s iter.Seq[uint64], keep func(uint64) bool) iter.Seq[uint64] {
	return func(yield func(uint64) bool) {
		for x := range s {
			if keep(x) && !yield(x) {
				return
			}
		}
	}
}

func main() {
	const n = 10000000
	v := make([]uint64, n)
	for i := range v {
		v[i] = uint64(i)
	}
	var s uint64
	for round := uint64(0); round < 20; round++ {
		r := round
		for y := range filterSeq(mapSeq(slices.Values(v), func(x uint64) uint64 { return (x + r) * 2 }), func(x uint64) bool { return x%3 == 0 }) {
			s += y
		}
	}
	fmt.Println(s)
}
