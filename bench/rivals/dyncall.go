// Go twin of bench/dyncall.grl: a slice of interface values.
package main

import "fmt"

type Shape interface{ Area() uint64 }
type Square struct{ side uint64 }
type Rect struct{ w, h uint64 }
type Tri struct{ b, h uint64 }

func (s *Square) Area() uint64 { return s.side * s.side }
func (r *Rect) Area() uint64   { return r.w * r.h }
func (t *Tri) Area() uint64    { return t.b * t.h / 2 }

func xs(x uint64) uint64 {
	x ^= x << 13
	x ^= x >> 7
	x ^= x << 17
	return x
}

func main() {
	const n = 1000000
	shapes := make([]Shape, 0, n)
	var x uint64 = 88172645463325252
	for i := 0; i < n; i++ {
		x = xs(x)
		k, a, b := x%3, x%100, (x>>8)%100
		switch k {
		case 0:
			shapes = append(shapes, &Square{a})
		case 1:
			shapes = append(shapes, &Rect{a, b})
		default:
			shapes = append(shapes, &Tri{a, b})
		}
	}
	var total uint64
	for pass := 0; pass < 20; pass++ {
		for _, s := range shapes {
			total += s.Area()
		}
	}
	fmt.Println(total)
}
