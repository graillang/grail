// The dot product of two vectors of one million float32, 200 passes with one element changed between
// passes; prints the total (twin of bench/dot_f32.c).
package main

import "fmt"

//go:noinline
func dot(x, y []float32) float32 {
	var s float32
	for i := range x {
		s = s + x[i]*y[i]
	}
	return s
}

func main() {
	const n = 1000000
	x := make([]float32, 0, n)
	y := make([]float32, 0, n)
	var xv, yv float32
	for i := 0; i < n; i++ {
		x = append(x, xv)
		y = append(y, yv)
		xv = xv + 0.5
		if 3.0 < xv {
			xv = 0
		}
		yv = yv + 0.25
		if 1.0 < yv {
			yv = 0
		}
	}
	total := 0.0
	for pass := 0; pass < 200; pass++ {
		x[pass] = x[pass] + 1.0
		total += float64(dot(x, y))
	}
	fmt.Println(total)
}
