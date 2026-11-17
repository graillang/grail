// Go twin of bench/bintrees.grl: *Node, collected by the GC.
package main

import "fmt"

type Node struct{ left, right *Node }

func make_(depth uint64) *Node {
	if depth == 0 {
		return &Node{}
	}
	return &Node{make_(depth - 1), make_(depth - 1)}
}

func check(t *Node) uint64 {
	if t == nil {
		return 0
	}
	return 1 + check(t.left) + check(t.right)
}

func main() {
	const max = 16
	fmt.Println(check(make_(max + 1)))
	longLived := make_(max)
	for d := uint64(4); d <= max; d += 2 {
		iterations := uint64(1) << (max - d + 4)
		var total uint64
		for i := uint64(0); i < iterations; i++ {
			total += check(make_(d))
		}
		fmt.Println(iterations, total)
	}
	fmt.Println(check(longLived))
}
